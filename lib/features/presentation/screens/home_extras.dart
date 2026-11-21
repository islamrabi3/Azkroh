import 'package:azkroh_app/features/core/services/remote_content_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/services/app_store_service.dart';
import 'package:azkroh_app/features/core/services/radio_service.dart';
import 'package:azkroh_app/features/core/widgets/app_loader.dart';
import 'package:azkroh_app/features/presentation/screens/game/quiz_screens.dart';
import 'package:azkroh_app/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// "Rate Azkroh" card on the home screen. Shown from the 2nd launch until
/// the user rates; "later" hides it for a few days.
class RatingCard extends StatelessWidget {
  const RatingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStoreService();
    return ValueListenableBuilder<bool>(
      valueListenable: store.showRatingCard,
      builder: (_, show, __) {
        if (!show) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppStyle.goldColor.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF3DC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.star_rounded,
                          color: AppStyle.goldColor, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('هل أعجبك أذكروه؟'),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppStyle.textDark)),
                          const SizedBox(height: 2),
                          Text(
                              tr('تقييمك يساعد غيرك على الوصول للتطبيق، والدال على الخير كفاعله'),
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.5,
                                  color: AppStyle.textLight)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: store.snoozeRatingCard,
                      child: Text(tr('لاحقاً'),
                          style: const TextStyle(color: AppStyle.textLight)),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppStyle.primaryGreen,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        store.rateFromCard();
                      },
                      icon: const Icon(Icons.star_rounded, size: 18),
                      label: Text(tr('قيّم التطبيق')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One-tap live Ruqyah stream on the home screen.
class RuqyahLiveCard extends StatefulWidget {
  const RuqyahLiveCard({super.key});

  @override
  State<RuqyahLiveCard> createState() => _RuqyahLiveCardState();
}

class _RuqyahLiveCardState extends State<RuqyahLiveCard> {
  final _radio = RadioService();
  late final Listenable _l =
      Listenable.merge([_radio.current, _radio.playing, _radio.buffering]);

  RadioStation get _station =>
      RadioService.featured.firstWhere((s) => s.name == 'الرقية الشرعية');

  @override
  void initState() {
    super.initState();
    _l.addListener(_changed);
  }

  @override
  void dispose() {
    _l.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final active = _radio.current.value?.name == _station.name;
    final buffering = active && _radio.buffering.value;
    final playing = active && _radio.playing.value && !buffering;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          HapticFeedback.selectionClick();
          active ? _radio.toggle() : _radio.play(_station);
        },
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [Color(0xFF2D4F7A), Color(0xFF1B3352)],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                    playing
                        ? Icons.graphic_eq_rounded
                        : Icons.health_and_safety_rounded,
                    color: AppStyle.goldColor,
                    size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(tr('الرقية الشرعية'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(tr('مباشر'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                        active
                            ? (buffering
                                ? tr('جاري الاتصال...')
                                : playing
                                    ? tr('بث مباشر')
                                    : tr('متوقف مؤقتاً'))
                            : tr('بث مباشر على مدار الساعة، اضغط للاستماع'),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12.5)),
                  ],
                ),
              ),
              if (buffering)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: AppLoader(size: 28, color: AppStyle.goldColor),
                )
              else
                Icon(
                    playing
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: AppStyle.goldColor,
                    size: 44),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entry card for the multiplayer quiz.
class QuizEntryCard extends StatelessWidget {
  const QuizEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const QuizHomeScreen()));
          },
          child: Ink(
            padding: const EdgeInsets.all(14),
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
                  child: const Icon(Icons.emoji_events_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('مسابقة أذكروه'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(tr('العب مع أصدقائك برقم الغرفة'),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.92),
                              fontSize: 12.5)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Videos, links and learning material published from the dashboard.
class RemoteContentStrip extends StatelessWidget {
  const RemoteContentStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<RemoteItem>>(
      valueListenable: RemoteContentService.instance.items,
      builder: (_, items, __) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_outline_rounded,
                      color: AppStyle.goldColor, size: 22),
                  const SizedBox(width: 6),
                  Text(tr('مختارات لك'),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppStyle.textDark)),
                ],
              ),
            ),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _RemoteCard(item: items[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RemoteCard extends StatelessWidget {
  final RemoteItem item;

  const _RemoteCard({required this.item});

  IconData get _icon {
    switch (item.kind) {
      case 'video':
      case 'playlist':
        return Icons.play_circle_fill_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'audio':
        return Icons.headphones_rounded;
      case 'article':
        return Icons.article_rounded;
      default:
        return Icons.link_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => launchUrl(Uri.parse(item.url),
              mode: LaunchMode.externalApplication),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 118,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.thumbnail != null)
                      Image.network(item.thumbnail!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: const Color(0xFFE7F2EE)))
                    else
                      Container(color: const Color(0xFFE7F2EE)),
                    Center(
                      child: Icon(_icon,
                          size: 42,
                          color: item.thumbnail != null
                              ? Colors.white
                              : AppStyle.primaryGreen),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Text(item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        height: 1.4,
                        color: AppStyle.textDark)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
