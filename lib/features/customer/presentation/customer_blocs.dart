import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/customer_repository.dart';
import '../domain/customer_models.dart';

sealed class DashboardEvent extends Equatable {
  const DashboardEvent();
  @override
  List<Object?> get props => [];
}

class DashboardLoaded extends DashboardEvent {}

class DashboardState extends Equatable {
  const DashboardState({
    this.loading = false,
    this.services = const [],
    this.error,
  });
  final bool loading;
  final List<ServiceItem> services;
  final String? error;
  @override
  List<Object?> get props => [loading, services, error];
}

class CustomerDashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  CustomerDashboardBloc(this.repo) : super(const DashboardState()) {
    on<DashboardLoaded>((e, emit) async {
      emit(const DashboardState(loading: true));
      try {
        emit(DashboardState(services: await repo.services()));
      } catch (_) {
        emit(const DashboardState(error: 'Could not load services'));
      }
    });
  }
  final CustomerRepository repo;
}

sealed class ServiceEvent extends Equatable {
  const ServiceEvent();
  @override
  List<Object?> get props => [];
}

class ServicesLoaded extends ServiceEvent {}

class ServiceQueryChanged extends ServiceEvent {
  const ServiceQueryChanged(this.query, this.category);
  final String query, category;
  @override
  List<Object?> get props => [query, category];
}

class ServiceState extends Equatable {
  const ServiceState(this.all, this.visible, {this.loading = false});
  final List<ServiceItem> all, visible;
  final bool loading;
  @override
  List<Object?> get props => [all, visible, loading];
}

class ServiceListingBloc extends Bloc<ServiceEvent, ServiceState> {
  ServiceListingBloc(this.repo)
    : super(const ServiceState([], [], loading: true)) {
    on<ServicesLoaded>((e, emit) async {
      final x = await repo.services();
      emit(ServiceState(x, x));
    });
    on<ServiceQueryChanged>((e, emit) {
      final q = e.query.toLowerCase();
      emit(
        ServiceState(
          state.all,
          state.all
              .where(
                (x) =>
                    (e.category == 'All' || x.category == e.category) &&
                    x.name.toLowerCase().contains(q),
              )
              .toList(),
        ),
      );
    });
  }
  final CustomerRepository repo;
}

sealed class HistoryEvent extends Equatable {
  const HistoryEvent();
  @override
  List<Object?> get props => [];
}

class HistoryLoaded extends HistoryEvent {}

class HistoryFiltered extends HistoryEvent {
  const HistoryFiltered(this.filter);
  final String filter;
  @override
  List<Object?> get props => [filter];
}

class HistoryState extends Equatable {
  const HistoryState(this.all, this.visible);
  final List<CustomerBooking> all, visible;
  @override
  List<Object?> get props => [all, visible];
}

class BookingHistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  BookingHistoryBloc(this.repo) : super(const HistoryState([], [])) {
    on<HistoryLoaded>((e, emit) async {
      final x = await repo.bookings();
      emit(HistoryState(x, x));
    });
    on<HistoryFiltered>(
      (e, emit) => emit(
        HistoryState(
          state.all,
          e.filter == 'All'
              ? state.all
              : state.all.where((x) => x.status == e.filter).toList(),
        ),
      ),
    );
  }
  final CustomerRepository repo;
}

class NotificationsBloc extends Cubit<int> {
  NotificationsBloc() : super(3);
  void markRead() => emit(0);
}

class SupportTicketsBloc extends Cubit<List<SupportTicket>> {
  SupportTicketsBloc(CustomerRepository r) : super(const []) {
    r.tickets().then(emit);
  }
  void create(String subject) => emit([
    ...state,
    SupportTicket('T-${1000 + state.length}', subject, 'Open'),
  ]);
}
