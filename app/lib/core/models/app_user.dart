class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    this.email,
    this.name,
    this.role = 'user',
  });

  final int id;
  final String username;
  final String? email;
  final String? name;
  final String role;

  bool get isAdmin => role == 'admin';
  String get displayName => (name?.trim().isNotEmpty ?? false)
      ? name!
      : (email ?? username);

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: (json['id'] as num).toInt(),
    username: json['username'] as String,
    email: json['email'] as String?,
    name: json['name'] as String?,
    role: (json['role'] as String?) ?? 'user',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'name': name,
    'role': role,
  };
}
