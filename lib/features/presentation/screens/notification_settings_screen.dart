import 'dart:io';
import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/notification_service.dart';
import 'package:azkroh_app/features/core/dhikr_notification_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  final DhikrNotificationScheduler _dhikrScheduler =
      DhikrNotificationScheduler();

  bool _prayerNotifications = true;
  bool _morningAzkarNotifications = true;
  bool _eveningAzkarNotifications = true;
  bool _dhikrReminders = true;
  int _dhikrInterval = 2;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSimulator = false;

  @override
  void initState() {
    super.initState();
    _checkIfSimulator();
    _loadSettings();
  }

  void _checkIfSimulator() {
    // Check if running on iOS simulator
    if (Platform.isIOS) {
      // In debug mode on iOS, we're likely on simulator
      _isSimulator = kDebugMode;
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await _notificationService.loadNotificationPreferences();
      setState(() {
        _prayerNotifications = prefs['prayer_notifications'] ?? true;
        _morningAzkarNotifications = prefs['morning_azkar'] ?? true;
        _eveningAzkarNotifications = prefs['evening_azkar'] ?? true;
        _dhikrReminders = prefs['dhikr_reminders'] ?? true;
        _dhikrInterval = prefs['dhikr_interval'] ?? 2;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('خطأ في تحميل الإعدادات', isError: true);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    try {
      await _notificationService.saveNotificationPreferences(
        prayerNotifications: _prayerNotifications,
        dhikrReminders: _dhikrReminders,
        qiblaReminders: false,
        dhikrInterval: _dhikrInterval,
      );

      await _dhikrScheduler.setDhikrRemindersEnabled(_dhikrReminders);
      if (_dhikrReminders) {
        await _dhikrScheduler.updateDhikrInterval(_dhikrInterval);
      }

      _showSnackBar('تم حفظ الإعدادات بنجاح ✓');
    } catch (e) {
      _showSnackBar('خطأ في حفظ الإعدادات', isError: true);
    }

    setState(() => _isSaving = false);
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
              child: Text(
                message,
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : AppStyle.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        margin: EdgeInsets.all(16.r),
        duration: const Duration(seconds: 2),
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
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
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
                              if (_isSimulator) _buildSimulatorWarning(),
                              if (_isSimulator) SizedBox(height: 16.h),
                              _buildHeaderCard(),
                              SizedBox(height: 24.h),
                              _buildSection(
                                title: 'إشعارات الصلاة',
                                icon: Icons.mosque_rounded,
                                children: [
                                  _buildSwitchTile(
                                    title: 'تذكير أوقات الصلاة',
                                    subtitle: 'إشعار عند دخول وقت كل صلاة',
                                    icon: Icons.access_time_rounded,
                                    value: _prayerNotifications,
                                    onChanged: (v) =>
                                        setState(() => _prayerNotifications = v),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
                              _buildSection(
                                title: 'أذكار الصباح والمساء',
                                icon: Icons.wb_sunny_rounded,
                                children: [
                                  _buildSwitchTile(
                                    title: 'تذكير أذكار الصباح',
                                    subtitle: 'إشعار يومي في الصباح الباكر',
                                    icon: Icons.wb_twilight_rounded,
                                    value: _morningAzkarNotifications,
                                    onChanged: (v) => setState(
                                        () => _morningAzkarNotifications = v),
                                  ),
                                  Divider(
                                      color: Colors.white24, height: 1.h),
                                  _buildSwitchTile(
                                    title: 'تذكير أذكار المساء',
                                    subtitle: 'إشعار يومي في المساء',
                                    icon: Icons.nights_stay_rounded,
                                    value: _eveningAzkarNotifications,
                                    onChanged: (v) => setState(
                                        () => _eveningAzkarNotifications = v),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
                              _buildSection(
                                title: 'تذكيرات الذكر',
                                icon: Icons.auto_awesome_rounded,
                                children: [
                                  _buildSwitchTile(
                                    title: 'تذكيرات دورية',
                                    subtitle: 'تذكيرات متكررة للذكر والاستغفار',
                                    icon: Icons.repeat_rounded,
                                    value: _dhikrReminders,
                                    onChanged: (v) =>
                                        setState(() => _dhikrReminders = v),
                                  ),
                                  if (_dhikrReminders) ...[
                                    Divider(
                                        color: Colors.white24, height: 1.h),
                                    _buildIntervalSelector(),
                                  ],
                                ],
                              ),
                              SizedBox(height: 24.h),
                              _buildTestSection(),
                              SizedBox(height: 24.h),
                              _buildSaveButton(),
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
              'إعدادات الإشعارات',
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

  Widget _buildSimulatorWarning() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 28.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تنبيه - المحاكي',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'الإشعارات قد لا تعمل بشكل كامل على iOS Simulator. جرّب على جهاز حقيقي.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
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
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
              ),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: const Color(0xFF1B5E20),
              size: 28.sp,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تخصيص الإشعارات',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'اختر الإشعارات التي تريد استقبالها',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
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
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: value
                  ? const Color(0xFFFFD700).withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              icon,
              color: value ? const Color(0xFFFFD700) : Colors.white54,
              size: 22.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            activeColor: const Color(0xFFFFD700),
            activeTrackColor: const Color(0xFFFFD700).withOpacity(0.3),
            inactiveThumbColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.grey.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalSelector() {
    return Padding(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'فترة التذكير',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
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
                    value: _dhikrInterval.toDouble(),
                    min: 1,
                    max: 6,
                    divisions: 5,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _dhikrInterval = v.round());
                    },
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '$_dhikrInterval ساعة',
                  style: TextStyle(
                    color: const Color(0xFF1B5E20),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_rounded,
                  color: const Color(0xFFFFD700), size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'اختبار الإشعارات',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildTestButton(
                  icon: Icons.notifications_outlined,
                  label: 'إشعار تجريبي',
                  onTap: () async {
                    try {
                      final hasPermission =
                          await _notificationService.areNotificationsEnabled();
                      debugPrint('Permission status: $hasPermission');
                      
                      if (!hasPermission && !_isSimulator) {
                        _showSnackBar(
                            'الرجاء السماح بالإشعارات من إعدادات الجهاز',
                            isError: true);
                        return;
                      }
                      
                      await _notificationService.showImmediateNotification(
                        id: 9999,
                        title: '✨ اختبار الإشعارات',
                        body: 'الإشعارات تعمل بشكل صحيح! الحمد لله',
                        payload: 'test',
                      );
                      
                      if (_isSimulator) {
                        _showSnackBar('تم الإرسال - تحقق من Xcode Console');
                      } else {
                        _showSnackBar('تم إرسال إشعار تجريبي');
                      }
                    } catch (e) {
                      debugPrint('Notification error: $e');
                      if (_isSimulator) {
                        _showSnackBar('الإشعارات محدودة على المحاكي', isError: true);
                      } else {
                        _showSnackBar('خطأ في إرسال الإشعار', isError: true);
                      }
                    }
                  },
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildTestButton(
                  icon: Icons.auto_awesome,
                  label: 'ذكر فوري',
                  onTap: () async {
                    try {
                      await _dhikrScheduler.sendImmediateDhikrNotification();
                      if (_isSimulator) {
                        _showSnackBar('تم الإرسال - تحقق من Xcode Console');
                      } else {
                        _showSnackBar('تم إرسال تذكير بالذكر');
                      }
                    } catch (e) {
                      debugPrint('Dhikr notification error: $e');
                      if (_isSimulator) {
                        _showSnackBar('الإشعارات محدودة على المحاكي', isError: true);
                      } else {
                        _showSnackBar('خطأ في إرسال الذكر', isError: true);
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 18.sp),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _saveSettings,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.3),
              blurRadius: 15.r,
              offset: Offset(0, 8.h),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSaving)
              SizedBox(
                width: 20.w,
                height: 20.w,
                child: const CircularProgressIndicator(
                  color: Color(0xFF1B5E20),
                  strokeWidth: 2,
                ),
              )
            else
              Icon(Icons.save_rounded,
                  color: const Color(0xFF1B5E20), size: 22.sp),
            SizedBox(width: 10.w),
            Text(
              _isSaving ? 'جاري الحفظ...' : 'حفظ الإعدادات',
              style: TextStyle(
                color: const Color(0xFF1B5E20),
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
