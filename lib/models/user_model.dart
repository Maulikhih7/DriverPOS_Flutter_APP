class UserModel {
  final String id;
  final String? name;
  final String? username;
  final String? email;
  final String role;
  final List<String> permissions;
  final String? firstPosition;
  final GolfCourse? golfCourse;
  final Terminal? terminal;
  final String? profileImage;
  final bool isVerified;

  const UserModel({
    required this.id,
    this.name,
    this.username,
    this.email,
    required this.role,
    this.permissions = const [],
    this.firstPosition,
    this.golfCourse,
    this.terminal,
    this.profileImage,
    this.isVerified = true,
  });

  String get displayName => name ?? username ?? email ?? 'User';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      // Backend workstation login returns 'fullName' (username) and 'name' (display name)
      name: json['name'],
      username: json['fullName'],
      email: json['email'],
      role: json['role'] ?? 'WorkStation',
      permissions: List<String>.from(json['permissions'] ?? []),
      firstPosition: json['firstPosition'],
      golfCourse: json['golfCourse'] != null
          ? GolfCourse.fromJson(json['golfCourse'])
          : null,
      terminal: json['terminal'] != null
          ? Terminal.fromJson(json['terminal'])
          : null,
      profileImage: json['profileImage'],
      isVerified: json['isVerified'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'fullName': username,
        'email': email,
        'role': role,
        'permissions': permissions,
        'firstPosition': firstPosition,
        'golfCourse': golfCourse?.toJson(),
        'terminal': terminal?.toJson(),
        'profileImage': profileImage,
        'isVerified': isVerified,
      };
}

class GolfCourse {
  final String id;
  final String name;
  final String? logo;
  final String? address;

  const GolfCourse({
    required this.id,
    required this.name,
    this.logo,
    this.address,
  });

  factory GolfCourse.fromJson(Map<String, dynamic> json) {
    return GolfCourse(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      logo: json['logo'],
      address: json['address'],
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'logo': logo,
        'address': address,
      };
}

class Terminal {
  final String id;
  final String name;

  const Terminal({required this.id, required this.name});

  factory Terminal.fromJson(Map<String, dynamic> json) {
    return Terminal(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'_id': id, 'name': name};
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final UserModel user;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Backend returns: { success, message, data: {...workstation fields}, accessToken, refreshToken }
    final userData = json['data'] as Map<String, dynamic>? ?? {};
    return AuthResponse(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      user: UserModel.fromJson(userData),
    );
  }
}
