import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../domain/technician_job.dart';
import '../../../core/network/api_client.dart';

abstract class TechnicianRepository {
  Future<List<TechnicianJob>> jobs();
  Future<TechnicianJob> update(String id, String status);
  Future<bool> updateAvailability(bool available);
  Future<List<TechnicianEarning>> earnings();
  Future<TechnicianProfile> profile();
  Future<List<TechnicianOpportunity>> opportunities({
    double? latitude,
    double? longitude,
  });
  Future<void> claimOpportunity(String id);
  Future<TechnicianProgress> progress();
  Future<void> submitWorkReport(
    String jobId, {
    required String description,
    String? summary,
  });
  Future<void> submitApplication(
    TechnicianApplicationInput input, {
    required Uint8List selfieBytes,
    required String selfieFileName,
    required Uint8List identityBytes,
    required String identityFileName,
    required Uint8List addressProofBytes,
    required String addressProofFileName,
    String selfieMimeType = 'image/jpeg',
  });
}

class MockTechnicianRepository implements TechnicianRepository {
  TechnicianProfile _profile = const TechnicianProfile(
    id: 'TECH-DEMO',
    name: 'Demo Technician',
    phone: '+91 98765 43210',
    address: 'MG Road, Bengaluru, Karnataka',
    postalCode: '560001',
    skills: ['AC Technician', 'Electrician'],
    verificationStatus: 'APPROVED',
    aadhaarLast4: '1234',
    rating: 4.8,
    available: true,
  );
  final items = <TechnicianJob>[
    const TechnicianJob(
      'FO-1842',
      'Alex Morgan',
      'AC maintenance',
      '24 Park Street',
      '10:00 AM',
      'Upcoming',
      'High',
    ),
    const TechnicianJob(
      'FO-1844',
      'Priya Singh',
      'Kitchen leak repair',
      '11 Lake View Road',
      '01:30 PM',
      'Pending',
      'Normal',
    ),
    const TechnicianJob(
      'FO-1831',
      'Rohan Mehta',
      'Electrical inspection',
      '8 MG Road',
      'Yesterday',
      'Completed',
      'Normal',
    ),
  ];
  @override
  Future<List<TechnicianJob>> jobs() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return List.of(items);
  }

  @override
  Future<TechnicianJob> update(String id, String status) async {
    final i = items.indexWhere((x) => x.id == id);
    if (i < 0) throw StateError('Job not found');
    final old = items[i];
    final next = TechnicianJob(
      old.id,
      old.customer,
      old.service,
      old.address,
      old.time,
      status,
      old.priority,
    );
    items[i] = next;
    return next;
  }

  @override
  Future<bool> updateAvailability(bool available) async => available;

  @override
  Future<List<TechnicianEarning>> earnings() async => const [];

  @override
  Future<TechnicianProfile> profile() async => _profile;

  @override
  Future<List<TechnicianOpportunity>> opportunities({
    double? latitude,
    double? longitude,
  }) async => const [
    TechnicianOpportunity(
      id: 'OP-201',
      service: 'Home cooking required',
      category: 'Home Cook',
      locality: 'Indiranagar · 560038',
      scheduledAt: 'Today · 06:30 PM',
      estimatedPrice: 850,
      distanceKm: 2.4,
    ),
    TechnicianOpportunity(
      id: 'OP-202',
      service: 'Electrical switch repair',
      category: 'Electrician',
      locality: 'Ulsoor · 560008',
      scheduledAt: 'Tomorrow · 10:00 AM',
      estimatedPrice: 599,
      distanceKm: 3.1,
    ),
  ];

  @override
  Future<void> claimOpportunity(String id) async {
    final opportunity = (await opportunities()).firstWhere((x) => x.id == id);
    items.insert(
      0,
      TechnicianJob(
        opportunity.id,
        'Customer details available after acceptance',
        opportunity.service,
        opportunity.locality,
        opportunity.scheduledAt,
        'Upcoming',
        'Normal',
      ),
    );
  }

  @override
  Future<TechnicianProgress> progress() async => const TechnicianProgress(
    totalJobs: 3,
    activeJobs: 1,
    completedJobs: 1,
    submittedReports: 1,
    pendingApprovals: 0,
    completionRate: 50,
    rating: 4.8,
    netEarnings: 0,
  );

  @override
  Future<void> submitWorkReport(
    String jobId, {
    required String description,
    String? summary,
  }) async {}

  @override
  Future<void> submitApplication(
    TechnicianApplicationInput input, {
    required Uint8List selfieBytes,
    required String selfieFileName,
    required Uint8List identityBytes,
    required String identityFileName,
    required Uint8List addressProofBytes,
    required String addressProofFileName,
    String selfieMimeType = 'image/jpeg',
  }) async {
    _profile = TechnicianProfile(
      id: _profile.id,
      name: input.name,
      phone: input.phone,
      address: '${input.addressLine1}, ${input.city}, ${input.state}',
      postalCode: input.postalCode,
      skills: input.skills,
      verificationStatus: 'PENDING_VERIFICATION',
      aadhaarLast4: input.aadhaarNumber.substring(8),
    );
  }
}

class ApiTechnicianRepository implements TechnicianRepository {
  ApiTechnicianRepository(this.api);
  final ApiClient api;

  @override
  Future<List<TechnicianJob>> jobs() async {
    final response = await api.get<Map<String, dynamic>>('/technician/jobs');
    final rows = response.data?['data'] as List<dynamic>? ?? const [];
    return rows.whereType<Map<String, dynamic>>().map(_jobFromJson).toList();
  }

  @override
  Future<TechnicianJob> update(String id, String status) async {
    final action = switch (status) {
      'Accepted' || 'Upcoming' => 'accept',
      'In progress' => 'start',
      'Paused' => 'pause',
      'Rejected' => 'reject',
      _ => throw ApiException('Unsupported job action: $status'),
    };
    await api.post<Map<String, dynamic>>('/technician/jobs/$id/$action');
    final refreshed = await jobs();
    return refreshed.firstWhere(
      (job) => job.id == id,
      orElse: () => throw const ApiException('Updated job was not found'),
    );
  }

  @override
  Future<bool> updateAvailability(bool available) async {
    final response = await api.put<Map<String, dynamic>>(
      '/technician/availability',
      data: {'available': available},
    );
    final data = response.data?['data'] as Map<String, dynamic>?;
    return data?['available'] == true;
  }

  @override
  Future<List<TechnicianEarning>> earnings() async {
    final response = await api.get<Map<String, dynamic>>(
      '/technician/earnings',
    );
    final rows = response.data?['data'] as List<dynamic>? ?? const [];
    return rows.whereType<Map<String, dynamic>>().map((row) {
      double amount(String key) => double.tryParse('${row[key] ?? 0}') ?? 0;
      return TechnicianEarning(
        id: '${row['id']}',
        jobId: '${row['jobId']}',
        grossAmount: amount('grossAmount'),
        commissionAmount: amount('commissionAmount'),
        netAmount: amount('netAmount'),
        status: '${row['status']}',
        createdAt: DateTime.tryParse('${row['createdAt']}') ?? DateTime.now(),
      );
    }).toList();
  }

  @override
  Future<TechnicianProfile> profile() async {
    final response = await api.get<Map<String, dynamic>>(
      '/technician/application',
    );
    final row = response.data?['data'] as Map<String, dynamic>?;
    if (row == null) throw const ApiException('Technician profile is missing');
    final user = row['user'] as Map<String, dynamic>? ?? const {};
    final address = row['address'] as Map<String, dynamic>? ?? const {};
    final serviceAreas = row['serviceAreas'] as List<dynamic>? ?? const [];
    final areaLabel = serviceAreas
        .whereType<Map<String, dynamic>>()
        .map((item) => item['serviceArea'] as Map<String, dynamic>? ?? item)
        .map((item) => '${item['name'] ?? item['city'] ?? ''}')
        .where((value) => value.isNotEmpty)
        .join(', ');
    final addressText = [
      address['line1'],
      address['city'],
      address['state'],
    ].where((x) => x != null && '$x'.isNotEmpty).join(', ');
    return TechnicianProfile(
      id: '${row['id'] ?? ''}',
      name: '${user['name'] ?? row['name'] ?? 'Technician'}',
      phone: '${user['phone'] ?? row['phone'] ?? ''}',
      address: addressText.isNotEmpty ? addressText : areaLabel,
      postalCode: '${address['postalCode'] ?? row['postalCode'] ?? ''}',
      skills: (row['skills'] as List<dynamic>? ?? const [])
          .map((x) => '$x')
          .toList(),
      verificationStatus: '${row['verificationStatus'] ?? 'DRAFT'}',
      aadhaarLast4: _aadhaarLast4(row['aadhaarMasked']),
      rating: double.tryParse('${row['rating'] ?? 0}') ?? 0,
      available: row['available'] == true,
    );
  }

  String? _aadhaarLast4(Object? masked) {
    final digits = '${masked ?? ''}'.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 4 ? digits.substring(digits.length - 4) : null;
  }

  @override
  Future<List<TechnicianOpportunity>> opportunities({
    double? latitude,
    double? longitude,
  }) async {
    final response = await api.get<Map<String, dynamic>>(
      '/technician/opportunities',
      query: <String, dynamic>{'latitude': latitude, 'longitude': longitude}
        ..removeWhere((_, value) => value == null),
    );
    final rows = response.data?['data'] as List<dynamic>? ?? const [];
    return rows.whereType<Map<String, dynamic>>().map((row) {
      final service = row['service'] as Map<String, dynamic>? ?? const {};
      final categoryValue = service['category'];
      final category = categoryValue is Map<String, dynamic>
          ? '${categoryValue['name'] ?? 'Service'}'
          : '${categoryValue ?? service['categoryName'] ?? 'Service'}';
      final area = row['area'] as Map<String, dynamic>? ?? const {};
      final scheduled = DateTime.tryParse('${row['scheduledAt'] ?? ''}');
      return TechnicianOpportunity(
        id: '${row['id']}',
        service: '${service['name'] ?? 'Service request'}',
        category: category,
        locality: [
          area['city'],
          area['postalCode'],
        ].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
        scheduledAt: scheduled == null
            ? 'Schedule unavailable'
            : '${scheduled.day.toString().padLeft(2, '0')}/${scheduled.month.toString().padLeft(2, '0')} · ${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}',
        estimatedPrice: double.tryParse('${row['estimatedPrice'] ?? 0}') ?? 0,
        distanceKm: double.tryParse('${row['distanceKm'] ?? ''}'),
      );
    }).toList();
  }

  @override
  Future<void> claimOpportunity(String id) async {
    await api.post<Map<String, dynamic>>('/technician/opportunities/$id/claim');
  }

  @override
  Future<TechnicianProgress> progress() async {
    final response = await api.get<Map<String, dynamic>>(
      '/technician/progress',
    );
    final row = response.data?['data'] as Map<String, dynamic>? ?? const {};
    final jobs = row['jobs'] as Map<String, dynamic>? ?? row;
    final earnings = row['earnings'] as Map<String, dynamic>? ?? row;
    int count(Map<String, dynamic> source, String key) =>
        int.tryParse('${source[key] ?? 0}') ?? 0;
    double amount(Map<String, dynamic> source, String key) =>
        double.tryParse('${source[key] ?? 0}') ?? 0;
    return TechnicianProgress(
      totalJobs: count(jobs, 'total'),
      activeJobs: count(jobs, 'active'),
      completedJobs: count(jobs, 'completed'),
      submittedReports: count(jobs, 'reportsSubmitted'),
      pendingApprovals: count(jobs, 'pendingApprovals'),
      completionRate: amount(jobs, 'completionRate'),
      rating: amount(row, 'rating'),
      netEarnings: amount(earnings, 'net'),
    );
  }

  @override
  Future<void> submitWorkReport(
    String jobId, {
    required String description,
    String? summary,
  }) async {
    await api.post<Map<String, dynamic>>(
      '/technician/jobs/$jobId/work-report',
      data: {
        'description': description,
        if (summary != null && summary.trim().isNotEmpty)
          'summary': summary.trim(),
      },
    );
  }

  @override
  Future<void> submitApplication(
    TechnicianApplicationInput input, {
    required Uint8List selfieBytes,
    required String selfieFileName,
    required Uint8List identityBytes,
    required String identityFileName,
    required Uint8List addressProofBytes,
    required String addressProofFileName,
    String selfieMimeType = 'image/jpeg',
  }) async {
    await api.patch<Map<String, dynamic>>(
      '/technician/application',
      data: {
        'name': input.name,
        'phone': input.phone,
        'skills': input.skills,
        'experienceYears': 0,
        'address': {
          'line1': input.addressLine1,
          'city': input.city,
          'state': input.state,
          'postalCode': input.postalCode,
        },
        'aadhaarNumber': input.aadhaarNumber,
        'aadhaarConsent': input.kycConsent,
      },
    );

    await _uploadDocument(
      type: 'IDENTITY',
      bytes: identityBytes,
      fileName: identityFileName,
      mimeType: 'image/jpeg',
    );
    await _uploadDocument(
      type: 'ADDRESS',
      bytes: addressProofBytes,
      fileName: addressProofFileName,
      mimeType: 'image/jpeg',
    );
    await _uploadDocument(
      type: 'LIVE_SELFIE',
      bytes: selfieBytes,
      fileName: selfieFileName,
      mimeType: selfieMimeType,
    );
    await api.post<Map<String, dynamic>>('/technician/verification/submit');
  }

  Future<void> _uploadDocument({
    required String type,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final intentResponse = await api.post<Map<String, dynamic>>(
      '/technician/documents/upload-intent',
      data: {
        'type': type,
        'mimeType': mimeType,
        'size': bytes.length,
        'fileName': fileName,
      },
    );
    final intent = intentResponse.data?['data'] as Map<String, dynamic>?;
    if (intent == null) {
      throw const ApiException('Selfie upload could not start');
    }
    final uploadUrl = '${intent['uploadUrl']}';
    final rawHeaders = intent['headers'] as Map<String, dynamic>? ?? const {};
    await Dio().put<void>(
      uploadUrl,
      data: bytes,
      options: Options(
        headers: {
          ...rawHeaders.map((key, value) => MapEntry(key, '$value')),
          'Content-Type': mimeType,
          'Content-Length': bytes.length,
        },
      ),
    );
    await api.post<Map<String, dynamic>>(
      '/technician/documents',
      data: {
        'type': type,
        'objectKey': intent['objectKey'],
        'mimeType': mimeType,
      },
    );
  }

  TechnicianJob _jobFromJson(Map<String, dynamic> json) {
    final booking = json['booking'] as Map<String, dynamic>? ?? const {};
    final customer = booking['customer'] as Map<String, dynamic>? ?? const {};
    final user = customer['user'] as Map<String, dynamic>? ?? const {};
    final service = booking['service'] as Map<String, dynamic>? ?? const {};
    final address = booking['address'] as Map<String, dynamic>? ?? const {};
    final scheduled = DateTime.tryParse('${booking['scheduledAt'] ?? ''}');
    final time = scheduled == null
        ? 'Schedule unavailable'
        : '${scheduled.day.toString().padLeft(2, '0')}/${scheduled.month.toString().padLeft(2, '0')} · ${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}';
    return TechnicianJob(
      '${json['id']}',
      '${user['name'] ?? 'Customer'}',
      '${service['name'] ?? 'Service'}',
      [
        address['line1'],
        address['city'],
      ].where((value) => value != null && '$value'.isNotEmpty).join(', '),
      time,
      _statusLabel('${json['status']}'),
      '${json['priority'] ?? 'NORMAL'}'.toLowerCase() == 'high'
          ? 'High'
          : 'Normal',
    );
  }

  String _statusLabel(String raw) => switch (raw.toUpperCase()) {
    'PENDING' => 'Pending',
    'ASSIGNED' => 'New',
    'ACCEPTED' => 'Accepted',
    'EN_ROUTE' => 'En route',
    'IN_PROGRESS' => 'In progress',
    'PAUSED' => 'Paused',
    'COMPLETED' => 'Completed',
    'CANCELLED' => 'Cancelled',
    _ => 'Unknown',
  };
}
