import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/network/api_client.dart';
import '../../../app/dependency_injection.dart';
import '../../auth/presentation/auth_session.dart';
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';
import 'admin_blocs.dart';
import 'admin_dashboard_bloc.dart';

abstract final class _AdminLayout {
  static const gutter = 20.0;
  static const pageTop = 16.0;
  static const pageBottom = 24.0;
  static const cardPadding = 16.0;
  static const cardGap = 12.0;
  static const sectionGap = 24.0;
  static const controlGap = 8.0;
  static const actionHeight = 48.0;
  static const pageInsets = EdgeInsets.fromLTRB(
    gutter,
    pageTop,
    gutter,
    pageBottom,
  );
  static const resultsInsets = EdgeInsets.fromLTRB(
    gutter,
    0,
    gutter,
    pageBottom,
  );
  static const filterInsets = EdgeInsets.fromLTRB(
    gutter,
    pageTop,
    gutter,
    controlGap,
  );

  static ButtonStyle primaryAction() => FilledButton.styleFrom(
    minimumSize: const Size(actionHeight, actionHeight),
    padding: const EdgeInsets.symmetric(horizontal: cardPadding),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int tab = 0;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => AdminDashboardBloc(sl<AdminRepository>())..load(),
      ),
      BlocProvider(
        create: (_) =>
            JobManagementBloc(sl<AdminRepository>())..add(AdminJobsLoaded()),
      ),
      BlocProvider(
        create: (_) => TechnicianManagementBloc(sl<AdminRepository>()),
      ),
      BlocProvider(create: (_) => AdminDateFilterBloc()),
      BlocProvider(create: (_) => ReportsBloc()),
    ],
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Theme.of(context).colorScheme.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        appBar: _AdminAppBar(
          tab: tab,
          height: 42 + MediaQuery.textScalerOf(context).scale(32),
        ),
        body: SafeArea(
          top: false,
          child: IndexedStack(
            index: tab,
            children: const [
              AdminHome(),
              AdminJobsTab(),
              AdminTeamTab(),
              AdminReportsTab(),
              AdminProfileTab(),
            ],
          ),
        ),
        bottomNavigationBar: WorkspaceNavigationBar(
          selectedIndex: tab,
          onSelected: (value) => setState(() => tab = value),
          destinations: const [
            WorkspaceDestination(
              'Dashboard',
              Icons.space_dashboard_outlined,
              Icons.space_dashboard_rounded,
              compactLabel: 'Home',
            ),
            WorkspaceDestination(
              'Jobs',
              Icons.work_outline_rounded,
              Icons.work_rounded,
            ),
            WorkspaceDestination(
              'Team',
              Icons.groups_outlined,
              Icons.groups_rounded,
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
    ),
  );
}

class _AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AdminAppBar({required this.tab, required this.height});

  final int tab;
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height + 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (title, icon) = const [
      ('Admin dashboard', Icons.space_dashboard_outlined),
      ('Job management', Icons.work_outline_rounded),
      ('Technician verification', Icons.verified_user_outlined),
      ('Reports & analytics', Icons.analytics_outlined),
      ('Business settings', Icons.settings_outlined),
    ][tab];
    return AppBar(
      automaticallyImplyLeading: false,
      centerTitle: false,
      toolbarHeight: height,
      titleSpacing: _AdminLayout.gutter,
      backgroundColor: Color.alphaBlend(
        colors.primary.withValues(alpha: .035),
        colors.surface,
      ),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      title: Row(
        children: [
          _SettingsIcon(icon, filled: tab == 0),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FieldOps Pro',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.only(
        left: _AdminLayout.controlGap,
        right: _AdminLayout.gutter,
      ),
      actions: [
        if (ApiConfig.useMocks && tab == 0)
          StatusPill('Demo', color: colors.primary),
        if (ApiConfig.useMocks && tab == 1)
          _CreateAdminJobButton(showLabel: !isCompactWorkspace(context)),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1),
      ),
    );
  }
}

class _CreateAdminJobButton extends StatelessWidget {
  const _CreateAdminJobButton({this.showLabel = false});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (!showLabel) {
      return IconButton.filled(
        tooltip: 'Create demo job',
        onPressed: () => createJob(context),
        icon: const Icon(Icons.add_rounded),
        style: IconButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          minimumSize: const Size.square(_AdminLayout.actionHeight),
        ),
      );
    }
    return Tooltip(
      message: 'Create demo job',
      child: FilledButton.icon(
        onPressed: () => createJob(context),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('New job'),
        style: _AdminLayout.primaryAction(),
      ),
    );
  }
}

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: _AdminLayout.pageInsets,
    children: [
      BlocBuilder<AdminDashboardBloc, AdminDashboardState>(
        builder: (context, state) {
          if (state.loading) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (state.error != null) {
            return Card(
              child: ListTile(
                leading: const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                ),
                title: Text(state.error!),
                trailing: TextButton(
                  onPressed: context.read<AdminDashboardBloc>().load,
                  child: const Text('Retry'),
                ),
              ),
            );
          }
          final data = state.summary!;
          final metrics = [
            (
              '${data.totalCustomers}',
              'Customers',
              Icons.groups_outlined,
              AppColors.primary,
            ),
            (
              '${data.totalTechnicians}',
              'Technicians',
              Icons.engineering_outlined,
              AppColors.secondary,
            ),
            (
              '${data.verifiedTechnicians}',
              'Verified techs',
              Icons.verified_outlined,
              AppColors.success,
            ),
            (
              '${data.pendingTechnicianApprovals}',
              'Pending approvals',
              Icons.fact_check_outlined,
              AppColors.warning,
            ),
            (
              '${data.totalBookings}',
              'Bookings',
              Icons.calendar_month_outlined,
              AppColors.primary,
            ),
            (
              '${data.activeJobs}',
              'Active jobs',
              Icons.work_history_outlined,
              AppColors.warning,
            ),
            (
              '${data.completedJobs}',
              'Completed',
              Icons.check_circle_outline,
              AppColors.success,
            ),
            (
              '${data.cancelledBookings}',
              'Cancelled',
              Icons.cancel_outlined,
              AppColors.error,
            ),
            (
              '${data.pendingPayouts}',
              'Pending payouts',
              Icons.account_balance_wallet_outlined,
              AppColors.secondary,
            ),
            (
              '${data.pendingComplaints}',
              'Open complaints',
              Icons.support_agent_outlined,
              AppColors.error,
            ),
          ];
          return Column(
            children: [
              _AdminMetricGrid(
                metrics: [
                  for (final (value, label, icon, color) in metrics)
                    AdminMetric(value, label, icon, color),
                ],
              ),
              const SizedBox(height: _AdminLayout.sectionGap),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(_AdminLayout.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Finance snapshot',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: _AdminLayout.cardGap),
                      Row(
                        children: [
                          Expanded(
                            child: _FinanceValue(
                              'Verified revenue',
                              data.totalRevenue,
                              AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FinanceValue(
                              'Pending payments',
                              data.pendingPayments,
                              AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: _AdminLayout.controlGap),
                      const Text(
                        'Revenue includes only server-verified paid transactions. Trends appear after a time-series API is available.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: _AdminLayout.sectionGap),
      const SectionTitle('Quick actions'),
      const SizedBox(height: _AdminLayout.controlGap),
      Wrap(
        spacing: _AdminLayout.controlGap,
        runSpacing: _AdminLayout.controlGap,
        children:
            [
                  ('Customers', Icons.people, 'customers'),
                  ('Categories', Icons.category_outlined, 'service-categories'),
                  ('Services', Icons.design_services, 'services'),
                  ('Payments', Icons.payments_outlined, 'payments'),
                  (
                    'Cash review',
                    Icons.receipt_long_outlined,
                    'cash-collections',
                  ),
                  ('Refunds', Icons.currency_exchange_outlined, 'refunds'),
                  (
                    'Settlements',
                    Icons.account_balance_outlined,
                    'settlements',
                  ),
                  ('Payouts', Icons.account_balance_wallet_outlined, 'payouts'),
                  ('Complaints', Icons.support_agent_outlined, 'complaints'),
                  ('Invoices', Icons.receipt_long, 'invoices'),
                ]
                .map(
                  (x) => ActionChip(
                    avatar: Icon(x.$2, size: 18, color: AppColors.primary),
                    label: Text(x.$1),
                    onPressed: () => context.push('/admin/manage/${x.$3}'),
                  ),
                )
                .toList(),
      ),
      const SizedBox(height: _AdminLayout.sectionGap),
      const SectionTitle('Pending assignments'),
      const SizedBox(height: _AdminLayout.cardGap),
      BlocBuilder<JobManagementBloc, AdminJobsState>(
        builder: (context, state) => Column(
          children: state.all
              .where((x) => x.technician == 'Unassigned')
              .map(
                (job) => Padding(
                  padding: const EdgeInsets.only(bottom: _AdminLayout.cardGap),
                  child: AdminJobCard(job),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
}

class _AdminMetricGrid extends StatelessWidget {
  const _AdminMetricGrid({required this.metrics, this.stackOnCompact = false});

  final List<AdminMetric> metrics;
  final bool stackOnCompact;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = stackOnCompact && isCompactWorkspace(context)
          ? 1
          : !stackOnCompact && constraints.maxWidth >= 640
          ? 4
          : 2;
      return Column(
        children: [
          for (var offset = 0; offset < metrics.length; offset += columns) ...[
            if (offset > 0) const SizedBox(height: _AdminLayout.cardGap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var cell = 0; cell < columns; cell++) ...[
                    if (cell > 0) const SizedBox(width: _AdminLayout.cardGap),
                    Expanded(
                      child: offset + cell < metrics.length
                          ? metrics[offset + cell]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

class AdminMetric extends StatelessWidget {
  const AdminMetric(this.value, this.label, this.icon, this.color, {super.key});
  final String value, label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(_AdminLayout.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: _AdminLayout.controlGap),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
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

class _FinanceValue extends StatelessWidget {
  const _FinanceValue(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '₹${value.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    ],
  );
}

class AdminJobsTab extends StatefulWidget {
  const AdminJobsTab({super.key});
  @override
  State<AdminJobsTab> createState() => _AdminJobsTabState();
}

class _AdminJobsTabState extends State<AdminJobsTab> {
  String status = 'All', query = '';
  void apply(BuildContext context) =>
      context.read<JobManagementBloc>().add(AdminJobsFiltered(query, status));
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: _AdminLayout.filterInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                onChanged: (v) {
                  query = v;
                  apply(context);
                },
                decoration: const InputDecoration(
                  hintText: 'Search jobs',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: _AdminLayout.controlGap),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: _AdminLayout.controlGap,
                  children:
                      [
                            'All',
                            'Pending',
                            'Upcoming',
                            'In progress',
                            'Completed',
                            'Cancelled',
                          ]
                          .map(
                            (x) => ChoiceChip(
                              label: Text(x),
                              selected: status == x,
                              selectedColor: colors.primaryContainer,
                              checkmarkColor: colors.primary,
                              labelStyle: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: status == x
                                    ? colors.primary
                                    : colors.onSurface,
                              ),
                              onSelected: (_) {
                                setState(() => status = x);
                                apply(context);
                              },
                            ),
                          )
                          .toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: BlocBuilder<JobManagementBloc, AdminJobsState>(
            builder: (context, state) {
              if (state.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.error == null && state.visible.isEmpty) {
                return const Center(child: Text('No jobs found.'));
              }
              return ListView(
                padding: _AdminLayout.resultsInsets,
                children: [
                  if (state.error case final error?)
                    _ManagementError(
                      message: error,
                      onRetry: () async {
                        context.read<JobManagementBloc>().add(
                          AdminJobsLoaded(),
                        );
                      },
                    ),
                  for (final job in state.visible)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: _AdminLayout.cardGap,
                      ),
                      child: AdminJobCard(job),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class AdminJobCard extends StatelessWidget {
  const AdminJobCard(this.job, {super.key});
  final AdminJob job;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.all(_AdminLayout.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusPill(
                    job.status,
                    color: job.status == 'Completed'
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
              ),
              const SizedBox(width: _AdminLayout.controlGap),
              Expanded(
                child: Text(
                  job.id,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: _AdminLayout.controlGap),
          Row(
            children: [
              Expanded(
                child: Text(job.service, style: theme.textTheme.titleMedium),
              ),
              if (!job.canAssign) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${job.customer} · ₹${job.amount}\nTechnician: ${job.technician}',
            style: theme.textTheme.bodyMedium,
          ),
          if (job.canAssign) ...[
            const SizedBox(height: _AdminLayout.controlGap),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: _AdminLayout.controlGap,
                runSpacing: _AdminLayout.controlGap,
                children: [
                  TextButton(
                    onPressed: () => showJobDetails(context, job),
                    child: const Text('Details'),
                  ),
                  FilledButton.icon(
                    onPressed: () => assignTechnician(context, job),
                    style: _AdminLayout.primaryAction(),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: Text(
                      job.technician == 'Unassigned' ? 'Assign' : 'Reassign',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: job.canAssign
          ? content
          : Semantics(
              button: true,
              hint: 'Open job details',
              child: InkWell(
                onTap: () => showJobDetails(context, job),
                child: content,
              ),
            ),
    );
  }
}

class AdminTeamTab extends StatelessWidget {
  const AdminTeamTab({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final compact = isCompactWorkspace(context);
    return Column(
      children: [
        Padding(
          padding: _AdminLayout.filterInsets,
          child: TextField(
            onChanged: context.read<TechnicianManagementBloc>().search,
            decoration: const InputDecoration(
              hintText: 'Search team',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: BlocBuilder<TechnicianManagementBloc, TechnicianManagementState>(
            builder: (context, state) {
              if (state.loading && state.members.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.error != null && state.members.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: context
                              .read<TechnicianManagementBloc>()
                              .reload,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView(
                padding: _AdminLayout.resultsInsets,
                children: state.members
                    .map(
                      (member) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: _AdminLayout.cardGap,
                        ),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: _AdminLayout.cardPadding,
                            ),
                            minVerticalPadding: 12,
                            onTap: member.role == 'Technician'
                                ? () => showStaff(context, member)
                                : null,
                            leading: CircleAvatar(
                              backgroundColor: colors.primaryContainer,
                              foregroundColor: colors.primary,
                              child: Text(
                                member.name.isEmpty ? '?' : member.name[0],
                              ),
                            ),
                            title: Text(
                              member.name,
                              style: theme.textTheme.titleMedium,
                            ),
                            subtitle: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 2,
                                  children: [
                                    Text(
                                      member.skill,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    Text(
                                      '${member.rating.toStringAsFixed(1)}\u00a0★',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                if (compact) ...[
                                  const SizedBox(
                                    height: _AdminLayout.controlGap,
                                  ),
                                  _staffStatus(member),
                                ],
                              ],
                            ),
                            trailing: compact ? null : _staffStatus(member),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

Widget _staffStatus(StaffMember member) => StatusPill(
  _verificationLabel(member.verificationStatus),
  color: _verificationColor(member.verificationStatus),
);

class AdminReportsTab extends StatelessWidget {
  const AdminReportsTab({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AdminDashboardBloc, AdminDashboardState>(
    builder: (context, state) => ListView(
      padding: _AdminLayout.pageInsets,
      children: [
        if (state.loading)
          const Center(child: CircularProgressIndicator())
        else if (state.error != null)
          Card(child: ListTile(title: Text(state.error!)))
        else ...[
          _AdminMetricGrid(
            stackOnCompact: true,
            metrics: [
              AdminMetric(
                '₹${state.summary!.totalRevenue.toStringAsFixed(2)}',
                'Verified revenue',
                Icons.payments_outlined,
                AppColors.success,
              ),
              AdminMetric(
                '${state.summary!.completedJobs}',
                'Completed jobs',
                Icons.check_circle_outline,
                AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: _AdminLayout.sectionGap),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(_AdminLayout.cardPadding),
              child: Row(
                children: [
                  Icon(Icons.query_stats_outlined, color: AppColors.primary),
                  SizedBox(width: _AdminLayout.cardGap),
                  Expanded(
                    child: Text(
                      'Trend charts and comparison percentages will appear after the backend provides dated aggregate series. No estimated or fabricated analytics are displayed.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: _AdminLayout.cardGap),
          AppButton(
            label: 'Copy summary as CSV',
            icon: Icons.copy_outlined,
            outlined: true,
            onPressed: () async {
              final summary = state.summary!;
              final csv =
                  'Metric,Value\n'
                  'Verified revenue (INR),${summary.totalRevenue.toStringAsFixed(2)}\n'
                  'Completed jobs,${summary.completedJobs}\n';
              await Clipboard.setData(ClipboardData(text: csv));
              if (context.mounted) notice(context, 'Report summary copied.');
            },
          ),
        ],
      ],
    ),
  );
}

class AdminProfileTab extends StatelessWidget {
  const AdminProfileTab({super.key});

  Future<void> _chooseTheme(BuildContext context) async {
    final selected = await showModalBottomSheet<AppPalette>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('App theme', style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final palette in AppPalette.values)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: palette.color,
                    radius: 13,
                  ),
                  title: Text(palette.label),
                  selected: palette == appPalette.value,
                  trailing: palette == appPalette.value
                      ? const Icon(Icons.check_circle_outline)
                      : null,
                  onTap: () => Navigator.pop(sheet, palette),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) await selectAppPalette(selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: _AdminLayout.pageInsets,
          children: [
            Card(
              color: colors.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(_AdminLayout.cardPadding),
                child: Row(
                  children: [
                    _SettingsIcon(
                      Icons.admin_panel_settings_outlined,
                      filled: true,
                    ),
                    const SizedBox(width: _AdminLayout.cardGap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ApiConfig.useMocks ? 'Demo Admin' : 'Administrator',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ApiConfig.useMocks
                                ? 'Sample workspace'
                                : 'Signed in to your workspace',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: _AdminLayout.sectionGap),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: _AdminLayout.cardPadding,
                  vertical: _AdminLayout.controlGap,
                ),
                leading: const _SettingsIcon(Icons.palette_outlined),
                title: Text('App theme', style: theme.textTheme.titleMedium),
                subtitle: Text(appPalette.value.label),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _chooseTheme(context),
              ),
            ),
            const SizedBox(height: _AdminLayout.sectionGap),
            Text('Workspace setup', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Configuration is unavailable in this build.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: _AdminLayout.cardGap),
            const _SettingsGroup(
              title: 'Business operations',
              icon: Icons.business_outlined,
              items: ['Business profile', 'Service areas', 'Operating hours'],
            ),
            const SizedBox(height: _AdminLayout.cardGap),
            const _SettingsGroup(
              title: 'Billing and payments',
              icon: Icons.account_balance_wallet_outlined,
              items: [
                'Tax configuration',
                'Payment settings',
                'Subscription management',
              ],
            ),
            const SizedBox(height: _AdminLayout.cardGap),
            const _SettingsGroup(
              title: 'Notifications and security',
              icon: Icons.shield_outlined,
              items: ['Notification settings', 'Security settings'],
            ),
            const SizedBox(height: _AdminLayout.sectionGap),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: colors.error),
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Log out'),
              onPressed: authSession.signOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon(this.icon, {this.filled = false});
  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: filled ? 48 : 40,
      height: filled ? 48 : 40,
      decoration: BoxDecoration(
        color: filled ? colors.primary : colors.primaryContainer,
        borderRadius: BorderRadius.circular(filled ? 14 : 12),
      ),
      child: Icon(
        icon,
        color: filled ? colors.onPrimary : colors.primary,
        size: 22,
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.icon,
    required this.items,
  });
  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      key: PageStorageKey(title),
      tilePadding: const EdgeInsets.symmetric(
        horizontal: _AdminLayout.cardPadding,
        vertical: 4,
      ),
      childrenPadding: const EdgeInsets.fromLTRB(
        _AdminLayout.cardPadding,
        0,
        _AdminLayout.cardPadding,
        _AdminLayout.cardGap,
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      shape: const Border(),
      collapsedShape: const Border(),
      leading: _SettingsIcon(icon),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      children: [
        const Divider(),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
            child: Text(item, style: Theme.of(context).textTheme.bodyMedium),
          ),
      ],
    ),
  );
}

class AdminManagementPage extends StatelessWidget {
  const AdminManagementPage(this.kind, {super.key});
  final String kind;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ManagementCubit(sl<AdminRepository>(), kind),
    child: Builder(
      builder: (context) => AppShell(
        title: managementTitle(kind),
        backLocation: '/admin',
        actions: ApiConfig.useMocks && _mockCanAdd(kind)
            ? [
                IconButton(
                  onPressed: () => addRecord(context, kind),
                  icon: const Icon(Icons.add),
                ),
              ]
            : null,
        child: BlocBuilder<ManagementCubit, ManagementState>(
          builder: (context, state) {
            if (state.loading && state.records.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null && state.records.isEmpty) {
              return _ManagementError(
                message: state.error!,
                onRetry: context.read<ManagementCubit>().reload,
              );
            }
            if (state.records.isEmpty) {
              return _ManagementEmpty(
                kind: kind,
                onRefresh: context.read<ManagementCubit>().reload,
              );
            }
            return RefreshIndicator(
              onRefresh: context.read<ManagementCubit>().reload,
              child: ListView(
                padding: _AdminLayout.pageInsets,
                children: [
                  if (state.error != null)
                    Card(
                      color: AppColors.error.withValues(alpha: .08),
                      child: ListTile(
                        leading: const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                        ),
                        title: Text(state.error!),
                        trailing: TextButton(
                          onPressed: context.read<ManagementCubit>().reload,
                          child: const Text('Retry'),
                        ),
                      ),
                    ),
                  ...state.records.map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: _AdminLayout.cardGap,
                      ),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: _AdminLayout.cardPadding,
                          ),
                          minVerticalPadding: _AdminLayout.controlGap,
                          onTap: state.processingId == record.id
                              ? null
                              : () => manageRecord(context, kind, record),
                          leading: Icon(
                            _managementIcon(kind),
                            color: AppColors.primary,
                          ),
                          title: Text(
                            record.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(record.subtitle),
                          trailing: state.processingId == record.id
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    StatusPill(
                                      record.status ??
                                          (record.active
                                              ? 'Active'
                                              : 'Inactive'),
                                      color: _recordStatusColor(record),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  if (state.loading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

class AdminJobsPage extends StatelessWidget {
  const AdminJobsPage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        JobManagementBloc(sl<AdminRepository>())..add(AdminJobsLoaded()),
    child: const AppShell(
      title: 'Jobs & dispatch',
      backLocation: '/admin',
      actions: [if (ApiConfig.useMocks) _CreateAdminJobButton()],
      child: AdminJobsTab(),
    ),
  );
}

String managementTitle(String kind) => switch (kind) {
  'customers' => 'Customer management',
  'service-categories' => 'Service categories',
  'services' => 'Service & pricing',
  'invoices' => 'Finance & invoices',
  'payments' => 'Verified payments',
  'cash-collections' => 'Cash receipt verification',
  'refunds' => 'Refund requests',
  'settlements' => 'Earning settlements',
  'payouts' => 'Technician payouts',
  'complaints' => 'Complaints & support',
  'team' => 'Roles & permissions',
  _ => 'Management',
};

bool _mockCanAdd(String kind) =>
    const {'customers', 'services', 'team'}.contains(kind);

IconData _managementIcon(String kind) => switch (kind) {
  'customers' => Icons.person_outline,
  'service-categories' => Icons.category_outlined,
  'services' => Icons.design_services_outlined,
  'invoices' => Icons.receipt_long_outlined,
  'payments' => Icons.payments_outlined,
  'cash-collections' => Icons.receipt_long_outlined,
  'refunds' => Icons.currency_exchange_outlined,
  'settlements' => Icons.account_balance_outlined,
  'payouts' => Icons.account_balance_wallet_outlined,
  'complaints' => Icons.support_agent_outlined,
  'team' => Icons.admin_panel_settings_outlined,
  _ => Icons.business_center_outlined,
};

Color _recordStatusColor(ManagedRecord record) {
  final status = record.status?.toUpperCase();
  if (status == null) {
    return record.active ? AppColors.success : AppColors.muted;
  }
  if ({
    'PAID',
    'RESOLVED',
    'ACTIVE',
    'APPROVED',
    'COMPLETED',
    'VERIFIED',
    'SUCCEEDED',
    'AVAILABLE',
  }.contains(status)) {
    return AppColors.success;
  }
  if ({
    'FAILED',
    'REJECTED',
    'CANCELLED',
    'SUSPENDED',
    'REVERSED',
  }.contains(status)) {
    return AppColors.error;
  }
  if ({
    'PENDING',
    'AUTHORIZED',
    'REQUESTED',
    'PROCESSING',
    'OPEN',
    'IN PROGRESS',
    'REOPENED',
    'SUBMITTED',
    'HELD',
  }.contains(status)) {
    return AppColors.warning;
  }
  return AppColors.muted;
}

class _RecordAction {
  const _RecordAction(
    this.label,
    this.action,
    this.icon, {
    this.destructive = false,
    this.inputLabel,
    this.inputKey,
    this.minLength = 1,
    this.extra = const {},
  });

  final String label;
  final String action;
  final IconData icon;
  final bool destructive;
  final String? inputLabel;
  final String? inputKey;
  final int minLength;
  final Map<String, dynamic> extra;
}

List<_RecordAction> _recordActions(String kind, ManagedRecord record) {
  final status = (record.status ?? (record.active ? 'Active' : 'Disabled'))
      .toUpperCase()
      .replaceAll('_', ' ');
  if (kind == 'customers') {
    return status == 'SUSPENDED'
        ? const [
            _RecordAction(
              'Reactivate customer',
              'activate',
              Icons.person_add_alt_1_outlined,
            ),
          ]
        : const [
            _RecordAction(
              'Suspend customer',
              'suspend',
              Icons.person_off_outlined,
              destructive: true,
              inputLabel: 'Suspension reason',
              inputKey: 'reason',
              minLength: 5,
            ),
          ];
  }
  if (kind == 'service-categories' || kind == 'services') {
    return status == 'ACTIVE'
        ? const [
            _RecordAction(
              'Disable',
              'disable',
              Icons.pause_circle_outline,
              destructive: true,
            ),
          ]
        : const [_RecordAction('Enable', 'enable', Icons.play_circle_outline)];
  }
  if (kind == 'complaints') {
    return switch (status) {
      'OPEN' || 'REOPENED' => const [
        _RecordAction('Start investigation', 'start', Icons.play_arrow_rounded),
      ],
      'IN PROGRESS' => const [
        _RecordAction(
          'Resolve complaint',
          'resolve',
          Icons.task_alt_outlined,
          inputLabel: 'Resolution provided to the customer',
          inputKey: 'resolution',
          minLength: 10,
        ),
      ],
      'RESOLVED' => const [
        _RecordAction(
          'Reopen complaint',
          'reopen',
          Icons.replay_outlined,
          destructive: true,
          inputLabel: 'Reason for reopening',
          inputKey: 'reason',
          minLength: 5,
        ),
      ],
      _ => const [],
    };
  }
  if (kind == 'payouts') {
    return switch (status) {
      'REQUESTED' => const [
        _RecordAction('Approve payout', 'approve', Icons.verified_outlined),
        _RecordAction(
          'Reject payout',
          'reject',
          Icons.cancel_outlined,
          destructive: true,
          inputLabel: 'Rejection reason',
          inputKey: 'reason',
          minLength: 5,
        ),
      ],
      'APPROVED' || 'FAILED' => const [
        _RecordAction('Start processing', 'process', Icons.sync_outlined),
        _RecordAction(
          'Reject and release earnings',
          'reject',
          Icons.cancel_outlined,
          destructive: true,
          inputLabel: 'Rejection reason',
          inputKey: 'reason',
          minLength: 5,
        ),
      ],
      'PROCESSING' => const [
        _RecordAction(
          'Confirm payout sent',
          'mark-paid',
          Icons.account_balance_outlined,
          inputLabel: 'Bank or provider reference',
          inputKey: 'reference',
          minLength: 6,
          extra: {'confirmationSource': 'BANK_PORTAL'},
        ),
        _RecordAction(
          'Mark processing failed',
          'fail',
          Icons.error_outline,
          destructive: true,
          inputLabel: 'Failure reason',
          inputKey: 'reason',
          minLength: 5,
        ),
      ],
      _ => const [],
    };
  }
  if (kind == 'cash-collections') {
    return status == 'SUBMITTED'
        ? const [
            _RecordAction(
              'Verify cash receipt',
              'verify',
              Icons.verified_outlined,
            ),
            _RecordAction(
              'Reject cash receipt',
              'reject',
              Icons.cancel_outlined,
              destructive: true,
              inputLabel: 'Rejection reason',
              inputKey: 'reason',
              minLength: 5,
            ),
          ]
        : const [];
  }
  if (kind == 'refunds') {
    return switch (status) {
      'REQUESTED' => const [
        _RecordAction('Approve refund', 'approve', Icons.verified_outlined),
        _RecordAction(
          'Reject refund',
          'reject',
          Icons.cancel_outlined,
          destructive: true,
          inputLabel: 'Rejection reason',
          inputKey: 'reason',
          minLength: 5,
        ),
      ],
      'APPROVED' => const [
        _RecordAction(
          'Process with payment provider',
          'process',
          Icons.currency_exchange_outlined,
        ),
        _RecordAction(
          'Reject refund',
          'reject',
          Icons.cancel_outlined,
          destructive: true,
          inputLabel: 'Rejection reason',
          inputKey: 'reason',
          minLength: 5,
        ),
      ],
      'FAILED' => const [
        _RecordAction(
          'Retry provider refund',
          'process',
          Icons.refresh_rounded,
        ),
      ],
      _ => const [],
    };
  }
  if (kind == 'settlements') {
    return switch (status) {
      'PENDING' => const [
        _RecordAction(
          'Approve as available',
          'available',
          Icons.task_alt_outlined,
        ),
        _RecordAction(
          'Place on hold',
          'hold',
          Icons.pause_circle_outline,
          destructive: true,
          inputLabel: 'Hold reason',
          inputKey: 'reason',
          minLength: 5,
        ),
        _RecordAction(
          'Reverse earning',
          'reverse',
          Icons.undo_outlined,
          destructive: true,
          inputLabel: 'Reversal reason',
          inputKey: 'reason',
          minLength: 5,
        ),
      ],
      'AVAILABLE' => const [
        _RecordAction(
          'Place on hold',
          'hold',
          Icons.pause_circle_outline,
          destructive: true,
          inputLabel: 'Hold reason',
          inputKey: 'reason',
          minLength: 5,
        ),
        _RecordAction(
          'Reverse earning',
          'reverse',
          Icons.undo_outlined,
          destructive: true,
          inputLabel: 'Reversal reason',
          inputKey: 'reason',
          minLength: 5,
        ),
      ],
      'HELD' => const [
        _RecordAction(
          'Release as available',
          'available',
          Icons.play_circle_outline,
        ),
        _RecordAction(
          'Reverse earning',
          'reverse',
          Icons.undo_outlined,
          destructive: true,
          inputLabel: 'Reversal reason',
          inputKey: 'reason',
          minLength: 5,
        ),
      ],
      _ => const [],
    };
  }
  return const [];
}

Future<void> manageRecord(
  BuildContext context,
  String kind,
  ManagedRecord record,
) async {
  final actions = _recordActions(kind, record);
  final selected = await showModalBottomSheet<_RecordAction>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(record.title, style: Theme.of(sheet).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              record.subtitle,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            Text('Reference: ${record.id}'),
            Text(
              'Status: ${record.status ?? (record.active ? 'Active' : 'Inactive')}',
            ),
            if (ApiConfig.useMocks && actions.isNotEmpty)
              const Text('Demo actions affect sample data only.'),
            const SizedBox(height: 16),
            ...actions.map(
              (action) => ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => Navigator.pop(sheet, action),
                leading: Icon(
                  action.icon,
                  color: action.destructive
                      ? AppColors.error
                      : AppColors.primary,
                ),
                title: Text(
                  action.label,
                  style: TextStyle(
                    color: action.destructive ? AppColors.error : null,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (selected == null || !context.mounted) return;

  final payload = <String, dynamic>{...selected.extra};
  if (selected.inputKey != null) {
    final value = await _askActionValue(context, selected);
    if (value == null || !context.mounted) return;
    payload[selected.inputKey!] = value;
  } else {
    final confirmed = await _confirmRecordAction(context, selected, record);
    if (confirmed != true || !context.mounted) return;
  }

  final error = await context.read<ManagementCubit>().performAction(
    record.id,
    selected.action,
    data: payload,
  );
  if (!context.mounted) return;
  notice(context, error ?? '${selected.label} completed successfully.');
}

Future<bool?> _confirmRecordAction(
  BuildContext context,
  _RecordAction action,
  ManagedRecord record,
) => showDialog<bool>(
  context: context,
  builder: (dialog) => AlertDialog(
    title: Text(action.label),
    content: Text(
      ApiConfig.useMocks
          ? 'Apply this action to ${record.title} in the demo workspace?'
          : 'Apply this action to ${record.title}? The server will validate and audit the change.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialog, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: action.destructive
            ? FilledButton.styleFrom(backgroundColor: AppColors.error)
            : null,
        onPressed: () => Navigator.pop(dialog, true),
        child: const Text('Confirm'),
      ),
    ],
  ),
);

Future<String?> _askActionValue(
  BuildContext context,
  _RecordAction action,
) async {
  var value = '';
  String? validationError;
  final result = await showDialog<String>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(action.label),
        content: TextField(
          onChanged: (text) => value = text,
          autofocus: true,
          minLines: action.inputKey == 'reference' ? 1 : 3,
          maxLines: action.inputKey == 'reference' ? 1 : 5,
          decoration: InputDecoration(
            labelText: action.inputLabel,
            errorText: validationError,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: action.destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            onPressed: () {
              final trimmed = value.trim();
              if (trimmed.length < action.minLength) {
                setDialogState(
                  () => validationError =
                      'Enter at least ${action.minLength} characters.',
                );
                return;
              }
              Navigator.pop(dialog, trimmed);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    ),
  );
  return result;
}

class _ManagementError extends StatelessWidget {
  const _ManagementError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 42,
            color: AppColors.muted,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _ManagementEmpty extends StatelessWidget {
  const _ManagementEmpty({required this.kind, required this.onRefresh});
  final String kind;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_managementIcon(kind), size: 42, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            'No ${managementTitle(kind).toLowerCase()} records found.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Refresh when new records are available.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    ),
  );
}

void notice(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
void assignTechnician(BuildContext context, AdminJob job) {
  final jobsBloc = context.read<JobManagementBloc>();
  showModalBottomSheet(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Assign technician',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(sheet),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<StaffMember>>(
              future: sl<AdminRepository>().staff(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final eligible = (snapshot.data ?? const <StaffMember>[])
                    .where(
                      (member) =>
                          member.role == 'Technician' &&
                          member.active &&
                          member.verificationStatus == 'APPROVED',
                    )
                    .toList();
                if (eligible.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'No approved online technician is currently eligible.',
                    ),
                  );
                }
                return Column(
                  children: eligible
                      .map(
                        (member) => ListTile(
                          onTap: () {
                            jobsBloc.add(AdminJobAssigned(job.id, member.id));
                            Navigator.pop(sheet);
                          },
                          leading: CircleAvatar(child: Text(member.name[0])),
                          title: Text(member.name),
                          subtitle: Text(
                            '${member.skill} · ${member.rating.toStringAsFixed(1)} ★',
                          ),
                          trailing: const StatusPill(
                            'Online',
                            color: AppColors.success,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

void showJobDetails(BuildContext context, AdminJob job) {
  showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(job.service),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reference: ${job.id}'),
          Text('Customer: ${job.customer}'),
          Text('Technician: ${job.technician}'),
          Text('Status: ${job.status}'),
          Text('Amount: ₹${job.amount}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> createJob(BuildContext context) async {
  final repo = sl<AdminRepository>();
  if (repo is! MockAdminRepository) return;
  final form = GlobalKey<FormState>();
  var service = '', customer = '', price = '';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Create demo job'),
      scrollable: true,
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Service description',
              ),
              onChanged: (value) => service = value.trim(),
              validator: (_) =>
                  service.isEmpty ? 'Enter a service description.' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Customer name'),
              onChanged: (value) => customer = value.trim(),
              validator: (_) =>
                  customer.isEmpty ? 'Enter a customer name.' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Amount (₹)'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) => price = value,
              validator: (_) =>
                  (int.tryParse(price) ?? -1) < 0 ? 'Enter an amount.' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) Navigator.pop(dialog, true);
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  repo.createDemoJob(customer, service, int.parse(price));
  context.read<JobManagementBloc>().add(AdminJobsLoaded());
  context.read<AdminDashboardBloc?>()?.load();
  notice(context, 'Demo job added.');
}

Future<void> showStaff(BuildContext context, StaffMember member) async {
  final status = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    member.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(sheet),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text('${member.role} · ${member.skill}\nRating ${member.rating} ★'),
            const SizedBox(height: 10),
            StatusPill(
              _verificationLabel(member.verificationStatus),
              color: _verificationColor(member.verificationStatus),
            ),
            const SizedBox(height: 16),
            if (member.verificationStatus != 'APPROVED') ...[
              AppButton(
                label: 'Approve after document review',
                onPressed: () => Navigator.pop(sheet, 'APPROVED'),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Reject application',
                outlined: true,
                onPressed: () => Navigator.pop(sheet, 'REJECTED'),
              ),
            ] else
              AppButton(
                label: 'Suspend technician',
                outlined: true,
                onPressed: () => Navigator.pop(sheet, 'SUSPENDED'),
              ),
          ],
        ),
      ),
    ),
  );
  if (status == null || !context.mounted) return;
  String? reason;
  if (status != 'APPROVED') {
    reason = await _askActionValue(
      context,
      _RecordAction(
        status == 'REJECTED' ? 'Reject application' : 'Suspend technician',
        status,
        Icons.person_off_outlined,
        destructive: true,
        inputLabel: 'Required reason',
        inputKey: 'reason',
        minLength: 5,
      ),
    );
    if (reason == null || !context.mounted) return;
  }
  final error = await context.read<TechnicianManagementBloc>().review(
    member.id,
    status,
    reason: reason,
  );
  if (!context.mounted) return;
  if (error == null) context.read<AdminDashboardBloc>().load();
  notice(context, error ?? 'Technician status updated.');
}

String _verificationLabel(String status) => status
    .toLowerCase()
    .replaceAll('_', ' ')
    .split(' ')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');

Color _verificationColor(String status) => switch (status) {
  'APPROVED' => AppColors.success,
  'REJECTED' || 'SUSPENDED' => AppColors.error,
  'PENDING_VERIFICATION' || 'UNDER_REVIEW' => AppColors.warning,
  _ => AppColors.muted,
};

void addRecord(BuildContext context, String kind) {
  final title = TextEditingController();
  final subtitle = TextEditingController();
  showDialog(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text('Add ${managementTitle(kind)} record'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Name or title'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: subtitle,
            decoration: const InputDecoration(labelText: 'Details'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (title.text.isNotEmpty) {
              context.read<ManagementCubit>().add(title.text, subtitle.text);
            }
            Navigator.pop(dialog);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
