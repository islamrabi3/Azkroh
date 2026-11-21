// Helper for manual simulator tests: joins QUIZ_CODE as a second player.

import 'dart:io';

import 'package:azkroh_app/features/core/services/backend.dart';
import 'package:azkroh_app/features/core/services/quiz_game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final code = Platform.environment['QUIZ_CODE'];
  test('join as second player', () async {
    final g = await QuizGame.join(
        client: SupabaseClient(Backend.url, Backend.publishableKey),
        code: code!,
        myId: 'friend',
        myName: 'أحمد');
    final end = DateTime.now().add(const Duration(seconds: 70));
    var answered = -1;
    while (DateTime.now().isBefore(end) &&
        g.state.value.phase != QuizPhase.finished) {
      final s = g.state.value;
      if (s.phase == QuizPhase.question && answered != s.index) {
        await Future<void>.delayed(const Duration(seconds: 2));
        g.answer(0);
        answered = s.index;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await g.dispose();
  }, skip: code == null, timeout: const Timeout(Duration(seconds: 90)));
}
