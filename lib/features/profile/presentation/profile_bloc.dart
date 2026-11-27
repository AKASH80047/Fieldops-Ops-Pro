import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class ProfileEvent extends Equatable {
  const ProfileEvent();
  @override
  List<Object?> get props => [];
}

class ProfileNameChanged extends ProfileEvent {
  const ProfileNameChanged(this.name);
  final String name;
  @override
  List<Object?> get props => [name];
}

class ProfileState extends Equatable {
  const ProfileState(this.name);
  final String name;
  @override
  List<Object?> get props => [name];
}

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc() : super(const ProfileState('Alex Morgan')) {
    on<ProfileNameChanged>((e, emit) => emit(ProfileState(e.name)));
  }
}
