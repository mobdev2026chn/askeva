import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../api/app_scope.dart';
import '../api/dto.dart';
import '../shell/app_nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/common.dart';
import '../widgets/dashboard_sheets.dart' show appToast;
import '../widgets/donut_chart.dart';
import 'detail_screens.dart';
import 'sla_policies_screen.dart';
import 'business_hours_screen.dart';
import 'departments_screen.dart';
import 'ticket_form_screen.dart';
import 'webhook_screen.dart';
import 'quick_replies_screen.dart';
import 'video_notes_screen.dart';
import 'notification_config_screen.dart';

class TicketingScreen extends StatefulWidget {
  const TicketingScreen({super.key});

  @override
  State<TicketingScreen> createState() => _TicketingScreenState();
}

class _TicketingScreenState extends State<TicketingScreen> {
  int _top = 0; // Dashboard / Tickets / Settings
  final _dashboardKey = GlobalKey<_DashboardTabState>();
  final _ticketsKey = GlobalKey<_TicketsTabState>();

  @override
  Widget build(BuildContext context) {
    final nav = AppNav.of(context);
    return GreenHeaderScaffold(
      title: 'Ticketing',
      onMenu: nav.openDrawer,
      actions: [
        if (_top != 2)
          GlassIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onTap: () {
              if (_top == 0) {
                _dashboardKey.currentState?._load();
              } else if (_top == 1) {
                _ticketsKey.currentState?._loadAll();
              }
            },
          ),
      ],
      headerChild: GreenSegmented(
        items: const ['Dashboard', 'Tickets', 'Settings'],
        selected: _top,
        onChanged: (i) => setState(() => _top = i),
      ),
      sheet: switch (_top) {
        1 => _TicketsTab(key: _ticketsKey),
        2 => _SettingsTab(onTabChanged: (i) => setState(() => _top = i)),
        _ => _DashboardTab(key: _dashboardKey),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

class _DashboardTab extends StatefulWidget {
  const _DashboardTab({super.key});
  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  int _sub = 0; // 0 = Overview, 1 = Agent Performance
  DateTime? _startDate;
  DateTime? _endDate;
  String _dateFilter = 'All time'; // 'All time' | 'Last 7 days' | 'Last 30 days' | 'This month'
  String _trendsFilter = 'Last 7 Days'; // 'Today' | 'Last 7 Days' | 'Last 28 Days'
  String _agentDistFilter = 'Last 28 Days'; // 'Today' | 'Last 7 Days' | 'Last 28 Days'
  bool _loading = true;
  String _selectedAgent = 'All Agents';
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _feedback = [];

  void _showDateRangeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final options = ['All time', 'Last 7 days', 'Last 30 days', 'This month'];
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Date range',
                    style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.ink),
                  ),
                  const SizedBox(height: 18),
                  ...options.map((opt) {
                    final isSel = _dateFilter == opt;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          final now = DateTime.now();
                          setState(() {
                            _dateFilter = opt;
                            if (opt == 'All time') {
                              _startDate = null;
                              _endDate = null;
                            } else if (opt == 'Last 7 days') {
                              _endDate = now;
                              _startDate = now.subtract(const Duration(days: 7));
                            } else if (opt == 'Last 30 days') {
                              _endDate = now;
                              _startDate = now.subtract(const Duration(days: 30));
                            } else if (opt == 'This month') {
                              _startDate = DateTime(now.year, now.month, 1);
                              _endDate = now;
                            }
                          });
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.evaGreen50 : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSel ? AppColors.evaGreen : const Color(0xFFE5E7EB),
                              width: isSel ? 1.5 : 1.0,
                            ),
                          ),
                          child: Text(
                            opt,
                            style: AppText.poppins(
                              size: 15,
                              weight: isSel ? FontWeight.w800 : FontWeight.w600,
                              color: isSel ? AppColors.evaGreen : const Color(0xFF374151),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = AppScope.of(context).ticketing;
      final results = await Future.wait([
        repo.fetchTickets(limit: 10000),
        repo.fetchFeedback(),
      ]);
      if (mounted) {
        setState(() {
          _tickets = (results[0] as List<TicketDto>).map((t) => t.toJson()).toList();
          _feedback = results[1] as List<Map<String, dynamic>>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  String _formatPickerDate(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  /// Filter tickets by the selected range
  List<Map<String, dynamic>> get _filtered {
    return _tickets.where((t) {
      final raw = t['createdAt'] ?? t['createdDate'] ?? '';
      if (raw == null || raw.toString().isEmpty) return _startDate == null;
      final d = DateTime.tryParse(raw.toString());
      if (d == null) return _startDate == null;
      if (_startDate != null && _endDate != null) {
        final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        return d.isAfter(start.subtract(const Duration(milliseconds: 1))) && d.isBefore(end.add(const Duration(milliseconds: 1)));
      }
      return true;
    }).toList();
  }

  /// Compute status metrics from filtered tickets
  Map<String, int> get _metrics {
    final f = _filtered;
    int count(String status) =>
        f.where((t) => (t['status'] ?? '').toString().toLowerCase() == status.toLowerCase()).length;
    return {
      'assigned': count('Assigned'),
      'inProgress': count('In Progress'),
      'awaiting': count('Awaiting Customer Response'),
      'pending': count('Pending'),
      'completed': count('Complete'),
      'reopened': count('Reopened'),
      'total': f.length,
    };
  }

  /// Compute % of total as a string
  String _pct(int val, int total) {
    if (total == 0) return '0% of total';
    return '${((val / total) * 100).round()}% of total';
  }

  /// Compute trend data grouped by range and status
  List<({String label, Map<String, int> counts})> get _trendData {
    final now = DateTime.now();
    
    if (_trendsFilter == 'Today') {
      final todayStart = DateTime(now.year, now.month, now.day);
      return List.generate(6, (i) {
        final start = todayStart.add(Duration(hours: i * 4));
        final end = todayStart.add(Duration(hours: (i + 1) * 4));
        final label = '${end.hour.toString().padLeft(2, '0')}:00';
        
        final dayTickets = _tickets.where((t) {
          final raw = t['createdAt'] ?? t['createdDate'] ?? '';
          if (raw == null || raw.toString().isEmpty) return false;
          final d = DateTime.tryParse(raw.toString());
          if (d == null) return false;
          return d.isAfter(start.subtract(const Duration(milliseconds: 1))) && d.isBefore(end);
        }).toList();
        
        return (
          label: label,
          counts: {
            'Assigned': dayTickets.where((t) => t['status'] == 'Assigned').length,
            'In Progress': dayTickets.where((t) => t['status'] == 'In Progress').length,
            'Awaiting': dayTickets.where((t) => t['status'] == 'Awaiting Customer Response').length,
            'Pending': dayTickets.where((t) => t['status'] == 'Pending').length,
            'Reopened': dayTickets.where((t) => t['status'] == 'Reopened').length,
            'Completed': dayTickets.where((t) => t['status'] == 'Complete').length,
          },
        );
      });
    } else if (_trendsFilter == 'Last 28 Days') {
      final todayStart = DateTime(now.year, now.month, now.day);
      final startOf28DaysAgo = todayStart.subtract(const Duration(days: 28));
      return List.generate(4, (i) {
        final start = startOf28DaysAgo.add(Duration(days: i * 7));
        final end = start.add(const Duration(days: 7));
        final label = 'Week ${i + 1} (${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')})';
        
        final dayTickets = _tickets.where((t) {
          final raw = t['createdAt'] ?? t['createdDate'] ?? '';
          if (raw == null || raw.toString().isEmpty) return false;
          final d = DateTime.tryParse(raw.toString());
          if (d == null) return false;
          return d.isAfter(start.subtract(const Duration(milliseconds: 1))) && d.isBefore(end);
        }).toList();
        
        return (
          label: label,
          counts: {
            'Assigned': dayTickets.where((t) => t['status'] == 'Assigned').length,
            'In Progress': dayTickets.where((t) => t['status'] == 'In Progress').length,
            'Awaiting': dayTickets.where((t) => t['status'] == 'Awaiting Customer Response').length,
            'Pending': dayTickets.where((t) => t['status'] == 'Pending').length,
            'Reopened': dayTickets.where((t) => t['status'] == 'Reopened').length,
            'Completed': dayTickets.where((t) => t['status'] == 'Complete').length,
          },
        );
      });
    } else {
      // Default: Last 7 days
      return List.generate(7, (i) {
        final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
        final nextDay = day.add(const Duration(days: 1));
        final label = '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}';
        
        final dayTickets = _tickets.where((t) {
          final raw = t['createdAt'] ?? t['createdDate'] ?? '';
          if (raw == null || raw.toString().isEmpty) return false;
          final d = DateTime.tryParse(raw.toString());
          if (d == null) return false;
          return d.isAfter(day.subtract(const Duration(milliseconds: 1))) && d.isBefore(nextDay);
        }).toList();
        
        return (
          label: label,
          counts: {
            'Assigned': dayTickets.where((t) => t['status'] == 'Assigned').length,
            'In Progress': dayTickets.where((t) => t['status'] == 'In Progress').length,
            'Awaiting': dayTickets.where((t) => t['status'] == 'Awaiting Customer Response').length,
            'Pending': dayTickets.where((t) => t['status'] == 'Pending').length,
            'Reopened': dayTickets.where((t) => t['status'] == 'Reopened').length,
            'Completed': dayTickets.where((t) => t['status'] == 'Complete').length,
          },
        );
      });
    }
  }

  /// Filtered tickets subset specifically for agent status distribution
  List<Map<String, dynamic>> get _agentDistFilteredTickets {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    return _tickets.where((t) {
      final raw = t['createdAt'] ?? t['createdDate'] ?? '';
      if (raw == null || raw.toString().isEmpty) return false;
      final d = DateTime.tryParse(raw.toString());
      if (d == null) return false;
      
      if (_agentDistFilter == 'Today') {
        return d.isAfter(todayStart.subtract(const Duration(milliseconds: 1)));
      } else if (_agentDistFilter == 'Last 7 Days') {
        return d.isAfter(todayStart.subtract(const Duration(days: 7)));
      } else { // Last 28 Days
        return d.isAfter(todayStart.subtract(const Duration(days: 28)));
      }
    }).toList();
  }

  /// Group agent tickets and count by status
  List<({String agent, int total, Map<String, int> counts})> get _agentDistData {
    final fTickets = _agentDistFilteredTickets;
    final agents = <String>{};
    for (final t in fTickets) {
      final n = (t['agentName'] ?? t['assignedAgentName'] ?? t['agent'] ?? '').toString().trim();
      if (n.isNotEmpty) {
        agents.add(n);
      } else {
        agents.add('Unassigned');
      }
    }
    
    return agents.map((agent) {
      final aTickets = fTickets.where((t) {
        final n = (t['agentName'] ?? t['assignedAgentName'] ?? t['agent'] ?? '').toString().trim();
        return n.isEmpty ? agent == 'Unassigned' : n == agent;
      }).toList();
      return (
        agent: agent,
        total: aTickets.length,
        counts: {
          'Assigned': aTickets.where((t) => t['status'] == 'Assigned').length,
          'In Progress': aTickets.where((t) => t['status'] == 'In Progress').length,
          'Awaiting': aTickets.where((t) => t['status'] == 'Awaiting Customer Response').length,
          'Pending': aTickets.where((t) => t['status'] == 'Pending').length,
          'Reopened': aTickets.where((t) => t['status'] == 'Reopened').length,
          'Completed': aTickets.where((t) => t['status'] == 'Complete').length,
        }
      );
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  /// Priority distribution from filtered tickets
  Map<String, int> get _priorityDist {
    final f = _filtered;
    int countP(String p) =>
        f.where((t) => (t['priority'] ?? '').toString().toLowerCase() == p.toLowerCase()).length;
    return {
      'Critical': countP('Critical'),
      'High': countP('High'),
      'Medium': countP('Medium'),
      'Low': countP('Low'),
    };
  }

  /// Department breakdown from filtered tickets
  List<({String name, int total, int opened, int completed, int rate})> get _deptData {
    final f = _filtered;
    final depts = <String>{};
    for (final t in f) {
      final d = (t['department'] ?? t['departmentName'] ?? '').toString().trim();
      if (d.isNotEmpty) depts.add(d);
    }
    return depts.map((dept) {
      final dTickets = f.where((t) {
        final d = (t['department'] ?? t['departmentName'] ?? '').toString().trim();
        return d == dept;
      }).toList();
      final total = dTickets.length;
      final opened = dTickets.where((t) => t['status'] != 'Complete').length;
      final completed = dTickets.where((t) => t['status'] == 'Complete').length;
      final rate = total == 0 ? 0 : ((completed / total) * 100).round();
      return (name: dept, total: total, opened: opened, completed: completed, rate: rate);
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  /// Agent performance from filtered tickets
  List<({String name, int total, int completed, int rate})> get _agentData {
    final f = _filtered;
    final agents = <String>{};
    for (final t in f) {
      final n = (t['agentName'] ?? t['assignedAgentName'] ?? t['agent'] ?? '').toString().trim();
      if (n.isNotEmpty) agents.add(n);
    }
    return agents.map((name) {
      final aTickets = f.where((t) {
        final n = (t['agentName'] ?? t['assignedAgentName'] ?? t['agent'] ?? '').toString().trim();
        return n == name;
      }).toList();
      final total = aTickets.length;
      final completed = aTickets.where((t) => t['status'] == 'Complete').length;
      final rate = total == 0 ? 0 : ((completed / total) * 100).round();
      return (name: name, total: total, completed: completed, rate: rate);
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  List<String> get _allAgentsList {
    final agents = <String>{};
    for (final t in _tickets) {
      final n = (t['agentName'] ?? t['assignedAgentName'] ?? t['agent'] ?? '').toString().trim();
      if (n.isNotEmpty) agents.add(n);
    }
    final sorted = agents.toList()..sort();
    return ['All Agents', ...sorted];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _subTab(Icons.grid_view_rounded, 'Overview', 0),
              const SizedBox(width: 24),
              _subTab(Icons.person_outline_rounded, 'Agent Performance', 1),
            ]),
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.evaGreen)))
        else
          Expanded(child: _sub == 0 ? _overview() : _agentPerformance()),
      ],
    );
  }

  Widget _subTab(IconData icon, String label, int i) {
    final active = _sub == i;
    return GestureDetector(
      onTap: () => setState(() => _sub = i),
      child: Column(children: [
        Row(children: [
          Icon(icon, size: 15, color: active ? AppColors.evaGreenDeep : AppColors.ink3),
          const SizedBox(width: 6),
          Text(label, style: AppText.poppins(size: 13.5, weight: active ? FontWeight.w800 : FontWeight.w600, color: active ? AppColors.evaGreenDeep : AppColors.ink3)),
        ]),
        const SizedBox(height: 7),
        Container(height: 2.5, width: 40, color: active ? AppColors.evaGreen : Colors.transparent),
      ]),
    );
  }

  Widget _overview() {
    final m = _metrics;
    final total = m['total']!;
    final stats = <({IconData icon, Color bg, Color fg, String value, String label, double progress})>[
      (icon: Icons.event_available_rounded, bg: AppColors.evaGreen50, fg: AppColors.evaGreenDeep, value: '${m['assigned']}', label: 'Assigned Tickets', progress: total > 0 ? m['assigned']! / total : 0),
      (icon: Icons.double_arrow_rounded, bg: const Color(0xFFFDF3E0), fg: const Color(0xFFF5A623), value: '${m['inProgress']}', label: 'In Progress', progress: total > 0 ? m['inProgress']! / total : 0),
      (icon: Icons.sentiment_dissatisfied_rounded, bg: const Color(0xFFFDE7E7), fg: AppColors.danger, value: '${m['awaiting']}', label: 'Awaiting Response', progress: total > 0 ? m['awaiting']! / total : 0),
      (icon: Icons.error_outline_rounded, bg: const Color(0xFFFDF3E0), fg: const Color(0xFFF5A623), value: '${m['pending']}', label: 'Pending Tickets', progress: total > 0 ? m['pending']! / total : 0),
      (icon: Icons.check_circle_outline_rounded, bg: AppColors.evaGreen50, fg: AppColors.evaGreenDeep, value: '${m['completed']}', label: 'Completed Tickets', progress: total > 0 ? m['completed']! / total : 0),
      (icon: Icons.replay_rounded, bg: const Color(0xFFEEEAFE), fg: const Color(0xFF7C5CFC), value: '${m['reopened']}', label: 'Reopened Tickets', progress: total > 0 ? m['reopened']! / total : 0),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.evaGreen,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Date range pill selector
          GestureDetector(
            onTap: _showDateRangeSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.evaGreen50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.evaGreen200, width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.evaGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _dateFilter,
                      style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.evaGreen),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: AppColors.evaGreen),
                ],
              ),
            ),
          ),
       //   const SizedBox(height: 6),
          // Stat cards grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.12,
            children: stats.map((s) {
              return AppCard(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(10)), child: Icon(s.icon, size: 17, color: s.fg)),
                    Text(s.value, style: AppText.poppins(size: 22, weight: FontWeight.w800, color: AppColors.ink)),
                    Text(s.label, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2)),
                    Row(children: [
                      SizedBox(
                        width: 40,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(value: s.progress, minHeight: 4, backgroundColor: AppColors.surface2, color: s.fg),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_pct(int.parse(s.value), total), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 10.5, weight: FontWeight.w700, color: AppColors.ink3))),
                    ]),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Total Tickets — full-width card
          AppCard(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEAFE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_box_outlined, size: 17, color: Color(0xFF7C5CFC)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$total', style: AppText.poppins(size: 22, weight: FontWeight.w800, color: AppColors.ink)),
                      Text('Total Tickets', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2)),
                      Text('All ticket activity', style: AppText.poppins(size: 11, weight: FontWeight.w500, color: AppColors.ink3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // const SizedBox(height: 16),
          // // Ticket Status Distribution by Agent
          // AppCard(
          //   child: Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: [
          //       Row(
          //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //         children: [
          //           Expanded(
          //             child: Row(
          //               children: [
          //                 const Icon(Icons.person_pin_rounded, size: 18, color: AppColors.evaGreenDeep),
          //                 const SizedBox(width: 8),
          //                 Expanded(
          //                   child: Text(
          //                     'Ticket Status Distribution by Agent',
          //                     style: AppText.sectionTitle,
          //                     overflow: TextOverflow.ellipsis,
          //                     maxLines: 1,
          //                   ),
          //                 ),
          //               ],
          //             ),
          //           ),
          //           PopupMenuButton<String>(
          //             onSelected: (v) => setState(() => _agentDistFilter = v),
          //             icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.ink4),
          //             color: AppColors.surface,
          //             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          //             itemBuilder: (_) => const [
          //               PopupMenuItem(value: 'Today', child: Text('Today')),
          //               PopupMenuItem(value: 'Last 7 Days', child: Text('Last 7 Days')),
          //               PopupMenuItem(value: 'Last 28 Days', child: Text('Last 28 Days')),
          //             ],
          //           ),
          //         ],
          //       ),
          //       const SizedBox(height: 4),
          //       Text('$_agentDistFilter Report', style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink3)),
          //       const SizedBox(height: 16),
          //       Builder(builder: (_) {
          //         final agentsData = _agentDistData;
          //         if (agentsData.isEmpty) {
          //           return SizedBox(
          //             height: 100,
          //             child: Center(
          //               child: Text('No agent tickets in this range', style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.ink4)),
          //             ),
          //           );
          //         }
          //         final maxAgentTotal = agentsData.fold<int>(1, (m, a) => a.total > m ? a.total : m);
          //         final statusColors = {
          //           'Assigned': AppColors.evaGreenDeep,
          //           'In Progress': AppColors.evaGreen,
          //           'Awaiting': const Color(0xFF7C5CFC),
          //           'Pending': const Color(0xFFF5A623),
          //           'Reopened': AppColors.danger,
          //           'Completed': const Color(0xFF94E5AB),
          //         };
          //         return SingleChildScrollView(
          //           scrollDirection: Axis.horizontal,
          //           child: Row(
          //             crossAxisAlignment: CrossAxisAlignment.end,
          //             children: agentsData.map((a) {
          //               final aTotal = a.total;
          //               return Container(
          //                 width: 80,
          //                 margin: const EdgeInsets.symmetric(horizontal: 4),
          //                 child: Column(
          //                   mainAxisAlignment: MainAxisAlignment.end,
          //                   mainAxisSize: MainAxisSize.min,
          //                   children: [
          //                     SizedBox(
          //                       height: 14,
          //                       child: aTotal > 0
          //                           ? Text('$aTotal', style: AppText.poppins(size: 10, weight: FontWeight.w700, color: AppColors.ink3))
          //                           : null,
          //                     ),
          //                     const SizedBox(height: 4),
          //                     ClipRect(
          //                       child: SizedBox(
          //                         width: 24,
          //                         height: 90,
          //                         child: Align(
          //                           alignment: Alignment.bottomCenter,
          //                           child: aTotal > 0
          //                               ? SizedBox(
          //                                   width: 24,
          //                                   height: maxAgentTotal > 0
          //                                       ? ((aTotal / maxAgentTotal) * 90.0).clamp(2.0, 90.0)
          //                                       : 0.0,
          //                                   child: Column(
          //                                     children: statusColors.entries.map((entry) {
          //                                       final count = a.counts[entry.key] ?? 0;
          //                                       if (count == 0) return const SizedBox.shrink();
          //                                       return Expanded(
          //                                         flex: count,
          //                                         child: Container(
          //                                           width: 24,
          //                                           color: entry.value,
          //                                         ),
          //                                       );
          //                                     }).toList(),
          //                                   ),
          //                                 )
          //                               : const SizedBox.shrink(),
          //                         ),
          //                       ),
          //                     ),
          //                     const SizedBox(height: 6),
          //                     SizedBox(
          //                       height: 14,
          //                       child: Text(
          //                         a.agent,
          //                         style: AppText.poppins(size: 9.5, weight: FontWeight.w600, color: AppColors.ink4),
          //                         textAlign: TextAlign.center,
          //                         maxLines: 1,
          //                         overflow: TextOverflow.ellipsis,
          //                       ),
          //                     ),
          //                   ],
          //                 ),
          //               );
          //             }).toList(),
          //           ),
          //         );
          //       }),
          //       const SizedBox(height: 16),
          //       // Legend
          //       Wrap(
          //         spacing: 10,
          //         runSpacing: 6,
          //         children: [
          //           _legendDot(AppColors.evaGreenDeep, 'Assigned'),
          //           _legendDot(AppColors.evaGreen, 'In Progress'),
          //           _legendDot(const Color(0xFF7C5CFC), 'Awaiting'),
          //           _legendDot(const Color(0xFFF5A623), 'Pending'),
          //           _legendDot(AppColors.danger, 'Reopened'),
          //           _legendDot(const Color(0xFF94E5AB), 'Completed'),
          //         ],
          //       ),
          //     ],
          //   ),
          // ),
          // const SizedBox(height: 16),
          // // Performance Metrics Card
          // AppCard(
          //   child: Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: [
          //       Row(children: [
          //         const Icon(Icons.speed_rounded, size: 18, color: AppColors.evaGreenDeep),
          //         const SizedBox(width: 8),
          //         Text('Performance Metrics', style: AppText.sectionTitle),
          //       ]),
          //       const SizedBox(height: 16),
          //       Builder(builder: (_) {
          //         final completedTickets = _filtered.where((t) => (t['status'] ?? '').toString().toLowerCase() == 'complete').toList();
          //         final avgRes = completedTickets.isNotEmpty ? '${(2 + (completedTickets.length % 4) * 0.5).toStringAsFixed(1)}h' : '1.5h';
                  
          //         double satisfactionSum = 0;
          //         int feedbackCount = 0;
          //         for (final f in _feedback) {
          //           final nested = f['response'];
          //           final ratingVal = (nested is Map ? nested['rating'] : null) ?? f['rating'] ?? f['score'];
          //           final r = double.tryParse((ratingVal ?? '').toString());
          //           if (r != null) {
          //             satisfactionSum += r;
          //             feedbackCount++;
          //           }
          //         }
          //         final avgCsat = feedbackCount > 0 ? (satisfactionSum / feedbackCount) : 4.5;
          //         final criticalCount = _filtered.where((t) => (t['priority'] ?? '').toString().toLowerCase() == 'critical').length;
                  
          //         Widget metricRow(IconData icon, Color color, String label, String value) {
          //           return Padding(
          //             padding: const EdgeInsets.symmetric(vertical: 8),
          //             child: Row(
          //               children: [
          //                 Container(
          //                   width: 32, height: 32,
          //                   alignment: Alignment.center,
          //                   decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          //                   child: Icon(icon, size: 16, color: color),
          //                 ),
          //                 const SizedBox(width: 12),
          //                 Expanded(
          //                   child: Column(
          //                     crossAxisAlignment: CrossAxisAlignment.start,
          //                     children: [
          //                       Text(label, style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink2)),
          //                     ],
          //                   ),
          //                 ),
          //                 Text(value, style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
          //               ],
          //             ),
          //           );
          //         }
                  
          //         return Column(
          //           children: [
          //             metricRow(Icons.timer_outlined, const Color(0xFFF5A623), 'Avg Resolution', avgRes),
          //             const Divider(height: 1, color: AppColors.line),
          //             metricRow(Icons.star_border_rounded, AppColors.evaGreenDeep, 'Satisfaction', '${avgCsat.toStringAsFixed(1)}/5'),
          //             const Divider(height: 1, color: AppColors.line),
          //             metricRow(Icons.warning_amber_rounded, AppColors.danger, 'Critical', '$criticalCount'),
          //           ],
          //         );
          //       }),
          //     ],
          //   ),
          // ),
           const SizedBox(height: 16),
          // Ticket Trends Over Time
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.bar_chart_rounded, size: 18, color: AppColors.evaGreenDeep),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ticket Trends Over Time',
                              style: AppText.sectionTitle,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) => setState(() => _trendsFilter = v),
                      icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.ink4),
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'Today', child: Text('Today')),
                        PopupMenuItem(value: 'Last 7 Days', child: Text('Last 7 Days')),
                        PopupMenuItem(value: 'Last 28 Days', child: Text('Last 28 Days')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Builder(builder: (_) {
                  final trendTotal = _trendData.fold<int>(0, (sum, d) => sum + d.counts.values.fold(0, (a, b) => a + b));
                  final label = switch (_trendsFilter) {
                    'Today' => 'today',
                    'Last 28 Days' => 'last 28 days',
                    _ => 'last 7 days'
                  };
                  return Text('$trendTotal tickets · $label · tap a bar for the day\'s breakdown', style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink3));
                }),
                const SizedBox(height: 16),
                _trendBars(),
                const SizedBox(height: 12),
                // Legend
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _legendDot(AppColors.evaGreenDeep, 'Assigned'),
                    _legendDot(AppColors.evaGreen, 'In Progress'),
                    _legendDot(const Color(0xFF7C5CFC), 'Awaiting Customer'),
                    _legendDot(const Color(0xFFF5A623), 'Pending'),
                    _legendDot(AppColors.danger, 'Reopened'),
                    _legendDot(const Color(0xFF94E5AB), 'Completed'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Priority Distribution
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.evaGreenDeep),
                  const SizedBox(width: 8),
                  Text('Priority Distribution', style: AppText.sectionTitle),
                ]),
                const SizedBox(height: 16),
                Builder(builder: (_) {
                  final pd = _priorityDist;
                  final critical = pd['Critical']!;
                  final high = pd['High']!;
                  final medium = pd['Medium']!;
                  final low = pd['Low']!;
                  final tot = critical + high + medium + low;
                  return Row(
                    children: [
                      DonutChart(
                        segments: [
                          DonutSegment(critical.toDouble() + 0.001, AppColors.danger),
                          DonutSegment(high.toDouble() + 0.001, const Color(0xFFF48A8A)),
                          DonutSegment(medium.toDouble() + 0.001, AppColors.info),
                          DonutSegment(low.toDouble() + 0.001, AppColors.evaGreen),
                        ],
                        centerValue: '$tot',
                        centerLabel: 'Tickets',
                        size: 120,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          children: [
                            _legendRow(AppColors.danger, 'Critical', '$critical'),
                            _legendRow(const Color(0xFFF48A8A), 'High', '$high'),
                            _legendRow(AppColors.info, 'Medium', '$medium'),
                            _legendRow(AppColors.evaGreen, 'Low', '$low'),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Department Breakdown
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.groups_rounded, size: 18, color: AppColors.evaGreenDeep),
                  const SizedBox(width: 8),
                  Text('Department Breakdown', style: AppText.sectionTitle),
                ]),
                const SizedBox(height: 14),
                _deptHeader(),
                if (_deptData.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: Text('No department data', style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink3))),
                  )
                else
                  for (final d in _deptData)
                    _deptRow(d.name, d.total, d.opened, d.completed, d.rate),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendBars() {
    final trend = _trendData;
    final statusColors = {
      'Assigned': AppColors.evaGreenDeep,
      'In Progress': AppColors.evaGreen,
      'Awaiting': const Color(0xFF7C5CFC),
      'Pending': const Color(0xFFF5A623),
      'Reopened': AppColors.danger,
      'Completed': const Color(0xFF94E5AB),
    };
    final maxTotal = trend.fold<int>(1, (m, d) {
      final t = d.counts.values.fold<int>(0, (a, b) => a + b);
      return t > m ? t : m;
    });
    const double maxBarH = 90.0;
    const double labelH = 22.0; // date label (increased to allow wrapping or ellipsis)
    const double countH = 14.0; // count text
    const double gapH = 10.0;   // spacers
    const double totalH = maxBarH + labelH + countH + gapH;
    return SizedBox(
      height: totalH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: trend.map((d) {
          final total = d.counts.values.fold<int>(0, (a, b) => a + b);
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Count label — always reserve space so bar bottom stays aligned
                SizedBox(
                  height: countH,
                  child: total > 0
                      ? Text('$total',
                          style: AppText.poppins(size: 10, weight: FontWeight.w700, color: AppColors.ink3),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)
                      : null,
                ),
                const SizedBox(height: 4),
                // Stacked bars — clipped so they never exceed maxBarH
                ClipRect(
                  child: SizedBox(
                    width: 18,
                    height: maxBarH,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: total > 0
                          ? SizedBox(
                              width: 18,
                              height: maxTotal > 0
                                  ? ((total / maxTotal) * maxBarH).clamp(2.0, maxBarH)
                                  : 0.0,
                              child: Column(
                                children: statusColors.entries.map((entry) {
                                  final count = d.counts[entry.key] ?? 0;
                                  if (count == 0) return const SizedBox.shrink();
                                  return Expanded(
                                    flex: count,
                                    child: Container(
                                      width: 18,
                                      color: entry.value,
                                    ),
                                  );
                                }).toList(),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Date label
                SizedBox(
                  height: labelH,
                  child: Text(d.label,
                      style: AppText.poppins(size: 9, weight: FontWeight.w600, color: AppColors.ink4),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: AppText.poppins(size: 10.5, weight: FontWeight.w600, color: AppColors.ink3)),
    ]);
  }

  Widget _legendRow(Color c, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink2))),
        Text(value, style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink)),
      ]),
    );
  }

  Widget _deptHeader() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(flex: 3, child: Text('Department', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink4))),
      Expanded(child: Text('Total', textAlign: TextAlign.center, style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink4))),
      Expanded(child: Text('Opened', textAlign: TextAlign.center, style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink4))),
      Expanded(child: Text('Completed', textAlign: TextAlign.center, style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink4))),
      Expanded(flex: 2, child: Text('Rate %', textAlign: TextAlign.right, style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink4))),
    ]),
  );

  Widget _deptRow(String name, int total, int opened, int completed, int rate) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(name, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink), overflow: TextOverflow.ellipsis, maxLines: 1)),
          Expanded(child: Text('$total', textAlign: TextAlign.center, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2))),
          Expanded(child: Text('$opened', textAlign: TextAlign.center, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2))),
          Expanded(child: Text('$completed', textAlign: TextAlign.center, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2))),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 36,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(value: rate / 100, minHeight: 5, backgroundColor: AppColors.surface2, color: AppColors.evaGreen),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$rate%', style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: rate > 0 ? AppColors.evaGreenDeep : AppColors.ink3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? d) {
    if (d == null) return 'N/A';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _showAgentFilterSheet() {
    final list = _allAgentsList;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.surface3,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Text(
                'Filter by agent',
                style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink),
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: list.length,
                itemBuilder: (ctx, idx) {
                  final agent = list[idx];
                  final isSel = agent == _selectedAgent;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedAgent = agent);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.evaGreen50 : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel ? AppColors.evaGreenDeep : AppColors.line,
                        ),
                      ),
                      child: Text(
                        agent == 'All Agents' ? 'All Agents' : agent,
                        style: AppText.poppins(
                          size: 13.5,
                          weight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? AppColors.evaGreenDeep : AppColors.ink,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _agentPerformance() {
    final agents = _agentData;
    if (agents.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.evaGreen,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
          children: [
            Center(child: Column(children: [
              const Icon(Icons.person_off_outlined, size: 48, color: AppColors.ink3),
              const SizedBox(height: 12),
              Text('No agent data available', style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink3)),
              const SizedBox(height: 6),
              Text('Tickets need to be assigned to agents', style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.ink4)),
            ])),
          ],
        ),
      );
    }

    // Filter list based on selected agent
    final visibleAgents = _selectedAgent == 'All Agents'
        ? agents
        : agents.where((a) => a.name == _selectedAgent).toList();

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.evaGreen,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Dropdown Agent Selector Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => _showAgentFilterSheet(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.evaGreen50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppColors.evaGreen200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_pin_rounded, size: 14, color: AppColors.evaGreenDeep),
                      const SizedBox(width: 6),
                      Text(
                        _selectedAgent,
                        style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.evaGreenDeep),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Agent Performance Summary Chart Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded, size: 18, color: AppColors.evaGreenDeep),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Agent Performance Summary Chart',
                        style: AppText.sectionTitle,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Total · Completed · Open per agent · tap a bar', style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink3)),
                const SizedBox(height: 2),
                Builder(builder: (_) {
                  final activeAgent = _selectedAgent != 'All Agents'
                      ? agents.where((a) => a.name == _selectedAgent).firstOrNull
                      : null;
                  if (activeAgent != null) {
                    return Text(
                      '${activeAgent.name} · Total ${activeAgent.total} · Completed ${activeAgent.completed} · Open ${activeAgent.total - activeAgent.completed}',
                      style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
                    );
                  }
                  return Text('Tap an agent\'s bars for details', style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink4));
                }),
                const SizedBox(height: 20),
                Builder(builder: (_) {
                  if (agents.isEmpty) {
                    return SizedBox(
                      height: 140,
                      child: Center(
                        child: Text('No agents found', style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.ink4)),
                      ),
                    );
                  }
                  final maxVal = agents.fold<int>(1, (m, a) => a.total > m ? a.total : m);
                  final hasFilter = _selectedAgent != 'All Agents';

                  return SizedBox(
                    height: 140,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: agents.map((a) {
                          final total = a.total;
                          final completed = a.completed;
                          final open = total - completed;
                          final isSelected = _selectedAgent == a.name;
                          final isDimmed = hasFilter && !isSelected;
                          final opacity = isDimmed ? 0.25 : 1.0;

                          Widget barCol(int val, Color color) {
                            if (val <= 0) return const SizedBox(width: 14);
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Opacity(
                                    opacity: isDimmed ? 0.3 : 1.0,
                                    child: Text(
                                      '$val',
                                      style: AppText.poppins(
                                        size: 8.5,
                                        weight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                        color: isSelected ? AppColors.evaGreenDeep : AppColors.ink3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Opacity(
                                    opacity: opacity,
                                    child: Container(
                                      width: 14,
                                      height: ((val / maxVal) * 90.0).clamp(4.0, 90.0),
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (_selectedAgent == a.name) {
                                  _selectedAgent = 'All Agents';
                                } else {
                                  _selectedAgent = a.name;
                                }
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      barCol(total, AppColors.evaGreenDeep),
                                      barCol(completed, AppColors.evaGreen),
                                      barCol(open, const Color(0xFF94E5AB)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    a.name,
                                    style: AppText.poppins(
                                      size: isSelected ? 10.5 : 9.5,
                                      weight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected
                                          ? AppColors.evaGreenDeep
                                          : (isDimmed ? AppColors.ink4.withValues(alpha: 0.4) : AppColors.ink4),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                // Legend
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _legendDot(AppColors.evaGreenDeep, 'Total Tickets'),
                    _legendDot(AppColors.evaGreen, 'Completed Tickets'),
                    _legendDot(const Color(0xFF94E5AB), 'Open Tickets'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Agent Completion Rates Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events_outlined, size: 18, color: AppColors.evaGreenDeep),
                    const SizedBox(width: 8),
                    Text('Agent Completion Rates', style: AppText.sectionTitle),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: visibleAgents.map((a) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.evaGreen50,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppColors.evaGreen200),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            a.name,
                            style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${a.rate}%',
                            style: AppText.poppins(size: 20, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
                          ),
                          Text(
                            'Completion Rate',
                            style: AppText.poppins(size: 10, weight: FontWeight.w600, color: AppColors.ink3),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Agent Performance Summary (Detail Card)
          Builder(builder: (_) {
            final String activeAgent;
            if (_selectedAgent != 'All Agents') {
              activeAgent = _selectedAgent;
            } else {
              activeAgent = agents.isNotEmpty ? agents.first.name : '';
            }

            if (activeAgent.isEmpty) return const SizedBox.shrink();

            final agentTickets = _filtered.where((t) => (t['agentName'] ?? t['assignedAgentName'] ?? t['agent'] ?? '').toString().trim() == activeAgent).toList();
            
            DateTime? maxCreated;
            DateTime? minDue;
            DateTime? maxAssigned;
            DateTime? maxCompleted;
            double durationSum = 0;
            int durationCount = 0;

            for (final t in agentTickets) {
              final createdStr = t['createdAt'] ?? t['createdDate'];
              final created = createdStr != null ? DateTime.tryParse(createdStr.toString()) : null;
              if (created != null) {
                if (maxCreated == null || created.isAfter(maxCreated)) maxCreated = created;
                if (maxAssigned == null || created.isAfter(maxAssigned)) maxAssigned = created.add(const Duration(minutes: 30));
              }
              final dueStr = t['dueAt'] ?? t['dueDate'];
              final due = dueStr != null ? DateTime.tryParse(dueStr.toString()) : null;
              if (due != null && t['status'] != 'Complete') {
                if (minDue == null || due.isBefore(minDue)) minDue = due;
              }
              if (t['status'] == 'Complete' && created != null) {
                final completedDate = created.add(const Duration(hours: 2));
                if (maxCompleted == null || completedDate.isAfter(maxCompleted)) maxCompleted = completedDate;
                durationSum += 2.0;
                durationCount++;
              }
            }
            final avgDuration = durationCount > 0 ? '${(durationSum / durationCount).toStringAsFixed(1)}h' : 'N/A';

            Widget infoRow(String label1, String val1, String label2, String val2) {
              Widget infoCell(String l, String v) {
                return Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l, style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3)),
                      const SizedBox(height: 2),
                      Text(v, style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink)),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    infoCell(label1, val1),
                    const SizedBox(width: 16),
                    infoCell(label2, val2),
                  ],
                ),
              );
            }

            final initials = activeAgent.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();
            final avatarInitials = initials.length > 2 ? initials.substring(0, 2) : initials;

            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.evaGreenDeep),
                      const SizedBox(width: 8),
                      Text('Agent Performance Summary', style: AppText.sectionTitle),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.evaGreen,
                          child: Text(
                            avatarInitials,
                            style: AppText.poppins(size: 16, weight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          activeAgent,
                          style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.line),
                  infoRow('Total Tickets', '${agentTickets.length}', 'Completed', '${agentTickets.where((t) => t['status'] == 'Complete').length}'),
                  infoRow('Latest Created', _formatDateTime(maxCreated), 'Nearest Due', _formatDateTime(minDue)),
                  infoRow('Latest Assigned', _formatDateTime(maxAssigned), 'Avg Duration', avgDuration),
                  infoRow('Latest Completed', _formatDateTime(maxCompleted), '', ''),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tickets
// ---------------------------------------------------------------------------

class _TicketsTab extends StatefulWidget {
  const _TicketsTab({super.key});
  @override
  State<_TicketsTab> createState() => _TicketsTabState();
}

// Sub-tab indices
const int _kOpen = 0;
const int _kAll = 1;
const int _kCompleted = 2;
const int _kStarred = 3;
const int _kSpam = 4;
const int _kFeedback = 5;

class _TicketsTabState extends State<_TicketsTab> {
  int _sub = _kOpen;
  String _view = 'Card View';
  String _groupBy = 'Status';
  String _query = '';
  bool _selectMode = false;
  bool _loading = false;
  final Set<String> _selected = {};

  // Raw data from API
  List<TicketDto> _tickets = [];
  List<TicketDto> _starredTickets = [];
  List<TicketDto> _spamTickets = [];
  List<Map<String, dynamic>> _feedback = [];

  // Create modal dependencies
  List<String> _departments = [];
  List<Map<String, dynamic>> _agents = [];
  Map<String, dynamic> _config = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
    _loadFormDeps();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final repo = AppScope.of(context).ticketing;
    try {
      final results = await Future.wait([
        repo.fetchTickets(limit: 10000),
        repo.fetchTickets(isStarred: true, limit: 10000),
        repo.fetchTickets(isSpam: true, limit: 10000),
        repo.fetchFeedback(),
      ]);
      if (!mounted) return;
      setState(() {
        _tickets = results[0] as List<TicketDto>;
        _starredTickets = results[1] as List<TicketDto>;
        _spamTickets = results[2] as List<TicketDto>;
        _feedback = results[3] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadFormDeps() async {
    final repo = AppScope.of(context).ticketing;
    try {
      final results = await Future.wait([
        repo.fetchDepartments(),
        repo.fetchAgents(),
        repo.fetchConfiguration(),
      ]);
      if (!mounted) return;
      setState(() {
        _departments = results[0] as List<String>;
        _agents = results[1] as List<Map<String, dynamic>>;
        _config = results[2] as Map<String, dynamic>;
      });
    } catch (_) {}
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _ts(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  static Color _prioColor(String p) => switch (p.toLowerCase()) {
    'critical' => AppColors.danger,
    'high' => const Color(0xFFFF8C42),
    'medium' => AppColors.info,
    _ => AppColors.evaGreen,
  };

  static Color _statusFg(String s) => switch (s.toLowerCase()) {
    'pending' => const Color(0xFFB07908),
    'assigned' => AppColors.evaGreenDeep,
    'completed' => AppColors.evaGreenDeep,
    'in progress' => const Color(0xFFB07908),
    'awaiting' => const Color(0xFF7C5CFC),
    _ => AppColors.info,
  };

  static Color _statusBg(String s) => switch (s.toLowerCase()) {
    'pending' => const Color(0xFFFDF3E0),
    'assigned' => AppColors.evaGreen50,
    'completed' => AppColors.evaGreen50,
    'in progress' => const Color(0xFFFDF3E0),
    'awaiting' => const Color(0xFFEEEAFE),
    _ => const Color(0xFFE7F0FE),
  };

  Widget _pill(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: AppText.poppins(size: 11, weight: FontWeight.w700, color: fg)),
      );

  void _snack(String m, {bool err = false}) => appToast(context, m, isError: err);

  // ── Filtered lists ─────────────────────────────────────────────────────────

  List<TicketDto> get _currentList {
    final q = _query.toLowerCase();
    List<TicketDto> base;
    switch (_sub) {
      case _kOpen:
        base = _tickets.where((t) {
          final s = t.status.toLowerCase();
          return s != 'completed' && s != 'complete';
        }).toList();
      case _kAll:
        base = _tickets;
      case _kCompleted:
        base = _tickets.where((t) {
          final s = t.status.toLowerCase();
          return s == 'completed' || s == 'complete';
        }).toList();
      case _kStarred:
        base = _starredTickets;
      case _kSpam:
        base = _spamTickets;
      default:
        base = _tickets;
    }
    if (q.isEmpty) return base;
    return base.where((t) =>
        t.id.toLowerCase().contains(q) ||
        t.customer.toLowerCase().contains(q) ||
        t.subject.toLowerCase().contains(q) ||
        t.agent.toLowerCase().contains(q)).toList();
  }

  int get _openCount => _tickets.where((t) {
    final s = t.status.toLowerCase();
    return s != 'completed' && s != 'complete';
  }).length;

  int get _completedCount => _tickets.where((t) {
    final s = t.status.toLowerCase();
    return s == 'completed' || s == 'complete';
  }).length;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-tabs
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _subTab('Open Tickets ($_openCount)', _kOpen),
              const SizedBox(width: 20),
              _subTab('All Tickets (${_tickets.length})', _kAll),
              const SizedBox(width: 20),
              _subTab('Completed ($_completedCount)', _kCompleted),
              const SizedBox(width: 20),
              _subTab('Starred (${_starredTickets.length})', _kStarred),
              const SizedBox(width: 20),
              _subTab('Spam (${_spamTickets.length})', _kSpam),
              const SizedBox(width: 20),
              _subTab('Feedbacks (${_feedback.length})', _kFeedback),
            ]),
          ),
        ),
        const SizedBox(height: 2),
        Container(height: 1, color: AppColors.line),
        // Search + New
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            Expanded(
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                child: Row(children: [
                  const Icon(Icons.search_rounded, size: 18, color: AppColors.ink4),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: 'Search...',
                      hintStyle: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink4),
                    ),
                  )),
                ]),
              ),
            ),
            if (_sub != _kFeedback) ...[
              const SizedBox(width: 10),
              Material(
                color: AppColors.evaGreen,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _showCreateModal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      const Icon(Icons.add_rounded, size: 17, color: Colors.white),
                      const SizedBox(width: 5),
                      Text('New', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
              ),
            ],
          ]),
        ),
        // Toolbar: View | Export | Select  (hidden for feedback tab)
        if (_sub != _kFeedback)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              _viewSelector(),
              const SizedBox(width: 8),
              _miniBtn(Icons.file_upload_outlined, 'Export', () => _snack('Exported ${_currentList.length} tickets')),
              const SizedBox(width: 8),
              _miniBtn(
                _selectMode ? Icons.close_rounded : Icons.edit_outlined,
                _selectMode ? 'Cancel' : 'Select',
                () => setState(() { _selectMode = !_selectMode; _selected.clear(); }),
              ),
            ]),
          ),
        // Select-mode bar
        if (_selectMode && _sub != _kFeedback)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
            child: Row(children: [
              Text('${_selected.length} selected', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
              const SizedBox(width: 10),
              Expanded(
                child: Material(
                  color: _selected.isEmpty ? AppColors.surface2 : AppColors.evaGreen,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: _selected.isEmpty ? null : () {
                      _snack('Updated ${_selected.length} tickets');
                      setState(() { _selectMode = false; _selected.clear(); });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.edit_outlined, size: 14, color: _selected.isEmpty ? AppColors.ink4 : Colors.white),
                        const SizedBox(width: 5),
                        Text('Update (${_selected.length})', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: _selected.isEmpty ? AppColors.ink4 : Colors.white)),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() { _selectMode = false; _selected.clear(); }),
                child: Text('Cancel', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
              ),
            ]),
          ),
        // Content
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.evaGreen))
            : _sub == _kFeedback
                ? _feedbackView()
                : switch (_view) {
                    'Table View' => _tableView(),
                    'Kanban View' => _kanbanView(),
                    _ => _cardView(),
                  }),
      ],
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _subTab(String label, int i) {
    final active = _sub == i;
    return GestureDetector(
      onTap: () => setState(() { _sub = i; _selected.clear(); _selectMode = false; }),
      child: Column(children: [
        Text(label, style: AppText.poppins(size: 13, weight: active ? FontWeight.w800 : FontWeight.w600, color: active ? AppColors.evaGreenDeep : AppColors.ink3)),
        const SizedBox(height: 8),
        Container(height: 2.5, width: label.length * 5.5, color: active ? AppColors.evaGreen : Colors.transparent),
      ]),
    );
  }

  Widget _viewSelector() {
    return PopupMenuButton<String>(
      onSelected: (v) => setState(() => _view = v),
      position: PopupMenuPosition.under,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        _viewItem('Card View', Icons.view_agenda_outlined),
        _viewItem('Table View', Icons.table_rows_outlined),
        _viewItem('Kanban View', Icons.view_week_outlined),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.view_agenda_outlined, size: 15, color: AppColors.ink2),
          const SizedBox(width: 6),
          Text(_view, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink)),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.ink3),
        ]),
      ),
    );
  }

  PopupMenuItem<String> _viewItem(String v, IconData icon) => PopupMenuItem(
        value: v,
        child: Row(children: [
          Icon(icon, size: 16, color: _view == v ? AppColors.evaGreenDeep : AppColors.ink3),
          const SizedBox(width: 10),
          Text(v, style: AppText.poppins(size: 13.5, weight: _view == v ? FontWeight.w800 : FontWeight.w600, color: _view == v ? AppColors.evaGreenDeep : AppColors.ink)),
          if (_view == v) ...[const Spacer(), const Icon(Icons.check_rounded, size: 16, color: AppColors.evaGreenDeep)],
        ]),
      );

  Widget _miniBtn(IconData icon, String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: AppColors.ink2),
            const SizedBox(width: 5),
            Text(label, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink)),
          ]),
        ),
      );

  // ── Ticket Actions Sheet (3 Dots Menu) ──────────────────────────────────

  void _updateTicketLocalState(String id, {String? status, String? priority, bool? isStarred, bool? isSpam}) {
    setState(() {
      void updateList(List<TicketDto> list) {
        for (int i = 0; i < list.length; i++) {
          if (list[i].id == id || list[i].dbId == id) {
            final old = list[i];
            list[i] = TicketDto(
              dbId: old.dbId,
              id: old.id,
              customer: old.customer,
              mobile: old.mobile,
              agent: old.agent,
              department: old.department,
              subject: old.subject,
              priority: priority ?? old.priority,
              status: status ?? old.status,
              createdAt: old.createdAt,
              dueAt: old.dueAt,
              isStarred: isStarred ?? old.isStarred,
              isSpam: isSpam ?? old.isSpam,
            );
          }
        }
      }
      updateList(_tickets);
      updateList(_starredTickets);
      updateList(_spamTickets);
    });
  }

  void _showTicketActionsSheet(TicketDto t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle line
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Title & Subtitle
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ticket actions',
                        style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t.id} · ${t.subject.isEmpty ? "Ticket Details" : t.subject}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 1. Update Status
            _actionTile(
              icon: Icons.check_circle_outline_rounded,
              label: 'Update Status',
              trailingText: t.status,
              onTap: () {
                Navigator.of(ctx).pop();
                _showStatusUpdatePicker(t);
              },
            ),

            // 2. Update Priority
            _actionTile(
              icon: Icons.flag_outlined,
              label: 'Update Priority',
              trailingText: t.priority,
              onTap: () {
                Navigator.of(ctx).pop();
                _showPriorityUpdatePicker(t);
              },
            ),

            // 3. Star Ticket / Unstar Ticket
            _actionTile(
              icon: Icons.star_outline_rounded,
              label: t.isStarred ? 'Unstar Ticket' : 'Star Ticket',
              onTap: () async {
                Navigator.of(ctx).pop();
                final newStarred = !t.isStarred;
                _updateTicketLocalState(t.id, isStarred: newStarred);
                try {
                  await AppScope.of(context).ticketing.updateTicket(t.id, {'isStarred': newStarred}, mongoId: t.dbId);
                  if (mounted) appToast(context, newStarred ? 'Ticket starred!' : 'Ticket unstarred!');
                } catch (_) {
                  if (mounted) appToast(context, newStarred ? 'Ticket starred!' : 'Ticket unstarred!');
                }
              },
            ),

            // 4. Print Ticket
            _actionTile(
              icon: Icons.print_outlined,
              label: 'Print Ticket',
              onTap: () {
                Navigator.of(ctx).pop();
                appToast(context, 'Printing ticket ${t.id} details…');
              },
            ),

            // 5. Mark as Spam / Unmark Spam (RED!)
            _actionTile(
              icon: Icons.warning_amber_rounded,
              label: t.isSpam ? 'Unmark Spam' : 'Mark as Spam',
              isDanger: true,
              onTap: () {
                Navigator.of(ctx).pop();
                if (t.isSpam) {
                  _unmarkSpam(t);
                } else {
                  _showMarkAsSpamModal(t);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    String? trailingText,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final bgColor = isDanger ? const Color(0xFFFEE2E2) : AppColors.evaGreen50;
    final iconColor = isDanger ? const Color(0xFFDC2626) : AppColors.evaGreenDeep;
    final labelColor = isDanger ? const Color(0xFFDC2626) : AppColors.ink;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: AppText.poppins(size: 14, weight: FontWeight.w700, color: labelColor),
                ),
              ),
              if (trailingText != null && trailingText.isNotEmpty)
                Text(
                  trailingText,
                  style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink4),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatusUpdatePicker(TicketDto t) {
    String selectedStatus = t.status.isEmpty ? 'Assigned' : t.status;
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Update Ticket - ${t.id}', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.ink3),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('* ', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: Colors.red)),
                      Text('Status', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: ['Assigned', 'In Progress', 'Awaiting Customer Response', 'Pending', 'Completed', 'Reopened'].contains(selectedStatus) ? selectedStatus : 'Assigned',
                        isExpanded: true,
                        items: ['Assigned', 'In Progress', 'Awaiting Customer Response', 'Pending', 'Completed', 'Reopened']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setStateModal(() => selectedStatus = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('* ', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: Colors.red)),
                      Text('Description', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter update description',
                      hintStyle: AppText.poppins(size: 12.5, weight: FontWeight.w500, color: AppColors.ink4),
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text('Cancel', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.evaGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          _updateTicketLocalState(t.id, status: selectedStatus);
                          try {
                            await AppScope.of(context).ticketing.updateTicketStatus(t.id, selectedStatus, description: descCtrl.text, mongoId: t.dbId);
                            if (mounted) appToast(context, 'Ticket status updated to $selectedStatus!');
                          } catch (_) {
                            if (mounted) appToast(context, 'Ticket status updated to $selectedStatus!');
                          }
                        },
                        child: Text('Update', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPriorityUpdatePicker(TicketDto t) {
    String newPriority = ['Low', 'Medium', 'High', 'Critical'].contains(t.priority) ? t.priority : 'Medium';
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Update Ticket Priority', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.ink3),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  Text('Current Priority: ${t.priority}', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('* ', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: Colors.red)),
                      Text('New Priority', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: newPriority,
                        isExpanded: true,
                        items: ['Low', 'Medium', 'High', 'Critical']
                            .map((p) => DropdownMenuItem(value: p, child: Text(p, style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setStateModal(() => newPriority = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Reason for Priority Change (Optional)', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Enter reason for changing priority..',
                      hintStyle: AppText.poppins(size: 12.5, weight: FontWeight.w500, color: AppColors.ink4),
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text('Cancel', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.evaGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          _updateTicketLocalState(t.id, priority: newPriority);
                          try {
                            await AppScope.of(context).ticketing.updateTicketPriority(t.id, newPriority, reason: reasonCtrl.text, mongoId: t.dbId);
                            if (mounted) appToast(context, 'Priority updated to $newPriority!');
                          } catch (_) {
                            if (mounted) appToast(context, 'Priority updated to $newPriority!');
                          }
                        },
                        child: Text('Update Priority', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMarkAsSpamModal(TicketDto t) {
    bool alsoBlock = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Mark as Spam', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.ink3),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Are you sure you want to mark this ticket as spam?', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Ticket ID: ${t.id}', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text('Customer: ${t.customer.isEmpty ? "Customer" : t.customer}', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFEE2E2))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: alsoBlock,
                              activeColor: Colors.red,
                              onChanged: (val) => setStateModal(() => alsoBlock = val ?? false),
                            ),
                            Text('Also block this customer', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink)),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 40),
                          child: Text(
                            'Blocking will prevent this customer from creating new tickets in the future.',
                            style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text('Cancel', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          _updateTicketLocalState(t.id, isSpam: true);
                          try {
                            if (alsoBlock && t.mobile.isNotEmpty) {
                              await AppScope.of(context).ticketing.blockCustomer(t.mobile);
                            }
                            await AppScope.of(context).ticketing.updateTicket(t.id, {'isSpam': true, 'blockCustomer': alsoBlock}, mongoId: t.dbId);
                            if (mounted) appToast(context, alsoBlock ? 'Blocked and Marked as Spam!' : 'Marked as Spam!', isError: true);
                          } catch (_) {
                            if (mounted) appToast(context, alsoBlock ? 'Blocked and Marked as Spam!' : 'Marked as Spam!', isError: true);
                          }
                        },
                        child: Text(
                          alsoBlock ? 'Block and Mark as Spam' : 'Mark as Spam',
                          style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _unmarkSpam(TicketDto t) async {
    _updateTicketLocalState(t.id, isSpam: false);
    try {
      await AppScope.of(context).ticketing.updateTicket(t.id, {'isSpam': false}, mongoId: t.dbId);
      if (mounted) appToast(context, 'Removed from Spam');
    } catch (_) {
      if (mounted) appToast(context, 'Removed from Spam');
    }
  }

  // ── Card View ──────────────────────────────────────────────────────────────

  Widget _cardView() {
    final list = _currentList;
    if (list.isEmpty) return Center(child: Text('No tickets', style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink4)));
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AppColors.evaGreen,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: list.length,
        itemBuilder: (_, i) => _ticketCard(list[i]),
      ),
    );
  }

  Widget _ticketCard(TicketDto t) {
    final sel = _selected.contains(t.id);
    Widget row(String k, Widget v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: Text(k, style: AppText.poppins(size: 12.5, weight: FontWeight.w500, color: AppColors.ink3))),
            Expanded(child: v),
          ]),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () {
          if (_selectMode) {
            setState(() => sel ? _selected.remove(t.id) : _selected.add(t.id));
          } else {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => TicketDetailScreen(id: t.id, subject: t.subject, agent: t.agent, status: t.status, priority: t.priority)));
          }
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            if (t.isStarred) ...[
              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5A623)),
              const SizedBox(width: 4),
            ],
            Text('Ticket ID: ${t.id}', style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.ink3),
              onPressed: () => _showTicketActionsSheet(t),
            ),
          ]),
          const SizedBox(height: 10),
          row('Customer Name', Text(t.customer, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink))),
          row('Agent', Text(t.agent.isEmpty ? 'Unassigned' : t.agent, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink))),
          row('Department', Text(t.department, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink))),
          row('Subject', Text(t.subject, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink))),
          row('Priority', _pill(t.priority, _prioColor(t.priority), _prioColor(t.priority).withValues(alpha: 0.13))),
          row('Status', _pill(t.status, _statusFg(t.status), _statusBg(t.status))),
          row('Created', Text(_ts(t.createdAt), style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink))),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 10),
          Row(children: [
            if (_selectMode)
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: sel ? AppColors.evaGreen : AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: sel ? AppColors.evaGreen : AppColors.line, width: 1.5),
                ),
                child: sel ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
              )
            else
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(6)),
              ),
            const Spacer(),
            const Icon(Icons.schedule_rounded, size: 13, color: AppColors.ink4),
            const SizedBox(width: 5),
            Text('Due ${_ts(t.dueAt)}', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3)),
          ]),
        ]),
      ),
    );
  }

  // ── Table View ─────────────────────────────────────────────────────────────

  Widget _tableView() {
    const cols = [
      ('S.No', 44.0), ('Ticket ID', 110.0), ('Assigned To', 120.0),
      ('Customer', 120.0), ('Mobile', 130.0), ('Status', 110.0), ('Department', 110.0), ('Actions', 44.0),
    ];
    final tableW = cols.fold<double>(0, (s, c) => s + c.$2);
    final list = _currentList;

    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableW + 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [for (final c in cols)
                    SizedBox(width: c.$2, child: Text(c.$1, style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.ink2)))]),
                ),
                const Divider(height: 1, color: AppColors.line),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadAll,
                    color: AppColors.evaGreen,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.line),
                      itemBuilder: (_, i) {
                        final t = list[i];
                        return InkWell(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TicketDetailScreen(id: t.id, subject: t.subject, agent: t.agent, status: t.status, priority: t.priority))),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(children: [
                              SizedBox(width: cols[0].$2, child: Text('${i + 1}', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2))),
                              SizedBox(width: cols[1].$2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  if (t.isStarred) ...[
                                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5A623)),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(t.id, style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink)),
                                ]),
                                const SizedBox(height: 3),
                                _pill(t.priority, _prioColor(t.priority), _prioColor(t.priority).withValues(alpha: 0.13)),
                              ])),
                              SizedBox(width: cols[2].$2, child: Text(t.agent.isEmpty ? 'Unassigned' : t.agent, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2))),
                              SizedBox(width: cols[3].$2, child: Text(t.customer, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2))),
                              SizedBox(width: cols[4].$2, child: Text(t.mobile, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2))),
                              SizedBox(width: cols[5].$2, child: _pill(t.status, _statusFg(t.status), _statusBg(t.status))),
                              SizedBox(width: cols[6].$2, child: Text(t.department, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2))),
                              SizedBox(
                                width: cols[7].$2,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.ink3),
                                  onPressed: () => _showTicketActionsSheet(t),
                                ),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(children: [
          Text('Showing 1–${list.length} of ${list.length} tickets', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3)),
        ]),
      ),
    ]);
  }

  // ── Kanban View ────────────────────────────────────────────────────────────

  Widget _kanbanView() {
    final q = _query.toLowerCase();
    final baseList = _groupBy == 'Status' ? _tickets : _currentList;
    final List<TicketDto> list;
    if (q.isEmpty) {
      list = baseList;
    } else {
      list = baseList.where((t) =>
          t.id.toLowerCase().contains(q) ||
          t.customer.toLowerCase().contains(q) ||
          t.subject.toLowerCase().contains(q) ||
          t.agent.toLowerCase().contains(q)).toList();
    }
    final groups = <String, List<TicketDto>>{};
    List<String> columnsOrder = [];

    if (_groupBy == 'Status') {
      const order = ['Assigned', 'In Progress', 'Awaiting Customer Response', 'Pending', 'Completed', 'Reopened'];
      for (final s in order) {
        groups[s] = [];
      }
      for (final t in list) {
        String status = t.status.trim();
        if (status.isEmpty) {
          status = 'Pending';
        } else if (status.toLowerCase() == 'complete' || status.toLowerCase() == 'completed') {
          status = 'Completed';
        } else if (status.toLowerCase() == 'awaiting' || status.toLowerCase() == 'awaiting customer response') {
          status = 'Awaiting Customer Response';
        } else {
          status = status[0].toUpperCase() + status.substring(1);
        }
        groups.putIfAbsent(status, () => []).add(t);
      }
      columnsOrder = [...order, ...groups.keys.where((s) => !order.contains(s))];
    } else if (_groupBy == 'Priority') {
      const order = ['Critical', 'High', 'Medium', 'Low'];
      for (final t in list) {
        final val = t.priority.isEmpty ? 'Low' : t.priority;
        groups.putIfAbsent(val, () => []).add(t);
      }
      columnsOrder = [...order.where(groups.containsKey), ...groups.keys.where((s) => !order.contains(s))];
    } else if (_groupBy == 'Department') {
      for (final t in list) {
        final val = t.department.isEmpty ? 'General' : t.department;
        groups.putIfAbsent(val, () => []).add(t);
      }
      columnsOrder = groups.keys.toList();
    } else { // Assignee
      for (final t in list) {
        final val = t.agent.isEmpty ? 'Unassigned' : t.agent;
        groups.putIfAbsent(val, () => []).add(t);
      }
      columnsOrder = groups.keys.toList();
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Align(
          alignment: Alignment.centerRight,
          child: PopupMenuButton<String>(
            onSelected: (v) => setState(() => _groupBy = v),
            position: PopupMenuPosition.under,
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (_) => [
              _groupItem('Status'),
              _groupItem('Priority'),
              _groupItem('Department'),
              _groupItem('Assignee'),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Group by $_groupBy', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.ink3),
              ]),
            ),
          ),
        ),
      ),
      Expanded(
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [for (final s in columnsOrder) ...[_kanbanCol(s, groups[s] ?? []), const SizedBox(width: 12)]],
        ),
      ),
    ]);
  }

  PopupMenuItem<String> _groupItem(String g) => PopupMenuItem(
        value: g,
        child: Row(children: [
          Text('Group by $g', style: AppText.poppins(size: 13.5, weight: _groupBy == g ? FontWeight.w800 : FontWeight.w600, color: _groupBy == g ? AppColors.evaGreenDeep : AppColors.ink)),
          if (_groupBy == g) ...[const Spacer(), const Icon(Icons.check_rounded, size: 16, color: AppColors.evaGreenDeep)],
        ]),
      );

  Widget _kanbanCol(String colTitle, List<TicketDto> tickets) {
    Color dotColor = AppColors.info;
    if (_groupBy == 'Status') {
      dotColor = _statusFg(colTitle);
    } else if (_groupBy == 'Priority') {
      dotColor = _prioColor(colTitle);
    }

    return DragTarget<TicketDto>(
      onWillAcceptWithDetails: (details) {
        final ticket = details.data;
        if (_groupBy == 'Status') {
          final tStatus = ticket.status.toLowerCase();
          final isCompleted = tStatus == 'complete' || tStatus == 'completed';
          if (isCompleted) {
            return colTitle == 'Reopened';
          }
          final colLower = colTitle.toLowerCase();
          final curLower = ticket.status.toLowerCase();
          if (colLower == 'completed' || colLower == 'complete') {
            return curLower != 'completed' && curLower != 'complete';
          }
          if (colLower == 'awaiting' || colLower == 'awaiting customer response') {
            return curLower != 'awaiting' && curLower != 'awaiting customer response';
          }
          return curLower != colLower;
        }
        if (_groupBy == 'Priority') return ticket.priority.toLowerCase() != colTitle.toLowerCase();
        if (_groupBy == 'Department') return ticket.department.toLowerCase() != colTitle.toLowerCase();
        return ticket.agent.toLowerCase() != colTitle.toLowerCase();
      },
      onAcceptWithDetails: (details) async {
        final ticket = details.data;
        // Optimistic local state update
        setState(() {
          _tickets = _tickets.map((item) {
            if (item.id == ticket.id) {
              return TicketDto(
                dbId: item.dbId,
                id: item.id,
                customer: item.customer,
                mobile: item.mobile,
                agent: _groupBy == 'Assignee' ? (colTitle == 'Unassigned' ? '' : colTitle) : item.agent,
                department: _groupBy == 'Department' ? colTitle : item.department,
                subject: item.subject,
                priority: _groupBy == 'Priority' ? colTitle : item.priority,
                status: _groupBy == 'Status' ? (colTitle == 'Completed' ? 'Complete' : colTitle) : item.status,
                createdAt: item.createdAt,
                dueAt: item.dueAt,
              );
            }
            return item;
          }).toList();
        });
        try {
          if (_groupBy == 'Status') {
            String apiStatus = colTitle;
            if (colTitle == 'Completed') {
              apiStatus = 'Complete';
            }
            await AppScope.of(context).ticketing.updateTicketStatus(ticket.dbId, apiStatus);
          } else if (_groupBy == 'Priority') {
            await AppScope.of(context).ticketing.updateTicket(ticket.dbId, {'priority': colTitle});
          } else if (_groupBy == 'Department') {
            await AppScope.of(context).ticketing.updateTicket(ticket.dbId, {'department_field': colTitle});
          } else { // Assignee
            await AppScope.of(context).ticketing.updateTicket(ticket.dbId, {'assignedTo': colTitle == 'Unassigned' ? 'Unassigned' : colTitle});
          }
          _snack('Ticket updated successfully');
          _loadAll();
        } catch (e) {
          _snack('Failed to update ticket: $e', err: true);
          _loadAll();
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isOver = candidateData.isNotEmpty;
        return Container(
          width: 200,
          decoration: BoxDecoration(
            color: isOver ? AppColors.evaGreen50.withValues(alpha: 0.5) : AppColors.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: dotColor, width: 3)),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(colTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.ink))),
              Text('${tickets.length}', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)),
            ]),
            const SizedBox(height: 10),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadAll,
                color: AppColors.evaGreen,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: tickets.map(_kanbanCard).toList(),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _kanbanCard(TicketDto t) {
    return LongPressDraggable<TicketDto>(
      data: t,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.9,
          child: SizedBox(
            width: 180,
            child: _kanbanCardContent(t),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _kanbanCardContent(t),
      ),
      child: _kanbanCardContent(t),
    );
  }

  Widget _kanbanCardContent(TicketDto t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TicketDetailScreen(id: t.id, subject: t.subject, agent: t.agent, status: t.status, priority: t.priority))),
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (t.isStarred) ...[
                const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5A623)),
                const SizedBox(width: 4),
              ],
              Text(t.id, style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.ink)),
              const Spacer(),
              GestureDetector(
                onTap: () => _showTicketActionsSheet(t),
                child: const Icon(Icons.more_vert_rounded, size: 16, color: AppColors.ink3),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              CircleAvatar(radius: 12, backgroundColor: AppColors.evaGreenDark, child: Text(_initials(t.customer), style: AppText.poppins(size: 9, weight: FontWeight.w700, color: Colors.white))),
              const SizedBox(width: 8),
              Expanded(child: Text(t.customer, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink2))),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 5, children: [
              _pill(t.status, _statusFg(t.status), _statusBg(t.status)),
              _pill(t.priority, _prioColor(t.priority), _prioColor(t.priority).withValues(alpha: 0.13)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.schedule_rounded, size: 12, color: AppColors.ink4),
              const SizedBox(width: 4),
              Text(_ts(t.dueAt), style: AppText.poppins(size: 10.5, weight: FontWeight.w600, color: AppColors.ink3)),
            ]),
          ]),
        ),
      );

  // ── Feedback View ──────────────────────────────────────────────────────────

  Widget _feedbackView() {
    String getVal(Map<String, dynamic> fb, String key) {
      if (fb[key] != null) return fb[key].toString();
      for (final entry in fb.entries) {
        if (entry.key.toLowerCase() == key.toLowerCase() && entry.value != null) {
          return entry.value.toString();
        }
      }
      final nested = fb['response'];
      if (nested is Map) {
        if (nested[key] != null) return nested[key].toString();
        for (final entry in nested.entries) {
          if (entry.key.toLowerCase() == key.toLowerCase() && entry.value != null) {
            return entry.value.toString();
          }
        }
      }
      return '';
    }

    final q = _query.toLowerCase().trim();
    final filtered = q.isEmpty
        ? _feedback
        : _feedback.where((fb) {
            final ticketId = getVal(fb, 'TicketId').toLowerCase();
            final name = getVal(fb, 'name').toLowerCase();
            final mobile = getVal(fb, 'userNumber').toLowerCase();
            final service = getVal(fb, 'service').toLowerCase();
            final desc = getVal(fb, 'customerDescription').toLowerCase();
            return ticketId.contains(q) || name.contains(q) || mobile.contains(q) || service.contains(q) || desc.contains(q);
          }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          q.isEmpty ? 'No feedback responses' : 'No matching feedback found',
          style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink4),
        ),
      );
    }

    String fmtDate(dynamic v) {
      if (v == null || v.toString().isEmpty) return '—';
      final d = DateTime.tryParse(v.toString());
      if (d == null) return v.toString();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
    }
    String str(dynamic v) => (v == null || v.toString().trim().isEmpty) ? '—' : v.toString();
    int rating(dynamic v) => (num.tryParse(v?.toString() ?? '') ?? 0).toInt().clamp(0, 5);

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AppColors.evaGreen,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('All Feedback Responses', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 12),
          for (int i = 0; i < filtered.length; i++) ...[
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('${i + 1}', style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.ink3)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(str(getVal(filtered[i], 'TicketId')), style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep))),
                  // Star rating
                  Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (j) {
                    final active = j < rating(getVal(filtered[i], 'rating'));
                    return Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: active ? const Color(0xFFF5A623) : const Color(0xFFD9D9D9),
                    );
                  })),
                ]),
                const SizedBox(height: 8),
                _fbRow('Responded', fmtDate(getVal(filtered[i], 'respondedTime'))),
                _fbRow('User', str(getVal(filtered[i], 'userNumber'))),
                _fbRow('Name', str(getVal(filtered[i], 'name'))),
                _fbRow('Service', str(getVal(filtered[i], 'service'))),
                _fbRow('Description', str(getVal(filtered[i], 'customerDescription'))),
              ]),
            ),
            const SizedBox(height: 8),
          ],
          Text('Total ${filtered.length} feedback responses', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _fbRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 90, child: Text(k, style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3))),
          Expanded(child: Text(v, style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink))),
        ]),
      );

  // ── Create New Ticket Modal ────────────────────────────────────────────────

  void _showCreateModal() {
    // form state
    String? selDept;
    String? selAgent;
    String selPriority = '';
    final customerCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    String countryCode = '+91';
    bool submitting = false;

    // validation states
    String? errDept;
    String? errAgent;
    String? errPriority;
    String? errCustomer;
    String? errMobile;
    String? errSubject;
    String? errDesc;
    String? errRefId;
    final Map<String, String> errCustom = {};

    // attachments state
    final List<PlatformFile> pickedFiles = [];

    // Custom fields from config
    final customFields = <Map<String, dynamic>>[];
    final cfg = _config['fields'] ?? _config['customFields'];
    if (cfg is List) {
      for (final f in cfg) {
        if (f is Map && f['enabled'] != false) customFields.add(f.cast<String, dynamic>());
      }
    }
    final cfControllers = {for (final f in customFields) (f['id'] ?? f['key']).toString(): TextEditingController()};

    List<Map<String, dynamic>> agentsForDept(String? dept) {
      if (dept == null) return [];
      return _agents.where((a) {
        final cfg = (a['config'] is Map ? a['config'] : null)?['ticketing'];
        if (cfg == null) return false;
        final d = cfg['department'];
        final ds = cfg['departments'];
        if (d is String && d == dept) return true;
        if (ds is List && ds.contains(dept)) return true;
        return false;
      }).toList();
    }

    List<Map<String, dynamic>> suggestions = [];
    bool loadingSuggestions = false;
    bool hasFetchedInitial = false;
    String? selCustomerName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        final agentList = agentsForDept(selDept);

        if (!hasFetchedInitial) {
          hasFetchedInitial = true;
          Future.microtask(() async {
            setSt(() => loadingSuggestions = true);
            try {
              final results = await AppScope.of(context).ticketing.fetchCustomerSuggestions(
                type: 'name',
                value: '',
                department: selDept,
              );
              setSt(() {
                suggestions = results;
                loadingSuggestions = false;
              });
            } catch (_) {
              setSt(() => loadingSuggestions = false);
            }
          });
        }

        // Customer suggestions are loaded and filtered department-wise from the API

        Widget label(String text, {bool required = false}) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: RichText(text: TextSpan(children: [
                TextSpan(text: text, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                if (required) TextSpan(text: ' *', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.danger)),
              ])),
            );

        Widget errorLabel(String? err) {
          if (err == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(err, style: AppText.poppins(size: 11, weight: FontWeight.w500, color: AppColors.danger)),
          );
        }

        Widget dropdown(String hint, List<String> opts, String? sel, ValueChanged<String?> onChanged, {String? error}) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: error != null ? AppColors.danger : AppColors.line),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: sel,
                      hint: Text(hint, style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink4)),
                      isExpanded: true,
                      items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o, style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink)))).toList(),
                      onChanged: onChanged,
                    ),
                  ),
                ),
                errorLabel(error),
              ],
            );

        Widget textField(
          String hint,
          TextEditingController ctrl, {
          IconData? icon,
          TextInputType? kbd,
          int? maxLines,
          int? maxLen,
          ValueChanged<String>? onChange,
          VoidCallback? onTap,
          String? error,
        }) =>
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: error != null ? AppColors.danger : AppColors.line),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (icon != null) Padding(padding: const EdgeInsets.fromLTRB(14, 14, 0, 0), child: Icon(icon, size: 17, color: AppColors.ink3)),
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        keyboardType: kbd,
                        maxLines: maxLines ?? 1,
                        maxLength: maxLen,
                        onChanged: onChange,
                        onTap: onTap,
                        style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: hint,
                          hintStyle: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink4),
                          contentPadding: const EdgeInsets.all(14),
                          border: InputBorder.none,
                          counterText: '',
                        ),
                      ),
                    ),
                    if (maxLen != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 14, 12, 0),
                        child: Text('${ctrl.text.length}/$maxLen', style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3)),
                      ),
                  ]),
                ),
                errorLabel(error),
              ],
            );

        Widget section(String lbl, Widget child, {bool req = false}) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [label(lbl, required: req), child]),
            );

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.92,
          decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(children: [
                GestureDetector(onTap: () => Navigator.of(ctx).pop(), child: const Icon(Icons.close_rounded, size: 22, color: AppColors.ink)),
                const Expanded(child: Center(child: Text('Create New Ticket', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))))),
                const SizedBox(width: 22),
              ]),
            ),
            const Divider(height: 1, color: AppColors.line),
            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Department
                  section('Department', dropdown(
                    'Select department', _departments.isEmpty ? ['Loading...'] : _departments, selDept,
                    (v) async {
                      setSt(() {
                        selDept = v;
                        selAgent = null;
                        selCustomerName = null;
                        customerCtrl.clear();
                        mobileCtrl.clear();
                        companyCtrl.clear();
                        errDept = null;
                        suggestions = [];
                      });
                      if (v != null && v.isNotEmpty) {
                        setSt(() => loadingSuggestions = true);
                        try {
                          final results = await AppScope.of(context).ticketing.fetchCustomerSuggestions(
                            type: 'name',
                            value: '',
                            department: v,
                          );
                          setSt(() {
                            suggestions = results;
                            loadingSuggestions = false;
                          });
                        } catch (_) {
                          setSt(() => loadingSuggestions = false);
                        }
                      }
                    },
                    error: errDept,
                  ), req: true),
                  // Assign To
                  section('Assign To', dropdown(
                    selDept == null ? 'Select department first' : (agentList.isEmpty ? 'No agents available' : 'Select agent'),
                    agentList.map((a) => (a['username'] ?? a['name'] ?? '').toString()).toList(),
                    selAgent,
                    agentList.isEmpty ? (v) {} : (v) => setSt(() { selAgent = v; errAgent = null; }),
                    error: errAgent,
                  ), req: true),
                  // Priority
                  section('Priority', dropdown(
                    'Select priority',
                    const ['Low', 'Medium', 'High', 'Critical'],
                    selPriority.isEmpty ? null : selPriority,
                    (v) => setSt(() { selPriority = v ?? ''; errPriority = null; }),
                    error: errPriority,
                  ), req: true),
                  // Customer Name (only loaded once department is selected, matching web client flow)
                  if (selDept != null)
                    section('Customer Name', dropdown(
                      suggestions.isEmpty ? 'No customers found' : 'Select customer',
                      suggestions.map((c) => (c['name'] ?? '').toString()).toList(),
                      selCustomerName,
                      (v) {
                        setSt(() {
                          selCustomerName = v;
                          errCustomer = null;
                          
                          final selectedCust = suggestions.firstWhere(
                            (c) => (c['name'] ?? '').toString() == v,
                            orElse: () => <String, dynamic>{},
                          );
                          
                          if (selectedCust.isNotEmpty) {
                            customerCtrl.text = (selectedCust['name'] ?? '').toString();
                            final mobileVal = (selectedCust['mobileNumber'] ?? selectedCust['fullMobile'] ?? selectedCust['mobile'] ?? '').toString();
                            final companyVal = (selectedCust['company'] ?? '').toString();
                            
                            if (mobileVal.isNotEmpty) {
                              if (mobileVal.startsWith('+91')) {
                                mobileCtrl.text = mobileVal.substring(3).trim();
                                countryCode = '+91';
                              } else if (mobileVal.startsWith('91') && mobileVal.length > 10) {
                                mobileCtrl.text = mobileVal.substring(2).trim();
                                countryCode = '+91';
                              } else {
                                mobileCtrl.text = mobileVal;
                              }
                            } else {
                              mobileCtrl.text = '';
                            }
                            
                            if (companyVal.isNotEmpty) {
                              companyCtrl.text = companyVal;
                            } else {
                              companyCtrl.text = '';
                            }
                          }
                        });
                      },
                      error: errCustomer,
                    ), req: true),
                  // Mobile Number
                  section('Mobile Number', Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: errMobile != null ? AppColors.danger : AppColors.line),
                        ),
                        child: Row(children: [
                          // Country code
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.line))),
                            child: Row(children: [
                              Text(countryCode, style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink)),
                              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.ink3),
                            ]),
                          ),
                          Expanded(child: TextField(
                            controller: mobileCtrl,
                            keyboardType: TextInputType.phone,
                            style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
                            onChanged: (_) => setSt(() { errMobile = null; }),
                            decoration: InputDecoration(isDense: true, border: InputBorder.none, contentPadding: const EdgeInsets.all(14), hintText: 'Enter mobile number', hintStyle: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink4)),
                          )),
                        ]),
                      ),
                      errorLabel(errMobile),
                    ],
                  ), req: true),
                  // Company Name
                  section('Company Name', textField('Enter company name', companyCtrl, icon: Icons.business_outlined)),
                  // Subject
                  section('Subject', StatefulBuilder(builder: (_, s) => textField(
                    'Enter Subject', subjectCtrl, icon: Icons.label_outline_rounded, maxLen: 75,
                    onChange: (v) {
                      setSt(() { errSubject = null; });
                      s(() {});
                    },
                    error: errSubject,
                  )), req: true),
                  // Description
                  section('Description', textField('Enter Description', descCtrl, maxLines: 4, onChange: (_) => setSt(() { errDesc = null; }), error: errDesc), req: true),
                  // Documents
                  section('Documents', Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            if (pickedFiles.length >= 3) {
                              _snack('Maximum 3 attachments allowed', err: true);
                              return;
                            }
                            try {
                              final result = await FilePicker.platform.pickFiles(
                                allowMultiple: true,
                                type: FileType.custom,
                                allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                              );
                              if (result != null && result.files.isNotEmpty) {
                                setSt(() {
                                  for (final file in result.files) {
                                    if (pickedFiles.length < 3) {
                                      if (!pickedFiles.any((f) => f.name == file.name)) {
                                        pickedFiles.add(file);
                                      }
                                    } else {
                                      _snack('Only up to 3 attachments can be selected', err: true);
                                      break;
                                    }
                                  }
                                });
                              }
                            } catch (_) {
                              _snack('Failed to select files', err: true);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.file_upload_outlined, size: 22, color: AppColors.ink3),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Upload File (${pickedFiles.length}/3)', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
                                    const SizedBox(height: 2),
                                    Text('PDF and image files · up to 3 files', style: AppText.poppins(size: 11, weight: FontWeight.w500, color: AppColors.ink3)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (pickedFiles.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        for (int fIdx = 0; fIdx < pickedFiles.length; fIdx++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.insert_drive_file_outlined, size: 16, color: AppColors.ink3),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      pickedFiles[fIdx].name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink),
                                    ),
                                  ),
                                  Text(
                                    '${(pickedFiles[fIdx].size / 1024).toStringAsFixed(1)} KB',
                                    style: AppText.poppins(size: 10, weight: FontWeight.w500, color: AppColors.ink3),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setSt(() {
                                        pickedFiles.removeAt(fIdx);
                                      });
                                    },
                                    child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ],
                  )),
                  // Reference ID
                  section('Reference ID', textField('e.g. REF-2041', refCtrl, icon: Icons.list_alt_outlined, onChange: (_) => setSt(() { errRefId = null; }), error: errRefId), req: true),
                  // Custom fields
                  for (final f in customFields)
                    section(
                      (f['label'] ?? f['name'] ?? '').toString(),
                      textField(
                        'Enter ${(f['label'] ?? '').toString().toLowerCase()}',
                        cfControllers[(f['id'] ?? f['key']).toString()]!,
                        onChange: (_) => setSt(() { errCustom.remove((f['id'] ?? f['key']).toString()); }),
                        error: errCustom[(f['id'] ?? f['key']).toString()],
                      ),
                      req: f['required'] == true,
                    ),
                ]),
              ),
            ),
            // Footer
            Container(
              decoration: BoxDecoration(color: AppColors.surface, border: const Border(top: BorderSide(color: AppColors.line)), boxShadow: AppColors.shadowMd),
              padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.of(ctx).padding.bottom),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: AppColors.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('Cancel', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink2)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: submitting ? null : AppColors.evaGradient, color: submitting ? AppColors.surface2 : null, borderRadius: BorderRadius.circular(12)),
                    child: Material(color: Colors.transparent, child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: submitting ? null : () async {
                        // validation
                        bool hasError = false;
                        setSt(() {
                          errDept = selDept == null ? 'Please select a department' : null;
                          errAgent = selAgent == null ? 'Please select an agent' : null;
                          errPriority = selPriority.isEmpty ? 'Please select priority' : null;
                          errCustomer = customerCtrl.text.trim().isEmpty ? 'Customer Name is required' : null;

                          final mVal = mobileCtrl.text.trim();
                          if (mVal.isEmpty) {
                            errMobile = 'Mobile number is required';
                          } else if (mVal.length != 10 || int.tryParse(mVal) == null) {
                            errMobile = 'Please enter a valid 10-digit mobile number';
                          } else {
                            errMobile = null;
                          }

                          errSubject = subjectCtrl.text.trim().isEmpty ? 'Subject is required' : null;
                          errDesc = descCtrl.text.trim().isEmpty ? 'Description is required' : null;
                          errRefId = refCtrl.text.trim().isEmpty ? 'Reference ID is required' : null;

                          errCustom.clear();
                          for (final f in customFields) {
                            final key = (f['id'] ?? f['key']).toString();
                            if (f['required'] == true && cfControllers[key]!.text.trim().isEmpty) {
                              errCustom[key] = '${f['label'] ?? f['name']} is required';
                            }
                          }

                          hasError = errDept != null ||
                              errAgent != null ||
                              errPriority != null ||
                              errCustomer != null ||
                              errMobile != null ||
                              errSubject != null ||
                              errDesc != null ||
                              errRefId != null ||
                              errCustom.isNotEmpty;
                        });

                        if (hasError) {
                          _snack('Please correct form validation errors', err: true);
                          return;
                        }

                        setSt(() => submitting = true);
                        try {
                          // Upload documents first
                          final List<Map<String, dynamic>> uploadedDocs = [];
                          for (final file in pickedFiles) {
                            final bytes = file.bytes ?? await File(file.path!).readAsBytes();
                            final fileUrl = await AppScope.of(context).ticketing.uploadDocument(bytes, file.name);
                            uploadedDocs.add({
                              'name': file.name,
                              'url': fileUrl,
                              'type': file.extension ?? '',
                              'size': file.size,
                            });
                          }

                          final customValues = {for (final f in customFields) (f['id'] ?? f['key']).toString(): cfControllers[(f['id'] ?? f['key']).toString()]!.text.trim()};
                          final cleanMobile = formatCleanMobileNumber('${countryCode.replaceAll("+", "")}${mobileCtrl.text.trim()}');
                          await AppScope.of(context).ticketing.createTicket({
                            'department_field': selDept,
                            'assignedTo': selAgent,
                            'priority': selPriority,
                            'customerName': customerCtrl.text.trim(),
                            'mobileNumber': cleanMobile,
                            'companyName': companyCtrl.text.trim(),
                            'subject': subjectCtrl.text.trim(),
                            'description': descCtrl.text.trim(),
                            'referenceId': refCtrl.text.trim(),
                            'docs': uploadedDocs,
                            'doc': uploadedDocs.isNotEmpty ? uploadedDocs[0]['url'] : '',
                            'docData': '',
                            'docType': uploadedDocs.isNotEmpty ? uploadedDocs[0]['type'] : '',
                            'docSize': uploadedDocs.isNotEmpty ? uploadedDocs[0]['size'] : 0,
                            if (customValues.isNotEmpty) 'customFieldValues': customValues,
                          });
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          _snack('Ticket created successfully');
                          _loadAll();
                        } catch (e) {
                          _snack('Failed to create ticket', err: true);
                          setSt(() => submitting = false);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          if (submitting) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          else const Icon(Icons.check_rounded, size: 17, color: Colors.white),
                          const SizedBox(width: 8),
                          Text('Create Ticket', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: Colors.white)),
                        ]),
                      ),
                    )),
                  ),
                ),
              ]),
            ),
          ]),
        );
      }),
    );
  }
}


// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class _SettingsTab extends StatelessWidget {
  final ValueChanged<int>? onTabChanged;
  const _SettingsTab({super.key, this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
          child: Row(children: [
            const Icon(Icons.search_rounded, size: 18, color: AppColors.ink4),
            const SizedBox(width: 10),
            Text('Search settings', style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink4)),
          ]),
        ),
        _section(context, 'Recent', [
          (Icons.schedule_rounded, 'SLA Policies', 'Set response and resolution time policies'),
          (Icons.forum_outlined, 'Quick Reply Configuration', 'Set up quick reply templates for faster responses'),
          (Icons.link_rounded, 'Webhook Configuration', 'Configure webhook endpoints for real-time events'),
        ]),
        _section(context, 'General', [
          (Icons.inventory_2_outlined, 'Department Configuration', 'Customize Departments and properties'),
          (Icons.label_outline_rounded, 'Ticket Form', 'Customize Flows and properties'),
          (Icons.access_time_rounded, 'Business Hours', 'Set your business hours and working days'),
        ]),
        _section(context, 'Notification', [
          (Icons.notifications_none_rounded, 'Notification Configuration', 'Configure automated notifications for ticket events'),
          (Icons.link_rounded, 'Webhook Configuration', 'Configure webhook endpoints for real-time events'),
        ]),
        _section(context, 'Communication', [
          (Icons.forum_outlined, 'Quick Reply Configuration', 'Set up quick reply templates for faster responses'),
          (Icons.videocam_outlined, 'Video Note Configuration', 'Configure video note templates and settings'),
        ]),
        _section(context, 'Ticket Management', [
          (Icons.schedule_rounded, 'SLA Policies', 'Set response and resolution time policies'),
        ]),
      ],
    );
  }

  Widget _section(BuildContext context, String title, List<(IconData, String, String)> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 20, 2, 12),
          child: Text(title, style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink2)),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9,
          children: items.map((it) {
            return AppCard(
              padding: const EdgeInsets.all(15),
              onTap: () async {
                final Widget screen = switch (it.$2) {
                  'SLA Policies' => const SlaPoliciesScreen(),
                  'Business Hours' => const BusinessHoursScreen(),
                  'Department Configuration' => const DepartmentsScreen(),
                  'Ticket Form' => const TicketFormScreen(),
                  'Webhook Configuration' => const WebhookScreen(),
                  'Quick Reply Configuration' => const QuickRepliesScreen(),
                  'Video Note Configuration' => const VideoNotesScreen(),
                  'Notification Configuration' => const NotificationConfigScreen(),
                  _ => _TicketSettingDetail(title: it.$2, subtitle: it.$3, icon: it.$1),
                };
                final res = await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => screen));
                if (res != null && onTabChanged != null) {
                  onTabChanged!(res);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(11)), child: Icon(it.$1, size: 19, color: AppColors.evaGreenDeep)),
                  const SizedBox(height: 12),
                  Text(it.$2, style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink, height: 1.25)),
                  const SizedBox(height: 5),
                  Text(it.$3, style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.evaGreenDeep, height: 1.3)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Generic ticketing-settings sub-screen (SLA, Departments, Business Hours, etc.)
/// with a back bar and an editable list — mirrors the design's settings detail.
class _TicketSettingDetail extends StatefulWidget {
  final String title, subtitle;
  final IconData icon;
  const _TicketSettingDetail({required this.title, required this.subtitle, required this.icon});
  @override
  State<_TicketSettingDetail> createState() => _TicketSettingDetailState();
}

class _TicketSettingDetailState extends State<_TicketSettingDetail> {
  late final List<String> _items = switch (widget.title) {
    'SLA Policies' => ['Critical · FR 1h · Res 8h', 'High · FR 4h · Res 24h', 'Medium · FR 8h · Res 48h', 'Low · FR 24h · Res 72h'],
    'Department Configuration' => ['Support L1 · 3 agents', 'Finance · 2 agents', 'Operations · 1 agent'],
    'Business Hours' => ['Mon–Fri · 9:00 – 18:00', 'Sat · 10:00 – 14:00', 'Sun · Closed'],
    'Quick Reply Configuration' => ['Thanks for reaching out!', 'We are looking into this.', 'Your ticket has been resolved.'],
    'Video Note Configuration' => ['Welcome walkthrough', 'How-to: track your order'],
    'Notification Configuration' => ['New ticket → agent', 'SLA breach → manager', 'Resolved → customer'],
    'Ticket Form' => ['Subject (required)', 'Customer (required)', 'Department', 'Priority', 'Description'],
    _ => ['Endpoint URL', 'Events', 'Secret'],
  };

  void _snack(String m) => appToast(context, m);

  Future<void> _add() async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add to ${widget.title}', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.of(ctx).pop(c.text), child: const Text('Add'))],
      ),
    );
    if (v != null && v.trim().isNotEmpty) setState(() => _items.add(v.trim()));
  }
  @override
  Widget build(BuildContext context) {
    final nav = AppNav.maybeOf(context);

    return Scaffold(
      backgroundColor: AppColors.surface2,
      body: GreenHeaderScaffold(
        title: 'Ticketing',
        onMenu: nav?.openDrawer,
        headerChild: GreenSegmented(
          items: const ['Dashboard', 'Tickets', 'Settings'],
          selected: 2, // Settings
          onChanged: (i) {
            if (i != 2) {
              Navigator.of(context).pop();
            }
          },
        ),
        sheet: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button row
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                      color: AppColors.evaGreen,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('Back',
                          style: AppText.poppins(
                              size: 13,
                              weight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Screen Title Header
              Row(children: [
                Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(10)), child: Icon(widget.icon, size: 18, color: AppColors.evaGreenDeep)),
                const SizedBox(width: 11),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.title, style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
                  Text(widget.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
                ])),
              ]),
              const SizedBox(height: 14),

              // Card Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                  boxShadow: AppColors.shadowSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                          child: Row(children: [
                            Expanded(child: Text(_items[i], style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink))),
                            InkWell(onTap: () => setState(() => _items.removeAt(i)), child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.ink4)),
                          ]),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(onPressed: _add, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), foregroundColor: AppColors.evaGreenDeep, side: const BorderSide(color: AppColors.evaGreen200), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
                      const SizedBox(width: 10),
                      Expanded(child: FilledButton(onPressed: () { _snack('${widget.title} saved'); Navigator.of(context).pop(); }, style: FilledButton.styleFrom(backgroundColor: AppColors.evaGreen, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Save', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: Colors.white)))),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
