import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../app/dependency_injection.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/presentation/auth_session.dart';
import '../../integrations/data/integration_repository.dart';
import 'customer_activity_widgets.dart';
import 'service_categories.dart';

final customerHasUpcomingBooking = ValueNotifier<bool>(false);
final customerUpcomingServiceName = ValueNotifier<String>('AC maintenance');
final customerUpcomingSchedule = ValueNotifier<String>('Tomorrow · 10:00 AM');
final customerPaymentMethod = ValueNotifier<String>('Pay after service');
final customerServiceAddress = ValueNotifier<String>(
  '221B Baker Street, New York',
);

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  int tab = 0;
  int unreadNotifications = customerHasUpcomingBooking.value ? 2 : 1;
  String filterCategory = 'All services';
  String filterBudget = 'Any budget';
  String filterTiming = 'Any time';
  double filterRating = 0;
  String customerAddress = customerServiceAddress.value;
  String bookingFilter = 'All';
  String bookingSchedule = customerUpcomingSchedule.value;
  String preferredVisitTime = 'Morning';
  String customerLanguage = 'English';
  bool preferSameTechnician = true;
  bool locating = false;
  bool assistantLoading = false;
  String? assistantReply;
  String? assistantRecommendedService;
  final assistantController = TextEditingController();

  @override
  void initState() {
    super.initState();
    customerHasUpcomingBooking.addListener(_handleBookingStateChanged);
    customerUpcomingSchedule.addListener(_handleScheduleChanged);
  }

  void _handleBookingStateChanged() {
    if (!mounted) return;
    setState(() {
      if (customerHasUpcomingBooking.value) {
        unreadNotifications++;
        bookingSchedule = customerUpcomingSchedule.value;
        tab = 2;
      } else {
        unreadNotifications = 1;
      }
    });
  }

  void _handleScheduleChanged() {
    if (!mounted) return;
    setState(() => bookingSchedule = customerUpcomingSchedule.value);
  }

  @override
  void dispose() {
    customerHasUpcomingBooking.removeListener(_handleBookingStateChanged);
    customerUpcomingSchedule.removeListener(_handleScheduleChanged);
    assistantController.dispose();
    super.dispose();
  }

  static const serviceData =
      <
        ({
          String name,
          int price,
          String image,
          String category,
          String timing,
          double rating,
        })
      >[
        (
          name: 'AC deep service',
          price: 799,
          image: 'assets/images/ac-service.png',
          category: 'AC & HVAC',
          timing: 'Today',
          rating: 4.9,
        ),
        (
          name: 'Leak repair',
          price: 499,
          image: 'assets/images/plumbing-service.png',
          category: 'Plumbing',
          timing: 'Today',
          rating: 4.8,
        ),
        (
          name: 'Electrical safety check',
          price: 599,
          image: 'assets/images/categories/electrical.png',
          category: 'Electrical',
          timing: 'Tomorrow',
          rating: 4.7,
        ),
        (
          name: 'Home cleaning',
          price: 1299,
          image: 'assets/images/cleaning-service.png',
          category: 'Cleaning',
          timing: 'This week',
          rating: 4.9,
        ),
        (
          name: 'Appliance inspection',
          price: 399,
          image: 'assets/images/categories/appliance_repair.png',
          category: 'Appliance Repair',
          timing: 'Tomorrow',
          rating: 4.6,
        ),
      ];

  static const bookingHistory =
      <({String service, String date, int price, String status})>[
        (
          service: 'Premium home cleaning',
          date: '09 Nov 2026',
          price: 1299,
          status: 'Completed',
        ),
        (
          service: 'Leak & tap repair',
          date: '21 Oct 2026',
          price: 499,
          status: 'Cancelled',
        ),
      ];

  bool get hasActiveFilters =>
      filterCategory != 'All services' ||
      filterBudget != 'Any budget' ||
      filterTiming != 'Any time' ||
      filterRating > 0;

  List<
    ({
      String name,
      int price,
      String image,
      String category,
      String timing,
      double rating,
    })
  >
  get filteredServices => serviceData.where((service) {
    final categoryMatches =
        filterCategory == 'All services' || service.category == filterCategory;
    final budgetMatches = switch (filterBudget) {
      'Under ₹500' => service.price < 500,
      '₹500–₹1000' => service.price >= 500 && service.price <= 1000,
      '₹1000+' => service.price > 1000,
      _ => true,
    };
    final timingMatches =
        filterTiming == 'Any time' || service.timing == filterTiming;
    return categoryMatches &&
        budgetMatches &&
        timingMatches &&
        service.rating >= filterRating;
  }).toList();
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Theme.of(context).colorScheme.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: tab,
          children: [
            _home(context),
            _services(context),
            _bookings(context),
            _assistant(context),
            _profile(context),
          ],
        ),
      ),
      bottomNavigationBar: WorkspaceNavigationBar(
        selectedIndex: tab,
        onSelected: (v) => setState(() => tab = v),
        destinations: const [
          WorkspaceDestination('Home', Icons.home_outlined, Icons.home_rounded),
          WorkspaceDestination(
            'Services',
            Icons.grid_view_outlined,
            Icons.grid_view_rounded,
            compactLabel: 'Browse',
          ),
          WorkspaceDestination(
            'Bookings',
            Icons.event_note_outlined,
            Icons.event_note_rounded,
            compactLabel: 'Visits',
          ),
          WorkspaceDestination(
            'Assistant',
            Icons.auto_awesome_outlined,
            Icons.auto_awesome_rounded,
            compactLabel: 'Assist',
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

  Widget _home(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _homeHeader(context),
          const SizedBox(height: 20),
          TextField(
            readOnly: true,
            onTap: () => _searchSheet(context),
            decoration: InputDecoration(
              hintText: 'Search AC repair, plumbing…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Filter services',
                onPressed: () => _filterSheet(context),
                icon: Icon(
                  Icons.tune_rounded,
                  color: hasActiveFilters
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
            ),
          ),
          if (hasActiveFilters) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.filter_alt_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${filteredServices.length} matching services',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear'),
                ),
              ],
            ),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (filterCategory != 'All services') filterCategory,
                if (filterBudget != 'Any budget') filterBudget,
                if (filterTiming != 'Any time') filterTiming,
                if (filterRating > 0)
                  '${filterRating.toStringAsFixed(1)}+ rating',
              ].map((label) => Chip(label: Text(label))).toList(),
            ),
          ],
          const SizedBox(height: 24),
          if (customerHasUpcomingBooking.value) ...[
            _upcomingServiceCard(context),
            const SizedBox(height: 18),
          ],
          Row(
            children: [
              const Expanded(child: SectionTitle('Quick actions')),
              TextButton(
                onPressed: () => _activitySheet(context),
                child: const Text('View activity'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CustomerQuickActions(
            actions: [
              CustomerQuickAction(
                label: 'Book service',
                caption: 'Schedule a trusted pro',
                icon: Icons.add_circle_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
                onTap: () => context.push('/customer/booking'),
              ),
              CustomerQuickAction(
                label: 'Track visit',
                caption: 'Follow service progress',
                icon: Icons.location_searching_rounded,
                color: AppColors.success,
                onTap: () => _trackService(context),
              ),
              CustomerQuickAction(
                label: 'Book again',
                caption: 'Repeat a past service',
                icon: Icons.replay_rounded,
                color: const Color(0xFF2563EB),
                onTap: () => context.push(
                  '/customer/booking',
                  extra: 'Premium home cleaning',
                ),
              ),
              CustomerQuickAction(
                label: 'Bills & receipts',
                caption: 'Review service payments',
                icon: Icons.receipt_long_outlined,
                color: const Color(0xFF0F766E),
                onTap: () => _invoiceSheet(context),
              ),
              CustomerQuickAction(
                label: 'Rate service',
                caption: 'Share your experience',
                icon: Icons.star_outline_rounded,
                color: AppColors.warning,
                onTap: () => _ratingSheet(context),
              ),
              CustomerQuickAction(
                label: 'Get support',
                caption: 'Chat or report an issue',
                icon: Icons.support_agent_rounded,
                color: const Color(0xFFDB2777),
                onTap: () => _supportSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 28),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 192,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/images/ac-promo.png', fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xF2FFFFFF), Color(0x00FFFFFF)],
                        stops: [0, .72],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'AC care, without\nthe wait',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Limited offer · up to 20% off',
                          style: TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: () => context.push(
                            '/customer/booking',
                            extra: 'AC deep service',
                          ),
                          child: const Text('Book now'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(child: SectionTitle('What service do you need?')),
              TextButton(
                onPressed: () => context.push('/customer/categories'),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 4 : 3;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: .9,
                ),
                itemCount: 8,
                itemBuilder: (_, i) => CategoryCard(
                  category: i < 7
                      ? serviceCategories[i]
                      : serviceCategories.last,
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(child: SectionTitle('Popular services')),
              TextButton(
                onPressed: () => setState(() => tab = 1),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (filteredServices.isEmpty)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  const Icon(Icons.search_off_rounded, color: AppColors.muted),
                  const SizedBox(height: 8),
                  const Text(
                    'No services match these filters',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear filters'),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 188,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filteredServices.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final service = filteredServices[i];
                  return InkWell(
                    onTap: () =>
                        context.push('/customer/booking', extra: service.name),
                    child: Container(
                      width: 154,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              service.image,
                              height: 90,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            service.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'From ₹${service.price} · ${service.rating} ★',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(child: SectionTitle('Recent activity')),
              TextButton(
                onPressed: () => _activitySheet(context),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CustomerActivityList(
            entries: [
              if (customerHasUpcomingBooking.value)
                CustomerActivityEntry(
                  title: 'Service visit scheduled',
                  subtitle:
                      '${customerUpcomingServiceName.value} · ${customerUpcomingSchedule.value}',
                  actionLabel: 'Track',
                  icon: Icons.event_available_outlined,
                  color: AppColors.success,
                  onTap: () => context.push('/customer/details'),
                )
              else
                CustomerActivityEntry(
                  title: 'Home cleaning completed',
                  subtitle: '09 Nov 2026 · Professional cleaning',
                  actionLabel: 'Rate',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                  onTap: () => _ratingSheet(context),
                ),
              CustomerActivityEntry(
                title: 'Invoice FO-1774 paid',
                subtitle: '₹1,299 · UPI · 09 Nov 2026',
                actionLabel: 'Receipt',
                icon: Icons.receipt_long_outlined,
                color: const Color(0xFF0F766E),
                onTap: () => _invoiceSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const SectionTitle('Home care plans'),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              onTap: () => _homeCarePlansSheet(context),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE7DFFF),
                child: Icon(Icons.verified_outlined, color: AppColors.primary),
              ),
              title: const Text('Save on routine maintenance'),
              subtitle: const Text(
                'Explore annual plans with priority support',
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle('Offers for you'),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.local_offer_outlined,
                color: AppColors.primary,
              ),
              title: const Text('FIELD20 · 20% off your first booking'),
              subtitle: const Text('New customer offer · terms apply'),
              trailing: IconButton(
                icon: const Icon(Icons.copy_outlined),
                tooltip: 'Copy FIELD20',
                onPressed: () async {
                  await Clipboard.setData(const ClipboardData(text: 'FIELD20'));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('FIELD20 copied')),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Need help choosing?',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Describe the issue and get suggestions.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => tab = 3),
                  child: const Text('Ask AI'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _homeHeader(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.white, Theme.of(context).colorScheme.primaryContainer],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0F432A91),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              alignment: Alignment.center,
              child: const Text(
                'AM',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good morning',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Alex Morgan',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<AppPalette>(
              tooltip: 'Change theme',
              icon: const Icon(Icons.palette_outlined),
              initialValue: appPalette.value,
              onSelected: selectAppPalette,
              itemBuilder: (context) => [
                for (final palette in AppPalette.values)
                  CheckedPopupMenuItem(
                    value: palette,
                    checked: palette == appPalette.value,
                    child: Text(palette.label),
                  ),
              ],
            ),
            Badge(
              isLabelVisible: unreadNotifications > 0,
              label: Text('$unreadNotifications'),
              offset: const Offset(-2, 2),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFFE8E5F0)),
                ),
                child: IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => _notificationSheet(context),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Material(
          color: Colors.white.withValues(alpha: .82),
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: () => _locationSheet(context),
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 19,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customerAddress,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, color: AppColors.muted),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _upcomingServiceCard(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFEAE7F2)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D17152A),
          blurRadius: 18,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'UPCOMING SERVICE',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const StatusPill('Assigned', color: AppColors.success),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          customerUpcomingServiceName.value,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: AppColors.muted,
            ),
            const SizedBox(width: 8),
            Text(
              customerUpcomingSchedule.value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.home_outlined, size: 18, color: AppColors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                customerServiceAddress.value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.push('/customer/details'),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('View booking details'),
          ),
        ),
      ],
    ),
  );

  void _trackService(BuildContext context) {
    if (customerHasUpcomingBooking.value) {
      context.push('/customer/details');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.softPrimary,
                child: Icon(
                  Icons.location_searching_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'No active visit',
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Once a service is scheduled, live status and technician updates will appear here.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              AppButton(
                label: 'Book a service',
                icon: Icons.add_rounded,
                onPressed: () {
                  Navigator.pop(sheet);
                  context.push('/customer/booking');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _activitySheet(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your activity',
                    style: Theme.of(sheet).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(sheet),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Text('Bookings, payments and service updates in one place.'),
            const SizedBox(height: 16),
            if (customerHasUpcomingBooking.value)
              Card(
                child: ListTile(
                  onTap: () {
                    Navigator.pop(sheet);
                    context.push('/customer/details');
                  },
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE5F7EA),
                    child: Icon(
                      Icons.location_searching_rounded,
                      color: AppColors.success,
                    ),
                  ),
                  title: Text(
                    customerUpcomingServiceName.value,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    'Scheduled · ${customerUpcomingSchedule.value}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                onTap: () {
                  Navigator.pop(sheet);
                  _ratingSheet(context);
                },
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF3D6),
                  child: Icon(
                    Icons.star_outline_rounded,
                    color: AppColors.warning,
                  ),
                ),
                title: const Text(
                  'Premium home cleaning',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Completed · 09 Nov 2026'),
                trailing: const Text(
                  'Rate now',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                onTap: () {
                  Navigator.pop(sheet);
                  _invoiceSheet(context);
                },
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE4F5F2),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: Color(0xFF0F766E),
                  ),
                ),
                title: const Text(
                  'Invoice FO-1774 paid',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('₹1,299 · UPI · 09 Nov 2026'),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _invoiceSheet(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bills & receipts',
                    style: Theme.of(sheet).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(sheet),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Text('Clear payment status for every service.'),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                onTap: () {
                  Navigator.pop(sheet);
                  _receiptDialog(context);
                },
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE5F7EA),
                  child: Icon(Icons.check_rounded, color: AppColors.success),
                ),
                title: const Text(
                  'Premium home cleaning',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Invoice FO-1774 · Paid via UPI'),
                trailing: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹1,299',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Receipt',
                      style: TextStyle(color: AppColors.primary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            if (customerHasUpcomingBooking.value) ...[
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.softPrimary,
                    child: Icon(
                      Icons.schedule_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    customerUpcomingServiceName.value,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(customerPaymentMethod.value),
                  trailing: const Text(
                    'After service',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Future<void> _receiptDialog(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      icon: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
      title: const Text('Payment receipt'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReceiptRow('Invoice', 'FO-1774'),
          _ReceiptRow('Service', 'Premium home cleaning'),
          _ReceiptRow('Paid on', '09 Nov 2026'),
          _ReceiptRow('Method', 'UPI'),
          Divider(height: 24),
          _ReceiptRow('Total paid', '₹1,299', strong: true),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Done'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(dialog);
            notice(context, 'Receipt ready to share');
          },
          icon: const Icon(Icons.ios_share_rounded),
          label: const Text('Share'),
        ),
      ],
    ),
  );

  Future<void> _ratingSheet(BuildContext context) async {
    var rating = 0;
    final feedback = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              24 + MediaQuery.viewInsetsOf(sheet).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rate your service',
                  style: Theme.of(sheet).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                const Text('How was your Premium home cleaning experience?'),
                const SizedBox(height: 18),
                Semantics(
                  label: '$rating out of 5 stars selected',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var value = 1; value <= 5; value++)
                        IconButton(
                          tooltip: '$value star${value == 1 ? '' : 's'}',
                          onPressed: () => update(() => rating = value),
                          iconSize: 36,
                          icon: Icon(
                            value <= rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: AppColors.warning,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: feedback,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Feedback (optional)',
                    hintText: 'Tell us what went well',
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Submit review',
                  icon: Icons.send_rounded,
                  onPressed: rating == 0
                      ? null
                      : () {
                          Navigator.pop(sheet);
                          notice(
                            context,
                            'Thanks for your $rating-star review',
                          );
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    feedback.dispose();
  }

  void _supportSheet(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How can we help?',
              style: Theme.of(sheet).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            const Text('Support is available every day from 8 AM to 10 PM.'),
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                onTap: () {
                  Navigator.pop(sheet);
                  notice(context, 'Support chat started');
                },
                leading: const CircleAvatar(
                  backgroundColor: AppColors.softPrimary,
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text(
                  'Chat with support',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Typical reply in under 2 minutes'),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                onTap: () {
                  Navigator.pop(sheet);
                  _reportIssueSheet(context);
                },
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFECEC),
                  child: Icon(
                    Icons.report_problem_outlined,
                    color: AppColors.error,
                  ),
                ),
                title: const Text(
                  'Report a service issue',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Create a support ticket for follow-up'),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _reportIssueSheet(BuildContext context) async {
    var issueType = 'Service quality';
    final details = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              24 + MediaQuery.viewInsetsOf(sheet).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report an issue',
                  style: Theme.of(sheet).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      ['Service quality', 'Payment', 'Technician', 'Other']
                          .map(
                            (value) => ChoiceChip(
                              label: Text(value),
                              selected: issueType == value,
                              onSelected: (_) =>
                                  update(() => issueType = value),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: details,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'What happened?',
                    hintText: 'Add details so we can resolve this faster',
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Create support ticket',
                  icon: Icons.confirmation_number_outlined,
                  onPressed: () {
                    Navigator.pop(sheet);
                    notice(context, '$issueType ticket T-1025 created');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    details.dispose();
  }

  void _homeCarePlansSheet(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Home care plans',
              style: Theme.of(sheet).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            const Text('Preventive care with transparent annual pricing.'),
            const SizedBox(height: 14),
            _PlanCard(
              name: 'Essential',
              price: '₹2,499 / year',
              benefits: '2 inspections · 10% service discount',
              onTap: () {
                Navigator.pop(sheet);
                notice(context, 'Essential plan selected');
              },
            ),
            const SizedBox(height: 10),
            _PlanCard(
              name: 'Complete Home',
              price: '₹4,999 / year',
              benefits: '4 inspections · priority support · 15% off',
              featured: true,
              onTap: () {
                Navigator.pop(sheet);
                notice(context, 'Complete Home plan selected');
              },
            ),
          ],
        ),
      ),
    ),
  );

  void _notificationSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Notifications',
                    style: Theme.of(sheet).textTheme.headlineMedium,
                  ),
                ),
                if (unreadNotifications > 0)
                  TextButton(
                    onPressed: () {
                      setState(() => unreadNotifications = 0);
                      Navigator.pop(sheet);
                    },
                    child: const Text('Mark all read'),
                  ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(sheet),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (customerHasUpcomingBooking.value)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEDE7FF),
                    child: Icon(
                      Icons.event_available,
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text(
                    'Booking scheduled',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${customerUpcomingServiceName.value} · ${customerUpcomingSchedule.value}',
                  ),
                  trailing: const Icon(
                    Icons.circle,
                    size: 9,
                    color: AppColors.primary,
                  ),
                ),
              ),
            const Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(0xFFFFF3D6),
                  child: Icon(
                    Icons.local_offer_outlined,
                    color: AppColors.warning,
                  ),
                ),
                title: Text(
                  '20% off AC care',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('Limited offer available until Friday'),
                trailing: Icon(Icons.circle, size: 9, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _locationSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Choose service address',
                    style: Theme.of(c).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(c),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEDE7FF),
                  child: Icon(Icons.home_outlined, color: AppColors.primary),
                ),
                title: const Text(
                  'Home',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(customerAddress),
                trailing: const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                ),
              ),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: locating ? 'Getting current location…' : 'Use my location',
              icon: Icons.my_location_rounded,
              onPressed: locating
                  ? null
                  : () {
                      Navigator.pop(c);
                      _useCurrentLocation(context);
                    },
            ),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text('Add new address'),
              onTap: () {
                Navigator.pop(c);
                notice(context, 'Address manager opens in Profile');
              },
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _useCurrentLocation(BuildContext context) async {
    setState(() => locating = true);
    notice(context, 'Getting your current location…');
    try {
      final position = await sl<IntegrationRepository>().currentLocation();
      if (!context.mounted) return;
      setState(() {
        customerAddress =
            'Current location · ${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}';
        customerServiceAddress.value = customerAddress;
      });
      if (context.mounted) notice(context, 'Current location selected');
    } on ApiException catch (error) {
      if (context.mounted) notice(context, error.message);
    } catch (_) {
      if (context.mounted) {
        notice(context, 'Could not get your current location');
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  void _searchSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search services',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(c),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Popular searches',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Wrap(
              spacing: 8,
              children: ['AC repair', 'Plumbing', 'Home cleaning']
                  .map(
                    (x) => ActionChip(
                      label: Text(x),
                      onPressed: () {
                        Navigator.pop(c);
                        context.push('/customer/booking');
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    ),
  );

  void _clearFilters() => setState(() {
    filterCategory = 'All services';
    filterBudget = 'Any budget';
    filterTiming = 'Any time';
    filterRating = 0;
  });

  void _filterSheet(BuildContext context) {
    var draftCategory = filterCategory;
    var draftBudget = filterBudget;
    var draftTiming = filterTiming;
    var draftRating = filterRating;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, updateSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filter services',
                        style: Theme.of(sheet).textTheme.headlineMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => updateSheet(() {
                        draftCategory = 'All services';
                        draftBudget = 'Any budget';
                        draftTiming = 'Any time';
                        draftRating = 0;
                      }),
                      child: const Text('Reset'),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheet),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Category',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                            'All services',
                            'AC & HVAC',
                            'Plumbing',
                            'Electrical',
                            'Cleaning',
                            'Appliance Repair',
                          ]
                          .map(
                            (value) => ChoiceChip(
                              label: Text(value),
                              selected: draftCategory == value,
                              onSelected: (_) =>
                                  updateSheet(() => draftCategory = value),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Budget',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Any budget', 'Under ₹500', '₹500–₹1000', '₹1000+']
                      .map(
                        (value) => ChoiceChip(
                          label: Text(value),
                          selected: draftBudget == value,
                          onSelected: (_) =>
                              updateSheet(() => draftBudget = value),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Availability',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Any time', 'Today', 'Tomorrow', 'This week']
                      .map(
                        (value) => ChoiceChip(
                          label: Text(value),
                          selected: draftTiming == value,
                          onSelected: (_) =>
                              updateSheet(() => draftTiming = value),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Minimum rating',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [0.0, 4.5, 4.8]
                      .map(
                        (value) => ChoiceChip(
                          label: Text(value == 0 ? 'Any rating' : '$value+ ★'),
                          selected: draftRating == value,
                          onSelected: (_) =>
                              updateSheet(() => draftRating = value),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Show matching services',
                  icon: Icons.filter_alt_outlined,
                  onPressed: () {
                    setState(() {
                      filterCategory = draftCategory;
                      filterBudget = draftBudget;
                      filterTiming = draftTiming;
                      filterRating = draftRating;
                    });
                    Navigator.pop(sheet);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _page(String title, List<Widget> items) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Expanded(child: ListView(children: items)),
        ],
      ),
    ),
  );
  Widget _services(BuildContext c) => _page('Services for your home', [
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6738E8), Color(0xFF9B7CF4)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.home_repair_service_rounded, color: Colors.white),
          SizedBox(height: 8),
          Text(
            'What can we help with?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Choose a facility, compare available services and book the one you need.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    ...serviceCategories.map(
      (category) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => c.push('/customer/categories/${category.slug}'),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    category.image,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${category.services.length} services · View & book',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    ),
  ]);
  Widget _bookings(BuildContext c) {
    final showUpcoming =
        customerHasUpcomingBooking.value &&
        (bookingFilter == 'All' || bookingFilter == 'Upcoming');
    final visibleHistory = bookingHistory
        .where(
          (booking) =>
              bookingFilter == 'All' || booking.status == bookingFilter,
        )
        .toList();
    final hasResults = showUpcoming || visibleHistory.isNotEmpty;

    return _page('My bookings', [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['All', 'Upcoming', 'Completed', 'Cancelled']
              .map(
                (filter) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: bookingFilter == filter,
                    onSelected: (_) => setState(() => bookingFilter = filter),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 14),
      if (showUpcoming) ...[
        _bookingCard(c),
        if (visibleHistory.isNotEmpty) const SizedBox(height: 14),
      ],
      for (var index = 0; index < visibleHistory.length; index++) ...[
        _historyBookingCard(c, visibleHistory[index]),
        if (index < visibleHistory.length - 1) const SizedBox(height: 10),
      ],
      if (!hasResults) _emptyBookings(),
      const SizedBox(height: 14),
      AppButton(
        label: hasResults ? 'Book another service' : 'Browse services',
        icon: Icons.add_rounded,
        onPressed: () => c.push('/customer/booking'),
      ),
    ]);
  }

  Widget _emptyBookings() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        const CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.softPrimary,
          child: Icon(Icons.event_available_outlined, color: AppColors.primary),
        ),
        const SizedBox(height: 10),
        Text(
          'No $bookingFilter bookings',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          'Bookings in this category will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
      ],
    ),
  );

  Widget _historyBookingCard(
    BuildContext context,
    ({String service, String date, int price, String status}) booking,
  ) {
    final completed = booking.status == 'Completed';
    final statusColor = completed ? AppColors.success : AppColors.muted;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.service,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                StatusPill(booking.status, color: statusColor),
              ],
            ),
            const SizedBox(height: 10),
            _bookingInfo(Icons.calendar_today_outlined, booking.date),
            const SizedBox(height: 7),
            _bookingInfo(
              Icons.payments_outlined,
              '₹${booking.price} ${completed ? '· Paid' : '· Refunded'}',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/customer/booking', extra: booking.service),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Book again'),
                ),
                if (completed)
                  OutlinedButton.icon(
                    onPressed: () => _ratingSheet(context),
                    icon: const Icon(Icons.star_outline_rounded),
                    label: const Text('Rate'),
                  ),
                if (completed)
                  OutlinedButton.icon(
                    onPressed: () => _invoiceSheet(context),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Receipt'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookingCard(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'UPCOMING SERVICE',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const StatusPill('Scheduled', color: AppColors.success),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            customerUpcomingServiceName.value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _bookingInfo(Icons.calendar_today_outlined, bookingSchedule),
          const SizedBox(height: 8),
          _bookingInfo(
            Icons.location_on_outlined,
            customerServiceAddress.value,
          ),
          const SizedBox(height: 8),
          _bookingInfo(Icons.payments_outlined, customerPaymentMethod.value),
          const Divider(height: 28),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Icon(Icons.engineering_outlined)),
            title: Text('Technician assignment pending'),
            subtitle: Text(
              'We’ll notify you when your technician is assigned.',
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/customer/details'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Details'),
              ),
              OutlinedButton.icon(
                onPressed: () => _rescheduleBooking(context),
                icon: const Icon(Icons.edit_calendar_outlined),
                label: const Text('Reschedule'),
              ),
              OutlinedButton.icon(
                onPressed: () => _cancelBooking(context),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _bookingInfo(IconData icon, String value) => Row(
    children: [
      Icon(icon, size: 18, color: AppColors.muted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(value, style: const TextStyle(color: AppColors.muted)),
      ),
    ],
  );

  Future<void> _rescheduleBooking(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a new time',
                style: Theme.of(sheet).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              ...[
                'Tomorrow · 02:00 PM',
                'Sat, 22 Nov · 10:00 AM',
                'Sun, 23 Nov · 11:00 AM',
              ].map(
                (slot) => ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: Text(slot),
                  onTap: () => Navigator.pop(sheet, slot),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted && context.mounted) {
      setState(() {
        bookingSchedule = selected;
        customerUpcomingSchedule.value = selected;
      });
      notice(context, 'Booking rescheduled to $selected');
    }
  }

  Future<void> _cancelBooking(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: const Text('This will cancel your scheduled service.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && context.mounted) {
      customerHasUpcomingBooking.value = false;
      setState(() => bookingFilter = 'Cancelled');
      notice(context, 'Booking cancelled');
    }
  }

  Widget _assistant(BuildContext c) => _page('Service assistant', [
    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B2EFF), Color(0xFF8B5CFF)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: Colors.white),
          SizedBox(height: 12),
          Text(
            'What needs fixing?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Describe the problem and get the right service recommendation.',
            style: TextStyle(color: Color(0xFFE9E1FF), height: 1.4),
          ),
        ],
      ),
    ),
    const SizedBox(height: 18),
    const Text('Try asking', style: TextStyle(fontWeight: FontWeight.w800)),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          [
                'My AC is not cooling',
                'There is a water leak',
                'Need an electrician',
              ]
              .map(
                (x) => ActionChip(
                  label: Text(x),
                  onPressed: assistantLoading
                      ? null
                      : () => _askAssistant(c, x),
                ),
              )
              .toList(),
    ),
    const SizedBox(height: 18),
    TextField(
      controller: assistantController,
      minLines: 1,
      maxLines: 3,
      textInputAction: TextInputAction.send,
      onSubmitted: assistantLoading ? null : (value) => _askAssistant(c, value),
      decoration: InputDecoration(
        hintText: 'Describe your issue…',
        suffixIcon: IconButton(
          icon: assistantLoading
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded, color: AppColors.primary),
          onPressed: assistantLoading
              ? null
              : () => _askAssistant(c, assistantController.text),
        ),
      ),
    ),
    if (assistantReply != null) ...[
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE4D9FF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_outlined, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Recommended for you',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(assistantReply!, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 16),
            AppButton(
              label: 'Book this service',
              icon: Icons.calendar_month_outlined,
              onPressed: () => c.push(
                '/customer/booking',
                extra: assistantRecommendedService,
              ),
            ),
          ],
        ),
      ),
    ],
  ]);

  Future<void> _askAssistant(BuildContext context, String issue) async {
    final cleanIssue = issue.trim();
    if (cleanIssue.length < 3) {
      notice(context, 'Please describe the issue first');
      return;
    }
    assistantController.text = cleanIssue;
    setState(() => assistantLoading = true);

    final lower = cleanIssue.toLowerCase();
    var service = 'Home Maintenance Inspection';
    var guidance = 'A professional can inspect the issue and confirm the fix.';
    if (lower.contains('ac') ||
        lower.contains('cool') ||
        lower.contains('hvac')) {
      service = 'AC Inspection';
      guidance = 'Best for cooling, airflow, noise, or leakage problems.';
    } else if (lower.contains('leak') ||
        lower.contains('water') ||
        lower.contains('tap')) {
      service = 'Pipe Leakage Repair';
      guidance = 'A plumber can locate the source and prevent water damage.';
    } else if (lower.contains('electric') ||
        lower.contains('switch') ||
        lower.contains('power')) {
      service = 'Electrical Safety Inspection';
      guidance =
          'Avoid touching exposed wiring and book a verified electrician.';
    } else if (lower.contains('clean')) {
      service = 'Deep Home Cleaning';
      guidance =
          'Choose the home size and preferred cleaning add-ons while booking.';
    }

    try {
      if (!ApiConfig.useMocks) {
        final result = await sl<IntegrationRepository>().ai(
          'service_recommendation',
          cleanIssue,
        );
        final remoteText = result['draft'] ?? result['recommendation'];
        if (remoteText != null && '$remoteText'.trim().isNotEmpty) {
          guidance = '$remoteText';
        }
      }
    } catch (_) {
      // Keep the deterministic recommendation available when AI is offline.
    } finally {
      if (mounted) {
        setState(() {
          assistantRecommendedService = service;
          assistantReply = '$service\n$guidance';
          assistantLoading = false;
        });
      }
    }
  }

  // Retained as the support flow that is opened from Profile settings.
  // ignore: unused_element
  Widget _support(BuildContext c) => _page('Help & support', [
    const Text('We are here whenever you need us.'),
    const SizedBox(height: 20),
    AppButton(
      label: 'Start a support chat',
      icon: Icons.chat_bubble_outline,
      onPressed: () => notice(c, 'Support chat opened'),
    ),
    const SizedBox(height: 20),
    const Text('Recent tickets', style: TextStyle(fontWeight: FontWeight.w800)),
    _statusCard('Invoice correction', 'T-1024', 'Open', AppColors.warning),
    _statusCard('Technician feedback', 'T-981', 'Resolved', AppColors.success),
  ]);
  Widget _profile(BuildContext c) => _page('Account', [
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child: Text(
              'AM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alex Morgan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'alex@fieldops.io',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Icon(Icons.verified_rounded, color: Colors.white),
        ],
      ),
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: _profileStatus(
            Icons.check_circle_outline_rounded,
            '12 services',
            'Completed',
            AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _profileStatus(
            Icons.savings_outlined,
            '₹1,240 saved',
            'With offers',
            AppColors.primary,
          ),
        ),
      ],
    ),
    const SizedBox(height: 16),
    const Text(
      'Personal settings',
      style: TextStyle(fontWeight: FontWeight.w900),
    ),
    const SizedBox(height: 8),
    _accountTile(
      Icons.location_on_outlined,
      'Service address',
      customerAddress,
      () => _locationSheet(c),
    ),
    _accountTile(
      Icons.credit_card_outlined,
      'Payment method',
      customerPaymentMethod.value,
      () => _paymentMethodsSheet(c),
    ),
    _accountTile(
      Icons.tune_rounded,
      'Service preferences',
      'Language, time and technician preferences',
      () => _preferencesSheet(c),
    ),
    const SizedBox(height: 10),
    const Text(
      'Support & privacy',
      style: TextStyle(fontWeight: FontWeight.w900),
    ),
    const SizedBox(height: 8),
    _accountTile(
      Icons.notifications_none_rounded,
      'Notifications',
      'Booking alerts and offers',
      () => _notificationSheet(c),
    ),
    _accountTile(
      Icons.support_agent_rounded,
      'Help & support',
      'Chat, FAQs and service issues',
      () => _supportSheet(c),
    ),
    _accountTile(
      Icons.receipt_long_outlined,
      'Bills & receipts',
      'Payment history and invoices',
      () => _invoiceSheet(c),
    ),
    const SizedBox(height: 12),
    AppButton(
      label: 'Log out',
      icon: Icons.logout_rounded,
      outlined: true,
      onPressed: () => _confirmLogout(c),
    ),
  ]);

  Widget _profileStatus(
    IconData icon,
    String title,
    String status,
    Color color,
  ) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(status, style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _accountTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEDE7FF),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );

  void _preferencesSheet(BuildContext context) {
    var draftTime = preferredVisitTime;
    var draftLanguage = customerLanguage;
    var draftSameTechnician = preferSameTechnician;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service preferences',
                  style: Theme.of(sheet).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                const Text('Personalize future recommendations and visits.'),
                const SizedBox(height: 18),
                const Text(
                  'Preferred visit time',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['Morning', 'Afternoon', 'Evening']
                      .map(
                        (value) => ChoiceChip(
                          label: Text(value),
                          selected: draftTime == value,
                          onSelected: (_) => update(() => draftTime = value),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Communication language',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['English', 'Hindi']
                      .map(
                        (value) => ChoiceChip(
                          label: Text(value),
                          selected: draftLanguage == value,
                          onSelected: (_) =>
                              update(() => draftLanguage = value),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Prefer the same technician',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'When your previously rated professional is available',
                  ),
                  value: draftSameTechnician,
                  onChanged: (value) =>
                      update(() => draftSameTechnician = value),
                ),
                const SizedBox(height: 10),
                AppButton(
                  label: 'Save preferences',
                  icon: Icons.check_rounded,
                  onPressed: () {
                    setState(() {
                      preferredVisitTime = draftTime;
                      customerLanguage = draftLanguage;
                      preferSameTechnician = draftSameTechnician;
                    });
                    Navigator.pop(sheet);
                    notice(context, 'Service preferences saved');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _paymentMethodsSheet(BuildContext context) {
    var selected = customerPaymentMethod.value;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment methods',
                  style: Theme.of(sheet).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose how you want to pay for your next service.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                ...[
                  (
                    'UPI',
                    Icons.qr_code_2_rounded,
                    'Pay securely with any UPI app',
                  ),
                  (
                    'Credit / debit card',
                    Icons.credit_card_rounded,
                    'Visa, Mastercard and RuPay',
                  ),
                  (
                    'Pay after service',
                    Icons.payments_outlined,
                    'Pay after the work is completed',
                  ),
                ].map(
                  (method) => Card(
                    color: selected == method.$1
                        ? const Color(0xFFF1ECFF)
                        : Colors.white,
                    child: ListTile(
                      onTap: () => update(() => selected = method.$1),
                      leading: Icon(method.$2, color: AppColors.primary),
                      title: Text(
                        method.$1,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(method.$3),
                      trailing: Icon(
                        selected == method.$1
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected == method.$1
                            ? AppColors.primary
                            : AppColors.muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Save payment preference',
                  icon: Icons.lock_outline_rounded,
                  onPressed: () {
                    customerPaymentMethod.value = selected;
                    setState(() {});
                    Navigator.pop(sheet);
                    notice(context, '$selected selected');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to book or manage services.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      customerHasUpcomingBooking.value = false;
      authSession.signOut();
    }
  }

  Widget _statusCard(String title, String date, String status, Color color) =>
      Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(15),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(Icons.home_repair_service, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(date),
          trailing: StatusPill(status, color: color),
        ),
      );
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.name,
    required this.price,
    required this.benefits,
    required this.onTap,
    this.featured = false,
  });

  final String name;
  final String price;
  final String benefits;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) => Card(
    color: featured ? AppColors.softPrimary : Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (featured)
                const StatusPill('Best value', color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            price,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(benefits),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onTap,
              child: const Text('Choose plan'),
            ),
          ),
        ],
      ),
    ),
  );
}

class BookingPage extends StatefulWidget {
  const BookingPage({super.key, this.initialService});
  final String? initialService;

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  late int step;
  late String paymentMethod;
  String? selectedService;
  String? selectedSlot;

  @override
  void initState() {
    super.initState();
    selectedService = widget.initialService;
    paymentMethod = customerPaymentMethod.value;
    step = selectedService == null ? 0 : 1;
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.useMocks) {
      return const AppShell(
        title: 'Book a service',
        backLocation: '/customer',
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Online booking is unavailable in this workspace. Contact your service provider to schedule a visit.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && step > 0) setState(() => step--);
      },
      child: AppShell(
        title: 'Book a service',
        backLocation: '/customer',
        onBack: () {
          if (step > 0) {
            setState(() => step--);
          } else if (context.canPop()) {
            context.pop();
          } else {
            context.go('/customer');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: (step + 1) / 4),
              const SizedBox(height: 20),
              Text(
                [
                  'Choose a service',
                  'Pick a time',
                  'Choose payment',
                  'Review booking',
                ][step],
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: step == 0
                    ? ListView(
                        children:
                            [
                                  'AC maintenance',
                                  'Plumbing repair',
                                  'Electrical inspection',
                                ]
                                .map(
                                  (x) => ListTile(
                                    onTap: () => setState(() {
                                      selectedService = x;
                                      step = 1;
                                    }),
                                    title: Text(x),
                                    subtitle: const Text('From ₹499'),
                                    trailing: const Icon(Icons.chevron_right),
                                  ),
                                )
                                .toList(),
                      )
                    : step == 1
                    ? ListView(
                        children: ['09:00 AM', '10:00 AM', '02:00 PM']
                            .map(
                              (x) => ListTile(
                                onTap: () => setState(() {
                                  selectedSlot = 'Tomorrow · $x';
                                  step = 2;
                                }),
                                title: Text(x),
                                subtitle: const Text('Tomorrow'),
                                trailing: const Icon(Icons.schedule_outlined),
                              ),
                            )
                            .toList(),
                      )
                    : step == 2
                    ? ListView(
                        children: [
                          _paymentChoice(
                            'UPI',
                            'Pay securely with any UPI app',
                            Icons.qr_code_2_rounded,
                          ),
                          _paymentChoice(
                            'Credit / debit card',
                            'Visa, Mastercard and RuPay',
                            Icons.credit_card_rounded,
                          ),
                          _paymentChoice(
                            'Pay after service',
                            'Pay when the service is completed',
                            Icons.handshake_outlined,
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Online payment is collected only after a secure invoice is created.',
                              style: TextStyle(
                                color: AppColors.muted,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedService ?? 'Home service',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(selectedSlot ?? 'Time not selected'),
                                  const SizedBox(height: 8),
                                  Text(customerServiceAddress.value),
                                  const Divider(height: 28),
                                  Text('Payment: $paymentMethod'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              AppButton(
                label: step == 3 ? 'Confirm booking' : 'Continue',
                onPressed: !_canContinue
                    ? null
                    : () {
                        if (step < 3) {
                          setState(() => step++);
                        } else {
                          customerPaymentMethod.value = paymentMethod;
                          customerUpcomingServiceName.value =
                              selectedService ?? 'Home service';
                          customerUpcomingSchedule.value =
                              selectedSlot ?? 'Tomorrow · 10:00 AM';
                          customerHasUpcomingBooking.value = true;
                          notice(
                            context,
                            paymentMethod == 'Pay after service'
                                ? 'Booking confirmed'
                                : 'Booking confirmed. Pay after invoice generation.',
                          );
                          context.go('/customer');
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canContinue => switch (step) {
    0 => selectedService != null,
    1 => selectedSlot != null,
    _ => true,
  };

  Widget _paymentChoice(String title, String subtitle, IconData icon) {
    final selected = paymentMethod == title;
    return Card(
      color: selected ? const Color(0xFFF1ECFF) : Colors.white,
      child: ListTile(
        onTap: () => setState(() => paymentMethod = title),
        leading: CircleAvatar(
          backgroundColor: selected
              ? AppColors.primary
              : const Color(0xFFF1ECFF),
          child: Icon(icon, color: selected ? Colors.white : AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? AppColors.primary : AppColors.muted,
        ),
      ),
    );
  }
}

class BookingDetailsPage extends StatelessWidget {
  const BookingDetailsPage({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Booking details',
    backLocation: '/customer',
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5B2EEA), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusPill('Scheduled', color: Colors.white),
              const SizedBox(height: 14),
              Text(
                customerUpcomingServiceName.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              _DetailLine(
                Icons.calendar_today_outlined,
                customerUpcomingSchedule.value,
              ),
              const SizedBox(height: 8),
              _DetailLine(
                Icons.location_on_outlined,
                customerServiceAddress.value,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionTitle('Service progress'),
        const SizedBox(height: 10),
        const Card(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Column(
              children: [
                _TrackingStep(
                  title: 'Booking confirmed',
                  subtitle: 'Your appointment is reserved',
                  completed: true,
                ),
                _TrackingStep(
                  title: 'Assigning a professional',
                  subtitle: 'We’ll share technician details shortly',
                  current: true,
                ),
                _TrackingStep(
                  title: 'Technician on the way',
                  subtitle: 'Live arrival tracking will unlock here',
                ),
                _TrackingStep(
                  title: 'Service completed',
                  subtitle: 'Review work and receive your invoice',
                  last: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Payment & safety'),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.softPrimary,
                  child: Icon(
                    Icons.payments_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text(
                  'Payment preference',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(customerPaymentMethod.value),
              ),
              const Divider(indent: 72),
              const ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(0xFFE5F7EA),
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.success,
                  ),
                ),
                title: Text(
                  'FieldOps protected',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'Verified professionals and service support included',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AppButton(
          label: 'Manage booking',
          icon: Icons.edit_calendar_outlined,
          onPressed: () => _manageBooking(context),
        ),
        const SizedBox(height: 10),
        AppButton(
          label: 'Get help',
          icon: Icons.support_agent_outlined,
          outlined: true,
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            builder: (sheet) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booking support',
                      style: Theme.of(sheet).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Reference FO-1908 · Support is available until the visit is complete.',
                    ),
                    const SizedBox(height: 14),
                    AppButton(
                      label: 'Start support chat',
                      icon: Icons.chat_bubble_outline_rounded,
                      onPressed: () {
                        Navigator.pop(sheet);
                        notice(context, 'Booking support chat started');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _manageBooking(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage booking',
                style: Theme.of(sheet).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.edit_calendar_outlined),
                title: const Text('Reschedule visit'),
                subtitle: const Text('Move to tomorrow at 2:00 PM'),
                onTap: () => Navigator.pop(sheet, 'reschedule'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.cancel_outlined,
                  color: AppColors.error,
                ),
                title: const Text('Cancel booking'),
                subtitle: const Text('Cancellation terms may apply'),
                onTap: () => Navigator.pop(sheet, 'cancel'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'reschedule') {
      customerUpcomingSchedule.value = 'Tomorrow · 02:00 PM';
      notice(context, 'Booking rescheduled to tomorrow at 2:00 PM');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: const Text('This appointment will no longer be available.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      customerHasUpcomingBooking.value = false;
      context.pop();
    }
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: Colors.white70, size: 18),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _TrackingStep extends StatelessWidget {
  const _TrackingStep({
    required this.title,
    required this.subtitle,
    this.completed = false,
    this.current = false,
    this.last = false,
  });

  final String title;
  final String subtitle;
  final bool completed;
  final bool current;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = completed || current ? AppColors.primary : AppColors.border;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: completed
                        ? AppColors.primary
                        : current
                        ? AppColors.softPrimary
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: completed
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        )
                      : current
                      ? const Center(
                          child: Icon(
                            Icons.circle,
                            color: AppColors.primary,
                            size: 8,
                          ),
                        )
                      : null,
                ),
                if (!last) Expanded(child: Container(width: 2, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 10 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: current ? AppColors.primary : AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void notice(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
