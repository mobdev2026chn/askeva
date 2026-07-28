import 'package:flutter/material.dart';
import '../../widgets/stat_card.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/leads_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardOverview extends StatefulWidget {
  final String? email;
  final String? name;
  const DashboardOverview({super.key, this.email, this.name});

  @override
  State<DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<DashboardOverview>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late List<Animation<double>> _animations;
  bool _isLoading = true;
  int _totalLeads = 0;
  List<dynamic> _agentStats = [];
  List<dynamic> _statusStats = [];
  List<dynamic> _sourceStats = [];
  Map<String, dynamic>? _wabaInfo;

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
    _loadWabaInfo();
    _mainController.forward();
  }

  Future<void> _loadWabaInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_data');
    Map<String, dynamic> wabaData = {
      'wabaNumber': '917200440497',
      'status': 'Live',
      'quality': 'GREEN',
      'tier': 'tier_3',
    };

    if (userJson != null) {
      final user = jsonDecode(userJson);
      wabaData = {
        'wabaNumber':
            user['wabaNumber'] ??
            user['businessWhatsappNumber'] ??
            '917200440497',
        'status': user['connectionStatus'] ?? 'Live',
        'quality': user['qualityRating'] ?? 'GREEN',
        'tier': user['tier'] ?? 'tier_3',
      };
    }

    setState(() {
      _wabaInfo = wabaData;
    });
  }

  Future<void> _fetchData() async {
    // Only show full loader if we have no data yet
    if (_totalLeads == 0) {
      setState(() => _isLoading = true);
    }

    try {
      final summary = await LeadsService.getLeadsSummary();
      final stats = await LeadsService.getAgentStats(days: 7);
      if (mounted) {
        setState(() {
          _totalLeads = summary['total'] ?? 0;
          _statusStats = summary['statusStats'] ?? [];
          _sourceStats = summary['sourceStats'] ?? [];
          _agentStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
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
      color: cs.surface,
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
                    // Layered Header Section
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Welcome Card Section
                          FadeTransition(
                            opacity: _animations[1],
                            child: SlideTransition(
                              position: _animations[1].drive(
                                Tween<Offset>(
                                  begin: const Offset(0, 0.2),
                                  end: Offset.zero,
                                ),
                              ),
                              child: Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(
                                  top: 60,
                                  left: 12,
                                  right: 12,
                                ),
                                padding: const EdgeInsets.only(
                                  top: 48,
                                  bottom: 24,
                                  left: 24,
                                  right: 24,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: TypingText(
                                        text: 'LMS',
                                        style: TextStyle(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 24,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  'Hi ${widget.name ?? "User"} ',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const Text(
                                                '👋',
                                                style: TextStyle(fontSize: 18),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Manage Your Leads!',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
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
                          // Header GIF Section
                          Positioned(
                            top: 0,
                            left: 20,
                            right: 20,
                            child: FadeTransition(
                              opacity: _animations[0],
                              child: ScaleTransition(
                                scale: _animations[0],
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    height: 100,
                                    child: Image.network(
                                      'https://askeva.in/images/contact/headers.gif',
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // WABA Details Card
                    if (_wabaInfo != null)
                      FadeTransition(
                        opacity: _animations[2],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  _buildWabaItem(
                                    Icons.verified_outlined,
                                    'WABA Number: ${_wabaInfo!['wabaNumber'] ?? 'N/A'}',
                                    Colors.green,
                                  ),
                                  const SizedBox(width: 24),
                                  _buildWabaItem(
                                    Icons.power_settings_new,
                                    'Status: ${_wabaInfo!['status'] ?? 'N/A'}',
                                    Colors.green,
                                  ),
                                  const SizedBox(width: 24),
                                  _buildWabaItem(
                                    Icons.flag_outlined,
                                    'Quality: ${_wabaInfo!['quality'] ?? 'N/A'}',
                                    Colors.green,
                                    isQuality: true,
                                  ),
                                  const SizedBox(width: 24),
                                  _buildWabaItem(
                                    Icons.chat_bubble_outline,
                                    '${_wabaInfo!['tier'] ?? 'tier_3'}: MSG_ 100000 LIMIT',
                                    Colors.green,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

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
                    // Recent Reports
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
                        title: '', // Hide title inside chart
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
              // Legend
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      return const Center(child: Text("No data available for the last 7 days"));
    }

    // Group stats by agent
    Map<String, List<FlSpot>> agentData = {};
    List<String> dates = [];

    // Get unique dates in order
    Set<String> dateSet = {};
    for (var stat in _agentStats) {
      dateSet.add(stat['date']);
    }
    dates = dateSet.toList()..sort();

    // Map date to X coordinate
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

      // Using a loop is safer and clearer than firstWhere with complex types
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

  Widget _buildWabaItem(
    IconData icon,
    String text,
    Color color, {
    bool isQuality = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        if (isQuality && text.toUpperCase().contains('GREEN')) ...[
          Text(
            text.split(': ')[0] + ': ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF535370),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            text.split(': ')[1],
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF535370),
            ),
          ),
        ] else
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF535370),
            ),
          ),
      ],
    );
  }
}

class TypingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const TypingText({super.key, required this.text, required this.style});

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _characterCount;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _characterCount = IntTween(begin: 0, end: widget.text.length).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _characterCount,
      builder: (context, child) {
        final len = _characterCount.value.clamp(0, widget.text.length);
        String text = widget.text.substring(0, len);
        return Text(text, style: widget.style);
      },
    );
  }
}
