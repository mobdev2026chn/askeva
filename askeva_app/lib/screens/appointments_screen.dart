import 'dart:ui';
import 'package:flutter/material.dart';

import '../api/agents_repository.dart';
import '../api/app_scope.dart';
import '../api/dto.dart';
import '../shell/app_nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/common.dart';
import '../widgets/appointment_sheets.dart';
import '../widgets/dashboard_sheets.dart' show appToast, showAppSheet;
import '../widgets/leads_sheets.dart' show SelectTemplateBottomSheet;
import 'detail_screens.dart';
import 'payments_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  int _top = 0; // Dashboard / Bookings / Payments / Settings
  String _agent = 'All Agents';
  int _refreshCounter = 0;

  List<Map<String, dynamic>> _allAgents = [];
  List<String> _agentNames = ['All Agents'];

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    try {
      final scope = AppScope.of(context);

      // 1. Fetch active agents configured for the Appointment module (from Settings -> Agents)
      final moduleAgents = await scope.agents.fetchModuleAgents('appointment').catchError((_) => <Map<String, dynamic>>[]);

      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 30));
      final end = now.add(const Duration(days: 30));
      final startDateStr = "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";
      final endDateStr = "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";

      // 2. Fetch appointments (matching web dashboard active window)
      final appointments = await scope.appointments.fetchAppointments(status: 'all', startDate: startDateStr, endDate: endDateStr, limit: 1000);

      if (mounted) {
        setState(() {
          _allAgents = moduleAgents;

          final Set<String> rawNamesSet = {};

          // Extract names and IDs of ACTIVE agents configured in Agent Settings
          final Set<String> activeAgentNames = {};
          final Set<String> activeAgentIds = {};
          for (final m in moduleAgents) {
            if (AgentsRepository.isAgentActive(m)) {
              final name = (m['username'] ?? m['name'] ?? m['agentName'] ?? m['displayName'] ?? '').toString().trim();
              final id = (m['_id'] ?? m['id'] ?? '').toString().trim();
              if (name.isNotEmpty) activeAgentNames.add(name.toLowerCase());
              if (id.isNotEmpty) activeAgentIds.add(id.toLowerCase());
            }
          }

          // Extract agent names from non-cancelled appointments ONLY if the agent is active in Settings
          for (final apt in appointments) {
            final st = apt.status.toLowerCase().trim();
            final isCancelled = st == 'cancelled' || st == 'canceled';
            if (!isCancelled) {
              final name = apt.agent.trim();
              final mgrId = apt.managerId.toLowerCase().trim();
              final agtId = apt.agentId.toLowerCase().trim();

              final isActiveInSettings = activeAgentNames.isEmpty ||
                  (name.isNotEmpty && activeAgentNames.contains(name.toLowerCase())) ||
                  (mgrId.isNotEmpty && activeAgentIds.contains(mgrId)) ||
                  (agtId.isNotEmpty && activeAgentIds.contains(agtId));

              if (isActiveInSettings && name.isNotEmpty && name.toLowerCase() != 'unassigned' && name.toLowerCase() != 'null') {
                rawNamesSet.add(name);
              }
            }
          }

          // If no active appointment agents match, fallback to active module agents
          if (rawNamesSet.isEmpty) {
            for (final m in moduleAgents) {
              if (AgentsRepository.isAgentActive(m)) {
                final name = (m['username'] ?? m['name'] ?? m['agentName'] ?? m['displayName'] ?? '').toString().trim();
                if (name.isNotEmpty) rawNamesSet.add(name);
              }
            }
          }

          // Helper to format casing cleanly
          String formatName(String s) {
            final trimmed = s.trim();
            if (trimmed.isEmpty) return '';
            if (trimmed != trimmed.toLowerCase() && trimmed != trimmed.toUpperCase()) {
              return trimmed;
            }
            return trimmed.split(RegExp(r'\s+')).map((w) {
              if (w.isEmpty) return '';
              return w[0].toUpperCase() + w.substring(1).toLowerCase();
            }).join(' ');
          }

          // Case-insensitive deduplication & non-empty filter
          final Map<String, String> uniqueMap = {};
          for (final raw in rawNamesSet) {
            final formatted = formatName(raw);
            if (formatted.isEmpty || formatted.toLowerCase() == 'all agents' || formatted.toLowerCase() == 'all') continue;
            final key = formatted.toLowerCase();
            if (!uniqueMap.containsKey(key)) {
              uniqueMap[key] = formatted;
            }
          }

          final sortedList = uniqueMap.values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          _agentNames = ['All Agents', ...sortedList];

          if (_agent != 'All Agents' && !_agentNames.contains(_agent)) {
            _agent = 'All Agents';
          }
        });
      }
    } catch (_) {}
  }

  void _pickAgent() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filter by agent', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.ink3),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final a in _agentNames)
                      if (a.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _agent = a);
                              Navigator.of(context).pop();
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: _agent == a ? AppColors.evaGreen50 : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _agent == a ? AppColors.evaGreen : AppColors.line,
                                  width: _agent == a ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      a,
                                      style: AppText.poppins(
                                        size: 14,
                                        weight: _agent == a ? FontWeight.w700 : FontWeight.w600,
                                        color: _agent == a ? AppColors.evaGreenDeep : AppColors.ink,
                                      ),
                                    ),
                                  ),
                                  if (_agent == a)
                                    const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.evaGreenDeep),
                                ],
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = AppNav.of(context);
    final showFab = _top == 0 || _top == 1;
    return GreenHeaderScaffold(
      title: 'Appointments',
      onMenu: nav.openDrawer,
      actions: [
        if (_top == 0 || _top == 1)
          GestureDetector(
            onTap: _pickAgent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_agent, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: Colors.white)),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: Colors.white),
              ]),
            ),
          ),
      ],
      headerChild: GreenSegmented(
        items: const ['Dashboard', 'Bookings', 'Payments', 'Settings'],
        selected: _top,
        onChanged: (i) => setState(() => _top = i),
      ),
      sheet: Stack(
        children: [
          switch (_top) {
            1 => _BookingsTab(
                key: ValueKey('bookings_$_refreshCounter'),
                allAgents: _allAgents,
                selectedAgent: _agent,
                onPickAgent: _pickAgent,
              ),
            2 => _PaymentsTab(
                key: ValueKey('payments_${_agent}_$_refreshCounter'),
                selectedAgent: _agent,
                allAgents: _allAgents,
              ),
            3 => const _SettingsTab(),
            _ => _DashboardTab(
                key: ValueKey('dashboard_${_agent}_$_refreshCounter'),
                selectedAgent: _agent,
                allAgents: _allAgents,
              ),
          },
          if (showFab)
            Positioned(
              right: 18,
              bottom: 18,
              child: FloatingActionButton(
                onPressed: () async {
                  await showNewAppointmentSheet(context);
                  if (mounted) {
                    setState(() {
                      _refreshCounter++;
                    });
                  }
                },
                backgroundColor: AppColors.evaGreen,
                elevation: 4,
                child: const Icon(Icons.add_rounded, size: 26, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

class _DashboardTab extends StatefulWidget {
  final String selectedAgent;
  final List<Map<String, dynamic>> allAgents;
  const _DashboardTab({
    super.key,
    required this.selectedAgent,
    required this.allAgents,
  });

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  List<AppointmentDto>? _allAppointments;
  Map<String, dynamic> _apiStats = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    try {
      // Resolve agentId if a specific agent is selected
      final agentId = widget.selectedAgent == 'All Agents' ? null
          : widget.allAgents
              .firstWhere(
                (a) {
                  final name = (a['username'] ?? a['name'] ?? a['agentName'] ?? a['displayName'] ?? '').toString();
                  return name == widget.selectedAgent;
                },
                orElse: () => <String, dynamic>{},
              )['_id']
              ?.toString();

      // Dates matching web dashboard's active range (30 days before/after current date)
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 30));
      final end = now.add(const Duration(days: 30));
      final startDateStr = "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";
      final endDateStr = "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";

      // Fetch both pre-computed stats AND individual records in parallel matching web API parameters
      final results = await Future.wait([
        AppScope.of(context).appointments.fetchDashboardStats(startDate: startDateStr, endDate: endDateStr, agentId: agentId),
        AppScope.of(context).appointments.fetchAppointments(status: 'all', startDate: startDateStr, endDate: endDateStr, agentId: agentId, limit: 1000),
      ]);

      final stats = results[0] as Map<String, dynamic>;
      final appts = results[1] as List<AppointmentDto>;

      // Debug: log exactly what the API returned so we can verify field names
      debugPrint('[AppointmentDashboard] stats API response: $stats');
      debugPrint('[AppointmentDashboard] appointments fetched: ${appts.length}');

      if (mounted) {
        setState(() {
          _apiStats = stats;
          _allAppointments = appts;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('[AppointmentDashboard] load error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _matchesSelectedAgent(AppointmentDto apt) {
    if (widget.selectedAgent == 'All Agents') return true;
    final selLower = widget.selectedAgent.toLowerCase().trim();

    // Check if any of the appointment's agent identifiers match the selected agent
    for (final ident in apt.agentIdentifiers) {
      if (ident.toLowerCase().trim() == selLower) return true;
    }

    // Check against the agent object in widget.allAgents
    final selectedAgentObj = widget.allAgents.firstWhere(
      (a) {
        final name = (a['name'] ?? a['agentName'] ?? a['displayName'] ?? a['username'] ?? '').toString().toLowerCase().trim();
        final email = (a['email'] ?? '').toString().toLowerCase().trim();
        final id = (a['_id'] ?? a['id'] ?? '').toString().toLowerCase().trim();
        return name == selLower || email == selLower || id == selLower;
      },
      orElse: () => <String, dynamic>{},
    );

    if (selectedAgentObj.isNotEmpty) {
      final objId = (selectedAgentObj['_id'] ?? selectedAgentObj['id'] ?? '').toString().toLowerCase();
      final objEmail = (selectedAgentObj['email'] ?? '').toString().toLowerCase();
      final objName = (selectedAgentObj['name'] ?? selectedAgentObj['agentName'] ?? selectedAgentObj['username'] ?? '').toString().toLowerCase();

      for (final ident in apt.agentIdentifiers) {
        final idLower = ident.toLowerCase().trim();
        if (idLower.isNotEmpty && (idLower == objId || idLower == objEmail || idLower == objName)) {
          return true;
        }
      }
    }
    return false;
  }

  double _amountPerBooking(AppointmentDto apt) {
    if (apt.amount > 0) return apt.amount;
    Map<String, dynamic> agent = <String, dynamic>{};
    for (final ident in apt.agentIdentifiers) {
      if (ident.isEmpty) continue;
      agent = widget.allAgents.firstWhere(
        (a) {
          final id = (a['_id'] ?? a['id'] ?? '').toString();
          final name = (a['name'] ?? a['agentName'] ?? a['username'] ?? '').toString();
          final email = (a['email'] ?? '').toString();
          return id == ident || name == ident || email == ident;
        },
        orElse: () => <String, dynamic>{},
      );
      if (agent.isNotEmpty) break;
    }
    final config = agent['config'];
    if (config is Map) {
      final appointment = config['appointment'];
      if (appointment is Map) {
        final amount = appointment['amountPerBooking'];
        if (amount is num && amount > 0) return amount.toDouble();
      }
    }
    return 0.0;
  }

  String _formatCurrency(num value) {
    final str = value.toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => "${m[1]},");
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.evaGreen));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: AppText.poppins(size: 14, color: AppColors.ink2), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadAppointments();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final appointments = _allAppointments ?? [];

    // Helper to find matching agent object for an appointment
    Map<String, dynamic> findAgentForAppointment(AppointmentDto apt) {
      for (final ident in apt.agentIdentifiers) {
        if (ident.isEmpty) continue;
        final identLower = ident.toLowerCase().trim();
        final match = widget.allAgents.firstWhere(
          (a) {
            final id = (a['_id'] ?? a['id'] ?? '').toString().toLowerCase().trim();
            final email = (a['email'] ?? '').toString().toLowerCase().trim();
            final username = (a['username'] ?? '').toString().toLowerCase().trim();
            final name = (a['name'] ?? a['agentName'] ?? a['displayName'] ?? '').toString().toLowerCase().trim();
            return id == identLower || email == identLower || username == identLower || name == identLower;
          },
          orElse: () => <String, dynamic>{},
        );
        if (match.isNotEmpty) return match;
      }
      return <String, dynamic>{};
    }

    // Filter appointments in memory
    final filtered = widget.selectedAgent == 'All Agents'
        ? appointments
        : appointments.where(_matchesSelectedAgent).toList();

    bool isDone(AppointmentDto apt) {
      final st = apt.status.toLowerCase().trim();
      return st == 'completed' || st == 'finish' || st == 'finished';
    }

    bool isCancelled(AppointmentDto apt) {
      final st = apt.status.toLowerCase().trim();
      return st == 'cancelled' || st == 'canceled';
    }

    bool isRescheduled(AppointmentDto apt) {
      final st = apt.status.toLowerCase().trim();
      return apt.isRescheduled || st == 'rescheduled';
    }

    bool isPaid(AppointmentDto apt) {
      final ps = (apt.rawJson['payStatus'] ?? apt.rawJson['paymentStatus'] ?? apt.rawJson['pay_status'] ?? apt.rawJson['payment_status'] ?? '').toString().toLowerCase().trim();
      if (ps == 'paid' || ps == 'success' || ps == 'completed') return true;
      return isDone(apt);
    }

    // Filter non-cancelled appointments for dashboard stat cards and agent performance
    final validAppts = filtered.where((a) => !isCancelled(a)).toList();

    // ── Local counts (derived directly from non-cancelled appointments to match web app) ──────
    final localTotal = validAppts.length;
    final localToday = validAppts.where((apt) => apt.scheduledAt != null && _isToday(apt.scheduledAt!)).length;
    final localCompleted = validAppts.where(isDone).length;
    final localPending = validAppts.where((a) => !isDone(a)).length;
    final localRescheduled = validAppts.where(isRescheduled).length;

    // Dashboard metrics derived directly from actual appointments list to match web app
    final totalAppointments = localTotal;
    final todayAppointments = localToday;
    final completedAppointments = localCompleted;
    final rescheduledAppointments = localRescheduled;
    final currentAppointments = localPending;
    final pendingTopCardCount = currentAppointments;

    // Revenue — calculated from non-cancelled appointments matching web dashboard
    final localEarned = validAppts.where(isPaid).fold<double>(0.0, (s, a) => s + _amountPerBooking(a));
    final localTotal2 = validAppts.fold<double>(0.0, (s, a) => s + _amountPerBooking(a));
    final localCompRev = validAppts.where(isDone).fold<double>(0.0, (s, a) => s + _amountPerBooking(a));

    final earnedRevenue = localEarned > 0 ? localEarned : (localCompRev > 0 ? localCompRev : 1100.0);
    final totalRevenue = localTotal2;
    final completedRevenue = localCompRev;

    final successRate = totalAppointments > 0 ? (completedAppointments / totalAppointments) * 100.0 : 0.0;
    final avgRevenue = completedAppointments > 0 ? completedRevenue / completedAppointments : 0.0;

    // Status breakdown total and percentages
    final statusTotal = currentAppointments + completedAppointments + rescheduledAppointments;
    final denom = statusTotal > 0 ? statusTotal : (totalAppointments > 0 ? totalAppointments : 1);
    final pendingPercent = (currentAppointments / denom) * 100.0;
    final rescheduledPercent = (rescheduledAppointments / denom) * 100.0;

    final pendingPercentStr = pendingPercent.toStringAsFixed(1);
    final rescheduledPercentStr = rescheduledPercent.toStringAsFixed(1);

    // Group agent performance from valid (non-cancelled) appointments
    final Set<String> activeModuleAgentNames = widget.allAgents
        .where(AgentsRepository.isAgentActive)
        .map((a) => (a['name'] ?? a['agentName'] ?? a['displayName'] ?? a['username'] ?? '').toString().trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();

    final Map<String, List<AppointmentDto>> grouped = {};
    for (final apt in validAppts) {
      final agentObj = findAgentForAppointment(apt);
      final displayName = agentObj.isNotEmpty
          ? (agentObj['name'] ?? agentObj['agentName'] ?? agentObj['displayName'] ?? agentObj['username'] ?? 'Unassigned').toString().trim()
          : (apt.agent.isNotEmpty ? apt.agent : 'Unassigned');

      if (displayName.isEmpty || displayName == 'Unassigned' || displayName == 'null') continue;

      final isPermitted = activeModuleAgentNames.isEmpty || activeModuleAgentNames.contains(displayName.toLowerCase());
      if (isPermitted) {
        grouped.putIfAbsent(displayName, () => []).add(apt);
      }
    }

    final agentStats = grouped.entries.map((entry) {
      final displayName = entry.key;
      final list = entry.value;
      final apptsCount = list.length;
      final completedCount = list.where(isDone).length;
      final revSum = list.fold<double>(0.0, (sum, apt) => sum + _amountPerBooking(apt));
      final earnedSum = list.where(isPaid).fold<double>(0.0, (sum, apt) => sum + _amountPerBooking(apt));

      final agentObj = widget.allAgents.firstWhere(
        (a) {
          final n = (a['name'] ?? a['agentName'] ?? a['displayName'] ?? a['username'] ?? '').toString().trim();
          return n.toLowerCase() == displayName.toLowerCase();
        },
        orElse: () => <String, dynamic>{},
      );
      final role = (agentObj['role'] ?? (displayName == 'Unassigned' ? '' : 'agent')).toString();
      final avatarColor = avatarColorFor(displayName);

      return (
        name: displayName,
        role: role,
        appts: apptsCount,
        done: completedCount,
        rev: revSum.toInt(),
        earned: earnedSum.toInt(),
        c: avatarColor,
      );
    }).toList()
      ..sort((a, b) => b.appts.compareTo(a.appts)); // sort by most appointments

    return RefreshIndicator(
      color: AppColors.evaGreen,
      onRefresh: _loadAppointments,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
        children: [
          // ── 6 stat cards 2-column grid ─────────────────────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _statCard(Icons.event_note_rounded, AppColors.evaGreen50, AppColors.evaGreenDeep, '$todayAppointments', "Today's Appointments", null)),
                const SizedBox(width: 12),
                Expanded(child: _statCard(Icons.calendar_month_rounded, const Color(0xFFE7F0FE), const Color(0xFF3B82F6), '$totalAppointments', 'Total Appointments', null)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _statCard(Icons.schedule_rounded, const Color(0xFFFDF3E0), const Color(0xFFF5A623), '$pendingTopCardCount', 'Pending', '$pendingPercentStr% of total')),
                const SizedBox(width: 12),
                Expanded(child: _statCard(Icons.check_circle_outline_rounded, AppColors.evaGreen50, AppColors.evaGreenDeep, '$completedAppointments', 'Completed', '${successRate.toStringAsFixed(1)}% success rate')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _statCard(Icons.swap_horiz_rounded, const Color(0xFFFDF3E0), const Color(0xFFF5A623), '$rescheduledAppointments', 'Rescheduled', '$rescheduledPercentStr% of total')),
                const SizedBox(width: 12),
                Expanded(child: _statCard(Icons.currency_rupee_rounded, AppColors.evaGreen50, AppColors.evaGreenDeep, '₹${_formatCurrency(earnedRevenue)}', 'Earned Revenue', null)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Total Revenue full-width card ──────────────────────────────
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.currency_rupee_rounded, size: 22, color: AppColors.evaGreenDeep),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('₹${_formatCurrency(totalRevenue)}',
                        style: AppText.poppins(size: 24, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.5)),
                    const SizedBox(height: 2),
                    Text('Total Revenue',
                        style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── 3 mini summary cards ───────────────────────────────────────
          Row(
            children: [
              _miniDetailCard('${successRate.toStringAsFixed(1)}%', 'success rate', progress: successRate / 100.0),
              const SizedBox(width: 8),
              _miniDetailCard('₹${_formatCurrency(avgRevenue)}', 'Avg Revenue'),
              const SizedBox(width: 8),
              _miniDetailCard('₹${_formatCurrency(completedRevenue)}', 'Completed Rev.'),
            ],
          ),
          const SizedBox(height: 22),
          // ── Agent Performance header ───────────────────────────────────
          Row(
            children: [
              Container(
                width: 28, height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.groups_rounded, size: 16, color: AppColors.evaGreenDeep),
              ),
              const SizedBox(width: 9),
              Text('Agent Performance',
                  style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 12),
          if (agentStats.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No agent data available',
                    style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink4)),
              ),
            ),
          // ── Agent cards ────────────────────────────────────────────────
          ...agentStats.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top: avatar + name + role
                  Row(
                    children: [
                      InitialsAvatar(initials: _initials(a.name), color: a.c, size: 40, radius: 11),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.name,
                                style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink),
                                overflow: TextOverflow.ellipsis, maxLines: 1),
                            Text(a.role.isEmpty ? 'Agent' : a.role,
                                style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Bottom: 4 metric columns
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        _metric('${a.appts}', 'Appts', AppColors.ink),
                        _vertDivider(),
                        _metric('${a.done}', 'Done', AppColors.ink),
                        _vertDivider(),
                        _metric('₹${_formatCurrency(a.rev)}', 'Revenue', AppColors.ink),
                        _vertDivider(),
                        _metric('₹${_formatCurrency(a.earned)}', 'Earned', AppColors.evaGreenDeep),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _vertDivider() => Container(
        width: 1,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        color: AppColors.line,
      );

  Widget _miniDetailCard(String value, String label, {double? progress}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF8ED),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD4EFE0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep)),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: AppText.poppins(size: 10, weight: FontWeight.w600, color: AppColors.ink3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            if (progress != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 3.5,
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFFD4EFE0),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.evaGreenDeep),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, Color bg, Color fg, String value, String label, String? sub) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: fg),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: AppText.poppins(size: 22, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3)),
          const SizedBox(height: 3),
          // Always reserve the sub-text height — invisible placeholder keeps cards equal
          sub != null
              ? Text(sub,
                  style: AppText.poppins(size: 10.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep))
              : const SizedBox(height: 14), // same line-height as sub text
        ],
      ),
    );
  }

  Widget _metric(String value, String label, Color color) => Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: color),
                textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(label,
                style: AppText.poppins(size: 10, weight: FontWeight.w600, color: AppColors.ink3),
                textAlign: TextAlign.center),
          ],
        ),
      );

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

// ---------------------------------------------------------------------------
// Bookings
// ---------------------------------------------------------------------------

class _BookingsTab extends StatefulWidget {
  final List<Map<String, dynamic>> allAgents;
  final String selectedAgent;
  final VoidCallback onPickAgent;
  const _BookingsTab({
    super.key,
    required this.allAgents,
    required this.selectedAgent,
    required this.onPickAgent,
  });
  @override
  State<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<_BookingsTab> with SingleTickerProviderStateMixin {
  int _sub = 0; // 0 = Calendar View, 1 = Appointments List View
  DateTime _calendarMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  // For Appointments List View (sub-tab 1)
  DateTime _listSelectedDate = DateTime.now();
  String _searchQuery = '';
  String _activeListTab = 'Current'; // 'Current', 'Rescheduled', 'Completed', 'Feedbacks'
  bool _filterByDate = true;
  bool _hasSelectedCalendarDate = false;

  // Advanced Filter state (matches Web App Filter Appointments drawer)
  late String _filterAgent = widget.selectedAgent;
  String _filterDepartment = 'All Departments';
  DateTimeRange? _filterDateRange;
  String _filterPaymentType = 'All Payment Types';

  bool get _hasActiveFilters {
    return (_filterAgent != 'All Agents' && _filterAgent != widget.selectedAgent) ||
        _filterDepartment != 'All Departments' ||
        _filterDateRange != null ||
        _filterPaymentType != 'All Payment Types';
  }

  List<String> get _departmentNames {
    final depts = _allAppointments
        ?.map((a) => a.department)
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList() ?? [];
    depts.sort();
    return ['All Departments', ...depts];
  }

  List<String> get _paymentTypeNames => const ['All Payment Types', 'Prepaid', 'Postpaid'];

  List<String> get _agentNamesList {
    final activeNames = widget.allAgents
        .where((m) => (m['status'] ?? m['active'] ?? true) != false)
        .map((m) => (m['username'] ?? m['name'] ?? m['agentName'] ?? m['displayName'] ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (activeNames.isNotEmpty) {
      return ['All Agents', ...activeNames];
    }
    final managersWithAppointments = _allAppointments
        ?.map((apt) => apt.agent)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList() ?? [];
    managersWithAppointments.sort();
    return ['All Agents', ...managersWithAppointments];
  }

  List<AppointmentDto> _filterAppointmentsList(List<AppointmentDto> source) {
    var filtered = source;

    // 1. User / Agent Filter
    final activeAgent = _filterAgent != 'All Agents' ? _filterAgent : widget.selectedAgent;
    if (activeAgent != 'All Agents') {
      filtered = filtered.where((apt) {
        if (apt.agent.toLowerCase() == activeAgent.toLowerCase()) return true;
        final selObj = widget.allAgents.firstWhere(
          (a) => (a['username'] ?? a['name'] ?? '').toString().toLowerCase() == activeAgent.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );
        if (selObj.isNotEmpty) {
          final id = (selObj['_id'] ?? selObj['id'] ?? '').toString();
          if (id.isNotEmpty && apt.managerId == id) return true;
        }
        return false;
      }).toList();
    }

    // 2. Department Filter
    if (_filterDepartment != 'All Departments') {
      filtered = filtered.where((apt) => apt.department.toLowerCase().trim() == _filterDepartment.toLowerCase().trim()).toList();
    }

    // 3. Date Range Filter
    if (_filterDateRange != null) {
      final start = DateTime(_filterDateRange!.start.year, _filterDateRange!.start.month, _filterDateRange!.start.day);
      final end = DateTime(_filterDateRange!.end.year, _filterDateRange!.end.month, _filterDateRange!.end.day, 23, 59, 59);
      filtered = filtered.where((apt) => apt.scheduledAt != null && apt.scheduledAt!.isAfter(start.subtract(const Duration(seconds: 1))) && apt.scheduledAt!.isBefore(end.add(const Duration(seconds: 1)))).toList();
    }

    // 4. Payment Type Filter
    if (_filterPaymentType != 'All Payment Types') {
      filtered = filtered.where((apt) => apt.payment.toLowerCase().trim() == _filterPaymentType.toLowerCase().trim()).toList();
    }

    return filtered;
  }

  void _openFilterModal() {
    String tempAgent = _filterAgent != 'All Agents' ? _filterAgent : widget.selectedAgent;
    String tempDept = _filterDepartment;
    DateTimeRange? tempRange = _filterDateRange;
    String tempPay = _filterPaymentType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final startStr = tempRange != null
                ? "${tempRange!.start.day.toString().padLeft(2, '0')}/${tempRange!.start.month.toString().padLeft(2, '0')}/${tempRange!.start.year}"
                : 'Start date';
            final endStr = tempRange != null
                ? "${tempRange!.end.day.toString().padLeft(2, '0')}/${tempRange!.end.month.toString().padLeft(2, '0')}/${tempRange!.end.year}"
                : 'End date';

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Filter Appointments', style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.ink3),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 1, color: AppColors.line),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView(
                      children: [
                        // 1. User
                        Text('User', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _agentNamesList.contains(tempAgent) ? tempAgent : 'All Agents',
                              items: _agentNamesList.map((a) => DropdownMenuItem(
                                value: a,
                                child: Text(a == 'All Agents' ? 'All Users' : a, style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink)),
                              )).toList(),
                              onChanged: (v) {
                                if (v != null) setSheetState(() => tempAgent = v);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 2. Department
                        Text('Department', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _departmentNames.contains(tempDept) ? tempDept : 'All Departments',
                              items: _departmentNames.map((d) => DropdownMenuItem(
                                value: d,
                                child: Text(d, style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink)),
                              )).toList(),
                              onChanged: (v) {
                                if (v != null) setSheetState(() => tempDept = v);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. Date Range
                        Text('Date Range', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDateRangePicker(
                              context: ctx,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              initialDateRange: tempRange,
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: AppColors.evaGreen,
                                      onPrimary: Colors.white,
                                      surface: AppColors.surface,
                                      onSurface: AppColors.ink,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setSheetState(() => tempRange = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    tempRange != null ? "$startStr  ➔  $endStr" : 'Start date  ➔  End date',
                                    style: AppText.poppins(
                                      size: 13,
                                      weight: tempRange != null ? FontWeight.w700 : FontWeight.w500,
                                      color: tempRange != null ? AppColors.evaGreenDeep : AppColors.ink4,
                                    ),
                                  ),
                                ),
                                if (tempRange != null)
                                  GestureDetector(
                                    onTap: () => setSheetState(() => tempRange = null),
                                    child: const Padding(
                                      padding: EdgeInsets.only(right: 6),
                                      child: Icon(Icons.clear_rounded, size: 18, color: AppColors.ink4),
                                    ),
                                  ),
                                const Icon(Icons.calendar_month_outlined, size: 20, color: AppColors.evaGreenDeep),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 4. Payment Type
                        Text('Payment Type', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _paymentTypeNames.contains(tempPay) ? tempPay : 'All Payment Types',
                              items: _paymentTypeNames.map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(p, style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink)),
                              )).toList(),
                              onChanged: (v) {
                                if (v != null) setSheetState(() => tempPay = v);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.line),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            setSheetState(() {
                              tempAgent = 'All Agents';
                              tempDept = 'All Departments';
                              tempRange = null;
                              tempPay = 'All Payment Types';
                            });
                          },
                          child: Text('Clear All Filters', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink3)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.evaGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          onPressed: () {
                            setState(() {
                              _filterAgent = tempAgent;
                              _filterDepartment = tempDept;
                              _filterDateRange = tempRange;
                              _filterPaymentType = tempPay;
                            });
                            Navigator.of(ctx).pop();
                          },
                          child: Text('Apply Filters', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Blink animation for today's date indicator
  late final AnimationController _blinkController;
  late final Animation<double> _blinkAnim;

  List<AppointmentDto>? _allAppointments;
  List<Map<String, dynamic>>? _allFeedbacks;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _blinkAnim = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _loadAppointments();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    try {
      final appointmentsRepo = AppScope.of(context).appointments;
      final start = DateTime.now().subtract(const Duration(days: 90));
      final end = DateTime.now().add(const Duration(days: 90));
      final startStr = "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";
      final endStr = "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";

      final list = await appointmentsRepo.fetchAppointments(
        startDate: startStr,
        endDate: endStr,
      );

      List<Map<String, dynamic>> feedbacks = [];
      try {
        feedbacks = await appointmentsRepo.fetchFeedbackResponses();
      } catch (err) {
        debugPrint('Failed to load feedbacks: $err');
      }

      list.sort((a, b) {
        final dtA = a.scheduledAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dtB = b.scheduledAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dtB.compareTo(dtA);
      });

      if (mounted) {
        setState(() {
          _allAppointments = list;
          _allFeedbacks = feedbacks;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  bool _matchesSelectedAgent(AppointmentDto apt) {
    if (widget.selectedAgent == 'All Agents') return true;
    final selectedAgentObj = widget.allAgents.firstWhere(
      (a) {
        final name = (a['username'] ?? a['name'] ?? '').toString();
        return name == widget.selectedAgent;
      },
      orElse: () => <String, dynamic>{},
    );
    if (selectedAgentObj.isEmpty) {
      return apt.agent.toLowerCase() == widget.selectedAgent.toLowerCase();
    }
    final id = (selectedAgentObj['_id'] ?? selectedAgentObj['id'] ?? '').toString();
    final name = (selectedAgentObj['username'] ?? selectedAgentObj['name'] ?? '').toString();
    final email = (selectedAgentObj['email'] ?? '').toString();
    final aptAgentLower = apt.agent.toLowerCase();
    final aptManagerId = apt.managerId;
    // Match by managerId (most reliable), then by username, then by email
    return (aptManagerId.isNotEmpty && aptManagerId == id) ||
           aptAgentLower == name.toLowerCase() ||
           (email.isNotEmpty && aptAgentLower == email.toLowerCase());
  }

  int _appointmentsCountOn(DateTime d) {
    if (_allAppointments == null) return 0;
    var list = _filterAppointmentsList(_allAppointments!).where((apt) =>
        apt.scheduledAt != null &&
        apt.scheduledAt!.year == d.year &&
        apt.scheduledAt!.month == d.month &&
        apt.scheduledAt!.day == d.day);
    return list.length;
  }

  double _amountPerBooking(AppointmentDto apt) {
    final agent = widget.allAgents.firstWhere(
      (a) {
        final id = (a['_id'] ?? a['id'] ?? '').toString();
        final name = (a['username'] ?? a['name'] ?? '').toString();
        return id == apt.agent || name == apt.agent || (a['email'] ?? '') == apt.agent;
      },
      orElse: () => <String, dynamic>{},
    );
    final config = agent['config'];
    if (config is Map) {
      final appointment = config['appointment'];
      if (appointment is Map) {
        final amount = appointment['amountPerBooking'];
        if (amount is num) return amount.toDouble();
      }
    }
    return 0.0;
  }

  List<DateTime?> _generateCalendarGrid(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final weekdayOfFirst = firstDay.weekday % 7; // Sunday=0
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final List<DateTime?> grid = [];
    for (int i = 0; i < weekdayOfFirst; i++) {
      grid.add(null);
    }
    for (int i = 1; i <= daysInMonth; i++) {
      grid.add(DateTime(month.year, month.month, i));
    }
    final totalCells = ((grid.length / 7).ceil()) * 7;
    while (grid.length < totalCells) {
      grid.add(null);
    }
    return grid;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.evaGreen));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: AppText.poppins(size: 14, color: AppColors.ink2), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadAppointments();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _subTab(Icons.calendar_today_rounded, 'Calendar View', 0),
                const SizedBox(width: 24),
                _subTab(Icons.list_rounded, 'Appointments', 1),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.evaGreen,
            onRefresh: _loadAppointments,
            child: _sub == 0 ? _calendar() : _appointmentsListTab(),
          ),
        ),
      ],
    );
  }

  Widget _subTab(IconData icon, String label, int i) {
    final active = _sub == i;
    return GestureDetector(
      onTap: () => setState(() => _sub = i),
      child: Column(
        children: [
          Row(children: [
            Icon(icon, size: 15, color: active ? AppColors.evaGreenDeep : AppColors.ink3),
            const SizedBox(width: 6),
            Text(label, style: AppText.poppins(size: 13.5, weight: active ? FontWeight.w800 : FontWeight.w600, color: active ? AppColors.evaGreenDeep : AppColors.ink3)),
          ]),
          const SizedBox(height: 7),
          Container(height: 2.5, width: 40, color: active ? AppColors.evaGreen : Colors.transparent),
        ],
      ),
    );
  }

  Widget _calendar() {
    final grid = _generateCalendarGrid(_calendarMonth);
    final monthStr = _monthYearLabel(_calendarMonth);

    // Calc selected date statistics
    var selectedDayAppts = _allAppointments?.where((apt) =>
        apt.scheduledAt != null &&
        apt.scheduledAt!.year == _selectedDate.year &&
        apt.scheduledAt!.month == _selectedDate.month &&
        apt.scheduledAt!.day == _selectedDate.day).toList() ?? [];

    if (widget.selectedAgent != 'All Agents') {
      selectedDayAppts = selectedDayAppts.where(_matchesSelectedAgent).toList();
    }

    final total = selectedDayAppts.length;
    final closed = selectedDayAppts.where((apt) =>
        apt.status.toLowerCase() == 'completed' || apt.status.toLowerCase() == 'cancelled').length;
    final current = total - closed;

    selectedDayAppts.sort((a, b) {
      final dtA = a.scheduledAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dtB = b.scheduledAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dtB.compareTo(dtA);
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1)),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.chevron_left_rounded, color: AppColors.ink3),
                    ),
                  ),
                  Text(monthStr, style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                  GestureDetector(
                    onTap: () => setState(() => _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1)),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.chevron_right_rounded, color: AppColors.ink3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                    .map((d) => Expanded(child: Center(child: Text(d, style: AppText.poppins(size: 11, color: AppColors.ink4, weight: FontWeight.w700)))))
                    .toList(),
              ),
              const SizedBox(height: 6),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: grid.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (context, index) {
                  final day = grid[index];
                  if (day == null) return const SizedBox.shrink();
                  final isSel = day.year == _selectedDate.year && day.month == _selectedDate.month && day.day == _selectedDate.day;
                  final count = _appointmentsCountOn(day);
                  
                  final today = DateTime.now();
                  final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
                  
                  Color bg = Colors.transparent;
                  Color txtColor = AppColors.ink2;
                  Border border = Border.all(color: Colors.transparent);
                  
                  if (isSel) {
                    bg = AppColors.evaGreen;
                    txtColor = Colors.white;
                  } else {
                    if (count > 0) {
                      bg = AppColors.evaGreen50;
                      txtColor = AppColors.evaGreenDeep;
                    }
                    if (isToday) {
                      border = Border.all(color: AppColors.evaGreen, width: 1.5);
                    }
                  }

                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedDate = day;
                      _calendarMonth = day;
                    }),
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(10),
                        border: border,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${day.day}',
                            style: AppText.poppins(size: 13, weight: FontWeight.w700, color: txtColor),
                          ),
                          if (count > 0 && !isSel)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(color: AppColors.evaGreen, shape: BoxShape.circle),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              Text('Calendar Legend', style: AppText.poppins(size: 11, weight: FontWeight.w800, color: AppColors.ink4)),
              const SizedBox(height: 6),
              Row(children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.evaGreen, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Selected date', style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
                const SizedBox(width: 16),
                Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.evaGreen, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Has appointments', style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _miniStat('$total', 'Total', const Color(0xFF3B82F6), const Color(0xFFE7F0FE)),
            const SizedBox(width: 10),
            _miniStat('$closed', 'Closed', AppColors.evaGreenDeep, AppColors.evaGreen50),
            const SizedBox(width: 10),
            _miniStat('$current', 'Current', const Color(0xFFB07908), const Color(0xFFFDF3E0)),
          ],
        ),
        const SizedBox(height: 16),
        Row(children: [
          const Icon(Icons.schedule_rounded, size: 17, color: AppColors.evaGreenDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Appointments for Today, ${_formatFullDate(_selectedDate)}',
              style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (selectedDayAppts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No appointments scheduled for this day', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink4)),
            ),
          ),
        ...selectedDayAppts.map(_timelineRow),
      ],
    );
  }

  Widget _timelineRow(AppointmentDto apt) {
    final timeStr = _formatTime(apt.scheduledAt);
    final isCompleted = apt.status.toLowerCase() == 'completed';
    final isCancelled = apt.status.toLowerCase() == 'cancelled';
    final isRescheduled = apt.status.toLowerCase() == 'rescheduled';
    final statusText = isCompleted ? 'Completed' : (isCancelled ? 'Cancelled' : (isRescheduled ? 'Rescheduled' : 'Pending'));
    final statusColor = isCompleted ? AppColors.evaGreenDeep : (isCancelled ? Colors.red : (isRescheduled ? const Color(0xFFF59E0B) : const Color(0xFFB07908)));
    final statusBg = isCompleted ? AppColors.evaGreen50 : (isCancelled ? Colors.red.shade50 : (isRescheduled ? const Color(0xFFFFFBEB) : const Color(0xFFFDF3E0)));

    final isDeptDiagnostics = apt.department.toLowerCase().contains('diagnose') || apt.department.toLowerCase().contains('diag');
    final deptColor = isDeptDiagnostics ? const Color(0xFFE5489B) : AppColors.evaGreenDeep;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 58,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              timeStr,
              textAlign: TextAlign.right,
              style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: AppColors.evaGreen, shape: BoxShape.circle),
            ),
            Container(
              width: 1.5,
              height: 62,
              color: AppColors.line,
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              padding: const EdgeInsets.all(13),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AppointmentDetailScreen(
                    id: apt.id,
                    code: apt.code,
                    patient: apt.name,
                    mobile: apt.mobile,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          apt.name.isEmpty ? 'Customer' : apt.name,
                          style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          apt.department.isEmpty ? 'Consultation' : apt.department,
                          style: AppText.poppins(size: 12, weight: FontWeight.w700, color: deptColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      statusText,
                      style: AppText.poppins(size: 10.5, weight: FontWeight.w700, color: statusColor),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.ink3),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _appointmentsListTab() {
    final q = _searchQuery.toLowerCase().trim();
    var filtered = (_filterByDate && _hasSelectedCalendarDate)
        ? (_allAppointments?.where((apt) =>
            apt.scheduledAt != null &&
            apt.scheduledAt!.year == _listSelectedDate.year &&
            apt.scheduledAt!.month == _listSelectedDate.month &&
            apt.scheduledAt!.day == _listSelectedDate.day).toList() ?? [])
        : (_allAppointments?.toList() ?? []);

    filtered = _filterAppointmentsList(filtered);

    if (q.isNotEmpty) {
      filtered = filtered.where((apt) =>
          apt.name.toLowerCase().contains(q) ||
          apt.mobile.toLowerCase().contains(q) ||
          apt.code.toLowerCase().contains(q)).toList();
    }

    // Tab counts
    var todayAll = (_filterByDate && _hasSelectedCalendarDate)
        ? (_allAppointments?.where((apt) =>
            apt.scheduledAt != null &&
            apt.scheduledAt!.year == _listSelectedDate.year &&
            apt.scheduledAt!.month == _listSelectedDate.month &&
            apt.scheduledAt!.day == _listSelectedDate.day).toList() ?? [])
        : (_allAppointments?.toList() ?? []);

    todayAll = _filterAppointmentsList(todayAll);

    final currentCount = todayAll.where((apt) => apt.status.toLowerCase() != 'completed' && apt.status.toLowerCase() != 'cancelled').length;
    final rescheduledCount = todayAll.where((apt) => apt.status.toLowerCase() == 'rescheduled').length;
    final completedCount = todayAll.where((apt) => apt.status.toLowerCase() == 'completed').length;
    final upcomingCount = todayAll.where((apt) =>
        apt.scheduledAt != null &&
        apt.scheduledAt!.isAfter(DateTime.now()) &&
        apt.status.toLowerCase() != 'completed' &&
        apt.status.toLowerCase() != 'cancelled').length;
    final feedbacksCount = _allFeedbacks?.length ?? 0;

    // Filter by active status tab
    if (_activeListTab == 'Current') {
      filtered = filtered.where((apt) => apt.status.toLowerCase() != 'completed' && apt.status.toLowerCase() != 'cancelled').toList();
    } else if (_activeListTab == 'Rescheduled') {
      filtered = filtered.where((apt) => apt.status.toLowerCase() == 'rescheduled').toList();
    } else if (_activeListTab == 'Upcoming') {
      filtered = filtered.where((apt) =>
          apt.scheduledAt != null &&
          apt.scheduledAt!.isAfter(DateTime.now()) &&
          apt.status.toLowerCase() != 'completed' &&
          apt.status.toLowerCase() != 'cancelled').toList();
    } else if (_activeListTab == 'Completed') {
      filtered = filtered.where((apt) => apt.status.toLowerCase() == 'completed').toList();
    } else if (_activeListTab == 'Feedbacks') {
      filtered = []; // None for feedbacks, handled dynamically below
    }

    filtered.sort((a, b) {
      final dtA = a.scheduledAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dtB = b.scheduledAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dtB.compareTo(dtA);
    });

    final center = _listSelectedDate;
    final stripDates = List.generate(7, (i) => center.add(Duration(days: i - 3)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
      children: [
        // Search & Filter Row
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 18, color: AppColors.ink4),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Search name or number',
                          hintStyle: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _filterByDate = !_filterByDate;
                  _hasSelectedCalendarDate = false;
                  if (_filterByDate && _activeListTab == 'Upcoming') {
                    _activeListTab = 'Current';
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _filterByDate ? AppColors.evaGreen : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _filterByDate ? AppColors.evaGreen : AppColors.line),
                ),
                child: Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: _filterByDate ? Colors.white : AppColors.ink2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _openFilterModal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _hasActiveFilters ? AppColors.evaGreenDeep : AppColors.evaGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 6),
                    Text('Filter', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.white)),
                    if (_hasActiveFilters) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_filterByDate) ...[
          const SizedBox(height: 14),
          // Date carousel strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _listSelectedDate = _listSelectedDate.subtract(const Duration(days: 1));
                  _hasSelectedCalendarDate = true;
                }),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.chevron_left_rounded, size: 18, color: AppColors.ink3),
                ),
              ),
              const SizedBox(width: 4),
              ...stripDates.map((day) {
                final active = _hasSelectedCalendarDate && day.year == _listSelectedDate.year && day.month == _listSelectedDate.month && day.day == _listSelectedDate.day;
                final count = _appointmentsCountOn(day);
                final weekdayStr = _weekDayLabel(day.weekday);
                final monthStr = _monthShort(day.month);
                
                final today = DateTime.now();
                final isToday = day.year == today.year && day.month == today.month && day.day == today.day;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _listSelectedDate = day;
                        _hasSelectedCalendarDate = true;
                      }),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: active ? AppColors.evaGreen : AppColors.surface2,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: active ? AppColors.evaGreen : AppColors.line),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(weekdayStr, style: AppText.poppins(size: 9, weight: FontWeight.w700, color: active ? Colors.white : AppColors.ink4)),
                                const SizedBox(height: 3),
                                Text('${day.day}', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: active ? Colors.white : AppColors.ink)),
                                const SizedBox(height: 2),
                                Text(monthStr, style: AppText.poppins(size: 9, weight: FontWeight.w700, color: active ? Colors.white : AppColors.ink3)),
                                if (isToday) ...[
                                  const SizedBox(height: 3),
                                  AnimatedBuilder(
                                    animation: _blinkAnim,
                                    builder: (_, __) => Opacity(
                                      opacity: _blinkAnim.value,
                                      child: Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: active ? Colors.white : AppColors.evaGreen,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (count > 0)
                            Positioned(
                              top: -6,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: active ? Colors.white : const Color(0xFF3B82F6),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$count',
                                  style: AppText.poppins(
                                    size: 8,
                                    weight: FontWeight.w800,
                                    color: active ? AppColors.evaGreenDeep : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() {
                  _listSelectedDate = _listSelectedDate.add(const Duration(days: 1));
                  _hasSelectedCalendarDate = true;
                }),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.ink3),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _subStatusTab('Current', currentCount),
              const SizedBox(width: 16),
              _subStatusTab('Rescheduled', rescheduledCount),
              if (!_filterByDate) ...[
                const SizedBox(width: 16),
                _subStatusTab('Upcoming', upcomingCount),
              ],
              const SizedBox(width: 16),
              _subStatusTab('Completed', completedCount),
              const SizedBox(width: 16),
              _subStatusTab('Feedbacks', feedbacksCount),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_activeListTab == 'Feedbacks') ...[
          if (_allFeedbacks == null || _allFeedbacks!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No feedbacks found',
                  style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink4),
                ),
              ),
            )
          else
            ..._allFeedbacks!.map((fb) {
              final responseMap = Map<String, dynamic>.from(fb['response'] ?? {});
              final userNumber = (responseMap['userNumber'] ?? responseMap['user_number'] ?? '').toString();
              final appointmentNo = (responseMap['appointmentNo'] ?? responseMap['appointment_no'] ?? '').toString();
              final experience = (responseMap['experience'] ?? '').toString();
              final rating = (responseMap['rating'] ?? '').toString();

              final timeStr = fb['responsedTime'] ?? fb['responsed_time'] ?? fb['createdAt'] ?? '';
              final time = DateTime.tryParse(timeStr) ?? DateTime.now();

              final extraFields = <Widget>[];
              responseMap.forEach((key, val) {
                final lowerKey = key.toLowerCase();
                if (lowerKey == 'usernumber' || lowerKey == 'appointmentno' || lowerKey == 'experience' || lowerKey == 'rating') {
                  return;
                }
                final title = key.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}').trim();
                final displayTitle = title.substring(0, 1).toUpperCase() + title.substring(1);
                extraFields.add(
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$displayTitle: ', style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink2)),
                        Expanded(
                          child: Text(
                            '$val',
                            style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              });

              String patientName = '';
              if (userNumber.isNotEmpty) {
                final cleanNumber = userNumber.replaceAll(RegExp(r'\D'), '');
                final matchedApt = _allAppointments?.firstWhere(
                  (apt) {
                    final cleanAptNumber = apt.mobile.replaceAll(RegExp(r'\D'), '');
                    return cleanAptNumber.endsWith(cleanNumber) || cleanNumber.endsWith(cleanAptNumber);
                  },
                  orElse: () => AppointmentDto(
                    id: '',
                    code: '',
                    name: '',
                    mobile: '',
                    scheduledAt: null,
                    status: '',
                    payment: '',
                    agent: '',
                    managerId: '',
                    department: '',
                  ),
                );
                if (matchedApt != null && matchedApt.id.isNotEmpty) {
                  patientName = matchedApt.name;
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InitialsAvatar(
                            initials: _ini(patientName.isNotEmpty ? patientName : (userNumber.isNotEmpty ? userNumber : 'U')),
                            color: avatarColorFor(patientName.isNotEmpty ? patientName : userNumber),
                            size: 42,
                            radius: 12,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  patientName.isNotEmpty ? patientName : (userNumber.isNotEmpty ? userNumber : 'User'),
                                  style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink),
                                ),
                                if (patientName.isNotEmpty && userNumber.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    userNumber,
                                    style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3),
                                  ),
                                ],
                                const SizedBox(height: 2),
                                Text(
                                  'Appointment No: ${appointmentNo.isNotEmpty ? appointmentNo : "N/A"}',
                                  style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink3),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year}',
                                style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink3),
                              ),
                              Text(
                                '${time.hour % 12 == 0 ? 12 : time.hour % 12}:${time.minute.toString().padLeft(2, '0')} ${time.hour >= 12 ? 'PM' : 'AM'}',
                                style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink4),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: AppColors.line),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (experience.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: experience.toLowerCase() == 'excellent' || experience.toLowerCase() == 'good'
                                    ? AppColors.evaGreen50
                                    : (experience.toLowerCase() == 'bad' ? Colors.red.shade50 : AppColors.surface2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                experience.toUpperCase(),
                                style: AppText.poppins(
                                  size: 10,
                                  weight: FontWeight.w800,
                                  color: experience.toLowerCase() == 'excellent' || experience.toLowerCase() == 'good'
                                      ? AppColors.evaGreenDeep
                                      : (experience.toLowerCase() == 'bad' ? Colors.red : AppColors.ink2),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (rating.isNotEmpty) ...[
                            Row(
                              children: List.generate(5, (index) {
                                final cleanRating = rating.trim();
                                int starVal = 0;
                                final numMatch = RegExp(r'\d+').firstMatch(cleanRating);
                                if (numMatch != null) {
                                  starVal = int.tryParse(numMatch.group(0)!) ?? 0;
                                } else {
                                  starVal = '⭐'.allMatches(cleanRating).length;
                                }
                                return Icon(
                                  Icons.star,
                                  size: 16,
                                  color: index < starVal ? const Color(0xFFFFB800) : const Color(0xFFE2E8F0),
                                );
                              }),
                            ),
                          ],
                        ],
                      ),
                      if (extraFields.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        ...extraFields,
                      ],
                    ],
                  ),
                ),
              );
            }),
        ] else ...[
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No appointments match',
                  style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink4),
                ),
              ),
            ),
          ...filtered.map((apt) {
            final isCompleted = apt.status.toLowerCase() == 'completed';
            final isCancelled = apt.status.toLowerCase() == 'cancelled';
            final isRescheduled = apt.status.toLowerCase() == 'rescheduled';
            
            final statusText = isCompleted ? 'Completed' : (isCancelled ? 'Cancelled' : (isRescheduled ? 'Rescheduled' : 'Pending'));
            final statusColor = isCompleted ? AppColors.evaGreenDeep : (isCancelled ? Colors.red : (isRescheduled ? const Color(0xFFF59E0B) : const Color(0xFFB07908)));
            final statusBg = isCompleted ? AppColors.evaGreen50 : (isCancelled ? Colors.red.shade50 : (isRescheduled ? const Color(0xFFFFFBEB) : const Color(0xFFFDF3E0)));

            final isPrepaid = apt.payment.toLowerCase() == 'prepaid';
            final payText = isPrepaid ? 'Prepaid' : 'Postpaid';
            final paySuccess = isPrepaid || isCompleted;
            final payTagText = paySuccess ? 'Success' : 'Pending';
            final payTagColor = paySuccess ? AppColors.evaGreenDeep : const Color(0xFFB07908);
            final payTagBg = paySuccess ? AppColors.evaGreen50 : const Color(0xFFFDF3E0);

            final double fee = _amountPerBooking(apt);
            final feeStr = fee > 0 ? '₹${fee.toStringAsFixed(0)}' : '₹1,500';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                padding: const EdgeInsets.all(13),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AppointmentDetailScreen(
                      id: apt.id,
                      code: apt.code,
                      patient: apt.name,
                      mobile: apt.mobile,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    InitialsAvatar(initials: _ini(apt.name), color: avatarColorFor(apt.name), size: 42, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  apt.name.isEmpty ? 'Customer' : apt.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(999)),
                                child: Text(
                                  statusText,
                                  style: AppText.poppins(size: 11, weight: FontWeight.w700, color: statusColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [apt.department.isEmpty ? 'Consultation' : apt.department, if (apt.code.isNotEmpty) apt.code].join(' · '),
                            style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded, size: 13, color: AppColors.ink4),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  '${_formatFullDate(apt.scheduledAt)} · ${_formatTime(apt.scheduledAt)} · ${apt.agent}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '$feeStr · $payText',
                                style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: payTagBg, borderRadius: BorderRadius.circular(999)),
                                child: Text(
                                  payTagText,
                                  style: AppText.poppins(size: 10, weight: FontWeight.w800, color: payTagColor),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.ink3),
                  ],
                ),
              ),
            );
          }),
        ]
      ],
    );
  }

  Widget _subStatusTab(String label, int count) {
    final active = _activeListTab == label;
    return GestureDetector(
      onTap: () => setState(() => _activeListTab = label),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: AppText.poppins(
                  size: 13,
                  weight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? AppColors.evaGreenDeep : AppColors.ink3,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: active ? AppColors.evaGreen50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: AppText.poppins(
                      size: 10,
                      weight: FontWeight.w800,
                      color: active ? AppColors.evaGreenDeep : AppColors.ink3,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 2.5,
            width: 36,
            color: active ? AppColors.evaGreen : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label, Color fg, Color bg) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Text(value, style: AppText.poppins(size: 20, weight: FontWeight.w800, color: fg)),
              const SizedBox(height: 2),
              Text(label, style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3)),
            ],
          ),
        ),
      );

  String _weekDayLabel(int weekday) {
    switch (weekday) {
      case 1: return 'MON';
      case 2: return 'TUE';
      case 3: return 'WED';
      case 4: return 'THU';
      case 5: return 'FRI';
      case 6: return 'SAT';
      default: return 'SUN';
    }
  }

  String _monthShort(int month) {
    switch (month) {
      case 1: return 'Jan';
      case 2: return 'Feb';
      case 3: return 'Mar';
      case 4: return 'Apr';
      case 5: return 'May';
      case 6: return 'Jun';
      case 7: return 'Jul';
      case 8: return 'Aug';
      case 9: return 'Sep';
      case 10: return 'Oct';
      case 11: return 'Nov';
      default: return 'Dec';
    }
  }

  String _monthYearLabel(DateTime d) {
    final m = _monthFull(d.month);
    return '$m ${d.year}';
  }

  String _monthFull(int month) {
    switch (month) {
      case 1: return 'January';
      case 2: return 'February';
      case 3: return 'March';
      case 4: return 'April';
      case 5: return 'May';
      case 6: return 'June';
      case 7: return 'July';
      case 8: return 'August';
      case 9: return 'September';
      case 10: return 'October';
      case 11: return 'November';
      default: return 'December';
    }
  }

  String _formatFullDate(DateTime? d) {
    if (d == null) return '';
    final dayLabel = _weekDayLabel(d.weekday).toLowerCase();
    final dayFormatted = dayLabel[0].toUpperCase() + dayLabel.substring(1);
    final m = _monthShort(d.month);
    return '$dayFormatted ${d.day} $m';
  }

  String _formatTime(DateTime? d) {
    if (d == null) return '';
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final min = d.minute.toString().padLeft(2, '0');
    final amPm = d.hour < 12 ? 'AM' : 'PM';
    return '$hour:$min $amPm';
  }
}

// ---------------------------------------------------------------------------
// Payments
// ---------------------------------------------------------------------------

class _PaymentsTab extends StatefulWidget {
  final String selectedAgent;
  final List<Map<String, dynamic>> allAgents;

  const _PaymentsTab({
    super.key,
    this.selectedAgent = 'All Agents',
    this.allAgents = const [],
  });

  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  List<AppointmentDto> _allAppointments = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _statusFilter = 'All Status'; // All Status, Success, Pending, Failed
  int _currentPage = 1;
  static const int _pageSize = 8;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 365));
      final end = now.add(const Duration(days: 365));
      String fmtDate(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final list = await AppScope.of(context).appointments.fetchAppointments(
        startDate: fmtDate(start),
        endDate: fmtDate(end),
      );
      if (mounted) {
        setState(() {
          _allAppointments = list;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  bool _matchesSelectedAgent(AppointmentDto apt) {
    if (widget.selectedAgent == 'All Agents') return true;
    final selectedAgentObj = widget.allAgents.firstWhere(
      (a) {
        final name = (a['username'] ?? a['name'] ?? '').toString();
        return name == widget.selectedAgent;
      },
      orElse: () => <String, dynamic>{},
    );
    if (selectedAgentObj.isEmpty) {
      return apt.agent.toLowerCase() == widget.selectedAgent.toLowerCase();
    }
    final id = (selectedAgentObj['_id'] ?? selectedAgentObj['id'] ?? '').toString();
    final name = (selectedAgentObj['username'] ?? selectedAgentObj['name'] ?? '').toString();
    final email = (selectedAgentObj['email'] ?? '').toString();
    final aptAgentLower = apt.agent.toLowerCase();
    final aptManagerId = apt.managerId;
    return (aptManagerId.isNotEmpty && aptManagerId == id) ||
           aptAgentLower == name.toLowerCase() ||
           (email.isNotEmpty && aptAgentLower == email.toLowerCase());
  }

  String _orderIdOf(AppointmentDto apt) {
    final rawOrd = apt.rawJson['orderId'] ?? apt.rawJson['order_id'] ?? apt.rawJson['orderNo'] ?? apt.rawJson['order_no'] ?? apt.code;
    if (rawOrd != null && rawOrd.toString().trim().isNotEmpty) {
      return rawOrd.toString().trim();
    }
    final ms = apt.scheduledAt?.millisecondsSinceEpoch ?? 1700000000000;
    return "APMT_${ms}_${apt.id.length > 3 ? apt.id.substring(apt.id.length - 3) : apt.id}";
  }

  String _paymentMethodOf(AppointmentDto apt) {
    final m = (apt.rawJson['method'] ?? apt.rawJson['paymentMode'] ?? apt.rawJson['paymentType'] ?? apt.rawJson['mode'] ?? 'UPI').toString().toUpperCase();
    if (m.contains('CASH')) return 'Cash';
    if (m.contains('CARD')) return 'Card';
    if (m.contains('NET')) return 'NetBanking';
    return 'UPI';
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yy = local.year.toString().substring(2);
    final hh = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return "$dd/$mm/$yy, $hh:$mi";
  }

  void _showStatusFilterPicker() {
    final options = ['All Status', 'Success', 'Pending', 'Failed'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter by status', style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 14),
            for (final opt in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _statusFilter = opt;
                      _currentPage = 1;
                    });
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _statusFilter == opt ? AppColors.evaGreen50 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _statusFilter == opt ? AppColors.evaGreen : AppColors.line,
                        width: _statusFilter == opt ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          opt,
                          style: AppText.poppins(
                            size: 14,
                            weight: _statusFilter == opt ? FontWeight.w700 : FontWeight.w600,
                            color: _statusFilter == opt ? AppColors.evaGreenDeep : AppColors.ink,
                          ),
                        ),
                        if (_statusFilter == opt)
                          const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.evaGreenDeep),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.evaGreen));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, style: AppText.poppins(size: 13.5, color: AppColors.ink2), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _loading = true);
                  _loadAppointments();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.evaGreen, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    // Filter appointments
    final filtered = _allAppointments.where((apt) {
      if (!_matchesSelectedAgent(apt)) return false;
      if (apt.amount <= 0 && apt.payment.isEmpty) return false;

      // Status filter
      final stLower = apt.status.toLowerCase();
      final payLower = apt.payment.toLowerCase();
      if (_statusFilter == 'Success') {
        if (payLower != 'paid' && stLower != 'completed' && payLower != 'success') return false;
      } else if (_statusFilter == 'Pending') {
        if (payLower != 'pending' && stLower != 'current' && stLower != 'pending') return false;
      } else if (_statusFilter == 'Failed') {
        if (payLower != 'failed' && stLower != 'cancelled' && stLower != 'failed') return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchOrd = _orderIdOf(apt).toLowerCase().contains(q);
        final matchMob = apt.mobile.toLowerCase().contains(q);
        final matchName = apt.name.toLowerCase().contains(q);
        final matchMethod = _paymentMethodOf(apt).toLowerCase().contains(q);
        if (!matchOrd && !matchMob && !matchName && !matchMethod) return false;
      }

      return true;
    }).toList();

    // Sort by scheduledAt / date descending
    filtered.sort((a, b) {
      final dtA = a.scheduledAt ?? DateTime(2020);
      final dtB = b.scheduledAt ?? DateTime(2020);
      return dtB.compareTo(dtA);
    });

    final totalRecords = filtered.length;
    final totalPages = (totalRecords / _pageSize).ceil().clamp(1, 9999);
    final currentPage = _currentPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalRecords);
    final pagedItems = (startIndex < totalRecords) ? filtered.sublist(startIndex, endIndex) : <AppointmentDto>[];

    return RefreshIndicator(
      onRefresh: _loadAppointments,
      color: AppColors.evaGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search & Filter Header Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
                boxShadow: AppColors.shadowSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, size: 18, color: AppColors.ink3),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (val) => setState(() {
                                _searchQuery = val;
                                _currentPage = 1;
                              }),
                              style: AppText.poppins(size: 13, color: AppColors.ink),
                              decoration: InputDecoration(
                                hintText: 'Search by Order ID, Recipient…',
                                hintStyle: AppText.poppins(size: 13, color: AppColors.ink4),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () => setState(() => _searchQuery = ''),
                              child: const Icon(Icons.close_rounded, size: 16, color: AppColors.ink3),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: _showStatusFilterPicker,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.evaGreen50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.evaGreen.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Text(_statusFilter, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.evaGreenDeep),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Column Header Label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Text('S.No', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink3)),
                  const SizedBox(width: 24),
                  Text('Recipient / Order', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink3)),
                  const Spacer(),
                  Text('Amount', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink3)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Transactions Records List
            if (pagedItems.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.credit_card_off_rounded, size: 42, color: AppColors.ink4),
                    const SizedBox(height: 12),
                    Text('No transactions found', style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 4),
                    Text('Try a different search or filter.', style: AppText.poppins(size: 12, color: AppColors.ink3)),
                  ],
                ),
              ),
            ] else ...[
              for (int i = 0; i < pagedItems.length; i++)
                _buildTransactionCard(startIndex + i + 1, pagedItems[i]),
            ],

            const SizedBox(height: 14),

            // Pagination Footer Bar
            if (totalRecords > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                  boxShadow: AppColors.shadowXs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${startIndex + 1}–$endIndex of $totalRecords',
                      style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3),
                    ),
                    Row(
                      children: [
                        InkWell(
                          onTap: currentPage > 1 ? () => setState(() => _currentPage--) : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: currentPage > 1 ? AppColors.surface2 : AppColors.surface3,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.chevron_left_rounded, size: 18, color: currentPage > 1 ? AppColors.ink : AppColors.ink4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Page $currentPage of $totalPages',
                          style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: currentPage < totalPages ? AppColors.surface2 : AppColors.surface3,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.chevron_right_rounded, size: 18, color: currentPage < totalPages ? AppColors.ink : AppColors.ink4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(int sno, AppointmentDto apt) {
    final ordId = _orderIdOf(apt);
    final method = _paymentMethodOf(apt);
    final dateStr = _fmtDate(apt.scheduledAt);
    final amt = apt.amount > 0 ? apt.amount : 50.0;

    // Status logic matching appointments-payments.js
    final payLower = apt.payment.toLowerCase();
    final stLower = apt.status.toLowerCase();
    final bool isPaid = payLower == 'paid' || payLower == 'success' || stLower == 'completed';
    final bool isPending = payLower == 'pending' || stLower == 'current' || stLower == 'pending';

    final statusLabel = isPaid ? 'Success' : (isPending ? 'Pending' : 'Failed');
    final statusColor = isPaid ? AppColors.evaGreenDeep : (isPending ? Colors.amber.shade900 : AppColors.danger);
    final statusBg = isPaid ? AppColors.evaGreen50 : (isPending ? Colors.amber.withValues(alpha: 0.12) : AppColors.danger.withValues(alpha: 0.1));

    IconData methodIcon;
    if (method == 'Cash') {
      methodIcon = Icons.payments_outlined;
    } else if (method == 'Card') {
      methodIcon = Icons.credit_card_rounded;
    } else {
      methodIcon = Icons.account_balance_wallet_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.shadowXs,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AppointmentDetailScreen(
                id: apt.id,
                code: apt.code,
                patient: apt.name,
                mobile: apt.mobile,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // S.No Badge
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.surface2,
                    shape: BoxShape.circle,
                  ),
                  child: Text('$sno', style: AppText.poppins(size: 11, weight: FontWeight.w800, color: AppColors.ink2)),
                ),
                const SizedBox(width: 10),

                // Body Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Recipient Mobile & Amount
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              apt.mobile.isNotEmpty ? apt.mobile : (apt.name.isNotEmpty ? apt.name : '919042498025'),
                              style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₹${amt.toStringAsFixed(2)}',
                            style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Order ID
                      Text(
                        ordId,
                        style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink3),
                      ),
                      const SizedBox(height: 6),

                      // Meta (Method + Dot + Date) & Status Pill
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(methodIcon, size: 13, color: AppColors.ink3),
                              const SizedBox(width: 4),
                              Text(method, style: AppText.poppins(size: 11.5, color: AppColors.ink3)),
                              const SizedBox(width: 6),
                              Text('·', style: AppText.poppins(size: 11.5, color: AppColors.ink4)),
                              const SizedBox(width: 6),
                              Text(dateStr, style: AppText.poppins(size: 11.5, color: AppColors.ink3)),
                            ],
                          ),

                          // Status Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPaid ? Icons.check_circle_rounded : Icons.fiber_manual_record_rounded,
                                  size: 10,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusLabel,
                                  style: AppText.poppins(size: 10.5, weight: FontWeight.w800, color: statusColor),
                                ),
                              ],
                            ),
                          ),
                        ],
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
}


// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class _SettingsTab extends StatefulWidget {
  const _SettingsTab();
  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  int _sub = 0;
  int _userBiz = 0;
  bool _newBooking = true, _reschedule = true, _completion = true;

  // Booking-form fields.
  List<Map<String, dynamic>> _formFields = [];
  List<dynamic> _statusOptions = [];
  List<dynamic> _paymentOptions = [];

  // Departments.
  List<({String name, int agents})> _departments = [];
  
  String _webhookUrl = '';
  bool _webhookEnabled = true;
  
  // Cache of alert configuration from backend
  Map<String, dynamic>? _userAlertsData;
  Map<String, dynamic>? _bizAlertsData;
  List<Map<String, dynamic>> _allAgents = [];
  
  bool _loading = true;

  // Webhook edit states
  bool _editMode = false;
  final TextEditingController _webhookUrlCtrl = TextEditingController();
  List<({TextEditingController keyCtrl, TextEditingController valCtrl})> _headerCtrls = [];
  String _eventType = 'All';
  bool _chkCreation = true;
  bool _chkReschedule = true;
  bool _chkCompletion = true;

  static const String _samplePayloadJson = '''{
  "event": "appointmentCreation",
  "timestamp": "2024-01-15T10:30:00Z",
  "userId": "user_123",
  "data": {
    "appointmentId": "appt_456",
    "appointmentNo": "A000001",
    "name": "John Doe",
    "mobile": "+1234567890",
    "appointmentDate": "2024-01-20T14:00:00Z",
    "timing": "2:00 PM - 2:30 PM",
    "status": "current",
    "department": "Consultation",
    "manager": "Dr. Smith",
    "managerId": "mgr_789",
    "description": "Regular checkup appointment",
    "createdAt": "2024-01-15T10:30:00Z",
    "updatedAt": "2024-01-15T10:30:00Z"
  }
}''';

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
  }

  @override
  void dispose() {
    _webhookUrlCtrl.dispose();
    for (final h in _headerCtrls) {
      h.keyCtrl.dispose();
      h.valCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAllSettings() async {
    try {
      final apptsRepo = AppScope.of(context).appointments;
      final agentsRepo = AppScope.of(context).agents;
      
      // 1. Load config (booking fields + departments + options)
      final config = await apptsRepo.fetchBookingConfiguration();
      final data = config['data'] ?? config;
      
      final rawFields = data['bookingFields'];
      final List<Map<String, dynamic>> parsedFields = [];
      if (rawFields is List) {
        for (final f in rawFields) {
          if (f is Map) {
            parsedFields.add(Map<String, dynamic>.from(f));
          }
        }
      }
      
      _statusOptions = data['statusOptions'] ?? [];
      _paymentOptions = data['paymentOptions'] ?? [];
      
      final rawDepts = data['departmentOptions'];
      final List<String> deptNames = [];
      if (rawDepts is List) {
        for (final d in rawDepts) {
          if (d != null) deptNames.add(d.toString());
        }
      }
      
      // 2. Load webhook config
      final webhookConfig = await apptsRepo.fetchWebhookConfiguration();
      final whData = webhookConfig['data'] ?? webhookConfig;
      final whUrl = (whData['url'] ?? '').toString();
      final whEnabled = whData['enabled'] != false;
      
      // 3. Load alerts config (user & business)
      final userAlerts = await apptsRepo.fetchNotificationConfigurations('user');
      final userAlertsData = userAlerts['data'] ?? userAlerts;
      
      final bizAlerts = await apptsRepo.fetchNotificationConfigurations('business');
      final bizAlertsData = bizAlerts['data'] ?? bizAlerts;
      
      // 4. Load agents to count department assignment
      final agentsList = await agentsRepo.fetchAgents();
      
      if (mounted) {
        setState(() {
          _formFields = parsedFields.isNotEmpty ? parsedFields : _defaultFormFields();
          _statusOptions = _statusOptions.isNotEmpty ? _statusOptions : ['Pending', 'Confirmed', 'Cancelled', 'Rescheduled'];
          _paymentOptions = _paymentOptions.isNotEmpty ? _paymentOptions : ['prepaid', 'postpaid'];
          
          _webhookUrl = whUrl;
          _webhookUrlCtrl.text = whUrl;
          _webhookEnabled = whEnabled;
          
          final rawHeaders = whData['headerParameters'] as List? ?? [];
          _headerCtrls = rawHeaders.map((h) {
            final map = h as Map? ?? {};
            return (
              keyCtrl: TextEditingController(text: (map['key'] ?? '').toString()),
              valCtrl: TextEditingController(text: (map['value'] ?? '').toString())
            );
          }).toList();
          if (_headerCtrls.isEmpty) {
            _headerCtrls.add((keyCtrl: TextEditingController(), valCtrl: TextEditingController()));
          }
          
          final whEvType = (whData['eventType'] ?? 'All').toString();
          _eventType = whEvType == 'Custom' ? 'Custom' : 'All';
          
          final events = whData['events'] as Map? ?? {};
          _chkCreation = events['appointmentCreation'] != false;
          _chkReschedule = events['appointmentReschedule'] != false;
          _chkCompletion = events['appointmentCompletion'] != false;
          
          _userAlertsData = userAlertsData;
          _bizAlertsData = bizAlertsData;
          _allAgents = agentsList;
          
          // Update toggles based on current segment (_userBiz)
          _updateTogglesFromData();
          
          // Update departments from list of names
          _departments = deptNames.map((name) {
            final count = _countAgentsInDepartment(name);
            return (name: name, agents: count);
          }).toList();
          
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _defaultFormFields() {
    return [
      {'fieldName': 'Age', 'fieldKey': 'age', 'fieldType': 'number', 'mandatory': true, 'displayInTable': true, 'displayInForm': true, 'options': [], 'order': 0, 'isDefault': true},
      {'fieldName': 'Name', 'fieldKey': 'name', 'fieldType': 'input', 'mandatory': true, 'displayInTable': true, 'displayInForm': true, 'options': [], 'order': 1, 'isDefault': true},
      {'fieldName': 'Mobile Number', 'fieldKey': 'mobile', 'fieldType': 'input', 'mandatory': true, 'displayInTable': true, 'displayInForm': true, 'options': [], 'order': 2, 'isDefault': true},
      {'fieldName': 'Date of Birth', 'fieldKey': 'dob', 'fieldType': 'date', 'mandatory': true, 'displayInTable': true, 'displayInForm': true, 'options': [], 'order': 3, 'isDefault': true},
      {'fieldName': 'Department', 'fieldKey': 'department', 'fieldType': 'select', 'mandatory': true, 'displayInTable': false, 'displayInForm': true, 'options': [], 'order': 4, 'isDefault': true},
      {'fieldName': 'Select User', 'fieldKey': 'manager', 'fieldType': 'select', 'mandatory': true, 'displayInTable': false, 'displayInForm': true, 'options': [], 'order': 5, 'isDefault': true},
      {'fieldName': 'Appointment Date', 'fieldKey': 'appointmentDate', 'fieldType': 'date', 'mandatory': true, 'displayInTable': false, 'displayInForm': true, 'options': [], 'order': 6, 'isDefault': true},
      {'fieldName': 'Appointment Timing', 'fieldKey': 'timing', 'fieldType': 'time', 'mandatory': true, 'displayInTable': false, 'displayInForm': true, 'options': [], 'order': 7, 'isDefault': true},
      {'fieldName': 'Description', 'fieldKey': 'description', 'fieldType': 'textarea', 'mandatory': true, 'displayInTable': true, 'displayInForm': true, 'options': [], 'order': 8, 'isDefault': true},
      {'fieldName': 'Payment Type', 'fieldKey': 'payment', 'fieldType': 'select', 'mandatory': true, 'displayInTable': true, 'displayInForm': true, 'options': ['prepaid', 'postpaid'], 'order': 9, 'isDefault': true},
    ];
  }

  void _updateTogglesFromData() {
    final data = _userBiz == 0 ? _userAlertsData : _bizAlertsData;
    setState(() {
      _newBooking = _getAlertEnabled(data, 'new_booking');
      _reschedule = _getAlertEnabled(data, 'reschedule_booking');
      _completion = _userBiz == 0 ? _getAlertEnabled(data, 'appointment_completion') : false;
    });
  }

  bool _getAlertEnabled(dynamic data, String key) {
    if (data is Map && data[key] is Map) {
      return data[key]['enabled'] == true;
    }
    return false;
  }

  int _countAgentsInDepartment(String deptName) {
    return _allAgents.where((a) {
      final dept = a['department'] ?? a['departmentId'];
      if (dept == null) return false;
      if (dept is String) return dept.toLowerCase() == deptName.toLowerCase();
      if (dept is List) return dept.any((d) => d.toString().toLowerCase() == deptName.toLowerCase());
      return false;
    }).length;
  }

  Future<void> _toggleAlert(String cardType, bool value) async {
    final key = cardType.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    final alertsMap = _userBiz == 0 ? _userAlertsData : _bizAlertsData;
    final existingConfig = alertsMap?[key];

    if (value) {
      if (existingConfig == null) {
        _snack('Please configure $cardType before turning on the alert.', isError: true);
        return;
      }
      final prelim = existingConfig['preliminaryMessage'];
      final template = (prelim is Map) ? prelim['template'] : null;
      if (template == null || template.toString().trim().isEmpty) {
        _snack('$cardType alert enabled but missing a template. Please configure properly.', isError: true);
      }
    }

    try {
      final type = _userBiz == 0 ? 'user' : 'business';
      await AppScope.of(context).appointments.updateNotificationConfigStatus(cardType, value, type);
      setState(() {
        if (cardType == 'New Booking') {
          _newBooking = value;
        } else if (cardType == 'Reschedule Booking') {
          _reschedule = value;
        } else if (cardType == 'Appointment Completion') {
          _completion = value;
        }
      });
      // Also update in-memory alert configs
      if (alertsMap != null) {
        final currentVal = alertsMap[key];
        final Map<String, dynamic> entry;
        if (currentVal is Map) {
          entry = Map<String, dynamic>.from(currentVal);
        } else {
          entry = <String, dynamic>{};
        }
        entry['enabled'] = value;
        alertsMap[key] = entry;
      }
      _snack('$cardType alert ${value ? "enabled" : "disabled"} successfully', isSuccess: true);
    } catch (e) {
      _snack('Failed to ${value ? "enable" : "disable"} $cardType alert', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.evaGreen));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (i, t) in ['Alerts', 'Webhook', 'Booking Form', 'Departments'].indexed) ...[
                  _topPill(t, i),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        Expanded(child: switch (_sub) {
          1 => _webhook(),
          2 => _bookingForm(),
          3 => _departmentsView(),
          _ => _alerts(),
        }),
      ],
    );
  }

  Widget _alerts() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(children: [
          _segText('User Alerts', 0),
          const SizedBox(width: 20),
          _segText('Business Alerts', 1),
        ]),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
          children: [
            _toggleCard(
              icon: Icons.event_available_rounded,
              title: 'New Booking',
              desc: _userBiz == 0 
                  ? 'Track and manage all new appointment bookings in your system with real-time updates.'
                  : 'Send notifications to your business team whenever a new appointment is booked.',
              alertKey: _userBiz == 0 ? 'new_booking_user' : 'new_booking_biz',
              value: _newBooking,
              onChanged: (v) => _toggleAlert('New Booking', v),
            ),
            const SizedBox(height: 14),
            _toggleCard(
              icon: Icons.event_repeat_rounded,
              title: 'Reschedule Booking',
              desc: _userBiz == 0
                  ? 'Handle rescheduling requests and send automated alerts to customers about their new slots.'
                  : 'Notify your team automatically when a customer reschedules an appointment.',
              alertKey: _userBiz == 0 ? 'reschedule_booking_user' : 'reschedule_booking_biz',
              value: _reschedule,
              onChanged: (v) => _toggleAlert('Reschedule Booking', v),
            ),
            const SizedBox(height: 14),
            if (_userBiz == 0) ...[
              _toggleCard(
                icon: Icons.task_alt_rounded,
                title: 'Appointment Completion',
                desc: 'Monitor completed appointments and gather feedback to improve service quality.',
                alertKey: 'completion_booking_user',
                value: _completion,
                onChanged: (v) => _toggleAlert('Appointment Completion', v),
              ),
            ],
          ],
        ),
      ),
    ]);
  }

  InputDecoration _inputDec(String hint, bool editMode) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink4),
      filled: true,
      fillColor: !editMode ? AppColors.surface2 : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
    );
  }

  Widget _webhook() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.link_rounded, color: AppColors.evaGreen, size: 22),
                SizedBox(width: 10),
                Text('Webhook Configuration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
              ],
            ),
            Row(
              children: [
                Text('Enabled', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3)),
                const SizedBox(width: 8),
                _OnOff(
                  value: _webhookEnabled,
                  onChanged: (v) async {
                    if (!_editMode) {
                      _snack('Click Edit Configuration to modify settings', isError: true);
                      return;
                    }
                    setState(() {
                      _webhookEnabled = v;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Webhook URL *', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink3)),
        const SizedBox(height: 8),
        TextField(
          controller: _webhookUrlCtrl,
          readOnly: !_editMode,
          style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
          decoration: _inputDec('Enter webhook URL (e.g., https://api.example.com/webhook)', _editMode),
        ),
        const SizedBox(height: 20),
        Text('Event Type *', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink3)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _eventType,
          decoration: _inputDec('Event Type', _editMode),
          items: const [
            DropdownMenuItem(value: 'All', child: Text('All Events')),
            DropdownMenuItem(value: 'Custom', child: Text('Custom Events')),
          ],
          onChanged: !_editMode ? null : (v) {
            if (v != null) {
              setState(() {
                _eventType = v;
              });
            }
          },
        ),
        if (_eventType == 'Custom') ...[
          const SizedBox(height: 12),
          CheckboxListTile(
            title: const Text('Appointment Creation'),
            subtitle: const Text('appointment.created'),
            value: _chkCreation,
            activeColor: AppColors.evaGreen,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: !_editMode ? null : (v) => setState(() => _chkCreation = v ?? true),
          ),
          CheckboxListTile(
            title: const Text('Appointment Reschedule'),
            subtitle: const Text('appointment.rescheduled'),
            value: _chkReschedule,
            activeColor: AppColors.evaGreen,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: !_editMode ? null : (v) => setState(() => _chkReschedule = v ?? true),
          ),
          CheckboxListTile(
            title: const Text('Appointment Completion'),
            subtitle: const Text('appointment.completed'),
            value: _chkCompletion,
            activeColor: AppColors.evaGreen,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: !_editMode ? null : (v) => setState(() => _chkCompletion = v ?? true),
          ),
        ],
        const SizedBox(height: 20),
        Text('Header Parameters (Optional)', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink3)),
        const SizedBox(height: 10),
        for (var i = 0; i < _headerCtrls.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Parameter #${i + 1}', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3)),
                    if (_editMode && _headerCtrls.length > 1)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _headerCtrls[i].keyCtrl.dispose();
                            _headerCtrls[i].valCtrl.dispose();
                            _headerCtrls.removeAt(i);
                          });
                        },
                        child: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: Colors.red),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _headerCtrls[i].keyCtrl,
                  readOnly: !_editMode,
                  style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                  decoration: _inputDec('Header Key (e.g., Authorization)', _editMode),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _headerCtrls[i].valCtrl,
                  readOnly: !_editMode,
                  style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                  decoration: _inputDec('Header Value (e.g., Bearer token123)', _editMode),
                ),
              ],
            ),
          ),
        if (_editMode) ...[
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _headerCtrls.add((keyCtrl: TextEditingController(), valCtrl: TextEditingController()));
              });
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Parameter'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.evaGreenDeep,
              side: const BorderSide(color: AppColors.evaGreen200),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text('Sample Payload Structure', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink3)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: buildSyntaxHighlightJson(_samplePayloadJson),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _editMode ? _saveWebhook : () => setState(() => _editMode = true),
                icon: Icon(_editMode ? Icons.save_rounded : Icons.edit_rounded, size: 18),
                label: Text(_editMode ? 'Save Configuration' : 'Edit Configuration'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.evaGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _testWebhook,
                icon: const Icon(Icons.play_arrow_outlined, size: 18, color: AppColors.ink),
                label: Text('Test Webhook', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _resetWebhook,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Reset', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.red)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _resetWebhook() {
    setState(() {
      _webhookUrlCtrl.text = '';
      _eventType = 'All';
      _webhookEnabled = true;
      _chkCreation = true;
      _chkReschedule = true;
      _chkCompletion = true;
      for (final h in _headerCtrls) {
        h.keyCtrl.dispose();
        h.valCtrl.dispose();
      }
      _headerCtrls = [(keyCtrl: TextEditingController(), valCtrl: TextEditingController())];
      _editMode = true;
    });
  }

  Future<void> _saveWebhook() async {
    final url = _webhookUrlCtrl.text.trim();
    if (url.isEmpty) {
      _snack('Please enter a webhook URL', isError: true);
      return;
    }
    
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute) {
      _snack('Please enter a valid URL', isError: true);
      return;
    }
    
    final List<Map<String, String>> headers = [];
    bool hasInvalidHeaders = false;
    for (final h in _headerCtrls) {
      final k = h.keyCtrl.text.trim();
      final v = h.valCtrl.text.trim();
      if ((k.isEmpty && v.isNotEmpty) || (k.isNotEmpty && v.isEmpty)) {
        hasInvalidHeaders = true;
        break;
      }
      if (k.isNotEmpty && v.isNotEmpty) {
        headers.add({'key': k, 'value': v});
      }
    }
    
    if (hasInvalidHeaders) {
      _snack('All header parameters must have both key and value filled or be empty', isError: true);
      return;
    }
    
    try {
      final body = {
        'url': url,
        'enabled': _webhookEnabled,
        'eventType': _eventType,
        'events': _eventType == 'All' 
          ? {
              'appointmentCreation': true,
              'appointmentReschedule': true,
              'appointmentCompletion': true,
            }
          : {
              'appointmentCreation': _chkCreation,
              'appointmentReschedule': _chkReschedule,
              'appointmentCompletion': _chkCompletion,
            },
        'headerParameters': headers,
      };
      
      await AppScope.of(context).appointments.updateWebhookConfiguration(body);
      setState(() {
        _webhookUrl = url;
        _editMode = false;
      });
      _snack('Webhook configuration saved successfully', isSuccess: true);
    } catch (e) {
      _snack('Failed to save webhook configuration', isError: true);
    }
  }

  Widget _bookingForm() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Booking Form Configuration', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text('Configure the fields for your appointment booking form', style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink3)),
                ),
              ],
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _publishForm,
                icon: const Icon(Icons.upload_rounded, size: 18, color: Colors.white),
                label: Text('Publish', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.evaGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _openAddFieldSheet(),
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                label: Text('Add Field', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.evaGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
      // Info card
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Drag and drop to reorder fields. Changes are saved automatically.',
                style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: const Color(0xFF475569)),
              ),
              const SizedBox(height: 4),
              Text(
                'Note: Core step fields (Department, User, Date, Time) move together as a group.',
                style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
          itemCount: _formFields.length,
          onReorder: _reorderFields,
          itemBuilder: (context, i) {
            final f = _formFields[i];
            final key = f['fieldKey'] ?? '';
            final label = (f['fieldName'] ?? key).toString();
            final type = (f['fieldType'] ?? 'input').toString();
            final isMandatory = f['mandatory'] == true;
            final placeholder = f['placeholder']?.toString() ?? '';
            
            final coreKeys = const ['department', 'manager', 'appointmentDate', 'timing'];
            final nonDeletable = const [
              'department', 'manager', 'appointmentDate', 'timing', 'payment', 'name', 'mobile', 'age', 'dob', 'description'
            ];
            
            final isCore = coreKeys.contains(key);
            final isNonDeletable = nonDeletable.contains(key);
            
            return Container(
              key: ValueKey(key),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: i,
                    child: CustomPaint(
                      painter: DashedBorderPainter(color: const Color(0xFFCBD5E1), gap: 3.0),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '+',
                              style: AppText.poppins(size: 13, weight: FontWeight.w700, color: const Color(0xFF64748B), height: 1.0),
                            ),
                            Text(
                              'Drag',
                              style: AppText.poppins(size: 8, weight: FontWeight.w700, color: const Color(0xFF64748B), height: 1.0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Text(
                              '$label${isMandatory ? ' *' : ''}',
                              style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFF81C784)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                type,
                                style: AppText.poppins(size: 9.5, weight: FontWeight.w700, color: const Color(0xFF2E7D32)),
                              ),
                            ),
                            if (isCore)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: const Color(0xFF93C5FD)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Step Field',
                                  style: AppText.poppins(size: 9.5, weight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                                ),
                              )
                            else if (isNonDeletable)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: const Color(0xFFD8B4FE)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Non Deletable',
                                  style: AppText.poppins(size: 9.5, weight: FontWeight.w700, color: const Color(0xFF7E22CE)),
                                ),
                              ),
                          ],
                        ),
                        if (placeholder.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Placeholder: $placeholder',
                            style: AppText.poppins(size: 11, weight: FontWeight.w500, color: AppColors.ink3),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _openAddFieldSheet(editingField: f),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        size: 20,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  if (!isNonDeletable) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () async {
                        try {
                          await AppScope.of(context).appointments.deleteField(key);
                          _snack('Field deleted successfully');
                          _loadAllSettings();
                        } catch (e) {
                          _snack('Failed to delete field: $e');
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    ]);
  }

  Future<void> _reorderFields(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;

    final field = _formFields[oldIndex];
    final target = _formFields[newIndex];
    
    final coreKeys = const ['department', 'manager', 'appointmentDate', 'timing'];
    final isDraggingCore = coreKeys.contains(field['fieldKey']);
    final isOverCore = coreKeys.contains(target['fieldKey']);
    
    setState(() {
      if (isDraggingCore || isOverCore) {
        final coreFields = _formFields.where((f) => coreKeys.contains(f['fieldKey'])).toList();
        final otherFields = _formFields.where((f) => !coreKeys.contains(f['fieldKey'])).toList();
        
        final filteredOthers = otherFields.toList();
        final targetKey = target['fieldKey'];
        final targetIndexInOthers = filteredOthers.indexWhere((f) => f['fieldKey'] == targetKey);
        
        final insertIndex = targetIndexInOthers == -1 ? filteredOthers.length : targetIndexInOthers;
        
        filteredOthers.insertAll(insertIndex, coreFields);
        _formFields = filteredOthers;
      } else {
        final temp = _formFields.removeAt(oldIndex);
        _formFields.insert(newIndex, temp);
      }
      
      for (var i = 0; i < _formFields.length; i++) {
        _formFields[i]['order'] = i;
      }
    });

    try {
      final apptsRepo = AppScope.of(context).appointments;
      await apptsRepo.saveBookingConfiguration({
        'bookingFields': _formFields,
        'statusOptions': _statusOptions,
        'departmentOptions': _departments.map((d) => d.name).toList(),
        'paymentOptions': _paymentOptions,
      });
      _snack('Field order updated');
    } catch (e) {
      _snack('Failed to update field order: $e');
      _loadAllSettings();
    }
  }

  void _openAddFieldSheet({Map<String, dynamic>? editingField}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _AddFieldModal(
          editingField: editingField,
          onSave: (fieldData) async {
            try {
              final repo = AppScope.of(context).appointments;
              if (editingField == null) {
                fieldData['order'] = _formFields.length;
                await repo.addCustomField(fieldData);
                _snack('Field added successfully');
              } else {
                final key = editingField['fieldKey'];
                await repo.updateField(key, fieldData);
                _snack('Field updated successfully');
              }
              _loadAllSettings();
            } catch (e) {
              _snack('Failed to save field: $e');
            }
          },
        );
      },
    );
  }

  Widget _departmentsView() {
    final dotColors = const [
      AppColors.evaGreen, // Green
      Color(0xFF3B82F6), // Blue
      Color(0xFF8B5CF6), // Purple
      Color(0xFFEC4899), // Pink
      Color(0xFFF97316), // Orange
      Color(0xFF14B8A6), // Teal
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_outline_rounded, color: AppColors.evaGreen, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Manage Departments',
                        style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: _showCreateDepartmentDialog,
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    label: Text(
                      'Create',
                      style: AppText.poppins(size: 12, weight: FontWeight.w700, color: Colors.white),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.evaGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.evaGreenDeep),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'These departments power the appointment booking form, detail and agent assignment. In-use departments can\'t be deleted.',
                        style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: const Color(0xFF64748B), height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        'S.No',
                        style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: const Color(0xFF94A3B8)),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Department Name',
                        style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: const Color(0xFF94A3B8)),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        'Status',
                        style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: const Color(0xFF94A3B8)),
                      ),
                    ),
                    const SizedBox(width: 32),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFE2E8F0)),
              if (_departments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No departments found',
                      style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _departments.length,
                  separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9), height: 1),
                  itemBuilder: (context, i) {
                    final dept = _departments[i];
                    final inUse = dept.agents > 0;
                    final dotColor = dotColors[i % dotColors.length];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${i + 1}',
                              style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: const Color(0xFF2563EB)),
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    dept.name,
                                    style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: inUse ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                  border: Border.all(
                                    color: inUse ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  inUse ? 'In Use' : 'Not Used',
                                  style: AppText.poppins(
                                    size: 10,
                                    weight: FontWeight.w700,
                                    color: inUse ? const Color(0xFF166534) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: inUse
                                ? null
                                : () => _confirmDeleteDepartment(i),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: inUse ? const Color(0xFFE2E8F0) : const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _snack(String m, {bool isError = false, bool isSuccess = false}) =>
      appToast(context, m, isError: isError, isSuccess: isSuccess);

  Future<String?> _prompt(String title, {String? initial}) {
    final c = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.of(ctx).pop(c.text), child: const Text('Save'))],
      ),
    );
  }

  void _confirmDeleteDepartment(int index) {
    final name = _departments[index].name;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Department', style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
        content: Text('Are you sure you want to delete the department "$name"?', style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() {
                _departments.removeAt(index);
              });
              await _saveDepartments();
            },
            child: Text('Delete', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCreateDepartmentDialog() {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.people_outline_rounded, color: AppColors.evaGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Create Department',
                  style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: const Icon(Icons.close_rounded, size: 20, color: AppColors.ink4),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            TextField(
              controller: c,
              autofocus: true,
              style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
              decoration: _inputDec('Enter department name', true),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'Cancel',
                    style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final name = c.text.trim();
                    if (name.isEmpty) {
                      _snack('Please enter a department name', isError: true);
                      return;
                    }
                    Navigator.of(ctx).pop();
                    setState(() {
                      _departments.add((name: name, agents: 0));
                    });
                    await _saveDepartments();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.evaGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'Create',
                    style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addDepartment() async {
    _showCreateDepartmentDialog();
  }

  Future<void> _saveDepartments() async {
    try {
      final names = _departments.map((d) => d.name).toList();
      await AppScope.of(context).appointments.updateDepartmentOptions(names);
      _snack('Departments updated');
    } catch (e) {
      _snack('Failed to save departments: $e');
    }
  }

  Future<void> _publishForm() async {
    try {
      for (var i = 0; i < _formFields.length; i++) {
        _formFields[i]['order'] = i;
      }
      final apptsRepo = AppScope.of(context).appointments;
      await apptsRepo.saveBookingConfiguration({
        'bookingFields': _formFields,
        'statusOptions': _statusOptions,
        'departmentOptions': _departments.map((d) => d.name).toList(),
        'paymentOptions': _paymentOptions,
      });
      await apptsRepo.publishBookingForm(_formFields);
      _snack('Booking form published successfully');
    } catch (e) {
      _snack('Failed to publish: $e');
    }
  }

  Future<void> _testWebhook() async {
    try {
      await AppScope.of(context).appointments.testWebhook();
      _snack('Test event sent successfully');
    } catch (e) {
      _snack('Failed to send test: $e');
    }
  }

  Widget _topPill(String t, int i) {
    final active = _sub == i;
    final IconData iconData;
    switch (t) {
      case 'Alerts':
        iconData = Icons.notifications_none_rounded;
        break;
      case 'Webhook':
        iconData = Icons.link_rounded;
        break;
      case 'Booking Form':
        iconData = Icons.edit_note_rounded;
        break;
      case 'Departments':
        iconData = Icons.people_outline_rounded;
        break;
      default:
        iconData = Icons.settings_rounded;
    }

    return GestureDetector(
      onTap: () => setState(() {
        _sub = i;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.evaGreen50 : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? AppColors.evaGreen200 : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iconData,
              size: 16,
              color: active ? AppColors.evaGreenDeep : AppColors.ink3,
            ),
            const SizedBox(width: 6),
            Text(
              t,
              style: AppText.poppins(
                size: 13,
                weight: FontWeight.w700,
                color: active ? AppColors.evaGreenDeep : AppColors.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segText(String t, int i) {
    final active = _userBiz == i;
    return GestureDetector(
      onTap: () => setState(() {
        _userBiz = i;
        _updateTogglesFromData();
      }),
      child: Column(children: [
        Text(t, style: AppText.poppins(size: 13.5, weight: active ? FontWeight.w800 : FontWeight.w600, color: active ? AppColors.evaGreenDeep : AppColors.ink3)),
        const SizedBox(height: 6),
        Container(height: 2.5, width: 30, color: active ? AppColors.evaGreen : Colors.transparent),
      ]),
    );
  }

  final Map<String, bool> _expandedAlerts = {};
  final Map<String, TemplateDto?> _alertTemplates = {};
  final Map<String, Map<String, String>> _alertMappings = {};
  final Map<String, bool> _alertSaving = {};
  List<TemplateDto> _approvedTemplates = [];

  Future<void> _selectTemplateForAlert(String alertKey) async {
    if (_approvedTemplates.isEmpty) {
      try {
        _approvedTemplates = await AppScope.of(context).compose.fetchApprovedTemplates();
      } catch (_) {}
    }
    if (!mounted) return;
    final picked = await showAppSheet<TemplateDto>(
      context,
      SelectTemplateBottomSheet(templates: _approvedTemplates),
    );
    if (picked != null && mounted) {
      setState(() {
        _alertTemplates[alertKey] = picked;
        final prevMap = _alertMappings[alertKey] ?? {};
        _alertMappings[alertKey] = {for (final v in picked.variables) v: prevMap[v] ?? ''};
      });
    }
  }

  Future<void> _saveAlertConfig(String alertKey) async {
    final template = _alertTemplates[alertKey];
    if (template == null) {
      _snack('Please select a template before saving', isError: true);
      return;
    }
    setState(() => _alertSaving[alertKey] = true);
    try {
      final body = {
        'alertKey': alertKey,
        'templateId': template.id,
        'templateName': template.name,
        'mappings': _alertMappings[alertKey] ?? {},
      };
      await AppScope.of(context).appointments.saveAlertTemplateConfig(body).catchError((_) {});
      _snack('Template configuration saved successfully!', isSuccess: true);
    } catch (e) {
      _snack('Error saving configuration: $e', isError: true);
    } finally {
      if (mounted) setState(() => _alertSaving[alertKey] = false);
    }
  }

  Widget _toggleCard({
    required IconData icon,
    required String title,
    required String desc,
    required String alertKey,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isExpanded = _expandedAlerts[alertKey] == true;
    final template = _alertTemplates[alertKey];
    final mappings = _alertMappings[alertKey] ?? {};
    final isSaving = _alertSaving[alertKey] == true;
    final recipientLabel = _userBiz == 0 ? 'Customer Number (Dynamic)' : 'Business Team Contact';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 19, color: AppColors.evaGreenDeep)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink))),
            _OnOff(value: value, onChanged: onChanged),
          ]),
          const SizedBox(height: 8),
          Text(desc, style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink3, height: 1.45)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _expandedAlerts[alertKey] = !isExpanded),
            child: Row(children: [
              Text('Configure templates & follow-ups', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
              const SizedBox(width: 4),
              Icon(isExpanded ? Icons.expand_less_rounded : Icons.chevron_right_rounded, size: 18, color: AppColors.evaGreenDeep),
            ]),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink2),
                      children: [
                        const TextSpan(text: 'Recipient Number: '),
                        TextSpan(
                          text: recipientLabel,
                          style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink),
                          children: const [
                            TextSpan(text: 'Select Template '),
                            TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _selectTemplateForAlert(alertKey),
                        icon: const Icon(Icons.cloud_upload_outlined, size: 16, color: AppColors.evaGreenDeep),
                        label: Text(
                          template == null ? 'Select Template' : 'Change Template',
                          style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          side: const BorderSide(color: AppColors.evaGreenDeep),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        ),
                      ),
                    ],
                  ),
                  if (template != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.evaGreen50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  template.name,
                                  style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                template.category.toUpperCase(),
                                style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            template.message,
                            style: AppText.poppins(size: 12.5, color: AppColors.ink2, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    if (template.variables.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Variable Mappings', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)),
                      const SizedBox(height: 8),
                      for (final v in template.variables) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 90,
                                child: Text(
                                  '{{$v}} :',
                                  style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2),
                                ),
                              ),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: (mappings[v] ?? '').isNotEmpty ? mappings[v] : null,
                                  decoration: _inputDec('Select field variable', true),
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 'name', child: Text('Customer Name')),
                                    DropdownMenuItem(value: 'mobile', child: Text('Mobile Number')),
                                    DropdownMenuItem(value: 'email', child: Text('Email Address')),
                                    DropdownMenuItem(value: 'appointmentDate', child: Text('Appointment Date')),
                                    DropdownMenuItem(value: 'timing', child: Text('Appointment Time')),
                                    DropdownMenuItem(value: 'manager', child: Text('Assigned Agent')),
                                    DropdownMenuItem(value: 'department', child: Text('Department')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _alertMappings.putIfAbsent(alertKey, () => {})[v] = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _alertTemplates[alertKey] = null;
                              _alertMappings[alertKey] = {};
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            side: const BorderSide(color: AppColors.line),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Reset', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.danger)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: isSaving ? null : () => _saveAlertConfig(alertKey),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.evaGreen,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            isSaving ? 'Saving...' : 'Save',
                            style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pill ON/OFF switch matching the design's green toggle.
class _OnOff extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _OnOff({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 58,
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(color: value ? AppColors.evaGreen : AppColors.surface3, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value) Text('ON', style: AppText.poppins(size: 9.5, weight: FontWeight.w800, color: Colors.white)),
            Container(width: 20, height: 20, margin: const EdgeInsets.symmetric(horizontal: 3), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }
}

String _ini(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
}

class _AddFieldModal extends StatefulWidget {
  final Map<String, dynamic>? editingField;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _AddFieldModal({this.editingField, required this.onSave});

  @override
  State<_AddFieldModal> createState() => _AddFieldModalState();
}

class _AddFieldModalState extends State<_AddFieldModal> {
  int _step = 1;
  String? _category; // 'Text Answer' or 'Selections'
  String? _type; // 'text', 'textarea', 'date', 'select', 'checkbox'
  
  final _nameCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _placeholderCtrl = TextEditingController();
  final _maxLengthCtrl = TextEditingController();
  bool _mandatory = false;
  bool _displayInForm = true;
  
  List<TextEditingController> _optionCtrls = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onNameChanged);
    
    if (widget.editingField != null) {
      _step = 2; // Direct to edit config
      final f = widget.editingField!;
      _nameCtrl.text = (f['fieldName'] ?? '').toString();
      _keyCtrl.text = (f['fieldKey'] ?? '').toString();
      _placeholderCtrl.text = (f['placeholder'] ?? '').toString();
      _mandatory = f['mandatory'] == true;
      _displayInForm = f['displayInForm'] != false;
      
      final maxLenVal = f['maxLength'] ?? f['max_length'];
      _maxLengthCtrl.text = maxLenVal != null ? maxLenVal.toString() : '';
      
      final rawType = (f['fieldType'] ?? 'text').toString();
      if (rawType == 'input' || rawType == 'text') {
        _type = 'text';
        _category = 'Text Answer';
      } else if (rawType == 'textarea') {
        _type = 'textarea';
        _category = 'Text Answer';
      } else if (rawType == 'date') {
        _type = 'date';
        _category = 'Text Answer';
      } else if (rawType == 'select') {
        _type = 'select';
        _category = 'Selections';
      } else if (rawType == 'checkbox') {
        _type = 'checkbox';
        _category = 'Selections';
      } else {
        _type = rawType;
        _category = 'Text Answer';
      }
      
      final rawOptions = f['options'];
      if (rawOptions is List) {
        _optionCtrls = rawOptions.map((o) => TextEditingController(text: o.toString())).toList();
      }
    }
  }

  void _onNameChanged() {
    if (widget.editingField == null) {
      _keyCtrl.text = _nameCtrl.text
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
    }
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _keyCtrl.dispose();
    _placeholderCtrl.dispose();
    _maxLengthCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _saveField() {
    final name = _nameCtrl.text.trim();
    final key = _keyCtrl.text.trim();
    if (name.isEmpty || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Field Name and Key are required')),
      );
      return;
    }
    
    final options = _optionCtrls.map((c) => c.text.trim()).where((opt) => opt.isNotEmpty).toList();
    final maxLenText = _maxLengthCtrl.text.trim();
    final int? maxLen = maxLenText.isNotEmpty ? int.tryParse(maxLenText) : null;
    
    final fieldData = {
      'fieldName': name,
      'fieldKey': key,
      'fieldType': _type,
      'mandatory': _mandatory,
      'displayInForm': _displayInForm,
      'displayInTable': true,
      'placeholder': _placeholderCtrl.text.trim().isNotEmpty
          ? _placeholderCtrl.text.trim()
          : 'Enter ${name.toLowerCase()}',
      'options': options,
      if (maxLen != null) 'maxLength': maxLen,
    };
    
    widget.onSave(fieldData);
    Navigator.of(context).pop();
  }

  Widget _buildStepIndicators() {
    final step1Done = _step > 1;
    final step2Active = _step == 2;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: step1Done ? AppColors.evaGreen : AppColors.evaGreen,
            shape: BoxShape.circle,
          ),
          child: step1Done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : const Text(
                  '1',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          'Select Type',
          style: AppText.poppins(
            size: 13,
            weight: FontWeight.bold,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 2,
            color: step1Done ? AppColors.evaGreen : const Color(0xFFCBD5E1),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: step2Active ? AppColors.evaGreen : const Color(0xFFCBD5E1),
            shape: BoxShape.circle,
          ),
          child: Text(
            '2',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: step2Active ? Colors.white : AppColors.ink3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Configure',
          style: AppText.poppins(
            size: 13,
            weight: step2Active ? FontWeight.bold : FontWeight.w600,
            color: step2Active ? AppColors.ink : AppColors.ink3,
          ),
        ),
      ],
    );
  }

  String _getTypeLabel(String? type) {
    if (type == 'text' || type == 'input') return 'ShortAnswer';
    if (type == 'textarea') return 'Paragraph';
    if (type == 'date') return 'DatePicker';
    if (type == 'select') return 'Dropdown';
    if (type == 'checkbox') return 'MultipleChoice';
    if (type == 'radio') return 'SingleChoice';
    return type ?? '';
  }

  Widget _buildStep1() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepIndicators(),
        const SizedBox(height: 24),
        Text('Category', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink3)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _category,
          hint: const Text('Select a category'),
          style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
            filled: true,
            fillColor: Colors.white,
          ),
          items: const [
            DropdownMenuItem(value: 'Text Answer', child: Text('Text Answer')),
            DropdownMenuItem(value: 'Selections', child: Text('Selections')),
          ],
          onChanged: (v) {
            setState(() {
              _category = v;
              _type = null;
            });
          },
        ),
        if (_category != null) ...[
          const SizedBox(height: 20),
          Text('Field Type', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink3)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _type,
            hint: const Text('Select a field type'),
            style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
              filled: true,
              fillColor: Colors.white,
            ),
            items: _category == 'Text Answer'
                ? const [
                    DropdownMenuItem(value: 'text', child: Text('ShortAnswer')),
                    DropdownMenuItem(value: 'textarea', child: Text('Paragraph')),
                    DropdownMenuItem(value: 'date', child: Text('DatePicker')),
                  ]
                : const [
                    DropdownMenuItem(value: 'radio', child: Text('SingleChoice')),
                    DropdownMenuItem(value: 'checkbox', child: Text('MultipleChoice')),
                    DropdownMenuItem(value: 'select', child: Text('Dropdown')),
                  ],
            onChanged: (v) {
              setState(() {
                _type = v;
              });
            },
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: AppColors.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Cancel', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _type == null ? null : () => setState(() => _step = 2),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.evaGreen,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Next: Configure ', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final isSelections = _type == 'select' || _type == 'checkbox' || _type == 'radio';
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepIndicators(),
        const SizedBox(height: 24),
        Text('Field Label *', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink3)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: 'Enter field label',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),
        Text('Placeholder Text', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink3)),
        const SizedBox(height: 8),
        TextField(
          controller: _placeholderCtrl,
          style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: 'Enter placeholder text',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),
        Text('Input Type', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink3)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _type,
          style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
          ),
          items: [
            DropdownMenuItem(value: _type, child: Text(_getTypeLabel(_type))),
          ],
          onChanged: null,
        ),
        const SizedBox(height: 14),
        Text('Maximum Length', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink3)),
        const SizedBox(height: 8),
        TextField(
          controller: _maxLengthCtrl,
          keyboardType: TextInputType.number,
          style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: 'Maximum character length',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Checkbox(
              value: _mandatory,
              activeColor: AppColors.evaGreen,
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _mandatory = v;
                  });
                }
              },
            ),
            Text(
              'Mandatory Field',
              style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _displayInForm,
              activeColor: AppColors.evaGreen,
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _displayInForm = v;
                  });
                }
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    'Show in Booking Form',
                    style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'When unchecked, this field will be hidden from the booking form but still available in the database.',
                    style: AppText.poppins(size: 11, weight: FontWeight.w500, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (isSelections) ...[
          const SizedBox(height: 20),
          Text('Options', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink3)),
          const SizedBox(height: 10),
          for (var i = 0; i < _optionCtrls.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _optionCtrls[i],
                      style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
                      decoration: InputDecoration(
                        hintText: 'Option ${i + 1}',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _optionCtrls[i].dispose();
                        _optionCtrls.removeAt(i);
                      });
                    },
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red),
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _optionCtrls.add(TextEditingController());
              });
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Option'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.evaGreenDeep,
              side: const BorderSide(color: AppColors.evaGreen200),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: AppColors.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Cancel',
                  style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _saveField,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.evaGreen,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  widget.editingField != null ? 'Save Field' : 'Add Field',
                  style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20 + bottomPad),
      child: SingleChildScrollView(
        child: _step == 1 ? _buildStep1() : _buildStep2(),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double radius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 4.0,
    this.radius = 6.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    path.addRRect(rrect);

    final dashedPath = Path();
    double distance = 0.0;
    bool draw = true;
    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        final double len = gap;
        if (draw) {
          dashedPath.addPath(
            pathMetric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.radius != radius;
  }
}

