import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../app/dependency_injection.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../domain/user_role.dart';
import 'auth_bloc.dart';
import 'auth_session.dart';
import 'auth_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(
    text: ApiConfig.useMocks ? 'alex@fieldops.io' : '',
  );
  final _password = TextEditingController(
    text: ApiConfig.useMocks ? 'password' : '',
  );
  late final AuthBloc _authBloc;
  UserRole _role = UserRole.customer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc(sl());
  }

  @override
  void dispose() {
    _authBloc.close();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _authBloc,
    child: BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          authSession.signIn(state.role);
        }
        if (state is AuthFailure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) => AuthScaffold(
        child: AutofillGroup(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AuthBrand(),
                const SizedBox(height: 30),
                Text(
                  'Welcome back',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(fontSize: 32),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    _roleSubtitle,
                    key: ValueKey(_role),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 15),
                  ),
                ),
                const SizedBox(height: 24),
                AuthField(
                  label: _role == UserRole.customer
                      ? 'Email address'
                      : 'Work email',
                  controller: _email,
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  validator: (value) => value?.contains('@') == true
                      ? null
                      : 'Enter a valid email address',
                ),
                const SizedBox(height: 12),
                AuthField(
                  label: 'Password',
                  controller: _password,
                  icon: Icons.lock_outline_rounded,
                  password: true,
                  visible: _visible,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                  onVisibility: () => setState(() => _visible = !_visible),
                  validator: (value) => (value?.length ?? 0) >= 6
                      ? null
                      : 'Use at least 6 characters',
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 17,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 6),
                        Text(
                          ApiConfig.useMocks
                              ? 'Demo workspace'
                              : 'Secure sign-in',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: const Text('Forgot password?'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Continue as',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 9),
                Semantics(
                  label: 'Workspace selection',
                  child: Row(
                    children: [
                      for (var i = 0; i < UserRole.values.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _WorkspaceOption(
                            role: UserRole.values[i],
                            selected: _role == UserRole.values[i],
                            onTap: () =>
                                setState(() => _role = UserRole.values[i]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _role.workspaceDescription,
                    key: ValueKey(_role),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Sign in',
                  icon: Icons.arrow_forward_rounded,
                  loading: state is AuthLoading,
                  onPressed: state is AuthLoading ? null : _submit,
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => context.push('/signup'),
                    child: const Text('New here? Create an account'),
                  ),
                ),
                const SizedBox(height: 2),
                const Center(
                  child: Text(
                    'By continuing, you agree to our Terms of Service and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  String get _roleSubtitle => switch (_role) {
    UserRole.customer => 'Book and manage trusted home services.',
    UserRole.technician => 'Manage jobs, schedules and earnings.',
    UserRole.manager => 'Monitor customers, teams and operations.',
  };

  void _submit() {
    if (_form.currentState!.validate()) {
      // The BLoC is introduced inside this State's build method, so use the
      // form context below that provider instead of the State's parent context.
      _form.currentContext!.read<AuthBloc>().add(
        SignInRequested(_email.text, _password.text, _role),
      );
    }
  }
}

class _WorkspaceOption extends StatelessWidget {
  const _WorkspaceOption({
    required this.role,
    required this.selected,
    required this.onTap,
  });
  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    inMutuallyExclusiveGroup: true,
    label: '${role.label}: ${role.workspaceDescription}',
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.softPrimary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  role == UserRole.customer
                      ? Icons.home_outlined
                      : role == UserRole.technician
                      ? Icons.engineering_outlined
                      : Icons.admin_panel_settings_outlined,
                  size: 24,
                  color: selected ? AppColors.primary : AppColors.muted,
                ),
                if (selected)
                  const Positioned(
                    right: -8,
                    top: -5,
                    child: Icon(
                      Icons.check_circle,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              role.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: selected ? AppColors.primary : AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
