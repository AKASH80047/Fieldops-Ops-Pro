import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/auth_repository.dart';
import '../domain/user_role.dart';
import '../../../core/network/api_client.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class SignInRequested extends AuthEvent {
  const SignInRequested(this.email, this.password, this.role);
  final String email, password;
  final UserRole role;
  @override
  List<Object?> get props => [email, password, role];
}

sealed class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  const Authenticated(this.role);
  final UserRole role;
  @override
  List<Object?> get props => [role];
}

class AuthFailure extends AuthState {
  const AuthFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repo) : super(AuthInitial()) {
    on<SignInRequested>((e, emit) async {
      emit(AuthLoading());
      try {
        emit(Authenticated(await _repo.signIn(e.email, e.password, e.role)));
      } on ApiException catch (error) {
        emit(AuthFailure(error.message));
      } catch (_) {
        emit(const AuthFailure('We could not sign you in. Please try again.'));
      }
    });
  }
  final AuthRepository _repo;
}
