import '../domain/customer_models.dart';

abstract class CustomerRepository {
  Future<List<ServiceItem>> services();
  Future<List<CustomerBooking>> bookings();
  Future<CustomerBooking> createBooking(
    ServiceItem service,
    String date,
    String slot,
    String address,
    String coupon,
  );
  Future<List<SupportTicket>> tickets();
}

class MockCustomerRepository implements CustomerRepository {
  final _services = const [
    ServiceItem('ac1', 'AC deep service', 'AC Repair', 799, 4.9, 60, 0xe1d3),
    ServiceItem('pl1', 'Leak & tap repair', 'Plumbing', 499, 4.8, 45, 0xe800),
    ServiceItem(
      'el1',
      'Electrical safety check',
      'Electrical',
      599,
      4.7,
      50,
      0xe1a3,
    ),
    ServiceItem(
      'cl1',
      'Premium home cleaning',
      'Cleaning',
      1299,
      4.9,
      120,
      0xe3b7,
    ),
    ServiceItem(
      'ap1',
      'Washing machine repair',
      'Appliance Repair',
      699,
      4.6,
      75,
      0xe1b1,
    ),
  ];
  @override
  Future<List<ServiceItem>> services() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _services;
  }

  @override
  Future<List<CustomerBooking>> bookings() async => const [
    CustomerBooking(
      'FO-1842',
      'AC deep service',
      'Tomorrow · 10:00 AM',
      799,
      'In progress',
    ),
    CustomerBooking(
      'FO-1774',
      'Premium home cleaning',
      '09 Nov 2026',
      1299,
      'Completed',
    ),
    CustomerBooking(
      'FO-1701',
      'Leak & tap repair',
      '21 Oct 2026',
      499,
      'Cancelled',
    ),
  ];
  @override
  Future<CustomerBooking> createBooking(
    ServiceItem s,
    String d,
    String t,
    String a,
    String c,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return CustomerBooking(
      'FO-1908',
      s.name,
      '$d · $t',
      c == 'FIELD20' ? (s.price * .8).round() : s.price,
      'Upcoming',
    );
  }

  @override
  Future<List<SupportTicket>> tickets() async => const [
    SupportTicket('T-1024', 'Invoice correction', 'Open'),
    SupportTicket('T-981', 'Technician feedback', 'Resolved'),
  ];
}

final customerRepository = MockCustomerRepository();
