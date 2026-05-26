import 'dart:async';

import 'package:flutter/material.dart';

/// Stream-driven countdown that reformats every second without rebuilding
/// the parent. Stops when the target is reached.
class CountdownText extends StatefulWidget {
  const CountdownText({
    super.key,
    required this.target,
    this.style,
    this.dense = false,
    this.expiredLabel = 'Live now',
  });

  final DateTime target;
  final TextStyle? style;
  final bool dense;
  final String expiredLabel;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _recompute();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _recompute());
  }

  void _recompute() {
    final r = widget.target.difference(DateTime.now());
    if (mounted) setState(() => _remaining = r);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    if (d.isNegative) return widget.expiredLabel;
    final days = d.inDays;
    final h = d.inHours % 24;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;

    if (widget.dense) {
      if (days >= 1) return '${days}d ${h}h';
      if (h >= 1) return '${h}h ${m}m';
      return '${m}m ${s}s';
    }

    final hh = (d.inHours).toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    if (days >= 1) return '${days}d ${h}h ${m}m';
    return '$hh:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final style = (widget.style ?? Theme.of(context).textTheme.titleSmall)?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w800,
    );
    return Text(_format(_remaining), style: style);
  }
}
