import 'package:audio_service/audio_service.dart';
import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/notification_router.dart';
import 'package:azkroh_app/features/core/services/media_handler.dart';
import 'package:azkroh_app/features/presentation/screens/all_screen/radio_screen.dart';
import 'package:azkroh_app/features/presentation/screens/listen/listen_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Floating "now playing" bubble shown over every screen while the radio or a
/// recitation is playing, so it can be paused / stopped / opened from
/// anywhere. Screens that already show their own player suppress it.
class NowPlayingBubble extends StatefulWidget {
  const NowPlayingBubble({super.key});

  /// > 0 while a screen with its own player is visible.
  static final ValueNotifier<int> suppress = ValueNotifier(0);

  @override
  State<NowPlayingBubble> createState() => _NowPlayingBubbleState();
}

class _NowPlayingBubbleState extends State<NowPlayingBubble> {
  final _media = MediaHandler.instance;
  bool _expanded = false;

  /// Extra distance from the default position, set by dragging the bubble.
  double _lift = 0;

  void _open() {
    setState(() => _expanded = false);
    final nav = NotificationRouter.navigatorKey.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute(
      builder: (_) => _media.mode == MediaMode.radio
          ? const RadioScreen()
          : const ListenScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NowPlayingBubble.suppress,
      builder: (_, suppressed, __) => StreamBuilder<MediaItem?>(
        stream: _media.mediaItem,
        builder: (_, itemSnap) => StreamBuilder<PlaybackState>(
          stream: _media.playbackState,
          builder: (context, stateSnap) {
            final item = itemSnap.data;
            if (suppressed > 0 ||
                item == null ||
                _media.mode == MediaMode.none) {
              return const SizedBox.shrink();
            }
            final st = stateSnap.data;
            final playing = st?.playing ?? false;
            final loading =
                st?.processingState == AudioProcessingState.loading ||
                    st?.processingState == AudioProcessingState.buffering;
            final mq = MediaQuery.of(context);
            final maxLift =
                mq.size.height - mq.padding.top - mq.padding.bottom - 96 - 120;
            final bottom = mq.padding.bottom + 96 + _lift.clamp(-60.0, maxLift);
            return PositionedDirectional(
              end: 12,
              bottom: bottom,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: _expanded
                    ? _card(context, item, playing, loading)
                    : _bubble(playing),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _bubble(bool playing) {
    return GestureDetector(
      key: const ValueKey('bubble'),
      // Drag up/down so it never hides content.
      onVerticalDragUpdate: (d) => setState(() => _lift -= d.delta.dy),
      child: Material(
        color: AppStyle.primaryGreen,
        shape: const CircleBorder(
            side: BorderSide(color: AppStyle.goldColor, width: 2)),
        elevation: 6,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _expanded = true);
          },
          child: SizedBox.square(
            dimension: 54,
            child: Icon(
                playing ? Icons.graphic_eq_rounded : Icons.pause_rounded,
                color: AppStyle.goldColor,
                size: 28),
          ),
        ),
      ),
    );
  }

  Widget _card(
      BuildContext context, MediaItem item, bool playing, bool loading) {
    final w = MediaQuery.sizeOf(context).width;
    return Material(
      key: const ValueKey('card'),
      elevation: 8,
      borderRadius: BorderRadius.circular(22),
      color: const Color(0xFF0B3D33),
      child: Container(
        width: (w - 24).clamp(0.0, 360.0),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 4, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppStyle.goldColor.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _open,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5)),
                    Text(item.artist ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12)),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_full_rounded,
                  color: Colors.white70, size: 20),
              onPressed: _open,
            ),
            IconButton(
              iconSize: 36,
              icon: Icon(
                  playing
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  color: AppStyle.goldColor),
              onPressed: loading
                  ? null
                  : () => playing ? _media.pause() : _media.play(),
            ),
            IconButton(
              icon:
                  const Icon(Icons.stop_circle_outlined, color: Colors.white70),
              onPressed: () {
                _media.stop();
                setState(() => _expanded = false);
              },
            ),
            IconButton(
              icon: const Icon(Icons.close_fullscreen_rounded,
                  color: Colors.white54, size: 18),
              onPressed: () => setState(() => _expanded = false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mixin for screens that show their own player: hides the bubble while
/// they are on screen.
mixin SuppressNowPlayingBubble<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    NowPlayingBubble.suppress.value++;
  }

  @override
  void dispose() {
    NowPlayingBubble.suppress.value--;
    super.dispose();
  }
}
