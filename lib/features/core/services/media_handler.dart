import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Who currently owns the shared media player.
enum MediaMode { none, listen, radio }

/// Callbacks a feature registers to receive lock-screen / notification
/// commands while it owns the player.
class MediaControls {
  final Future<void> Function() play;
  final Future<void> Function() pause;
  final Future<void> Function() stop;
  final Future<void> Function()? next;
  final Future<void> Function()? previous;
  final bool seekable;

  /// Called when another feature takes the player away from this owner.
  final VoidCallback? onYield;

  const MediaControls({
    required this.play,
    required this.pause,
    required this.stop,
    this.next,
    this.previous,
    this.seekable = false,
    this.onYield,
  });
}

/// Single long-form player shared by the Listen section and the radio, exposed
/// to the OS media session (lock screen, Control Center, Android media
/// notification, headphones, car).
class MediaHandler extends BaseAudioHandler with SeekHandler {
  MediaHandler._() {
    player.playbackEventStream.listen(
      (_) => _broadcast(),
      onError: (Object e, StackTrace st) => _broadcast(),
    );
    player.playingStream.listen((_) => _broadcast());
  }

  static MediaHandler? _instance;

  /// Always available; falls back to a handler that is not registered with
  /// the OS if [init] failed or has not run yet.
  static MediaHandler get instance => _instance ??= MediaHandler._();

  /// Registers the handler with the OS. Safe to call once at startup.
  static Future<void> init() async {
    if (_registered) return;
    try {
      _instance = await AudioService.init<MediaHandler>(
        builder: () => _instance ?? MediaHandler._(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.islamsalemco.azkroh.media',
          androidNotificationChannelName: 'التلاوة والإذاعة',
          androidNotificationIcon: 'drawable/ic_stat_media',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
      _registered = true;
      unawaited(_instance!._prepareArt());
    } catch (e) {
      debugPrint('MediaHandler init failed: $e');
    }
  }

  static bool _registered = false;

  final AudioPlayer player = AudioPlayer();

  MediaMode _mode = MediaMode.none;
  MediaMode get mode => _mode;
  MediaControls? _controls;
  Uri? _artUri;

  /// Takes ownership of the player. The previous owner is told through
  /// [MediaControls.onYield]; owners check [mode] when reacting to player
  /// state.
  void claim(MediaMode mode, MediaControls controls) {
    final prev = _controls;
    if (_mode != mode && prev != null) prev.onYield?.call();
    _mode = mode;
    _controls = controls;
    _broadcast();
  }

  void release(MediaMode mode) {
    if (_mode != mode) return;
    _mode = MediaMode.none;
    _controls = null;
    mediaItem.add(null);
    playbackState.add(PlaybackState(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  /// Updates what the lock screen shows.
  void setNowPlaying({
    required String id,
    required String title,
    String? artist,
    String? album,
    Duration? duration,
  }) {
    mediaItem.add(MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album ?? 'أذكروه',
      duration: duration,
      artUri: _artUri,
    ));
  }

  void updateDuration(Duration? d) {
    final m = mediaItem.value;
    if (m != null && d != null && m.duration != d) {
      mediaItem.add(m.copyWith(duration: d));
    }
  }

  Future<void> _prepareArt() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/media_art_v2.png');
      if (!f.existsSync()) {
        final data = await rootBundle.load('assets/images/app_icon.png');
        await f.writeAsBytes(data.buffer.asUint8List());
      }
      _artUri = Uri.file(f.path);
      final m = mediaItem.value;
      if (m != null) mediaItem.add(m.copyWith(artUri: _artUri));
    } catch (_) {}
  }

  void _broadcast() {
    final c = _controls;
    if (c == null) return;
    final playing = player.playing;
    final ps = player.processingState;
    const map = {
      ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    };
    final controls = <MediaControl>[
      if (c.previous != null) MediaControl.skipToPrevious,
      playing ? MediaControl.pause : MediaControl.play,
      if (c.next != null) MediaControl.skipToNext,
      MediaControl.stop,
    ];
    final compact = <int>[];
    for (int i = 0; i < controls.length && compact.length < 3; i++) {
      if (controls[i] != MediaControl.stop || controls.length <= 2) {
        compact.add(i);
      }
    }
    playbackState.add(PlaybackState(
      controls: controls,
      systemActions: {
        if (c.seekable) MediaAction.seek,
        if (c.seekable) MediaAction.seekForward,
        if (c.seekable) MediaAction.seekBackward,
      },
      androidCompactActionIndices: compact,
      // A paused/stopped item must still be "ready" to keep the lock-screen
      // card visible; idle removes it.
      processingState: ps == ProcessingState.idle && playing == false
          ? AudioProcessingState.ready
          : map[ps]!,
      playing: playing,
      updatePosition: c.seekable ? player.position : Duration.zero,
      bufferedPosition: c.seekable ? player.bufferedPosition : Duration.zero,
      speed: player.speed,
    ));
  }

  // ---------------------------------------------------------------------------
  // OS commands
  // ---------------------------------------------------------------------------
  @override
  Future<void> play() async => _controls?.play();

  @override
  Future<void> pause() async => _controls?.pause();

  @override
  Future<void> stop() async {
    final c = _controls;
    if (c != null) await c.stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async => _controls?.next?.call();

  @override
  Future<void> skipToPrevious() async => _controls?.previous?.call();

  @override
  Future<void> seek(Duration position) async {
    if (_controls?.seekable == true) await player.seek(position);
  }

  @override
  Future<void> onTaskRemoved() async => stop();
}
