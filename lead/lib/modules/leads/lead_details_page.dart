import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/leads_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/drawer_menu_icon.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import '../../theme/app_colors.dart';
import '../dashboard/dashboard_page.dart';
import 'lead_template_selection_page.dart';

class LeadDetailsPage extends StatefulWidget {
  final String? leadId;
  const LeadDetailsPage({super.key, this.leadId});

  @override
  State<LeadDetailsPage> createState() => _LeadDetailsPageState();
}

class _LeadDetailsPageState extends State<LeadDetailsPage> {
  late Future<Map<String, dynamic>> _future;
  Map<String, dynamic>? _lastLead;
  int _activityRefreshKey = 0;
  late Future<List<dynamic>> _activityFuture;

  @override
  void initState() {
    super.initState();
    _future = LeadsService.getLead(widget.leadId ?? '');
    _activityFuture = LeadsService.getLeadActivity(widget.leadId ?? '');
  }

  Future<void> _onRefresh() async {
    setState(() {
      _future = LeadsService.getLead(widget.leadId ?? '');
      _activityFuture = LeadsService.getLeadActivity(widget.leadId ?? '');
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      initialIndex:
          4, // Default to Notes (index 4) as it was the focus, change if needed
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: const DrawerMenuIcon(),
          title: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snap) {
              final lead = snap.data ?? {};
              final name = _safeString(lead['name']);
              final onSurface = Theme.of(context).colorScheme.onSurface;
              return Text(
                (name.isNotEmpty && name != '—') ? name : 'Lead Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                ),
              );
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).colorScheme.onSurface.withOpacity(0.85) : Theme.of(context).colorScheme.onSurfaceVariant,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(icon: Icon(Icons.call, size: 20), text: 'Call'),
              Tab(icon: Icon(Icons.notifications_none, size: 20), text: 'Reminders'),
              Tab(icon: Icon(Icons.person_outline, size: 20), text: 'Profile'),
              Tab(icon: Icon(Icons.send_outlined, size: 20), text: 'Template'),
              Tab(icon: Icon(Icons.description_outlined, size: 20), text: 'Notes'),
              Tab(icon: Icon(Icons.history_toggle_off, size: 20), text: 'Activity'),
              Tab(icon: Icon(Icons.phone_forwarded, size: 20), text: 'Logs'),
            ],
          ),
        ),
        drawer: const AppDrawer(),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return RefreshIndicator(
                onRefresh: _onRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(child: Text('Error: ${snap.error}')),
                  ),
                ),
              );
            }
            final lead = snap.data ?? {};
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _lastLead = lead);
            });

            return TabBarView(
              children: [
                _buildCallTab(lead),
                _RemindersTab(leadId: widget.leadId),
                _buildProfileTab(lead),
                _SendTemplateTab(lead: lead),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _NotesTab(leadId: widget.leadId),
                ),
                _buildActivityLogsTab(lead, onRetry: () {
                  setState(() {
                    _activityRefreshKey++;
                    _activityFuture = LeadsService.getLeadActivity(widget.leadId ?? '');
                  });
                }),
                _buildCallLogsTab(lead),
              ],
            );
          },
        ),
        bottomNavigationBar: _buildBottomBar(context),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lead = _lastLead ?? {};
    final isConverted = lead['isConverted'] == true ||
        lead['isCoverted'] == true ||
        (lead['status']?.toString().toLowerCase() == 'converted');
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isConverted)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _onConvertToCustomer,
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text('Convert to Customer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            BottomNavigationBar(
              currentIndex: 1,
              onTap: (idx) => _onBottomNavTap(context, idx),
              selectedItemColor: cs.primary,
              unselectedItemColor: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : cs.onSurfaceVariant,
              type: BottomNavigationBarType.fixed,
              backgroundColor: cs.surface,
              elevation: 0,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people_alt), label: 'Leads'),
                BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Chat'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onConvertToCustomer() async {
    final leadId = widget.leadId;
    if (leadId == null || leadId.isEmpty) return;
    try {
      await LeadsService.convertLeadToCustomer(leadId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lead converted to customer successfully')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _onBottomNavTap(BuildContext context, int index) {
    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardPage(initialIndex: 0)),
        (route) => false,
      );
    } else if (index == 1) {
      Navigator.of(context).pop();
    } else if (index == 2) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardPage(initialIndex: 2)),
        (route) => false,
      );
    }
  }

  Widget _buildCallTab(Map<String, dynamic> lead) {
    final phone =
        lead['contactNumber'] ?? lead['mobile'] ?? (lead['mobileNumber'] ?? '');
    return Center(
      child: Builder(
        builder: (ctx) {
          final isDarkCall = Theme.of(ctx).brightness == Brightness.dark;
          final csCall = Theme.of(ctx).colorScheme;
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: csCall.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (isDarkCall ? Colors.black : Colors.grey).withAlpha(isDarkCall ? 80 : 30),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withAlpha(100),
                      width: 2,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withAlpha(50),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.call, color: Colors.white, size: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Make a Call to Lead',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkCall ? csCall.onSurface : const Color(0xFF4A4A6A),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
              'Lead: ${lead['name'] ?? ''}',
              style: TextStyle(fontSize: 16, color: isDarkCall ? csCall.onSurface.withOpacity(0.85) : csCall.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Phone: $phone',
              style: TextStyle(fontSize: 16, color: isDarkCall ? csCall.onSurface.withOpacity(0.85) : csCall.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                if (phone != null && phone.isNotEmpty) {
                  final uri = Uri.parse('tel:$phone');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not launch dialer'),
                        ),
                      );
                    }
                  }
                }
              },
              icon: const Icon(Icons.call, color: Colors.white),
              label: const Text(
                'Click to Call',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    },
    ),
  );
  }

  /// Description for Profile "Additional Information" only. Web shows "No description"
  /// when there is no text description; do not show notes array count here.
  static String _descriptionForProfile(Map<String, dynamic> lead) {
    final v = lead['description'];
    if (v == null) return 'No description';
    if (v is String) return v.trim().isEmpty ? 'No description' : v;
    if (v is List || v is Map) return 'No description';
    return v.toString().trim().isEmpty ? 'No description' : v.toString();
  }

  /// Converts API value to display string. Handles List (e.g. notes array), Map, null.
  static String _safeString(dynamic v) {
    if (v == null) return '—';
    if (v is String) return v.isEmpty ? '—' : v;
    if (v is List) {
      if (v.isEmpty) return '—';
      if (v.length == 1 && v.first is String) return v.first as String;
      return '${v.length} item(s)';
    }
    if (v is Map) return (v['name'] ?? v['email'] ?? v['title'])?.toString() ?? '—';
    return v.toString();
  }

  Widget _buildProfileTab(Map<String, dynamic> lead) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoCard('Basic Information', Icons.person_outline_rounded, [
            _buildInfoRow('Name', _safeString(lead['name'])),
            _buildInfoRow('Mobile', _safeString(lead['contactNumber'] ?? lead['mobile'])),
            _buildInfoRow('Email', _safeString(lead['email'])),
          ]),
          const SizedBox(height: 12),
          _buildInfoCard('Lead Details', Icons.description_outlined, [
            _buildInfoRow('Created', _formatDate(lead['createdAt'])),
            _buildInfoRow('Source', _safeString(lead['source'])),
            _buildStatusRow(lead),
            _buildInfoRow(
              'Assigned',
              (lead['assignedTo'] is Map)
                  ? _safeString(lead['assignedTo']!['name'] ?? lead['assignedTo']!['email'])
                  : _safeString(lead['assignedTo']),
            ),
          ]),
          const SizedBox(height: 12),
          _buildInfoCard('Additional Information', Icons.push_pin_outlined, [
            _buildInfoRow(
              'Description',
              _descriptionForProfile(lead),
            ),
          ]),
          const SizedBox(height: 12),
          _buildDescriptionHistoryCard(lead),
          const SizedBox(height: 88),
        ],
      ),
    );
  }

  Widget _buildDescriptionHistoryCard(Map<String, dynamic> lead) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.history_edu, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Description History',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Tooltip(
                message: 'Download Description History!',
                child: IconButton(
                  icon: const Icon(Icons.download),
                  color: AppColors.primary,
                  onPressed: () => _downloadDescriptionHistory(lead),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'No description changes recorded.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? cs.onSurface.withOpacity(0.85) : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadDescriptionHistory(Map<String, dynamic> lead) async {
    try {
      final name = _safeString(lead['name']);
      final description = _safeString(lead['description'] ?? lead['notes']);
      final createdAt = _formatDate(lead['createdAt']);
      final buffer = StringBuffer();
      buffer.writeln('Description History - $name');
      buffer.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
      buffer.writeln('');
      buffer.writeln('Lead created: $createdAt');
      buffer.writeln('');
      buffer.writeln('--- Description ---');
      buffer.writeln(description);
      buffer.writeln('');
      buffer.writeln('--- History ---');
      buffer.writeln('No description changes recorded.');
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/description_history_${lead['_id'] ?? 'lead'}.txt');
      await file.writeAsString(buffer.toString());
      await OpenFilex.open(file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Description history saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  static const double _statusPillRadius = 20;

  Widget _buildStatusRow(Map<String, dynamic> lead) {
    final status = lead['status']?.toString() ?? '';
    // API v1/lead-configuration/leads returns isConverted (or isCoverted); show Active Lead
    final isConverted = lead['isConverted'] == true ||
        lead['isCoverted'] == true ||
        status.toLowerCase() == 'converted';
    final displayActiveLead = isConverted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              'Status:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF555555),
              ),
            ),
          ),
          Expanded(
            child: displayActiveLead
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1EA443),
                      borderRadius:
                          BorderRadius.circular(_statusPillRadius),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Active Lead',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : Text(
                    status.isEmpty ? '—' : status,
                    style: const TextStyle(color: Color(0xFF666666)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: isDark ? cs.onSurface.withOpacity(0.85) : cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return date.toString();
    }
  }

  Widget _buildActivityLogsTab(Map<String, dynamic> lead, {VoidCallback? onRetry}) {
    return FutureBuilder<List<dynamic>>(
      key: ValueKey<int>(_activityRefreshKey),
      future: _activityFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load activity',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    snap.error.toString().replaceFirst('Exception: ', ''),
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: const Center(
                    child: Text('No activity logs for this lead'),
                  ),
                ),
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, idx) {
            final it = items[idx] as Map<String, dynamic>;
            final description = it['description']?.toString() ?? 'Activity';
            final createdAt = _formatDate(it['createdAt']);
            final metadata = it['metadata'] is Map ? it['metadata'] as Map<String, dynamic> : null;
            return _ActivityLogTile(
              description: description,
              createdAt: createdAt,
              metadata: metadata,
            );
          },
          ),
        );
      },
    );
  }

  Widget _buildCallLogsTab(Map<String, dynamic> lead) {
    final leadPhone = _safeString(lead['contactNumber'] ?? lead['mobile'] ?? lead['fullMobile'] ?? lead['mobileNumber']);
    final normLead = leadPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return FutureBuilder<List<dynamic>>(
      future: LeadsService.getLeadCalls(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final allCalls = snap.data ?? [];
        final forLead = normLead.isEmpty
            ? allCalls
            : allCalls.where((c) {
                final m = c as Map<String, dynamic>;
                final from = (m['callFrom'] ?? m['from'] ?? '').toString().replaceAll(RegExp(r'[\s\-\(\)]'), '');
                final to = (m['callTo'] ?? m['to'] ?? '').toString().replaceAll(RegExp(r'[\s\-\(\)]'), '');
                final dial = (m['dialWhomNumber'] ?? '').toString().replaceAll(RegExp(r'[\s\-\(\)]'), '');
                return from.contains(normLead) || to.contains(normLead) || dial.contains(normLead) ||
                    normLead.contains(from) || normLead.contains(to) || normLead.contains(dial);
              }).toList();
        return _CallLogsView(calls: forLead, leadPhone: leadPhone);
      },
    );
  }
}

class _ActivityLogTile extends StatefulWidget {
  final String description;
  final String createdAt;
  final Map<String, dynamic>? metadata;

  const _ActivityLogTile({
    required this.description,
    required this.createdAt,
    this.metadata,
  });

  @override
  State<_ActivityLogTile> createState() => _ActivityLogTileState();
}

class _ActivityLogTileState extends State<_ActivityLogTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hasDetails = widget.metadata != null && widget.metadata!.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.createdAt,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).colorScheme.onSurface.withOpacity(0.85) : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (hasDetails) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Row(
                  children: [
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _expanded ? 'Hide Details' : 'View Details',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (_expanded && widget.metadata != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.metadata!.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${e.key}: ${e.value}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CallLogsView extends StatelessWidget {
  final List<dynamic> calls;
  final String leadPhone;

  const _CallLogsView({required this.calls, required this.leadPhone});

  @override
  Widget build(BuildContext context) {
    if (calls.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No call logs found for this lead',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            AppColors.primary.withOpacity(0.08),
          ),
          columns: const [
            DataColumn(label: Text('S.No', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Call From', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Duration', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Recording', style: TextStyle(fontWeight: FontWeight.w600))),
          ],
          rows: List.generate(calls.length, (i) {
            final c = calls[i] as Map<String, dynamic>;
            final recUrl = c['recordingUrl']?.toString() ?? c['fullCallData']?['RecordingUrl']?.toString() ?? '';
            return DataRow(
              cells: [
                DataCell(Text('${i + 1}')),
                DataCell(Text(_formatCallDate(c['createdAt']))),
                DataCell(Text(_safeStr(c['callFrom'] ?? c['from'] ?? '—'))),
                DataCell(Text(_safeStr(c['callStatus'] ?? c['status'] ?? '—'))),
                DataCell(Text(_safeStr(c['callDuration'] ?? '0'))),
                DataCell(
                  recUrl.isNotEmpty
                      ? InkWell(
                          onTap: () => launchUrl(Uri.parse(recUrl)),
                          child: const Icon(Icons.play_circle_outline, color: AppColors.primary),
                        )
                      : const Text('—'),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  static String _formatCallDate(dynamic date) {
    if (date == null) return '—';
    try {
      final dt = DateTime.parse(date.toString());
      return DateFormat('MMM d, y HH:mm').format(dt);
    } catch (_) {
      return date.toString();
    }
  }

  static String _safeStr(dynamic v) {
    if (v == null) return '—';
    return v.toString();
  }
}

class _RemindersTab extends StatefulWidget {
  final String? leadId;

  const _RemindersTab({this.leadId});

  @override
  State<_RemindersTab> createState() => _RemindersTabState();
}

class _RemindersTabState extends State<_RemindersTab> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = LeadsService.getLeadReminders(widget.leadId ?? '');
  }

  Future<void> _refresh() async {
    setState(() {
      _future = LeadsService.getLeadReminders(widget.leadId ?? '');
    });
    await _future;
  }

  Future<void> _showAddReminder() async {
    if (widget.leadId == null) return;
    final dateController = TextEditingController();
    final descController = TextEditingController();
    DateTime? pickedDate;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Add Reminder'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: dateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Date & Time',
                      border: OutlineInputBorder(),
                    ),
                    onTap: () async {
                      final dt = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (dt != null) {
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          pickedDate = DateTime(dt.year, dt.month, dt.day, time.hour, time.minute);
                          dateController.text = DateFormat('yyyy-MM-dd HH:mm').format(pickedDate!);
                          setDialogState(() {});
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (pickedDate == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Please select date & time')),
                    );
                    return;
                  }
                  try {
                    await LeadsService.addLeadReminder(widget.leadId!, {
                      'date': dateController.text,
                      'description': descController.text,
                      'type': 'general',
                    });
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    _refresh();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reminder added')),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Failed: $e')),
                      );
                    }
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
    dateController.dispose();
    descController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refresh,
              child: list.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: const Center(child: Text('No reminders')),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 70),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final r = list[i] as Map<String, dynamic>;
                        final date = r['date']?.toString() ?? '—';
                        final desc = r['description']?.toString() ?? r['notes']?.toString() ?? '—';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(desc),
                            subtitle: Text(date),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final id = r['reminderId']?.toString();
                                if (id == null) return;
                                try {
                                  await LeadsService.deleteLeadReminder(widget.leadId!, id);
                                  if (mounted) _refresh();
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to delete: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: _showAddReminder,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SendTemplateTab extends StatefulWidget {
  final Map<String, dynamic> lead;

  const _SendTemplateTab({required this.lead});

  @override
  State<_SendTemplateTab> createState() => _SendTemplateTabState();
}

class _SendTemplateTabState extends State<_SendTemplateTab> {
  Map<String, dynamic>? _selectedTemplate;
  bool _sending = false;

  Future<void> _openTemplateSelection() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => const LeadTemplateSelectionPage(),
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedTemplate = result);
    }
  }

  Future<void> _sendTemplate() async {
    if (_selectedTemplate == null) return;
    final templateId = _selectedTemplate!['_id']?.toString();
    if (templateId == null) return;
    final leadId = widget.lead['_id']?.toString() ?? widget.lead['id']?.toString();
    if (leadId == null || leadId.isEmpty) return;
    final mobile = widget.lead['contactNumber'] ?? widget.lead['mobile'] ?? widget.lead['fullMobile'] ?? widget.lead['mobileNumber'];
    if (mobile == null || mobile.toString().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lead has no mobile number')),
        );
      }
      return;
    }
    setState(() => _sending = true);
    try {
      await LeadsService.sendTemplateMessage({
        'templateId': templateId,
        'recipientData': {
          'leadId': leadId,
          'fullMobile': mobile.toString(),
          'name': widget.lead['name']?.toString(),
        },
        'variableValues': {},
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template sent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryMobile = widget.lead['contactNumber'] ?? widget.lead['mobile'] ?? widget.lead['fullMobile'] ?? widget.lead['mobileNumber'] ?? '—';
    final status = widget.lead['status']?.toString() ?? 'New Lead';
    final selectedName = _selectedTemplate?['name']?.toString();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openTemplateSelection,
                  icon: const Icon(Icons.mail_outline, size: 20),
                  label: const Text('Select Template'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Status: $status',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Primary Mobile Number', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(primaryMobile.toString(), style: Theme.of(context).textTheme.bodyLarge),
          if (selectedName != null) ...[
            const SizedBox(height: 16),
            const Text('Selected Template', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text(selectedName, style: Theme.of(context).textTheme.bodyLarge),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: (_sending || _selectedTemplate == null) ? null : _sendTemplate,
            icon: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
            label: Text(_sending ? 'Sending...' : 'Send to 1 Recipient'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesTab extends StatefulWidget {
  final String? leadId;
  const _NotesTab({this.leadId});

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  String _selectedType = 'Text'; // Text, Audio, Image, Video, Document
  final TextEditingController _textController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isLoading = false;
  int _notesListKey = 0; // Increment after add to refresh list
  late Future<List<dynamic>> _notesFuture;

  @override
  void initState() {
    super.initState();
    _notesFuture = LeadsService.getLeadNotes(widget.leadId ?? '');
  }

  void _refreshNotesList() {
    setState(() {
      _notesListKey++;
      _notesFuture = LeadsService.getLeadNotes(widget.leadId ?? '');
    });
  }

  // Audio specific
  String _audioMode = 'record'; // 'record' or 'upload'
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _recordedPath;
  String?
  _selectedAudioPath; // For uploaded file path (mobile) or just name (web)
  bool _isPlaying = false;

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await Permission.microphone.request().isGranted) {
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final String filePath =
            '${appDocDir.path}/note_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: filePath);
        setState(() {
          _isRecording = true;
          _recordedPath = null;
        });
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required')),
          );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting record: $e')));
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordedPath = path;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error stopping record: $e')));
    }
  }

  /// MIME type for note mediaData (same as web: image/jpeg, video/mp4, etc.)
  static String _getMimeTypeForNote(
    String selectedType,
    String? extension,
    String fileName,
  ) {
    final parts = fileName.split('.');
    final ext = (extension ?? (parts.length > 1 ? parts.last : '')).toString().toLowerCase();
    if (selectedType == 'Audio') {
      if (ext == 'm4a' || ext == 'mp4') return 'audio/mp4';
      if (ext == 'ogg') return 'audio/ogg';
      if (ext == 'wav') return 'audio/wav';
      if (ext == 'mp3') return 'audio/mpeg';
      return 'audio/mp4';
    }
    if (selectedType == 'Image') {
      if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
      if (ext == 'png') return 'image/png';
      if (ext == 'gif') return 'image/gif';
      if (ext == 'webp') return 'image/webp';
      return 'image/jpeg';
    }
    if (selectedType == 'Video') {
      if (ext == 'mp4') return 'video/mp4';
      if (ext == 'webm') return 'video/webm';
      if (ext == 'mov') return 'video/quicktime';
      return 'video/mp4';
    }
    if (selectedType == 'Document') {
      if (ext == 'pdf') return 'application/pdf';
      if (ext == 'doc') return 'application/msword';
      if (ext == 'docx') return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      return 'application/octet-stream';
    }
    return 'application/octet-stream';
  }

  Future<void> _playAudio(String path) async {
    try {
      await _audioPlayer.play(DeviceFileSource(path));
      setState(() => _isPlaying = true);
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) setState(() => _isPlaying = false);
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error playing audio: $e')));
    }
  }

  Future<void> _pauseAudio() async {
    await _audioPlayer.pause();
    setState(() => _isPlaying = false);
  }

  void _addNote() async {
    if (widget.leadId == null) return;
    String? content = _textController.text;
    Map<String, dynamic> noteData = {'type': _selectedType.toLowerCase()};

    dynamic fileToUpload;
    String folderName = 'notes';

    if (_selectedType == 'Text') {
      if (content.isEmpty) return;
      noteData['content'] = content;
    } else if (_selectedType == 'Audio') {
      if (_audioMode == 'record') {
        if (_recordedPath == null) return;
        fileToUpload = _recordedPath;
      } else {
        if (_selectedFile == null) return;
        fileToUpload = _selectedFile; // PlatformFile
      }
    } else {
      // Image, Video, Document
      if (_selectedFile == null) return;
      fileToUpload = _selectedFile;
    }

    // Upload logic if media (same as web: upload file then send mediaData with name, type MIME, size, url)
    if (_selectedType != 'Text' && fileToUpload != null) {
      setState(() => _isLoading = true);
      try {
        final uploadResp = await LeadsService.uploadFile(
          fileToUpload,
          folderName,
        );
        // Backend S3 returns { fileUrl }; some wrappers may return { data: { url } } or { url }
        final fileUrl = uploadResp['fileUrl']?.toString() ??
            uploadResp['data']?['url']?.toString() ??
            uploadResp['url']?.toString();

        if (fileUrl != null && fileUrl.isNotEmpty) {
          String fileName = _selectedType == 'Audio' && _audioMode == 'record'
              ? 'recorded_audio.m4a'
              : (_selectedFile?.name ?? 'file');
          int fileSize = 0;
          if (fileToUpload is String) {
            final f = File(fileToUpload);
            if (f.existsSync()) fileSize = f.lengthSync();
          } else if (_selectedFile != null) {
            fileSize = _selectedFile!.size;
          }
          String mimeType = _getMimeTypeForNote(
            _selectedType,
            _selectedFile?.extension,
            fileName,
          );
          noteData['mediaData'] = [
            {
              'name': fileName,
              'type': mimeType,
              'size': fileSize,
              'url': fileUrl,
            },
          ];

          if (_selectedType == 'Audio') {
            noteData['audioSource'] = _audioMode; // 'record' or 'upload'
          }
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        setState(() => _isLoading = false);
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      await LeadsService.addLeadNote(widget.leadId!, noteData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note added successfully')),
        );
        _textController.clear();
        setState(() {
          _selectedFile = null;
          _recordedPath = null;
          _selectedAudioPath = null;
          _isLoading = false;
        });
        _refreshNotesList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add note: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickFile(FileType type) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: type);
      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
          if (_selectedType == 'Audio') {
            _selectedAudioPath = _selectedFile!.path;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add New Note',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select Note Type:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Text', 'Audio', 'Image', 'Video', 'Document'].map((
                type,
              ) {
                final isSelected = _selectedType == type;
                IconData icon;
                switch (type) {
                  case 'Text':
                    icon = Icons.chat_bubble_outline;
                    break;
                  case 'Audio':
                    icon = Icons.mic_none;
                    break;
                  case 'Image':
                    icon = Icons.image_outlined;
                    break;
                  case 'Video':
                    icon = Icons.videocam_outlined;
                    break;
                  case 'Document':
                    icon = Icons.description_outlined;
                    break;
                  default:
                    icon = Icons.circle;
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () => setState(() {
                      _selectedType = type;
                      _selectedFile = null;
                      _recordedPath = null;
                      _selectedAudioPath = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? AppColors.primary : (isDark ? Colors.white24 : Colors.grey.shade300),
                        ),
                        borderRadius: BorderRadius.circular(4),
                        color: isSelected
                            ? AppColors.primary.withAlpha(20)
                            : (isDark ? cs.surfaceContainerHighest : Colors.white),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            size: 18,
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? Colors.white70 : Colors.grey.shade600),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            type,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? Colors.white70 : Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _buildInputSection(),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                minimumSize: const Size(100, 40),
              ),
              onPressed: _isLoading ? null : _addNote,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Add Note', style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 16),
          _buildNotesList(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    if (_selectedType == 'Text') {
      return TextField(
        controller: _textController,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: 'Enter note content...',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } else if (_selectedType == 'Audio') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Audio Option:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              Radio<String>(
                value: 'record',
                groupValue: _audioMode,
                onChanged: (val) => setState(() {
                  _audioMode = val!;
                  _recordedPath = null;
                  _selectedAudioPath = null;
                  _selectedFile = null;
                }),
                activeColor: AppColors.primary,
              ),
              const Text('Record Audio'),
              const SizedBox(width: 20),
              Radio<String>(
                value: 'upload',
                groupValue: _audioMode,
                onChanged: (val) => setState(() {
                  _audioMode = val!;
                  _recordedPath = null;
                  _selectedAudioPath = null;
                  _selectedFile = null;
                }),
                activeColor: AppColors.primary,
              ),
              const Text('Upload Audio File'),
            ],
          ),
          const SizedBox(height: 12),
          if (_audioMode == 'record') _buildRecorderUI(),
          if (_audioMode == 'upload') _buildAudioUploadUI(),
        ],
      );
    } else {
      // Image, Video, Document
      return InkWell(
        onTap: () {
          FileType ft = FileType.any;
          if (_selectedType == 'Image') ft = FileType.image;
          if (_selectedType == 'Video') ft = FileType.video;
          _pickFile(ft);
        },
        child: Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Center(
            child: _selectedFile == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _selectedType == 'Image'
                            ? Icons.image
                            : _selectedType == 'Video'
                            ? Icons.videocam
                            : Icons.description,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Click to upload ${_selectedType.toLowerCase()}',
                        style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).colorScheme.onSurface.withOpacity(0.85) : Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedFile!.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }
  }

  Widget _buildRecorderUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isRecording && _recordedPath == null)
          ElevatedButton.icon(
            onPressed: _startRecording,
            icon: const Icon(Icons.mic, color: Colors.white),
            label: const Text(
              'Start Recording',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        if (_isRecording)
          ElevatedButton.icon(
            onPressed: _stopRecording,
            icon: const Icon(Icons.stop, color: Colors.white),
            label: const Text(
              'Stop Recording',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        if (_recordedPath != null)
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  size: 36,
                  color: AppColors.primary,
                ),
                onPressed: () {
                  if (_isPlaying) {
                    _pauseAudio();
                  } else {
                    _playAudio(_recordedPath!);
                  }
                },
              ),
              const Text(
                'Audio Recorded',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => setState(() => _recordedPath = null),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildAudioUploadUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedFile == null)
          ElevatedButton.icon(
            onPressed: () => _pickFile(FileType.audio),
            icon: const Icon(Icons.upload_file, color: Colors.white),
            label: const Text(
              'Select Audio File',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        if (_selectedFile != null)
          Row(
            children: [
              if (_selectedAudioPath != null)
                IconButton(
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    size: 36,
                    color: AppColors.primary,
                  ),
                  onPressed: () {
                    if (_isPlaying) {
                      _pauseAudio();
                    } else {
                      _playAudio(_selectedAudioPath!);
                    }
                  },
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedFile!.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey),
                onPressed: () => setState(() {
                  _selectedFile = null;
                  _selectedAudioPath = null;
                }),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _deleteNote(String noteId) async {
    if (widget.leadId == null) return;
    try {
      await LeadsService.deleteLeadNote(widget.leadId!, noteId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note deleted')),
        );
        _refreshNotesList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete note: $e')),
        );
      }
    }
  }

  Future<void> _clearAllNotes(List<dynamic> notes) async {
    if (widget.leadId == null || notes.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notes'),
        content: const Text(
          'Are you sure you want to delete all notes for this lead? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All Notes'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final noteIds = notes
        .map((n) => (n as Map<String, dynamic>)['_id']?.toString())
        .whereType<String>()
        .toList();
    if (noteIds.isEmpty) return;
    try {
      await LeadsService.bulkDeleteLeadNotes(widget.leadId!, noteIds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${noteIds.length} notes deleted')),
        );
        _refreshNotesList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear notes: $e')),
        );
      }
    }
  }

  Widget _buildNotesList() {
    return FutureBuilder<List<dynamic>>(
      key: ValueKey<int>(_notesListKey),
      future: _notesFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load notes',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    snap.error.toString().replaceFirst('Exception: ', ''),
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _refreshNotesList,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final notes = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.notes_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'All Notes (${notes.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (notes.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _clearAllNotes(notes),
                    icon: const Icon(Icons.delete_sweep, size: 18, color: Colors.red),
                    label: const Text(
                      'Clear All Notes',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (notes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No notes found',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85)),
                  ),
                ),
              ),
            if (notes.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: notes.length,
                padding: const EdgeInsets.only(bottom: 16),
                itemBuilder: (context, idx) {
                    final note = notes[idx] as Map<String, dynamic>;
                    final cs = Theme.of(context).colorScheme;
                    final noteId = note['_id']?.toString();
                    final isDarkNote = Theme.of(context).brightness == Brightness.dark;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isDarkNote ? Colors.white12 : Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${idx + 1}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  note['type']?.toString().toUpperCase() ?? 'TEXT',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkNote ? cs.onSurface.withOpacity(0.85) : cs.onSurfaceVariant,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatDate(note['createdAt']),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkNote ? cs.onSurface.withOpacity(0.85) : cs.onSurfaceVariant,
                                  ),
                                ),
                                if (noteId != null) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                                    onPressed: () => _deleteNote(noteId),
                                    tooltip: 'Delete note',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildNoteContent(note),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ],
        );
      },
    );
  }

  Widget _buildNoteContent(Map<String, dynamic> note) {
    final type = (note['type'] ?? 'text').toString().toLowerCase();
    final mediaList = note['mediaData'] is List ? note['mediaData'] as List : null;
    final firstMedia = (mediaList != null && mediaList.isNotEmpty)
        ? mediaList[0] as Map<String, dynamic>?
        : null;
    final url = firstMedia?['url']?.toString();

    if (type == 'audio') {
      final media = firstMedia ?? (note['audioData'] is Map ? note['audioData'] as Map<String, dynamic>? : null);
      if (media == null) return const Text('Audio Note');
      final audioUrl = media['url']?.toString();
      return InkWell(
        onTap: audioUrl != null && audioUrl.isNotEmpty
            ? () async {
                final uri = Uri.tryParse(audioUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            : null,
        child: Row(
          children: [
            Icon(Icons.audiotrack, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(media['name']?.toString() ?? 'Audio File')),
            if (audioUrl != null && audioUrl.isNotEmpty)
              const Icon(Icons.play_circle_outline, color: AppColors.primary),
          ],
        ),
      );
    }
    if (type == 'image') {
      if (url != null && url.isNotEmpty) {
        return InkWell(
          onTap: () async {
            final uri = Uri.tryParse(url);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      firstMedia?['name']?.toString() ?? 'Image',
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to view',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, size: 18, color: AppColors.primary),
            ],
          ),
        );
      }
      return Text(note['content'] ?? '${mediaList?.length ?? 0} file(s)');
    }
    if (type == 'video') {
      if (url != null && url.isNotEmpty) {
        return InkWell(
          onTap: () async {
            final uri = Uri.tryParse(url);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.play_circle_filled,
                      size: 40, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      firstMedia?['name']?.toString() ?? 'Video',
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to view video',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, size: 18, color: AppColors.primary),
            ],
          ),
        );
      }
      return Text(note['content'] ?? '${mediaList?.length ?? 0} file(s)');
    }
    if (type == 'document') {
      if (url != null && url.isNotEmpty) {
        return InkWell(
          onTap: () async {
            final uri = Uri.tryParse(url);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Row(
            children: [
              Icon(Icons.description, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  firstMedia?['name']?.toString() ?? 'Tap to view document',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const Icon(Icons.open_in_new, size: 18, color: AppColors.primary),
            ],
          ),
        );
      }
      return Text(note['content'] ?? '${mediaList?.length ?? 0} file(s)');
    }
    return Text(
      note['content'] ??
          (mediaList != null ? '${mediaList.length} file(s)' : ''),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return date.toString();
    }
  }
}

class DottedBorderBox extends StatelessWidget {
  final Widget child;
  const DottedBorderBox({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: FileUploadDottedPainter(),
      child: Center(child: child),
    );
  }
}

class FileUploadDottedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    // Simple rect for now, dotted implementation requires logic
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    // Implementing true dotted border logic is verbose, using solid for now with intent.
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
