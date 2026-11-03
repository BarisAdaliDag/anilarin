/// Kayıtlı kullanıcının bilgileri (Firestore `users/{uid}`).
class UserProfile {
  String firstName;
  String lastName;
  String email;
  String phone;
  int createdAtMs;
  int kvkkAcceptedAtMs;

  UserProfile({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.createdAtMs = 0,
    this.kvkkAcceptedAtMs = 0,
  });

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phone': phone,
    'createdAt': createdAtMs,
    'kvkkAcceptedAt': kvkkAcceptedAtMs,
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    firstName: j['firstName'] ?? '',
    lastName: j['lastName'] ?? '',
    email: j['email'] ?? '',
    phone: j['phone'] ?? '',
    createdAtMs: j['createdAt'] ?? 0,
    kvkkAcceptedAtMs: j['kvkkAcceptedAt'] ?? 0,
  );
}
