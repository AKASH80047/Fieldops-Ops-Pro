import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class CustomerQuickAction {
  const CustomerQuickAction({
    required this.label,
    required this.caption,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String caption;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class CustomerQuickActions extends StatelessWidget {
  const CustomerQuickActions({super.key, required this.actions});

  final List<CustomerQuickAction> actions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final availableWidth = constraints.maxWidth / textScale;
      final columns = availableWidth >= 620
          ? 3
          : (availableWidth >= 290 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: actions.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 40 + 58 * textScale,
        ),
        itemBuilder: (context, index) =>
            _QuickActionTile(action: actions[index]),
      );
    },
  );
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final CustomerQuickAction action;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${action.label}. ${action.caption}',
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(action.icon, color: action.color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CustomerActivityEntry {
  const CustomerActivityEntry({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class CustomerActivityList extends StatelessWidget {
  const CustomerActivityList({super.key, required this.entries});

  final List<CustomerActivityEntry> entries;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          _ActivityTile(entry: entries[index]),
          if (index < entries.length - 1)
            const Divider(indent: 68, endIndent: 16),
        ],
      ],
    ),
  );
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.entry});

  final CustomerActivityEntry entry;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: entry.onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
    leading: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: entry.color.withValues(alpha: .11),
        shape: BoxShape.circle,
      ),
      child: Icon(entry.icon, color: entry.color, size: 21),
    ),
    title: Text(
      entry.title,
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
    subtitle: Text(entry.subtitle),
    trailing: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          entry.actionLabel,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        const Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: AppColors.muted,
        ),
      ],
    ),
  );
}
