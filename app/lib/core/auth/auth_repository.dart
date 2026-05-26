import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  AuthRepository(this._auth);
  final FirebaseAuth _auth;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return _auth.currentUser?.getIdToken(forceRefresh);
  }

  Future<User> signInWithGoogle() async {
    final google = await GoogleSignIn().signIn();
    if (google == null) throw FirebaseAuthException(code: 'cancelled');
    final googleAuth = await google.authentication;
    final cred = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // ─────────────────────────────────────────────────────────────────────
    // Known firebase_auth 4.x ↔ google_sign_in 6.x bug:
    //   "type 'List<Object?>' is not a subtype of type 'PigeonUserDetails?'"
    //
    // The native sign-in actually succeeds — only the Pigeon return-value
    // cast in `signInWithCredential` throws. We catch the cast (TypeError),
    // then resolve the freshly-authed user via `authStateChanges`. The
    // upgrade path is firebase_auth 5.x (breaking — bumps firebase_core to
    // 3.x and ripples across every firebase_* dep). Until that's planned,
    // this workaround is the supported community fix.
    // ─────────────────────────────────────────────────────────────────────
    try {
      final result = await _auth.signInWithCredential(cred);
      if (result.user != null) return result.user!;
    } on TypeError catch (_) {
      // fall through to the auth-state recovery
    } on PlatformException catch (e) {
      // Pigeon platform errors that wrap the same cast failure.
      if (!_isPigeonCastError(e)) rethrow;
    }

    // Wait for the first non-null user from the auth-state stream (auth
    // already succeeded native-side; this just gives Firebase a tick to
    // surface it).
    final user = await _auth
        .authStateChanges()
        .firstWhere((u) => u != null, orElse: () => null)
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    if (user != null) return user;
    if (_auth.currentUser != null) return _auth.currentUser!;
    throw FirebaseAuthException(
      code: 'sign-in-failed',
      message: 'Google sign-in returned no user.',
    );
  }

  bool _isPigeonCastError(PlatformException e) {
    final m = '${e.message ?? ''}${e.details ?? ''}';
    return m.contains('PigeonUserDetails') || m.contains('List<Object?>');
  }

  Future<User> signInAnonymously() async {
    final result = await _auth.signInAnonymously();
    return result.user!;
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), GoogleSignIn().signOut()]);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((_) {
  return AuthRepository(FirebaseAuth.instance);
});
