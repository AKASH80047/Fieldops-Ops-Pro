import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../domain/user_role.dart';
import 'auth_widgets.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final key = GlobalKey<FormState>();
  final fields = List.generate(13, (_) => TextEditingController());
  bool terms = false;
  UserRole? role;
  final additionalSkills = <String>{};
  @override
  void dispose() {
    for (final controller in fields) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => AuthScaffold(
    child: Form(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => c.pop(),
                icon: const Icon(Icons.arrow_back),
              ),
              const AuthBrand(compact: true),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            role == UserRole.technician
                ? 'Join as a Service Professional'
                : 'Create customer account',
            style: Theme.of(c).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            role == UserRole.technician
                ? 'Your profile is reviewed before you can accept jobs.'
                : 'Book trusted home services in a few simple steps.',
          ),
          const SizedBox(height: 24),
          if (role == null) ...[
            _RegistrationRoleCard(
              title: 'Customer',
              description: 'Book trusted home services.',
              icon: Icons.home_outlined,
              onTap: () => setState(() => role = UserRole.customer),
            ),
            const SizedBox(height: 12),
            _RegistrationRoleCard(
              title: 'Technician / Service Professional',
              description: 'Manage jobs and grow your earnings.',
              icon: Icons.engineering_outlined,
              onTap: () => setState(() => role = UserRole.technician),
            ),
            const SizedBox(height: 18),
            const Text(
              'Admin accounts are provisioned by your organization. Use the Admin workspace on the sign-in screen.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ] else ...[
            ..._fieldsForRole(),
            if (role == UserRole.technician) ...[
              const SizedBox(height: 4),
              const Text(
                'Professional skills',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select one primary skill and any additional skills.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Primary skill',
                  prefixIcon: Icon(Icons.handyman_outlined),
                ),
                items: _skills
                    .map(
                      (skill) =>
                          DropdownMenuItem(value: skill, child: Text(skill)),
                    )
                    .toList(),
                validator: (value) =>
                    value == null ? 'Choose your primary skill' : null,
                onChanged: (_) {},
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _skills
                    .map(
                      (skill) => FilterChip(
                        label: Text(skill),
                        selected: additionalSkills.contains(skill),
                        onSelected: (selected) => setState(
                          () => selected
                              ? additionalSkills.add(skill)
                              : additionalSkills.remove(skill),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Identity and skill documents are requested securely after initial registration when required.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ],
          CheckboxListTile(
            enabled: role != null,
            contentPadding: EdgeInsets.zero,
            value: terms,
            onChanged: (v) => setState(() => terms = v ?? false),
            title: const Text('I agree to the Terms and Privacy Policy'),
          ),
          if (role != null)
            AppButton(
              label: role == UserRole.technician
                  ? 'Submit for review'
                  : 'Create customer account',
              onPressed: terms
                  ? () {
                      if (key.currentState!.validate()) {
                        ScaffoldMessenger.of(c).showSnackBar(
                          SnackBar(
                            content: Text(
                              role == UserRole.technician
                                  ? 'Professional registration requires the pending verification endpoint.'
                                  : 'Customer registration requires the pending backend endpoint.',
                            ),
                          ),
                        );
                      }
                    }
                  : null,
            ),
          Center(
            child: TextButton(
              onPressed: () => c.pop(),
              child: const Text('Already have an account? Sign in'),
            ),
          ),
        ],
      ),
    ),
  );

  List<Widget> _fieldsForRole() {
    final technician = role == UserRole.technician;
    final labels = <String>[
      'Full name',
      'Email',
      'Mobile number',
      'Password',
      'Confirm password',
      if (technician) ...[
        'Address',
        'City',
        'State',
        'Postal code',
        'Experience (years)',
        'Qualification / certification',
        'Work description',
        'Service areas',
      ],
    ];
    return labels.asMap().entries.map((entry) {
      final password = entry.key == 3 || entry.key == 4;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AuthField(
          label: entry.value,
          controller: fields[entry.key],
          icon: password
              ? Icons.lock_outline
              : entry.key == 1
              ? Icons.mail_outline
              : entry.key == 2
              ? Icons.phone_outlined
              : Icons.person_outline,
          password: password,
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'This field is required';
            }
            if (entry.key == 4 && value != fields[3].text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      );
    }).toList();
  }
}

const _skills = <String>[
  'AC Technician',
  'Electrician',
  'Plumber',
  'Home Cook',
  'Home Cleaner',
  'Refrigerator Technician',
  'Carpenter',
  'Pest Control Professional',
  'Painter',
  'Laundry Professional',
  'Scrap Collector / Kabadi',
  'Excavation Operator',
  'Gardening Professional',
  'Solar Technician',
];

class _RegistrationRoleCard extends StatelessWidget {
  const _RegistrationRoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });
  final String title, description;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFEAE8F2)),
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        ],
      ),
    ),
  );
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final email = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => AuthScaffold(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => c.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(height: 20),
        const Icon(
          Icons.mark_email_read_outlined,
          size: 56,
          color: AppColors.primary,
        ),
        const SizedBox(height: 22),
        Text(
          'Reset your password',
          style: Theme.of(c).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text('Enter your work email and we’ll send reset instructions.'),
        const SizedBox(height: 26),
        AuthField(
          label: 'Work email',
          controller: email,
          icon: Icons.mail_outline,
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Send reset link',
          onPressed: () {
            if (!RegExp(
              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
            ).hasMatch(email.text.trim())) {
              ScaffoldMessenger.of(c).showSnackBar(
                const SnackBar(content: Text('Enter a valid work email.')),
              );
              return;
            }
            c.push('/otp');
          },
        ),
      ],
    ),
  );
}

class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  String code = '';

  @override
  Widget build(BuildContext c) => AuthScaffold(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => c.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(height: 20),
        Text('Verify your email', style: Theme.of(c).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Enter the six-digit code sent to your inbox.'),
        const SizedBox(height: 28),
        TextField(
          maxLength: 6,
          onChanged: (value) => code = value,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Verification code',
            counterText: '',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            letterSpacing: 10,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        AppButton(
          label: 'Verify code',
          onPressed: () {
            if (!RegExp(r'^\d{6}$').hasMatch(code)) {
              ScaffoldMessenger.of(c).showSnackBar(
                const SnackBar(content: Text('Enter a six-digit code.')),
              );
              return;
            }
            c.push('/reset-password');
          },
        ),
        Center(
          child: TextButton(
            onPressed: () => ScaffoldMessenger.of(c).showSnackBar(
              const SnackBar(
                content: Text('Resend requires the pending backend endpoint.'),
              ),
            ),
            child: const Text('Resend code in 00:30'),
          ),
        ),
      ],
    ),
  );
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});
  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final one = TextEditingController(), two = TextEditingController();
  @override
  void dispose() {
    one.dispose();
    two.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => AuthScaffold(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => c.go('/login'),
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(height: 18),
        Text(
          'Create a new password',
          style: Theme.of(c).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text('Use 8+ characters with a mix of letters and numbers.'),
        const SizedBox(height: 24),
        AuthField(
          label: 'New password',
          controller: one,
          password: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        AuthField(
          label: 'Confirm new password',
          controller: two,
          password: true,
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: (one.text.length / 12).clamp(0, 1),
          backgroundColor: const Color(0xFFEAE8F2),
          color: AppColors.success,
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Update password',
          onPressed: () => ScaffoldMessenger.of(c).showSnackBar(
            const SnackBar(
              content: Text(
                'Password update requires the pending backend endpoint.',
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
