import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../app/dependency_injection.dart';
import '../../../core/network/api_client.dart';
import '../../../core/notifications/firebase_messaging_service.dart';
import '../../auth/presentation/auth_session.dart';
import '../data/technician_repository.dart';
import '../domain/technician_job.dart';
import 'technician_blocs.dart';
import 'technician_home_widgets.dart';

class TechnicianDashboard extends StatefulWidget {
  const TechnicianDashboard({super.key});
  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) =>
            TechnicianJobsBloc(sl<TechnicianRepository>())
              ..add(TechnicianJobsLoaded()),
      ),
      BlocProvider(
        create: (_) =>
            TechnicianAvailabilityBloc(sl<TechnicianRepository>())..load(),
      ),
      BlocProvider(
        create: (_) =>
            TechnicianEarningsBloc(sl<TechnicianRepository>())..load(),
      ),
    ],
    child: Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: tab,
          children: [
            TechHome(
              onShowJobs: () => setState(() => tab = 1),
              onShowReports: () => setState(() => tab = 3),
            ),
            TechJobs(),
            TechEarnings(),
            TechReports(),
            TechProfile(),
          ],
        ),
      ),
      bottomNavigationBar: WorkspaceNavigationBar(
        selectedIndex: tab,
        onSelected: (value) => setState(() => tab = value),
        destinations: const [
          WorkspaceDestination('Home', Icons.home_outlined, Icons.home_rounded),
          WorkspaceDestination(
            'Jobs',
            Icons.work_outline_rounded,
            Icons.work_rounded,
          ),
          WorkspaceDestination(
            'Earnings',
            Icons.account_balance_wallet_outlined,
            Icons.account_balance_wallet_rounded,
            compactLabel: 'Earn',
          ),
          WorkspaceDestination(
            'Reports',
            Icons.analytics_outlined,
            Icons.analytics_rounded,
            compactLabel: 'Stats',
          ),
          WorkspaceDestination(
            'Profile',
            Icons.account_circle_outlined,
            Icons.account_circle_rounded,
            compactLabel: 'Me',
          ),
        ],
      ),
    ),
  );
}

class TechHome extends StatelessWidget {
  const TechHome({
    super.key,
    required this.onShowJobs,
    required this.onShowReports,
  });
  final VoidCallback onShowJobs, onShowReports;
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<TechnicianJobsBloc, TechnicianJobsState>(
    builder: (context, state) {
      final jobs = state.all;
      final requests = jobs.where((job) => job.status == 'Pending').length;
      final active = jobs.where((job) => job.status == 'In progress').length;
      final completed = jobs.where((job) => job.status == 'Completed').length;
      final hour = DateTime.now().hour;
      final greeting = hour < 12
          ? 'Good morning'
          : hour < 17
          ? 'Good afternoon'
          : 'Good evening';
      return RefreshIndicator(
        onRefresh: () async =>
            context.read<TechnicianJobsBloc>().add(TechnicianJobsLoaded()),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _TechHeader(greeting: greeting, requestCount: requests),
            const _ForegroundJobNotification(),
            const SizedBox(height: 16),
            BlocBuilder<TechnicianAvailabilityBloc, bool>(
              builder: (context, online) => Card(
                color: online ? AppColors.ink : AppColors.muted,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        online ? Icons.bolt : Icons.pause_circle_outline,
                        color: online ? Colors.amber : Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              online ? 'You are online' : 'You are offline',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text(
                              'Central service area',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: online,
                        onChanged: context
                            .read<TechnicianAvailabilityBloc>()
                            .changed,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _ApprovedSkills(),
            const SizedBox(height: 20),
            const SectionTitle('Choose the work you do'),
            const SizedBox(height: 4),
            const Text(
              'Select a category to register or add it to your verified profile.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.1,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: technicianCategories
                  .map(
                    (item) => Card(
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () =>
                            context.push('/tech/onboarding', extra: item.$1),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Icon(item.$2, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.$1,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            const NearbyOpportunities(),
            const SizedBox(height: 16),
            if (requests > 0)
              InkWell(
                onTap: onShowJobs,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.campaign_outlined, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'New job requests!',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              '$requests service request${requests == 1 ? '' : 's'} in your area',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward, color: Colors.white),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 18),
            const SectionTitle('Today at a glance'),
            const SizedBox(height: 10),
            _TechnicianMetrics(
              children: [
                MetricCard(
                  '$requests',
                  'New requests',
                  Icons.notifications_active_outlined,
                ),
                MetricCard('$active', 'In progress', Icons.timelapse),
                MetricCard('$completed', 'Completed', Icons.check_circle),
                BlocBuilder<TechnicianEarningsBloc, TechnicianEarningsState>(
                  builder: (context, earnings) {
                    final cutoff = DateTime.now().subtract(
                      const Duration(days: 7),
                    );
                    final total = earnings.entries
                        .where((item) => !item.createdAt.isBefore(cutoff))
                        .fold<double>(0, (sum, item) => sum + item.netAmount);
                    return MetricCard(
                      earnings.loading ? '…' : '₹${total.toStringAsFixed(0)}',
                      'Week earnings',
                      Icons.payments,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            SectionTitle(
              'Today’s jobs',
              action: TextButton(
                onPressed: onShowJobs,
                child: const Text('View all'),
              ),
            ),
            if (state.loading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.error != null)
              Text(state.error!)
            else if (jobs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Text(
                    'No jobs scheduled today. Turn on availability to receive eligible requests.',
                  ),
                ),
              )
            else
              ...jobs.take(2).map(JobCard.new),
            const SizedBox(height: 20),
            const SectionTitle('Quick actions'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.assignment_outlined),
                  label: const Text('Assigned jobs'),
                  onPressed: onShowJobs,
                ),
                ActionChip(
                  avatar: const Icon(Icons.description_outlined),
                  label: const Text('Job reports'),
                  onPressed: onShowReports,
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _TechHeader extends StatelessWidget {
  const _TechHeader({required this.greeting, required this.requestCount});

  final String greeting;
  final int requestCount;

  @override
  Widget build(BuildContext context) => FutureBuilder<TechnicianProfile>(
    future: sl<TechnicianRepository>().profile(),
    builder: (context, snapshot) {
      final profile = snapshot.data;
      final name = profile?.name ?? 'Technician';
      final initials = name
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .take(2)
          .map((part) => part[0].toUpperCase())
          .join();
      return Row(
        children: [
          CircleAvatar(
            radius: 25,
            child: Text(initials.isEmpty ? 'T' : initials),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $name!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const Text(
                  'Service Professional',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                if (profile != null)
                  Text(
                    profile.isApproved
                        ? '${profile.postalCode} service area · Verified'
                        : 'eKYC: ${_statusText(profile.verificationStatus)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          Badge(
            label: Text('$requestCount'),
            isLabelVisible: requestCount > 0,
            child: IconButton(
              tooltip: 'Notifications',
              onPressed: () => notice(
                context,
                requestCount == 0
                    ? 'No new job notifications.'
                    : '$requestCount job request${requestCount == 1 ? '' : 's'} waiting.',
              ),
              icon: const Icon(Icons.notifications_none),
            ),
          ),
        ],
      );
    },
  );

  static String _statusText(String status) => status
      .toLowerCase()
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

class _ApprovedSkills extends StatelessWidget {
  const _ApprovedSkills();

  @override
  Widget build(BuildContext context) => FutureBuilder<TechnicianProfile>(
    future: sl<TechnicianRepository>().profile(),
    builder: (context, snapshot) {
      final skills = snapshot.data?.skills ?? const <String>[];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My approved skills',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (snapshot.connectionState == ConnectionState.waiting)
            const LinearProgressIndicator()
          else if (skills.isEmpty)
            const Text(
              'Complete eKYC and skill verification to receive work.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skills
                  .map(
                    (skill) => Chip(
                      avatar: const Icon(
                        Icons.verified_outlined,
                        size: 16,
                        color: AppColors.success,
                      ),
                      label: Text(skill),
                    ),
                  )
                  .toList(),
            ),
        ],
      );
    },
  );
}

class _ForegroundJobNotification extends StatelessWidget {
  const _ForegroundJobNotification();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: FirebaseMessagingService.latestForegroundNotification,
    builder: (context, notification, _) {
      if (notification == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Card(
          color: const Color(0xFFF1ECFF),
          child: ListTile(
            onTap: () {
              context.read<TechnicianJobsBloc>().add(TechnicianJobsLoaded());
              FirebaseMessagingService.clearForegroundNotification();
            },
            leading: const Icon(
              Icons.notifications_active,
              color: AppColors.primary,
            ),
            title: Text(
              notification.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(notification.body),
            trailing: IconButton(
              tooltip: 'Dismiss',
              onPressed: FirebaseMessagingService.clearForegroundNotification,
              icon: const Icon(Icons.close),
            ),
          ),
        ),
      );
    },
  );
}

class _TechnicianMetrics extends StatelessWidget {
  const _TechnicianMetrics({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = constraints.maxWidth / scale < 240 ? 1 : 2;
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard(this.value, this.label, this.icon, {super.key});
  final String value, label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class TechJobs extends StatefulWidget {
  const TechJobs({super.key});
  @override
  State<TechJobs> createState() => _TechJobsState();
}

class _TechJobsState extends State<TechJobs> {
  String status = 'All';
  String query = '';
  void filter(BuildContext context) => context.read<TechnicianJobsBloc>().add(
    TechnicianJobsFiltered(query, status),
  );
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assigned jobs',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (ApiConfig.useMocks) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(
                    Icons.science_outlined,
                    size: 17,
                    color: AppColors.warning,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Demo jobs · changes stay in this session',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) {
                query = value;
                filter(context);
              },
              decoration: const InputDecoration(
                hintText: 'Search jobs or customers',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    [
                          'All',
                          'New',
                          'Upcoming',
                          'Pending',
                          'In progress',
                          'Completed',
                        ]
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(item),
                              selected: status == item,
                              onSelected: (_) {
                                setState(() => status = item);
                                filter(context);
                              },
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: BlocBuilder<TechnicianJobsBloc, TechnicianJobsState>(
          builder: (context, state) {
            if (state.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.visible.isEmpty) {
              return const Center(child: Text('No jobs match this filter.'));
            }
            return RefreshIndicator(
              onRefresh: () async => context.read<TechnicianJobsBloc>().add(
                TechnicianJobsLoaded(),
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: state.visible.map((job) => JobCard(job)).toList(),
              ),
            );
          },
        ),
      ),
    ],
  );
}

class JobCard extends StatelessWidget {
  const JobCard(this.job, {super.key});
  final TechnicianJob job;
  @override
  Widget build(BuildContext context) {
    final pending = job.status == 'Pending' || job.status == 'New';
    final statusColor = switch (job.status) {
      'Completed' => AppColors.success,
      'Pending' || 'New' => AppColors.warning,
      'In progress' => AppColors.secondary,
      _ => AppColors.primary,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/tech/job', extra: job),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_serviceIcon(job.service), color: statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.service,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          job.id,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(job.status, color: statusColor),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 17,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      job.customer,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 17,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      job.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_outlined,
                    size: 17,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(job.time)),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.flag_outlined,
                    size: 16,
                    color: job.priority == 'High'
                        ? AppColors.error
                        : AppColors.muted,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${job.priority} priority',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (pending)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.read<TechnicianJobsBloc>().add(
                          TechnicianJobStatusChanged(job.id, 'Upcoming'),
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => context.read<TechnicianJobsBloc>().add(
                          TechnicianJobStatusChanged(job.id, 'Rejected'),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                  ],
                )
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/tech/job', extra: job),
                    child: const Text('Open job details →'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _serviceIcon(String service) {
    final text = service.toLowerCase();
    if (text.contains('ac') || text.contains('appliance')) {
      return Icons.ac_unit_outlined;
    }
    if (text.contains('electrical')) {
      return Icons.electrical_services_outlined;
    }
    if (text.contains('plumb') || text.contains('leak')) {
      return Icons.plumbing_outlined;
    }
    return Icons.handyman_outlined;
  }
}

class TechEarnings extends StatelessWidget {
  const TechEarnings({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<TechnicianEarningsBloc, TechnicianEarningsState>(
    builder: (context, state) {
      final entries = _filtered(state.entries, state.filter);
      final net = entries.fold<double>(0, (sum, item) => sum + item.netAmount);
      final commission = entries.fold<double>(
        0,
        (sum, item) => sum + item.commissionAmount,
      );
      final available = entries
          .where((item) => item.status == 'AVAILABLE')
          .fold<double>(0, (sum, item) => sum + item.netAmount);
      final pending = entries
          .where((item) => item.status == 'PENDING')
          .fold<double>(0, (sum, item) => sum + item.netAmount);
      return RefreshIndicator(
        onRefresh: context.read<TechnicianEarningsBloc>().load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Earnings & performance',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: [
                'Week',
                'Month',
                'Year',
              ].map((x) => ButtonSegment(value: x, label: Text(x))).toList(),
              selected: {state.filter},
              onSelectionChanged: (value) =>
                  context.read<TechnicianEarningsBloc>().filter(value.first),
            ),
            const SizedBox(height: 18),
            if (state.loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.error != null)
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                  ),
                  title: Text(state.error!),
                  trailing: TextButton(
                    onPressed: context.read<TechnicianEarningsBloc>().load,
                    child: const Text('Retry'),
                  ),
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verified earnings',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      entries.isEmpty ? '—' : _money(net),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      entries.isEmpty
                          ? 'Available after payment verification'
                          : '${_money(commission)} platform commission recorded',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (entries.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No settled earnings to show yet. Customer approval, server-side payment verification and commission calculation are required before a payout balance is available.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              const SectionTitle('Settlement status'),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('Available for payout'),
                  trailing: Text(
                    entries.isEmpty ? '—' : _money(available),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Pending review'),
                  trailing: Text(
                    entries.isEmpty ? '—' : _money(pending),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (entries.isNotEmpty) ...[
                const SizedBox(height: 16),
                const SectionTitle('Transactions'),
                const SizedBox(height: 8),
                ...entries.map(
                  (entry) => Card(
                    child: ListTile(
                      leading: Icon(
                        entry.status == 'PAID'
                            ? Icons.check_circle_outline
                            : Icons.schedule_outlined,
                        color: entry.status == 'PAID'
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      title: Text('Job ${entry.jobId}'),
                      subtitle: Text(
                        '${entry.status} · Gross ${_money(entry.grossAmount)} · Commission ${_money(entry.commissionAmount)}',
                      ),
                      trailing: Text(
                        _money(entry.netAmount),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      );
    },
  );

  List<TechnicianEarning> _filtered(
    List<TechnicianEarning> entries,
    String filter,
  ) {
    final now = DateTime.now();
    final start = switch (filter) {
      'Week' => now.subtract(const Duration(days: 7)),
      'Year' => DateTime(now.year),
      _ => DateTime(now.year, now.month),
    };
    return entries.where((entry) => !entry.createdAt.isBefore(start)).toList();
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';
}

class TechReports extends StatelessWidget {
  const TechReports({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<TechnicianProgress>(
    future: sl<TechnicianRepository>().progress(),
    builder: (context, snapshot) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('My progress', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        const Text(
          'Only your verified jobs, reports, rating and earnings are included.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        if (snapshot.connectionState == ConnectionState.waiting)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (snapshot.hasError)
          Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline, color: AppColors.error),
              title: const Text('Could not load your progress'),
              subtitle: Text('${snapshot.error}'),
            ),
          )
        else if (snapshot.data case final progress?) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Job completion',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 5),
                Text(
                  '${progress.completionRate.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (progress.completionRate / 100).clamp(0, 1),
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _TechnicianMetrics(
            children: [
              MetricCard(
                '${progress.completedJobs}',
                'Completed jobs',
                Icons.task_alt,
              ),
              MetricCard(
                '${progress.activeJobs}',
                'Active jobs',
                Icons.timelapse,
              ),
              MetricCard(
                progress.rating.toStringAsFixed(1),
                'Customer rating',
                Icons.star_outline,
              ),
              MetricCard(
                '₹${progress.netEarnings.toStringAsFixed(0)}',
                'Verified earnings',
                Icons.payments_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const SectionTitle('Work reports'),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.description_outlined,
                color: AppColors.primary,
              ),
              title: Text('${progress.submittedReports} submitted reports'),
              subtitle: Text(
                '${progress.pendingApprovals} awaiting customer approval',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.privacy_tip_outlined,
                color: AppColors.success,
              ),
              title: const Text('Private technician report'),
              subtitle: const Text(
                'These totals are calculated by the server for your account only.',
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class TechProfile extends StatelessWidget {
  const TechProfile({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<TechnicianProfile>(
    future: sl<TechnicianRepository>().profile(),
    builder: (context, snapshot) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('My profile', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        const Text(
          'This page only shows data linked to your signed-in account.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        if (snapshot.connectionState == ConnectionState.waiting)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (snapshot.hasError)
          Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline, color: AppColors.error),
              title: const Text('Could not load your profile'),
              subtitle: Text('${snapshot.error}'),
            ),
          )
        else if (snapshot.data case final profile?) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: Text(
                      profile.name.isEmpty
                          ? 'T'
                          : profile.name[0].toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        Text(profile.phone),
                        const SizedBox(height: 6),
                        StatusPill(
                          profile.verificationStatus.replaceAll('_', ' '),
                          color: profile.isApproved
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.shield_outlined, color: AppColors.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SectionTitle('Verified personal details'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('Residential address'),
                  subtitle: Text(
                    profile.address.isEmpty
                        ? 'Address verification pending'
                        : '${profile.address} · ${profile.postalCode}',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Aadhaar'),
                  subtitle: Text(
                    profile.aadhaarLast4 == null
                        ? 'Not submitted'
                        : 'XXXX XXXX ${profile.aadhaarLast4}',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.star_outline),
                  title: const Text('Customer rating'),
                  subtitle: Text(profile.rating.toStringAsFixed(1)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SectionTitle('Approved skills'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: profile.skills
                .map(
                  (skill) => Chip(
                    avatar: const Icon(
                      Icons.verified,
                      color: AppColors.success,
                    ),
                    label: Text(skill),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          AppButton(
            label: profile.isApproved
                ? 'Update verification details'
                : 'Complete eKYC',
            icon: Icons.verified_user_outlined,
            onPressed: () => context.push(
              '/tech/onboarding',
              extra: profile.skills.isEmpty
                  ? 'Electrician'
                  : profile.skills.first,
            ),
          ),
        ],
        const SizedBox(height: 12),
        AppButton(
          label: 'Log out',
          outlined: true,
          onPressed: authSession.signOut,
        ),
      ],
    ),
  );
}

class TechnicianJobPage extends StatelessWidget {
  const TechnicianJobPage({super.key, this.job});
  final TechnicianJob? job;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => JobExecutionBloc(),
    child: JobWorkflow(
      job:
          job ??
          const TechnicianJob(
            'FO-1842',
            'Alex Morgan',
            'AC maintenance',
            '24 Park Street',
            '10:00 AM',
            'Upcoming',
            'High',
          ),
    ),
  );
}

class JobWorkflow extends StatelessWidget {
  const JobWorkflow({super.key, required this.job});
  final TechnicianJob job;
  static const steps = [
    'Accept job',
    'Navigate to customer',
    'Start job',
    'Before photos',
    'Inspection checklist',
    'Work description',
    'Materials used',
    'Additional charges',
    'After photos',
    'Generate summary',
    'Customer signature',
    'Submit completion',
  ];
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<JobExecutionBloc, JobExecutionState>(
        builder: (context, state) => AppShell(
          title: job.id,
          backLocation: '/tech',
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              StatusPill(
                state.completed
                    ? 'Customer confirmation pending'
                    : state.step == 0
                    ? job.status
                    : 'In progress',
                color: AppColors.warning,
              ),
              const SizedBox(height: 14),
              Text(
                job.service,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text('${job.customer} · ${job.address} · ${job.time}'),
              const SizedBox(height: 14),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(child: Text('A')),
                      title: Text(job.customer),
                      subtitle: const Text('+91 98765 43210'),
                      trailing: IconButton(
                        onPressed: () => notice(context, 'Calling customer…'),
                        icon: const Icon(Icons.call),
                      ),
                    ),
                    ListTile(
                      onTap: () => notice(
                        context,
                        'Maps API key and location permission are required.',
                      ),
                      leading: const Icon(
                        Icons.map_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(job.address),
                      subtitle: const Text('2.1 km · ETA 8 min'),
                      trailing: const Icon(Icons.navigation),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Workflow ${state.step + 1}/${steps.length}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (state.step + 1) / steps.length),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[state.step],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      workflowContent(context, state),
                      const SizedBox(height: 16),
                      AppButton(
                        label: state.step == steps.length - 1
                            ? 'Submit report for customer approval'
                            : 'Save & continue',
                        onPressed: () => _advance(context, state),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _advance(BuildContext context, JobExecutionState state) async {
    try {
      if (state.step == 0) {
        await sl<TechnicianRepository>().update(job.id, 'Upcoming');
      } else if (state.step == 2) {
        await sl<TechnicianRepository>().update(job.id, 'In progress');
      } else if (state.step == steps.length - 1) {
        final submitted = await _submitReport(context);
        if (!submitted) return;
      }
      if (!context.mounted) return;
      context.read<JobExecutionBloc>().add(JobStepCompleted());
      if (state.step == steps.length - 1) {
        notice(
          context,
          'Work report submitted. Customer approval and verified payment are required before earnings are confirmed.',
        );
      }
    } catch (error) {
      if (context.mounted) notice(context, '$error');
    }
  }

  Future<bool> _submitReport(BuildContext context) async {
    final key = GlobalKey<FormState>();
    var description = '';
    final submitted = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Submit work report'),
        content: Form(
          key: key,
          child: TextFormField(
            onChanged: (value) => description = value.trim(),
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Work completed',
              hintText: 'Describe inspection, repair and final checks…',
            ),
            validator: (value) => (value ?? '').trim().length < 10
                ? 'Add at least 10 characters'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.pop(dialog, description);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (submitted == null) return false;
    await sl<TechnicianRepository>().submitWorkReport(
      job.id,
      description: submitted,
      summary: 'Service work completed and submitted for customer review.',
    );
    return true;
  }

  Widget workflowContent(BuildContext context, JobExecutionState state) {
    if (state.step == 4) {
      return Column(
        children: List.generate(
          4,
          (index) => CheckboxListTile(
            value: state.checks.contains(index),
            onChanged: (_) =>
                context.read<JobExecutionBloc>().add(ChecklistChanged(index)),
            title: Text(
              [
                'Power isolated safely',
                'Filters inspected',
                'Cooling tested',
                'Work area cleaned',
              ][index],
            ),
          ),
        ),
      );
    }
    if (state.step == 3 || state.step == 8) {
      return OutlinedButton.icon(
        onPressed: () =>
            notice(context, 'Camera/media permission integration is pending.'),
        icon: const Icon(Icons.add_a_photo),
        label: Text(state.step == 3 ? 'Add before photos' : 'Add after photos'),
      );
    }
    if (state.step == 10) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEAE8F2)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(child: Text('Customer signature pad integration')),
      );
    }
    if ([5, 6, 7].contains(state.step)) {
      return const TextField(
        maxLines: 3,
        decoration: InputDecoration(hintText: 'Add work details…'),
      );
    }
    return Text(
      [
        'Review and accept this assignment.',
        'Open navigation and proceed safely.',
        'Confirm arrival before starting.',
        '',
        '',
        '',
        '',
        '',
        '',
        'Generate the report summary.',
        '',
        'Submit the work report for customer review. Completion, earnings and payout are confirmed only after approval and payment verification.',
      ][state.step],
    );
  }
}

void notice(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
