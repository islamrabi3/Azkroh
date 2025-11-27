import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quran/quran.dart' as quran;
import 'package:shared_preferences/shared_preferences.dart';

class EnhancedQuranScreen extends StatefulWidget {
  const EnhancedQuranScreen({super.key});

  @override
  State<EnhancedQuranScreen> createState() => _EnhancedQuranScreenState();
}

class _EnhancedQuranScreenState extends State<EnhancedQuranScreen>
    with TickerProviderStateMixin {
  int? _lastReadSurah;
  int? _lastReadVerse;
  int? _bookmarkedSurah;
  int? _bookmarkedVerse;
  late SharedPreferences _prefs;
  bool _isLoading = true;
  late AnimationController _animationController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadPreferences();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastReadSurah = _prefs.getInt('lastReadSurah');
      _lastReadVerse = _prefs.getInt('lastReadVerse');
      _bookmarkedSurah = _prefs.getInt('bookmarkedSurah');
      _bookmarkedVerse = _prefs.getInt('bookmarkedVerse');
      _isLoading = false;
    });
  }

  List<int> get _filteredSurahs {
    if (_searchQuery.isEmpty) {
      return List.generate(114, (index) => index + 1);
    }
    return List.generate(114, (index) => index + 1).where((surahNum) {
      final arabicName = quran.getSurahNameArabic(surahNum).toLowerCase();
      final englishName = quran.getSurahName(surahNum).toLowerCase();
      final query = _searchQuery.toLowerCase();
      return arabicName.contains(query) ||
          englishName.contains(query) ||
          surahNum.toString().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppStyle.primaryGreen))
            : CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  _buildSearchBar(),
                  if (_lastReadSurah != null) _buildLastReadSection(),
                  if (_bookmarkedSurah != null) _buildBookmarkSection(),
                  _buildSurahList(),
                ],
              ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180.h,
      floating: false,
      pinned: true,
      backgroundColor: AppStyle.primaryGreen,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          'القرآن الكريم',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black26,
                blurRadius: 4.r,
                offset: Offset(1.w, 1.h),
              ),
            ],
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppStyle.darkGreen,
                AppStyle.primaryGreen,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.1,
                  child: CustomPaint(
                    painter: IslamicPatternPainter(),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 20.h),
                    Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white,
                        size: 40.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15.r),
            boxShadow: [
              BoxShadow(
                color: AppStyle.primaryGreen.withOpacity(0.1),
                blurRadius: 10.r,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              hintText: 'ابحث عن سورة...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14.sp),
              prefixIcon:
                  Icon(Icons.search, color: AppStyle.primaryGreen, size: 24.sp),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey, size: 20.sp),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20.w,
                vertical: 15.h,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLastReadSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EnhancedSurahScreen(
                  surahNumber: _lastReadSurah!,
                  initialVerse: _lastReadVerse,
                ),
              ),
            ).then((_) => _loadPreferences());
          },
          child: Container(
            padding: EdgeInsets.all(16.r),
            margin: EdgeInsets.only(bottom: 12.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppStyle.primaryGreen.withOpacity(0.8),
                  AppStyle.darkGreen,
                ],
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: AppStyle.primaryGreen.withOpacity(0.3),
                  blurRadius: 8.r,
                  offset: Offset(0, 4.h),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color: Colors.white,
                    size: 28.sp,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'متابعة القراءة',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14.sp,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'سورة ${quran.getSurahNameArabic(_lastReadSurah!)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontFamily: 'Amiri-Quran',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'الآية $_lastReadVerse',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white70,
                  size: 20.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookmarkSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EnhancedSurahScreen(
                  surahNumber: _bookmarkedSurah!,
                  initialVerse: _bookmarkedVerse,
                ),
              ),
            ).then((_) => _loadPreferences());
          },
          child: Container(
            padding: EdgeInsets.all(16.r),
            margin: EdgeInsets.only(bottom: 16.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppStyle.goldColor.withOpacity(0.5),
                width: 2.w,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppStyle.goldColor.withOpacity(0.1),
                  blurRadius: 8.r,
                  offset: Offset(0, 4.h),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: AppStyle.goldColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.bookmark_rounded,
                    color: AppStyle.goldColor,
                    size: 28.sp,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'العلامة المرجعية',
                        style: TextStyle(
                          color: AppStyle.textLight,
                          fontSize: 14.sp,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'سورة ${quran.getSurahNameArabic(_bookmarkedSurah!)}',
                        style: TextStyle(
                          color: AppStyle.textDark,
                          fontSize: 18.sp,
                          fontFamily: 'Amiri-Quran',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'الآية $_bookmarkedVerse',
                        style: TextStyle(
                          color: AppStyle.textLight,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppStyle.textLight,
                  size: 20.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSurahList() {
    final surahs = _filteredSurahs;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final surahNumber = surahs[index];
          return _buildSurahCard(surahNumber, index);
        },
        childCount: surahs.length,
      ),
    );
  }

  Widget _buildSurahCard(int surahNumber, int index) {
    final isBookmarked = _bookmarkedSurah == surahNumber;
    final revelationType = quran.getPlaceOfRevelation(surahNumber);
    final isMakki = revelationType == 'Makkah';

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 500)),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20.h * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10.r,
                  offset: Offset(0, 4.h),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16.r),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EnhancedSurahScreen(surahNumber: surahNumber),
                    ),
                  ).then((_) => _loadPreferences());
                },
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Row(
                    children: [
                      Container(
                        width: 50.r,
                        height: 50.r,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isBookmarked
                                ? [AppStyle.goldColor, AppStyle.darkGold]
                                : [AppStyle.primaryGreen, AppStyle.darkGreen],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$surahNumber',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quran.getSurahNameArabic(surahNumber),
                              style: TextStyle(
                                fontSize: 22.sp,
                                fontFamily: 'Amiri-Quran',
                                fontWeight: FontWeight.bold,
                                color: AppStyle.textDark,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Icon(
                                  isMakki
                                      ? Icons.location_city_rounded
                                      : Icons.mosque_rounded,
                                  size: 14.sp,
                                  color: AppStyle.textLight,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  isMakki ? 'مكية' : 'مدنية',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: AppStyle.textLight,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Icon(
                                  Icons.format_list_numbered_rounded,
                                  size: 14.sp,
                                  color: AppStyle.textLight,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  '${quran.getVerseCount(surahNumber)} آية',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: AppStyle.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            quran.getSurahName(surahNumber),
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppStyle.primaryGreen,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isBookmarked)
                            Padding(
                              padding: EdgeInsets.only(top: 4.h),
                              child: Icon(
                                Icons.bookmark_rounded,
                                color: AppStyle.goldColor,
                                size: 20.sp,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class EnhancedSurahScreen extends StatefulWidget {
  final int surahNumber;
  final int? initialVerse;

  const EnhancedSurahScreen({
    super.key,
    required this.surahNumber,
    this.initialVerse,
  });

  @override
  State<EnhancedSurahScreen> createState() => _EnhancedSurahScreenState();
}

class _EnhancedSurahScreenState extends State<EnhancedSurahScreen> {
  late SharedPreferences _prefs;
  int? _lastReadVerse;
  int? _bookmarkedVerse;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingVerse;
  bool _isPlaying = false;
  final ScrollController _scrollController = ScrollController();
  double _fontSize = 24.0;

  // Map to store GlobalKeys for each verse
  final Map<int, GlobalKey> _verseKeys = {};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
        _playingVerse = null;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Get or create a GlobalKey for a verse
  GlobalKey _getVerseKey(int verseNumber) {
    if (!_verseKeys.containsKey(verseNumber)) {
      _verseKeys[verseNumber] = GlobalKey();
    }
    return _verseKeys[verseNumber]!;
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      final savedSurah = _prefs.getInt('lastReadSurah');
      if (savedSurah == widget.surahNumber) {
        _lastReadVerse = _prefs.getInt('lastReadVerse');
      }
      final bookmarkedSurah = _prefs.getInt('bookmarkedSurah');
      if (bookmarkedSurah == widget.surahNumber) {
        _bookmarkedVerse = _prefs.getInt('bookmarkedVerse');
      }
      _fontSize = _prefs.getDouble('quran_font_size') ?? 24.0;
    });

    if (widget.initialVerse != null) {
      // Wait for the list to be built, then scroll
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Add a small delay to ensure the list is fully rendered
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollToVerse(widget.initialVerse!);
        });
      });
    }
  }

  void _scrollToVerse(int verseNumber) {
    final key = _verseKeys[verseNumber];
    if (key?.currentContext != null) {
      // Use Scrollable.ensureVisible for accurate scrolling
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.3, // Position verse at 30% from top of screen
      );
    } else {
      // Fallback: try again after a short delay
      Future.delayed(const Duration(milliseconds: 200), () {
        final retryKey = _verseKeys[verseNumber];
        if (retryKey?.currentContext != null) {
          Scrollable.ensureVisible(
            retryKey!.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.3,
          );
        }
      });
    }
  }

  Future<void> _saveLastRead(int verseNumber) async {
    await _prefs.setInt('lastReadSurah', widget.surahNumber);
    await _prefs.setInt('lastReadVerse', verseNumber);
    setState(() {
      _lastReadVerse = verseNumber;
    });
  }

  Future<void> _toggleBookmark(int verseNumber) async {
    if (_bookmarkedVerse == verseNumber) {
      await _prefs.remove('bookmarkedSurah');
      await _prefs.remove('bookmarkedVerse');
      setState(() {
        _bookmarkedVerse = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إزالة العلامة المرجعية',
              style: TextStyle(fontSize: 14.sp)),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      await _prefs.setInt('bookmarkedSurah', widget.surahNumber);
      await _prefs.setInt('bookmarkedVerse', verseNumber);
      setState(() {
        _bookmarkedVerse = verseNumber;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ العلامة المرجعية',
              style: TextStyle(fontSize: 14.sp)),
          backgroundColor: AppStyle.primaryGreen,
        ),
      );
    }
  }

  Future<void> _playVerse(int verseNumber) async {
    if (_playingVerse == verseNumber && _isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
      return;
    }

    int absoluteVerseNumber = 0;
    for (int i = 1; i < widget.surahNumber; i++) {
      absoluteVerseNumber += quran.getVerseCount(i);
    }
    absoluteVerseNumber += verseNumber;

    final audioUrl =
        'https://cdn.islamic.network/quran/audio/64/ar.alafasy/$absoluteVerseNumber.mp3';

    debugPrint('🎵 Playing audio: $audioUrl');

    try {
      setState(() {
        _playingVerse = verseNumber;
        _isPlaying = true;
      });

      await _audioPlayer.stop();
      await _audioPlayer.setSourceUrl(audioUrl);
      await _audioPlayer.resume();

      debugPrint('🎵 Audio started successfully');
    } catch (e) {
      debugPrint('🎵 Error playing audio: $e');
      setState(() {
        _isPlaying = false;
        _playingVerse = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text('عذراً، تأكد من اتصالك بالإنترنت',
                      style: TextStyle(fontSize: 14.sp)),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
        );
      }
    }
  }

  void _changeFontSize(double delta) async {
    final newSize = (_fontSize + delta).clamp(18.0, 36.0);
    await _prefs.setDouble('quran_font_size', newSize);
    setState(() {
      _fontSize = newSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    final verseCount = quran.getVerseCount(widget.surahNumber);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF8F5),
        appBar: AppBar(
          backgroundColor: AppStyle.primaryGreen,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Column(
            children: [
              Text(
                quran.getSurahNameArabic(widget.surahNumber),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                quran.getSurahName(widget.surahNumber),
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.text_decrease_rounded, size: 24.sp),
              onPressed: () => _changeFontSize(-2),
              tooltip: 'تصغير الخط',
            ),
            IconButton(
              icon: Icon(Icons.text_increase_rounded, size: 24.sp),
              onPressed: () => _changeFontSize(2),
              tooltip: 'تكبير الخط',
            ),
          ],
        ),
        body: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          itemCount: verseCount + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              if (widget.surahNumber != 1 && widget.surahNumber != 9) {
                return _buildBismillah();
              }
              return const SizedBox.shrink();
            }

            final verseNumber = index;
            return _buildVerseCard(verseNumber);
          },
        ),
      ),
    );
  }

  Widget _buildBismillah() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppStyle.primaryGreen.withOpacity(0.1),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
          style: TextStyle(
            fontSize: (_fontSize + 4).sp,
            fontFamily: 'Amiri-Quran',
            color: AppStyle.primaryGreen,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildVerseCard(int verseNumber) {
    final verse =
        quran.getVerse(widget.surahNumber, verseNumber, verseEndSymbol: true);
    final isBookmarked = _bookmarkedVerse == verseNumber;
    final isLastRead = _lastReadVerse == verseNumber;
    final isPlaying = _playingVerse == verseNumber && _isPlaying;

    return GestureDetector(
      key: _getVerseKey(verseNumber),
      onTap: () => _saveLastRead(verseNumber),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: isLastRead
              ? AppStyle.primaryGreen.withOpacity(0.05)
              : isBookmarked
                  ? AppStyle.goldColor.withOpacity(0.05)
                  : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isBookmarked
                ? AppStyle.goldColor.withOpacity(0.5)
                : isLastRead
                    ? AppStyle.primaryGreen.withOpacity(0.3)
                    : Colors.transparent,
            width: 2.w,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10.r,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              verse,
              style: TextStyle(
                fontSize: _fontSize.sp,
                fontFamily: 'Amiri-Quran',
                height: 2,
                color: AppStyle.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppStyle.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    'آية $verseNumber',
                    style: TextStyle(
                      color: AppStyle.primaryGreen,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_filled_rounded,
                    color: isPlaying ? AppStyle.primaryGreen : Colors.grey[600],
                    size: 32.sp,
                  ),
                  onPressed: () => _playVerse(verseNumber),
                  tooltip: isPlaying ? 'إيقاف' : 'استماع',
                ),
                IconButton(
                  icon: Icon(
                    isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: isBookmarked ? AppStyle.goldColor : Colors.grey[600],
                    size: 28.sp,
                  ),
                  onPressed: () => _toggleBookmark(verseNumber),
                  tooltip: isBookmarked ? 'إزالة العلامة' : 'إضافة علامة',
                ),
                IconButton(
                  icon: Icon(
                    isLastRead
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline_rounded,
                    color:
                        isLastRead ? AppStyle.primaryGreen : Colors.grey[600],
                    size: 28.sp,
                  ),
                  onPressed: () => _saveLastRead(verseNumber),
                  tooltip: 'تحديد كآخر قراءة',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class IslamicPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const double spacing = 40;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        _drawStar(canvas, Offset(x, y), 15, paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final x = center.dx + size * (i % 2 == 0 ? 1 : 0.5) * (i < 4 ? 1 : -1);
      final y =
          center.dy + size * (i % 2 == 0 ? 1 : 0.5) * (i < 2 || i > 5 ? -1 : 1);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
