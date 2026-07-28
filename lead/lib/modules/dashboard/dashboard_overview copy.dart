import 'package:flutter/material.dart';
import '../../widgets/stat_card.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardOverview extends StatelessWidget {
  final String? email;
  final String? name; // Added name parameter
  const DashboardOverview({super.key, this.email, this.name});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Mock data for counts
    const int totalLeads = 12;
    const int openLeads = 8;
    const int closedLeads = 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 800),
          child: Text(
            ' LMS',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: cs.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        CircleAvatar(
          radius: 36,
          backgroundColor: const Color(
            0xFF6EB82C,
          ).withAlpha(51), // 20% opacity of accent green
          child: Text(
            (name ?? email ?? 'U')[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Welcome,',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          name ?? email ?? 'User',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 18),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(seconds: 1),
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StatCard(
                title: 'Total Leads',
                value: '$totalLeads',
                color: cs.primary,
              ),
              const SizedBox(width: 8),
              StatCard(title: 'Open', value: '$openLeads', color: cs.secondary),
              const SizedBox(width: 8),
              StatCard(
                title: 'Closed',
                value: '$closedLeads',
                color: cs.tertiary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Lead Distribution',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(
                  color: cs.secondary,
                  value: openLeads.toDouble(),
                  title: 'Open\n$openLeads',
                  radius: 60,
                  titleStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  color: cs.tertiary,
                  value: closedLeads.toDouble(),
                  title: 'Closed\n$closedLeads',
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Reports',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              ListTile(
                leading: Icon(Icons.description, color: cs.primary),
                title: const Text('Monthly Lead Report'),
                subtitle: const Text('Generated on Jan 1, 2026'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {},
              ),
              ListTile(
                leading: Icon(Icons.description, color: cs.primary),
                title: const Text('Agent Performance'),
                subtitle: const Text('Top agent: Math'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}
