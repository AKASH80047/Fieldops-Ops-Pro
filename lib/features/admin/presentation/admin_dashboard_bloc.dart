import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';

class AdminDashboardState extends Equatable {
  const AdminDashboardState({this.summary, this.loading = false, this.error});
  final AdminDashboardSummary? summary;
  final bool loading;
  final String? error;
  @override
  List<Object?> get props => [summary, loading, error];
}

class AdminDashboardBloc extends Cubit<AdminDashboardState> {
  AdminDashboardBloc(this.repository)
    : super(const AdminDashboardState(loading: true));
  final AdminRepository repository;

  Future<void> load() async {
    emit(const AdminDashboardState(loading: true));
    try {
      emit(AdminDashboardState(summary: await repository.dashboard()));
    } catch (_) {
      emit(
        const AdminDashboardState(error: 'Could not load the admin dashboard.'),
      );
    }
  }
}
