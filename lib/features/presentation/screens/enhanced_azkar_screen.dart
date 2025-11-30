import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/doaa_model.dart';
import 'package:azkroh_app/features/core/services/azkar_state_service.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:azkroh_app/features/presentation/cubit/states.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';

class EnhancedAzkarScreen extends StatefulWidget {
  const EnhancedAzkarScreen({
    super.key,
    required this.pageTitle,
    required this.listOfDoaaModel,
    required this.azkarType,
  });

  final String pageTitle;
  final List<DoaaModel> listOfDoaaModel;
  final String azkarType;

  @override
  State<EnhancedAzkarScreen> createState() => _EnhancedAzkarScreenState();
}

class _EnhancedAzkarScreenState extends State<EnhancedAzkarScreen>
    with TickerProviderStateMixin {
  final AzkarStateService _stateService = AzkarStateService();
  late List<int> _counts;
  late List<bool> _completed;
  bool _isLoading = true;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  int _totalRepeatCount = 0;
  int _completedCount = 0;

  @override
  void initState() {
    super.initState();
    _counts = List.generate(
        widget.listOfDoaaModel.length, (i) => widget.listOfDoaaModel[i].repeatTime);
    _completed = List.generate(widget.listOfDoaaModel.length, (_) => false);
    
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
    );
    
    _loadSavedState();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedState() async {
    _totalRepeatCount = widget.listOfDoaaModel.fold(0, (sum, item) => sum + item.repeatTime);
    
    if (widget.azkarType == 'morning' || widget.azkarType == 'evening') {
      final savedCounts = await _stateService.loadAzkarCounts(azkarType: widget.azkarType);
      
      if (savedCounts != null) {
        setState(() {
          for (int i = 0; i < widget.listOfDoaaModel.length; i++) {
            final id = widget.listOfDoaaModel[i].id ?? i.toString();
            if (savedCounts.containsKey(id)) {
              _counts[i] = savedCounts[id]!;
              _completed[i] = _counts[i] == 0;
            }
          }
          _updateProgress();
        });
      }
    }
    
    setState(() {
      _isLoading = false;
    });
    _updateProgress();
  }

  Future<void> _saveState() async {
    if (widget.azkarType == 'morning' || widget.azkarType == 'evening') {
      final countsMap = <String, int>{};
      for (int i = 0; i < widget.listOfDoaaModel.length; i++) {
        final id = widget.listOfDoaaModel[i].id ?? i.toString();
        countsMap[id] = _counts[i];
      }
      await _stateService.saveAzkarCounts(
        azkarType: widget.azkarType,
        counts: countsMap,
      );
    }
  }

  void _decrementCount(int index) {
    if (_counts[index] > 0) {
      HapticFeedback.lightImpact();
      setState(() {
        _counts[index]--;
        if (_counts[index] == 0) {
          _completed[index] = true;
          HapticFeedback.mediumImpact();
        }
        _updateProgress();
      });
      // Save state immediately and ensure it persists
      _saveState().then((_) {
        debugPrint('✅ Azkar state saved for index $index');
      }).catchError((e) {
        debugPrint('❌ Error saving Azkar state: $e');
      });
      
      if (_completed.every((c) => c)) {
        _showCompletionDialog();
      }
    }
  }

  void _updateProgress() {
    final remaining = _counts.fold(0, (sum, count) => sum + count);
    _completedCount = _totalRepeatCount - remaining;
    final progress = _totalRepeatCount > 0 
        ? _completedCount / _totalRepeatCount 
        : 0.0;
    
    _progressAnimation = Tween<double>(
      begin: _progressAnimation.value,
      end: progress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOut,
    ));
    _progressController.forward(from: 0);
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppStyle.primaryGreen, size: 32.sp),
            SizedBox(width: 12.w),
            Text(
              'بارك الله فيك!',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 22.sp,
                color: AppStyle.primaryGreen,
              ),
            ),
          ],
        ),
        content: Text(
          'أتممت أذكارك، جعلها الله في ميزان حسناتك.',
          style: TextStyle(fontFamily: 'Amiri', fontSize: 16.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'آمين',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 18.sp,
                color: AppStyle.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
    
    if (widget.azkarType == 'morning' || widget.azkarType == 'evening') {
      _stateService.markAzkarCompleted(azkarType: widget.azkarType);
    }
  }

  void _resetAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          'إعادة التعداد؟',
          style: TextStyle(fontFamily: 'Amiri', fontSize: 20.sp),
        ),
        content: Text(
          'سيتم إعادة جميع العدادات إلى القيم الأصلية.',
          style: TextStyle(fontFamily: 'Amiri', fontSize: 16.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: TextStyle(fontFamily: 'Amiri', fontSize: 14.sp, color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                for (int i = 0; i < widget.listOfDoaaModel.length; i++) {
                  _counts[i] = widget.listOfDoaaModel[i].repeatTime;
                  _completed[i] = false;
                }
                _updateProgress();
              });
              _saveState();
            },
            child: Text(
              'إعادة',
              style: TextStyle(fontFamily: 'Amiri', fontSize: 14.sp, color: AppStyle.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppCubit, Appstates>(
      builder: (context, state) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: AppStyle.softGray,
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    slivers: [
                      _buildAppBar(),
                      _buildProgressSection(),
                      _buildRemainingTimeSection(),
                      _buildAzkarList(),
                    ],
                  ),
          ),
        );
      },
      listener: (context, state) {},
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140.h,
      floating: false,
      pinned: true,
      backgroundColor: AppStyle.primaryGreen,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, size: 24.sp),
          onPressed: _resetAll,
          tooltip: 'إعادة التعداد',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          widget.pageTitle,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
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
                  child: Icon(
                    widget.azkarType == 'morning'
                        ? Icons.wb_sunny_rounded
                        : widget.azkarType == 'evening'
                            ? Icons.nightlight_round
                            : Icons.auto_awesome_rounded,
                    size: 200.sp,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.all(16.r),
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: AppStyle.primaryGreen.withOpacity(0.1),
              blurRadius: 15.r,
              offset: Offset(0, 5.h),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'التقدم',
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppStyle.textDark,
                  ),
                ),
                Text(
                  '$_completedCount / $_totalRepeatCount',
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 16.sp,
                    color: AppStyle.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Stack(
                  children: [
                    Container(
                      height: 12.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: _progressAnimation.value.clamp(0.0, 1.0),
                      child: Container(
                        height: 12.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppStyle.primaryGreen,
                              AppStyle.lightGreen,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6.r),
                          boxShadow: [
                            BoxShadow(
                              color: AppStyle.primaryGreen.withOpacity(0.3),
                              blurRadius: 8.r,
                              offset: Offset(0, 2.h),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatItem(
                  '${_completed.where((c) => c).length}',
                  'مكتمل',
                  Icons.check_circle_outline,
                  AppStyle.primaryGreen,
                ),
                SizedBox(width: 32.w),
                _buildStatItem(
                  '${_completed.where((c) => !c).length}',
                  'متبقي',
                  Icons.pending_outlined,
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20.sp),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppStyle.textLight,
                fontFamily: 'Amiri',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRemainingTimeSection() {
    if (widget.azkarType != 'morning' && widget.azkarType != 'evening') {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final remaining = _stateService.getRemainingTimeForPeriod();
    if (remaining == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;

    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: widget.azkarType == 'morning'
              ? Colors.orange.withOpacity(0.1)
              : Colors.indigo.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: widget.azkarType == 'morning'
                ? Colors.orange.withOpacity(0.3)
                : Colors.indigo.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.timer_outlined,
              color: widget.azkarType == 'morning' ? Colors.orange : Colors.indigo,
              size: 24.sp,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'الوقت المتبقي: ${hours > 0 ? '$hours ساعة و ' : ''}$minutes دقيقة',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 14.sp,
                  color: widget.azkarType == 'morning' ? Colors.orange[800] : Colors.indigo[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAzkarList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildAzkarCard(index),
        childCount: widget.listOfDoaaModel.length,
      ),
    );
  }

  Widget _buildAzkarCard(int index) {
    final doaa = widget.listOfDoaaModel[index];
    final isCompleted = _completed[index];
    final count = _counts[index];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isCompleted ? AppStyle.primaryGreen.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: isCompleted
            ? Border.all(color: AppStyle.primaryGreen.withOpacity(0.5), width: 2.w)
            : null,
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
          borderRadius: BorderRadius.circular(20.r),
          onTap: () => _decrementCount(index),
          child: Padding(
            padding: EdgeInsets.all(20.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  doaa.content ?? '',
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 20.sp,
                    height: 1.8,
                    color: isCompleted ? AppStyle.primaryGreen : AppStyle.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                if (doaa.desc != null && doaa.desc!.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: AppStyle.goldColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      doaa.desc!,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 14.sp,
                        color: AppStyle.darkGold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                
                SizedBox(height: 16.h),
                const Divider(),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => _decrementCount(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          gradient: isCompleted
                              ? LinearGradient(
                                  colors: [AppStyle.primaryGreen, AppStyle.darkGreen])
                              : LinearGradient(
                                  colors: [AppStyle.goldColor, AppStyle.darkGold]),
                          borderRadius: BorderRadius.circular(25.r),
                          boxShadow: [
                            BoxShadow(
                              color: (isCompleted
                                      ? AppStyle.primaryGreen
                                      : AppStyle.goldColor)
                                  .withOpacity(0.3),
                              blurRadius: 8.r,
                              offset: Offset(0, 2.h),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCompleted
                                  ? Icons.check_rounded
                                  : Icons.touch_app_rounded,
                              color: Colors.white,
                              size: 20.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              isCompleted ? 'تم' : 'التكرار: $count',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Amiri',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.copy_rounded, size: 22.sp),
                          color: Colors.grey[600],
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: doaa.content ?? ''));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم النسخ', style: TextStyle(fontSize: 14.sp)),
                                backgroundColor: AppStyle.primaryGreen,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          tooltip: 'نسخ',
                        ),
                        IconButton(
                          icon: Icon(Icons.share_rounded, size: 22.sp),
                          color: Colors.grey[600],
                          onPressed: () async {
                            try {
                              await Share.share(
                                '${doaa.content ?? ''}\n\n${doaa.desc ?? ''}\n\nمن تطبيق أذكروه',
                                subject: 'ذكر من تطبيق أذكروه',
                              );
                              debugPrint('تمت المشاركة بنجاح');
                            } catch (e) {
                              debugPrint('خطأ في المشاركة: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('حدث خطأ أثناء المشاركة', style: TextStyle(fontSize: 14.sp)),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                          tooltip: 'مشاركة',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
