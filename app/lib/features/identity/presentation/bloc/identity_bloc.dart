import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/identity_repository.dart';

// Events
abstract class IdentityEvent {}

class LoadIdentity extends IdentityEvent {}

class UpdateProfileEvent extends IdentityEvent {
  final String displayName;
  final String email;
  final String bio;
  final String? avatarUrl;

  UpdateProfileEvent({
    required this.displayName,
    required this.email,
    required this.bio,
    this.avatarUrl,
  });
}

class RevokeSessionEvent extends IdentityEvent {
  final String sessionId;
  RevokeSessionEvent(this.sessionId);
}

// States
abstract class IdentityState {}

class IdentityInitial extends IdentityState {}

class IdentityLoading extends IdentityState {}

class IdentityLoaded extends IdentityState {
  final UserProfile profile;
  final List<UserSession> sessions;

  IdentityLoaded({
    required this.profile,
    required this.sessions,
  });

  IdentityLoaded copyWith({
    UserProfile? profile,
    List<UserSession>? sessions,
  }) {
    return IdentityLoaded(
      profile: profile ?? this.profile,
      sessions: sessions ?? this.sessions,
    );
  }
}

class IdentityError extends IdentityState {
  final String message;
  IdentityError(this.message);
}

// BLoC
class IdentityBloc extends Bloc<IdentityEvent, IdentityState> {
  final IdentityRepository repository;

  IdentityBloc({required this.repository}) : super(IdentityInitial()) {
    on<LoadIdentity>(_onLoadIdentity);
    on<UpdateProfileEvent>(_onUpdateProfile);
    on<RevokeSessionEvent>(_onRevokeSession);
  }

  Future<void> _onLoadIdentity(LoadIdentity event, Emitter<IdentityState> emit) async {
    emit(IdentityLoading());
    try {
      final profile = await repository.getProfile();
      final sessions = await repository.getSessions();
      emit(IdentityLoaded(profile: profile, sessions: sessions));
    } catch (e) {
      emit(IdentityError(e.toString()));
    }
  }

  Future<void> _onUpdateProfile(UpdateProfileEvent event, Emitter<IdentityState> emit) async {
    try {
      final updatedProfile = await repository.updateProfile(
        displayName: event.displayName,
        email: event.email,
        bio: event.bio,
        avatarUrl: event.avatarUrl,
      );
      final sessions = await repository.getSessions();
      emit(IdentityLoaded(profile: updatedProfile, sessions: sessions));
    } catch (e) {
      emit(IdentityError(e.toString()));
    }
  }

  Future<void> _onRevokeSession(RevokeSessionEvent event, Emitter<IdentityState> emit) async {
    try {
      await repository.revokeSession(event.sessionId);
      final sessions = await repository.getSessions();
      if (state is IdentityLoaded) {
        emit((state as IdentityLoaded).copyWith(sessions: sessions));
      }
    } catch (e) {
      emit(IdentityError(e.toString()));
    }
  }
}
