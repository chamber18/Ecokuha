import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;
  final dynamic details;

  const Failure(this.message, [this.code, this.details]);

  @override
  List<Object?> get props => [message, code, details];
}

/// Server-related failures
class ServerFailure extends Failure {
  const ServerFailure(super.message, [super.code, super.details]);
}

/// Network-related failures
class NetworkFailure extends Failure {
  const NetworkFailure(super.message, [super.code, super.details]);
}

/// Cache-related failures
class CacheFailure extends Failure {
  const CacheFailure(super.message, [super.code, super.details]);
}

/// Validation-related failures
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, [super.code, super.details]);
}

/// Authentication-related failures
class AuthFailure extends Failure {
  const AuthFailure(super.message, [super.code, super.details]);
}

/// Permission-related failures
class PermissionFailure extends Failure {
  const PermissionFailure(super.message, [super.code, super.details]);
}

/// Unexpected failures
class UnknownFailure extends Failure {
  const UnknownFailure(super.message, [super.code, super.details]);
}
