import 'package:equatable/equatable.dart';

class AdminDashboardSummary extends Equatable {
  const AdminDashboardSummary({
    required this.totalCustomers,
    required this.totalTechnicians,
    required this.verifiedTechnicians,
    required this.pendingTechnicianApprovals,
    required this.totalBookings,
    required this.activeJobs,
    required this.completedJobs,
    required this.cancelledBookings,
    required this.totalRevenue,
    required this.pendingPayments,
    required this.pendingPayouts,
    required this.pendingComplaints,
  });
  final int totalCustomers,
      totalTechnicians,
      verifiedTechnicians,
      pendingTechnicianApprovals,
      totalBookings,
      activeJobs,
      completedJobs,
      cancelledBookings,
      pendingPayouts,
      pendingComplaints;
  final double totalRevenue, pendingPayments;
  @override
  List<Object?> get props => [
    totalCustomers,
    totalTechnicians,
    verifiedTechnicians,
    pendingTechnicianApprovals,
    totalBookings,
    activeJobs,
    completedJobs,
    cancelledBookings,
    totalRevenue,
    pendingPayments,
    pendingPayouts,
    pendingComplaints,
  ];
}

class AdminJob extends Equatable {
  const AdminJob(
    this.id,
    this.customer,
    this.service,
    this.technician,
    this.status,
    this.amount,
  );
  final String id, customer, service, technician, status;
  final int amount;
  bool get canAssign =>
      const {'Pending', 'Upcoming', 'Assigned'}.contains(status);
  @override
  List<Object?> get props => [
    id,
    customer,
    service,
    technician,
    status,
    amount,
  ];
  AdminJob copyWith({String? technician, String? status}) => AdminJob(
    id,
    customer,
    service,
    technician ?? this.technician,
    status ?? this.status,
    amount,
  );
}

class StaffMember extends Equatable {
  const StaffMember(
    this.id,
    this.name,
    this.role,
    this.skill,
    this.active,
    this.rating, [
    this.verificationStatus = 'APPROVED',
    this.documents = const [],
    this.serviceAreas = const [],
  ]);
  final String id, name, role, skill, verificationStatus;
  final bool active;
  final double rating;
  final List<TechnicianDocument> documents;
  final List<String> serviceAreas;
  bool get documentsApproved =>
      documents.isNotEmpty &&
      documents.every((document) => document.isApproved);
  @override
  List<Object?> get props => [
    id,
    name,
    role,
    skill,
    active,
    rating,
    verificationStatus,
    documents,
    serviceAreas,
  ];
  StaffMember copyWith({
    bool? active,
    String? verificationStatus,
    List<TechnicianDocument>? documents,
    List<String>? serviceAreas,
  }) => StaffMember(
    id,
    name,
    role,
    skill,
    active ?? this.active,
    rating,
    verificationStatus ?? this.verificationStatus,
    documents ?? this.documents,
    serviceAreas ?? this.serviceAreas,
  );

  StaffMember toggle() => copyWith(active: !active);
}

class TechnicianDocument extends Equatable {
  const TechnicianDocument({
    required this.id,
    required this.type,
    required this.status,
    this.rejectionReason,
    this.uploadedAt,
    this.reviewedAt,
  });

  final String id, type, status;
  final String? rejectionReason;
  final DateTime? uploadedAt, reviewedAt;

  bool get isApproved => status == 'APPROVED';
  bool get isPending => status == 'PENDING';

  TechnicianDocument copyWith({
    String? status,
    String? rejectionReason,
    DateTime? reviewedAt,
  }) => TechnicianDocument(
    id: id,
    type: type,
    status: status ?? this.status,
    rejectionReason: rejectionReason,
    uploadedAt: uploadedAt,
    reviewedAt: reviewedAt ?? this.reviewedAt,
  );

  @override
  List<Object?> get props => [
    id,
    type,
    status,
    rejectionReason,
    uploadedAt,
    reviewedAt,
  ];
}

class ManagedRecord extends Equatable {
  const ManagedRecord(
    this.id,
    this.title,
    this.subtitle, {
    this.active = true,
    this.status,
  });
  final String id, title, subtitle;
  final bool active;
  final String? status;

  ManagedRecord copyWith({
    String? title,
    String? subtitle,
    bool? active,
    String? status,
  }) => ManagedRecord(
    id,
    title ?? this.title,
    subtitle ?? this.subtitle,
    active: active ?? this.active,
    status: status ?? this.status,
  );

  @override
  List<Object?> get props => [id, title, subtitle, active, status];
}
