/// User profile from `GET /users/me` — `query.MeResponse`.
class UserProfile {
  UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.role,
    this.status,
    this.createdAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? role;
  final String? status;
  final DateTime? createdAt;

  String get fullName {
    final parts = [firstName, lastName].where((s) => s.isNotEmpty);
    return parts.join(' ');
  }

  bool get isProfileComplete => firstName.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (role != null) 'role': role,
        if (status != null) 'status': status,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      firstName: (json['first_name'] as String? ?? '').trim(),
      lastName: (json['last_name'] as String? ?? '').trim(),
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String?,
      status: json['status'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
