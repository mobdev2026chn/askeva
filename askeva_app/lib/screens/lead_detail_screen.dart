import 'package:flutter/material.dart';

import '../api/app_scope.dart';
import '../api/dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/common.dart';
import '../widgets/conversation_launch.dart';
import '../widgets/dashboard_sheets.dart' show appToast, kNotificationUnreadCount;
import '../widgets/leads_extra.dart';
import '../widgets/leads_sheets.dart';
import 'detail_screens.dart';

/// Shared back-header scaffold for detail screens.
class _DetailScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? bottom;
  final Color? headerBgColor;
  final Color? headerTextColor;
  final List<Widget>? actions;
  const _DetailScaffold({
    required this.title,
    required this.body,
    this.bottom,
    this.headerBgColor,
    this.headerTextColor,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bg = headerBgColor ?? AppColors.surface;
    final fg = headerTextColor ?? AppColors.ink;
    return AnnotatedRegion(
      value: bg == AppColors.surface ? AppTheme.statusDark : AppTheme.statusLight,
      child: Scaffold(
        backgroundColor: AppColors.surface2,
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: bg,
              padding: EdgeInsets.fromLTRB(6, topPad + 8, 16, 14),
              child: Row(
                children: [
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.chevron_left_rounded, size: 28, color: fg)),
                  Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 18, weight: FontWeight.w800, color: fg))),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
            if (bg == AppColors.surface) const Divider(height: 1, color: AppColors.line),
            Expanded(child: body),
            if (bottom != null) bottom!,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lead Details
// ---------------------------------------------------------------------------

class LeadDetailScreen extends StatefulWidget {
  final LeadDto lead;
  const LeadDetailScreen({super.key, required this.lead});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  late LeadDto _currentLead;
  List<Map<String, dynamic>> _auditLogs = [];
  bool _loadingLogs = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentLead = widget.lead;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadLead();
      _loadLogs();
      _markLeadNotificationsRead();
    });
  }

  Future<void> _markLeadNotificationsRead() async {
    try {
      final s = AppScope.of(context);
      final unread = await s.notifications.fetchNotifications(isRead: false, limit: 100);
      final leadId = _currentLead.id;
      final leadName = _currentLead.name.toLowerCase().trim();

      bool markedAny = false;
      for (final n in unread) {
        final d = n.data;
        final notifLeadId = (d['leadId'] ?? d['id'] ?? d['_id'] ?? '').toString();
        final matchesId = notifLeadId.isNotEmpty && notifLeadId == leadId;
        final matchesName = leadName.isNotEmpty &&
            (n.title.toLowerCase().contains(leadName) || n.body.toLowerCase().contains(leadName));
        final isLeadType = n.type.toLowerCase().contains('lead') || n.id.contains('lead');

        if (isLeadType && (matchesId || matchesName)) {
          await s.notifications.markAsRead(n.id);
          markedAny = true;
        }
      }

      if (markedAny && mounted) {
        final newCount = await s.notifications.fetchUnreadCount();
        kNotificationUnreadCount.value = newCount;
      }
    } catch (_) {}
  }

  Future<void> _reloadLead() async {
    try {
      final updated = await AppScope.of(context).leads.fetchLead(_currentLead.id);
      if (mounted) {
        setState(() {
          _currentLead = updated;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await AppScope.of(context).leads.fetchAuditLogs(_currentLead.id);
      if (mounted) {
        setState(() {
          _auditLogs = logs;
          _loadingLogs = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingLogs = false);
      }
    }
  }

  List<Map<String, dynamic>> _getDescriptionHistory() {
    final list = <Map<String, dynamic>>[];
    
    // 1. Collect all description updates from audit logs
    final descriptionUpdates = _auditLogs.where((log) {
      final meta = log['metadata'];
      return log['action'] == 'field_updated' && meta is Map && meta['field'] == 'description';
    }).map((log) {
      final meta = log['metadata'] as Map;
      return {
        'id': log['_id']?.toString() ?? '',
        'dateTime': _formatDateTime(log['createdAt']),
        'description': meta['newValue']?.toString() ?? '',
        'createdAt': log['createdAt']?.toString() ?? '',
        'type': 'update',
      };
    }).toList();

    // 2. Find earliest update to check for oldValue
    final sortedUpdates = List<Map<String, dynamic>>.from(descriptionUpdates);
    sortedUpdates.sort((a, b) {
      final ad = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(0);
      final bd = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(0);
      return ad.compareTo(bd);
    });

    final earliestUpdate = sortedUpdates.isNotEmpty ? sortedUpdates.first : null;
    if (earliestUpdate != null) {
      final firstAuditLog = _auditLogs.firstWhere(
        (log) => log['_id']?.toString() == earliestUpdate['id']?.toString(),
        orElse: () => <String, dynamic>{},
      );
      final meta = firstAuditLog['metadata'];
      final oldValue = (meta is Map ? meta['oldValue'] : null)?.toString();
      if (oldValue != null && oldValue.trim().isNotEmpty) {
        list.add({
          'id': 'initial-${_currentLead.id}',
          'dateTime': _formatDateTime(_currentLead.createdAt),
          'description': oldValue,
          'createdAt': _currentLead.createdAt?.toIso8601String() ?? '',
          'type': 'initial',
        });
      }
    }

    // 3. Fallback: if no oldValue found, use the lead's current description
    if (list.isEmpty && _currentLead.description.trim().isNotEmpty) {
      list.add({
        'id': 'initial-${_currentLead.id}',
        'dateTime': _formatDateTime(_currentLead.createdAt),
        'description': _currentLead.description,
        'createdAt': _currentLead.createdAt?.toIso8601String() ?? '',
        'type': 'initial',
      });
    }

    // 4. Add all updates
    list.addAll(descriptionUpdates);

    // 5. Sort by createdAt (oldest first)
    list.sort((a, b) {
      final ad = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(0);
      final bd = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(0);
      return ad.compareTo(bd);
    });

    return list;
  }

  String _formatDateTime(dynamic dtVal) {
    if (dtVal == null) return '—';
    try {
      final dt = dtVal is DateTime ? dtVal : DateTime.parse(dtVal.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dtVal.toString();
    }
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 8),
          Text(title, style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3)),
        ],
      ),
    );
  }

  Widget _historyRow(String sNo, String dateTime, String description, {bool first = false}) {
    return Container(
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.surface3))),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('S.No: $sNo', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3)),
              Text(dateTime, style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink4)),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final display = _currentLead.name.isEmpty ? (_currentLead.mobile.isEmpty ? 'Unknown' : _currentLead.mobile) : _currentLead.name;
    return _DetailScaffold(
      title: 'Profile Details',
      bottom: Container(
        color: AppColors.surface,
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 14),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.evaGradient, borderRadius: BorderRadius.circular(13)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: _isLoading ? null : () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Convert to Customer', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
                          content: Text('Are you sure you want to convert this lead to a customer? This will also remove the current agent assignment.', style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink2)),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2))),
                            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Convert', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: Theme.of(context).colorScheme.primary))),
                          ],
                        ),
                      );
                      if (ok != true) return;
                      setState(() => _isLoading = true);
                      try {
                        await AppScope.of(context).leads.convertLead(_currentLead.id);
                        if (!mounted) return;
                        appToast(context, 'Converted to customer', isSuccess: true);
                        Navigator.of(context).pop(true);
                      } catch (e) {
                        if (!mounted) return;
                        appToast(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Center(
                        child: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Convert as customer', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  showLeadForm(
                    context,
                    lead: _currentLead,
                    companies: const [],
                    sources: const [],
                    agents: const [],
                  ).then((ok) {
                    if (ok == true) {
                      _reloadLead();
                      _loadLogs();
                    }
                  });
                },
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), side: const BorderSide(color: AppColors.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                child: Text('Edit lead', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink)),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          Row(
            children: [
              InitialsAvatar(initials: _initials(display), color: avatarColorFor(display), size: 52, radius: 15),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(display, style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 6),
                  StatusPill(status: _currentLead.status),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 1. Basic Information
          _sectionHeader(Icons.person_outline_rounded, 'Basic Information'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _infoRow(Icons.account_circle_outlined, 'Name', _currentLead.name.isEmpty ? '—' : _currentLead.name, first: true),
                _infoRow(Icons.phone_outlined, 'Mobile', _currentLead.mobile.isEmpty ? '—' : (_currentLead.countryCode.isNotEmpty ? '+${_currentLead.countryCode} ${_currentLead.mobile}' : _currentLead.mobile)),
                if (_currentLead.company.isNotEmpty) _infoRow(Icons.business_outlined, 'Company', _currentLead.company),
                if (_currentLead.email.isNotEmpty) _infoRow(Icons.email_outlined, 'Email', _currentLead.email),
                if (_currentLead.website.isNotEmpty) _infoRow(Icons.language_rounded, 'Website', _currentLead.website),
                if (_currentLead.tags.isNotEmpty) _infoRow(Icons.sell_outlined, 'Tags', _currentLead.tags.join(', ')),
              ],
            ),
          ),
          
          // 2. Lead Details
          _sectionHeader(Icons.assignment_outlined, 'Lead Details'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _infoRow(Icons.calendar_today_rounded, 'Created At', _formatDateTime(_currentLead.createdAt), first: true),
                _infoRow(Icons.public_rounded, 'Source', _currentLead.source.isEmpty ? 'User Initiated - Whatsapp' : _currentLead.source),
                _infoRow(Icons.label_outline_rounded, 'Status', null, statusChild: StatusPill(status: _currentLead.status)),
                _infoRow(Icons.person_pin_rounded, 'Assigned', _currentLead.assignedTo ?? 'Unassigned'),
                if (_currentLead.position.isNotEmpty) _infoRow(Icons.shopping_bag_outlined, 'Product', _currentLead.position),
                if (_currentLead.value != null) _infoRow(Icons.payments_outlined, 'Lead Value', '₹${_currentLead.value!.toInt()}'),
              ],
            ),
          ),
          
          // 3. Additional Information
          _sectionHeader(Icons.push_pin_outlined, 'Additional Information'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _infoRow(Icons.description_outlined, 'Description', _currentLead.description.isEmpty ? '—' : _currentLead.description, first: true),
                if (_currentLead.address.isNotEmpty) _infoRow(Icons.location_on_outlined, 'Address', _currentLead.address),
                if (_currentLead.country.isNotEmpty) _infoRow(Icons.flag_outlined, 'Country', _currentLead.country),
                if (_currentLead.city.isNotEmpty) _infoRow(Icons.location_city_rounded, 'City', _currentLead.city),
              ],
            ),
          ),
          
          // 4. Description History
          _sectionHeader(Icons.book_outlined, 'Description History'),
          Builder(
            builder: (context) {
              final history = _getDescriptionHistory();
              if (history.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No description changes recorded', style: AppText.poppins(size: 12, color: AppColors.ink4)),
                );
              }
              return AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (int i = 0; i < history.length; i++)
                      _historyRow(
                        '${i + 1}',
                        history[i]['dateTime'] ?? '—',
                        history[i]['description'] ?? '—',
                        first: i == 0,
                      ),
                  ],
                ),
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String k, String? v, {Widget? statusChild, bool first = false}) {
    return Container(
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.surface3))),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.ink3),
          const SizedBox(width: 12),
          Text(k, style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3)),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: statusChild ??
                  Text(v ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Customer Details
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Customer Details
// ---------------------------------------------------------------------------

class CustomerDetailScreen extends StatefulWidget {
  final LeadDto lead;
  const CustomerDetailScreen({super.key, required this.lead});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  int _tab = 0; // 0: Appointments, 1: Ticketing
  bool _loading = true;
  List<AppointmentDto> _appointments = [];
  List<TicketDto> _tickets = [];

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
  }

  String _cleanMobile(String m) => m.replaceAll(RegExp(r'\D'), '');

  bool _mobileMatches(String a, String b) {
    final cleanA = _cleanMobile(a);
    final cleanB = _cleanMobile(b);
    if (cleanA.isEmpty || cleanB.isEmpty) return false;
    if (cleanA == cleanB) return true;
    if (cleanA.length >= 10 && cleanB.length >= 10) {
      return cleanA.endsWith(cleanB.substring(cleanB.length - 10)) ||
             cleanB.endsWith(cleanA.substring(cleanA.length - 10));
    }
    return false;
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadCustomerData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final scope = AppScope.of(context);
      final c = widget.lead;
      final nameLower = c.name.trim().toLowerCase();
      final emailLower = c.email.trim().toLowerCase();

      final allAppointments = await scope.appointments.fetchAppointments().catchError((_) => <AppointmentDto>[]);
      final allTickets = await scope.ticketing.fetchTickets().catchError((_) => <TicketDto>[]);

      final customerApts = allAppointments.where((apt) {
        if (_mobileMatches(apt.mobile, c.mobile)) return true;
        if (nameLower.isNotEmpty && apt.name.trim().toLowerCase() == nameLower) return true;
        return false;
      }).toList();

      final customerTkts = allTickets.where((t) {
        if (_mobileMatches(t.mobile, c.mobile)) return true;
        if (nameLower.isNotEmpty && t.customer.trim().toLowerCase() == nameLower) return true;
        if (emailLower.isNotEmpty && (t.customer.trim().toLowerCase() == emailLower || t.subject.trim().toLowerCase().contains(emailLower))) return true;
        return false;
      }).toList();

      if (mounted) {
        setState(() {
          _appointments = customerApts;
          _tickets = customerTkts;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.lead;
    final name = c.name.isEmpty ? 'Unknown' : c.name;
    String conv(DateTime? d) => d == null ? '—' : '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return _DetailScaffold(
      title: 'Customer Details',
      headerBgColor: Theme.of(context).primaryColor,
      headerTextColor: Colors.white,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: () {
            _loadCustomerData();
            appToast(context, 'Refreshing customer details...');
          },
        ),
      ],
      body: RefreshIndicator(
        color: AppColors.evaGreen,
        onRefresh: () async {
          await _loadCustomerData();
          if (mounted) appToast(context, 'Customer data refreshed');
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            // Customer Details Info Card
            AppCard(
              child: Column(
                children: [
                  Row(children: [
                    Expanded(child: _kv('Name', name)),
                    Expanded(child: _kv('Company', c.company.isEmpty ? 'N/A' : c.company)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _kv('Email', c.email.isEmpty ? 'N/A' : c.email)),
                    Expanded(child: _kv('Mobile', c.mobile.isEmpty ? 'N/A' : '+91 ${c.mobile}')),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _kv('Conversion Date', conv(c.createdAt))),
                    Expanded(child: _kv('Lead Closed By', c.assignedTo ?? 'Unassigned')),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _kv('Source', c.source.isEmpty ? 'Chat-Sync' : c.source)),
                    Expanded(child: _kv('Status', '', statusChild: Row(children: [
                      Icon(Icons.check_rounded, size: 15, color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 5),
                      Text('Converted', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: Theme.of(context).colorScheme.secondary)),
                    ]))),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tabs: Appointments & Ticketing
            Row(children: [
              _tabBtn('Appointments (${_appointments.length})', 0),
              const SizedBox(width: 24),
              _tabBtn('Ticketing (${_tickets.length})', 1),
            ]),
            const SizedBox(height: 16),

            // Content Area
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.evaGreen)),
              )
            else if (_tab == 0) ...[
              if (_appointments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No appointments for this customer.',
                      style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink3),
                    ),
                  ),
                )
              else
                ..._appointments.map(_appointmentCard),
            ] else ...[
              if (_tickets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No tickets for this customer.',
                      style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink3),
                    ),
                  ),
                )
              else
                ..._tickets.map(_ticketCard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _appointmentCard(AppointmentDto apt) {
    final code = apt.code.isEmpty ? 'A${apt.id.substring(0, apt.id.length > 6 ? 6 : apt.id.length)}' : apt.code;
    final isCompleted = apt.status.toLowerCase() == 'completed';
    final isCancelled = apt.status.toLowerCase() == 'cancelled';
    final isRescheduled = apt.status.toLowerCase() == 'rescheduled';
    final statusText = isCompleted ? 'Completed' : (isCancelled ? 'Cancelled' : (isRescheduled ? 'Rescheduled' : (apt.status.isEmpty ? 'Current' : apt.status)));
    final statusColor = isCompleted ? AppColors.evaGreenDeep : (isCancelled ? Colors.red : (isRescheduled ? const Color(0xFFF59E0B) : AppColors.evaGreenDeep));
    final statusBg = isCompleted ? AppColors.evaGreen50 : (isCancelled ? Colors.red.shade50 : (isRescheduled ? const Color(0xFFFFFBEB) : AppColors.evaGreen50));

    final isPrepaid = apt.payment.toLowerCase() == 'prepaid';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AppointmentDetailScreen(
              id: apt.id,
              code: code,
              patient: apt.name.isEmpty ? widget.lead.name : apt.name,
              mobile: apt.mobile.isEmpty ? widget.lead.mobile : apt.mobile,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(code, style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.ink)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    apt.name.isEmpty ? widget.lead.name : apt.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                  child: Text(statusText, style: AppText.poppins(size: 11, weight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.medical_services_outlined, size: 14, color: AppColors.ink4),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    apt.department.isEmpty ? 'Consultation' : apt.department,
                    style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3),
                  ),
                ),
                Text(
                  apt.timing.isEmpty ? '15 mins' : apt.timing,
                  style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.ink4),
                const SizedBox(width: 6),
                Text(
                  _formatDate(apt.scheduledAt),
                  style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3),
                ),
                const Spacer(),
                if (apt.payment.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPrepaid ? AppColors.evaGreen50 : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      apt.payment,
                      style: AppText.poppins(
                        size: 10.5,
                        weight: FontWeight.w700,
                        color: isPrepaid ? AppColors.evaGreenDeep : const Color(0xFFD97706),
                      ),
                    ),
                  ),
              ],
            ),
            if (apt.agent.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 13, color: AppColors.ink4),
                  const SizedBox(width: 6),
                  Text(
                    'Manager: ${apt.agent}',
                    style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink4),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ticketCard(TicketDto t) {
    final statusColor = switch (t.status.toLowerCase()) {
      'pending' => const Color(0xFFD97706),
      'resolved' || 'closed' => AppColors.evaGreenDeep,
      'open' || 'in progress' => const Color(0xFF3B82F6),
      _ => AppColors.ink3,
    };
    final statusBg = switch (t.status.toLowerCase()) {
      'pending' => const Color(0xFFFFFBEB),
      'resolved' || 'closed' => AppColors.evaGreen50,
      'open' || 'in progress' => const Color(0xFFEFF6FF),
      _ => AppColors.surface2,
    };

    final prioColor = switch (t.priority.toLowerCase()) {
      'high' || 'critical' => Colors.red,
      'medium' => const Color(0xFFD97706),
      _ => AppColors.evaGreenDeep,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TicketDetailScreen(
              id: t.id,
              subject: t.subject.isEmpty ? 'Support Ticket' : t.subject,
              agent: t.agent.isEmpty ? 'Unassigned' : t.agent,
              status: t.status,
              priority: t.priority,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(6)),
                  child: Text(t.id, style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.ink)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.customer.isEmpty ? widget.lead.name : t.customer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                  child: Text(t.status, style: AppText.poppins(size: 11, weight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
            if (t.subject.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(t.subject, style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Department: ${t.department.isEmpty ? 'OH' : t.department}', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: prioColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text('Priority: ${t.priority}', style: AppText.poppins(size: 10.5, weight: FontWeight.w700, color: prioColor)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 13, color: AppColors.ink4),
                const SizedBox(width: 6),
                Text(_formatDate(t.createdAt), style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink4)),
                const Spacer(),
                Text('Assigned: ${t.agent.isEmpty ? 'Unassigned' : t.agent}', style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {Widget? statusChild}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
          const SizedBox(height: 4),
          if (statusChild != null) statusChild else Text(v, style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
        ],
      );

  Widget _tabBtn(String label, int i) {
    final active = _tab == i;
    return GestureDetector(
      onTap: () => setState(() => _tab = i),
      child: Column(children: [
        Text(label, style: AppText.poppins(size: 13.5, weight: active ? FontWeight.w800 : FontWeight.w600, color: active ? Theme.of(context).colorScheme.secondary : AppColors.ink3)),
        const SizedBox(height: 6),
        Container(height: 2.5, width: 50, color: active ? Theme.of(context).colorScheme.primary : Colors.transparent),
      ]),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
}
