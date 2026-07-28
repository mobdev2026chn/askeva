import 'package:flutter/material.dart';
import '../../widgets/stat_card.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/leads_service.dart';
import 'package:intl/intl.dart';

/// Dedicated dashboard for the Leads section.
/// Does not show the "Hi user" welcome card or WABA number/status live card.
class LeadsDashboardPage extends StatefulWidget {
  const LeadsDashboardPage({super.key});

  @override
  State<LeadsDashboardPage> createState() => _LeadsDashboardPageState();
}

class _LeadsDashboardPageState extends State<LeadsDashboardPage>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late List<Animation<double>> _animations;
  bool _isLoading = true;
  List<dynamic> _agentStats = [];
  List<dynamic> _statusStats = [];
  List<dynamic> _sourceStats = [];

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animations = List.generate(8, (index) {
      final start = (index * 0.1).clamp(0.0, 1.0);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _mainController,
        curve: Interval(start, end, curve: Curves.easeOutBack),
      );
    });

    _fetchData();
    _mainController.forward();
  }

  Future<void> _fetchData() async {
    if (_statusStats.isEmpty && _sourceStats.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final summary = await LeadsService.getLeadsSummary();
      final stats = await LeadsService.getAgentStats(days: 7);
      if (mounted) {
        setState(() {
          _statusStats = summary['statusStats'] ?? [];
          _sourceStats = summary['sourceStats'] ?? [];
          _agentStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching leads dashboard data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: Colors.white,
      child: RefreshIndicator(
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: _isLoading
              ? SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: const Center(child: CircularProgressIndicator()),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),

                    // Status Statistics Header
                    _buildSectionHeader(
                      cs,
                      'Lead Status Summary',
                      Icons.pie_chart_outline,
                    ),
                    const SizedBox(height: 16),
                    // Status Breakdown Grid
                    FadeTransition(
                      opacity: _animations[2],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                StatCard(
                                  title: 'New Lead',
                                  value:
                                      '${_getCount(_statusStats, 'New Lead')}',
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                StatCard(
                                  title: 'Hot',
                                  value: '${_getCount(_statusStats, 'Hot')}',
                                  color: Colors.deepOrange,
                                ),
                                const SizedBox(width: 8),
                                StatCard(
                                  title: 'Warm',
                                  value: '${_getCount(_statusStats, 'Warm')}',
                                  color: Colors.orange,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                StatCard(
                                  title: 'Converted',
                                  value:
                                      '${_getCount(_statusStats, 'Converted')}',
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 8),
                                StatCard(
                                  title: 'Cold',
                                  value: '${_getCount(_statusStats, 'Cold')}',
                                  color: Colors.lightBlue,
                                ),
                                const SizedBox(width: 8),
                                StatCard(
                                  title: 'Invalid',
                                  value:
                                      '${_getCount(_statusStats, 'Invalid')}',
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Source Statistics Header
                    _buildSectionHeader(
                      cs,
                      'Lead Source Summary',
                      Icons.source_outlined,
                    ),
                    const SizedBox(height: 16),
                    // Source Breakdown Grid
                    FadeTransition(
                      opacity: _animations[2],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                StatCard(
                                  title: 'Business Card',
                                  value:
                                      '${_getCount(_sourceStats, 'Business Card')}',
                                  color: Colors.indigo,
                                ),
                                const SizedBox(width: 8),
                                StatCard(
                                  title: 'Website',
                                  value:
                                      '${_getCount(_sourceStats, 'Website')}',
                                  color: Colors.teal,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                StatCard(
                                  title: 'Referral',
                                  value:
                                      '${_getCount(_sourceStats, 'Referral')}',
                                  color: Colors.deepPurple,
                                ),
                                const SizedBox(width: 8),
                                StatCard(
                                  title: 'Social Media',
                                  value:
                                      '${_getCount(_sourceStats, 'Social Media')}',
                                  color: Colors.cyan,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Pie Charts Section: Status
                    FadeTransition(
                      opacity: _animations[4],
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildPieChartCard(
                              'Status Distribution',
                              _statusStats,
                              cs,
                              [
                                Colors.blue,
                                Colors.deepOrange,
                                Colors.orange,
                                Colors.green,
                                Colors.lightBlue,
                                Colors.grey,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Pie Charts Section: Source
                    FadeTransition(
                      opacity: _animations[5],
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildPieChartCard(
                              'Source Distribution',
                              _sourceStats,
                              cs,
                              [
                                Colors.indigo,
                                Colors.teal,
                                Colors.deepPurple,
                                Colors.cyan,
                                Colors.amber,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Agent Performance Line Chart (Conditional)
                    if (_agentStats.isNotEmpty)
                      FadeTransition(
                        opacity: _animations[3],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.trending_up,
                                        color: cs.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Agent Performance (Last 7 Days)',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    height: 250,
                                    child: _buildAgentLineChart(cs),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                    // Quick Reports
                    FadeTransition(
                      opacity: _animations[6],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text(
                                'Quick Reports',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildReportItem(
                              cs,
                              'Monthly Lead Report',
                              'View performance trends',
                            ),
                            _buildReportItem(
                              cs,
                              'Agent Leaderboard',
                              'Top performers this month',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPieChartCard(
    String title,
    List<dynamic> data,
    ColorScheme cs,
    List<Color> colorPalette,
  ) {
    if (data.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(enabled: false),
                    sections: data.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final val = entry.value;
                      return PieChartSectionData(
                        color: colorPalette[idx % colorPalette.length],
                        value: (val['count'] as int).toDouble(),
                        title: '',
                        radius: 50,
                        showTitle: false,
                      );
                    }).toList(),
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: data.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final val = entry.value;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colorPalette[idx % colorPalette.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${val['name']} (${val['count']})',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentLineChart(ColorScheme cs) {
    if (_agentStats.isEmpty) {
      return const Center(
          child: Text("No data available for the last 7 days"));
    }

    Map<String, List<FlSpot>> agentData = {};
    List<String> dates = [];

    Set<String> dateSet = {};
    for (var stat in _agentStats) {
      dateSet.add(stat['date']);
    }
    dates = dateSet.toList()..sort();

    Map<String, double> dateToX = {};
    for (int i = 0; i < dates.length; i++) {
      dateToX[dates[i]] = i.toDouble();
    }

    for (var stat in _agentStats) {
      String agent = stat['agentName'];
      double x = dateToX[stat['date']] ?? 0;
      double y = (stat['count'] ?? 0).toDouble();

      if (!agentData.containsKey(agent)) {
        agentData[agent] = [];
      }
      agentData[agent]!.add(FlSpot(x, y));
    }

    List<LineChartBarData> bars = [];
    int colorIdx = 0;
    List<Color> colors = [
      cs.primary,
      cs.secondary,
      cs.tertiary,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
    ];

    agentData.forEach((agent, spots) {
      spots.sort((a, b) => a.x.compareTo(b.x));
      bars.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: colors[colorIdx % colors.length],
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: colors[colorIdx % colors.length].withOpacity(0.1),
          ),
        ),
      );
      colorIdx++;
    });

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int idx = value.toInt();
                if (idx >= 0 && idx < dates.length) {
                  DateTime dt = DateTime.parse(dates[idx]);
                  return Text(
                    DateFormat('MM/dd').format(dt),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 22,
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 28),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: bars,
        lineTouchData: LineTouchData(enabled: false),
      ),
    );
  }

  int _getCount(List<dynamic> stats, String name) {
    try {
      if (stats.isEmpty) return 0;
      final target = name.toLowerCase().trim();

      for (var s in stats) {
        if (s is Map) {
          final sName = (s['name'] ?? '').toString().toLowerCase().trim();
          if (sName == target) {
            return (s['count'] ?? 0) as int;
          }
        }
      }
      return 0;
    } catch (e) {
      debugPrint('Error getting count for $name: $e');
      return 0;
    }
  }

  Widget _buildSectionHeader(ColorScheme cs, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const Expanded(child: Divider(indent: 12)),
        ],
      ),
    );
  }

  Widget _buildReportItem(ColorScheme cs, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: cs.primary.withAlpha(30),
          child: Icon(Icons.assessment_outlined, color: cs.primary),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        trailing: Icon(Icons.chevron_right, color: cs.primary.withAlpha(150)),
        onTap: () {},
      ),
    );
  }
}
