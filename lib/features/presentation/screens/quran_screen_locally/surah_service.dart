import 'package:azkroh_app/features/presentation/screens/quran_screen_locally/surah_data.dart';
import 'package:quran/quran.dart' as quran;

class SurahService {
  SurahData getSurahData(int surahNumber) {
    String arabicText = '';
    for (int i = 1; i <= quran.getVerseCount(surahNumber); i++) {
      arabicText += '${quran.getVerse(surahNumber, i, verseEndSymbol: true)} ';
    }
    if (surahNumber != 1 && surahNumber != 9) {
      arabicText = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\n\n$arabicText';
    }

    return SurahData(
      number: surahNumber,
      arabicName: quran.getSurahNameArabic(surahNumber),
      verseCount: quran.getVerseCount(surahNumber),
      arabicText: arabicText,
    );
  }
}