import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class TeamCrest extends StatelessWidget {
  const TeamCrest({super.key, this.url, this.size = 32});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Icon(Icons.shield_outlined, size: size * 0.9);
    }
    return CachedNetworkImage(
      imageUrl: url!,
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholder: (_, __) => SizedBox(width: size, height: size),
      errorWidget: (_, __, ___) => Icon(Icons.shield_outlined, size: size * 0.9),
    );
  }
}
