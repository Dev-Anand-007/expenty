/// The signed-in user's editable profile.
class Profile {
  final String id;
  final String name;
  final String email;

  /// Unique handle other people can search by (always lowercase).
  final String? username;
  final String? photoUrl;

  const Profile({
    required this.id,
    required this.name,
    required this.email,
    this.username,
    this.photoUrl,
  });

  Profile copyWith({
    String? id,
    String? name,
    String? email,
    String? username,
    String? photoUrl,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Profile &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            name == other.name &&
            email == other.email &&
            username == other.username &&
            photoUrl == other.photoUrl;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, email, username, photoUrl);
}
