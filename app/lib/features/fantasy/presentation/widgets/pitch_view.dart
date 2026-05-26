import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/design/app_gradients.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/motion.dart';
import '../../data/models/fantasy_models.dart';
import 'player_slot.dart';

/// Stadium-grade painted pitch. Four rows top → bottom (FWD / MID / DEF / GK)
/// rendered over a real grass texture (alternating mowed stripes), with
/// FIFA-style line markings and a centre circle.
///
/// 8-player formation: 2 FWD / 2 MID / 2 DEF / 2 GK (1 starter + 1 substitute
/// in the lineup model). Tap a slot to open the picker, long-press to set
/// captain.
class PitchView extends StatelessWidget {
  const PitchView({
    super.key,
    required this.slots,
    required this.players,
    required this.captainId,
    required this.onSlotTap,
    required this.onSlotLongPress,
  });

  final Map<PlayerPosition, List<String>> slots;
  final Map<String, PlayerValuationDto> players;
  final String? captainId;
  final void Function(PlayerPosition position, int slotIndex, String? currentPlayerId) onSlotTap;
  final void Function(String playerId) onSlotLongPress;

  static const _positionsTopToBottom = [
    PlayerPosition.FWD,
    PlayerPosition.MID,
    PlayerPosition.DEF,
    PlayerPosition.GK,
  ];

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.78,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Grass + mowed stripes
            CustomPaint(painter: _PitchPainter()),
            // Subtle floodlight glow
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppGradients.floodlight),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
              child: Column(
                children: [
                  for (final pos in _positionsTopToBottom)
                    Expanded(child: _Row(position: pos, parent: this)),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fade(duration: AppMotion.lg, curve: AppMotion.enter);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.position, required this.parent});
  final PlayerPosition position;
  final PitchView parent;

  @override
  Widget build(BuildContext context) {
    const required = {
      PlayerPosition.GK: 2,
      PlayerPosition.DEF: 2,
      PlayerPosition.MID: 2,
      PlayerPosition.FWD: 2,
    };
    final count = required[position]!;
    final filled = parent.slots[position] ?? const <String>[];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(count, (i) {
        final playerId = i < filled.length ? filled[i] : null;
        final player = playerId == null ? null : parent.players[playerId];
        return PlayerSlot(
          position: position,
          player: player,
          isCaptain: playerId != null && playerId == parent.captainId,
          onTap: () => parent.onSlotTap(position, i, playerId),
          onLongPress: playerId == null ? null : () => parent.onSlotLongPress(playerId),
          indexInRow: i,
        );
      }),
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base grass gradient
    canvas.drawRect(
      rect,
      Paint()..shader = AppGradients.turf.createShader(rect),
    );

    // Mowed stripes — alternating darker/lighter horizontal bands.
    const stripeCount = 7;
    final stripeHeight = size.height / stripeCount;
    for (int i = 0; i < stripeCount; i++) {
      final paint = Paint()
        ..color = i.isEven
            ? const Color(0xFF0B5A2D).withValues(alpha: 0.35)
            : const Color(0xFF1E9A55).withValues(alpha: 0.18);
      canvas.drawRect(
        Rect.fromLTWH(0, i * stripeHeight, size.width, stripeHeight),
        paint,
      );
    }

    // White line markings.
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    // Outer frame
    final frame = rect.deflate(8);
    canvas.drawRRect(RRect.fromRectAndRadius(frame, const Radius.circular(18)), line);

    // Halfway line + centre circle + dot
    final midY = size.height / 2;
    canvas.drawLine(Offset(8, midY), Offset(size.width - 8, midY), line);
    canvas.drawCircle(Offset(size.width / 2, midY), size.width * 0.12, line);
    canvas.drawCircle(
      Offset(size.width / 2, midY),
      2.6,
      Paint()..color = Colors.white.withValues(alpha: 0.65),
    );

    // Penalty boxes (top + bottom)
    final boxW = size.width * 0.5;
    final boxH = size.height * 0.16;
    final boxL = (size.width - boxW) / 2;
    canvas.drawRect(Rect.fromLTWH(boxL, 8, boxW, boxH), line);
    canvas.drawRect(Rect.fromLTWH(boxL, size.height - 8 - boxH, boxW, boxH), line);

    // 6-yard boxes
    final smallW = size.width * 0.28;
    final smallH = size.height * 0.07;
    final smallL = (size.width - smallW) / 2;
    canvas.drawRect(Rect.fromLTWH(smallL, 8, smallW, smallH), line);
    canvas.drawRect(Rect.fromLTWH(smallL, size.height - 8 - smallH, smallW, smallH), line);

    // Penalty arcs (top + bottom)
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width / 2, 8 + boxH + 6),
        radius: size.width * 0.08,
      ),
      0,
      3.14159,
      false,
      line,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width / 2, size.height - 8 - boxH - 6),
        radius: size.width * 0.08,
      ),
      3.14159,
      3.14159,
      false,
      line,
    );

    // Corner arcs
    final cornerR = 10.0;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(8, 8), radius: cornerR),
      0, 1.5708, false, line,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width - 8, 8), radius: cornerR),
      1.5708, 1.5708, false, line,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(8, size.height - 8), radius: cornerR),
      -1.5708, 1.5708, false, line,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width - 8, size.height - 8), radius: cornerR),
      3.14159, 1.5708, false, line,
    );
  }

  @override
  bool shouldRepaint(covariant _PitchPainter old) => false;
}
