import 'package:flutter/material.dart';

/// Shared visual frame for every shareable artifact — gold/black gradient,
/// PITCH wordmark header, watermark footer. Children compose their own
/// content area; the frame guarantees brand consistency.
class ShareCardFrame extends StatelessWidget {
  const ShareCardFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.userHandle,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? userHandle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF181410), Color(0xFF0C0A07)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(),
          const SizedBox(height: 22),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFEBD9A8),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              height: 1.05,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(child: child),
          const SizedBox(height: 18),
          _Footer(handle: userHandle),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22, height: 22,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0xFFF1E4B6), Color(0xFFE5C26B), Color(0xFF8E6422)],
              stops: [0.2, 0.6, 1.0],
              center: Alignment(-0.3, -0.4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [Color(0xFFEBD9A8), Color(0xFFB78A2E)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ).createShader(rect),
          child: const Text(
            'PITCH',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: Colors.white,
            ),
          ),
        ),
        const Spacer(),
        const Text(
          'WORLD CUP 2026',
          style: TextStyle(
            color: Color(0xFFB78A2E),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({this.handle});
  final String? handle;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Join on',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              'pitch.app',
              style: const TextStyle(
                color: Color(0xFFEBD9A8),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (handle != null)
          Text(
            handle!.startsWith('@') ? handle! : '@$handle',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}
