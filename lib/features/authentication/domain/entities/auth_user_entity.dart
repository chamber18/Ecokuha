import 'package:equatable/equatable.dart';

enum UserRole {
  household,
  collector,
  junkshop;

  String get name {
    switch (this) {
      case UserRole.household:
        return 'household';
      case UserRole.collector:
        return 'collector';
      case UserRole.junkshop:
        return 'junkshop';
    }
  }

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'household':
        return UserRole.household;
      case 'collector':
        return UserRole.collector;
      case 'junkshop':
        return UserRole.junkshop;
      default:
        throw ArgumentError('Invalid user role: $role');
    }
  }
}

class AuthUserEntity extends Equatable {
  final String id;
  final String email;
  final String? fullName;
  final UserRole role;
  final String? profileImageUrl;
  final bool isEmailVerified;
  final bool isProfileComplete;
  final String?
  applicationStatus; // For collectors: pending, approved, rejected, reapplying
  final bool hadPriorApproval; // True if collector was ever approved before
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final String? signInProvider; // 'google.com', 'password', etc.

  const AuthUserEntity({
    required this.id,
    required this.email,
    this.fullName,
    required this.role,
    this.profileImageUrl,
    this.isEmailVerified = false,
    this.isProfileComplete = false,
    this.applicationStatus,
    this.hadPriorApproval = false,
    required this.createdAt,
    this.lastLoginAt,
    this.signInProvider,
  });

  String get displayName {
    if (fullName != null && fullName!.trim().isNotEmpty) return fullName!;
    return email.split('@').first;
  }

  String get name => (fullName ?? '').trim().isEmpty
      ? email.split('@').first
      : fullName!.trim();

  @override
  List<Object?> get props => [
    id,
    email,
    fullName,
    role,
    profileImageUrl,
    isEmailVerified,
    isProfileComplete,
    applicationStatus,
    hadPriorApproval,
    createdAt,
    lastLoginAt,
    signInProvider,
  ];

  AuthUserEntity copyWith({
    String? id,
    String? email,
    String? fullName,
    UserRole? role,
    String? profileImageUrl,
    bool? isEmailVerified,
    bool? isProfileComplete,
    String? applicationStatus,
    bool? hadPriorApproval,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return AuthUserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      applicationStatus: applicationStatus ?? this.applicationStatus,
      hadPriorApproval: hadPriorApproval ?? this.hadPriorApproval,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
