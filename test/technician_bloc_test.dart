import 'dart:typed_data';

import 'package:field_ops_pro/features/technician/data/technician_repository.dart';
import 'package:field_ops_pro/features/technician/domain/technician_job.dart';
import 'package:field_ops_pro/features/technician/presentation/technician_blocs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('availability changes only after repository confirmation', () async {
    final bloc = TechnicianAvailabilityBloc();
    await bloc.changed(false);
    expect(bloc.state, isFalse);
    await bloc.close();
  });

  test('jobs load from mock repository', () async {
    final bloc = TechnicianJobsBloc(MockTechnicianRepository());
    bloc.add(TechnicianJobsLoaded());
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(bloc.state.visible, isNotEmpty);
    await bloc.close();
  });

  test('job workflow advances and keeps checklist state', () async {
    final bloc = JobExecutionBloc();
    bloc.add(const ChecklistChanged(0));
    bloc.add(JobStepCompleted());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.step, 1);
    expect(bloc.state.checks, contains(0));
    await bloc.close();
  });

  test(
    'eKYC keeps only masked Aadhaar data in the technician profile',
    () async {
      final repository = MockTechnicianRepository();
      final bytes = Uint8List.fromList([1, 2, 3]);

      await repository.submitApplication(
        const TechnicianApplicationInput(
          name: 'Rahul Sharma',
          phone: '9876543210',
          aadhaarNumber: '123456789012',
          addressLine1: '12 MG Road',
          city: 'Bengaluru',
          state: 'Karnataka',
          postalCode: '560001',
          skills: ['Electrician'],
          locationConsent: true,
          kycConsent: true,
        ),
        selfieBytes: bytes,
        selfieFileName: 'selfie.jpg',
        identityBytes: bytes,
        identityFileName: 'identity.jpg',
        addressProofBytes: bytes,
        addressProofFileName: 'address.jpg',
      );

      final profile = await repository.profile();
      expect(profile.aadhaarLast4, '9012');
      expect(profile.verificationStatus, 'PENDING_VERIFICATION');
      expect(profile.props, isNot(contains('123456789012')));
    },
  );

  test('claiming a nearby opportunity adds it only to own jobs', () async {
    final repository = MockTechnicianRepository();
    final before = (await repository.jobs()).length;
    final opportunity = (await repository.opportunities()).first;

    await repository.claimOpportunity(opportunity.id);

    final jobs = await repository.jobs();
    expect(jobs, hasLength(before + 1));
    expect(jobs.first.id, opportunity.id);
    expect(jobs.first.customer, contains('available after acceptance'));
  });
}
