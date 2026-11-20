import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Share text. iOS/iPadOS need the source rect of the tapped widget
/// (`sharePositionOrigin`), otherwise the share sheet throws.
Future<void> shareText(BuildContext context, String text) async {
  Rect? origin;
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize) {
    origin = box.localToGlobal(Offset.zero) & box.size;
  }
  if (origin == null || origin.isEmpty) {
    final size = MediaQuery.sizeOf(context);
    origin = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2), width: 1, height: 1);
  }
  await Share.share(text, sharePositionOrigin: origin);
}
