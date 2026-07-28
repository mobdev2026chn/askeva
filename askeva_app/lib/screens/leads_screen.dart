import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../api/app_scope.dart';
import '../api/dto.dart';
import '../api/gemini_config.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../shell/app_nav.dart';
import '../shell/app_sidebar.dart';
import 'lead_detail_screen.dart';
import 'detail_screens.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import '../widgets/dashboard_sheets.dart';
import '../widgets/donut_chart.dart';
import '../widgets/leads_extra.dart';
import '../widgets/leads_sheets.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  String? _selectedLeadStatus;
  int _top = 1; // 0 Dashboard, 1 Leads, 2 Settings
  int _sub = 0; // 0 Leads, 1 Companies, 2 Customers
  int _dashboardSub = 0; // 0 Overview, 1 Performance
  int _settingsSub = 0; // 0 Reminders, 1 Configuration, 2 Webhook, 3 Quick Reply
  bool _kanban = false;

  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _debounce;
  Future<LeadsPage>? _future;

  // Overview Analytics Filter State
  String _overviewTimeFilter = '30';
  String _overviewAssigned = 'all';
  String _overviewSource = 'all';
  String _overviewStatus = 'all';
  List<DateTime>? _overviewDateRange;
  Future<AnalyticsDto>? _overviewFuture;

  // Performance Analytics Filter State
  String _perfTimeFilter = '30';
  String _perfAssigned = 'all';
  String _perfSource = 'all';
  String _perfStatus = 'all';
  Future<AnalyticsDto>? _perfFuture;

  LeadFilter _filter = LeadFilter.empty;
  bool _selectMode = false;
  final Set<String> _selected = {};
  final Map<String, int> _lifecycle = {}; // leadId -> 0 active / 1 at-risk / 2 churned
  final Map<String, String> _statusOverride = {}; // leadId -> kanban status label

  List<String> _agentNames() => MockData.agents.map((a) => a.name).toList();
  List<String> _companyNames(LeadsPage p) => (p.leads.map((l) => l.company).where((c) => c.trim().isNotEmpty).toSet().toList()..sort());
  List<String> _sourceNames(LeadsPage p) => (p.leads.map((l) => l.source).where((s) => s.trim().isNotEmpty).toSet().toList()..sort());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
    _overviewFuture ??= _loadOverview();
    _perfFuture ??= _loadPerf();
  }

  List<Map<String, dynamic>> _offlineCards = [];

  Future<LeadsPage> _load() async {
    final repo = AppScope.of(context).leads;
    try {
      final syncedCount = await repo.syncOfflineCards();
      if (syncedCount > 0 && mounted) {
        appToast(context, '⚡ Synced $syncedCount offline scanned business card(s) to AskEva server!', isSuccess: true);
      }
    } catch (_) {}
    try {
      _offlineCards = await repo.getOfflineCards();
    } catch (_) {}

    final page = await repo.fetchLeads(q: _query, limit: 500);
    kTotalLeadsCount.value = page.total;
    return page;
  }

  bool _matchesQuery(LeadDto l) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return (l.name.toLowerCase().contains(q)) ||
        (l.email.toLowerCase().contains(q)) ||
        (l.mobile.toLowerCase().contains(q)) ||
        (l.company.toLowerCase().contains(q)) ||
        (l.source.toLowerCase().contains(q)) ||
        (l.status.label.toLowerCase().contains(q));
  }

  Future<AnalyticsDto> _loadOverview() => AppScope.of(context).leads.fetchAnalytics(
        timeFilter: _overviewTimeFilter,
        assigned: _overviewAssigned,
        source: _overviewSource,
        status: _overviewStatus,
        dateRange: _overviewDateRange,
      );

  Future<AnalyticsDto> _loadPerf() => AppScope.of(context).leads.fetchAnalytics(
        timeFilter: _perfTimeFilter,
        assigned: _perfAssigned,
        source: _perfSource,
        status: _perfStatus,
      );

  bool _isReloading = false;

  void _reload() {
    _handleRefresh();
  }

  Future<void> _handleRefresh() async {
    if (_isReloading) return;
    if (mounted) setState(() => _isReloading = true);
    appToast(context, 'Refreshing data...');
    try {
      final f1 = _load();
      final f2 = _loadOverview();
      final f3 = _loadPerf();
      setState(() {
        _future = f1;
        _overviewFuture = f2;
        _perfFuture = f3;
      });
      await Future.wait<dynamic>([f1, f2, f3]).catchError((_) => <dynamic>[]);
    } finally {
      if (mounted) {
        setState(() => _isReloading = false);
        appToast(context, 'Data refreshed', isSuccess: true);
      }
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _query = v.trim();
        _future = _load();
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nav = AppNav.of(context);
    return GreenHeaderScaffold(
      title: 'Leads',
      onMenu: nav.openDrawer,
      actions: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GlassIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifications',
              onTap: () => showNotificationsPanel(context),
            ),
            ValueListenableBuilder<int>(
              valueListenable: kNotificationUnreadCount,
              builder: (context, count, _) {
                if (count == 0) return const SizedBox.shrink();
                return Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text('$count', style: AppText.poppins(size: 10, weight: FontWeight.w800, color: Colors.white)),
                  ),
                );
              },
            ),
          ],
        ),
      ],
      headerChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GreenSegmented(
            items: const ['Dashboard', 'Leads', 'Settings'],
            selected: _top,
            onChanged: (i) => setState(() => _top = i),
          ),
          if (_top == 1) ...[
            const SizedBox(height: 14),
            GreenChipTabs(
              items: const ['Leads', 'Companies', 'Customers'],
              selected: _sub,
              onChanged: (i) => setState(() => _sub = i),
            ),
          ],
          if (_top == 0) ...[
            const SizedBox(height: 14),
            GreenChipTabs(
              items: const ['Overview', 'Performance'],
              selected: _dashboardSub,
              onChanged: (i) => setState(() => _dashboardSub = i),
            ),
          ],
          if (_top == 2) ...[
            const SizedBox(height: 14),
            GreenChipTabs(
              items: const ['Reminders', 'Configuration', 'Webhook', 'Quick Reply', 'Assignment Mode'],
              icons: const [Icons.notifications_none_rounded, Icons.settings_outlined, Icons.link_rounded, Icons.chat_outlined, Icons.manage_accounts_outlined],
              selected: _settingsSub,
              onChanged: (i) => setState(() => _settingsSub = i),
            ),
          ],
        ],
      ),
      sheet: _top == 2
          ? LeadsSettingsView(tab: _settingsSub, onChanged: (i) => setState(() => _settingsSub = i))
          : _top == 0
              ? Stack(
                  children: [
                    _dashboardView(),
                    if (_dashboardSub == 0)
                      Positioned(
                        right: 18,
                        bottom: 18,
                        child: _ScanCardFab(onTap: _openCameraAutoScanner),
                      ),
                  ],
                )
              : Stack(
                  children: [
                    RefreshIndicator(
                      color: AppColors.evaGreen,
                      onRefresh: () async => _reload(),
                      child: AsyncView<LeadsPage>(
                        future: _future,
                        onRetry: _reload,
                        builder: (page) {
                          _page = page;
                          return switch (_sub) {
                            1 => _companies(page),
                            2 => _customers(page),
                            _ => _leads(page),
                          };
                        },
                      ),
                    ),
                    if (_sub == 0 && !_selectMode)
                      Positioned(
                        right: 18,
                        bottom: 18,
                        child: _Fab(onTap: _openNewLead),
                      ),
                  ],
                ),
    );
  }

  LeadsPage? _page;

  void _openNewLead() {
    final p = _page;
    showLeadForm(
      context,
      companies: p == null ? const [] : _companyNames(p),
      sources: p == null ? const [] : _sourceNames(p),
      agents: _agentNames(),
    ).then((ok) {
      if (ok == true) _reload();
    });
  }

  Future<void> _openCameraAutoScanner() async {
    LeadDto? scannedLead;
    
    final result = await Navigator.of(context).push<LeadDto>(
      MaterialPageRoute(
        builder: (ctx) => _CameraScannerOverlay(
          onScanDone: (lead) {
            scannedLead = lead;
          },
        ),
      ),
    );

    if (!mounted) return;

    final leadToEdit = result ?? scannedLead ?? LeadDto(
      id: '',
      name: 'Scanned Contact',
      email: '',
      mobile: '',
      countryCode: '+91',
      company: '',
      position: '',
      statusRaw: 'New',
      source: 'Business Card',
      createdAt: DateTime.now(),
    );

    final p = _page;
    final ok = await showLeadForm(
      context,
      lead: leadToEdit,
      companies: p == null ? const [] : _companyNames(p),
      sources: p == null ? const ['Business Card'] : _sourceNames(p),
      agents: _agentNames(),
    );

    if (ok == true && mounted) {
      _reload();
    }
  }

  Future<void> _openFilters() async {
    final p = _page;
    final res = await showLeadFilters(
      context,
      current: _filter,
      sources: p == null ? const [] : _sourceNames(p),
      companies: p == null ? const [] : _companyNames(p),
      agents: _agentNames(),
    );
    if (res != null && mounted) setState(() => _filter = res);
  }

  Future<void> _bulkDelete(List<LeadDto> all) async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Leads', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
        content: Text('Permanently delete ${ids.length} selected lead${ids.length == 1 ? '' : 's'}? This action cannot be undone.', style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink2)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Delete', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _selectMode = false;
      _selected.clear();
    });

    final repo = AppScope.of(context).leads;
    try {
      await repo.deleteLeads(ids);
      if (mounted) appToast(context, '${ids.length} lead${ids.length == 1 ? '' : 's'} deleted');
    } catch (e) {
      if (mounted) appToast(context, 'Error deleting leads: $e');
    } finally {
      if (mounted) _reload();
    }
  }

  void _bulkUpdate(List<LeadDto> all) {
    final selectedLeads = all.where((l) => _selected.contains(l.id)).toList();
    final hasConverted = selectedLeads.any(_isLeadConverted);
    final allConverted = selectedLeads.isNotEmpty && selectedLeads.every(_isLeadConverted);
    final hasNonNew = selectedLeads.any((l) => _displayStatus(l).label != 'New Lead' && _displayStatus(l).label != 'New');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _BulkUpdateSheet(
            selectedCount: _selected.length,
            agents: _agentNames(),
            hasConvertedLeads: hasConverted,
            allConvertedLeads: allConverted,
            hasNonNewLeads: hasNonNew,
            onApply: (status, agent) async {
              String? backendStatus;
              if (status != null) {
                backendStatus = switch (status) {
                  'New' => 'New Lead',
                  'Customer' => 'Converted',
                  _ => status,
                };
              }
              
              setState(() => _selectMode = false);
              final repo = AppScope.of(context).leads;
              final idsToUpdate = List<String>.from(_selected);
              _selected.clear();
              
              _snack('Updating ${idsToUpdate.length} leads...');
              
              for (final id in idsToUpdate) {
                final leadObj = all.firstWhere((l) => l.id == id, orElse: () => selectedLeads.first);
                final Map<String, dynamic> body = {};
                if (backendStatus != null && !_isLeadConverted(leadObj)) {
                  body['status'] = backendStatus;
                }
                if (agent != null) body['assignedTo'] = agent;
                if (body.isNotEmpty) {
                  try {
                    await repo.updateLead(id, body);
                  } catch (_) {}
                }
              }
              
              if (hasConverted && backendStatus != null) {
                _snack('Bulk update complete (converted customer statuses preserved)');
              } else {
                _snack('Bulk update complete');
              }
              _reload();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineCardsBanner() {
    if (_offlineCards.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade400),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_offlineCards.length} Offline Scanned Card(s)',
              style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: Colors.amber.shade900),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            onPressed: () async {
              final repo = AppScope.of(context).leads;
              final count = await repo.syncOfflineCards();
              if (mounted) {
                if (count > 0) {
                  appToast(context, '⚡ Synced $count offline card(s) to AskEva server!', isSuccess: true);
                } else {
                  appToast(context, 'Sync completed.');
                }
                _reload();
              }
            },
            icon: const Icon(Icons.sync_rounded, size: 12, color: Colors.white),
            label: Text('Sync Now', style: AppText.poppins(size: 11, weight: FontWeight.w800, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.evaGreen,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Leads ----------------
  Widget _leads(LeadsPage page) {
    final filtered = page.leads.where(_filter.matches).where(_matchesQuery).toList();
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(16, 14, 16, _selectMode ? 120 : 90),
          children: [
            _buildOfflineCardsBanner(),
            Row(
              children: [
                Expanded(child: _searchField('Search leads')),
                const SizedBox(width: 10),
                _filtersButton(),
              ],
            ),
            if (_filter.activeCount > 0) ...[
              const SizedBox(height: 10),
              _filterChips(),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _toolBtn(Icons.sync_rounded, 'Sync', () => _sync()),
                  const SizedBox(width: 10),
                  _toolBtn(Icons.description_outlined, 'Sample CSV', () => _downloadSampleCsv()),
                  const SizedBox(width: 10),
                  _toolBtn(Icons.download_rounded, 'Import', () => showImportWizard(context, onDone: () { _snack('Leads imported'); _reload(); })),
                  const SizedBox(width: 10),
                  _toolBtn(Icons.file_upload_outlined, 'Export', () => _exportLeads(filtered)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('${filtered.length} leads', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2)),
                const Spacer(),
                _selectPill(filtered),
                const SizedBox(width: 10),
                _viewToggle(),
              ],
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              _emptyState()
            else if (_kanban)
              _kanbanView(filtered)
            else
              ...filtered.map(_leadCard),
          ],
        ),
        if (_selectMode) Positioned(left: 0, right: 0, bottom: 0, child: _bulkBar(filtered)),
      ],
    );
  }

  Widget _emptyState() {
    final hasFilters = _filter.activeCount > 0 || _query.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.evaGreen50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 34,
                color: AppColors.evaGreenDeep,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No leads found',
              style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'No leads match your active filters or search query.'
                  : 'There are no leads created yet.',
              textAlign: TextAlign.center,
              style: AppText.poppins(size: 13, color: AppColors.ink3),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _filter = const LeadFilter();
                    _query = '';
                    _searchCtrl.clear();
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.evaGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.filter_alt_off_rounded, size: 16, color: AppColors.evaGreenDeep),
                label: Text(
                  'Clear Filters',
                  style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _sync() {
    _showSyncSheet();
  }

  void _showSyncSheet() {
    bool sendAlert = false;
    bool syncing = false;
    int? createdCount;
    int? skippedCount;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF3E0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.error_outline_rounded, color: Color(0xFFE65100), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sync WhatsApp Contacts',
                          style: AppText.poppins(size: 16.5, weight: FontWeight.w800, color: AppColors.ink),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'This will sync all WhatsApp contacts with ',
                          style: AppText.poppins(size: 13, color: AppColors.ink3, height: 1.4),
                        ),
                        TextSpan(
                          text: 'User Initiated Message',
                          style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink),
                        ),
                        TextSpan(
                          text: ' as new leads.',
                          style: AppText.poppins(size: 13, color: AppColors.ink3, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (createdCount != null || skippedCount != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3FDF3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.evaGreen200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Last Sync Results:',
                            style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.check_rounded, size: 16, color: AppColors.evaGreenDeep),
                              const SizedBox(width: 6),
                              Text(
                                'Created: ${createdCount ?? 0} leads',
                                style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: AppColors.ink3),
                              const SizedBox(width: 6),
                              Text(
                                'Skipped: ${skippedCount ?? 0} duplicates',
                                style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Note: Only unique contacts will be created as leads. Existing contacts will be skipped.',
                    style: AppText.poppins(size: 11.5, color: AppColors.ink4, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: sendAlert,
                        activeColor: AppColors.evaGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (v) => setSheetState(() => sendAlert = v ?? false),
                      ),
                      Expanded(
                        child: Text(
                          'Send New Lead Alerts to the synced leads',
                          style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.line),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text('Cancel', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: syncing
                              ? null
                              : () async {
                                  setSheetState(() => syncing = true);
                                  try {
                                    final res = await AppScope.of(context).leads.syncWhatsAppContacts(sendAlert: sendAlert);
                                    final created = (res['created'] ?? res['createdCount'] ?? res['newLeads'] ?? res['createdLeads'] ?? 0);
                                    final skipped = (res['skipped'] ?? res['skippedCount'] ?? res['duplicates'] ?? 0);

                                    setSheetState(() {
                                      createdCount = int.tryParse(created.toString()) ?? 0;
                                      skippedCount = int.tryParse(skipped.toString()) ?? 0;
                                      syncing = false;
                                    });

                                    _snack('Sync completed! $createdCount created, $skippedCount skipped.');
                                    _reload();
                                  } catch (e) {
                                    setSheetState(() => syncing = false);
                                    _snack('Sync failed: $e');
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.evaGreen,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: syncing
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text('Start Sync', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _snack(String msg) => appToast(context, msg);

  Future<void> _downloadSampleCsv() async {
    final url = Uri.parse('https://askeva.blr1.cdn.digitaloceanspaces.com/Samplecontact.csv');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _snack('Could not open download link');
      }
    } catch (_) {
      _snack('Error launching download');
    }
  }

  Future<void> _exportLeads(List<LeadDto> filtered) async {
    if (filtered.isEmpty) {
      _snack('No leads available to export');
      return;
    }
    
    final csvHeader = 'Name,Company,Email,Status,Source,Assigned,CreatedAt\n';
    final csvRows = filtered.map((lead) {
      final status = lead.status.label;
      final source = lead.source;
      final assigned = lead.assignedTo ?? 'Unassigned';
      final date = lead.createdAt?.toIso8601String() ?? '';
      return '"${lead.name}","${lead.company}","${lead.email}","$status","$source","$assigned","$date"';
    }).join('\n');
    
    final csvContent = csvHeader + csvRows;
    final bytes = Uint8List.fromList(utf8.encode(csvContent));
    
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Leads CSV',
        fileName: 'leads_export.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );
      if (path != null) {
        _snack('Leads exported successfully to $path');
      }
    } catch (e) {
      _snack('Error saving export file: $e');
    }
  }

  Widget _filterChips() {
    final chips = <(String, VoidCallback)>[];
    void add(String? v, LeadFilter Function() clear) {
      if (v != null) chips.add((v, () => setState(() => _filter = clear())));
    }

    add(_filter.status, () => _filter.copyWith(status: null));
    add(_filter.source, () => _filter.copyWith(source: null));
    add(_filter.company, () => _filter.copyWith(company: null));
    add(_filter.assigned, () => _filter.copyWith(assigned: null));
    if (_filter.timePeriod != 'All time') chips.add((_filter.timePeriod, () => setState(() => _filter = _filter.copyWith(timePeriod: 'All time'))));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in chips)
          Container(
            padding: const EdgeInsets.fromLTRB(11, 6, 6, 6),
            decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.evaGreen200)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(c.$1, style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
              const SizedBox(width: 4),
              InkWell(onTap: c.$2, child: const Icon(Icons.close_rounded, size: 14, color: AppColors.evaGreenDeep)),
            ]),
          ),
      ],
    );
  }

  Widget _bulkBar(List<LeadDto> filtered) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: AppColors.surface, border: const Border(top: BorderSide(color: AppColors.line)), boxShadow: AppColors.shadowMd),
      child: Row(children: [
        Text('${_selected.length} selected', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
        const Spacer(),
        TextButton(
          onPressed: () => setState(() {
            if (_selected.length == filtered.length) {
              _selected.clear();
            } else {
              _selected
                ..clear()
                ..addAll(filtered.map((l) => l.id));
            }
          }),
          child: Text(_selected.length == filtered.length ? 'Deselect all' : 'Select all', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
        ),
        const SizedBox(width: 4),
        FilledButton(onPressed: _selected.isEmpty ? null : () => _bulkUpdate(filtered), style: FilledButton.styleFrom(backgroundColor: AppColors.evaGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text('Update', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: Colors.white))),
        const SizedBox(width: 8),
        IconButton(onPressed: _selected.isEmpty ? null : () => _bulkDelete(filtered), icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger)),
      ]),
    );
  }

  LeadStatus _displayStatus(LeadDto l) => _statusOverride.containsKey(l.id) ? leadStatusFromString(_statusOverride[l.id]) : l.status;

  void _openActions(LeadDto l) {
    final p = _page;
    showLeadActions(
      context,
      l,
      onChanged: _reload,
      companies: p == null ? const [] : _companyNames(p),
      sources: p == null ? const [] : _sourceNames(p),
      agents: _agentNames(),
    );
  }

  Widget _leadCard(LeadDto l) {
    final selected = _selected.contains(l.id);
    return _renderLeadCard(
      context,
      l,
      selectMode: _selectMode,
      selected: selected,
      status: _displayStatus(l),
      onTap: _selectMode
          ? () => setState(() => selected ? _selected.remove(l.id) : _selected.add(l.id))
          : () => _openActions(l),
    );
  }

  Widget _kanbanView(List<LeadDto> leads) {
    const cols = kLeadStatuses;
    final groups = <String, List<LeadDto>>{for (final c in cols) c: []};
    for (final l in leads) {
      final label = _displayStatus(l).label;
      (groups[label] ??= []).add(l);
    }

    final double boardHeight = math.max(480.0, MediaQuery.of(context).size.height * 0.62);

    return SizedBox(
      height: boardHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: cols.asMap().entries.map((entry) {
          final colIndex = entry.key;
          final status = entry.value;
          final list = groups[status] ?? const [];
          final statusStyle = leadStatusFromString(status);

          return DragTarget<LeadDto>(
            onWillAcceptWithDetails: (d) => _displayStatus(d.data).label != status,
            onAcceptWithDetails: (d) => _changeStatus(d.data, status),
            builder: (ctx, candidate, rejected) {
              final hovering = candidate.isNotEmpty;
              return Container(
                width: 250,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hovering ? AppColors.evaGreen50 : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hovering ? AppColors.evaGreen : AppColors.line,
                    width: hovering ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Column Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusStyle.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: statusStyle.fg, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: statusStyle.fg),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${list.length}',
                              style: AppText.poppins(size: 12, weight: FontWeight.w800, color: statusStyle.fg),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Column Lead Cards List
                    Expanded(
                      child: list.isEmpty
                          ? Center(
                              child: Text(
                                'Drop lead here',
                                style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink4),
                              ),
                            )
                          : ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (ctx, i) {
                                final l = list[i];
                                final display = l.name.isEmpty ? l.mobile : l.name;

                                final cardContent = AppCard(
                                  padding: const EdgeInsets.all(12),
                                  onTap: () => _openActions(l),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          InitialsAvatar(
                                            initials: _initials(display),
                                            color: avatarColorFor(display),
                                            size: 30,
                                            radius: 9,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              display,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        l.mobile,
                                        style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        l.assignedTo ?? 'Unassigned',
                                        style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink4),
                                      ),
                                      const SizedBox(height: 8),
                                      const Divider(height: 1, color: AppColors.line),
                                      const SizedBox(height: 6),
                                      // Left-to-Right Status Change Buttons (Overflow-safe)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          if (colIndex > 0)
                                            Flexible(
                                              child: InkWell(
                                                borderRadius: BorderRadius.circular(6),
                                                onTap: () => _changeStatus(l, cols[colIndex - 1]),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.chevron_left_rounded, size: 16, color: AppColors.ink3),
                                                      Flexible(
                                                        child: Text(
                                                          cols[colIndex - 1],
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: AppText.poppins(size: 10.5, weight: FontWeight.w700, color: AppColors.ink3),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            const SizedBox.shrink(),
                                          if (colIndex < cols.length - 1)
                                            Flexible(
                                              child: InkWell(
                                                borderRadius: BorderRadius.circular(6),
                                                onTap: () => _changeStatus(l, cols[colIndex + 1]),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          cols[colIndex + 1],
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: AppText.poppins(size: 10.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
                                                        ),
                                                      ),
                                                      const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.evaGreenDeep),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            const SizedBox.shrink(),
                                        ],
                                      ),
                                    ],
                                  ),
                                );

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Draggable<LeadDto>(
                                    data: l,
                                    affinity: Axis.horizontal,
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: SizedBox(
                                        width: 220,
                                        child: Opacity(
                                          opacity: 0.9,
                                          child: cardContent,
                                        ),
                                      ),
                                    ),
                                    childWhenDragging: Opacity(
                                      opacity: 0.3,
                                      child: cardContent,
                                    ),
                                    child: cardContent,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Future<void> _changeStatus(LeadDto l, String status) async {
    if (_isLeadConverted(l)) {
      _snack('Converted customer status cannot be changed');
      return;
    }
    final currentLabel = _displayStatus(l).label;
    final isCurrentNew = currentLabel == 'New Lead' || currentLabel == 'New';
    final targetIsNew = status == 'New Lead' || status == 'New';
    if (!isCurrentNew && targetIsNew) {
      _snack('Cannot change status back to New Lead');
      return;
    }

    final cleanStatus = (status == 'Customer' || status == 'Converted') ? 'Customer' : status;
    setState(() => _statusOverride[l.id] = cleanStatus);
    if (cleanStatus == 'Customer') {
      try {
        await AppScope.of(context).leads.convertLead(l.id);
      } catch (_) {}
      if (mounted) {
        _snack('${l.name.isEmpty ? 'Lead' : l.name} converted to customer');
        _reload();
      }
      return;
    }
    try {
      await AppScope.of(context).leads.updateLead(l.id, {'status': cleanStatus});
    } catch (_) {}
    if (mounted) {
      _snack('Moved to $cleanStatus');
      _reload();
    }
  }

  bool _isLeadConverted(LeadDto l) {
    final label = _displayStatus(l).label.toLowerCase();
    return l.isConverted || label == 'customer' || label == 'converted';
  }

  // ---------------- Companies ----------------
  Widget _companies(LeadsPage page) {
    final counts = <String, int>{};
    for (final l in page.leads.where(_isLeadConverted)) {
      final key = l.company.trim().isEmpty ? 'No Company' : l.company.trim();
      if (_query.isEmpty || key.toLowerCase().contains(_query.toLowerCase()) || _matchesQuery(l)) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      children: [
        Row(
          children: [
            Expanded(child: _searchField('Search companies')),
            const SizedBox(width: 10),
            GestureDetector(onTap: _reload, child: _iconBtn(Icons.refresh_rounded, isLoading: _isReloading)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _toolBtn(Icons.download_rounded, 'Import Customers', () => showImportWizard(context, onDone: () { _snack('Customers imported'); _reload(); })),
              const SizedBox(width: 10),
              _toolBtn(Icons.description_outlined, 'Sample CSV', () => _downloadSampleCsv()),
              const SizedBox(width: 10),
              _toolBtn(Icons.file_upload_outlined, 'Export', () => _exportLeads(page.leads.where(_isLeadConverted).toList())),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text('${entries.length} companies', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2)),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No companies found',
                style: AppText.poppins(size: 14, color: AppColors.ink3, weight: FontWeight.w600),
              ),
            ),
          )
        else
          ...entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  padding: const EdgeInsets.all(15),
                  onTap: () {
                    final members = page.leads.where((l) => _isLeadConverted(l) && (l.company.trim().isEmpty ? 'No Company' : l.company.trim()) == e.key).toList();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => _CompanyCustomersScreen(company: e.key, leads: members)));
                },
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.business_rounded, color: AppColors.evaGreenDeep, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.key, style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                          const SizedBox(height: 3),
                          Text('${e.value} customer${e.value == 1 ? '' : 's'}', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.ink4),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.chevron_left_rounded, color: AppColors.ink4),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.evaGreen,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '1',
                style: AppText.poppins(size: 13, weight: FontWeight.w800, color: Colors.white),
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.chevron_right_rounded, color: AppColors.ink4),
            ),
          ],
        ),
      ],
    );
  }

  Widget _customers(LeadsPage page) {
    final list = page.leads.where(_isLeadConverted).toList();
    final filtered = list.where(_filter.matches).where(_matchesQuery).toList();
    String since(DateTime? d) => d == null ? '—' : '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      children: [
        Row(
          children: [
            Expanded(child: _searchField('Search customers')),
            const SizedBox(width: 10),
            GestureDetector(onTap: _reload, child: _iconBtn(Icons.refresh_rounded, isLoading: _isReloading)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _toolBtn(Icons.download_rounded, 'Import Customers', () => showImportWizard(context, onDone: () { _snack('Customers imported'); _reload(); })),
              const SizedBox(width: 10),
              _toolBtn(Icons.description_outlined, 'Sample CSV', () => _downloadSampleCsv()),
              const SizedBox(width: 10),
              _toolBtn(Icons.file_upload_outlined, 'Export', () => _exportLeads(filtered)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _dateRangePill(),
        const SizedBox(height: 14),
        Text('${filtered.length} customers', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2)),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No customers found',
                style: AppText.poppins(size: 14, color: AppColors.ink3, weight: FontWeight.w600),
              ),
            ),
          )
        else
          ...filtered.map((l) {
            final display = l.name.isEmpty ? 'Unknown' : l.name;
            final displayDate = l.conversionDate ?? l.createdAt;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomerDetailScreen(lead: l))),
                child: Row(
                  children: [
                    InitialsAvatar(initials: _initials(display), color: avatarColorFor(display), size: 44, radius: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(child: Text(display, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink))),
                              const SizedBox(width: 8),
                              _lifecycleBadge(l),
                            ],
                          ),
                          if (l.company.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(l.company, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3)),
                          ],
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded, size: 13, color: AppColors.ink4),
                              const SizedBox(width: 4),
                              Flexible(child: Text(l.assignedTo ?? 'Unassigned', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink4))),
                              const SizedBox(width: 10),
                              const Icon(Icons.schedule_rounded, size: 13, color: AppColors.ink4),
                              const SizedBox(width: 4),
                              Text('Since ${since(displayDate)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink4)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text('View', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.evaGreenDeep),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // ---------------- small pieces ----------------
  Widget _searchField(String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.line)),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: AppColors.ink4),
          const SizedBox(width: 11),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.ink4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filtersButton() {
    final count = _filter.activeCount;
    return GestureDetector(
      onTap: _openFilters,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(color: AppColors.evaGreen, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.filter_alt_outlined, size: 17, color: Colors.white),
                const SizedBox(width: 7),
                Text('Filters', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
          if (count > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 18, height: 18, alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.danger, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                child: Text('$count', style: AppText.poppins(size: 9.5, weight: FontWeight.w800, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolBtn(IconData icon, String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.line)),
          child: Row(
            children: [
              Icon(icon, size: 15, color: AppColors.ink2),
              const SizedBox(width: 6),
              Text(label, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink)),
            ],
          ),
        ),
      );

  Widget _iconBtn(IconData icon, {bool isLoading = false}) => Container(
        width: 44, height: 44, alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
        child: isLoading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.evaGreenDeep))
            : Icon(icon, size: 19, color: AppColors.evaGreenDeep),
      );

  Widget _selectPill(List<LeadDto> filtered) => GestureDetector(
        onTap: () => setState(() {
          _selectMode = !_selectMode;
          if (!_selectMode) _selected.clear();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: _selectMode ? AppColors.evaGreen50 : AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _selectMode ? AppColors.evaGreen200 : AppColors.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_selectMode ? Icons.close_rounded : Icons.check_box_outlined, size: 15, color: AppColors.evaGreenDeep),
            const SizedBox(width: 5),
            Text(_selectMode ? 'Cancel' : 'Select', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
          ]),
        ),
      );

  Widget _viewToggle() {
    Widget btn(IconData icon, bool active, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36, height: 32, alignment: Alignment.center,
            decoration: BoxDecoration(color: active ? AppColors.evaGreen50 : AppColors.surface, borderRadius: BorderRadius.circular(9), border: Border.all(color: active ? AppColors.evaGreen200 : AppColors.line)),
            child: Icon(icon, size: 17, color: active ? AppColors.evaGreenDeep : AppColors.ink4),
          ),
        );
    return Row(children: [
      btn(Icons.format_list_bulleted_rounded, !_kanban, () => setState(() => _kanban = false)),
      const SizedBox(width: 6),
      btn(Icons.view_kanban_outlined, _kanban, () => setState(() => _kanban = true)),
    ]);
  }

  Widget _dateRangePill() => GestureDetector(
        onTap: () async {
          final picked = await showModalBottomSheet<List<DateTime>>(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (ctx) => CustomDateRangePicker(initialRange: _filter.dateRange),
          );
          if (picked != null && picked.length == 2) {
            setState(() {
              _filter = _filter.copyWith(dateRange: picked);
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.evaGreen50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.evaGreen200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _filter.dateRange == null
                      ? 'Start date → End date'
                      : '${_filter.dateRange![0].day}/${_filter.dateRange![0].month}/${_filter.dateRange![0].year} → ${_filter.dateRange![1].day}/${_filter.dateRange![1].month}/${_filter.dateRange![1].year}',
                  style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.evaGreenDeep),
                ),
              ),
              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.evaGreenDeep),
            ],
          ),
        ),
      );

  Widget _lifecycleBadge(LeadDto l) {
    final state = _lifecycle[l.id] ?? 0;
    final (label, fg, bg) = switch (state) {
      1 => ('At-risk', AppColors.warmFg, AppColors.warmBg),
      2 => ('Churned', AppColors.ink3, AppColors.surface3),
      _ => ('Active', AppColors.evaGreenDeep, AppColors.evaGreen50),
    };
    return GestureDetector(
      onTap: () {
        setState(() => _lifecycle[l.id] = (state + 1) % 3);
        _snack('${l.name.isEmpty ? 'Customer' : l.name} → $label'.replaceFirst(label, ['Active', 'At-risk', 'Churned'][(state + 1) % 3]));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: AppText.poppins(size: 10.5, weight: FontWeight.w700, color: fg)),
        ]),
      ),
    );
  }

  // ---------------- Dashboard Layouts & Widgets ----------------
  Widget _dashboardView() {
    final isOverview = _dashboardSub == 0;
    return RefreshIndicator(
      color: AppColors.evaGreen,
      onRefresh: () async {
        setState(() {
          if (isOverview) {
            _overviewFuture = _loadOverview();
          } else {
            _perfFuture = _loadPerf();
          }
        });
      },
      child: isOverview
          ? AsyncView<AnalyticsDto>(
              future: _overviewFuture,
              onRetry: () => setState(() => _overviewFuture = _loadOverview()),
              builder: (data) => _overviewLayout(data),
            )
          : AsyncView<AnalyticsDto>(
              future: _perfFuture,
              onRetry: () => setState(() => _perfFuture = _loadPerf()),
              builder: (data) => _performanceLayout(data),
            ),
    );
  }

  Widget _overviewLayout(AnalyticsDto data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      children: [
        // Filters bar
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.ink3),
                  const SizedBox(width: 6),
                  Text(
                    _overviewTimeFilter == 'all' ? 'All time' : 'Last $_overviewTimeFilter days',
                    style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink2),
                  ),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _showFilterSheet(true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.evaGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'Filters',
                      style: AppText.poppins(size: 12, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 3x2 Grid of metrics
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.7,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          children: [
            _metricCard('Hot Leads', '${data.overview.hotLeads}', Icons.local_fire_department_rounded, const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
            _metricCard('Customers', '${data.overview.customers}', Icons.check_circle_outline_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5)),
            _metricCard('Conversion Rate', '${data.overview.conversionRate.toStringAsFixed(1)}%', Icons.trending_up_rounded, const Color(0xFF8B5CF6), const Color(0xFFF5F3FF)),
            _metricCard('Achieved Value', '₹${data.overview.achievedValue.toInt()}', Icons.account_balance_wallet_outlined, const Color(0xFF10B981), const Color(0xFFECFDF5)),
            _metricCard('Total Value', '₹${data.overview.totalValue.toInt()}', Icons.credit_card_outlined, const Color(0xFFF59E0B), const Color(0xFFFFFBEB)),
            _metricCard('Total Leads', '${data.overview.totalLeads}', Icons.people_outline_rounded, const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
          ],
        ),
        const SizedBox(height: 16),
        // Lead Status Pie Card
        _leadStatusCard(data),
        const SizedBox(height: 16),
        // Redesigned 30-Day Trend Card
        _TrendChartCard(trend: data.monthlyTrend),
        const SizedBox(height: 16),
        // Top Performers Card
        _topPerformers(data.employeePerformance),
      ],
    );
  }

  Widget _metricCard(String title, String val, IconData icon, Color iconColor, Color iconBg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            val,
            style: AppText.poppins(size: 19, weight: FontWeight.w800, color: AppColors.ink),
          ),
        ],
      ),
    );
  }

  Widget _leadStatusCard(AnalyticsDto data) {
    final statusMap = data.statusCounts;
    final total = statusMap.values.fold<int>(0, (a, b) => a + b);
    
    final selectedStatus = _selectedLeadStatus ?? 'New';
    
    final legendItems = [
      ('New', statusMap['New Lead'] ?? statusMap['New'] ?? 0, const Color(0xFF3B82F6)),
      ('Hot', statusMap['Hot'] ?? 0, const Color(0xFFF2542D)),
      ('Warm', statusMap['Warm'] ?? 0, const Color(0xFFE0A106)),
      ('Cold', statusMap['Cold'] ?? 0, const Color(0xFF88CD8F)),
      ('Customer', statusMap['Converted'] ?? statusMap['Customer'] ?? 0, const Color(0xFF2BA84A)),
    ];

    final segments = <DonutSegment>[];
    for (final item in legendItems) {
      if (item.$2 > 0) {
        final isSel = selectedStatus.toLowerCase() == item.$1.toLowerCase();
        final finalColor = isSel ? item.$3 : item.$3.withValues(alpha: 0.25);
        segments.add(DonutSegment(item.$2.toDouble(), finalColor, label: item.$1));
      }
    }

    if (segments.isEmpty) {
      segments.add(const DonutSegment(1.0, Colors.grey, label: 'New'));
    }

    final selectedCount = legendItems.firstWhere((item) => item.$1.toLowerCase() == selectedStatus.toLowerCase(), orElse: () => legendItems[0]).$2;

    // Use total leads count so total is not unused
    final totalCountText = 'Total leads: $total';
    debugPrint(totalCountText);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_rounded, color: AppColors.evaGreenDeep, size: 20),
              const SizedBox(width: 8),
              Text(
                'Lead Status',
                style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Center(
                  child: DonutChart(
                    segments: segments,
                    centerValue: selectedStatus,
                    centerLabel: '$selectedCount',
                    size: 120,
                    thickness: 16,
                    onSegmentTap: (index, segment) {
                      if (segment.label != null && segment.label!.isNotEmpty) {
                        setState(() {
                          _selectedLeadStatus = segment.label;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: legendItems.map((item) {
                    final isSel = selectedStatus.toLowerCase() == item.$1.toLowerCase();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedLeadStatus = item.$1;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFFEAF9E6) : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: item.$3, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.$1,
                                  style: AppText.poppins(
                                    size: 12.5, 
                                    weight: isSel ? FontWeight.w800 : FontWeight.w600, 
                                    color: isSel ? AppColors.evaGreenDeep : AppColors.ink3,
                                  ),
                                ),
                              ),
                              Text(
                                '${item.$2}',
                                style: AppText.poppins(
                                  size: 12.5, 
                                  weight: isSel ? FontWeight.w800 : FontWeight.w700, 
                                  color: isSel ? AppColors.evaGreenDeep : AppColors.ink,
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _performanceLayout(AnalyticsDto data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.ink3),
                  const SizedBox(width: 6),
                  Text(
                    _perfTimeFilter == 'all' ? 'All time' : 'Last $_perfTimeFilter days',
                    style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink2),
                  ),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _showFilterSheet(false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.evaGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'Filters',
                      style: AppText.poppins(size: 12, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.people_outline_rounded, color: AppColors.evaGreenDeep, size: 20),
            const SizedBox(width: 8),
            Text(
              'Agents Performance',
              style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (data.employeePerformance.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('No performance data available', style: AppText.poppins(size: 13, color: AppColors.ink4))),
          )
        else
          ...data.employeePerformance.map((item) => _AgentPerformanceCard(item: item)),
        const SizedBox(height: 16),
        _CompanyPerformanceTable(data: data.companyPerformance),
      ],
    );
  }

  Widget _topPerformers(List<EmployeePerformanceDto> perf) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, color: AppColors.evaGreenDeep, size: 20),
              const SizedBox(width: 8),
              Text(
                'Top Performers',
                style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (perf.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No performers found', style: AppText.poppins(size: 13, color: AppColors.ink4))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: perf.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (ctx, i) {
                final p = perf[i];
                final isUnassigned = p.employee.toLowerCase().contains('unassigned');
                final avColor = isUnassigned ? AppColors.ink4 : AppColors.evaGreen;
                final initial = p.employee.isNotEmpty ? p.employee[0].toUpperCase() : 'U';
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: avColor,
                          child: Text(initial, style: AppText.poppins(size: 14, weight: FontWeight.w800, color: Colors.white)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.employee,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${p.leads} leads · ${p.converted} converted',
                                style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${(p.value / 1000).toStringAsFixed(1)}k',
                          style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (p.conversionRate / 100).clamp(0.0, 1.0),
                              backgroundColor: AppColors.line,
                              color: AppColors.evaGreen,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${p.conversionRate.toInt()}%',
                          style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }



  void _showFilterSheet(bool isOverview) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DashboardFilterSheet(
        isOverview: isOverview,
        timeFilter: isOverview ? _overviewTimeFilter : _perfTimeFilter,
        selectedAssigned: isOverview ? _overviewAssigned : _perfAssigned,
        selectedSource: isOverview ? _overviewSource : _perfSource,
        selectedStatus: isOverview ? _overviewStatus : _perfStatus,
        dateRange: isOverview ? _overviewDateRange : null,
        onApply: (time, assigned, source, status, range) {
          setState(() {
            if (isOverview) {
              _overviewTimeFilter = time;
              _overviewAssigned = assigned;
              _overviewSource = source;
              _overviewStatus = status;
              _overviewDateRange = range;
              _overviewFuture = _loadOverview();
            } else {
              _perfTimeFilter = time;
              _perfAssigned = assigned;
              _perfSource = source;
              _perfStatus = status;
              _perfFuture = _loadPerf();
            }
          });
        },
      ),
    );
  }

}

class _TrendChartCard extends StatefulWidget {
  final List<TrendPointDto> trend;
  const _TrendChartCard({required this.trend});

  @override
  State<_TrendChartCard> createState() => _TrendChartCardState();
}

class _TrendChartCardState extends State<_TrendChartCard> {
  int _mode = 0; // 0 Daily, 1 Weekly
  int? _selectedBarIndex;

  String _formatFullDate(String dateStr) {
    try {
      final parts = dateStr.split(' ');
      if (parts.length >= 2) {
        final monthStr = parts[0];
        final day = int.tryParse(parts[1]);
        if (day != null) {
          final monthMap = {
            'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
            'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
          };
          final month = monthMap[monthStr.toLowerCase().substring(0, 3)];
          if (month != null) {
            final now = DateTime.now();
            final dt = DateTime(now.year, month, day);
            final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            final weekday = weekdays[dt.weekday - 1];
            return '$weekday, $dateStr';
          }
        }
      }
    } catch (_) {}
    return dateStr;
  }

  Widget _buildTooltip(TrendPointDto point) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        '${_formatFullDate(point.date)} - ${point.leads} leads',
        style: AppText.poppins(
          size: 11,
          weight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trendPoints = widget.trend;
    final totalLeads = trendPoints.fold<int>(0, (sum, p) => sum + p.leads);
    final avgLeads = trendPoints.isEmpty ? 0.0 : totalLeads / trendPoints.length;
    final maxVal = trendPoints.fold<int>(1, (max, p) => p.leads > max ? p.leads : max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up_rounded, color: AppColors.evaGreenDeep, size: 20),
              const SizedBox(width: 8),
              Text(
                '30-Day Trend',
                style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$totalLeads',
                    style: AppText.poppins(size: 28, weight: FontWeight.w800, color: AppColors.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'new leads - avg ${avgLeads.toStringAsFixed(1)}/day',
                    style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink4),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.trending_down_rounded, size: 12, color: Color(0xFFDC2626)),
                        const SizedBox(width: 4),
                        Text(
                          '-71%',
                          style: AppText.poppins(size: 11, weight: FontWeight.w700, color: const Color(0xFFDC2626)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Daily / Weekly Toggle
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        _toggleBtn('Daily', _mode == 0, () => setState(() => _mode = 0)),
                        _toggleBtn('Weekly', _mode == 1, () => setState(() => _mode = 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Chart bars representation
          if (trendPoints.isEmpty)
            Container(
              height: 100,
              alignment: Alignment.center,
              child: Text('No trend data available', style: AppText.poppins(size: 13, color: AppColors.ink4)),
            )
          else
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  height: 100,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(trendPoints.length, (idx) {
                      final p = trendPoints[idx];
                      final pct = maxVal > 0 ? (p.leads / maxVal) : 0.0;
                      final barHeight = (pct * 70).clamp(6.0, 70.0);
                      final isSelected = _selectedBarIndex == idx;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              _selectedBarIndex = isSelected ? null : idx;
                            });
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                width: 8,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.evaGreenDeep : AppColors.evaGreen,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                p.date,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.poppins(size: 9, weight: FontWeight.w700, color: AppColors.ink4),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                if (_selectedBarIndex != null && _selectedBarIndex! < trendPoints.length) ...[
                  Positioned(
                    top: -38,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _buildTooltip(trendPoints[_selectedBarIndex!]),
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 12),
          Text(
            'vs 7 in the prior 30 days',
            style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active ? AppColors.shadowXs : null,
        ),
        child: Text(
          label,
          style: AppText.poppins(
            size: 11.5,
            weight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? AppColors.ink : AppColors.ink4,
          ),
        ),
      ),
    );
  }
}

class _AgentPerformanceCard extends StatefulWidget {
  final EmployeePerformanceDto item;
  const _AgentPerformanceCard({required this.item});

  @override
  State<_AgentPerformanceCard> createState() => _AgentPerformanceCardState();
}

class _AgentPerformanceCardState extends State<_AgentPerformanceCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isUnassigned = item.employee.toLowerCase().contains('unassigned');
    final avColor = isUnassigned ? AppColors.ink4 : AppColors.evaGreen;
    final initial = item.employee.isNotEmpty ? item.employee[0].toUpperCase() : 'U';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: avColor,
                child: Text(initial, style: AppText.poppins(size: 14, weight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.employee,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  color: AppColors.evaGreen,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: Text('${item.leads}', style: AppText.poppins(size: 11, weight: FontWeight.w800, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (item.conversionRate / 100).clamp(0.0, 1.0),
                    backgroundColor: AppColors.line,
                    color: AppColors.evaGreen,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${item.conversionRate.toInt()}%',
                style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.ink3),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.wallet_outlined, size: 14, color: AppColors.ink4),
              const SizedBox(width: 5),
              Text(
                '₹${item.value.toInt()}',
                style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Row(
                  children: [
                    Icon(
                      _expanded ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 15,
                      color: AppColors.evaGreenDeep,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _expanded ? 'Hide Details' : 'View Details',
                      style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 14),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              children: [
                _gridItem('Total Leads', '${item.leads}'),
                _gridItem('Converted', '${item.converted}'),
                _gridItem('Conversion Rate', '${item.conversionRate.toInt()}%'),
                _gridItem('Total Value', '₹${item.value.toInt()}'),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'New · Hot · Warm · Cold · Converted',
              style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink4),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _statusChip('${item.newLead} New', Colors.blue),
                _statusChip('${item.warm} Warm', Colors.orange),
                _statusChip('${item.hot} Hot', Colors.red),
                _statusChip('${item.converted} Customer', AppColors.evaGreen),
                _statusChip('${item.cold} Cold', Colors.grey),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _gridItem(String k, String v) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(k, style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink4)),
          const SizedBox(height: 2),
          Text(v, style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: AppText.poppins(size: 11, weight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _CompanyPerformanceTable extends StatelessWidget {
  final List<CompanyPerformanceDto> data;
  const _CompanyPerformanceTable({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: AppColors.evaGreenDeep, size: 20),
              const SizedBox(width: 8),
              Text(
                'Detailed Company Performance',
                style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('Company', style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink4)),
              ),
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.center,
                  child: Text('Leads', style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink4)),
                ),
              ),
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.center,
                  child: Text('Converted', style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink4)),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.line),
          if (data.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No company data found', style: AppText.poppins(size: 13, color: AppColors.ink4))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.length,
              separatorBuilder: (_, _) => const Divider(height: 20, color: AppColors.line),
              itemBuilder: (ctx, i) {
                final item = data[i];
                final initial = item.company.isNotEmpty ? item.company[0].toUpperCase() : 'C';
                final color = avatarColorFor(item.company);
                return Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: color,
                            child: Text(initial, style: AppText.poppins(size: 11, weight: FontWeight.w800, color: Colors.white)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.company,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.evaGreen, shape: BoxShape.circle),
                          child: Text('${item.leads}', style: AppText.poppins(size: 11, weight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.evaGreen, shape: BoxShape.circle),
                          child: Text('${item.converted}', style: AppText.poppins(size: 11, weight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ScanCardFab extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanCardFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.evaGreen,
      borderRadius: BorderRadius.circular(30),
      elevation: 4,
      shadowColor: AppColors.evaGreen.withValues(alpha: 0.5),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Scan Card',
                style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Validates and sanitizes individual fields extracted during card scanning
class LeadFieldValidator {
  // ── Email ──────────────────────────────────────────────────────────────
  static bool isValidEmail(String val) {
    final clean = val.trim().replaceAll(' ', '');
    if (clean.length < 5) return false;
    return RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]{2,}$', caseSensitive: false).hasMatch(clean);
  }

  // ── Mobile (rejects Landline, Telephone, Fax) ─────────────────────────
  static bool isValidMobile(String digits, {String segmentText = ''}) {
    final seg = segmentText.toLowerCase();
    // Reject Fax
    if (seg.contains('fax') || seg.contains('f:') || seg.contains('f-')) return false;
    // Reject labelled Telephone / Landline / Office
    if (seg.startsWith('tel:') || seg.contains('telephone') || seg.contains('landline') || seg.startsWith('office:') || seg.startsWith('t:')) return false;
    final d = digits.replaceAll(RegExp(r'[^\d]'), '');
    if (d.length < 7 || d.length > 15) return false;
    // 10-digit Indian numbers: mobile starts 6–9, landline starts 2–5
    if (d.length == 10) {
      final f = d[0];
      if (f == '2' || f == '3' || f == '4' || f == '5') return false;
    }
    return true;
  }

  // ── Website ────────────────────────────────────────────────────────────
  static bool isValidWebsite(String val) {
    final c = val.trim().toLowerCase();
    if (c.length < 4) return false;
    return RegExp(r'^(https?://)?(www\.)?[\w-]+\.[\w.]{2,}(/\S*)?$', caseSensitive: false).hasMatch(c);
  }

  // Helper to clean degrees (B.E., M.E., B.Tech, Ph.D., MBA) and trailing punctuation from name candidate
  static String cleanPersonName(String val) {
    String name = val.trim()
        .replaceAll('*', ' ')
        .replaceAll('!', 'i')
        .replaceAll(',', ' ')
        .replaceAll(';', ' ')
        .replaceAll(':', ' ')
        .replaceAll('"', ' ')
        .replaceAll("'", ' ');
    
    // Remove educational qualification suffixes (B.E., M.E., B.Tech, M.Tech, MBA, Ph.D., M.D., B.Sc, M.Sc, B.Com, M.Com)
    name = name.replaceAll(RegExp(r'\b(b\.?e\.?|m\.?e\.?|b\.?tech\.?|m\.?tech\.?|m\.?b\.?a\.?|ph\.?d\.?|m\.?d\.?|b\.?sc\.?|m\.?sc\.?|b\.?com\.?|m\.?com\.?)\b', caseSensitive: false), ' ');
    return name.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // ── Person Name ────────────────────────────────────────────────────────
  /// Accepts: "R. Kamalakannan", "KARTHIKESH SUNDHARESH", "V. NAGARAJA", "Dr. Anil Kumar"
  /// Rejects: company names, designations, addresses, slogans, URLs, phone numbers
  static bool isValidName(String val) {
    final clean = cleanPersonName(val);
    if (clean.length < 2 || clean.length > 40) return false;
    // Must not contain digits or special symbols
    if (RegExp(r'[\d@#\$%&*()_+=\[\]{}<>|/\\]').hasMatch(clean)) return false;
    final low = clean.toLowerCase();
    // Must not be a URL or email
    if (low.contains('www.') || low.contains('@') || low.contains('.com') || low.contains('.in') || low.contains('.org') || low.contains('.io') || low.contains('.net')) return false;
    // Blocked slogans & marketing tags
    if (low == 'go gre' || low == 'go green' || low == 'save earth' || low == 'iso certified' || low.startsWith('iso ')) return false;
    
    // Blocked keywords — company suffixes, designations, addresses, institutional keywords
    const blocked = [
      'pvt', 'ltd', 'limited', 'llp', 'inc', 'llc', 'corp', 'corporation', 'company', 'co',
      'solutions', 'technologies', 'technology', 'systems', 'services',
      'enterprises', 'industries', 'consulting', 'consultancy', 'group', 'global',
      'international', 'ventures', 'software', 'digital', 'automations',
      'infra', 'infrastructure', 'projects', 'constructions', 'developers',
      'builders', 'engineering', 'logistics', 'estates', 'traders', 'exports',
      'imports', 'agency', 'firm', 'labs', 'pharmaceuticals', 'pharma',
      'biotech', 'healthcare', 'laboratories', 'chemicals', 'sciences',
      'lifesciences', 'diagnostics', 'studios', 'battery', 'batteries', 'energy', 'power', 'solar',
      'startup', 'incubation', 'park', 'campus', 'university', 'college', 'hall',
      'floor', 'centre', 'center', 'association', 'trust', 'foundation',
      'managing', 'partner', 'partmer', 'proprietor', 'propriter',
      'founder', 'owner', 'director', 'manager', 'engineer', 'architect',
      'specialist', 'executive', 'president', 'consultant', 'officer',
      'analyst', 'associate', 'developer', 'designer', 'advocate',
      'advisor', 'coordinator', 'supervisor', 'administrator', 'agent',
      'sales', 'marketing', 'head', 'lead', 'vp', 'chief', 'officer', 'business',
      'street', 'road', 'nagar', 'sector', 'phase', 'building', 'tower',
      'complex', 'plot', 'marg', 'chowk', 'colony',
    ];
    if (blocked.any((k) => low == k || low.startsWith('$k ') || low.endsWith(' $k') || low.contains(' $k ') || low.contains('$k '))) return false;
    // 1–4 words, each word only letters, dots, or hyphens
    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length > 4) return false;
    for (final w in words) {
      if (!RegExp(r'^[A-Za-z.\-]+$').hasMatch(w)) return false;
    }
    // At least one real word with ≥2 alphabetic characters
    return words.any((w) => RegExp(r'[A-Za-z]{2,}').hasMatch(w));
  }

  // ── Company Name ───────────────────────────────────────────────────────
  static bool isValidCompany(String val, {String? personName}) {
    final clean = val.trim().replaceAll('*', '').replaceAll('!', 'i').trim();
    if (clean.length < 2 || clean.length > 70) return false;
    final low = clean.toLowerCase();
    // Must not be an email or URL
    if (clean.contains('@') || low.startsWith('www.')) return false;
    // Must not be a phone / fax line
    if (RegExp(r'^(ph\+|ph:|mob:|tel:|cell:|fax:)', caseSensitive: false).hasMatch(low)) return false;
    if (clean.replaceAll(RegExp(r'[^\d]'), '').length >= 7) return false;
    // Reject standalone suffixes with no brand name
    const standaloneSuffixes = ['pvt ltd', 'pvt limited', 'private limited', 'ltd', 'limited', 'inc', 'llc', 'corp', 'corporation'];
    if (standaloneSuffixes.contains(low)) return false;
    // Must not equal the person name
    if (personName != null && personName.isNotEmpty && low == personName.toLowerCase()) return false;
    return true;
  }

  // ── Position / Designation ────────────────────────────────────────────
  static bool isValidPosition(String val) {
    final clean = val.trim();
    if (clean.length < 2 || clean.length > 50) return false;
    if (RegExp(r'[@#\$%&*()_+=\[\]{}<>|/\\\d]').hasMatch(clean)) return false;
    return true;
  }

  // ── City & Country ────────────────────────────────────────────────────
  static bool isValidCity(String val) {
    final c = val.trim();
    return c.length >= 2 && c.length <= 30 && !RegExp(r'[\d@#\$%&*_+=<>|/\\]').hasMatch(c);
  }

  static bool isValidCountry(String val) {
    final c = val.trim();
    return c.length >= 2 && c.length <= 35 && !RegExp(r'[\d@#\$%&*_+=<>|/\\]').hasMatch(c);
  }
}

LeadDto _mergeLeads(LeadDto a, LeadDto b) {
  String pickBest(String valA, String valB) {
    if (valA.isEmpty || valA == 'Scanned Contact') return valB;
    if (valB.isEmpty || valB == 'Scanned Contact') return valA;
    return valA.length >= valB.length ? valA : valB;
  }

  String pickMobile(String mA, String mB) {
    if (mA.length >= 7) return mA;
    return mB;
  }

  final mobile = pickMobile(a.mobile, b.mobile);
  final countryCode = a.mobile.length >= 7
      ? a.countryCode
      : (b.mobile.length >= 7 ? b.countryCode : (a.countryCode.isNotEmpty ? a.countryCode : b.countryCode));

  return LeadDto(
    id: a.id.isNotEmpty ? a.id : b.id,
    name: pickBest(a.name, b.name),
    email: pickBest(a.email, b.email),
    mobile: mobile,
    countryCode: countryCode.isNotEmpty ? countryCode : '+91',
    company: pickBest(a.company, b.company),
    position: pickBest(a.position, b.position),
    address: pickBest(a.address, b.address),
    city: pickBest(a.city, b.city),
    country: pickBest(a.country, b.country),
    website: pickBest(a.website, b.website),
    statusRaw: a.statusRaw.isNotEmpty ? a.statusRaw : b.source,
    source: a.source.isNotEmpty ? a.source : b.source,
    createdAt: a.createdAt,
  );
}

/// Google Gemini AI Card Parser Service (Multimodal Vision + Text API)
class GeminiCardParser {
  static Future<LeadDto?> parseWithGeminiVision(String imagePath, List<String> rawOcrLines) async {
    final rawText = rawOcrLines.join('\n').trim();

    String? base64Image;
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          base64Image = base64Encode(bytes);
        }
      }
    } catch (e) {
      print('⚠️ Error encoding image for Gemini Vision: $e');
    }

    try {
      final prompt = '''
You are an expert business card OCR parser. Analyze this business card image and text, and extract exact contact details with high accuracy.

CRITICAL PARSING RULES FOR ACCURACY:
1. COMPANY NAME: Detect the Company / Organization Name accurately. Companies often present their company name using unique custom fonts, brand logos, or large header typography on the card. Cross-reference the company brand logo/header text with the website domain (e.g. www.acmecorp.com -> Acme Corp) or email domain (e.g. info@acmecorp.com -> Acme Corp) to identify and extract the exact Company Name without mismatch.
2. MOBILE NUMBER: Extract the full mobile phone number accurately without missing digits (e.g., 10 digits for Indian mobile numbers starting with 6-9, or full international format with country code like +91 9876543210). Ensure no digits are omitted or confused with letter characters.

Return ONLY a valid JSON object with these exact keys (no markdown code block, no extra explanation):
{
  "name": "Full Person Name (strip qualification degrees like B.E., M.E., MBA, Ph.D. unless part of name)",
  "company": "Full Company / Organization Name",
  "position": "Job Title / Designation / Position",
  "email": "Email address",
  "mobile": "Full Mobile phone number (10 digits minimum or full international number)",
  "website": "Company website URL",
  "address": "Full Street Address / Location",
  "city": "City",
  "country": "Country"
}

Raw OCR Text Context:
$rawText
''';

      // 1. Try Backend API first if running
      try {
        final backendUrl = Uri.parse('https://api.askeva.net/v1/gemini/parse-card');
        final response = await http.post(
          backendUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'rawText': rawText,
            if (base64Image != null) 'base64Image': base64Image,
          }),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final leadData = data['data'] ?? data;
          if (leadData != null && (leadData['name'] != null || leadData['company'] != null)) {
            return LeadDto(
              id: '',
              name: leadData['name']?.toString() ?? '',
              email: leadData['email']?.toString() ?? '',
              mobile: leadData['phone']?.toString() ?? leadData['mobile']?.toString() ?? '',
              countryCode: '+91',
              company: leadData['company']?.toString() ?? '',
              position: leadData['role']?.toString() ?? leadData['position']?.toString() ?? '',
              address: leadData['location']?.toString() ?? leadData['address']?.toString() ?? '',
              city: leadData['city']?.toString() ?? '',
              country: leadData['country']?.toString() ?? '',
              website: leadData['website']?.toString() ?? '',
              statusRaw: 'New Lead',
              source: 'Business Card (Gemini AI Vision)',
              createdAt: DateTime.now(),
            );
          }
        }
      } catch (_) {}

      // 2. Direct Gemini REST API call (Multimodal Image + Text Vision API)
      final apiKey = GeminiConfig.apiKey;
      if (apiKey.isNotEmpty) {
        final apiUrl = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey');
        
        final List<Map<String, dynamic>> parts = [
          {"text": prompt}
        ];
        if (base64Image != null) {
          parts.add({
            "inline_data": {
              "mime_type": "image/jpeg",
              "data": base64Image,
            }
          });
        }

        final res = await http.post(
          apiUrl,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            "contents": [
              {
                "parts": parts
              }
            ],
            "generationConfig": {
              "temperature": 0.1,
              "responseMimeType": "application/json"
            }
          }),
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final textResp = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
          final cleanJsonStr = textResp.replaceAll('```json', '').replaceAll('```', '').trim();
          final parsed = jsonDecode(cleanJsonStr);

          return LeadDto(
            id: '',
            name: parsed['name']?.toString() ?? '',
            email: parsed['email']?.toString() ?? '',
            mobile: parsed['mobile']?.toString() ?? '',
            countryCode: '+91',
            company: parsed['company']?.toString() ?? '',
            position: parsed['position']?.toString() ?? '',
            address: parsed['address']?.toString() ?? '',
            city: parsed['city']?.toString() ?? '',
            country: parsed['country']?.toString() ?? '',
            website: parsed['website']?.toString() ?? '',
            statusRaw: 'New Lead',
            source: 'Business Card (Gemini AI Vision)',
            createdAt: DateTime.now(),
          );
        } else {
          print('⚠️ Gemini API HTTP ${res.statusCode} Error: ${res.body}');
        }
      }
    } catch (e) {
      print('⚠️ Gemini AI Vision card parser exception: $e');
    }
    return null;
  }
}

/// Runs ML Kit text recognition on [imagePath] and extracts lead fields.
/// Uses Google Gemini AI Vision parsing with robust on-device weighted scoring fallback.
Future<LeadDto> _ocrToLead(String imagePath) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final inputImage = InputImage.fromFilePath(imagePath);
  final recognised = await recognizer.processImage(inputImage);
  await recognizer.close();

  // ── Collect ALL lines with metadata ─────────────────────────────────
  final List<_OcrLine> lines = [];
  for (final block in recognised.blocks) {
    for (final line in block.lines) {
      final text = line.text.trim();
      if (text.isEmpty) continue;
      final top = line.boundingBox.top.toDouble();
      final height = line.boundingBox.height.toDouble();

      // Split lines like "V. RANJITH MATHAN B.Tech., Pharma - CEO"
      final roleSplitRx = RegExp(r'\s+[-–—|,]\s*(ceo|cto|cfo|coo|founder|owner|director|manager|consultant|proprietor|president|head|engineer)\b', caseSensitive: false);
      if (roleSplitRx.hasMatch(text)) {
        final match = roleSplitRx.firstMatch(text)!;
        final part1 = text.substring(0, match.start).trim();
        final part2 = text.substring(match.start).replaceAll(RegExp(r'^[-–—|,]\s*'), '').trim();
        if (part1.isNotEmpty) lines.add(_OcrLine(text: part1, top: top, fontHeight: height));
        if (part2.isNotEmpty) lines.add(_OcrLine(text: part2, top: top + 0.1, fontHeight: height));
      } else {
        lines.add(_OcrLine(text: text, top: top, fontHeight: height));
      }
    }
  }

  // Sort top-to-bottom
  lines.sort((a, b) => a.top.compareTo(b.top));

  if (lines.isEmpty) {
    print('⚠️ OCR Result: No text detected on card image.');
    return LeadDto(id: '', name: 'Scanned Contact', email: '', mobile: '',
        countryCode: '+91', company: '', position: '', address: '', city: '',
        country: '', website: '', statusRaw: 'New Lead', source: 'Business Card',
        createdAt: DateTime.now());
  }

  // 🤖 1. Try Google Gemini AI Vision Parser First (Image Base64 + OCR Text)
  final rawLinesList = lines.map((l) => l.text).toList();
  final aiLead = await GeminiCardParser.parseWithGeminiVision(imagePath, rawLinesList);
  if (aiLead != null && (aiLead.name.isNotEmpty || aiLead.company.isNotEmpty)) {
    print('====================================================');
    print('🤖 GOOGLE GEMINI AI VISION CARD PARSER RESULTS');
    print('====================================================');
    print('📄 RAW OCR LINES (${lines.length}):');
    for (int i = 0; i < lines.length; i++) {
      print('   [$i] ${lines[i].text}');
    }
    print('----------------------------------------------------');
    print('👤 LOADED NAME      : "${aiLead.name}"');
    print('🏢 LOADED COMPANY   : "${aiLead.company}"');
    print('💼 LOADED POSITION  : "${aiLead.position}"');
    print('📧 LOADED EMAIL     : "${aiLead.email}"');
    print('📱 LOADED MOBILE    : "${aiLead.mobile}"');
    print('🌐 LOADED WEBSITE   : "${aiLead.website}"');
    print('📍 LOADED ADDRESS   : "${aiLead.address}"');
    print('====================================================');
    return aiLead;
  }

  // ── Regex tools ───────────────────────────────────────────────────────────
  final emailRx    = RegExp(r'[\w.+-]+\s*@\s*[\w-]+\.[\w.]+', caseSensitive: false);
  final mobileRx   = RegExp(r'(\+?\d[\d\s\-\(\)]{7,}\d)');
  final websiteRx  = RegExp(r'(https?://)?(www\.)?[\w-]+\.[\w.]{2,}(/\S*)?', caseSensitive: false);
  final pincodeRx  = RegExp(r'\b\d{6}\b');

  // ── Keyword lists ─────────────────────────────────────────────────────────
  const roleKw = [
    'ceo', 'cto', 'cfo', 'coo', 'cmo', 'founder', 'co-founder', 'owner',
    'partner', 'partmer', 'partnr', 'proprietor', 'propriter',
    'director', 'directer', 'managing director', 'managing partner',
    'managing partmer', 'managing', 'manager', 'general manager',
    'sales manager', 'marketing manager', 'engineer', 'software engineer',
    'architect', 'specialist', 'executive', 'vice president', 'vp',
    'president', 'head', 'consultant', 'consultancy', 'officer', 'analyst', 'associate',
    'principal', 'developer', 'designer', 'advocate', 'doctor', 'ca', 'cpa',
    'business developer', 'business development', 'sales executive',
    'marketing executive', 'technical lead', 'team lead', 'chief executive officer',
    'business consultant',
  ];
    const companyKw = [
      'pvt ltd', 'private limited', 'ltd', 'limited', 'llp', 'inc', 'llc',
      'corp', 'corporation', 'company', 'solutions', 'technologies', 'technology',
      'tech', 'systems', 'services', 'enterprises', 'industries', 'consulting',
      'group', 'global', 'international', 'ventures', 'studios', 'labs',
      'software', 'digital', 'automations', 'associates', 'traders', 'exports',
      'imports', 'agency', 'firm', 'infra', 'infrastructure', 'projects',
      'constructions', 'developers', 'builders', 'engineering', 'logistics',
      'estates', 'lifesciences', 'life sciences', 'pharma', 'pharmaceuticals',
      'biotech', 'healthcare', 'laboratories', 'chemicals', 'diagnostics', 'sciences',
      'it solutions', 'it services', 'battery', 'batteries', 'academy', 'studio',
      'school', 'institute', 'center', 'centre', 'clinic', 'arts academy',
    ];
  const addrKw = [
    'no.', 'plot', 'flat', 'door', 'house', 'road', 'street', 'st.',
    'nagar', 'colony', 'sector', 'phase', 'floor', 'building', 'tower',
    'complex', 'park', 'landmark', 'opp', 'near', 'behind', 'marg',
    'chowk', 'padi', 'layout', 'extension', 'hyderabad', 'secunderabad',
    'manikonda', 'bangalore', 'bengaluru', 'chennai', 'puppalaguda',
    'kukatpally', 'gachibowli', 'banjara hills', 'jubilee hills', 'semmancheri', 'semmancherl',
    'adambakkam', 'kesari nagar', 'startup', 'incubation', 'sathyabama',
  ];
  const cityKw = [
    'mumbai', 'delhi', 'bangalore', 'bengaluru', 'chennai', 'hyderabad',
    'pune', 'ahmedabad', 'kolkata', 'surat', 'jaipur', 'lucknow', 'nagpur',
    'indore', 'thane', 'bhopal', 'visakhapatnam', 'vadodara', 'ghaziabad',
    'ludhiana', 'nashik', 'faridabad', 'rajkot', 'meerut', 'varanasi',
    'srinagar', 'aurangabad', 'amritsar', 'coimbatore', 'gwalior',
    'vijayawada', 'jodhpur', 'madurai', 'raipur', 'chandigarh', 'guwahati',
    'solapur', 'mysore', 'gurgaon', 'gurugram', 'noida', 'greater noida',
    'london', 'dubai', 'new york', 'singapore', 'sydney', 'secunderabad',
    'manikonda', 'kukatpally', 'gachibowli',
  ];
  const countryKw = [
    'india', 'telangana', 'andhra pradesh', 'karnataka', 'tamil nadu',
    'maharashtra', 'kerala', 'united states', 'usa', 'united arab emirates',
    'uae', 'united kingdom', 'uk', 'singapore', 'australia', 'canada',
    'germany', 'france', 'japan', 'china', 'brazil', 'south africa',
    'saudi arabia', 'qatar', 'kuwait', 'oman', 'bahrain', 'malaysia',
  ];
  const genericEmails = ['gmail', 'yahoo', 'hotmail', 'outlook', 'icloud',
    'rediffmail', 'protonmail', 'aol', 'zoho', 'ymail', 'live', 'msn', 'gmall', 'gmai', 'yaho', 'hotmai'];

  String titleCase(String s) => s.split(' ').map((w) {
    if (w.isEmpty) return w;
    if (w.endsWith('.') && w.length <= 3) return w.toUpperCase();
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  }).join(' ');

  String fixOcrText(String input) {
    return input.replaceAll('*', '')
                .replaceAll('SERV!CES', 'SERVICES')
                .replaceAll('SERV!CE', 'SERVICE')
                .replaceAllMapped(RegExp(r'\b3([A-Za-z]+)\b'), (m) => 'B${m[1]}')
                .replaceAllMapped(RegExp(r'\b([A-Za-z]+)3([A-Za-z]+)\b'), (m) => '${m[1]}B${m[2]}')
                .trim();
  }

  bool thisIsPhone(String text) {
    return text.replaceAll(RegExp(r'[^\d]'), '').length >= 7;
  }

  bool thisIsPersonName(String text) {
    return LeadFieldValidator.isValidName(LeadFieldValidator.cleanPersonName(text));
  }

  bool isAddressLine(String low, List<String> addrKw, List<String> cityKw, RegExp pincodeRx, String raw) {
    return addrKw.any((k) => low.contains(k)) || cityKw.any((k) => low.contains(k)) || pincodeRx.hasMatch(raw);
  }

  String email    = '';
  String website  = '';
  String mobile   = '';
  String countryCode = '';
  String role     = '';
  String company  = '';
  String name     = '';
  String address  = '';
  String city     = '';
  String country  = '';

  final List<_OcrLine> remaining = [];

  // Step A: Extract Email, Website, Mobile
  for (final ln in lines) {
    final t = fixOcrText(ln.text);
    final low = t.toLowerCase();

    // Email
    if (email.isEmpty) {
      final m = emailRx.firstMatch(t);
      if (m != null) {
        final cand = m.group(0)!.replaceAll(' ', '').toLowerCase();
        if (LeadFieldValidator.isValidEmail(cand)) { email = cand; continue; }
      }
    }

    // Website
    if (website.isEmpty && (low.contains('www') || low.contains('.com') || low.contains('.in') || low.contains('.io') || low.contains('.org') || low.contains('.net'))) {
      if (!low.contains('@')) {
        final m = websiteRx.firstMatch(t);
        if (m != null) {
          final cand = m.group(0)!.toLowerCase();
          if (LeadFieldValidator.isValidWebsite(cand)) { website = cand; continue; }
        }
      }
    }

    // Fax / Tel line checks
    if (low.contains('fax') || low.startsWith('f:') || low.startsWith('f-')) continue;
    final isTelLine = low.startsWith('tel:') || low.contains('telephone') || low.contains('landline') || low.startsWith('t:');

    // Phone / Mobile
    if (mobile.isEmpty && !isTelLine) {
      final hasLabel = low.contains('mob') || low.contains('phone') || low.contains('cell') || low.contains('ph:') || low.contains('m:');
      final digitCount = t.replaceAll(RegExp(r'[^\d]'), '').length;
      if (hasLabel || digitCount >= 8) {
        final matches = mobileRx.allMatches(t).toList();
        for (final m in matches) {
          String raw = m.group(0)!
              .replaceAll('O', '0').replaceAll('o', '0')
              .replaceAll('I', '1').replaceAll('l', '1').replaceAll('|', '1')
              .replaceAll('Z', '2').replaceAll('z', '2')
              .replaceAll('S', '5').replaceAll('s', '5')
              .replaceAll('B', '8')
              .replaceAll(RegExp(r'^(tel|mob|mobile|phone|ph|m|cell|fax|d):?', caseSensitive: false), '')
              .trim();
          final knownCodes = ['+971', '+61', '+65', '+91', '+44', '+1'];
          bool matched = false;
          for (final code in knownCodes) {
            if (raw.startsWith(code)) {
              countryCode = code;
              mobile = raw.substring(code.length).replaceAll(RegExp(r'[^\d]'), '');
              matched = true; break;
            }
          }
          if (!matched) {
            if (raw.startsWith('+')) {
              final d = raw.replaceAll(RegExp(r'[^\d]'), '');
              if (d.length >= 10) { countryCode = '+${d.substring(0, d.length - 10)}'; mobile = d.substring(d.length - 10); }
              else { mobile = d; }
            } else {
              String d = raw.replaceAll(RegExp(r'[^\d]'), '');
              if (d.length == 12 && d.startsWith('91')) { countryCode = '+91'; d = d.substring(2); }
              else if (d.length == 11 && d.startsWith('0')) { d = d.substring(1); }
              mobile = d;
            }
          }
          if (mobile.length >= 10 && LeadFieldValidator.isValidMobile(mobile, segmentText: t)) break;
          mobile = '';
        }
        if (mobile.isNotEmpty) continue;
      }
    }

    remaining.add(_OcrLine(text: t, top: ln.top, fontHeight: ln.fontHeight));
  }

  if (mobile.length == 10 && countryCode.isEmpty) countryCode = '+91';

  // Step B: Extract email/web domain for company matching
  String emailDomain = '';
  if (email.contains('@')) {
    final parts = email.split('@').last.split('.');
    if (parts.isNotEmpty && parts.first.length >= 3) {
      final dom = parts.first.toLowerCase();
      if (!genericEmails.contains(dom)) emailDomain = dom;
    }
  }
  String webDomain = '';
  if (website.isNotEmpty) {
    final clean = website.replaceAll(RegExp(r'^(https?://)?(www\.)?', caseSensitive: false), '');
    final parts = clean.split('.');
    if (parts.isNotEmpty && parts.first.length >= 3) {
      final dom = parts.first.toLowerCase().replaceAll(RegExp(r'pvt|ltd|inc|llc|corp'), '');
      if (dom.length >= 3) webDomain = dom;
    }
  }

  // Step C: Holistic On-Device Weighted Scoring Matrix
  double bestNameScore = 0;
  double bestCompanyScore = 0;
  double bestRoleScore = 0;

  int bestNameIdx = -1;
  int bestCompanyIdx = -1;
  int bestRoleIdx = -1;

  final List<_OcrLine> addressPool = [];

  for (int i = 0; i < remaining.length; i++) {
    final ln = remaining[i];
    final text = ln.text.trim();
    final low = text.toLowerCase();
    final cleanText = LeadFieldValidator.cleanPersonName(text);
    final segClean = low.replaceAll(RegExp(r'[^a-z0-9]'), '');

    // ── 1. Company Scoring ─────────────────────────────────────────────
    double cScore = 0;
    final isCompanyKw = companyKw.any((k) => low.contains(k));
    final domToMatch = webDomain.isNotEmpty ? webDomain : emailDomain;
    final matchesDomain = domToMatch.isNotEmpty && (
      segClean.contains(domToMatch) ||
      domToMatch.contains(segClean) ||
      (domToMatch.length >= 4 && segClean.length >= 4 && segClean.startsWith(domToMatch.substring(0, 4)))
    );
    final isUpperCompany = text == text.toUpperCase() && text.length >= 4 && !thisIsPersonName(text);
    final isTopHeaderLine = (ln.top <= 140 || i == 0 || i == 1);
    final isLargeFont = (ln.fontHeight >= 22);

    if (matchesDomain) cScore += 80;
    if (isCompanyKw) cScore += 50;
    if (isUpperCompany) cScore += 25;
    if (isTopHeaderLine && !thisIsPersonName(text) && !isAddressLine(low, addrKw, cityKw, pincodeRx, text)) cScore += 35;
    if (isLargeFont && !thisIsPersonName(text)) cScore += 25;

    // Deductions for Company
    if (low.contains('@') || low.startsWith('www.') || thisIsPhone(text) || isAddressLine(low, addrKw, cityKw, pincodeRx, text)) cScore = -100;
    if (cScore > bestCompanyScore && LeadFieldValidator.isValidCompany(text)) {
      bestCompanyScore = cScore;
      bestCompanyIdx = i;
    }

    // ── 2. Position / Role Scoring ─────────────────────────────────────
    double rScore = 0;
    final isRole = roleKw.any((k) => low == k || low.startsWith('$k ') || low.endsWith(' $k') || low.contains(' $k ') || low.startsWith(k));
    if (isRole) rScore += 60;
    if (low.contains('@') || low.startsWith('www.') || thisIsPhone(text) || isAddressLine(low, addrKw, cityKw, pincodeRx, text)) rScore = -100;

    if (rScore > bestRoleScore && LeadFieldValidator.isValidPosition(text)) {
      bestRoleScore = rScore;
      bestRoleIdx = i;
    }

    // Address check
    if (isAddressLine(low, addrKw, cityKw, pincodeRx, text)) {
      addressPool.add(ln);
      if (city.isEmpty) {
        for (final c in cityKw) {
          if (low.contains(c)) { city = titleCase(c); break; }
        }
      }
      if (country.isEmpty) {
        for (final c in countryKw) {
          if (low.contains(c)) { country = titleCase(c); break; }
        }
      }
    }
  }

  // Set Company & Role from top scoring lines
  if (bestCompanyIdx != -1 && bestCompanyScore >= 25) {
    company = titleCase(remaining[bestCompanyIdx].text);
  }
  // Fallback: Infer company from website/email domain if still missing
  if (company.isEmpty || company.length < 3) {
    final refDom = webDomain.isNotEmpty ? webDomain : emailDomain;
    if (refDom.isNotEmpty && refDom.length >= 3) {
      company = titleCase(refDom.replaceAll(RegExp(r'[-_]'), ' '));
    }
  }
  if (bestRoleIdx != -1 && bestRoleScore >= 30) {
    role = titleCase(remaining[bestRoleIdx].text);
  }

  // ── 3. Name Scoring Matrix ──────────────────────────────────────────
  String emailPrefix = '';
  if (email.contains('@')) {
    final userPart = email.split('@').first.toLowerCase();
    // Strip numbers/dots from email username (e.g. "karthikesh.s99" -> "karthikesh s")
    emailPrefix = userPart.replaceAll(RegExp(r'[\d_.]'), ' ').trim();
  }

  for (int i = 0; i < remaining.length; i++) {
    if (i == bestCompanyIdx || i == bestRoleIdx) continue;
    final ln = remaining[i];
    final text = ln.text.trim();
    final low = text.toLowerCase();
    final cleanName = LeadFieldValidator.cleanPersonName(text);

    double nScore = 0;
    final hasSalutation = RegExp(r'^(mr\.?|mrs\.?|ms\.?|dr\.?|er\.?|prof\.?|ca\.?)\s+', caseSensitive: false).hasMatch(text);
    final hasInitial = RegExp(r'^[a-z]\.\s*[a-z]', caseSensitive: false).hasMatch(cleanName) || RegExp(r'\s+[a-z]\.$', caseSensitive: false).hasMatch(cleanName);
    final isAdjacentToRole = (bestRoleIdx != -1 && (i == bestRoleIdx - 1 || i == bestRoleIdx + 1));
    final matchesEmailUser = (emailPrefix.length >= 3 && low.contains(emailPrefix));
    
    // Check if line is 2-3 words, mostly alphabetic capital words
    final words = cleanName.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final isCapitalizedWords = words.length >= 2 && words.length <= 4 && words.every((w) => RegExp(r'^[A-Z][a-z]+$|^[A-Z]+$').hasMatch(w));

    if (hasInitial) nScore += 65;
    if (matchesEmailUser) nScore += 65;
    if (hasSalutation) nScore += 55;
    if (isCapitalizedWords) nScore += 40;
    if (isAdjacentToRole) nScore += 35;
    if (i == 0 || i == 1) nScore += 20; // Upper card position bonus

    // Deductions for Name
    if (low.contains('@') || low.startsWith('www.') || thisIsPhone(text) || isAddressLine(low, addrKw, cityKw, pincodeRx, text)) nScore = -100;
    if (low.contains('factory address') || low.contains('office address') || low.contains('head office') || low.contains('branch office')) nScore = -100;
    if (companyKw.any((k) => low.contains(k)) || (emailDomain.isNotEmpty && low.replaceAll(RegExp(r'[^a-z0-9]'), '').contains(emailDomain))) nScore = -100;
    if (low == 'go gre' || low == 'go green' || low == 'save earth' || low.startsWith('iso ')) nScore = -100;

    if (nScore > bestNameScore && LeadFieldValidator.isValidName(cleanName)) {
      bestNameScore = nScore;
      bestNameIdx = i;
    }
  }

  if (bestNameIdx != -1 && bestNameScore >= 15) {
    name = LeadFieldValidator.cleanPersonName(remaining[bestNameIdx].text);
  }

  // Fallback if name is still empty
  if (name.isEmpty) {
    for (int i = 0; i < remaining.length; i++) {
      if (i == bestCompanyIdx || i == bestRoleIdx) continue;
      final cand = LeadFieldValidator.cleanPersonName(remaining[i].text);
      if (LeadFieldValidator.isValidName(cand)) {
        name = cand;
        break;
      }
    }
  }

  // Step E: Build address from address pool
  if (addressPool.isNotEmpty) {
    final parts = <String>[];
    for (final ln in addressPool) {
      final t = ln.text;
      if (name.isNotEmpty && t.toLowerCase().contains(name.toLowerCase())) continue;
      if (company.isNotEmpty && t.toLowerCase().contains(company.toLowerCase())) continue;
      parts.add(t);
    }
    if (city.isNotEmpty && !parts.any((p) => p.toLowerCase().contains(city.toLowerCase()))) parts.add(city);
    if (country.isNotEmpty && !parts.any((p) => p.toLowerCase().contains(country.toLowerCase()))) parts.add(country);
    address = parts.join(', ');
  }

  // Casing normalization
  if (name.isNotEmpty && name != 'Scanned Contact') name = titleCase(name);
  if (company.isNotEmpty) company = titleCase(company);
  if (city.isNotEmpty) city = titleCase(city);
  if (country.isNotEmpty) country = titleCase(country);
  email = email.toLowerCase();
  website = website.toLowerCase();

  // ── Print debug log of loaded fields ──────────────────────────────────────
  print('====================================================');
  print('🎴 BUSINESS CARD OCR EXTRACTION RESULTS');
  print('====================================================');
  print('📄 RAW OCR LINES (${lines.length}):');
  for (int i = 0; i < lines.length; i++) {
    print('   [$i] ${lines[i].text} (height: ${lines[i].fontHeight.toStringAsFixed(1)})');
  }
  print('----------------------------------------------------');
  print('👤 LOADED NAME      : "${name.isNotEmpty ? name : 'Scanned Contact'}"');
  print('🏢 LOADED COMPANY   : "$company"');
  print('💼 LOADED POSITION  : "$role"');
  print('📧 LOADED EMAIL     : "$email"');
  print('📱 LOADED MOBILE    : "$countryCode $mobile"');
  print('🌐 LOADED WEBSITE   : "$website"');
  print('📍 LOADED ADDRESS   : "$address"');
  print('====================================================');

  return LeadDto(
    id: '',
    name: name.isNotEmpty ? name : 'Scanned Contact',
    email: email,
    mobile: mobile,
    countryCode: countryCode.isNotEmpty ? countryCode : '+91',
    company: company,
    position: role,
    address: address,
    city: city,
    country: country,
    website: website,
    statusRaw: 'New Lead',
    source: 'Business Card',
    createdAt: DateTime.now(),
  );
}

/// Lightweight data class holding an OCR line with its position and font-size metadata.
class _OcrLine {
  final String text;
  final double top;
  final double fontHeight;
  const _OcrLine({required this.text, required this.top, required this.fontHeight});
}



/// ---- Real Camera Document Auto-Scanner Overlay ----
class _CameraScannerOverlay extends StatefulWidget {
  final ValueChanged<LeadDto> onScanDone;
  const _CameraScannerOverlay({required this.onScanDone});

  @override
  State<_CameraScannerOverlay> createState() => _CameraScannerOverlayState();
}

class _CameraScannerOverlayState extends State<_CameraScannerOverlay> with SingleTickerProviderStateMixin {
  CameraController? _ctrl;
  late AnimationController _laserCtrl;
  bool _initialising = true;
  bool _capturing = false;
  bool _disposed = false;
  String? _error;
  Timer? _autoScanTimer;
  int _scanAttempts = 0;
  String _statusMsg = 'Hold steady — auto-analyzing card...';

  bool _hasSufficientCardData(LeadDto lead) {
    final validMobile = LeadFieldValidator.isValidMobile(lead.mobile);
    final validEmail = LeadFieldValidator.isValidEmail(lead.email);
    final validName = LeadFieldValidator.isValidName(lead.name);
    final validCompany = LeadFieldValidator.isValidCompany(lead.company, personName: lead.name);

    return validMobile || validEmail || (validName && validCompany);
  }

  @override
  void initState() {
    super.initState();
    _laserCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _initCamera();
  }

  @override
  void dispose() {
    _disposed = true;
    _autoScanTimer?.cancel();
    _laserCtrl.dispose();
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (_disposed) return;
      if (cameras.isEmpty) {
        _fallbackToSystemCamera();
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await ctrl.initialize();
      if (_disposed) { await ctrl.dispose(); return; }
      if (!mounted) { await ctrl.dispose(); return; }
      setState(() { _ctrl = ctrl; _initialising = false; });

      // Schedule auto-scan document detection after camera focus stabilizes
      _scheduleAutoScan();
    } catch (e) {
      if (!_disposed && mounted) {
        _fallbackToSystemCamera();
      }
    }
  }

  Future<void> _fallbackToSystemCamera() async {
    if (_disposed || !mounted) return;
    try {
      final picker = ImagePicker();
      final XFile? xfile = await picker.pickImage(source: ImageSource.camera, imageQuality: 92);
      if (xfile == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      if (!mounted) return;
      final lead = await _ocrToLead(xfile.path);
      widget.onScanDone(lead);
      if (mounted) Navigator.of(context).pop(lead);
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _scheduleAutoScan() {
    _autoScanTimer?.cancel();
    // Wait 1200ms for camera focus & exposure stabilization
    _autoScanTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && !_capturing && !_disposed && _ctrl != null && _ctrl!.value.isInitialized && !_ctrl!.value.isTakingPicture) {
        _doScan(isManual: false);
      }
    });
  }

  Future<void> _doScan({bool isManual = false}) async {
    if (_capturing && !isManual) return;
    _autoScanTimer?.cancel();
    
    if (_ctrl == null || !_ctrl!.value.isInitialized || _ctrl!.value.isTakingPicture) {
      _fallbackToSystemCamera();
      return;
    }

    setState(() {
      _capturing = true;
      _statusMsg = 'Stabilizing camera & focusing card...';
    });

    try {
      HapticFeedback.lightImpact();

      // Frame 1/3: Primary OCR text capture
      setState(() => _statusMsg = 'Analyzing card text (Frame 1/3)...');
      final file1 = await _ctrl!.takePicture();
      if (!mounted) return;
      var masterLead = await _ocrToLead(file1.path);

      // Frame 2/3: Contact & Company detail verification
      if (_ctrl!.value.isInitialized && !_ctrl!.value.isTakingPicture) {
        await Future.delayed(const Duration(milliseconds: 350));
        if (mounted) setState(() => _statusMsg = 'Validating contact & company (Frame 2/3)...');
        try {
          final file2 = await _ctrl!.takePicture();
          final lead2 = await _ocrToLead(file2.path);
          masterLead = _mergeLeads(masterLead, lead2);
        } catch (_) {}
      }

      // Frame 3/3: Address & Phone number multi-line extraction
      if (_ctrl!.value.isInitialized && !_ctrl!.value.isTakingPicture) {
        await Future.delayed(const Duration(milliseconds: 350));
        if (mounted) setState(() => _statusMsg = 'Extracting complete address & mobile (Frame 3/3)...');
        try {
          final file3 = await _ctrl!.takePicture();
          final lead3 = await _ocrToLead(file3.path);
          masterLead = _mergeLeads(masterLead, lead3);
        } catch (_) {}
      }

      final isValid = _hasSufficientCardData(masterLead);

      if (isValid || isManual || _scanAttempts >= 2) {
        setState(() => _statusMsg = 'Full card analysis complete! Fetching details...');
        HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        widget.onScanDone(masterLead);
        Navigator.of(context).pop(masterLead);
      } else {
        _scanAttempts++;
        if (mounted) {
          setState(() {
            _capturing = false;
            _statusMsg = 'Hold card aligned — performing deep scan...';
          });
          _autoScanTimer = Timer(const Duration(milliseconds: 900), () {
            if (mounted && !_capturing && !_disposed) {
              _doScan(isManual: false);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _capturing = false);
        _fallbackToSystemCamera();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2012),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                  ),
                  Expanded(
                    child: Text(
                      'Scan Business Card',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38C82D).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF38C82D).withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.wifi_off_rounded, size: 11, color: Color(0xFF38C82D)),
                        SizedBox(width: 3),
                        Text(
                          'Offline Ready',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF38C82D)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Camera preview area
            Expanded(
              child: GestureDetector(
                onTap: () => _doScan(isManual: true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildPreview(),
                  ),
                ),
              ),
            ),
            // Status Hint
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF38C82D).withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_capturing)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(color: Color(0xFF38C82D), strokeWidth: 2),
                    )
                  else
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF38C82D),
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _statusMsg,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
            ),
            // White circular shutter button matching mockup
            GestureDetector(
              onTap: () => _doScan(isManual: true),
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _capturing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: AppColors.evaGreen, strokeWidth: 3),
                        )
                      : Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_initialising) {
      return const ColoredBox(
        color: Color(0xFF1A2E1C),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50))),
      );
    }
    if (_error != null) {
      return ColoredBox(
        color: const Color(0xFF1A2E1C),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins'), textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (_ctrl == null || !_ctrl!.value.isInitialized) {
      return const ColoredBox(color: Color(0xFF1A2E1C), child: SizedBox.expand());
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        CameraPreview(_ctrl!),
        // Card alignment overlay with animated scanning laser
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: AspectRatio(
              aspectRatio: 1.586,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF38C82D),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38C82D).withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _laserCtrl,
                  builder: (context, child) {
                    return Align(
                      alignment: Alignment(0, (_laserCtrl.value * 2) - 1),
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF38C82D),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF38C82D).withValues(alpha: 0.9),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardFilterSheet extends StatefulWidget {
  final bool isOverview;
  final String timeFilter;
  final String selectedAssigned;
  final String selectedSource;
  final String selectedStatus;
  final List<DateTime>? dateRange;
  final Function(String time, String assigned, String source, String status, List<DateTime>? range) onApply;

  const _DashboardFilterSheet({
    required this.isOverview,
    required this.timeFilter,
    required this.selectedAssigned,
    required this.selectedSource,
    required this.selectedStatus,
    required this.dateRange,
    required this.onApply,
  });

  @override
  State<_DashboardFilterSheet> createState() => _DashboardFilterSheetState();
}

class _DashboardFilterSheetState extends State<_DashboardFilterSheet> {
  late String _time;
  late String _assigned;
  late String _source;
  late String _status;
  List<DateTime>? _range;

  List<Map<String, dynamic>> _agents = [];
  List<String> _sources = [];
  List<String> _statuses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _time = widget.timeFilter;
    _assigned = widget.selectedAssigned;
    _source = widget.selectedSource;
    _status = widget.selectedStatus;
    _range = widget.dateRange;
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final agentsRepo = AppScope.of(context).agents;
    final leadsRepo = AppScope.of(context).leads;
    try {
      final agentsData = await agentsRepo.fetchAgents();
      final rolesData = await agentsRepo.fetchRoles().catchError((_) => <Map<String, dynamic>>[]);
      final fields = await leadsRepo.fetchFieldOptions();

      final leadRoleNames = <String>{};
      for (final r in rolesData) {
        final roleName = (r['role_name'] ?? r['name'] ?? r['role'] ?? '').toString().trim().toLowerCase();
        final perms = r['permissions'] as Map?;
        if (roleName.contains('admin') || roleName.contains('lead') || roleName.contains('owner') || roleName.contains('manager')) {
          leadRoleNames.add(roleName);
        } else if (perms != null) {
          final lm = perms['leadsMain'] ?? perms['leads'] ?? perms['leadsDashboard'] ?? perms['lead'];
          if (lm != null && lm.toString() != '[]' && lm.toString() != '{}' && lm.toString() != 'false' && lm.toString() != 'null') {
            leadRoleNames.add(roleName);
          }
        }
      }

      final filteredAgents = <Map<String, dynamic>>[];
      for (final a in agentsData) {
        final status = (a['status'] ?? '').toString().toLowerCase();
        if (status == 'inactive' || status == 'disabled' || status == 'suspended') continue;

        final role = (a['role'] ?? a['role_name'] ?? '').toString().trim().toLowerCase();
        final bool isSuperAdmin = role == 'superadmin' || role == 'admin' || role == 'owner';
        final bool isLeadRole = leadRoleNames.contains(role) || role.contains('lead') || role.contains('admin') || role.contains('manager');
        final bool hasExplicitLeadPerm = a['leadAccess'] == true || a['hasLeadAccess'] == true || a['leadsAccess'] == true || a['canAccessLeads'] == true;

        bool hasAgentMapLeadPerm = false;
        final agentPerms = a['permissions'] as Map?;
        if (agentPerms != null) {
          final lm = agentPerms['leadsMain'] ?? agentPerms['leads'] ?? agentPerms['leadsDashboard'] ?? agentPerms['lead'];
          if (lm != null && lm.toString() != '[]' && lm.toString() != '{}' && lm.toString() != 'false' && lm.toString() != 'null') {
            hasAgentMapLeadPerm = true;
          }
        }

        if (isSuperAdmin || isLeadRole || hasExplicitLeadPerm || hasAgentMapLeadPerm) {
          filteredAgents.add(a);
        }
      }

      final finalAgents = filteredAgents.isNotEmpty
          ? filteredAgents
          : agentsData.where((a) {
              final status = (a['status'] ?? '').toString().toLowerCase();
              return status != 'inactive' && status != 'disabled' && status != 'suspended';
            }).toList();

      if (!context.mounted) return;
      setState(() {
        _agents = finalAgents;
        _sources = fields['source'] ?? ['Website', 'Referral', 'Social Media'];
        _statuses = fields['status'] ?? ['New Lead', 'Hot', 'Warm', 'Cold', 'Converted'];
        _loading = false;
      });
    } catch (_) {
      if (!context.mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 24),
      child: _loading
          ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: AppColors.evaGreen)))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: AppColors.ink4),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.isOverview ? 'Global Filters' : 'Performance Filters',
                      style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (widget.isOverview) ...[
                  Text('Created Date Range', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showModalBottomSheet<List<DateTime>>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => CustomDateRangePicker(initialRange: _range),
                      );
                      if (picked != null && picked.length == 2) {
                        setState(() => _range = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.evaGreen50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.evaGreen200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _range == null
                                  ? 'Start date → End date'
                                  : '${_range![0].day}/${_range![0].month}/${_range![0].year} → ${_range![1].day}/${_range![1].month}/${_range![1].year}',
                              style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.evaGreenDeep),
                            ),
                          ),
                          const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.evaGreenDeep),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text('Time Period', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                const SizedBox(height: 8),
                _dropdown(
                  value: _time,
                  items: const [
                    DropdownMenuItem(value: '7', child: Text('Last 7 days', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    DropdownMenuItem(value: '30', child: Text('Last 30 days', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    DropdownMenuItem(value: '90', child: Text('Last 90 days', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    DropdownMenuItem(value: 'all', child: Text('All time', overflow: TextOverflow.ellipsis, maxLines: 1)),
                  ],
                  onChanged: (v) => setState(() {
                    _time = v!;
                    if (v != 'all') _range = null;
                  }),
                ),
                const SizedBox(height: 16),
                Text('Assigned To', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                const SizedBox(height: 8),
                _dropdown(
                  value: _assigned,
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Agents', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    for (final a in _agents)
                      DropdownMenuItem(
                        value: (a['_id'] ?? '').toString(),
                        child: Text((a['username'] ?? '').toString(), overflow: TextOverflow.ellipsis, maxLines: 1),
                      ),
                  ],
                  onChanged: (v) => setState(() => _assigned = v!),
                ),
                const SizedBox(height: 16),
                Text('Lead Source', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                const SizedBox(height: 8),
                _dropdown(
                  value: _source,
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Sources', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    for (final s in _sources) DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, maxLines: 1)),
                  ],
                  onChanged: (v) => setState(() => _source = v!),
                ),
                const SizedBox(height: 16),
                Text('Lead Status', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                const SizedBox(height: 8),
                _dropdown(
                  value: _status,
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Status', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    for (final st in _statuses) DropdownMenuItem(value: st, child: Text(st, overflow: TextOverflow.ellipsis, maxLines: 1)),
                  ],
                  onChanged: (v) => setState(() => _status = v!),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _time = '30';
                            _assigned = 'all';
                            _source = 'all';
                            _status = 'all';
                            _range = null;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('Clear All', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.danger)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          widget.onApply(_time, _assigned, _source, _status, _range);
                          Navigator.of(context).pop();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.evaGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('Apply Filters', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final safeValue = items.any((item) => item.value == value) ? value : items.first.value as T;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: safeValue,
          isExpanded: true,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item.value,
              enabled: item.enabled,
              onTap: item.onTap,
              child: ClipRect(
                child: SizedBox(
                  width: double.infinity,
                  child: item.child,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.ink4),
        ),
      ),
    );
  }
}

class _CompanyCustomersScreen extends StatefulWidget {
  final String company;
  final List<LeadDto> leads;
  const _CompanyCustomersScreen({required this.company, required this.leads});

  @override
  State<_CompanyCustomersScreen> createState() => _CompanyCustomersScreenState();
}

class _CompanyCustomersScreenState extends State<_CompanyCustomersScreen> {
  int _tab = 0; // 0 Customers, 1 Appointments, 2 Ticketing
  bool _loading = true;
  List<AppointmentDto> _companyAppointments = [];
  List<TicketDto> _companyTickets = [];

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
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

  Future<void> _loadCompanyData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final scope = AppScope.of(context);
      final leadMobiles = widget.leads.map((l) => l.mobile).where((m) => m.isNotEmpty).toList();
      final leadNames = widget.leads.map((l) => l.name.trim().toLowerCase()).where((n) => n.isNotEmpty).toList();

      final allAppointments = await scope.appointments.fetchAppointments().catchError((_) => <AppointmentDto>[]);
      final allTickets = await scope.ticketing.fetchTickets().catchError((_) => <TicketDto>[]);

      final apts = allAppointments.where((apt) {
        if (leadMobiles.any((m) => _mobileMatches(apt.mobile, m))) return true;
        if (leadNames.contains(apt.name.trim().toLowerCase())) return true;
        return false;
      }).toList();

      final tkts = allTickets.where((t) {
        if (leadMobiles.any((m) => _mobileMatches(t.mobile, m))) return true;
        if (leadNames.contains(t.customer.trim().toLowerCase())) return true;
        return false;
      }).toList();

      if (mounted) {
        setState(() {
          _companyAppointments = apts;
          _companyTickets = tkts;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface2,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        title: Text(widget.company, style: AppText.poppins(size: 17, weight: FontWeight.w800, color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              _tabBtn('Customers (${widget.leads.length})', 0),
              const SizedBox(width: 20),
              _tabBtn('Appointments (${_companyAppointments.length})', 1),
              const SizedBox(width: 20),
              _tabBtn('Ticketing (${_companyTickets.length})', 2),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: AppColors.evaGreen)),
            )
          else if (_tab == 0) ...[
            if (widget.leads.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text('No customers found for this company', style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink3)),
                ),
              )
            else
              ...widget.leads.map((l) {
                return _renderLeadCard(
                  context,
                  l,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomerDetailScreen(lead: l))),
                );
              }),
          ] else if (_tab == 1) ...[
            if (_companyAppointments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text('No appointments found for this company.', style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink3)),
                ),
              )
            else
              ..._companyAppointments.map(_appointmentCard),
          ] else ...[
            if (_companyTickets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text('No tickets found for this company.', style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink3)),
                ),
              )
            else
              ..._companyTickets.map(_ticketCard),
          ],
        ],
      ),
    );
  }

  Widget _tabBtn(String label, int i) {
    final active = _tab == i;
    return GestureDetector(
      onTap: () => setState(() => _tab = i),
      child: Column(children: [
        Text(label, style: AppText.poppins(size: 13, weight: active ? FontWeight.w800 : FontWeight.w600, color: active ? Theme.of(context).colorScheme.secondary : AppColors.ink3)),
        const SizedBox(height: 6),
        Container(height: 2.5, width: 40, color: active ? Theme.of(context).colorScheme.primary : Colors.transparent),
      ]),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AppointmentDetailScreen(
              id: apt.id,
              code: code,
              patient: apt.name,
              mobile: apt.mobile,
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
                  child: Text(code, style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.ink)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(apt.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                  child: Text(statusText, style: AppText.poppins(size: 11, weight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${apt.department.isEmpty ? 'Consultation' : apt.department} · ${_formatDate(apt.scheduledAt)}', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3)),
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
                  child: Text(t.customer, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
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
            const SizedBox(height: 6),
            Text('Dept: ${t.department.isEmpty ? 'OH' : t.department} · Priority: ${t.priority}', style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
          ],
        ),
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  final VoidCallback onTap;
  const _Fab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.evaGreen,
      borderRadius: BorderRadius.circular(30),
      elevation: 4,
      shadowColor: AppColors.evaGreen.withValues(alpha: 0.5),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text('New Lead', style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncProgressSheet extends StatefulWidget {
  final VoidCallback onDone;
  const _SyncProgressSheet({required this.onDone});

  @override
  State<_SyncProgressSheet> createState() => _SyncProgressSheetState();
}

class _SyncProgressSheetState extends State<_SyncProgressSheet> {
  int _step = 0;
  String _mode = 'manual';

  @override
  void initState() {
    super.initState();
    _loadModeAndSync();
  }

  Future<void> _loadModeAndSync() async {
    try {
      final mode = await AppScope.of(context).leads.fetchAssignmentMode();
      if (mounted) setState(() => _mode = mode);
    } catch (_) {}
    _runSync();
  }

  Future<void> _runSync() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _step = 1);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _step = 2);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final isRoundRobin = _mode == 'round_robin';
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sync UI contacts',
                  style: AppText.poppins(size: 16.5, weight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: AppColors.ink4),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isRoundRobin ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isRoundRobin ? AppColors.evaGreen : AppColors.line),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isRoundRobin ? Icons.autorenew_rounded : Icons.person_outline_rounded,
                    size: 14,
                    color: isRoundRobin ? AppColors.evaGreenDeep : AppColors.ink3,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isRoundRobin ? 'Assignment Mode: Round Robin (Auto-assigned)' : 'Assignment Mode: Manual',
                    style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: isRoundRobin ? AppColors.evaGreenDeep : AppColors.ink3),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              value: _step == 2 ? 1.0 : null,
              color: AppColors.evaGreen,
              strokeWidth: 4.5,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _step == 2 ? 'Sync complete!' : 'Syncing UI contacts...',
            style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Pulling people who messaged you first. Other sources sync automatically.',
              textAlign: TextAlign.center,
              style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink4),
            ),
          ),
          const SizedBox(height: 20),
          _statusRow(
            'UI Contacts',
            'Reading inbound-first WhatsApp senders',
            _step >= 1,
          ),
          const SizedBox(height: 12),
          _statusRow(
            'Matching',
            'Skipping contacts already in Leads',
            _step >= 2,
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String title, String desc, bool isDone) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFFECFDF5) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDone ? Icons.check_rounded : Icons.sync_rounded,
              size: 16,
              color: isDone ? const Color(0xFF10B981) : AppColors.ink4,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
}

String _mon(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];

Widget _renderLeadCard(
  BuildContext context,
  LeadDto l, {
  bool selectMode = false,
  bool selected = false,
  LeadStatus? status,
  required VoidCallback onTap,
}) {
  final display = l.name.isEmpty ? (l.mobile.isEmpty ? 'Unknown' : l.mobile) : l.name;
  String fmtDate(DateTime? d) => d == null ? '' : '${d.day} ${_mon(d.month)} ${d.year}';
  final statusToShow = status ?? l.status;

  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectMode) ...[
            Icon(selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 22, color: selected ? AppColors.evaGreen : AppColors.ink4),
            const SizedBox(width: 10),
          ],
          InitialsAvatar(initials: _initials(display), color: avatarColorFor(display), size: 44, radius: 13),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(display, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink))),
                    StatusPill(status: statusToShow),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.call_outlined, size: 13, color: AppColors.ink4),
                    const SizedBox(width: 5),
                    Flexible(child: Text(l.mobile.isEmpty ? '—' : l.mobile, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2))),
                    if (l.source.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.public_rounded, size: 13, color: AppColors.ink4),
                      const SizedBox(width: 5),
                      Flexible(child: Text(l.source, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2))),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 13, color: AppColors.ink4),
                    const SizedBox(width: 5),
                    Flexible(child: Text(l.assignedTo ?? 'Unassigned', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3))),
                    const SizedBox(width: 12),
                    const Icon(Icons.schedule_rounded, size: 13, color: AppColors.ink4),
                    const SizedBox(width: 5),
                    Text(fmtDate(l.createdAt), style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3)),
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


class _BulkUpdateSheet extends StatefulWidget {
  final int selectedCount;
  final List<String> agents;
  final bool hasConvertedLeads;
  final bool allConvertedLeads;
  final bool hasNonNewLeads;
  final Function(String? status, String? agent) onApply;

  const _BulkUpdateSheet({
    required this.selectedCount,
    required this.agents,
    this.hasConvertedLeads = false,
    this.allConvertedLeads = false,
    this.hasNonNewLeads = false,
    required this.onApply,
  });

  @override
  State<_BulkUpdateSheet> createState() => _BulkUpdateSheetState();
}

class _BulkUpdateSheetState extends State<_BulkUpdateSheet> {
  String? _selectedStatus = 'None';
  String? _selectedAgent = 'None';
  
  bool _statusExpanded = false;
  bool _agentExpanded = false;
  
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  List<String> get _availableStatuses {
    if (widget.allConvertedLeads) return const ['None'];
    final list = <String>['None'];
    if (!widget.hasNonNewLeads) {
      list.add('New');
    }
    list.addAll(['Hot', 'Warm', 'Cold', 'Customer']);
    return list;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF9E6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_note_rounded, color: AppColors.evaGreenDeep, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'Bulk Update · ${widget.selectedCount} selected',
                style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 18, color: AppColors.ink4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Text('Update Status', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)),
          const SizedBox(height: 6),
          
          if (widget.allConvertedLeads)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Text(
                    'Converted Customer (Locked)',
                    style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink4),
                  ),
                  const Spacer(),
                  const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.ink4),
                ],
              ),
            )
          else ...[
            GestureDetector(
              onTap: () {
                setState(() {
                  _statusExpanded = !_statusExpanded;
                  _agentExpanded = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _statusExpanded ? AppColors.evaGreen : AppColors.line),
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedStatus ?? 'None',
                      style: AppText.poppins(
                        size: 14,
                        weight: FontWeight.w700,
                        color: (_selectedStatus == null || _selectedStatus == 'None') ? AppColors.ink4 : AppColors.ink,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _statusExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.ink3,
                    ),
                  ],
                ),
              ),
            ),
            if (_statusExpanded) ...[
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: _availableStatuses.map((status) {
                    final isSel = _selectedStatus == status;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedStatus = status;
                          _statusExpanded = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: isSel ? const Color(0xFFEAF9E6) : Colors.transparent,
                        child: Text(
                          status,
                          style: AppText.poppins(
                            size: 14,
                            weight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? AppColors.evaGreenDeep : AppColors.ink,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
          
          const SizedBox(height: 16),
          
          Text('Change Assigned To', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)),
          const SizedBox(height: 6),
          
          GestureDetector(
            onTap: () {
              setState(() {
                _agentExpanded = !_agentExpanded;
                _statusExpanded = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _agentExpanded ? AppColors.evaGreen : AppColors.line),
              ),
              child: Row(
                children: [
                  Text(
                    _selectedAgent ?? 'None',
                    style: AppText.poppins(
                      size: 14,
                      weight: FontWeight.w700,
                      color: (_selectedAgent == null || _selectedAgent == 'None') ? AppColors.ink4 : AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _agentExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.ink3,
                  ),
                ],
              ),
            ),
          ),
          if (_agentExpanded) ...[
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.toLowerCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: AppText.poppins(size: 13, color: AppColors.ink4),
                        prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.ink4),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: ['None', ...widget.agents].where((agent) => agent == 'None' || agent.toLowerCase().contains(_searchQuery)).map((agent) {
                        final isSel = _selectedAgent == agent;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedAgent = agent;
                              _agentExpanded = false;
                              _searchCtrl.clear();
                              _searchQuery = '';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFFEAF9E6) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              agent,
                              style: AppText.poppins(
                                size: 13.5,
                                weight: isSel ? FontWeight.w800 : FontWeight.w600,
                                color: isSel ? AppColors.evaGreenDeep : AppColors.ink,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Cancel', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: ((_selectedStatus == null || _selectedStatus == 'None') && (_selectedAgent == null || _selectedAgent == 'None')) 
                      ? null 
                      : () {
                          Navigator.pop(context);
                          widget.onApply(
                            _selectedStatus == 'None' ? null : _selectedStatus,
                            _selectedAgent == 'None' ? null : _selectedAgent,
                          );
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.evaGreen,
                    disabledBackgroundColor: AppColors.line,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Apply Changes', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
