import 'package:dartz/dartz.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';
import '../entities/auth_user_entity.dart';

class GetCurrentUserUseCase implements UseCase<AuthUserEntity, NoParams> {
  final AuthRepository repository;

  GetCurrentUserUseCase({required this.repository});

  @override
  Future<Either<Failure, AuthUserEntity>> call(NoParams params) async {
    return await repository.getCurrentUser();
  }
}
