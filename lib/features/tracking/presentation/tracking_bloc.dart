import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class TrackingEvent extends Equatable {
  const TrackingEvent();
  @override
  List<Object?> get props => [];
}

class LocationConsentChanged extends TrackingEvent {
  const LocationConsentChanged(this.allowed);
  final bool allowed;
  @override
  List<Object?> get props => [allowed];
}

class TrackingState extends Equatable {
  const TrackingState(this.consent);
  final bool consent;
  @override
  List<Object?> get props => [consent];
}

class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  TrackingBloc() : super(const TrackingState(false)) {
    on<LocationConsentChanged>((e, emit) => emit(TrackingState(e.allowed)));
  }
}
