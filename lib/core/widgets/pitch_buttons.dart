import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_gradients.dart';
import '../design/app_spacing.dart';
import '../design/motion.dart';

/// `.btn--gold` from `components.css`. Champagne gradient with gold-glow shadow.
class GoldButton extends StatefulWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.small = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool small;
  final bool expand;

  @override
  State<GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<GoldButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.small ? 32.0 : 44.0;
    final padH = widget.small ? 12.0 : 18.0;
    final fontSize = widget.small ? 12.0 : 14.0;

    final core = AnimatedContainer(
      duration: AppMotion.sm,
      curve: AppMotion.ease,
      transform: _hover && widget.onPressed != null
          ? (Matrix4.identity()..translate(0.0, -1.0))
          : Matrix4.identity(),
      height: h,
      padding: EdgeInsets.symmetric(horizontal: padH),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r3),
        gradient: AppGradients.buttonGold,
        boxShadow: [
          // inset top highlight + bottom shadow + gold glow
          BoxShadow(
            color: const Color(0xFFC99A3D).withValues(alpha: _hover ? 0.38 : 0.28),
            blurRadius: _hover ? 32 : 24,
            offset: Offset(0, _hover ? 12 : 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: fontSize + 2, color: const Color(0xFF1E1810)),
            const SizedBox(width: 8),
          ],
          Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
              color: const Color(0xFF1E1810),
              letterSpacing: -0.05,
            ),
          ),
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: widget.onPressed == null ? 0.5 : 1.0,
          child: widget.expand
              ? SizedBox(width: double.infinity, child: core)
              : core,
        ),
      ),
    );
  }
}

/// `.btn--ghost` from `components.css`. Translucent surface + border, blur backdrop.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.small = false,
    this.gold = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool small;
  final bool gold;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final h = small ? 32.0 : 44.0;
    final padH = small ? 12.0 : 18.0;
    final fontSize = small ? 12.0 : 14.0;
    final color = gold ? AppColors.gold : AppColors.fg;
    final borderColor = gold ? AppColors.goldHairline : AppColors.border;

    final core = Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: padH),
      decoration: BoxDecoration(
        color: gold ? Colors.transparent : AppColors.surface3.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadii.r3),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: color),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
              color: color,
              letterSpacing: -0.05,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1.0,
        child: expand ? SizedBox(width: double.infinity, child: core) : core,
      ),
    );
  }
}

/// `.icon-btn` — round 36px translucent surface with gold dot indicator option.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.dot = false,
    this.size = 36,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final bool dot;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.surface3.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSoft, width: 1),
            ),
            child: Icon(icon, size: 16, color: AppColors.fg),
          ),
          if (dot)
            Positioned(
              top: 7, right: 7,
              child: Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bg, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `.hairline` — 1px gradient divider.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.gold = false});
  final bool gold;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            gold ? AppColors.goldHairline : AppColors.border,
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

/// Avatar pill — gold gradient with monogram. Matches `.avatar` in spec.
class GoldAvatar extends StatelessWidget {
  const GoldAvatar({super.key, required this.initials, this.size = 36});
  final String initials;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFC99A3D), Color(0xFF7E5A1F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: AppColors.goldHairline, blurRadius: 0, spreadRadius: 1.5),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
          color: const Color(0xFF1E1810),
        ),
      ),
    );
  }
}
