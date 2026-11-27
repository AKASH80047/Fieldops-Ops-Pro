import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../data/integration_repository.dart';

sealed class IntegrationState extends Equatable {
  const IntegrationState();
  @override
  List<Object?> get props => [];
}

class IntegrationInitial extends IntegrationState {}

class IntegrationLoading extends IntegrationState {}

class IntegrationSuccess<T> extends IntegrationState {
  const IntegrationSuccess(this.data);
  final T data;
  @override
  List<Object?> get props => [data];
}

class IntegrationFailure extends IntegrationState {
  const IntegrationFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class LocationBloc extends Cubit<IntegrationState> {
  LocationBloc(this.repo) : super(IntegrationInitial());
  final IntegrationRepository repo;
  Future<void> request() async {
    emit(IntegrationLoading());
    try {
      emit(IntegrationSuccess<Position>(await repo.currentLocation()));
    } catch (e) {
      emit(IntegrationFailure('$e'));
    }
  }
}

class MapsBloc extends LocationBloc {
  MapsBloc(super.repo);
}

class LiveTrackingBloc extends LocationBloc {
  LiveTrackingBloc(super.repo);
}

class AIAssistantBloc extends Cubit<IntegrationState> {
  AIAssistantBloc(this.repo) : super(IntegrationInitial());
  final IntegrationRepository repo;
  Future<void> ask(String task, String content) async {
    emit(IntegrationLoading());
    try {
      emit(IntegrationSuccess(await repo.ai(task, content)));
    } catch (e) {
      emit(IntegrationFailure('$e'));
    }
  }
}

class AIReportBloc extends AIAssistantBloc {
  AIReportBloc(super.repo);
}

class PaymentBloc extends Cubit<IntegrationState> {
  PaymentBloc(this.repo) : super(IntegrationInitial());
  final IntegrationRepository repo;
  Future<void> create(String invoiceId, String idempotencyKey) async {
    emit(IntegrationLoading());
    try {
      emit(
        IntegrationSuccess(await repo.createPayment(invoiceId, idempotencyKey)),
      );
    } catch (e) {
      emit(IntegrationFailure('$e'));
    }
  }
}

class NotificationBloc extends Cubit<IntegrationState> {
  NotificationBloc(this.repo) : super(IntegrationInitial());
  final IntegrationRepository repo;
  Future<void> load() async {
    emit(IntegrationLoading());
    try {
      emit(IntegrationSuccess(await repo.notifications()));
    } catch (e) {
      emit(IntegrationFailure('$e'));
    }
  }
}

class ChatBloc extends Cubit<IntegrationState> {
  ChatBloc(this.repo) : super(IntegrationInitial());
  final IntegrationRepository repo;
  Future<void> load(String id) async {
    emit(IntegrationLoading());
    try {
      emit(IntegrationSuccess(await repo.messages(id)));
    } catch (e) {
      emit(IntegrationFailure('$e'));
    }
  }

  Future<void> send(String id, String text) async {
    try {
      await repo.sendMessage(id, text);
      await load(id);
    } catch (e) {
      emit(IntegrationFailure('$e'));
    }
  }
}

class OfflineSyncBloc extends Cubit<IntegrationState> {
  OfflineSyncBloc(this.repo) : super(IntegrationInitial());
  final IntegrationRepository repo;
  Future<void> push(
    String key,
    String operation,
    String id,
    Map<String, dynamic> payload,
  ) async {
    emit(IntegrationLoading());
    try {
      emit(IntegrationSuccess(await repo.sync(key, operation, id, payload)));
    } catch (e) {
      emit(IntegrationFailure('$e'));
    }
  }
}

class InvoiceBloc extends Cubit<IntegrationState> {
  InvoiceBloc() : super(IntegrationInitial());
}
