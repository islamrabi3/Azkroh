import '../utils/arabic_text.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A quiz question as played in a room.
class QuizQuestion {
  final String text;
  final List<String> options;
  final int correct;
  final String explanation;

  const QuizQuestion(this.text, this.options, this.correct, this.explanation);

  factory QuizQuestion.fromRow(Map row) => QuizQuestion(
        spellHonorifics(row['question'] as String),
        List<String>.from(row['options'] as List).map(spellHonorifics).toList(),
        (row['correct'] as num).toInt(),
        spellHonorifics((row['explanation'] ?? '') as String),
      );
}

class QuizPlayer {
  final String id;
  final String name;
  final int score;
  final bool answered;

  const QuizPlayer(this.id, this.name, this.score, this.answered);

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'score': score, 'answered': answered};

  factory QuizPlayer.fromJson(Map j) => QuizPlayer(
      j['id'] as String,
      j['name'] as String,
      (j['score'] as num).toInt(),
      j['answered'] == true);
}

enum QuizPhase { connecting, lobby, question, reveal, finished, notFound, closed }

/// Snapshot of the room shown by the UI.
class QuizState {
  final QuizPhase phase;
  final int index; // 0-based question index
  final int total;
  final int seconds;
  final DateTime? deadline; // local clock
  final String? question;
  final List<String> options;
  final int? correct; // only in reveal / finished
  final String? explanation;
  final List<QuizPlayer> players; // sorted by score desc
  final int? myAnswer;

  const QuizState({
    this.phase = QuizPhase.connecting,
    this.index = 0,
    this.total = 0,
    this.seconds = 20,
    this.deadline,
    this.question,
    this.options = const [],
    this.correct,
    this.explanation,
    this.players = const [],
    this.myAnswer,
  });

  QuizState copyWith({
    QuizPhase? phase,
    int? myAnswer,
    bool clearMyAnswer = false,
    List<QuizPlayer>? players,
  }) =>
      QuizState(
        phase: phase ?? this.phase,
        index: index,
        total: total,
        seconds: seconds,
        deadline: deadline,
        question: question,
        options: options,
        correct: correct,
        explanation: explanation,
        players: players ?? this.players,
        myAnswer: clearMyAnswer ? null : (myAnswer ?? this.myAnswer),
      );
}

/// Multiplayer quiz over Supabase Realtime (broadcast + presence), without
/// any login: the host's device runs the game; players join with the room
/// number. Channel: `quiz-<code>`.
class QuizGame {
  final SupabaseClient client;
  final bool isHost;
  final String code;
  final String myId;
  final String myName;

  QuizGame._(this.client, this.isHost, this.code, this.myId, this.myName);

  final ValueNotifier<QuizState> state = ValueNotifier(const QuizState());

  RealtimeChannel? _ch;
  Timer? _timer;
  Timer? _joinTimeout;
  bool _disposed = false;

  // Host-only
  List<QuizQuestion> _questions = const [];
  int _seconds = 20;
  final Map<String, String> _names = {}; // id -> name (present players)
  final Map<String, int> _scores = {};
  final Map<String, int> _answers = {}; // this question: id -> choice
  int _index = -1;
  QuizPhase _phase = QuizPhase.lobby;
  DateTime? _deadline;

  // Player-only: last time the host was seen in presence.
  bool _hostSeen = false;

  static String newCode() =>
      (100000 + Random.secure().nextInt(900000)).toString();

  // ---------------------------------------------------------------------------
  // Create / join
  // ---------------------------------------------------------------------------
  static Future<QuizGame> host({
    required SupabaseClient client,
    required String myId,
    required String myName,
    required int count,
    String? category,
    int seconds = 20,
  }) async {
    final rows = await client.rpc('random_questions',
        params: {'p_count': count, 'p_category': category}) as List;
    final g = QuizGame._(client, true, newCode(), myId, myName);
    g._questions = rows.map((r) => QuizQuestion.fromRow(r as Map)).toList();
    g._seconds = seconds;
    g._names[myId] = myName;
    g._scores[myId] = 0;
    await g._connect();
    g._publish();
    return g;
  }

  static Future<QuizGame> join({
    required SupabaseClient client,
    required String code,
    required String myId,
    required String myName,
  }) async {
    final g = QuizGame._(client, false, code, myId, myName);
    await g._connect();
    // Ask the host for the current state; no answer -> room not found.
    g._send('hello', {'id': myId, 'name': myName});
    g._joinTimeout = Timer(const Duration(seconds: 7), () {
      if (g.state.value.phase == QuizPhase.connecting) {
        g.state.value = const QuizState(phase: QuizPhase.notFound);
      }
    });
    return g;
  }

  Future<void> _connect() async {
    final ch = client.channel('quiz-$code',
        opts: RealtimeChannelConfig(key: myId, self: false));
    _ch = ch;
    ch.onBroadcast(event: 'state', callback: (m) => _onState(_payload(m)));
    if (isHost) {
      ch.onBroadcast(event: 'hello', callback: (m) => _onHello(_payload(m)));
      ch.onBroadcast(event: 'answer', callback: (m) => _onAnswer(_payload(m)));
    }
    ch.onPresenceSync((_) => _onPresence());

    final done = Completer<void>();
    ch.subscribe((status, err) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await ch.track({'id': myId, 'name': myName, 'host': isHost});
        if (!done.isCompleted) done.complete();
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        if (!done.isCompleted) {
          done.completeError(err ?? Exception('realtime $status'));
        }
      }
    });
    await done.future.timeout(const Duration(seconds: 12));
  }

  static Map<String, dynamic> _payload(Map<String, dynamic> m) {
    final p = m['payload'];
    return p is Map ? Map<String, dynamic>.from(p) : m;
  }

  void _send(String event, Map<String, dynamic> payload) {
    _ch?.sendBroadcastMessage(event: event, payload: payload);
  }

  // ---------------------------------------------------------------------------
  // Presence
  // ---------------------------------------------------------------------------
  void _onPresence() {
    final ch = _ch;
    if (ch == null || _disposed) return;
    final present = <String, String>{};
    var hostHere = false;
    for (final s in ch.presenceState()) {
      for (final p in s.presences) {
        final id = p.payload['id'] as String?;
        if (id == null) continue;
        present[id] = (p.payload['name'] as String?) ?? '';
        if (p.payload['host'] == true) hostHere = true;
      }
    }
    if (isHost) {
      present[myId] = myName;
      _names
        ..clear()
        ..addAll(present);
      for (final id in present.keys) {
        _scores.putIfAbsent(id, () => 0);
      }
      _publish();
      _maybeAllAnswered();
    } else {
      if (hostHere) _hostSeen = true;
      // Host left before the end.
      if (_hostSeen &&
          !hostHere &&
          state.value.phase != QuizPhase.finished &&
          state.value.phase != QuizPhase.closed) {
        state.value = state.value.copyWith(phase: QuizPhase.closed);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Host logic
  // ---------------------------------------------------------------------------
  void _onHello(Map<String, dynamic> p) {
    final id = p['id'] as String?;
    if (id == null) return;
    _names[id] = (p['name'] as String?) ?? '';
    _scores.putIfAbsent(id, () => 0);
    _publish();
  }

  void _onAnswer(Map<String, dynamic> p) {
    final id = p['id'] as String?;
    final idx = (p['index'] as num?)?.toInt();
    final choice = (p['choice'] as num?)?.toInt();
    if (id == null || idx != _index || choice == null) return;
    _recordAnswer(id, choice);
  }

  void _recordAnswer(String id, int choice) {
    if (_phase != QuizPhase.question || _answers.containsKey(id)) return;
    _answers[id] = choice;
    final q = _questions[_index];
    if (choice == q.correct) {
      final left = _deadline!.difference(DateTime.now()).inMilliseconds;
      final bonus = (100 * left / (_seconds * 1000)).clamp(0, 100).round();
      _scores[id] = (_scores[id] ?? 0) + 100 + bonus;
    }
    _publish();
    _maybeAllAnswered();
  }

  void _maybeAllAnswered() {
    if (_phase != QuizPhase.question) return;
    if (_names.keys.every(_answers.containsKey)) _reveal();
  }

  /// Host: start the game (also used for "play again").
  Future<void> start() async {
    if (!isHost) return;
    if (_index >= 0) {
      // Play again: new questions, scores reset.
      final rows = await client.rpc('random_questions',
          params: {'p_count': _questions.length}) as List;
      _questions = rows.map((r) => QuizQuestion.fromRow(r as Map)).toList();
      for (final k in _scores.keys.toList()) {
        _scores[k] = 0;
      }
      _index = -1;
    }
    _next();
  }

  void _next() {
    _timer?.cancel();
    _index++;
    if (_index >= _questions.length) {
      _phase = QuizPhase.finished;
      _publish();
      return;
    }
    _answers.clear();
    _phase = QuizPhase.question;
    _deadline = DateTime.now().add(Duration(seconds: _seconds));
    _publish();
    _timer = Timer(Duration(seconds: _seconds), _reveal);
  }

  void _reveal() {
    if (_phase != QuizPhase.question) return;
    _timer?.cancel();
    _phase = QuizPhase.reveal;
    _publish();
    _timer = Timer(const Duration(seconds: 5), _next);
  }

  /// Host: the full state, broadcast to players and applied locally.
  void _publish() {
    if (!isHost || _disposed) return;
    final q = (_index >= 0 && _index < _questions.length)
        ? _questions[_index]
        : null;
    final showAnswer =
        _phase == QuizPhase.reveal || _phase == QuizPhase.finished;
    final players = _names.keys
        .map((id) => QuizPlayer(id, _names[id] ?? '', _scores[id] ?? 0,
            _answers.containsKey(id)))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final payload = <String, dynamic>{
      'phase': _phase.name,
      'index': _index < 0 ? 0 : _index,
      'total': _questions.length,
      'seconds': _seconds,
      'remainingMs': _deadline == null
          ? 0
          : max(0, _deadline!.difference(DateTime.now()).inMilliseconds),
      'question': q?.text,
      'options': q?.options ?? const <String>[],
      'correct': showAnswer ? q?.correct : null,
      'explanation': showAnswer ? q?.explanation : null,
      'players': players.map((p) => p.toJson()).toList(),
    };
    _send('state', payload);
    _onState(payload);
  }

  // ---------------------------------------------------------------------------
  // Everyone
  // ---------------------------------------------------------------------------
  void _onState(Map<String, dynamic> p) {
    if (_disposed) return;
    _joinTimeout?.cancel();
    final phase = QuizPhase.values.firstWhere((e) => e.name == p['phase'],
        orElse: () => QuizPhase.lobby);
    final index = (p['index'] as num?)?.toInt() ?? 0;
    final prev = state.value;
    final sameQuestion = prev.index == index &&
        (prev.phase == QuizPhase.question || prev.phase == QuizPhase.reveal);
    final remaining = (p['remainingMs'] as num?)?.toInt() ?? 0;
    state.value = QuizState(
      phase: phase,
      index: index,
      total: (p['total'] as num?)?.toInt() ?? 0,
      seconds: (p['seconds'] as num?)?.toInt() ?? 20,
      deadline: phase == QuizPhase.question
          ? (sameQuestion && prev.deadline != null
              ? prev.deadline
              : DateTime.now().add(Duration(milliseconds: remaining)))
          : null,
      question: p['question'] as String?,
      options: List<String>.from((p['options'] as List?) ?? const []),
      correct: (p['correct'] as num?)?.toInt(),
      explanation: p['explanation'] as String?,
      players: ((p['players'] as List?) ?? const [])
          .map((e) => QuizPlayer.fromJson(e as Map))
          .toList(),
      myAnswer: sameQuestion ? prev.myAnswer : null,
    );
  }

  /// Answer the current question (once).
  void answer(int choice) {
    final s = state.value;
    if (s.phase != QuizPhase.question || s.myAnswer != null) return;
    state.value = s.copyWith(myAnswer: choice);
    if (isHost) {
      _recordAnswer(myId, choice);
    } else {
      _send('answer', {'id': myId, 'index': s.index, 'choice': choice});
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _joinTimeout?.cancel();
    final ch = _ch;
    _ch = null;
    if (ch != null) {
      try {
        await ch.untrack();
      } catch (_) {}
      await client.removeChannel(ch);
    }
  }
}
