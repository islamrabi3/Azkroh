import 'dart:async';
import 'dart:math';

import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/services/backend.dart';
import 'package:azkroh_app/features/core/services/quiz_game.dart';
import 'package:azkroh_app/features/core/utils/share_helper.dart';
import 'package:azkroh_app/features/core/widgets/app_loader.dart';
import 'package:azkroh_app/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _green = AppStyle.primaryGreen;
const _deep = Color(0xFF0B3D33);
const _gold = AppStyle.goldColor;

/// Entry: name, create a room, join by number, or play alone.
class QuizHomeScreen extends StatefulWidget {
  const QuizHomeScreen({super.key});

  @override
  State<QuizHomeScreen> createState() => _QuizHomeScreenState();
}

class _QuizHomeScreenState extends State<QuizHomeScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  String _myId = '';
  int _count = 10;
  int _seconds = 20;
  String? _category;
  bool _busy = false;

  static const _categories = <String, String>{
    'seerah': 'سيرة النبي ﷺ',
    'companions': 'الصحابة',
    'battles': 'الغزوات',
    'quran': 'أسئلة في القرآن',
    'prophets': 'الأنبياء',
    'general': 'معلومات دينية',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    var id = p.getString('quiz_player_id');
    if (id == null) {
      final r = Random.secure();
      id = List.generate(12, (_) => r.nextInt(16).toRadixString(16)).join();
      await p.setString('quiz_player_id', id);
    }
    _myId = id;
    _name.text = p.getString('quiz_player_name') ?? '';
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<bool> _checkName() async {
    final n = _name.text.trim();
    if (n.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('اكتب اسمك أولاً'))));
      return false;
    }
    final p = await SharedPreferences.getInstance();
    await p.setString('quiz_player_name', n);
    return true;
  }

  Future<void> _host() async {
    if (!await _checkName() || !mounted) return;
    await _open(() => QuizGame.host(
          client: Backend.client,
          myId: _myId,
          myName: _name.text.trim(),
          count: _count,
          category: _category,
          seconds: _seconds,
        ));
  }

  Future<void> _join() async {
    if (!await _checkName() || !mounted) return;
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('رقم الغرفة من ٦ أرقام'))));
      return;
    }
    await _open(() => QuizGame.join(
        client: Backend.client,
        code: code,
        myId: _myId,
        myName: _name.text.trim()));
  }

  Future<void> _open(Future<QuizGame> Function() make) async {
    if (!Backend.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('تأكد من الاتصال بالإنترنت ثم حاول مرة أخرى'))));
      return;
    }
    setState(() => _busy = true);
    try {
      final g = await make();
      if (!mounted) {
        await g.dispose();
        return;
      }
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => QuizRoomScreen(game: g)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(tr('تأكد من الاتصال بالإنترنت ثم حاول مرة أخرى'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocale.direction,
      child: Scaffold(
        backgroundColor: AppStyle.background,
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(tr('مسابقة أذكروه'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: _busy
            ? const AppLoader()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _hero(),
                  const SizedBox(height: 16),
                  _card(
                    title: tr('اسمك في المسابقة'),
                    child: TextField(
                      controller: _name,
                      textInputAction: TextInputAction.done,
                      decoration: _input(tr('مثال: عبد الله'),
                          Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _card(
                    title: tr('ادخل غرفة صديقك'),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _code,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 22,
                                letterSpacing: 6,
                                fontWeight: FontWeight.w700),
                            decoration: _input(tr('رقم الغرفة'), null)
                                .copyWith(counterText: ''),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _green,
                            minimumSize: const Size(96, 54),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _join,
                          child: Text(tr('دخول'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _card(
                    title: tr('أنشئ غرفة جديدة'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(tr('عدد الأسئلة')),
                        _chips<int>([5, 10, 15, 20], _count,
                            (v) => AppLocale.digits(v),
                            (v) => setState(() => _count = v)),
                        _label(tr('وقت كل سؤال')),
                        _chips<int>([10, 15, 20, 30], _seconds,
                            (v) => '${AppLocale.digits(v)} ${tr('ث')}',
                            (v) => setState(() => _seconds = v)),
                        _label(tr('القسم')),
                        _chips<String?>(
                            [null, ..._categories.keys],
                            _category,
                            (v) => v == null
                                ? tr('الكل')
                                : tr(_categories[v]!),
                            (v) => setState(() => _category = v)),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: _deep,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _host,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: Text(tr('أنشئ الغرفة'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                            tr('ستحصل على رقم غرفة تشاركه مع أصدقائك، ويمكنك أيضاً البدء وحدك.'),
                            style: const TextStyle(
                                color: AppStyle.textLight, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [Color(0xFF13705A), _deep]),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: _gold, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('العب مع أصدقائك'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                    tr('أسئلة في السيرة والصحابة والقرآن والأنبياء، بدون تسجيل دخول'),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _input(String hint, IconData? icon) => InputDecoration(
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        filled: true,
        fillColor: AppStyle.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppStyle.textDark)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(t,
            style: const TextStyle(
                color: AppStyle.textLight, fontWeight: FontWeight.w600)),
      );

  Widget _chips<T>(List<T> values, T selected, String Function(T) label,
      ValueChanged<T> onTap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((v) {
        final sel = v == selected;
        return ChoiceChip(
          label: Text(label(v)),
          selected: sel,
          showCheckmark: false,
          selectedColor: _green,
          backgroundColor: Colors.white,
          side: BorderSide(color: sel ? _green : const Color(0xFFE3DED2)),
          labelStyle: TextStyle(
              color: sel ? Colors.white : AppStyle.textDark,
              fontWeight: FontWeight.w700),
          onSelected: (_) => onTap(v),
        );
      }).toList(),
    );
  }
}

/// The live room: lobby, questions, answer reveal and results.
class QuizRoomScreen extends StatefulWidget {
  final QuizGame game;

  const QuizRoomScreen({super.key, required this.game});

  @override
  State<QuizRoomScreen> createState() => _QuizRoomScreenState();
}

class _QuizRoomScreenState extends State<QuizRoomScreen> {
  QuizGame get g => widget.game;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    g.state.addListener(_changed);
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && g.state.value.phase == QuizPhase.question) {
        setState(() {});
      }
    });
  }

  void _changed() {
    if (!mounted) return;
    final s = g.state.value;
    if (s.phase == QuizPhase.reveal) {
      HapticFeedback.mediumImpact();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    g.state.removeListener(_changed);
    g.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = g.state.value;
    Widget body;
    switch (s.phase) {
      case QuizPhase.connecting:
        body = const AppLoader();
        break;
      case QuizPhase.notFound:
        body = _message(Icons.search_off_rounded,
            tr('لم نجد غرفة بهذا الرقم. تأكد من الرقم وأن صاحب الغرفة ما زال فيها.'));
        break;
      case QuizPhase.closed:
        body = _message(Icons.logout_rounded, tr('غادر صاحب الغرفة، انتهت المسابقة.'));
        break;
      case QuizPhase.lobby:
        body = _lobby(s);
        break;
      case QuizPhase.question:
      case QuizPhase.reveal:
        body = _question(s);
        break;
      case QuizPhase.finished:
        body = _results(s);
        break;
    }
    return Directionality(
      textDirection: AppLocale.direction,
      child: Scaffold(
        backgroundColor: AppStyle.background,
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
              '${tr('الغرفة')} ${AppLocale.digits(g.code)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: SafeArea(child: body),
      ),
    );
  }

  Widget _message(IconData icon, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 60, color: AppStyle.textLight),
              const SizedBox(height: 14),
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.7, fontSize: 15)),
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr('رجوع'))),
            ],
          ),
        ),
      );

  // ---------------------------------------------------------------------------
  Widget _lobby(QuizState s) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient:
                const LinearGradient(colors: [Color(0xFF13705A), _deep]),
          ),
          child: Column(
            children: [
              Text(tr('رقم الغرفة'),
                  style: TextStyle(color: Colors.white.withOpacity(0.8))),
              const SizedBox(height: 6),
              SelectableText(g.code,
                  style: const TextStyle(
                      color: _gold,
                      fontSize: 44,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: g.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr('تم النسخ'))));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text(tr('نسخ')),
                  ),
                  const SizedBox(width: 8),
                  Builder(
                    builder: (bctx) => TextButton.icon(
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: () => shareText(bctx,
                          '${tr('تعال نلعب مسابقة أذكروه! رقم الغرفة:')} ${g.code}'),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: Text(tr('مشاركة')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
            '${tr('اللاعبون')} (${AppLocale.digits(s.players.length)})',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...s.players.map((p) => _playerTile(p, showScore: false)),
        const SizedBox(height: 20),
        if (g.isHost)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _deep,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: s.total == 0 ? null : g.start,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
                s.players.length > 1 ? tr('ابدأ المسابقة') : tr('ابدأ وحدك'),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLoader(size: 24),
              const SizedBox(width: 10),
              Text(tr('في انتظار صاحب الغرفة ليبدأ...')),
            ],
          ),
      ],
    );
  }

  Widget _playerTile(QuizPlayer p, {bool showScore = true, int? rank}) {
    final me = p.id == g.myId;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: me ? const Color(0xFFE7F2EE) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: rank == 0 ? _gold : _green,
            child: Text(
                rank != null
                    ? AppLocale.digits(rank + 1)
                    : (p.name.isEmpty ? '?' : p.name.characters.first),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(me ? '${p.name} (${tr('أنت')})' : p.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (showScore)
            Text(AppLocale.digits(p.score),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: _green)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  Widget _question(QuizState s) {
    final reveal = s.phase == QuizPhase.reveal;
    final totalMs = s.seconds * 1000;
    final leftMs = s.deadline == null
        ? 0
        : max(0, s.deadline!.difference(DateTime.now()).inMilliseconds);
    final answered = s.players.where((p) => p.answered).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
                '${tr('السؤال')} ${AppLocale.digits(s.index + 1)} / ${AppLocale.digits(s.total)}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (!reveal)
              Text(
                  '${AppLocale.digits((leftMs / 1000).ceil())} ${tr('ث')}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: leftMs < 5000 ? Colors.redAccent : _green)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: reveal ? 0 : leftMs / totalMs,
            minHeight: 8,
            backgroundColor: const Color(0xFFE3DED2),
            color: leftMs < 5000 ? Colors.redAccent : _gold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(s.question ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 19, height: 1.7, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 14),
        ...List.generate(s.options.length, (i) => _option(s, i, reveal)),
        const SizedBox(height: 8),
        if (reveal && (s.explanation ?? '').isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF3DC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded, color: _gold),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(s.explanation!,
                        style: const TextStyle(height: 1.6))),
              ],
            ),
          )
        else if (!reveal)
          Center(
            child: Text(
                '${tr('أجاب')} ${AppLocale.digits(answered)} ${tr('من')} ${AppLocale.digits(s.players.length)}',
                style: const TextStyle(color: AppStyle.textLight)),
          ),
        if (reveal) ...[
          const SizedBox(height: 14),
          ...s.players.take(5).toList().asMap().entries.map(
              (e) => _playerTile(e.value, rank: e.key)),
        ],
      ],
    );
  }

  Widget _option(QuizState s, int i, bool reveal) {
    final mine = s.myAnswer == i;
    final isCorrect = reveal && s.correct == i;
    final isWrong = reveal && mine && s.correct != i;
    Color bg = Colors.white;
    Color border = const Color(0xFFE3DED2);
    if (!reveal && mine) {
      bg = const Color(0xFFE7F2EE);
      border = _green;
    }
    if (isCorrect) {
      bg = const Color(0xFFDDF3E6);
      border = const Color(0xFF2E9E5B);
    }
    if (isWrong) {
      bg = const Color(0xFFFBE3E1);
      border = Colors.redAccent;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: reveal || s.myAnswer != null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  g.answer(i);
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 1.6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(s.options[i],
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                if (isCorrect)
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF2E9E5B))
                else if (isWrong)
                  const Icon(Icons.cancel_rounded, color: Colors.redAccent)
                else if (mine)
                  const Icon(Icons.radio_button_checked_rounded,
                      color: _green),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  Widget _results(QuizState s) {
    final players = s.players;
    final top = players.isEmpty ? 0 : players.first.score;
    final me = players.firstWhere((p) => p.id == g.myId,
        orElse: () => QuizPlayer(g.myId, g.myName, 0, false));
    final winner = top > 0 && me.score == top;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: winner
                  ? const [Color(0xFFD4AF37), Color(0xFFA8842C)]
                  : const [Color(0xFF13705A), _deep],
            ),
          ),
          child: Column(
            children: [
              Icon(
                  winner
                      ? Icons.emoji_events_rounded
                      : Icons.favorite_rounded,
                  color: Colors.white,
                  size: 56),
              const SizedBox(height: 10),
              Text(winner ? tr('فزت! ما شاء الله') : tr('أحسنت!'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                  winner
                      ? tr('نسأل الله لك الأجر، وأن يلبسك حُلّة من حُلل الجنة')
                      : tr('لم تخسر شيئاً؛ ما دمت ذكرت الله فأنت من الفائزين، ونسأل الله لك الأجر'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, height: 1.7)),
              const SizedBox(height: 8),
              Text('${tr('نقاطك')}: ${AppLocale.digits(me.score)}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(tr('الترتيب'),
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...players.asMap().entries.map((e) => _playerTile(e.value, rank: e.key)),
        const SizedBox(height: 16),
        if (g.isHost)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: g.start,
            icon: const Icon(Icons.replay_rounded),
            label: Text(tr('العب مرة أخرى'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48)),
          onPressed: () => Navigator.pop(context),
          child: Text(tr('خروج')),
        ),
      ],
    );
  }
}
