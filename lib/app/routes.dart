import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/domain/user_role.dart';
import '../features/auth/presentation/auth_session.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/auth_pages.dart';
import '../features/customer/presentation/customer_pages.dart';
import '../features/customer/presentation/service_categories.dart';
import '../features/technician/presentation/technician_pages.dart';
import '../features/technician/presentation/technician_onboarding_page.dart';
import '../features/technician/domain/technician_job.dart';
import '../features/admin/presentation/admin_pages.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: authSession,
  redirect: (context, state) {
    final path = state.matchedLocation;
    final role = authSession.role;
    if (role == null) {
      return _publicPaths.contains(path) ? null : '/login';
    }
    if (_publicPaths.contains(path)) return _homeFor(role);
    if (path.startsWith('/customer') && role != UserRole.customer) {
      return _homeFor(role);
    }
    if (path.startsWith('/tech') && role != UserRole.technician) {
      return _homeFor(role);
    }
    if (path.startsWith('/admin') && role != UserRole.manager) {
      return _homeFor(role);
    }
    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
    GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
    GoRoute(path: '/signup', builder: (_, _) => const SignupPage()),
    GoRoute(
      path: '/forgot-password',
      builder: (_, _) => const ForgotPasswordPage(),
    ),
    GoRoute(path: '/otp', builder: (_, _) => const OtpPage()),
    GoRoute(
      path: '/reset-password',
      builder: (_, _) => const ResetPasswordPage(),
    ),
    GoRoute(path: '/customer', builder: (_, _) => const CustomerHomePage()),
    GoRoute(
      path: '/customer/booking',
      builder: (_, state) =>
          BookingPage(initialService: state.extra as String?),
    ),
    GoRoute(
      path: '/customer/categories',
      builder: (_, _) => const AllCategoriesPage(),
    ),
    GoRoute(
      path: '/customer/categories/:slug',
      builder: (_, state) =>
          CategoryDetailsPage(slug: state.pathParameters['slug']!),
    ),
    GoRoute(
      path: '/customer/details',
      builder: (_, _) => const BookingDetailsPage(),
    ),
    GoRoute(path: '/tech', builder: (_, _) => const TechnicianDashboard()),
    GoRoute(
      path: '/tech/onboarding',
      builder: (_, state) => TechnicianOnboardingPage(
        initialSkill: state.extra as String? ?? 'Electrician',
      ),
    ),
    GoRoute(
      path: '/tech/job',
      builder: (_, state) =>
          TechnicianJobPage(job: state.extra as TechnicianJob?),
    ),
    GoRoute(path: '/admin', builder: (_, _) => const AdminDashboard()),
    GoRoute(path: '/admin/jobs', builder: (_, _) => const AdminJobsPage()),
    GoRoute(
      path: '/admin/manage/:kind',
      builder: (_, state) => AdminManagementPage(state.pathParameters['kind']!),
    ),
  ],
);

const _publicPaths = {
  '/splash',
  '/login',
  '/signup',
  '/forgot-password',
  '/otp',
  '/reset-password',
};

String _homeFor(UserRole role) => switch (role) {
  UserRole.customer => '/customer',
  UserRole.technician => '/tech',
  UserRole.manager => '/admin',
};

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) context.go('/login');
    });
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6738E8), Color(0xFF9B7CF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hub_rounded, color: Colors.white, size: 64),
            SizedBox(height: 16),
            Text(
              'FieldOps Pro',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Service work, intelligently coordinated',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    ),
  );
}
