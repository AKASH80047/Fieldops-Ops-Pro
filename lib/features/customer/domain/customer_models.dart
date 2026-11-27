import 'package:equatable/equatable.dart';

class ServiceItem extends Equatable {
  const ServiceItem(
    this.id,
    this.name,
    this.category,
    this.price,
    this.rating,
    this.minutes,
    this.icon,
  );
  final String id, name, category;
  final int price, minutes, icon;
  final double rating;
  @override
  List<Object?> get props => [id, name, category, price, rating, minutes, icon];
}

class CustomerBooking extends Equatable {
  const CustomerBooking(
    this.id,
    this.service,
    this.date,
    this.price,
    this.status,
  );
  final String id, service, date, status;
  final int price;
  @override
  List<Object?> get props => [id, service, date, price, status];
}

class SupportTicket extends Equatable {
  const SupportTicket(this.id, this.subject, this.status);
  final String id, subject, status;
  @override
  List<Object?> get props => [id, subject, status];
}
