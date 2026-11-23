import 'package:firebase_auth/firebase_auth.dart';
import 'package:habits/services/cloud/auth_backend.dart';

/// A controllable in-memory [AuthBackend] for tests — unlike firebase_auth_mocks
/// it supports linkWithCredential (keeping the uid), which is exactly the anon→
/// account flow under test.
class FakeAuthBackend implements AuthBackend {
  FakeAuthBackend({String? uid, this.anonymous = true}) : _uid = uid;

  String? _uid;
  bool anonymous;

  /// When set, [link] returns [LinkOutcome.alreadyInUse] and [signInWith]
  /// switches to [existingUid] (an existing foreign account).
  String? existingUid;

  int anonCreated = 0;
  int verificationsSent = 0;
  bool deleted = false;

  @override
  String? get currentUid => _uid;
  @override
  bool get isAnonymous => anonymous && _uid != null;
  @override
  bool get isSignedIn => _uid != null;

  @override
  Future<String?> ensureSignedIn() async {
    if (_uid != null) return _uid;
    anonCreated++;
    _uid = 'anon-${anonCreated}-${DateTime.now().microsecondsSinceEpoch}';
    anonymous = true;
    return _uid;
  }

  @override
  Future<LinkOutcome> link(AuthCredential credential) async {
    if (_uid == null) return LinkOutcome.noCurrentUser;
    if (existingUid != null) return LinkOutcome.alreadyInUse;
    anonymous = false; // linked → same uid, now a real account
    return LinkOutcome.linked;
  }

  @override
  Future<String?> signInWith(AuthCredential credential) async {
    _uid = existingUid ?? _uid;
    anonymous = false;
    return _uid;
  }

  @override
  Future<void> signOut() async {
    _uid = null;
    anonymous = false;
  }

  @override
  Future<void> deleteCurrentUser() async {
    deleted = true;
    _uid = null;
  }

  @override
  Future<void> sendEmailVerification() async {
    verificationsSent++;
  }
}
