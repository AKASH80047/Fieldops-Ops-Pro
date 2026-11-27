import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';
import '../../../core/network/api_client.dart';

sealed class AdminJobsEvent extends Equatable {
  const AdminJobsEvent();
  @override
  List<Object?> get props => [];
}

class AdminJobsLoaded extends AdminJobsEvent {}

class AdminJobsFiltered extends AdminJobsEvent {
  const AdminJobsFiltered(this.query, this.status);
  final String query, status;
  @override
  List<Object?> get props => [query, status];
}

class AdminJobAssigned extends AdminJobsEvent {
  const AdminJobAssigned(this.id, this.technician);
  final String id, technician;
  @override
  List<Object?> get props => [id, technician];
}

class AdminJobsState extends Equatable {
  const AdminJobsState(
    this.all,
    this.visible, {
    this.loading = false,
    this.error,
  });
  final List<AdminJob> all, visible;
  final bool loading;
  final String? error;
  @override
  List<Object?> get props => [all, visible, loading, error];
}

class JobManagementBloc extends Bloc<AdminJobsEvent, AdminJobsState> {
  JobManagementBloc(this.repo)
    : super(const AdminJobsState([], [], loading: true)) {
    on<AdminJobsLoaded>((e, emit) async {
      try {
        final jobs = await repo.jobs();
        emit(AdminJobsState(jobs, _filter(jobs)));
      } on ApiException catch (error) {
        emit(AdminJobsState(state.all, state.visible, error: error.message));
      } catch (_) {
        emit(
          AdminJobsState(
            state.all,
            state.visible,
            error: 'Could not load jobs.',
          ),
        );
      }
    });
    on<AdminJobsFiltered>((e, emit) {
      _query = e.query.trim().toLowerCase();
      _status = e.status;
      emit(
        AdminJobsState(state.all, _filter(state.all), loading: state.loading),
      );
    });
    on<AdminJobAssigned>((e, emit) async {
      try {
        final updated = await repo.assign(e.id, e.technician);
        final jobs = state.all
            .map((job) => job.id == updated.id ? updated : job)
            .toList();
        emit(AdminJobsState(jobs, _filter(jobs)));
      } on ApiException catch (error) {
        emit(AdminJobsState(state.all, state.visible, error: error.message));
      } catch (_) {
        emit(
          AdminJobsState(
            state.all,
            state.visible,
            error: 'Could not assign the technician.',
          ),
        );
      }
    });
  }
  final AdminRepository repo;
  String _query = '', _status = 'All';

  List<AdminJob> _filter(List<AdminJob> jobs) => jobs
      .where(
        (job) =>
            (_status == 'All' ||
                job.status == _status ||
                (_status == 'Upcoming' && job.status == 'Assigned')) &&
            (job.service.toLowerCase().contains(_query) ||
                job.customer.toLowerCase().contains(_query) ||
                job.id.toLowerCase().contains(_query)),
      )
      .toList();
}

class TechnicianManagementState extends Equatable {
  const TechnicianManagementState({
    this.members = const [],
    this.loading = false,
    this.error,
    this.processingDocumentId,
    this.processingTechnicianId,
  });

  final List<StaffMember> members;
  final bool loading;
  final String? error, processingDocumentId, processingTechnicianId;

  @override
  List<Object?> get props => [
    members,
    loading,
    error,
    processingDocumentId,
    processingTechnicianId,
  ];
}

class TechnicianManagementBloc extends Cubit<TechnicianManagementState> {
  TechnicianManagementBloc(this.repo)
    : super(const TechnicianManagementState(loading: true)) {
    reload();
  }
  final AdminRepository repo;

  Future<void> reload() async {
    emit(TechnicianManagementState(members: state.members, loading: true));
    try {
      emit(TechnicianManagementState(members: await repo.staff()));
    } on ApiException catch (error) {
      emit(
        TechnicianManagementState(members: state.members, error: error.message),
      );
    } catch (_) {
      emit(
        TechnicianManagementState(
          members: state.members,
          error: 'Could not load technicians.',
        ),
      );
    }
  }

  Future<void> search(String q) async {
    try {
      final members = await repo.staff();
      final query = q.toLowerCase();
      emit(
        TechnicianManagementState(
          members: members
              .where(
                (member) =>
                    member.name.toLowerCase().contains(query) ||
                    member.skill.toLowerCase().contains(query),
              )
              .toList(),
        ),
      );
    } catch (_) {
      emit(
        TechnicianManagementState(
          members: state.members,
          error: 'Could not search technicians.',
        ),
      );
    }
  }

  Future<String?> review(String id, String status, {String? reason}) async {
    emit(
      TechnicianManagementState(
        members: state.members,
        processingTechnicianId: id,
      ),
    );
    try {
      await repo.reviewTechnician(id, status, reason: reason);
      emit(TechnicianManagementState(members: await repo.staff()));
      return null;
    } on ApiException catch (error) {
      emit(
        TechnicianManagementState(members: state.members, error: error.message),
      );
      return error.message;
    } catch (_) {
      const message = 'Could not update technician verification.';
      emit(TechnicianManagementState(members: state.members, error: message));
      return message;
    }
  }

  Future<String?> reviewDocument(
    String technicianId,
    String documentId,
    String status, {
    String? reason,
  }) async {
    emit(
      TechnicianManagementState(
        members: state.members,
        processingDocumentId: documentId,
      ),
    );
    try {
      await repo.reviewTechnicianDocument(
        technicianId,
        documentId,
        status,
        reason: reason,
      );
      emit(TechnicianManagementState(members: await repo.staff()));
      return null;
    } on ApiException catch (error) {
      emit(
        TechnicianManagementState(members: state.members, error: error.message),
      );
      return error.message;
    } catch (_) {
      const message = 'Could not review this document.';
      emit(TechnicianManagementState(members: state.members, error: message));
      return message;
    }
  }
}

class ManagementState extends Equatable {
  const ManagementState({
    this.records = const [],
    this.loading = false,
    this.error,
    this.processingId,
  });

  final List<ManagedRecord> records;
  final bool loading;
  final String? error;
  final String? processingId;

  @override
  List<Object?> get props => [records, loading, error, processingId];
}

class ManagementCubit extends Cubit<ManagementState> {
  ManagementCubit(this.repo, this.kind)
    : super(const ManagementState(loading: true)) {
    reload();
  }
  final AdminRepository repo;
  final String kind;

  Future<void> reload() async {
    emit(ManagementState(records: state.records, loading: true));
    try {
      emit(ManagementState(records: await repo.records(kind)));
    } on ApiException catch (error) {
      emit(ManagementState(records: state.records, error: error.message));
    } catch (_) {
      emit(
        ManagementState(
          records: state.records,
          error: 'Could not load ${kind.replaceAll('-', ' ')}.',
        ),
      );
    }
  }

  Future<void> add(String title, String subtitle) async {
    emit(ManagementState(records: state.records, loading: true));
    try {
      emit(ManagementState(records: await repo.add(kind, title, subtitle)));
    } on ApiException catch (error) {
      emit(ManagementState(records: state.records, error: error.message));
    } catch (_) {
      emit(
        ManagementState(
          records: state.records,
          error: 'Could not save this record.',
        ),
      );
    }
  }

  Future<String?> performAction(
    String id,
    String action, {
    Map<String, dynamic> data = const {},
  }) async {
    emit(ManagementState(records: state.records, processingId: id));
    try {
      await repo.performRecordAction(kind, id, action, data: data);
      emit(ManagementState(records: await repo.records(kind)));
      return null;
    } on ApiException catch (error) {
      emit(ManagementState(records: state.records, error: error.message));
      return error.message;
    } catch (_) {
      const message = 'Could not complete this Admin action.';
      emit(ManagementState(records: state.records, error: message));
      return message;
    }
  }
}

class AdminDateFilterBloc extends Cubit<String> {
  AdminDateFilterBloc() : super('Last 7 Days');
  void select(String value) => emit(value);
}

class AdminNotificationsBloc extends Cubit<int> {
  AdminNotificationsBloc() : super(0);
  void markRead() => emit(0);
}

class ReportsBloc extends Cubit<String> {
  ReportsBloc() : super('Revenue');
  void select(String value) => emit(value);
}

class RolePermissionBloc extends Cubit<Map<String, bool>> {
  RolePermissionBloc()
    : super({
        'Manage jobs': true,
        'Manage team': true,
        'Financial reports': false,
      });
  void toggle(String key, bool value) => emit({...state, key: value});
}

typedef JobAssignmentBloc = JobManagementBloc;
typedef JobCalendarBloc = AdminDateFilterBloc;
typedef CustomerManagementBloc = ManagementCubit;
typedef ServiceManagementBloc = ManagementCubit;
typedef FinancialManagementBloc = ManagementCubit;
typedef TeamManagementBloc = ManagementCubit;
typedef AdminSettingsBloc = ManagementCubit;
