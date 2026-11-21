// Live test against the real Supabase project (needs network).
// Run: flutter test test/live/quiz_game_live_test.dart
import 'dart:async';

import 'package:azkroh_app/features/core/services/backend.dart';
import 'package:azkroh_app/features/core/services/quiz_game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> waitFor(bool Function() ok, {int seconds = 15}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!ok()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('waitFor');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  test('host + 2 players play a 2-question game', () async {
    SupabaseClient mk() =>
        SupabaseClient(Backend.url, Backend.publishableKey);
    final host = await QuizGame.host(
        client: mk(), myId: 'h1', myName: 'المضيف', count: 2, seconds: 6);
    expect(host.code.length, 6);
    expect(host.state.value.total, 2);

    final p1 = await QuizGame.join(
        client: mk(), code: host.code, myId: 'p1', myName: 'أحمد');
    final p2 = await QuizGame.join(
        client: mk(), code: host.code, myId: 'p2', myName: 'محمد');
    await waitFor(() =>
        p1.state.value.phase == QuizPhase.lobby &&
        p2.state.value.phase == QuizPhase.lobby &&
        host.state.value.players.length == 3);

    await host.start();
    await waitFor(() => p1.state.value.phase == QuizPhase.question);
    host.answer(0);
    p1.answer(1);
    p2.answer(2);
    // All answered -> reveal right away.
    await waitFor(() => p2.state.value.phase == QuizPhase.reveal);
    expect(p2.state.value.correct, isNotNull);
    expect(p2.state.value.explanation, isNotNull);

    // Next question, nobody answers -> reveals on timeout, then finished.
    await waitFor(() => p1.state.value.phase == QuizPhase.question &&
        p1.state.value.index == 1);
    await waitFor(() => p1.state.value.phase == QuizPhase.finished,
        seconds: 20);
    expect(p1.state.value.players.length, 3);

    final bad = await QuizGame.join(
        client: mk(), code: '000001', myId: 'x', myName: 'x');
    await waitFor(() => bad.state.value.phase == QuizPhase.notFound,
        seconds: 10);

    // Host leaves -> players see the room closed (if not finished).
    for (final g in [host, p1, p2, bad]) {
      await g.dispose();
    }
  }, timeout: const Timeout(Duration(seconds: 90)));
}
