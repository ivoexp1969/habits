import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../l10n/app_localizations.dart';

/// Language-agnostic auth error codes. The UI turns these into localized text
/// via [authErrorMessage] — the service never returns user-facing strings.
enum AuthError {
  generic,
  needVerify,
  reauth,
  invalidEmail,
  userDisabled,
  userNotFound,
  wrongPassword,
  emailInUse,
  weakPassword,
  tooManyRequests,
  network,
  accountExists,
}

/// Maps an [AuthError] to a localized message.
String authErrorMessage(AppLocalizations l10n, AuthError e) {
  switch (e) {
    case AuthError.needVerify:
      return l10n.authErrNeedVerify;
    case AuthError.reauth:
      return l10n.authErrReauth;
    case AuthError.invalidEmail:
      return l10n.authErrInvalidEmail;
    case AuthError.userDisabled:
      return l10n.authErrUserDisabled;
    case AuthError.userNotFound:
      return l10n.authErrUserNotFound;
    case AuthError.wrongPassword:
      return l10n.authErrWrongPassword;
    case AuthError.emailInUse:
      return l10n.authErrEmailInUse;
    case AuthError.weakPassword:
      return l10n.authErrWeakPassword;
    case AuthError.tooManyRequests:
      return l10n.authErrTooManyRequests;
    case AuthError.network:
      return l10n.authErrNetwork;
    case AuthError.accountExists:
      return l10n.authErrAccountExists;
    case AuthError.generic:
      return l10n.authErrGeneric;
  }
}

/// Outcome of an auth attempt. [error] is a code (null on success or on a
/// user-cancelled flow); the UI localizes it.
typedef AuthResult = ({bool ok, AuthError? error, bool needsVerification});

/// Thin wrapper around FirebaseAuth for Навици. Accounts are OPTIONAL — the app
/// works fully without signing in; local SharedPreferences stays the source of
/// truth. Signing in only adds cloud backup + cross-device sync (see
/// [CloudSyncService]).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;
  String? get email => _auth.currentUser?.email;
  String? get uid => _auth.currentUser?.uid;

  Stream<User?> get authState => _auth.authStateChanges();

  // ----- Email / password -------------------------------------------------

  Future<AuthResult> registerWithEmail(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      await cred.user?.sendEmailVerification();
      return (ok: true, error: null, needsVerification: true);
    } on FirebaseAuthException catch (e) {
      return (ok: false, error: _code(e), needsVerification: false);
    } catch (_) {
      return (ok: false, error: AuthError.generic, needsVerification: false);
    }
  }

  Future<AuthResult> loginWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      final verified = cred.user?.emailVerified ?? false;
      if (!verified) {
        return (ok: false, error: AuthError.needVerify, needsVerification: true);
      }
      return (ok: true, error: null, needsVerification: false);
    } on FirebaseAuthException catch (e) {
      return (ok: false, error: _code(e), needsVerification: false);
    } catch (_) {
      return (ok: false, error: AuthError.generic, needsVerification: false);
    }
  }

  Future<AuthResult> resendVerification() async {
    try {
      await _auth.currentUser?.reload();
      await _auth.currentUser?.sendEmailVerification();
      return (ok: true, error: null, needsVerification: true);
    } catch (_) {
      return (ok: false, error: AuthError.generic, needsVerification: false);
    }
  }

  Future<bool> reloadAndCheckVerified() async {
    try {
      await _auth.currentUser?.reload();
      return _auth.currentUser?.emailVerified ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return (ok: true, error: null, needsVerification: false);
    } on FirebaseAuthException catch (e) {
      return (ok: false, error: _code(e), needsVerification: false);
    } catch (_) {
      return (ok: false, error: AuthError.generic, needsVerification: false);
    }
  }

  // ----- Google -----------------------------------------------------------

  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        return (ok: false, error: null, needsVerification: false); // cancelled
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      return (ok: true, error: null, needsVerification: false);
    } on FirebaseAuthException catch (e) {
      return (ok: false, error: _code(e), needsVerification: false);
    } catch (_) {
      return (ok: false, error: AuthError.generic, needsVerification: false);
    }
  }

  // ----- Apple (iOS) ------------------------------------------------------

  bool get appleAvailable => !kIsWeb && Platform.isIOS;

  Future<AuthResult> signInWithApple() async {
    try {
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oauth = OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        accessToken: apple.authorizationCode,
      );
      await _auth.signInWithCredential(oauth);
      return (ok: true, error: null, needsVerification: false);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return (ok: false, error: null, needsVerification: false);
      }
      return (ok: false, error: AuthError.generic, needsVerification: false);
    } on FirebaseAuthException catch (e) {
      return (ok: false, error: _code(e), needsVerification: false);
    } catch (_) {
      return (ok: false, error: AuthError.generic, needsVerification: false);
    }
  }

  // ----- Session ----------------------------------------------------------

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {/* not signed in via Google */}
    await _auth.signOut();
  }

  /// Deletes the auth account. The caller should first delete the Firestore
  /// document via [CloudSyncService.deleteCloudData]. May return
  /// [AuthError.reauth] (`requires-recent-login`).
  Future<AuthResult> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
      return (ok: true, error: null, needsVerification: false);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return (ok: false, error: AuthError.reauth, needsVerification: false);
      }
      return (ok: false, error: _code(e), needsVerification: false);
    } catch (_) {
      return (ok: false, error: AuthError.generic, needsVerification: false);
    }
  }

  AuthError _code(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return AuthError.invalidEmail;
      case 'user-disabled':
        return AuthError.userDisabled;
      case 'user-not-found':
        return AuthError.userNotFound;
      case 'wrong-password':
      case 'invalid-credential':
        return AuthError.wrongPassword;
      case 'email-already-in-use':
        return AuthError.emailInUse;
      case 'weak-password':
        return AuthError.weakPassword;
      case 'too-many-requests':
        return AuthError.tooManyRequests;
      case 'network-request-failed':
        return AuthError.network;
      case 'account-exists-with-different-credential':
        return AuthError.accountExists;
      default:
        return AuthError.generic;
    }
  }
}
