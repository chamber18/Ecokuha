import 'package:flutter_bloc/flutter_bloc.dart';
import 'register_event.dart';
import 'register_state.dart';
import '../../../domain/usecases/register_usecase.dart';
import '../../../domain/usecases/google_signin_usecase.dart';
import '../../../domain/entities/auth_user_entity.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final RegisterUseCase registerUseCase;
  final GoogleSignInUseCase googleSignInUseCase;

  RegisterBloc({
    required this.registerUseCase,
    required this.googleSignInUseCase,
  }) : super(const RegisterState()) {
    on<SubmitRegister>(_onSubmit);
    on<SocialRegisterPressed>(_onSocial);
  }

  Future<void> _onSubmit(
    SubmitRegister event,
    Emitter<RegisterState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null, success: false));

    try {
      final result = await registerUseCase(
        RegisterParams(
          email: event.email,
          password: event.password,
          confirmPassword: event.confirmPassword,
          role: UserRole.fromString(event.role ?? 'household'),
          fullName: '', // Provide empty string instead of null
        ),
      );

      result.fold(
        (failure) =>
            emit(state.copyWith(isLoading: false, error: failure.message)),
        (authResponse) => emit(state.copyWith(isLoading: false, success: true)),
      );
    } catch (e) {
      emit(
        state.copyWith(isLoading: false, error: 'An unexpected error occurred'),
      );
    }
  }

  Future<void> _onSocial(
    SocialRegisterPressed event,
    Emitter<RegisterState> emit,
  ) async {
    if (event.provider != 'google') {
      emit(
        state.copyWith(
          isLoading: false,
          error: '${event.provider} sign-in not implemented yet',
        ),
      );
      return;
    }

    emit(state.copyWith(isLoading: true, error: null, success: false));

    try {
      final result = await googleSignInUseCase(
        GoogleSignInParams(role: event.role),
      );

      result.fold(
        (failure) {
          emit(
            state.copyWith(
              isLoading: false,
              error: failure.message,
              success: false,
            ),
          );
        },
        (authResponse) {
          emit(state.copyWith(isLoading: false, error: null, success: true));
        },
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Google sign-in failed: ${e.toString()}',
          success: false,
        ),
      );
    }
  }
}
