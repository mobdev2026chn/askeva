import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_getIconForTitle(title), color: color, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForTitle(String title) {
    title = title.toLowerCase();
    if (title.contains('total')) return Icons.analytics;
    if (title.contains('new')) return Icons.fiber_new;
    if (title.contains('hot')) return Icons.whatshot;
    if (title.contains('warm')) return Icons.wb_sunny_outlined;
    if (title.contains('cold')) return Icons.ac_unit;
    if (title.contains('invalid')) return Icons.error_outline;
    if (title.contains('converted')) return Icons.verified_user;
    if (title.contains('business')) return Icons.contact_mail;
    if (title.contains('website')) return Icons.language;
    if (title.contains('referral')) return Icons.people_outline;
    if (title.contains('social')) return Icons.share;
    if (title.contains('open')) return Icons.pending_actions;
    if (title.contains('closed')) return Icons.check_circle_outline;
    return Icons.show_chart;
  }
}
