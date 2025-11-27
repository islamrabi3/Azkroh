import 'package:azkroh_app/features/core/services/azan_audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AzanSettingsScreen extends StatefulWidget {
  const AzanSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AzanSettingsScreen> createState() => _AzanSettingsScreenState();
}

class _AzanSettingsScreenState extends State<AzanSettingsScreen> {
  final AzanAudioService _azanService = AzanAudioService();
  
  bool _azanEnabled = true;
  String _selectedReciter = 'mishary';
  double _volume = 1.0;
  bool _isLoading = true;
  bool _isPlaying = false;
  
  // Prayer-specific toggles
  Map<String, bool> _prayerAzanEnabled = {
    'الفجر': true,
    'الظهر': true,
    'العصر': true,
    'المغرب': true,
    'العشاء': true,
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _azanService.initialize();
    
    final isEnabled = await _azanService.isAzanEnabled();
    final reciter = await _azanService.getSelectedReciter();
    final volume = await _azanService.getAzanVolume();
    
    // Load prayer-specific settings
    for (final prayer in _prayerAzanEnabled.keys) {
      _prayerAzanEnabled[prayer] = await _azanService.isAzanEnabledForPrayer(prayer);
    }
    
    setState(() {
      _azanEnabled = isEnabled;
      _selectedReciter = reciter;
      _volume = volume;
      _isLoading = false;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20.sp,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(message, style: TextStyle(fontSize: 14.sp)),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        margin: EdgeInsets.all(16.r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1B5E20),
                Color(0xFF2E7D32),
                Color(0xFF388E3C),
              ],
            ),
          ),
          child: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : Column(
                    children: [
                      _buildAppBar(),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.all(16.r),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMainToggle(),
                              SizedBox(height: 20.h),
                              if (_azanEnabled) ...[
                                _buildReciterSection(),
                                SizedBox(height: 20.h),
                                _buildVolumeSection(),
                                SizedBox(height: 20.h),
                                _buildPrayerToggles(),
                                SizedBox(height: 20.h),
                                _buildTestSection(),
                              ],
                              SizedBox(height: 30.h),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20.sp,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'إعدادات الأذان',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 48.w),
        ],
      ),
    );
  }

  Widget _buildMainToggle() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              gradient: _azanEnabled
                  ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFB8860B)])
                  : LinearGradient(colors: [Colors.grey.shade600, Colors.grey.shade700]),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              Icons.volume_up_rounded,
              color: _azanEnabled ? const Color(0xFF1B5E20) : Colors.white,
              size: 28.sp,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تشغيل الأذان',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _azanEnabled ? 'سيتم تشغيل الأذان عند دخول وقت الصلاة' : 'الأذان معطل',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _azanEnabled,
            onChanged: (value) async {
              HapticFeedback.selectionClick();
              await _azanService.setAzanEnabled(value);
              setState(() => _azanEnabled = value);
            },
            activeColor: const Color(0xFFFFD700),
            activeTrackColor: const Color(0xFFFFD700).withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildReciterSection() {
    return _buildSection(
      title: 'صوت المؤذن',
      icon: Icons.mic_rounded,
      child: Column(
        children: AzanAudioService.azanReciters.entries.map((entry) {
          final isSelected = _selectedReciter == entry.key;
          return GestureDetector(
            onTap: () async {
              HapticFeedback.selectionClick();
              await _azanService.setSelectedReciter(entry.key);
              setState(() => _selectedReciter = entry.key);
            },
            child: Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFFD700).withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFFD700).withOpacity(0.5)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24.r,
                    height: 24.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? const Color(0xFFFFD700) : Colors.white38,
                        width: 2.w,
                      ),
                      color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
                    ),
                    child: isSelected
                        ? Icon(Icons.check, color: const Color(0xFF1B5E20), size: 16.sp)
                        : null,
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Text(
                      entry.value['name']!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      setState(() => _isPlaying = true);
                      await _azanService.previewAzan(entry.key);
                      Future.delayed(const Duration(seconds: 15), () {
                        if (mounted) setState(() => _isPlaying = false);
                      });
                    },
                    icon: Icon(
                      Icons.play_circle_outline_rounded,
                      color: Colors.white70,
                      size: 24.sp,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVolumeSection() {
    return _buildSection(
      title: 'مستوى الصوت',
      icon: Icons.volume_up_rounded,
      child: Row(
        children: [
          Icon(Icons.volume_mute_rounded, color: Colors.white54, size: 20.sp),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFFFFD700),
                inactiveTrackColor: Colors.white.withOpacity(0.2),
                thumbColor: const Color(0xFFFFD700),
                overlayColor: const Color(0xFFFFD700).withOpacity(0.2),
                trackHeight: 6.h,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10.r),
              ),
              child: Slider(
                value: _volume,
                min: 0.0,
                max: 1.0,
                onChanged: (value) async {
                  setState(() => _volume = value);
                  await _azanService.setAzanVolume(value);
                },
              ),
            ),
          ),
          Icon(Icons.volume_up_rounded, color: Colors.white54, size: 20.sp),
          SizedBox(width: 8.w),
          Text(
            '${(_volume * 100).toInt()}%',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerToggles() {
    final prayerIcons = {
      'الفجر': Icons.nightlight_round,
      'الظهر': Icons.wb_sunny_rounded,
      'العصر': Icons.sunny_snowing,
      'المغرب': Icons.wb_twilight_rounded,
      'العشاء': Icons.stars_rounded,
    };

    return _buildSection(
      title: 'تخصيص الأذان لكل صلاة',
      icon: Icons.tune_rounded,
      child: Column(
        children: _prayerAzanEnabled.entries.map((entry) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Row(
              children: [
                Icon(
                  prayerIcons[entry.key],
                  color: entry.value ? const Color(0xFFFFD700) : Colors.white54,
                  size: 22.sp,
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                    ),
                  ),
                ),
                Switch(
                  value: entry.value,
                  onChanged: (value) async {
                    HapticFeedback.selectionClick();
                    await _azanService.setAzanEnabledForPrayer(entry.key, value);
                    setState(() => _prayerAzanEnabled[entry.key] = value);
                  },
                  activeColor: const Color(0xFFFFD700),
                  activeTrackColor: const Color(0xFFFFD700).withOpacity(0.3),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTestSection() {
    return _buildSection(
      title: 'اختبار الأذان',
      icon: Icons.play_arrow_rounded,
      child: Row(
        children: [
          Expanded(
            child: _buildTestButton(
              label: 'أذان الفجر',
              icon: Icons.nightlight_round,
              onTap: () async {
                HapticFeedback.lightImpact();
                setState(() => _isPlaying = true);
                await _azanService.playAzan(prayerName: 'الفجر', isFajr: true);
                _showSnackBar('جاري تشغيل أذان الفجر...');
              },
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildTestButton(
              label: 'الأذان العادي',
              icon: Icons.wb_sunny_rounded,
              onTap: () async {
                HapticFeedback.lightImpact();
                setState(() => _isPlaying = true);
                await _azanService.playAzan(prayerName: 'الظهر', isFajr: false);
                _showSnackBar('جاري تشغيل الأذان...');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF1B5E20), size: 20.sp),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF1B5E20),
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12.h, right: 4.w),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFFFD700), size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: child,
        ),
      ],
    );
  }

  @override
  void dispose() {
    if (_isPlaying) {
      _azanService.stopAzan();
    }
    super.dispose();
  }
}

