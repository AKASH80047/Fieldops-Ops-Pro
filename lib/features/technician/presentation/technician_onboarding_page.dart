import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/dependency_injection.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/technician_repository.dart';
import '../domain/technician_job.dart';

class TechnicianOnboardingPage extends StatefulWidget {
  const TechnicianOnboardingPage({super.key, required this.initialSkill});

  final String initialSkill;

  @override
  State<TechnicianOnboardingPage> createState() =>
      _TechnicianOnboardingPageState();
}

class _TechnicianOnboardingPageState extends State<TechnicianOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _aadhaar = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postalCode = TextEditingController();
  final _picker = ImagePicker();

  late String _skill;
  XFile? _selfie;
  Uint8List? _selfieBytes;
  XFile? _identityDocument;
  Uint8List? _identityBytes;
  XFile? _addressDocument;
  Uint8List? _addressBytes;
  Position? _position;
  bool _locationConsent = true;
  bool _kycConsent = false;
  bool _locating = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _skill = widget.initialSkill;
    _useCurrentLocation();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _aadhaar,
      _address,
      _city,
      _state,
      _postalCode,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (!_locationConsent || _locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Turn on location services to find nearby work.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location permission is required for nearby jobs.');
      }
      final position = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _position = position);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _captureSelfie() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1440,
      preferredCameraDevice: CameraDevice.front,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selfie = photo;
      _selfieBytes = bytes;
      _error = null;
    });
  }

  Future<void> _captureDocument({required bool identity}) async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
      maxWidth: 1800,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    setState(() {
      if (identity) {
        _identityDocument = photo;
        _identityBytes = bytes;
      } else {
        _addressDocument = photo;
        _addressBytes = bytes;
      }
      _error = null;
    });
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selfie == null || _selfieBytes == null) {
      setState(() => _error = 'A live selfie is required for eKYC.');
      return;
    }
    if (_identityDocument == null || _identityBytes == null) {
      setState(() => _error = 'Capture your Aadhaar identity document.');
      return;
    }
    if (_addressDocument == null || _addressBytes == null) {
      setState(() => _error = 'Capture a valid address proof.');
      return;
    }
    if (!_kycConsent) {
      setState(() => _error = 'Please accept the eKYC consent.');
      return;
    }
    if (!_locationConsent) {
      setState(() => _error = 'Location consent is required for nearby jobs.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await sl<TechnicianRepository>().submitApplication(
        TechnicianApplicationInput(
          name: _name.text.trim(),
          phone: _phone.text.replaceAll(RegExp(r'\s'), ''),
          aadhaarNumber: _aadhaar.text.replaceAll(RegExp(r'\D'), ''),
          addressLine1: _address.text.trim(),
          city: _city.text.trim(),
          state: _state.text.trim(),
          postalCode: _postalCode.text.trim(),
          skills: [_skill],
          locationConsent: _locationConsent,
          kycConsent: _kycConsent,
          latitude: _position?.latitude,
          longitude: _position?.longitude,
        ),
        selfieBytes: _selfieBytes!,
        selfieFileName: _selfie!.name,
        identityBytes: _identityBytes!,
        identityFileName: _identityDocument!.name,
        addressProofBytes: _addressBytes!,
        addressProofFileName: _addressDocument!.name,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          icon: const Icon(
            Icons.verified_user_outlined,
            color: AppColors.primary,
          ),
          title: const Text('Verification submitted'),
          content: const Text(
            'Your eKYC is under review. You will receive a notification after approval; jobs can only be accepted after that.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) context.go('/tech');
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Professional eKYC',
    backLocation: '/tech',
    child: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1ECFF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Icon(Icons.security_outlined, color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your Aadhaar number is never stored in plain text. Only a protected verification reference and last four digits are retained.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Work category'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _skill,
            decoration: const InputDecoration(
              labelText: 'Primary service',
              prefixIcon: Icon(Icons.handyman_outlined),
            ),
            items: _workCategories
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => setState(() => _skill = value ?? _skill),
          ),
          const SizedBox(height: 18),
          const SectionTitle('Personal details'),
          const SizedBox(height: 8),
          _field(_name, 'Full name as per Aadhaar', Icons.person_outline),
          _field(
            _phone,
            'Mobile number',
            Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (value) => RegExp(r'^\+?[0-9 ]{10,15}$').hasMatch(value)
                ? null
                : 'Enter a valid mobile number',
          ),
          _field(
            _aadhaar,
            '12-digit Aadhaar number',
            Icons.badge_outlined,
            keyboardType: TextInputType.number,
            obscureText: true,
            validator: (value) =>
                RegExp(
                  r'^\d{12}$',
                ).hasMatch(value.replaceAll(RegExp(r'\D'), ''))
                ? null
                : 'Enter all 12 Aadhaar digits',
          ),
          const SizedBox(height: 8),
          const SectionTitle('Residential address'),
          const SizedBox(height: 8),
          _field(_address, 'House / street address', Icons.home_outlined),
          _field(_city, 'City', Icons.location_city_outlined),
          _field(_state, 'State', Icons.map_outlined),
          _field(
            _postalCode,
            '6-digit PIN code',
            Icons.pin_drop_outlined,
            keyboardType: TextInputType.number,
            validator: (value) => RegExp(r'^\d{6}$').hasMatch(value)
                ? null
                : 'Enter a valid 6-digit PIN code',
          ),
          const SizedBox(height: 8),
          const SectionTitle('Live verification'),
          const SizedBox(height: 8),
          _documentTile(
            title: 'Aadhaar identity document',
            subtitle:
                'Capture a clear photo; it is stored in protected storage.',
            captured: _identityDocument != null,
            onTap: () => _captureDocument(identity: true),
          ),
          const SizedBox(height: 8),
          _documentTile(
            title: 'Address proof',
            subtitle: 'Capture a utility bill or accepted address document.',
            captured: _addressDocument != null,
            onTap: () => _captureDocument(identity: false),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _captureSelfie,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 190,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F7FC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E1EF)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _selfieBytes == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 42,
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Take live selfie',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Front camera only · no gallery upload',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(_selfieBytes!, fit: BoxFit.cover),
                        const Align(
                          alignment: Alignment.bottomCenter,
                          child: ColoredBox(
                            color: Color(0x99000000),
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                'Tap to retake',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _locationConsent,
            onChanged: (value) {
              setState(() => _locationConsent = value);
              if (value) _useCurrentLocation();
            },
            title: const Text('Use my location for nearby jobs'),
            subtitle: Text(
              _locating
                  ? 'Getting current location…'
                  : _position == null
                  ? 'Location is used only for service-area matching.'
                  : 'Current location captured securely.',
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _kycConsent,
            onChanged: (value) => setState(() => _kycConsent = value ?? false),
            title: const Text('I consent to identity and selfie verification'),
            subtitle: const Text(
              'Approval is completed after secure verification and admin review.',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 14),
          AppButton(
            label: _submitting ? 'Submitting securely…' : 'Submit eKYC',
            icon: Icons.verified_user_outlined,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String value)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return 'This field is required';
        return validator?.call(text);
      },
    ),
  );

  Widget _documentTile({
    required String title,
    required String subtitle,
    required bool captured,
    required VoidCallback onTap,
  }) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: captured
            ? AppColors.success.withValues(alpha: .12)
            : const Color(0xFFEDE7FF),
        child: Icon(
          captured ? Icons.check : Icons.document_scanner_outlined,
          color: captured ? AppColors.success : AppColors.primary,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(captured ? 'Captured securely · tap to retake' : subtitle),
      trailing: const Icon(Icons.camera_alt_outlined),
    ),
  );
}

const _workCategories = <String>[
  'Electrician',
  'Plumber',
  'Home Cook',
  'Home Cleaner',
  'AC Technician',
  'Appliance Repair',
  'Carpenter',
  'Painter',
  'Pest Control',
  'Gardener',
];
