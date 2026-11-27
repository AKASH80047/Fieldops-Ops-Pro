import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

bool isCompactWorkspace(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
  return width / textScale < 350;
}

class WorkspaceDestination {
  const WorkspaceDestination(
    this.label,
    this.icon,
    this.selectedIcon, {
    this.compactLabel,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String? compactLabel;
}

class WorkspaceNavigationBar extends StatelessWidget {
  const WorkspaceNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<WorkspaceDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compact = isCompactWorkspace(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 1),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            if (index == selectedIndex) return;
            HapticFeedback.selectionClick();
            onSelected(index);
          },
          height: 74,
          animationDuration: const Duration(milliseconds: 220),
          indicatorColor: colors.primaryContainer,
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          overlayColor: WidgetStatePropertyAll(
            colors.primary.withValues(alpha: .09),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? colors.primary : AppColors.muted,
            );
          }),
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: compact
                    ? destination.compactLabel ?? destination.label
                    : destination.label,
                tooltip: destination.label,
              ),
          ],
        ),
      ),
    );
  }
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: null,
          child: const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }
    final button = switch ((outlined, icon)) {
      (true, final IconData value) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(value),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary),
        ),
      ),
      (true, null) => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary),
        ),
        child: Text(label),
      ),
      (false, final IconData value) => FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(value),
        label: Text(label),
      ),
      (false, null) => FilledButton(onPressed: onPressed, child: Text(label)),
    };
    return SizedBox(width: double.infinity, height: 52, child: button);
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      ?action,
    ],
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.color = AppColors.primary});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.bottom,
    this.backLocation,
    this.onBack,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? bottom;
  final String? backLocation;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    final showBack = onBack != null || context.canPop() || backLocation != null;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: showBack
            ? IconButton(
                tooltip: 'Back',
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.ink,
                ),
                onPressed:
                    onBack ??
                    () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(backLocation!);
                      }
                    },
              )
            : null,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: actions,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(child: child),
      bottomNavigationBar: bottom,
    );
  }
}
