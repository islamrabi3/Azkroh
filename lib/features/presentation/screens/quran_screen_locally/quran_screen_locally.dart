import 'package:audioplayers/audioplayers.dart';
import 'package:azkroh_app/features/presentation/screens/quran_screen_locally/surah_data.dart';
import 'package:azkroh_app/features/presentation/screens/quran_screen_locally/surah_service.dart';
import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;
import 'package:shared_preferences/shared_preferences.dart';

class SurahListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
            title: Text('القرآن الكريم', textDirection: TextDirection.rtl)),
        body: ListView.builder(
          itemCount: 114,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(quran.getSurahNameArabic(index + 1),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri-Quran',
                      fontSize: 25.0)),
              subtitle: Text('عدد الآيات: ${quran.getVerseCount(index + 1)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 15.0, fontFamily: 'Amiri')),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SurahScreen(surahNumber: index + 1),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class SurahScreen extends StatefulWidget {
  final int surahNumber;

  SurahScreen({required this.surahNumber});

  @override
  _SurahScreenState createState() => _SurahScreenState();
}

class _SurahScreenState extends State<SurahScreen> {
  late SurahData _surahData;
  final SurahService _surahService = SurahService();
  int? _lastReadSurah;
  int? _lastReadVerse;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _surahData = _surahService.getSurahData(widget.surahNumber);
    _loadLastReadVerse();
  }

  Future<void> _loadLastReadVerse() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastReadSurah = _prefs.getInt('lastReadSurah');
      _lastReadVerse = _prefs.getInt('lastReadVerse');
    });
  }

  Future<void> _saveLastReadVerse(int surahNumber, int verseNumber) async {
    await _prefs.setInt('lastReadSurah', surahNumber);
    await _prefs.setInt('lastReadVerse', verseNumber);
    setState(() {
      _lastReadSurah = surahNumber;
      _lastReadVerse = verseNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_surahData.arabicName, textDirection: TextDirection.rtl),
        ),
        body: ListView.builder(
          itemCount: _surahData.verseCount,
          itemBuilder: (context, index) {
            String verse = quran.getVerse(
              widget.surahNumber,
              index + 1,
              verseEndSymbol: true,
            );
            if (index == 0 &&
                widget.surahNumber != 1 &&
                widget.surahNumber != 9) {
              verse = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\n\n' + verse;
            }
            return GestureDetector(
              onTap: () {
                _saveLastReadVerse(widget.surahNumber, index + 1);
              },
              child: Container(
                margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                padding: EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: _lastReadSurah == widget.surahNumber &&
                      _lastReadVerse == index + 1
                      ? Colors.yellow[100]
                      : null,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  verse,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Amiri-Quran',
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}