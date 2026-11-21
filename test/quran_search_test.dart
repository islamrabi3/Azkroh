import 'package:azkroh_app/features/presentation/screens/quran_screen_locally/quran_search_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final idx = QuranSearchIndex.instance;

  test('finds Al-Fatiha 2 without diacritics', () {
    final r = idx.search('الحمد لله رب العالمين');
    expect(r.first.surah, 1);
    expect(r.first.ayah, 2);
  });

  test('finds Al-Ikhlas with hamza-less spelling', () {
    final r = idx.search('قل هو الله احد');
    expect(r.any((h) => h.surah == 112 && h.ayah == 1), isTrue);
  });

  test('Ayat al-Kursi by a phrase', () {
    final r = idx.search('لا تأخذه سنة ولا نوم');
    expect(r.first.surah, 2);
    expect(r.first.ayah, 255);
    expect(r.first.page, 42);
  });

  test('multi-word search matches words in any order', () {
    final r = idx.search('موسى فرعون');
    expect(r.length, greaterThan(10));
  });

  test('short query returns nothing', () {
    expect(idx.search('ا'), isEmpty);
  });
}
