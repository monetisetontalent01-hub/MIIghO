import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../data/auth_repository.dart';

// Events
abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}
class OTPSendRequested extends AuthEvent {
  final String phone;
  OTPSendRequested(this.phone);
  @override
  List<Object?> get props => [phone];
}
class OTPVerifyRequested extends AuthEvent {
  final String phone;
  final String code;
  OTPVerifyRequested(this.phone, this.code);
  @override
  List<Object?> get props => [phone, code];
}
class LogoutRequested extends AuthEvent {}

// States
abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class OTPSent extends AuthState {
  final String phone;
  OTPSent(this.phone);
  @override
  List<Object?> get props => [phone];
}
class AuthAuthenticated extends AuthState {}
class AuthUnauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<OTPSendRequested>(_onOTPSendRequested);
    on<OTPVerifyRequested>(_onOTPVerifyRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onAuthCheckRequested(AuthCheckRequested event, Emitter<AuthState> emit) async {
    final token = await authRepository.getAccessToken();
    if (token != null) {
      emit(AuthAuthenticated());
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onOTPSendRequested(OTPSendRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await authRepository.sendOTP(event.phone);
      emit(OTPSent(event.phone));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onOTPVerifyRequested(OTPVerifyRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await authRepository.verifyOTP(event.phone, event.code, 'device_id_stub');
      emit(AuthAuthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    await authRepository.logout();
    emit(AuthUnauthenticated());
  }
}
