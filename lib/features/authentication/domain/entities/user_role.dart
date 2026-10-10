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
