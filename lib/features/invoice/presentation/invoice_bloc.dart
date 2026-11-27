import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class InvoiceEvent extends Equatable {
  const InvoiceEvent();
  @override
  List<Object?> get props => [];
}

class InvoiceRequested extends InvoiceEvent {}

class InvoiceState extends Equatable {
  const InvoiceState(this.ready);
  final bool ready;
  @override
  List<Object?> get props => [ready];
}

class InvoiceBloc extends Bloc<InvoiceEvent, InvoiceState> {
  InvoiceBloc() : super(const InvoiceState(false)) {
    on<InvoiceRequested>((e, emit) => emit(const InvoiceState(true)));
  }
}
