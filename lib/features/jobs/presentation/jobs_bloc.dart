import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class JobsEvent extends Equatable {
  const JobsEvent();
  @override
  List<Object?> get props => [];
}

class JobStatusChanged extends JobsEvent {
  const JobStatusChanged(this.status);
  final String status;
  @override
  List<Object?> get props => [status];
}

class JobsState extends Equatable {
  const JobsState(this.status);
  final String status;
  @override
  List<Object?> get props => [status];
}

class JobsBloc extends Bloc<JobsEvent, JobsState> {
  JobsBloc() : super(const JobsState('scheduled')) {
    on<JobStatusChanged>((e, emit) => emit(JobsState(e.status)));
  }
}
