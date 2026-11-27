import 'package:field_ops_pro/features/admin/data/admin_repository.dart';
import 'package:field_ops_pro/features/admin/presentation/admin_blocs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin jobs load and can be assigned', () async {
    final repository = MockAdminRepository();
    final bloc = JobManagementBloc(repository);
    bloc.add(AdminJobsLoaded());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bloc.state.all, isNotEmpty);
    final id = bloc.state.all.first.id;
    bloc.add(AdminJobAssigned(id, 'Rahul Sharma'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bloc.state.all.first.technician, 'Rahul Sharma');
    await bloc.close();
  });

  test('management CRUD adds a local record', () async {
    final bloc = ManagementCubit(MockAdminRepository(), 'customers');
    await Future<void>.delayed(Duration.zero);
    final before = bloc.state.records.length;
    await bloc.add('New Customer', 'new@example.com');
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.records.length, before + 1);
    expect(bloc.state.error, isNull);
    await bloc.close();
  });

  test('management action updates a record and clears progress', () async {
    final bloc = ManagementCubit(MockAdminRepository(), 'customers');
    await Future<void>.delayed(Duration.zero);
    final id = bloc.state.records.first.id;

    final error = await bloc.performAction(
      id,
      'suspend',
      data: const {'reason': 'Policy review required'},
    );

    expect(error, isNull);
    expect(bloc.state.processingId, isNull);
    expect(bloc.state.records.first.status, 'Suspended');
    expect(bloc.state.records.first.active, isFalse);
    await bloc.close();
  });

  test('settlement can be released from pending to available', () async {
    final bloc = ManagementCubit(MockAdminRepository(), 'settlements');
    await Future<void>.delayed(Duration.zero);

    final error = await bloc.performAction(
      bloc.state.records.first.id,
      'available',
    );

    expect(error, isNull);
    expect(bloc.state.records.first.status, 'Available');
    expect(bloc.state.records.first.active, isTrue);
    await bloc.close();
  });

  test('refund follows approval and provider processing states', () async {
    final bloc = ManagementCubit(MockAdminRepository(), 'refunds');
    await Future<void>.delayed(Duration.zero);
    final id = bloc.state.records.first.id;

    expect(await bloc.performAction(id, 'approve'), isNull);
    expect(bloc.state.records.first.status, 'Approved');
    expect(await bloc.performAction(id, 'process'), isNull);
    expect(bloc.state.records.first.status, 'Succeeded');
    await bloc.close();
  });

  test('cash receipt verification marks the record verified', () async {
    final bloc = ManagementCubit(MockAdminRepository(), 'cash-collections');
    await Future<void>.delayed(Duration.zero);
    final id = bloc.state.records.first.id;

    expect(await bloc.performAction(id, 'verify'), isNull);
    expect(bloc.state.records.first.status, 'Verified');
    expect(bloc.state.records.first.active, isTrue);
    await bloc.close();
  });

  test('role permission can be changed', () {
    final bloc = RolePermissionBloc();
    bloc.toggle('Financial reports', true);
    expect(bloc.state['Financial reports'], isTrue);
    bloc.close();
  });
}
