import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../domain/auth/app_user.dart';
import '../../../domain/auth/auth_repository.dart';

/// Firebase-backed [AuthRepository]: Google Sign-In through
/// `package:google_sign_in` (v7 API — a one-time [GoogleSignIn.initialize]
/// call, then [GoogleSignIn.authenticate]) feeding a credential into
/// `firebase_auth`.
///
/// On Android, [GoogleSignIn.initialize] needs no `clientId`/`serverClientId`
/// as long as `google-services.json` contains a web OAuth client entry
/// (`oauth_client` with `client_type: 3`) — the native plugin reads it from
/// the generated `default_web_client_id` string resource. See
/// `google_sign_in_android`'s README ("Integration" section).
///
/// This is the only file (besides `firestore_event_repository.dart`) that
/// imports Firebase packages directly — `features/auth/presentation` and
/// `features/auth/application` only ever see [AuthRepository]/[AppUser]
/// (RULES.md: widgets never touch Firebase directly).
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    fb_auth.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  }) : _firebaseAuth = firebaseAuth ?? fb_auth.FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final fb_auth.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;
  Future<void>? _googleSignInInitialization;

  @override
  Stream<AppUser?> authStateChanges() =>
      _firebaseAuth.authStateChanges().map(_toAppUser);

  @override
  Future<AppUser?> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();

    final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (error) {
      // A plain user cancellation is not an error the UI needs to surface
      // (task brief M2b §2 — "handle sign-in cancellation gracefully").
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    }

    final GoogleSignInAuthentication googleAuth = account.authentication;
    final fb_auth.AuthCredential credential =
        fb_auth.GoogleAuthProvider.credential(idToken: googleAuth.idToken);
    final fb_auth.UserCredential userCredential = await _firebaseAuth
        .signInWithCredential(credential);
    final fb_auth.User? user = userCredential.user;
    if (user == null) {
      return null;
    }

    await _mergeUserDocument(user);
    return _toAppUser(user);
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    // Best-effort: Google Sign-In's own session doesn't need to succeed for
    // the app's sign-out to be effective (Firebase Auth already dropped the
    // user), but dropping it too avoids silently re-signing-in next time via
    // a cached Google session.
    await _googleSignIn.signOut();
  }

  Future<void> _ensureGoogleSignInInitialized() {
    return _googleSignInInitialization ??= _googleSignIn.initialize();
  }

  /// Creates or merges the `users/{uid}` profile document on sign-in
  /// (task brief M2b §2 — "via the repository, not from widgets"). The
  /// `createdAt` field is only ever set once, on first sign-in; subsequent
  /// sign-ins only refresh the profile fields that may have changed upstream
  /// (display name, email, photo).
  Future<void> _mergeUserDocument(fb_auth.User user) async {
    final DocumentReference<Map<String, dynamic>> doc = _firestore
        .collection('users')
        .doc(user.uid);
    final DocumentSnapshot<Map<String, dynamic>> existing = await doc.get();

    final Map<String, dynamic> profileFields = <String, dynamic>{
      'displayName': user.displayName,
      'email': user.email,
      'photoUrl': user.photoURL,
    };

    if (existing.exists) {
      await doc.update(profileFields);
    } else {
      await doc.set(<String, dynamic>{
        ...profileFields,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  AppUser? _toAppUser(fb_auth.User? user) {
    if (user == null) {
      return null;
    }
    return AppUser(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
      photoUrl: user.photoURL,
    );
  }
}
