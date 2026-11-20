import 'package:azkroh_app/features/core/widgets/app_loader.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A dhikr from the authentic Sunnah with its recommended count.
class Dhikr {
  final String id;
  final String text;
  final int target; // recommended count (0 = not specified, default 33)
  final String virtue;
  final String source;

  const Dhikr(this.id, this.text, this.target, this.virtue, this.source);
}

/// Authentic adhkar (counts and sources from the hadith).
const List<Dhikr> kAdhkar = [
  Dhikr('subhan_wa_bihamdih', 'سُبْحَانَ اللهِ وَبِحَمْدِهِ', 100,
      'مَنْ قَالَ: سُبْحَانَ اللهِ وَبِحَمْدِهِ فِي يَوْمٍ مِائَةَ مَرَّةٍ حُطَّتْ خَطَايَاهُ وَإِنْ كَانَتْ مِثْلَ زَبَدِ الْبَحْرِ',
      'متفق عليه'),
  Dhikr(
      'tahleel_100',
      'لَا إِلَهَ إِلَّا اللهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
      100,
      'كَانَتْ لَهُ عَدْلَ عَشْرِ رِقَابٍ، وَكُتِبَتْ لَهُ مِائَةُ حَسَنَةٍ، وَمُحِيَتْ عَنْهُ مِائَةُ سَيِّئَةٍ، وَكَانَتْ لَهُ حِرْزًا مِنَ الشَّيْطَانِ يَوْمَهُ ذَلِكَ حَتَّى يُمْسِيَ',
      'متفق عليه'),
  Dhikr('istighfar', 'أَسْتَغْفِرُ اللهَ وَأَتُوبُ إِلَيْهِ', 100,
      'يَا أَيُّهَا النَّاسُ تُوبُوا إِلَى اللهِ، فَإِنِّي أَتُوبُ فِي الْيَوْمِ إِلَيْهِ مِائَةَ مَرَّةٍ',
      'رواه مسلم'),
  Dhikr('subhanallah', 'سُبْحَانَ اللهِ', 33,
      'تُسَبِّحَانِ ثَلَاثًا وَثَلَاثِينَ، وَتَحْمَدَانِ ثَلَاثًا وَثَلَاثِينَ، وَتُكَبِّرَانِ أَرْبَعًا وَثَلَاثِينَ، فَهُوَ خَيْرٌ لَكُمَا مِنْ خَادِمٍ',
      'متفق عليه'),
  Dhikr('alhamdulillah', 'الْحَمْدُ لِلَّهِ', 33,
      'الطُّهُورُ شَطْرُ الْإِيمَانِ، وَالْحَمْدُ لِلَّهِ تَمْلَأُ الْمِيزَانَ',
      'رواه مسلم'),
  Dhikr('allahuakbar', 'اللهُ أَكْبَرُ', 34,
      'وَتُكَبِّرَانِ أَرْبَعًا وَثَلَاثِينَ (عند النوم)، وتمام المائة بعد الصلاة',
      'متفق عليه'),
  Dhikr('kalimatan', 'سُبْحَانَ اللهِ وَبِحَمْدِهِ، سُبْحَانَ اللهِ الْعَظِيمِ', 0,
      'كَلِمَتَانِ خَفِيفَتَانِ عَلَى اللِّسَانِ، ثَقِيلَتَانِ فِي الْمِيزَانِ، حَبِيبَتَانِ إِلَى الرَّحْمَنِ',
      'متفق عليه'),
  Dhikr('baqiyat', 'سُبْحَانَ اللهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا اللهُ، وَاللهُ أَكْبَرُ', 0,
      'أَحَبُّ الْكَلَامِ إِلَى اللهِ أَرْبَعٌ… لَا يَضُرُّكَ بِأَيِّهِنَّ بَدَأْتَ',
      'رواه مسلم'),
  Dhikr('hawqala', 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللهِ', 0,
      'كَنْزٌ مِنْ كُنُوزِ الْجَنَّةِ', 'متفق عليه'),
  Dhikr('salah_nabi', 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ', 10,
      'مَنْ صَلَّى عَلَيَّ وَاحِدَةً صَلَّى اللهُ عَلَيْهِ عَشْرًا', 'رواه مسلم'),
  Dhikr(
      'adad_khalqih',
      'سُبْحَانَ اللهِ وَبِحَمْدِهِ، عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ',
      3,
      'لَقَدْ قُلْتُ بَعْدَكِ أَرْبَعَ كَلِمَاتٍ ثَلَاثَ مَرَّاتٍ، لَوْ وُزِنَتْ بِمَا قُلْتِ مُنْذُ الْيَوْمِ لَوَزَنَتْهُنَّ',
      'رواه مسلم'),
  Dhikr('tahleel', 'لَا إِلَهَ إِلَّا اللهُ', 100,
      'أَفْضَلُ الذِّكْرِ لَا إِلَهَ إِلَّا اللهُ', 'رواه الترمذي وحسّنه'),
  Dhikr('dhun_nun', 'لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ', 0,
      'دَعْوَةُ ذِي النُّونِ… لَمْ يَدْعُ بِهَا رَجُلٌ مُسْلِمٌ فِي شَيْءٍ قَطُّ إِلَّا اسْتَجَابَ اللهُ لَهُ',
      'رواه الترمذي وصححه الألباني'),
  Dhikr('subhan_malik', 'سُبْحَانَ الْمَلِكِ الْقُدُّوسِ', 3,
      'كان النبي ﷺ يقولها بعد الوتر ثلاث مرات، يرفع صوته بالثالثة',
      'رواه النسائي وصححه الألباني'),
];

/// Tasbih counter with the adhkar of the Sunnah.
class Sebha extends StatefulWidget {
  const Sebha({super.key});

  @override
  State<Sebha> createState() => _SebhaState();
}

class _SebhaState extends State<Sebha> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 140));

  int _index = 0;
  int _count = 0;
  final Map<String, int> _targets = {};
  final Map<String, int> _today = {};
  final Map<String, int> _total = {};
  bool _loaded = false;

  Dhikr get _d => kAdhkar[_index];
  int get _target => _targets[_d.id] ?? (_d.target == 0 ? 33 : _d.target);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _save();
    super.dispose();
  }

  String get _todayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _index = (prefs.getInt('sebha_index') ?? 0).clamp(0, kAdhkar.length - 1);
    _targets.addAll(Map<String, int>.from(
        jsonDecode(prefs.getString('sebha_targets') ?? '{}') as Map));
    _total.addAll(Map<String, int>.from(
        jsonDecode(prefs.getString('sebha_total') ?? '{}') as Map));
    final day = jsonDecode(prefs.getString('sebha_today') ?? '{}') as Map;
    if (day['date'] == _todayKey) {
      _today.addAll(Map<String, int>.from(day['counts'] as Map));
    }
    _count = 0;
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sebha_index', _index);
    await prefs.setString('sebha_targets', jsonEncode(_targets));
    await prefs.setString('sebha_total', jsonEncode(_total));
    await prefs.setString(
        'sebha_today', jsonEncode({'date': _todayKey, 'counts': _today}));
  }

  void _tap() {
    setState(() {
      _count++;
      _today[_d.id] = (_today[_d.id] ?? 0) + 1;
      _total[_d.id] = (_total[_d.id] ?? 0) + 1;
    });
    _pulse.forward(from: 0);
    if (_count == _target) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(
                '${tr('أتممت العدد المسنون')} (${AppLocale.digits(_target)}) • ${tr('يمكنك الزيادة')}')));
    } else {
      HapticFeedback.selectionClick();
    }
    if (_count % 10 == 0) _save();
  }

  void _reset() {
    HapticFeedback.mediumImpact();
    setState(() => _count = 0);
  }

  void _select(int i) {
    setState(() {
      _index = i;
      _count = 0;
    });
    _save();
  }

  Future<void> _editTarget() async {
    int value = _target;
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppStyle.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Directionality(
          textDirection: AppLocale.direction,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr('عدد مرات الذكر'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                if (_d.target > 0)
                  Text(
                      '${tr('المسنون')}: ${AppLocale.digits(_d.target)}',
                      style: const TextStyle(color: AppStyle.textLight)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      onPressed: value > 1
                          ? () => setS(() => value = math.max(1, value - 1))
                          : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(AppLocale.digits(value),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 34, fontWeight: FontWeight.w700)),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => setS(() => value++),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [33, 100, 300, 500, 1000]
                      .map((v) => ChoiceChip(
                            label: Text(AppLocale.digits(v)),
                            selected: value == v,
                            showCheckmark: false,
                            selectedColor: AppStyle.primaryGreen,
                            labelStyle: TextStyle(
                                color: value == v
                                    ? Colors.white
                                    : AppStyle.textDark),
                            onSelected: (_) => setS(() => value = v),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppStyle.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 13)),
                    onPressed: () => Navigator.pop(ctx, value),
                    child: Text(tr('حفظ')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null) {
      setState(() => _targets[_d.id] = result);
      _save();
    }
  }

  void _openList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppStyle.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Directionality(
        textDirection: AppLocale.direction,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          builder: (ctx, scroll) => ListView.separated(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            itemCount: kAdhkar.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = kAdhkar[i];
              final sel = i == _index;
              final t = _targets[d.id] ?? (d.target == 0 ? 33 : d.target);
              final done = _today[d.id] ?? 0;
              return Material(
                color: sel ? const Color(0xFFE7F2EE) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.pop(ctx);
                    _select(i);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(d.text,
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(
                                      fontFamily: 'Amiri',
                                      fontSize: 18,
                                      height: 1.7,
                                      color: AppStyle.textDark)),
                              const SizedBox(height: 4),
                              Text(
                                  '${tr('اليوم')}: ${AppLocale.digits(done)} / ${AppLocale.digits(t)} • ${tr(d.source)}',
                                  style: const TextStyle(
                                      color: AppStyle.textLight,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(
                            value: (done / t).clamp(0.0, 1.0),
                            strokeWidth: 4,
                            color: AppStyle.goldColor,
                            backgroundColor: AppStyle.border,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_count / _target).clamp(0.0, 1.0);
    final done = _count >= _target;
    return Directionality(
      textDirection: AppLocale.direction,
      child: Scaffold(
        backgroundColor: AppStyle.background,
        appBar: AppBar(
          backgroundColor: AppStyle.primaryGreen,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Text(tr('السبحة'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              tooltip: tr('الأذكار'),
              icon: const Icon(Icons.format_list_bulleted_rounded),
              onPressed: _openList,
            ),
          ],
        ),
        body: !_loaded
            ? const Center(
                child: AppLoader(color: AppStyle.primaryGreen))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // Dhikr card
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: _openList,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppStyle.border),
                        ),
                        child: Column(
                          children: [
                            Text(_d.text,
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                    fontFamily: 'Amiri',
                                    fontSize: 24,
                                    height: 1.8,
                                    color: AppStyle.darkGreen)),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBF1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  Text('«${_d.virtue}»',
                                      textAlign: TextAlign.center,
                                      textDirection: TextDirection.rtl,
                                      style: const TextStyle(
                                          fontFamily: 'Amiri',
                                          fontSize: 15,
                                          height: 1.8,
                                          color: AppStyle.textDark)),
                                  const SizedBox(height: 2),
                                  Text(tr(_d.source),
                                      style: const TextStyle(
                                          color: AppStyle.darkGold,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.swap_horiz_rounded,
                                    size: 18, color: AppStyle.primaryGreen),
                                const SizedBox(width: 4),
                                Text(tr('اختر ذكراً آخر'),
                                    style: const TextStyle(
                                        color: AppStyle.primaryGreen,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Counter
                  Center(
                    child: GestureDetector(
                      onTap: _tap,
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, child) => Transform.scale(
                          scale: 1 - 0.04 * math.sin(_pulse.value * math.pi),
                          child: child,
                        ),
                        child: SizedBox.square(
                          dimension: 250,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.square(
                                dimension: 250,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 10,
                                  strokeCap: StrokeCap.round,
                                  color: done
                                      ? AppStyle.goldColor
                                      : AppStyle.primaryGreen,
                                  backgroundColor: AppStyle.border,
                                ),
                              ),
                              Container(
                                width: 214,
                                height: 214,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF0F5C4A),
                                      Color(0xFF0B3D33)
                                    ],
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(AppLocale.digits(_count),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 64,
                                            fontWeight: FontWeight.w700,
                                            height: 1.1)),
                                    Text(
                                        '${tr('من')} ${AppLocale.digits(_target)}',
                                        style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.7),
                                            fontSize: 15)),
                                    if (done)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 6),
                                        child: Icon(Icons.check_circle_rounded,
                                            color: AppStyle.goldColor),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(tr('اضغط على الدائرة للتسبيح'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppStyle.textLight)),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _action(Icons.restart_alt_rounded,
                            tr('تصفير'), _reset),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _action(Icons.tune_rounded,
                            tr('تعديل العدد'), _editTarget),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppStyle.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                            child: _stat(tr('اليوم'), _today[_d.id] ?? 0)),
                        Container(
                            width: 1, height: 36, color: AppStyle.border),
                        Expanded(
                            child: _stat(
                                tr('الإجمالي'), _total[_d.id] ?? 0)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppStyle.primaryGreen,
        side: const BorderSide(color: AppStyle.primaryGreen),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Widget _stat(String label, int v) => Column(
        children: [
          Text(AppLocale.digits(v),
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppStyle.darkGreen)),
          Text(label, style: const TextStyle(color: AppStyle.textLight)),
        ],
      );
}
