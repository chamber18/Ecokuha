import 'package:equatable/equatable.dart';
import 'package:ecokuha/core/constants/firestore_fields/index.dart';
import '../../domain/entities/auth_user_entity.dart';

class AuthUserModel extends Equatable {
  final String id;
  final String email;
  final String? fullName;
  final UserRole role;
  final String? profileImageUrl;
  final bool isEmailVerified;
  final bool isProfileComplete;
  final String? applicationStatus;
  final bool hadPriorApproval;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final String? signInProvider;

  const AuthUserModel({
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

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    // Backward compatibility: accept full_name or first/last name pairs
    final legacyFirst =
        json[UserFields.firstNameSnake] ?? json[UserFields.firstName];
    final legacyLast =
        json[UserFields.lastNameSnake] ?? json[UserFields.lastName];
    final computedFull =
        json[UserFields.fullName] ??
        json['fullName'] ??
        ((legacyFirst != null || legacyLast != null)
            ? '${legacyFirst ?? ''} ${legacyLast ?? ''}'.trim()
            : null);
    return AuthUserModel(
      id: json[UserFields.id] ?? '',
      email: json[UserFields.email] ?? '',
      fullName: computedFull,
      role: UserRole.fromString(json[UserFields.role] ?? 'household'),
      profileImageUrl:
          json[UserFields.profileImageUrl] ??
          json[UserFields.profilePictureUrl] ??
          json[UserFields.avatar],
      isEmailVerified:
          json[UserFields.isEmailVerified] ??
          json[UserFields.emailVerified] ??
          false,
      isProfileComplete:
          json[UserFields.isProfileComplete] ??
          json[UserFields.profileComplete] ??
          false,
      applicationStatus: json[UserFields.applicationStatus],
      // hadPriorApproval: true if the collector was ever approved (approved_at field exists)
      hadPriorApproval:
          json['approved_at'] != null && json['approved_at'] != '',
      createdAt: json[UserFields.createdAtSnake] != null
          ? DateTime.parse(json[UserFields.createdAtSnake])
          : json[UserFields.createdAt] != null
          ? DateTime.parse(json[UserFields.createdAt])
          : DateTime.now(),
      lastLoginAt: json[UserFields.lastLoginAt] != null
          ? DateTime.parse(json[UserFields.lastLoginAt])
          : json[UserFields.lastLoginAtCamel] != null
          ? DateTime.parse(json[UserFields.lastLoginAtCamel])
          : null,
      signInProvider: json['signInProvider'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      UserFields.id: id,
      UserFields.email: email,
      // Write consolidated full name
      UserFields.fullName: fullName,
      UserFields.role: role.name,
      UserFields.profileImageUrl: profileImageUrl,
      UserFields.isEmailVerified: isEmailVerified,
      UserFields.isProfileComplete: isProfileComplete,
      UserFields.applicationStatus: applicationStatus,
      UserFields.createdAtSnake: createdAt.toIso8601String(),
      UserFields.lastLoginAt: lastLoginAt?.toIso8601String(),
      'signInProvider': signInProvider,
    };
  }

  factory AuthUserModel.fromEntity(AuthUserEntity entity) {
    return AuthUserModel(
      id: entity.id,
      email: entity.email,
      fullName: entity.fullName,
      role: entity.role,
      profileImageUrl: entity.profileImageUrl,
      isEmailVerified: entity.isEmailVerified,
      isProfileComplete: entity.isProfileComplete,
      applicationStatus: entity.applicationStatus,
      hadPriorApproval: entity.hadPriorApproval,
      createdAt: entity.createdAt,
      lastLoginAt: entity.lastLoginAt,
      signInProvider: entity.signInProvider,
    );
  }

  AuthUserEntity toEntity() {
    return AuthUserEntity(
      id: id,
      email: email,
      fullName: fullName,
      role: role,
      profileImageUrl: profileImageUrl,
      isEmailVerified: isEmailVerified,
      isProfileComplete: isProfileComplete,
      applicationStatus: applicationStatus,
      hadPriorApproval: hadPriorApproval,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
      signInProvider: signInProvider,
    );
  }

  AuthUserModel copyWith({
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
    return AuthUserModel(
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
  ];
}
