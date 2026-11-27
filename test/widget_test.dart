import 'package:field_ops_pro/app/app.dart';
import 'package:field_ops_pro/app/dependency_injection.dart';
import 'package:field_ops_pro/app/routes.dart';
import 'package:field_ops_pro/features/auth/domain/user_role.dart';
import 'package:field_ops_pro/features/auth/presentation/auth_session.dart';
import 'package:field_ops_pro/features/customer/presentation/customer_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('role labels are user facing', () {
    expect(UserRole.technician.label, 'Technician');
    expect(UserRole.manager.label, 'Admin');
    expect(
      UserRole.manager.workspaceDescription,
      'Manage customers, teams and operations.',
    );
  });

  testWidgets('customer login, booking, and role guard workflow', (
    tester,
  ) async {
    await sl.reset();
    configureDependencies();
    authSession.signOut();
    customerHasUpcomingBooking.value = false;
    await tester.pumpWidget(const FieldOpsApp());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('UPCOMING SERVICE'), findsNothing);
    expect(find.text('My jobs'), findsNothing);
    expect(find.text('Wallet'), findsNothing);

    await tester.tap(find.text('Services'));
    await tester.pumpAndSettle();
    expect(find.text('Services for your home'), findsOneWidget);
    expect(find.text('AC & HVAC'), findsOneWidget);

    await tester.tap(find.text('AC & HVAC'));
    await tester.pumpAndSettle();
    expect(find.text('Available services'), findsOneWidget);
    await tester.tap(find.text('AC Installation'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a time'), findsOneWidget);
    await tester.tap(find.text('09:00 AM'));
    await tester.pumpAndSettle();
    expect(find.text('Choose payment'), findsOneWidget);
    await tester.tap(find.text('Pay after service'));
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Review booking'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm booking'));
    await tester.pumpAndSettle();
    expect(find.text('My bookings'), findsOneWidget);
    expect(find.text('AC Installation'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('UPCOMING SERVICE'), findsOneWidget);
    expect(find.text('AC Installation'), findsOneWidget);

    appRouter.go('/admin');
    await tester.pumpAndSettle();
    expect(find.text('Alex Morgan'), findsOneWidget);
  });

  testWidgets('customer can log out from profile', (tester) async {
    await sl.reset();
    configureDependencies();
    authSession.signOut();
    customerHasUpcomingBooking.value = false;
    await tester.pumpWidget(const FieldOpsApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    final logoutLabel = find.text('Log out');
    expect(logoutLabel, findsOneWidget);
    await tester.tap(logoutLabel);
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
