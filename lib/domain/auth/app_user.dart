/// A pure-Dart, Firebase-free representation of the signed-in user.
///
/// Mirrors the subset of `firebase_auth`'s `User` the app actually needs
/// (ARCHITECTURE.md §3: domain must not import Firebase). Presentation and
/// data code convert to/from this at the boundary.
class AppUser {
  const AppUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  /// Firebase Auth uid — also the value Firestore Security Rules compare
  /// against `resource.data.ownerUid` (RULES.md §5.2).
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppUser &&
          other.uid == uid &&
          other.displayName == displayName &&
          other.email == email &&
          other.photoUrl == photoUrl);

  @override
  int get hashCode => Object.hash(uid, displayName, email, photoUrl);

  @override
  String toString() =>
      'AppUser(uid: $uid, displayName: $displayName, email: $email)';
}
