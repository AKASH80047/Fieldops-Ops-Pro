import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';

class ServiceCategory {
  const ServiceCategory(
    this.slug,
    this.name,
    this.description,
    this.image,
    this.services,
  );
  final String slug, name, description, image;
  final List<String> services;
}

const serviceCategories = <ServiceCategory>[
  ServiceCategory(
    'ac-hvac',
    'AC & HVAC',
    'Cooling, heating and air-quality care',
    'assets/images/categories/ac_hvac.png',
    [
      'AC Installation',
      'AC Uninstallation',
      'AC Repair',
      'AC General Service',
      'AC Deep Cleaning',
      'AC Gas Refill',
      'AC Water Leakage Repair',
      'AC PCB Repair',
      'AC Compressor Repair',
      'Duct Cleaning',
      'Heating System Repair',
      'Annual AC Maintenance',
    ],
  ),
  ServiceCategory(
    'electrical',
    'Electrical',
    'Safe installations and electrical repairs',
    'assets/images/categories/electrical.png',
    [
      'Fan Installation',
      'Fan Repair',
      'Light & LED Installation',
      'Switch & Socket Repair',
      'Wiring & Rewiring',
      'MCB & Fuse Repair',
      'Short Circuit Repair',
      'Inverter Installation',
      'Doorbell Installation',
      'Smart Switch Installation',
      'Electrical Safety Inspection',
    ],
  ),
  ServiceCategory(
    'plumbing',
    'Plumbing',
    'Leaks, fittings and water-system services',
    'assets/images/categories/plumbing.png',
    [
      'Tap Repair',
      'Pipe Leakage Repair',
      'Bathroom Fittings',
      'Toilet Installation',
      'Flush Repair',
      'Drain Cleaning',
      'Kitchen Sink Repair',
      'Water Tank Cleaning',
      'Water Pump Repair',
      'RO Installation & Repair',
      'Shower Installation',
      'Water Leakage Detection',
    ],
  ),
  ServiceCategory(
    'cooking-chef',
    'Cooking & Chef',
    'Flexible cooks and chefs for your home',
    'assets/images/categories/cooking_chef.png',
    [
      'Daily Home Cook',
      'Part-Time Cook',
      'Full-Time Cook',
      'Personal Chef',
      'North Indian Cooking',
      'South Indian Cooking',
      'Chinese Cooking',
      'Continental Cooking',
      'Vegetarian Cooking',
      'Non-Vegetarian Cooking',
      'Party & Event Chef',
      'Meal Preparation',
      'Kitchen Assistant',
    ],
  ),
  ServiceCategory(
    'cleaning',
    'Cleaning',
    'Professional cleaning for every room',
    'assets/images/categories/cleaning.png',
    [
      'Full Home Cleaning',
      'Deep Home Cleaning',
      'Bathroom Cleaning',
      'Kitchen Deep Cleaning',
      'Sofa Cleaning',
      'Carpet Cleaning',
      'Mattress Cleaning',
      'Floor Cleaning',
      'Window Cleaning',
      'Balcony Cleaning',
      'Move-In Cleaning',
      'Move-Out Cleaning',
      'Office Cleaning',
    ],
  ),
  ServiceCategory(
    'appliance-repair',
    'Appliance Repair',
    'Diagnosis and repair for home appliances',
    'assets/images/categories/appliance_repair.png',
    [
      'Washing Machine Repair',
      'Refrigerator Repair',
      'Microwave Repair',
      'Television Repair',
      'Dishwasher Repair',
      'Geyser Repair',
      'Water Purifier Repair',
      'Chimney Repair',
      'Induction Cooktop Repair',
      'Mixer Grinder Repair',
      'Air Cooler Repair',
      'Vacuum Cleaner Repair',
    ],
  ),
  ServiceCategory(
    'carpenter',
    'Carpenter',
    'Furniture, fittings and custom woodwork',
    'assets/images/categories/carpenter.png',
    [
      'Furniture Repair',
      'Door Repair',
      'Lock Installation',
      'Bed Assembly',
      'Wardrobe Installation',
      'Modular Kitchen Work',
      'Shelf Installation',
      'Curtain Rod Installation',
      'Furniture Polishing',
      'Drawer Repair',
      'Custom Furniture Work',
    ],
  ),
  ServiceCategory(
    'pest-control',
    'Pest Control',
    'Safe treatment with clear precautions',
    'assets/images/categories/pest_control.png',
    [
      'Cockroach Control',
      'Termite Treatment',
      'Mosquito Control',
      'Bed Bug Treatment',
      'Rodent Control',
      'Ant Control',
      'Lizard Control',
      'General Pest Control',
      'Pre-Construction Termite Treatment',
      'Post-Construction Termite Treatment',
    ],
  ),
  ServiceCategory(
    'painting',
    'Painting',
    'Painting, waterproofing and renovation',
    'assets/images/categories/painting.png',
    [
      'Interior Painting',
      'Exterior Painting',
      'Wall Putty',
      'Texture Painting',
      'Waterproofing',
      'Wall Crack Repair',
      'Ceiling Painting',
      'Wallpaper Installation',
      'Tile Installation',
      'Bathroom Renovation',
      'Kitchen Renovation',
      'Complete Home Renovation',
    ],
  ),
  ServiceCategory(
    'home-maintenance',
    'Home Maintenance',
    'Repairs, inspection and preventive care',
    'assets/images/categories/home_maintenance.png',
    [
      'General Home Inspection',
      'Door & Window Repair',
      'Minor Home Repairs',
      'Fixture Installation',
      'Wall Mounting',
      'Curtain Installation',
      'Furniture Assembly',
      'Regular Home Maintenance',
      'Preventive Maintenance',
      'Annual Maintenance Contract',
      'Property Maintenance',
    ],
  ),
  ServiceCategory(
    'smart-home',
    'Smart Home',
    'Connected security and automation setup',
    'assets/images/categories/smart_home.png',
    [
      'CCTV Installation',
      'Video Doorbell',
      'Smart Lock Installation',
      'Smart Switch Installation',
      'Home Automation',
      'Smart Lighting',
      'Wi-Fi Setup',
      'Smart Thermostat',
      'Security Alarm Installation',
      'Smart Device Configuration',
    ],
  ),
  ServiceCategory(
    'laundry',
    'Laundry',
    'Pickup, garment care and delivery',
    'assets/images/categories/laundry.png',
    [
      'Clothes Washing',
      'Wash & Fold',
      'Wash & Iron',
      'Ironing Only',
      'Dry Cleaning',
      'Express Laundry',
      'Blanket Cleaning',
      'Curtain Cleaning',
      'Bedsheet Cleaning',
      'Shoe Cleaning',
      'Premium Garment Care',
      'Laundry Pickup & Delivery',
    ],
  ),
  ServiceCategory(
    'more-services',
    'More Services',
    'Additional services available in your area',
    'assets/images/categories/more_services.png',
    [
      'Gardening & Plant Care',
      'Lawn Maintenance',
      'Packers & Movers',
      'Furniture Shifting',
      'Car Wash at Home',
      'Bike Maintenance',
      'Home Salon',
      'Beauty Services',
      'Pet Grooming',
      'Pet Walking',
      'Elderly Assistance',
      'Solar Panel Installation',
      'Water Purifier Maintenance',
      'Home Security Services',
    ],
  ),
];

class AllCategoriesPage extends StatefulWidget {
  const AllCategoriesPage({super.key});
  @override
  State<AllCategoriesPage> createState() => _AllCategoriesPageState();
}

class _AllCategoriesPageState extends State<AllCategoriesPage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final visible = serviceCategories
        .where((x) => x.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return AppShell(
      title: 'All Services',
      backLocation: '/customer',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(
                hintText: 'Search categories',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(child: Text('No matching services found.'))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: .84,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                        ),
                    itemCount: visible.length,
                    itemBuilder: (_, i) =>
                        CategoryCard(category: visible[i], large: true),
                  ),
          ),
        ],
      ),
    );
  }
}

class CategoryDetailsPage extends StatelessWidget {
  const CategoryDetailsPage({super.key, required this.slug});
  final String slug;
  @override
  Widget build(BuildContext context) {
    final category = serviceCategories.firstWhere(
      (x) => x.slug == slug,
      orElse: () => serviceCategories.last,
    );
    return AppShell(
      title: category.name,
      backLocation: '/customer/categories',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              category.image,
              height: 210,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            category.description,
            style: const TextStyle(color: AppColors.muted),
          ),
          if (category.slug == 'pest-control')
            const Card(
              child: ListTile(
                leading: Icon(
                  Icons.health_and_safety_outlined,
                  color: AppColors.warning,
                ),
                title: Text('Safety first'),
                subtitle: Text(
                  'Treatment precautions are shown before confirmation.',
                ),
              ),
            ),
          if (category.slug == 'laundry')
            const Card(
              child: ListTile(
                leading: Icon(
                  Icons.local_shipping_outlined,
                  color: AppColors.primary,
                ),
                title: Text('Pickup & delivery'),
                subtitle: Text(
                  'Pickup and delivery charges are shown separately.',
                ),
              ),
            ),
          const SizedBox(height: 14),
          const SectionTitle('Available services'),
          ...category.services.map(
            (service) => Card(
              child: ListTile(
                onTap: () => context.push('/customer/booking', extra: service),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEDE7FF),
                  child: Icon(Icons.check, color: AppColors.primary),
                ),
                title: Text(
                  service,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'View availability and transparent pricing',
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  const CategoryCard({super.key, required this.category, this.large = false});
  final ServiceCategory category;
  final bool large;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.push('/customer/categories/${category.slug}'),
    borderRadius: BorderRadius.circular(18),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D17152A),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: Image.asset(
                category.image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(
                    Icons.home_repair_service,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(large ? 12 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  maxLines: large ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: large ? 14 : 12,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
                if (large)
                  Text(
                    '${category.services.length} services',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
