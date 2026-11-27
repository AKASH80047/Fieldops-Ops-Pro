import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/dependency_injection.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/technician_repository.dart';
import '../domain/technician_job.dart';
import 'technician_blocs.dart';

const technicianCategories = <(String, IconData)>[
  ('Electrician', Icons.electrical_services_outlined),
  ('Plumber', Icons.plumbing_outlined),
  ('Home Cook', Icons.restaurant_outlined),
  ('Home Cleaner', Icons.cleaning_services_outlined),
  ('AC Technician', Icons.ac_unit_outlined),
  ('Appliance Repair', Icons.home_repair_service_outlined),
  ('Carpenter', Icons.carpenter_outlined),
  ('Painter', Icons.format_paint_outlined),
];

class NearbyOpportunities extends StatefulWidget {
  const NearbyOpportunities({super.key});

  @override
  State<NearbyOpportunities> createState() => _NearbyOpportunitiesState();
}

class _NearbyOpportunitiesState extends State<NearbyOpportunities> {
  late Future<List<TechnicianOpportunity>> _future;
  bool _locating = false;
  String? _claimingId;

  @override
  void initState() {
    super.initState();
    _future = _loadWithLocation();
  }

  Future<List<TechnicianOpportunity>> _loadWithLocation() async {
    if (!ApiConfig.useMocks) {
      try {
        if (mounted) setState(() => _locating = true);
        if (!await Geolocator.isLocationServiceEnabled()) {
          return sl<TechnicianRepository>().opportunities();
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition();
          return sl<TechnicianRepository>().opportunities(
            latitude: position.latitude,
            longitude: position.longitude,
          );
        }
      } catch (_) {
        // Server-side postal-code matching remains the privacy-safe fallback.
      } finally {
        if (mounted) setState(() => _locating = false);
      }
    }
    return sl<TechnicianRepository>().opportunities();
  }

  void _reload() => setState(() => _future = _loadWithLocation());

  Future<void> _claim(TechnicianOpportunity opportunity) async {
    setState(() => _claimingId = opportunity.id);
    try {
      await sl<TechnicianRepository>().claimOpportunity(opportunity.id);
      if (!mounted) return;
      context.read<TechnicianJobsBloc>().add(TechnicianJobsLoaded());
      _showMessage('Job accepted. Customer details are now available in Jobs.');
      _reload();
    } catch (error) {
      if (mounted) _showMessage('$error');
    } finally {
      if (mounted) setState(() => _claimingId = null);
    }
  }

  void _showMessage(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionTitle(
        'Jobs near you',
        action: IconButton(
          tooltip: 'Refresh nearby jobs',
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
        ),
      ),
      Text(
        _locating
            ? 'Checking your current location…'
            : 'Matched securely by verified skill and service area.',
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
      const SizedBox(height: 8),
      FutureBuilder<List<TechnicianOpportunity>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          if (snapshot.hasError) {
            return Card(
              child: ListTile(
                leading: const Icon(
                  Icons.lock_outline,
                  color: AppColors.warning,
                ),
                title: const Text('Nearby jobs unavailable'),
                subtitle: const Text(
                  'Complete eKYC, get approved and go online to view eligible requests.',
                ),
                trailing: TextButton(
                  onPressed: _reload,
                  child: const Text('Retry'),
                ),
              ),
            );
          }
          final opportunities = snapshot.data ?? const [];
          if (opportunities.isEmpty) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'No matching customer requests right now. We’ll notify you when work becomes available in your area.',
                ),
              ),
            );
          }
          return Column(children: opportunities.map(_opportunityCard).toList());
        },
      ),
    ],
  );

  Widget _opportunityCard(TechnicianOpportunity item) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEDE7FF),
                child: Icon(
                  _categoryIcon(item.category),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.service,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      item.category,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${item.estimatedPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${item.locality}${item.distanceKm == null ? '' : ' · ${item.distanceKm!.toStringAsFixed(1)} km'}',
          ),
          Text(
            item.scheduledAt,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _claimingId == null ? () => _claim(item) : null,
              icon: const Icon(Icons.task_alt),
              label: Text(_claimingId == item.id ? 'Accepting…' : 'Accept job'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Customer name and full address stay private until assignment.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
        ],
      ),
    ),
  );

  IconData _categoryIcon(String value) {
    final category = value.toLowerCase();
    if (category.contains('cook')) return Icons.restaurant_outlined;
    if (category.contains('electric')) {
      return Icons.electrical_services_outlined;
    }
    if (category.contains('plumb')) return Icons.plumbing_outlined;
    if (category.contains('clean')) return Icons.cleaning_services_outlined;
    if (category.contains('ac')) return Icons.ac_unit_outlined;
    return Icons.handyman_outlined;
  }
}
