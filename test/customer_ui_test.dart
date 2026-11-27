import 'package:field_ops_pro/app/app.dart';
import 'package:field_ops_pro/app/dependency_injection.dart';
import 'package:field_ops_pro/app/routes.dart';
import 'package:field_ops_pro/core/theme/app_theme.dart';
import 'package:field_ops_pro/features/auth/presentation/auth_session.dart';
import 'package:field_ops_pro/features/customer/presentation/customer_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpLogin(WidgetTester tester) async {
    await sl.reset();
    configureDependencies();
    authSession.signOut();
    customerHasUpcomingBooking.value = false;
    customerUpcomingSchedule.value = 'Tomorrow · 10:00 AM';
    await tester.pumpWidget(const FieldOpsApp());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    appRouter.go('/login');
    await tester.pumpAndSettle();
  }

  Future<void> signInAsCustomer(WidgetTester tester) async {
    await pumpLogin(tester);
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Alex Morgan'), findsOneWidget);
  }

  testWidgets('login stays usable on a compact phone and role changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpLogin(tester);

    expect(find.text('Continue as'), findsOneWidget);
    await tester.ensureVisible(find.text('Technician'));
    await tester.tap(find.text('Technician'));
    await tester.pumpAndSettle();
    expect(find.text('Manage jobs, schedules and earnings.'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Show password'));
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(find.text('alex@fieldops.io'), findsOneWidget);
    await tester.ensureVisible(find.text('Sign in'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer quick actions open receipts, rating and tracking', (
    tester,
  ) async {
    await signInAsCustomer(tester);

    final receipts = find.text('Bills & receipts').first;
    await tester.ensureVisible(receipts);
    await tester.tap(receipts);
    await tester.pumpAndSettle();
    expect(
      find.text('Clear payment status for every service.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Invoice FO-1774 · Paid via UPI'));
    await tester.pumpAndSettle();
    expect(find.text('Payment receipt'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final rating = find.text('Rate service').first;
    await tester.ensureVisible(rating);
    await tester.tap(rating);
    await tester.pumpAndSettle();
    expect(
      find.text('How was your Premium home cleaning experience?'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('5 stars'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit review'));
    await tester.pumpAndSettle();
    expect(find.text('Thanks for your 5-star review'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    final track = find.text('Track visit').first;
    await tester.ensureVisible(track);
    await tester.tap(track);
    await tester.pumpAndSettle();
    expect(find.text('No active visit'), findsOneWidget);
  });

  testWidgets('password recovery requires an email and a six-digit code', (
    tester,
  ) async {
    await pumpLogin(tester);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid work email.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'alex@fieldops.io');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a six-digit code.'), findsOneWidget);
    expect(find.text('Create a new password'), findsNothing);
  });

  testWidgets('admin metrics fit on a phone and job assignment closes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpLogin(tester);
    await tester.tap(find.text('Admin'));
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Jobs').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rahul Sharma').last);
    await tester.pumpAndSettle();
    expect(find.text('Assign technician'), findsNothing);
    expect(find.textContaining('Technician: Rahul Sharma'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking history filters show completed and cancelled work', (
    tester,
  ) async {
    await signInAsCustomer(tester);

    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('Premium home cleaning'), findsOneWidget);
    expect(find.text('Leak & tap repair'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Premium home cleaning'), findsOneWidget);
    expect(find.text('Leak & tap repair'), findsNothing);
  });

  testWidgets('admin management routes and main tabs open in demo mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpLogin(tester);
    await tester.tap(find.text('Admin'));
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    const pages = {
      'Customers': 'Customer management',
      'Categories': 'Service categories',
      'Services': 'Service & pricing',
      'Payments': 'Verified payments',
      'Cash review': 'Cash receipt verification',
      'Refunds': 'Refund requests',
      'Settlements': 'Earning settlements',
      'Payouts': 'Technician payouts',
      'Complaints': 'Complaints & support',
      'Invoices': 'Finance & invoices',
    };
    for (final page in pages.entries) {
      final chip = find.widgetWithText(ActionChip, page.key);
      await tester.scrollUntilVisible(
        chip.hitTestable(),
        160,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text(page.value), findsOneWidget);
      if (page.key == 'Cash review') {
        await tester.tap(find.text('Cash receipt · Rahul Sharma'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Verify cash receipt'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        expect(find.text('Verified'), findsWidgets);
      }
      expect(tester.takeException(), isNull, reason: page.key);
      appRouter.pop();
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();
    expect(find.text('Technician verification'), findsOneWidget);
    await tester.enterText(find.byType(TextField).hitTestable(), 'Rahul');
    await tester.pumpAndSettle();
    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('Sameer Khan'), findsNothing);

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('Reports & analytics'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Business settings'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );
    expect(
      find.byIcon(Icons.account_circle_rounded).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.text('Business operations'));
    await tester.pumpAndSettle();
    expect(find.text('Service areas'), findsOneWidget);
    await tester.tap(find.text('Business operations'));
    await tester.pumpAndSettle();

    final previousPalette = appPalette.value;
    addTearDown(() => appPalette.value = previousPalette);
    FlutterSecureStorage.setMockInitialValues({});
    await tester.tap(find.text('App theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean blue'));
    await tester.pumpAndSettle();
    expect(appPalette.value, AppPalette.ocean);
    expect(find.text('Ocean blue'), findsOneWidget);
    expect(
      await const FlutterSecureStorage().read(key: 'app_palette'),
      'ocean',
    );

    await tester.scrollUntilVisible(
      find.text('Log out'),
      250,
      scrollable: find.byType(Scrollable).hitTestable().last,
    );
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin can create demo jobs and review technicians', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpLogin(tester);
    await tester.tap(find.text('Admin'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jobs').last);
    await tester.pumpAndSettle();
    expect(find.text('Reassign'), findsNothing);
    expect(
      tester.getSize(find.byTooltip('Create demo job')).height,
      greaterThanOrEqualTo(48),
    );
    final activeJob = find.widgetWithText(Card, 'Leak repair');
    await tester.ensureVisible(activeJob);
    await tester.pumpAndSettle();
    await tester.tap(activeJob);
    await tester.pumpAndSettle();
    expect(find.text('Reference: FO-1844'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Create demo job'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a service description.'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'QA water heater service');
    await tester.enterText(fields.at(1), 'QA customer');
    await tester.enterText(fields.at(2), '499');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('QA water heater service'), findsOneWidget);

    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();
    for (final (name, action, status) in [
      ('Arjun Verma', 'Reject application', 'Rejected'),
      ('Rahul Sharma', 'Suspend technician', 'Suspended'),
    ]) {
      final technician = find.widgetWithText(ListTile, name);
      await tester.ensureVisible(technician);
      await tester.pumpAndSettle();
      await tester.tap(technician);
      await tester.pumpAndSettle();
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Enter at least 5 characters.'), findsOneWidget);
      await tester.enterText(
        find.byType(EditableText).last,
        'QA review reason',
      );
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text(status), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('technician workspace tabs render on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(332, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpLogin(tester);
    await tester.ensureVisible(find.text('Technician'));
    await tester.tap(find.text('Technician'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Earn'), findsOneWidget);
    expect(find.byTooltip('Earnings'), findsOneWidget);
    const titles = [
      'Choose the work you do',
      'Assigned jobs',
      'Earnings & performance',
      'My progress',
      'My profile',
    ];
    for (var index = 0; index < titles.length; index++) {
      await tester.tap(find.byType(NavigationDestination).at(index));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        index,
      );
      expect(find.text(titles[index]), findsOneWidget);
      expect(tester.takeException(), isNull, reason: titles[index]);
    }
  });

  testWidgets('assistant recommendation starts the existing booking flow', (
    tester,
  ) async {
    await signInAsCustomer(tester);

    await tester.tap(find.text('Assistant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My AC is not cooling'));
    await tester.pumpAndSettle();
    final bookRecommendation = find.text('Book this service');
    await tester.ensureVisible(bookRecommendation);
    await tester.pumpAndSettle();
    await tester.tap(bookRecommendation);
    await tester.pumpAndSettle();
    expect(find.text('Pick a time'), findsOneWidget);
  });

  testWidgets('customer and admin tabs fit at 130 percent text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(332, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await signInAsCustomer(tester);
    expect(find.text('Visits'), findsOneWidget);
    expect(find.byTooltip('Bookings'), findsOneWidget);
    for (final (index, title) in [
      (1, 'Services for your home'),
      (2, 'My bookings'),
      (3, 'Service assistant'),
      (4, 'Account'),
    ]) {
      await tester.tap(find.byType(NavigationDestination).at(index));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        index,
      );
      expect(find.text(title), findsOneWidget);
      expect(tester.takeException(), isNull, reason: title);
    }
    authSession.signOut();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Admin'));
    await tester.tap(find.text('Admin'));
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.widgetWithText(Card, 'Verified techs')).height,
      tester.getSize(find.widgetWithText(Card, 'Pending approvals')).height,
    );
    for (final (index, title) in [
      (1, 'Job management'),
      (2, 'Technician verification'),
      (3, 'Reports & analytics'),
      (4, 'Business settings'),
    ]) {
      await tester.tap(find.byType(NavigationDestination).at(index));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(tester.takeException(), isNull, reason: title);
    }
  });
}
