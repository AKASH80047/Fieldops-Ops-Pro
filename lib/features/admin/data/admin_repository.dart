import '../domain/admin_models.dart';
import '../../../core/network/api_client.dart';

abstract class AdminRepository {
  Future<AdminDashboardSummary> dashboard();
  Future<List<AdminJob>> jobs();
  Future<List<StaffMember>> staff();
  Future<List<ManagedRecord>> records(String kind);
  Future<AdminJob> assign(String id, String technician);
  Future<List<ManagedRecord>> add(String kind, String title, String subtitle);
  Future<void> reviewTechnician(String id, String status, {String? reason});
  Future<void> reviewTechnicianDocument(
    String technicianId,
    String documentId,
    String status, {
    String? reason,
  });
  Future<void> performRecordAction(
    String kind,
    String id,
    String action, {
    Map<String, dynamic> data = const {},
  });
}

class MockAdminRepository implements AdminRepository {
  @override
  Future<AdminDashboardSummary> dashboard() async {
    final payments = store['payments'] ?? const <ManagedRecord>[];
    final payouts = store['payouts'] ?? const <ManagedRecord>[];
    final complaints = store['complaints'] ?? const <ManagedRecord>[];
    return AdminDashboardSummary(
      totalCustomers: (store['customers'] ?? const []).length,
      totalTechnicians: staffData.length,
      verifiedTechnicians: staffData
          .where((staff) => staff.verificationStatus == 'APPROVED')
          .length,
      pendingTechnicianApprovals: staffData
          .where((staff) => staff.verificationStatus != 'APPROVED')
          .length,
      totalBookings: jobData.length,
      activeJobs: jobData
          .where(
            (job) => job.status == 'In progress' || job.status == 'Upcoming',
          )
          .length,
      completedJobs: jobData.where((job) => job.status == 'Completed').length,
      cancelledBookings: jobData
          .where((job) => job.status == 'Cancelled')
          .length,
      totalRevenue: payments
          .where((payment) => payment.status == 'Paid')
          .fold(0, (sum, payment) => sum + _recordAmount(payment)),
      pendingPayments: payments
          .where((payment) => payment.status != 'Paid')
          .fold(0, (sum, payment) => sum + _recordAmount(payment)),
      pendingPayouts: payouts.where((payout) => payout.status != 'Paid').length,
      pendingComplaints: complaints
          .where((complaint) => complaint.status != 'Resolved')
          .length,
    );
  }

  final jobData = <AdminJob>[
    const AdminJob(
      'FO-1842',
      'Alex Morgan',
      'AC maintenance',
      'Unassigned',
      'Pending',
      799,
    ),
    const AdminJob(
      'FO-1844',
      'Priya Singh',
      'Leak repair',
      'Rahul Sharma',
      'In progress',
      599,
    ),
    const AdminJob(
      'FO-1831',
      'Rohan Mehta',
      'Electrical inspection',
      'Sameer Khan',
      'Completed',
      899,
    ),
  ];
  final staffData = <StaffMember>[
    const StaffMember(
      'T-21',
      'Rahul Sharma',
      'Technician',
      'AC & Appliances',
      true,
      4.9,
    ),
    const StaffMember(
      'T-22',
      'Sameer Khan',
      'Technician',
      'Electrical',
      true,
      4.8,
    ),
    const StaffMember(
      'M-03',
      'Neha Kapoor',
      'Manager',
      'Operations',
      true,
      4.9,
    ),
    StaffMember(
      'T-24',
      'Arjun Verma',
      'Technician',
      'Plumbing & Repairs',
      false,
      0,
      'PENDING_VERIFICATION',
      [
        TechnicianDocument(
          id: 'DOC-201',
          type: 'Government ID',
          status: 'PENDING',
          uploadedAt: DateTime(2026, 11, 17, 10, 30),
        ),
        TechnicianDocument(
          id: 'DOC-202',
          type: 'Trade certificate',
          status: 'PENDING',
          uploadedAt: DateTime(2026, 11, 17, 10, 34),
        ),
      ],
      const ['Central Delhi'],
    ),
  ];
  final store = <String, List<ManagedRecord>>{
    'customers': [
      const ManagedRecord('C-101', 'Alex Morgan', '12 bookings · ₹18,420'),
      const ManagedRecord('C-102', 'Priya Singh', '8 bookings · ₹9,820'),
    ],
    'services': [
      const ManagedRecord('S-01', 'AC deep service', '₹799 · 60 min'),
      const ManagedRecord('S-02', 'Leak repair', '₹499 · 45 min'),
    ],
    'service-categories': [
      const ManagedRecord('CAT-01', 'Home maintenance', '4 active services'),
      const ManagedRecord('CAT-02', 'Appliances', '6 active services'),
      const ManagedRecord('CAT-03', 'Cleaning', '3 active services'),
    ],
    'invoices': [
      const ManagedRecord('INV-2041', 'Invoice #2041', '₹1,299 · Paid'),
      const ManagedRecord('INV-2042', 'Invoice #2042', '₹799 · Pending'),
    ],
    'payments': [
      const ManagedRecord(
        'PAY-301',
        'Invoice #2041',
        '₹1,299 · UPI',
        status: 'Paid',
      ),
      const ManagedRecord(
        'PAY-302',
        'Invoice #2042',
        '₹799 · Cash',
        active: false,
        status: 'Pending',
      ),
    ],
    'cash-collections': [
      const ManagedRecord(
        'CC-101',
        'Cash receipt · Rahul Sharma',
        'Invoice INV-2042 · ₹799',
        active: false,
        status: 'Submitted',
      ),
    ],
    'refunds': [
      const ManagedRecord(
        'RF-101',
        'Refund · Invoice INV-2041',
        '₹299 · Customer request',
        active: false,
        status: 'Requested',
      ),
    ],
    'payouts': [
      const ManagedRecord(
        'PO-101',
        'Rahul Sharma',
        '₹639 · Week ending 18 Nov',
        active: false,
        status: 'Requested',
      ),
      const ManagedRecord(
        'PO-102',
        'Sameer Khan',
        '₹720 · Week ending 11 Nov',
        status: 'Paid',
      ),
    ],
    'complaints': [
      const ManagedRecord(
        'CMP-101',
        'Technician arrived late',
        'Priya Singh · High priority',
        active: false,
        status: 'Open',
      ),
      const ManagedRecord(
        'CMP-102',
        'Service quality feedback',
        'Alex Morgan · Normal priority',
        status: 'Resolved',
      ),
    ],
    'settlements': [
      const ManagedRecord(
        'ST-101',
        'Rahul Sharma',
        'Net ₹639 · Job FO-1842',
        active: false,
        status: 'Pending',
      ),
    ],
    'team': [
      const ManagedRecord('U-01', 'Maya Patel', 'Super Admin'),
      const ManagedRecord('U-02', 'Neha Kapoor', 'Manager'),
    ],
  };
  @override
  Future<List<AdminJob>> jobs() async => List.of(jobData);
  @override
  Future<List<StaffMember>> staff() async => List.of(staffData);
  @override
  Future<List<ManagedRecord>> records(String kind) async =>
      List.of(store[kind] ?? []);
  @override
  Future<AdminJob> assign(String id, String technician) async {
    final i = jobData.indexWhere((x) => x.id == id);
    if (i < 0) throw StateError('Job not found');
    if (!jobData[i].canAssign) {
      throw const ApiException(
        'Only pending or upcoming jobs can be assigned.',
      );
    }
    final selected = staffData
        .where((item) => item.id == technician)
        .firstOrNull;
    jobData[i] = jobData[i].copyWith(
      technician: selected?.name ?? technician,
      status: 'Upcoming',
    );
    return jobData[i];
  }

  void createDemoJob(String customer, String service, int amount) {
    jobData.insert(
      0,
      AdminJob(
        'DEMO-${jobData.length + 1}',
        customer,
        service,
        'Unassigned',
        'Pending',
        amount,
      ),
    );
  }

  @override
  Future<List<ManagedRecord>> add(
    String kind,
    String title,
    String subtitle,
  ) async {
    store
        .putIfAbsent(kind, () => [])
        .add(
          ManagedRecord(
            '${kind[0].toUpperCase()}-${100 + store[kind]!.length}',
            title,
            subtitle,
          ),
        );
    return List.of(store[kind]!);
  }

  @override
  Future<void> reviewTechnician(
    String id,
    String status, {
    String? reason,
  }) async {
    final index = staffData.indexWhere((staff) => staff.id == id);
    if (index < 0) throw StateError('Technician not found');
    final staff = staffData[index];
    staffData[index] = staff.copyWith(
      active: status == 'APPROVED',
      verificationStatus: status,
    );
  }

  @override
  Future<void> reviewTechnicianDocument(
    String technicianId,
    String documentId,
    String status, {
    String? reason,
  }) async {
    final staffIndex = staffData.indexWhere(
      (staff) => staff.id == technicianId,
    );
    if (staffIndex < 0) throw StateError('Technician not found');
    final staff = staffData[staffIndex];
    final documentIndex = staff.documents.indexWhere(
      (document) => document.id == documentId,
    );
    if (documentIndex < 0) throw StateError('Document not found');
    final documents = List<TechnicianDocument>.of(staff.documents);
    documents[documentIndex] = documents[documentIndex].copyWith(
      status: status,
      rejectionReason: status == 'REJECTED' ? reason : null,
      reviewedAt: DateTime.now(),
    );
    staffData[staffIndex] = staff.copyWith(documents: documents);
  }

  @override
  Future<void> performRecordAction(
    String kind,
    String id,
    String action, {
    Map<String, dynamic> data = const {},
  }) async {
    final records = store[kind];
    if (records == null) return;
    final index = records.indexWhere((record) => record.id == id);
    if (index < 0) return;
    final record = records[index];
    final status = switch ((kind, action)) {
      ('refunds', 'process') => 'Succeeded',
      ('settlements', 'available') => 'Available',
      ('settlements', 'hold') => 'Held',
      ('settlements', 'reverse') => 'Reversed',
      ('cash-collections', 'verify') => 'Verified',
      (_, 'suspend') => 'Suspended',
      (_, 'activate') || (_, 'enable') => 'Active',
      (_, 'disable') => 'Disabled',
      (_, 'start') => 'In progress',
      (_, 'resolve') => 'Resolved',
      (_, 'reopen') => 'Reopened',
      (_, 'approve') => 'Approved',
      (_, 'process') => 'Processing',
      (_, 'mark-paid') => 'Paid',
      (_, 'fail') => 'Failed',
      (_, 'reject') => 'Rejected',
      _ => record.status,
    };
    records[index] = record.copyWith(
      active: const {
        'activate',
        'enable',
        'resolve',
        'mark-paid',
        'verify',
        'available',
      }.contains(action),
      status: status,
    );
  }

  double _recordAmount(ManagedRecord record) {
    final match = RegExp(
      r'₹([0-9,]+(?:\.[0-9]+)?)',
    ).firstMatch(record.subtitle);
    return double.tryParse((match?.group(1) ?? '0').replaceAll(',', '')) ?? 0;
  }
}

class ApiAdminRepository implements AdminRepository {
  ApiAdminRepository(this.api);
  final ApiClient api;

  @override
  Future<AdminDashboardSummary> dashboard() async {
    final response = await api.get<Map<String, dynamic>>('/admin/dashboard');
    final data = response.data?['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw const ApiException('Invalid admin dashboard response');
    }
    int count(String key) => (data[key] as num?)?.toInt() ?? 0;
    double amount(String key) => double.tryParse('${data[key] ?? 0}') ?? 0;
    return AdminDashboardSummary(
      totalCustomers: count('totalCustomers'),
      totalTechnicians: count('totalTechnicians'),
      verifiedTechnicians: count('verifiedTechnicians'),
      pendingTechnicianApprovals: count('pendingTechnicianApprovals'),
      totalBookings: count('totalBookings'),
      activeJobs: count('activeJobs'),
      completedJobs: count('completedJobs'),
      cancelledBookings: count('cancelledBookings'),
      totalRevenue: amount('totalRevenue'),
      pendingPayments: amount('pendingPayments'),
      pendingPayouts: count('pendingPayouts'),
      pendingComplaints: count('pendingComplaints'),
    );
  }

  @override
  Future<List<AdminJob>> jobs() async {
    final response = await api.get<Map<String, dynamic>>('/admin/jobs');
    final rows = response.data?['data'] as List<dynamic>? ?? const [];
    return rows.whereType<Map<String, dynamic>>().map((row) {
      final booking = row['booking'] as Map<String, dynamic>? ?? const {};
      final customer = booking['customer'] as Map<String, dynamic>? ?? const {};
      final user = customer['user'] as Map<String, dynamic>? ?? const {};
      final service = booking['service'] as Map<String, dynamic>? ?? const {};
      final assignments = row['assignments'] as List<dynamic>? ?? const [];
      final assignment = assignments
          .whereType<Map<String, dynamic>>()
          .where((item) => item['unassignedAt'] == null)
          .firstOrNull;
      final tech = assignment?['technician'] as Map<String, dynamic>?;
      final techUser = tech?['user'] as Map<String, dynamic>?;
      return AdminJob(
        '${row['id']}',
        '${user['name'] ?? 'Customer'}',
        '${service['name'] ?? 'Service'}',
        '${techUser?['name'] ?? 'Unassigned'}',
        _status('${row['status']}'),
        double.tryParse(
              '${booking['finalPrice'] ?? booking['estimatedPrice'] ?? 0}',
            )?.round() ??
            0,
      );
    }).toList();
  }

  @override
  Future<List<StaffMember>> staff() async {
    final response = await api.get<Map<String, dynamic>>('/admin/technicians');
    final rows = response.data?['data'] as List<dynamic>? ?? const [];
    return rows.whereType<Map<String, dynamic>>().map((row) {
      final user = row['user'] as Map<String, dynamic>? ?? const {};
      final skills = row['skills'] as List<dynamic>? ?? const [];
      final documents = (row['documents'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (document) => TechnicianDocument(
              id: '${document['id']}',
              type: '${document['type'] ?? 'Document'}',
              status: '${document['status'] ?? 'PENDING'}',
              rejectionReason: document['rejectionReason'] as String?,
              uploadedAt: DateTime.tryParse('${document['uploadedAt'] ?? ''}'),
              reviewedAt: DateTime.tryParse('${document['reviewedAt'] ?? ''}'),
            ),
          )
          .toList();
      final serviceAreas = (row['serviceAreas'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((assignment) => _map(assignment['serviceArea']))
          .map((area) => '${area['name'] ?? ''}'.trim())
          .where((name) => name.isNotEmpty)
          .toList();
      return StaffMember(
        '${row['id']}',
        '${user['name'] ?? 'Technician'}',
        'Technician',
        skills.isEmpty ? 'Skills not set' : skills.join(', '),
        row['available'] == true,
        double.tryParse('${row['rating'] ?? 0}') ?? 0,
        '${row['verificationStatus'] ?? 'DRAFT'}',
        documents,
        serviceAreas,
      );
    }).toList();
  }

  @override
  Future<List<ManagedRecord>> records(String kind) async {
    if (kind == 'customers') {
      final response = await api.get<Map<String, dynamic>>('/admin/customers');
      final rows = response.data?['data'] as List<dynamic>? ?? const [];
      return rows.whereType<Map<String, dynamic>>().map((row) {
        final user = row['user'] as Map<String, dynamic>? ?? const {};
        final counts = row['_count'] as Map<String, dynamic>? ?? const {};
        return ManagedRecord(
          '${row['id']}',
          '${user['name'] ?? 'Customer'}',
          '${user['email'] ?? ''} · ${counts['bookings'] ?? 0} bookings · ${user['status'] ?? 'ACTIVE'}',
          active: user['status'] == 'ACTIVE',
          status: _label('${user['status'] ?? 'ACTIVE'}'),
        );
      }).toList();
    }
    if (kind == 'service-categories') {
      final response = await api.get<Map<String, dynamic>>(
        '/admin/service-categories',
      );
      return _rows(response.data).map((row) {
        final counts = _map(row['_count']);
        final services = row['services'] as List<dynamic>?;
        final serviceCount =
            (counts['services'] as num?)?.toInt() ?? services?.length ?? 0;
        return ManagedRecord(
          '${row['id']}',
          '${row['name'] ?? 'Service category'}',
          '$serviceCount ${serviceCount == 1 ? 'service' : 'services'}',
          active: row['active'] == true,
          status: row['active'] == true ? 'Active' : 'Disabled',
        );
      }).toList();
    }
    if (kind == 'services') {
      final response = await api.get<Map<String, dynamic>>('/admin/services');
      return _rows(response.data).map((row) {
        final category = _map(row['category']);
        final categoryName = '${category['name'] ?? 'Uncategorised'}';
        return ManagedRecord(
          '${row['id']}',
          '${row['name'] ?? 'Service'}',
          '$categoryName · ₹${row['basePrice'] ?? 0} · ${row['durationMinutes'] ?? 0} min',
          active: row['active'] == true,
          status: row['active'] == true ? 'Active' : 'Disabled',
        );
      }).toList();
    }
    if (kind == 'invoices') {
      final response = await api.get<Map<String, dynamic>>('/invoices');
      final rows = response.data?['data'] as List<dynamic>? ?? const [];
      return rows
          .whereType<Map<String, dynamic>>()
          .map(
            (row) => ManagedRecord(
              '${row['id']}',
              'Invoice ${row['number'] ?? ''}',
              '₹${row['total'] ?? 0} · ${row['status'] ?? 'Pending'}',
              active: row['status'] == 'PAID',
              status: _label('${row['status'] ?? 'PENDING'}'),
            ),
          )
          .toList();
    }
    if (kind == 'payments') {
      final response = await api.get<Map<String, dynamic>>('/admin/payments');
      return _rows(response.data).map((row) {
        final invoice = _map(row['invoice']);
        final status = '${row['status'] ?? 'PENDING'}';
        final invoiceNumber = '${invoice['number'] ?? ''}'.trim();
        final provider = '${row['provider'] ?? 'Payment'}';
        return ManagedRecord(
          '${row['id']}',
          invoiceNumber.isEmpty
              ? 'Payment ${_shortId(row['id'])}'
              : 'Invoice $invoiceNumber',
          '₹${row['amount'] ?? 0} · $provider',
          active: status == 'PAID',
          status: _label(status),
        );
      }).toList();
    }
    if (kind == 'payouts') {
      final response = await api.get<Map<String, dynamic>>('/admin/payouts');
      return _rows(response.data).map((row) {
        final technician = _map(row['technician']);
        final user = _map(technician['user']);
        final status = '${row['status'] ?? 'REQUESTED'}';
        final reference = '${row['reference'] ?? ''}'.trim();
        return ManagedRecord(
          '${row['id']}',
          '${user['name'] ?? 'Technician payout'}',
          '₹${row['amount'] ?? 0}${reference.isEmpty ? '' : ' · Ref $reference'}',
          active: status == 'PAID',
          status: _label(status),
        );
      }).toList();
    }
    if (kind == 'complaints') {
      final response = await api.get<Map<String, dynamic>>('/admin/complaints');
      return _rows(response.data).map((row) {
        final customer = _map(row['customer']);
        final user = _map(customer['user']);
        final status = '${row['status'] ?? 'OPEN'}';
        final priority = _label('${row['priority'] ?? 'NORMAL'}');
        return ManagedRecord(
          '${row['id']}',
          '${row['subject'] ?? 'Support complaint'}',
          '${user['name'] ?? 'Customer'} · $priority priority',
          active: status == 'RESOLVED',
          status: _label(status),
        );
      }).toList();
    }
    if (kind == 'cash-collections') {
      final response = await api.get<Map<String, dynamic>>(
        '/admin/cash-collections',
      );
      return _rows(response.data).map((row) {
        final technician = _map(row['technician']);
        final user = _map(technician['user']);
        final payment = _map(row['payment']);
        final invoice = _map(payment['invoice']);
        final status = '${row['status'] ?? 'SUBMITTED'}';
        final invoiceNumber = '${invoice['number'] ?? ''}'.trim();
        return ManagedRecord(
          '${row['id']}',
          'Cash receipt · ${user['name'] ?? 'Technician'}',
          '${invoiceNumber.isEmpty ? 'Invoice' : 'Invoice $invoiceNumber'} · ₹${row['amount'] ?? payment['amount'] ?? 0}',
          active: status == 'VERIFIED',
          status: _label(status),
        );
      }).toList();
    }
    if (kind == 'refunds') {
      final response = await api.get<Map<String, dynamic>>('/admin/refunds');
      return _rows(response.data).map((row) {
        final payment = _map(row['payment']);
        final invoice = _map(payment['invoice']);
        final status = '${row['status'] ?? 'REQUESTED'}';
        final invoiceNumber = '${invoice['number'] ?? ''}'.trim();
        final reason = '${row['reason'] ?? ''}'.trim();
        return ManagedRecord(
          '${row['id']}',
          invoiceNumber.isEmpty
              ? 'Refund ${_shortId(row['id'])}'
              : 'Refund · Invoice $invoiceNumber',
          '₹${row['amount'] ?? 0}${reason.isEmpty ? '' : ' · $reason'}',
          active: status == 'SUCCEEDED',
          status: _label(status),
        );
      }).toList();
    }
    if (kind == 'settlements') {
      final response = await api.get<Map<String, dynamic>>(
        '/admin/settlements',
      );
      return _rows(response.data).map((row) {
        final technician = _map(row['technician']);
        final user = _map(technician['user']);
        final status = '${row['status'] ?? 'PENDING'}';
        return ManagedRecord(
          '${row['id']}',
          '${user['name'] ?? 'Technician settlement'}',
          'Net ₹${row['netAmount'] ?? 0} · Gross ₹${row['grossAmount'] ?? 0}',
          active: status == 'AVAILABLE' || status == 'PAID',
          status: _label(status),
        );
      }).toList();
    }
    if (kind == 'team') {
      return (await staff())
          .map(
            (member) => ManagedRecord(
              member.id,
              member.name,
              '${member.role} · ${_verification(member.verificationStatus)}',
              active: member.verificationStatus == 'APPROVED',
            ),
          )
          .toList();
    }
    return const [];
  }

  @override
  Future<AdminJob> assign(String id, String technician) =>
      _assign(id, technician);

  Future<AdminJob> _assign(String id, String technicianId) async {
    await api.post<Map<String, dynamic>>(
      '/admin/jobs/$id/assign-technician',
      data: {'technicianId': technicianId},
    );
    final refreshed = await jobs();
    return refreshed.firstWhere(
      (job) => job.id == id,
      orElse: () => throw const ApiException('Assigned job was not found'),
    );
  }

  @override
  Future<List<ManagedRecord>> add(String kind, String title, String subtitle) =>
      throw const ApiException('This admin operation is not configured');

  @override
  Future<void> reviewTechnician(
    String id,
    String status, {
    String? reason,
  }) async {
    final data = <String, dynamic>{'status': status};
    if (reason != null) {
      data['reason'] = reason;
    }
    await api.patch<Map<String, dynamic>>(
      '/admin/technicians/$id/verification',
      data: data,
    );
  }

  @override
  Future<void> reviewTechnicianDocument(
    String technicianId,
    String documentId,
    String status, {
    String? reason,
  }) async {
    final data = <String, dynamic>{'status': status};
    if (reason != null) data['reason'] = reason;
    await api.patch<Map<String, dynamic>>(
      '/admin/technicians/$technicianId/documents/$documentId',
      data: data,
    );
  }

  @override
  Future<void> performRecordAction(
    String kind,
    String id,
    String action, {
    Map<String, dynamic> data = const {},
  }) async {
    if (kind == 'customers') {
      final status = action == 'activate' ? 'ACTIVE' : 'SUSPENDED';
      await api.patch<Map<String, dynamic>>(
        '/admin/customers/$id/status',
        data: {'status': status, ...data},
      );
      return;
    }
    if (kind == 'service-categories' || kind == 'services') {
      await api.patch<Map<String, dynamic>>(
        '/admin/$kind/$id',
        data: {'active': action == 'enable'},
      );
      return;
    }
    if (kind == 'complaints') {
      await api.post<Map<String, dynamic>>(
        '/admin/complaints/$id/$action',
        data: data,
      );
      return;
    }
    if (kind == 'payouts') {
      await api.post<Map<String, dynamic>>(
        '/admin/payouts/$id/$action',
        data: data,
      );
      return;
    }
    if (kind == 'cash-collections') {
      await api.post<Map<String, dynamic>>(
        '/admin/cash-collections/$id/$action',
        data: data,
      );
      return;
    }
    if (kind == 'refunds') {
      await api.post<Map<String, dynamic>>(
        '/admin/refunds/$id/$action',
        data: data,
      );
      return;
    }
    if (kind == 'settlements') {
      final status = switch (action) {
        'available' => 'AVAILABLE',
        'hold' => 'HELD',
        'reverse' => 'REVERSED',
        _ => throw const ApiException('Unsupported settlement action'),
      };
      await api.patch<Map<String, dynamic>>(
        '/admin/settlements/$id',
        data: {'status': status, ...data},
      );
      return;
    }
    throw const ApiException('This record does not support Admin actions');
  }

  String _status(String value) => switch (value.toUpperCase()) {
    'PENDING' => 'Pending',
    'IN_PROGRESS' => 'In progress',
    'COMPLETED' => 'Completed',
    'CANCELLED' => 'Cancelled',
    'ACCEPTED' => 'Accepted',
    'EN_ROUTE' => 'En route',
    'PAUSED' => 'Paused',
    'ASSIGNED' => 'Assigned',
    _ => 'Unknown',
  };

  String _verification(String value) => value
      .toLowerCase()
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');

  Iterable<Map<String, dynamic>> _rows(Map<String, dynamic>? response) {
    final value = response?['data'];
    final rows = value is List<dynamic>
        ? value
        : value is Map<String, dynamic>
        ? (value['items'] as List<dynamic>? ?? const [])
        : const <dynamic>[];
    return rows.whereType<Map<String, dynamic>>();
  }

  Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : const {};

  String _label(String value) => value
      .toLowerCase()
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');

  String _shortId(Object? value) {
    final id = '$value';
    return id.length <= 8 ? id : id.substring(0, 8).toUpperCase();
  }
}
