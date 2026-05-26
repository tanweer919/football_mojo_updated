import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Generates a shareable PNG from a Flutter widget and hands it to the
/// system share sheet. The widget is mounted as a hidden overlay so a
/// `RepaintBoundary` can be captured cleanly without leaving the calling
/// screen.
class ShareService {
  ShareService._();
  static final instance = ShareService._();

  /// Renders [builder]'s widget at [logicalSize], captures it as PNG, then
  /// shares it with [text] as the message body. Auto-removes the hidden
  /// overlay after capture.
  Future<bool> shareArtifact({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    required Size logicalSize,
    required String text,
    String filename = 'pitch_share.png',
    double pixelRatio = 3.0,
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final boundaryKey = GlobalKey();
    final completer = Completer<Uint8List>();

    final entry = OverlayEntry(
      builder: (ctx) {
        // Hidden but laid out so RepaintBoundary captures a real frame.
        // Offstage on its own won't paint; Opacity 0 keeps the paint cycle
        // running while staying invisible to the user.
        return Positioned(
          left: -10_000, // off-screen but still in the paint tree
          top: -10_000,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0,
              child: RepaintBoundary(
                key: boundaryKey,
                child: SizedBox.fromSize(
                  size: logicalSize,
                  child: MediaQuery(
                    data: MediaQuery.of(ctx).copyWith(size: logicalSize),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Builder(builder: builder),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(entry);

    // Wait two frames so any image/network widgets get a chance to lay out
    // before we capture. Three frames is paranoid-safe; one tends to miss
    // cached images that resolve on the next microtask.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    try {
      final boundary = boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw StateError('encode_failed');
      completer.complete(byteData.buffer.asUint8List());
    } catch (e) {
      completer.completeError(e);
    } finally {
      entry.remove();
    }

    try {
      final bytes = await completer.future;
      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(text: text, files: [XFile(file.path)]),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
