import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/technician_repository.dart';
import '../domain/technician_job.dart';

sealed class TechnicianJobsEvent extends Equatable {
  const TechnicianJobsEvent();
  @override
  List<Object?> get props => [];
}

class TechnicianJobsLoaded extends TechnicianJobsEvent {}

class TechnicianJobsFiltered extends TechnicianJobsEvent {
  const TechnicianJobsFiltered(this.query, this.status);
  final String query, status;
  @override
  List<Object?> get props => [query, status];
}

class TechnicianJobStatusChanged extends TechnicianJobsEvent {
  const TechnicianJobStatusChanged(this.id, this.status);
  final String id, status;
  @override
  List<Object?> get props => [id, status];
}

class TechnicianJobsState extends Equatable {
  const TechnicianJobsState(
    this.all,
    this.visible, {
    this.loading = false,
    this.error,
  });
  final List<TechnicianJob> all, visible;
  final bool loading;
  final String? error;
  @override
  List<Object?> get props => [all, visible, loading, error];
}

class TechnicianJobsBloc
    extends Bloc<TechnicianJobsEvent, TechnicianJobsState> {
  TechnicianJobsBloc(this.repo)
    : super(const TechnicianJobsState([], [], loading: true)) {
    on<TechnicianJobsLoaded>((e, emit) async {
      try {
        final x = await repo.jobs();
        emit(TechnicianJobsState(x, x));
      } catch (_) {
        emit(const TechnicianJobsState([], [], error: 'Could not load jobs'));
      }
    });
    on<TechnicianJobsFiltered>((e, emit) {
      final q = e.query.toLowerCase();
      emit(
        TechnicianJobsState(
          state.all,
          state.all
              .where(
                (x) =>
                    (e.status == 'All' || x.status == e.status) &&
                    (x.service.toLowerCase().contains(q) ||
                        x.customer.toLowerCase().contains(q)),
              )
              .toList(),
        ),
      );
    });
    on<TechnicianJobStatusChanged>((e, emit) async {
      try {
        final updated = await repo.update(e.id, e.status);
        final all = state.all
            .map((job) => job.id == updated.id ? updated : job)
            .toList();
        emit(TechnicianJobsState(all, all));
      } catch (_) {
        emit(
          TechnicianJobsState(
            state.all,
            state.visible,
            error: 'Could not update this job. Please try again.',
          ),
        );
      }
    });
  }
  final TechnicianRepository repo;
}

class TechnicianAvailabilityBloc extends Cubit<bool> {
  TechnicianAvailabilityBloc([TechnicianRepository? repository])
    : _repository = repository ?? MockTechnicianRepository(),
      super(false);
  final TechnicianRepository _repository;
  Future<void> load() async {
    try {
      emit((await _repository.profile()).available);
    } catch (_) {
      // Remain offline until the authenticated profile can be confirmed.
    }
  }

  Future<void> changed(bool value) async {
    try {
      final confirmed = await _repository.updateAvailability(value);
      emit(confirmed);
    } catch (_) {
      // Keep the last server-confirmed state. The UI must never claim Online
      // after a failed availability request.
    }
  }
}

class TechnicianNotificationsBloc extends Cubit<int> {
  TechnicianNotificationsBloc() : super(2);
  void read() => emit(0);
}

class TechnicianProfileBloc extends Cubit<String> {
  TechnicianProfileBloc() : super('Rahul Sharma');
  void rename(String value) => emit(value);
}

class TechnicianEarningsState extends Equatable {
  const TechnicianEarningsState({
    this.entries = const [],
    this.filter = 'Month',
    this.loading = false,
    this.error,
  });
  final List<TechnicianEarning> entries;
  final String filter;
  final bool loading;
  final String? error;
  @override
  List<Object?> get props => [entries, filter, loading, error];
}

class TechnicianEarningsBloc extends Cubit<TechnicianEarningsState> {
  TechnicianEarningsBloc(this.repository)
    : super(const TechnicianEarningsState(loading: true));
  final TechnicianRepository repository;

  Future<void> load() async {
    emit(TechnicianEarningsState(filter: state.filter, loading: true));
    try {
      emit(
        TechnicianEarningsState(
          entries: await repository.earnings(),
          filter: state.filter,
        ),
      );
    } catch (_) {
      emit(
        TechnicianEarningsState(
          filter: state.filter,
          error: 'Could not load verified earnings.',
        ),
      );
    }
  }

  void filter(String value) => emit(
    TechnicianEarningsState(
      entries: state.entries,
      filter: value,
      error: state.error,
    ),
  );
}

sealed class JobExecutionEvent extends Equatable {
  const JobExecutionEvent();
  @override
  List<Object?> get props => [];
}

class JobStepCompleted extends JobExecutionEvent {}

class ChecklistChanged extends JobExecutionEvent {
  const ChecklistChanged(this.index);
  final int index;
  @override
  List<Object?> get props => [index];
}

class JobExecutionState extends Equatable {
  const JobExecutionState(this.step, this.checks, {this.completed = false});
  final int step;
  final Set<int> checks;
  final bool completed;
  @override
  List<Object?> get props => [step, checks, completed];
}

class JobExecutionBloc extends Bloc<JobExecutionEvent, JobExecutionState> {
  JobExecutionBloc() : super(const JobExecutionState(0, {})) {
    on<JobStepCompleted>(
      (e, emit) => emit(
        JobExecutionState(
          state.step < 11 ? state.step + 1 : state.step,
          state.checks,
          completed: state.step >= 11,
        ),
      ),
    );
    on<ChecklistChanged>((e, emit) {
      final x = Set<int>.from(state.checks);
      x.contains(e.index) ? x.remove(e.index) : x.add(e.index);
      emit(JobExecutionState(state.step, x));
    });
  }
}

typedef TechnicianDashboardBloc = TechnicianJobsBloc;
typedef JobDetailsBloc = JobExecutionBloc;
typedef JobReportBloc = JobExecutionBloc;
typedef TechnicianLocationBloc = TechnicianAvailabilityBloc;
