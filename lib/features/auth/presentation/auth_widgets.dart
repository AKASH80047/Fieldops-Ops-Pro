import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: true,
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFBFAFF), AppColors.background],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -125,
              right: -95,
              child: Container(
                width: 300,
                height: 300,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0x386738E8), Color(0x008B5CF6)],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -110,
              left: -115,
              child: Container(
                width: 270,
                height: 270,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x128B5CF6),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 700;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 520 : 480),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        wide ? 20 : 22,
                        wide ? 36 : 24,
                        wide ? 20 : 22,
                        20 + MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: wide
                          ? Container(
                              padding: const EdgeInsets.all(36),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .94),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: AppColors.border),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x16432A91),
                                    blurRadius: 40,
                                    offset: Offset(0, 18),
                                  ),
                                ],
                              ),
                              child: child,
                            )
                          : child,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: compact ? 40 : 46,
        height: compact ? 40 : 46,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.hub_rounded, color: Colors.white),
      ),
      const SizedBox(width: 12),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FieldOps',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 19,
              color: AppColors.ink,
            ),
          ),
          Text(
            'PRO',
            style: TextStyle(
              letterSpacing: 2,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    ],
  );
}

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.icon,
    this.password = false,
    this.visible = false,
    this.onVisibility,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onFieldSubmitted,
  });
  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final bool password, visible;
  final VoidCallback? onVisibility;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  @override
  Widget build(BuildContext c) => TextFormField(
    controller: controller,
    obscureText: password && !visible,
    validator: validator,
    onChanged: onChanged,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    autofillHints: autofillHints,
    onFieldSubmitted: onFieldSubmitted,
    textCapitalization: TextCapitalization.none,
    autocorrect: false,
    enableSuggestions: !password,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon, color: AppColors.muted),
      suffixIcon: password
          ? IconButton(
              tooltip: visible ? 'Hide password' : 'Show password',
              onPressed: onVisibility,
              icon: Icon(
                visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.muted,
              ),
            )
          : null,
    ),
  );
}
