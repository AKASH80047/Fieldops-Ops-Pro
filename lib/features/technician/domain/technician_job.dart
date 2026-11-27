import 'package:equatable/equatable.dart';

class TechnicianJob extends Equatable {
  const TechnicianJob(
    this.id,
    this.customer,
    this.service,
    this.address,
    this.time,
    this.status,
    this.priority,
  );
  final String id, customer, service, address, time, status, priority;
  @override
  List<Object?> get props => [
    id,
    customer,
    service,
    address,
    time,
    status,
    priority,
  ];
}

class TechnicianEarning extends Equatable {
  const TechnicianEarning({
    required this.id,
    required this.jobId,
    required this.grossAmount,
    required this.commissionAmount,
    required this.netAmount,
    required this.status,
    required this.createdAt,
  });
  final String id, jobId, status;
  final double grossAmount, commissionAmount, netAmount;
  final DateTime createdAt;
  @override
  List<Object?> get props => [
    id,
    jobId,
    grossAmount,
    commissionAmount,
    netAmount,
    status,
    createdAt,
  ];
}

class TechnicianProfile extends Equatable {
  const TechnicianProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.postalCode,
    required this.skills,
    required this.verificationStatus,
    this.aadhaarLast4,
    this.rating = 0,
    this.available = false,
  });

  final String id, name, phone, address, postalCode, verificationStatus;
  final String? aadhaarLast4;
  final List<String> skills;
  final double rating;
  final bool available;

  bool get isApproved => verificationStatus == 'APPROVED';

  @override
  List<Object?> get props => [
    id,
    name,
    phone,
    address,
    postalCode,
    skills,
    verificationStatus,
    aadhaarLast4,
    rating,
    available,
  ];
}

class TechnicianOpportunity extends Equatable {
  const TechnicianOpportunity({
    required this.id,
    required this.service,
    required this.category,
    required this.locality,
    required this.scheduledAt,
    required this.estimatedPrice,
    this.distanceKm,
  });

  final String id, service, category, locality, scheduledAt;
  final double estimatedPrice;
  final double? distanceKm;

  @override
  List<Object?> get props => [
    id,
    service,
    category,
    locality,
    scheduledAt,
    estimatedPrice,
    distanceKm,
  ];
}

class TechnicianProgress extends Equatable {
  const TechnicianProgress({
    required this.totalJobs,
    required this.activeJobs,
    required this.completedJobs,
    required this.submittedReports,
    required this.pendingApprovals,
    required this.completionRate,
    required this.rating,
    required this.netEarnings,
  });

  final int totalJobs, activeJobs, completedJobs, submittedReports;
  final int pendingApprovals;
  final double completionRate, rating, netEarnings;

  @override
  List<Object?> get props => [
    totalJobs,
    activeJobs,
    completedJobs,
    submittedReports,
    pendingApprovals,
    completionRate,
    rating,
    netEarnings,
  ];
}

class TechnicianApplicationInput extends Equatable {
  const TechnicianApplicationInput({
    required this.name,
    required this.phone,
    required this.aadhaarNumber,
    required this.addressLine1,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.skills,
    required this.locationConsent,
    required this.kycConsent,
    this.latitude,
    this.longitude,
  });

  final String name, phone, aadhaarNumber, addressLine1, city, state;
  final String postalCode;
  final List<String> skills;
  final bool locationConsent, kycConsent;
  final double? latitude, longitude;

  @override
  List<Object?> get props => [
    name,
    phone,
    aadhaarNumber,
    addressLine1,
    city,
    state,
    postalCode,
    skills,
    locationConsent,
    kycConsent,
    latitude,
    longitude,
  ];
}
