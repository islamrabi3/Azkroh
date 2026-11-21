import 'dart:io';

import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/presentation/screens/professional_splash_screen.dart'
    show IslamicStarPainter;
import 'package:azkroh_app/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wallet number for donations (Egyptian mobile wallet).
const String kSupportWallet = '01554860861';

/// Shown on iOS too at the owner's request. Note: Apple guideline 3.1.1
/// restricts asking for money outside In-App Purchase, so App Review may
/// reject a build that shows it; set to false to hide it on iOS.
const bool kShowSupportOnIos = true;

bool get showSupportCard => !Platform.isIOS || kShowSupportOnIos;

/// "Support us" card shown on the home screen.
class SupportCard extends StatelessWidget {
  const SupportCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => showSupportSheet(context),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [Color(0xFFD4AF37), Color(0xFFA8842C)],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.volunteer_activism_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('ادعم أذكروه'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(tr('ساهم في استمرار التطبيق وتطويره، صدقة جارية لك'),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showSupportSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SupportSheet(),
  );
}

class _SupportSheet extends StatelessWidget {
  const _SupportSheet();

  String get _pretty =>
      '${kSupportWallet.substring(0, 4)} ${kSupportWallet.substring(4, 7)} ${kSupportWallet.substring(7)}';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocale.direction,
      child: Container(
        decoration: const BoxDecoration(
          color: AppStyle.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0F5C4A), Color(0xFF0B3D33)],
                  ),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: -30,
                      child: Opacity(
                        opacity: 0.08,
                        child: CustomPaint(
                          size: const Size.square(220),
                          painter: const IslamicStarPainter(
                              color: Colors.white, stroke: true),
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white38,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            color: AppStyle.goldColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.volunteer_activism_rounded,
                              color: Color(0xFF0B3D33), size: 36),
                        ),
                        const SizedBox(height: 14),
                        Text(tr('ادعم أذكروه'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                          tr('أذكروه تطبيق مجاني بلا إعلانات. دعمك يساعدنا على تطوير مزايا جديدة وتغطية تكاليف الخوادم والمحتوى.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              height: 1.6,
                              fontSize: 13.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  children: [
                    // Hadith on continuous charity
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBF1),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: AppStyle.goldColor.withOpacity(0.4)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '«مَنْ دَلَّ عَلَى خَيْرٍ فَلَهُ مِثْلُ أَجْرِ فَاعِلِهِ»',
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 19,
                                height: 1.8,
                                color: AppStyle.darkGreen),
                          ),
                          Text(tr('رواه مسلم'),
                              style: const TextStyle(
                                  color: AppStyle.textLight, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Wallet
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppStyle.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined,
                                  color: AppStyle.primaryGreen),
                              const SizedBox(width: 8),
                              Text(tr('رقم المحفظة الإلكترونية'),
                                  style: const TextStyle(
                                      color: AppStyle.textLight,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: SelectableText(
                              _pretty,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: AppStyle.darkGreen,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(tr('يمكنك التحويل من أي محفظة أو عبر إنستاباي'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppStyle.textLight, fontSize: 12.5)),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppStyle.primaryGreen,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () {
                                Clipboard.setData(
                                    const ClipboardData(text: kSupportWallet));
                                HapticFeedback.mediumImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(tr('تم نسخ الرقم'))));
                              },
                              icon: const Icon(Icons.copy_rounded),
                              label: Text(tr('نسخ الرقم')),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr('جزاكم الله خيراً وجعله في ميزان حسناتكم 🤍'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppStyle.darkGold,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
