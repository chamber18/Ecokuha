import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../domain/usecases/login_usecase.dart';
import '../../../domain/usecases/google_signin_usecase.dart';
import '../../../domain/entities/auth_user_entity.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

// Events
abstract class LoginEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoginSubmitted extends LoginEvent {
  final String email;
  final String password;

  LoginSubmitted({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class GoogleSignInRequested extends LoginEvent {}

class LoginReset extends LoginEvent {}

// States
abstract class LoginState extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {}

class LoginSuccess extends LoginState {
  final AuthUserEntity user;

  LoginSuccess({required this.user});

  @override
  List<Object?> get props => [user];
}

class LoginFailure extends LoginState {
  final String message;

  LoginFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

// BLoC
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final LoginUseCase loginUseCase;
  final GoogleSignInUseCase googleSignInUseCase;

  LoginBloc({required this.loginUseCase, required this.googleSignInUseCase})
    : super(LoginInitial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<LoginReset>(_onLoginReset);
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(LoginLoading());

    try {
      final result = await loginUseCase(
        LoginParams(email: event.email, password: event.password),
      );

      result.fold(
        (failure) => emit(LoginFailure(message: failure.message)),
        (authResponse) =>
            emit(LoginSuccess(user: authResponse.user!.toEntity())),
      );
    } catch (e) {
      emit(LoginFailure(message: 'An unexpected error occurred'));
    }
  }

  Future<void> _onGoogleSignInRequested(
    GoogleSignInRequested event,
    Emitter<LoginState> emit,
  ) async {
    if (kDebugMode) print('🔵 Google Sign-In requested');
    emit(LoginLoading());

    try {
      if (kDebugMode) print('🔵 Calling Google Sign-In use case...');
      final result = await googleSignInUseCase(const GoogleSignInParams());

      result.fold(
        (failure) {
          if (kDebugMode) print('🔴 Google Sign-In failed: ${failure.message}');
          emit(LoginFailure(message: failure.message));
        },
        (authResponse) {
          if (kDebugMode) print('🟢 Google Sign-In successful!');
          if (kDebugMode) print('🟢 User: ${authResponse.user?.email}');
          if (kDebugMode) print('🟢 Role: ${authResponse.user?.role}');
          if (kDebugMode) print('🟢 Profile complete: ${authResponse.user?.isProfileComplete}');
          emit(LoginSuccess(user: authResponse.user!.toEntity()));
        },
      );
    } catch (e) {
      if (kDebugMode) print('🔴 Google Sign-In exception: $e');
      emit(LoginFailure(message: 'Google sign-in failed: ${e.toString()}'));
    }
  }

  void _onLoginReset(LoginReset event, Emitter<LoginState> emit) {
    emit(LoginInitial());
  }
}
