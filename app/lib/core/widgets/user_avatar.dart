import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../design/app_colors.dart';
import '../../features/profile/data/profile_repository.dart';

/// Reusable user avatar with three render states:
///   - Signed-out      → grey placeholder + person icon
///   - Signed-in, photo → CachedNetworkImage of the user's photo URL
///   - Signed-in, no photo → gold-gradient circle with initials from
///                            displayName (or email local-part)
///
/// Resolves the user from `myProfileProvider` (backend photoUrl) with a
/// fallback to the live Firebase user's photoURL so the avatar still
/// renders correctly on first sign-in before the backend has stored it.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    required this.size,
    this.fontSize,
    this.iconSize,
  });

  final double size;
  /// Override initial-letter font size. Defaults to `size * 0.4`.
  final double? fontSize;
  /// Override placeholder icon size. Defaults to `size * 0.55`.
  final double? iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final firebaseUser = authState.valueOrNull;
    final isSignedIn = firebaseUser != null && !firebaseUser.isAnonymous;
    if (!isSignedIn) {
      return _PlaceholderAvatar(size: size, iconSize: iconSize);
    }
    final profileAsync = ref.watch(myProfileProvider);
    final profile = profileAsync.valueOrNull;
    final photoUrl = profile?.photoUrl ?? firebaseUser.photoURL;
    final displayName = profile?.displayName ?? firebaseUser.displayName;
    final email = profile?.email ?? firebaseUser.email;

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return _PhotoAvatar(
        size: size,
        url: photoUrl,
        fallback: _InitialAvatar(
          size: size,
          initials: _initialsFor(displayName, email),
          fontSize: fontSize,
        ),
      );
    }
    return _InitialAvatar(
      size: size,
      initials: _initialsFor(displayName, email),
      fontSize: fontSize,
    );
  }

  /// One or two letters used when no photo is available. Prefers the
  /// first letter of two words in displayName; falls back to first two
  /// letters of the name (or email local-part); never returns empty.
  static String _initialsFor(String? displayName, String? email) {
    final source = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!.trim()
        : (email?.split('@').first.trim() ?? '');
    if (source.isEmpty) return '?';
    final parts = source.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return source.substring(0, source.length >= 2 ? 2 : 1).toUpperCase();
  }
}

class _PhotoAvatar extends StatelessWidget {
  const _PhotoAvatar({
    required this.size,
    required this.url,
    required this.fallback,
  });
  final double size;
  final String url;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: size,
          height: size,
          color: AppColors.surface3,
        ),
        // Errors (404, bad URL) fall back to initials.
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({
    required this.size,
    required this.initials,
    this.fontSize,
  });
  final double size;
  final String initials;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFC99A3D), Color(0xFF7E5A1F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w800,
          fontSize: fontSize ?? size * 0.4,
          color: const Color(0xFF1E1810),
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}

class _PlaceholderAvatar extends StatelessWidget {
  const _PlaceholderAvatar({required this.size, this.iconSize});
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface3,
        border: Border.all(color: AppColors.borderSoft),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_outline,
        size: iconSize ?? size * 0.55,
        color: AppColors.muted,
      ),
    );
  }
}
