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

  /// Renders [builder] at [logicalSize], writes the PNG to a temp file,
  /// and returns the file path. Use this when the caller wants to attach
  /// the PNG to a ChottuLink-generated deep link share rather than
  /// firing the plain share sheet.
  Future<String?> renderArtifactToFile({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    required Size logicalSize,
    String filename = 'pitch_share.png',
    double pixelRatio = 3.0,
  }) async {
    final bytes = await _capture(
      context: context,
      builder: builder,
      logicalSize: logicalSize,
      pixelRatio: pixelRatio,
    );
    if (bytes == null) return null;
    try {
      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

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
    final bytes = await _capture(
      context: context,
      builder: builder,
      logicalSize: logicalSize,
      pixelRatio: pixelRatio,
    );
    if (bytes == null) return false;
    try {
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

  /// Renders [builder] at a FIXED WIDTH with intrinsic (content-driven)
  /// height and writes the PNG to a temp file. Use for tall "poster"
  /// graphics whose height can't be known up front — e.g. a full bracket
  /// prediction. Returns null on failure.
  ///
  /// [maxHeight] is a safety ceiling so an unbounded layout can't blow up
  /// memory; content taller than this is clipped (set generously).
  Future<String?> renderTallArtifactToFile({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    required double width,
    String filename = 'pitch_poster.png',
    double pixelRatio = 2.0,
    double maxHeight = 8000,
  }) async {
    final bytes = await _capture(
      context: context,
      builder: builder,
      // A null logicalSize signals width-only layout to _capture.
      logicalSize: null,
      width: width,
      maxHeight: maxHeight,
      pixelRatio: pixelRatio,
    );
    if (bytes == null) return null;
    try {
      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Hidden-overlay PNG capture. Used by [shareArtifact],
  /// [renderArtifactToFile] (fixed [logicalSize]) and
  /// [renderTallArtifactToFile] (width-only, intrinsic height). Returns
  /// null on failure.
  Future<Uint8List?> _capture({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    Size? logicalSize,
    double? width,
    double maxHeight = 8000,
    required double pixelRatio,
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final boundaryKey = GlobalKey();
    // Width-only mode lays the child out at a tight width and loose
    // height so a Column(mainAxisSize.min) sizes to its content; the
    // RepaintBoundary then captures that intrinsic size.
    final mqSize = logicalSize ?? Size(width ?? 1080, maxHeight);

    final entry = OverlayEntry(
      builder: (ctx) {
        final framed = MediaQuery(
          data: MediaQuery.of(ctx).copyWith(size: mqSize),
          child: Material(
            type: MaterialType.transparency,
            child: Builder(builder: builder),
          ),
        );
        // A positioned (left/top only) overlay child receives UNBOUNDED
        // constraints. A SizedBox pins a finite size regardless:
        //   - fixed-size mode → both dimensions tight
        //   - width-only mode → width tight, height loose (0..inf) so the
        //     poster's Column(mainAxisSize.min) wraps to its content.
        final sized = logicalSize != null
            ? SizedBox.fromSize(size: logicalSize, child: framed)
            : SizedBox(width: width, child: framed);
        // NOTE: no Opacity here. RenderOpacity with opacity 0 skips
        // painting its subtree, which leaves the RepaintBoundary unpainted
        // and makes toImage throw (!debugNeedsPaint). The content is
        // already invisible because it's positioned far off-screen, so the
        // opacity wrapper is unnecessary as well as harmful.
        return Positioned(
          left: -20_000, // off-screen but still in the paint tree
          top: -20_000,
          child: IgnorePointer(
            child: RepaintBoundary(key: boundaryKey, child: sized),
          ),
        );
      },
    );
    overlay.insert(entry);

    // Two frames so any image/network widgets resolve before capture.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    try {
      final boundary = boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      // Wait until the boundary has actually painted (large posters can
      // need an extra frame); avoids a "needs paint" toImage failure.
      var tries = 0;
      while (boundary.debugNeedsPaint && tries < 8) {
        await WidgetsBinding.instance.endOfFrame;
        tries++;
      }
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e, st) {
      debugPrint('ShareService capture failed: $e\n$st');
      return null;
    } finally {
      entry.remove();
    }
  }
}
