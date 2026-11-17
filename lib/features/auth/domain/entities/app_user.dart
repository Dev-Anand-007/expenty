class AppUser {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
  });

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? photoUrl,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  @override
  String toString() {
    return 'AppUser(id: $id, name: $name, email: $email)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppUser &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            name == other.name &&
            email == other.email &&
            photoUrl == other.photoUrl;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, email, photoUrl);
  }
}