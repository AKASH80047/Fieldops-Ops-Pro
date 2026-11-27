import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../customer/data/customer_repository.dart';
import '../../customer/domain/customer_models.dart';

sealed class BookingEvent extends Equatable {
  const BookingEvent();
  @override
  List<Object?> get props => [];
}

class BookingServiceSelected extends BookingEvent {
  const BookingServiceSelected(this.service);
  final ServiceItem service;
  @override
  List<Object?> get props => [service];
}

class BookingScheduleSelected extends BookingEvent {
  const BookingScheduleSelected(this.date, this.slot);
  final String date, slot;
  @override
  List<Object?> get props => [date, slot];
}

class BookingAddressSelected extends BookingEvent {
  const BookingAddressSelected(this.address);
  final String address;
  @override
  List<Object?> get props => [address];
}

class BookingCouponApplied extends BookingEvent {
  const BookingCouponApplied(this.code);
  final String code;
  @override
  List<Object?> get props => [code];
}

class BookingSubmitted extends BookingEvent {}

class BookingState extends Equatable {
  const BookingState({
    this.service,
    this.date = '',
    this.slot = '',
    this.address = '24 Park Street, Bengaluru',
    this.coupon = '',
    this.saving = false,
    this.confirmed,
    this.error,
  });
  final ServiceItem? service;
  final String date, slot, address, coupon;
  final bool saving;
  final CustomerBooking? confirmed;
  final String? error;
  BookingState copyWith({
    ServiceItem? service,
    String? date,
    String? slot,
    String? address,
    String? coupon,
    bool? saving,
    CustomerBooking? confirmed,
    String? error,
  }) => BookingState(
    service: service ?? this.service,
    date: date ?? this.date,
    slot: slot ?? this.slot,
    address: address ?? this.address,
    coupon: coupon ?? this.coupon,
    saving: saving ?? this.saving,
    confirmed: confirmed,
    error: error,
  );
  @override
  List<Object?> get props => [
    service,
    date,
    slot,
    address,
    coupon,
    saving,
    confirmed,
    error,
  ];
}

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  BookingBloc(this.repo) : super(const BookingState()) {
    on<BookingServiceSelected>(
      (e, emit) => emit(state.copyWith(service: e.service)),
    );
    on<BookingScheduleSelected>(
      (e, emit) => emit(state.copyWith(date: e.date, slot: e.slot)),
    );
    on<BookingAddressSelected>(
      (e, emit) => emit(state.copyWith(address: e.address)),
    );
    on<BookingCouponApplied>(
      (e, emit) => emit(
        state.copyWith(
          coupon: e.code == 'FIELD20' ? e.code : '',
          error: e.code == 'FIELD20' ? null : 'Invalid coupon code',
        ),
      ),
    );
    on<BookingSubmitted>((e, emit) async {
      if (state.service == null || state.date.isEmpty || state.slot.isEmpty) {
        emit(state.copyWith(error: 'Complete service and schedule details'));
        return;
      }
      emit(state.copyWith(saving: true));
      final b = await repo.createBooking(
        state.service!,
        state.date,
        state.slot,
        state.address,
        state.coupon,
      );
      emit(state.copyWith(saving: false, confirmed: b));
    });
  }
  final CustomerRepository repo;
}
