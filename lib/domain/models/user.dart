/// The signed-in user, from `GET /users/me`.
class User {
  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.language,
  });

  factory User.fromJson(Object? json) {
    final map = json as Map<String, Object?>;
    return User(
      id: map['id'] as String,
      firstName: (map['first_name'] as String? ?? '').trim(),
      lastName: (map['last_name'] as String? ?? '').trim(),
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      language: map['language'] as String?,
    );
  }

  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;

  /// The language the server speaks to the user in (`ru`, `uz` or `en`);
  /// null in a copy saved by a build that didn't know about it.
  final String? language;

  User withLanguage(String language) => User(
    id: id,
    firstName: firstName,
    lastName: lastName,
    email: email,
    phone: phone,
    language: language,
  );

  String get fullName =>
      [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

  /// A driver has to give at least a first name before using the app.
  bool get isProfileComplete => firstName.isNotEmpty;

  Map<String, Object?> toJson() => {
    'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'email': ?email,
    'phone': ?phone,
    'language': ?language,
  };
}
