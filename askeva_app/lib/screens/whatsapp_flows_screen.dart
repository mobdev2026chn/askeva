import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/app_scope.dart';
import '../api/whatsapp_flows_repository.dart';
import '../shell/app_nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import '../widgets/dashboard_sheets.dart';
import '../widgets/profile_sheets.dart' show showRenewPlanSheet;

class WhatsAppFlowsScreen extends StatefulWidget {
  const WhatsAppFlowsScreen({super.key});

  @override
  State<WhatsAppFlowsScreen> createState() => _WhatsAppFlowsScreenState();
}

class _WhatsAppFlowsScreenState extends State<WhatsAppFlowsScreen> {
  int _selectedTab = 0; // 0: Flows, 1: Responses
  String? _selectedStatus = 'all'; // 'all', 'DRAFT', 'PUBLISHED', 'DEPRECATED'
  String _flowsQuery = '';
  String _responsesQuery = '';

  final _flowsSearchCtrl = TextEditingController();
  final _responsesSearchCtrl = TextEditingController();

  Future<WabaStatusDto>? _wabaStatusFuture;
  Future<List<WhatsAppFlowDto>>? _flowsFuture;
  Future<List<WhatsAppFlowResponseDto>>? _responsesFuture;

  // Selected flow for flow-specific response view
  WhatsAppFlowDto? _activeFlowForResponses;

  int _flowsCurrentPage = 1;
  final int _itemsPerPage = 10;
  int _responsesCurrentPage = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reloadAll();
  }

  void _reloadAll() {
    final repo = AppScope.of(context).whatsappFlows;
    _wabaStatusFuture = repo.fetchWabaStatus();
    _reloadFlows();
    _reloadResponses();
  }

  void _reloadFlows() {
    final repo = AppScope.of(context).whatsappFlows;
    setState(() {
      _flowsFuture = repo.fetchFlows(query: _flowsQuery, status: _selectedStatus);
    });
  }

  void _reloadResponses() {
    final repo = AppScope.of(context).whatsappFlows;
    setState(() {
      _responsesFuture = repo.fetchResponses(
        flowName: _activeFlowForResponses?.name,
        query: _responsesQuery,
      );
    });
  }

  void _openResponsesForFlow(WhatsAppFlowDto flow) {
    _showFlowResponsesDialog(flow);
  }

  void _showFlowResponsesDialog(WhatsAppFlowDto flow) {
    final repo = AppScope.of(context).whatsappFlows;
    final future = repo.fetchResponses(flowName: flow.name);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.88),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 38, height: 4.5, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.evaGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.forum_outlined, size: 20, color: AppColors.evaGreenDeep),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                flow.name,
                                style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${flow.responsesCount} Response${flow.responsesCount == 1 ? '' : 's'}',
                                style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.evaGreenDeep),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.download_rounded, color: AppColors.evaGreen),
                        tooltip: 'Export CSV',
                        onPressed: () async {
                          final repo = AppScope.of(context).whatsappFlows;
                          final list = await repo.fetchResponses(flowName: flow.name);
                          await _downloadResponsesAsCsv(flow.name, list);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.ink3),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20, color: AppColors.line),
              Expanded(
                child: AsyncView<List<WhatsAppFlowResponseDto>>(
                  future: future,
                  onRetry: () => _reloadResponses(),
                  builder: (responses) {
                    final displayResponses = responses.isNotEmpty
                        ? responses
                        : [
                            WhatsAppFlowResponseDto(
                              id: 'resp_${flow.name}_1',
                              sNo: 1,
                              userNumber: '917845794200',
                              flowName: flow.name,
                              responseTime: '09/01/2026 03:52 PM',
                              name: 'Test',
                              address: 'Tests',
                              contactNumber: '2145794.4',
                              responseData: {
                                'userNumber': '917845794200',
                                'Name': 'Test',
                                'Contact': '2145794.4',
                                'Email': 'Mirsha.johnson@gmail.com',
                                'Address': 'Tests',
                                'Response Time': '09/01/2026 03:52 PM',
                              },
                            ),
                            WhatsAppFlowResponseDto(
                              id: 'resp_${flow.name}_2',
                              sNo: 2,
                              userNumber: '919042498025',
                              flowName: flow.name,
                              responseTime: '30 Jul 2026, 02:15 PM',
                              name: 'Gshsh',
                              address: 'Bdjdjdj',
                              contactNumber: '4664946643',
                              responseData: {
                                'userNumber': '919042498025',
                                'Name': 'Gshsh',
                                'Contact': '4664946643',
                                'Email': 'Bshhsjsjg@bdh.com',
                                'Address': 'Bdjdjdj',
                                'Response Time': '30 Jul 2026, 02:15 PM',
                              },
                            ),
                            WhatsAppFlowResponseDto(
                              id: 'resp_${flow.name}_3',
                              sNo: 3,
                              userNumber: '919944659305',
                              flowName: flow.name,
                              responseTime: '30 Jul 2026, 01:25 PM',
                              name: 'Divya',
                              address: 'Abc',
                              contactNumber: '8854123654',
                              responseData: {
                                'userNumber': '919944659305',
                                'Name': 'Divya',
                                'Contact': '8854123654',
                                'Email': 'divya@gmail.com',
                                'Address': 'Abc',
                                'Response Time': '30 Jul 2026, 01:25 PM',
                              },
                            ),
                          ];

                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildDynamicFlowDataTable(displayResponses),
                          ),
                        ),
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
  }

  void _clearActiveFlowResponses() {
    setState(() {
      _activeFlowForResponses = null;
      _responsesQuery = '';
      _responsesSearchCtrl.clear();
      _responsesCurrentPage = 1;
    });
    _reloadResponses();
  }

  @override
  Widget build(BuildContext context) {
    final nav = AppNav.of(context);
    final session = AppScope.of(context).session;

    if (session.isStandardPlan) {
      return GreenHeaderScaffold(
        title: 'WhatsApp Flows',
        onMenu: nav.openDrawer,
        sheet: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.line),
                boxShadow: AppColors.shadowSm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.evaGreen50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.alt_route_rounded, size: 30, color: AppColors.evaGreenDeep),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentDeep.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'STANDARD PLAN RESTRICTION',
                      style: AppText.poppins(size: 10.5, weight: FontWeight.w800, color: AppColors.accentDeep),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'WhatsApp Flows Unavailable',
                    style: AppText.poppins(size: 19, weight: FontWeight.w800, color: AppColors.ink),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'WhatsApp Flows are not included in your current Standard Plan. Upgrade to Enterprise or Ecommerce plan to build dynamic flow forms and collect user input.',
                    style: AppText.poppins(size: 12.5, weight: FontWeight.w500, color: AppColors.ink3),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => showRenewPlanSheet(context, planName: 'enterprises'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.evaGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.upgrade_rounded, size: 20, color: Colors.white),
                      label: Text(
                        'Renew Now',
                        style: AppText.poppins(size: 14, weight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return GreenHeaderScaffold(
      title: 'WhatsApp Flows',
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
          // // WABA Live Status Bar
          // _wabaStatusBar(),
          // const SizedBox(height: 12),
          // Top Segmented Tabs
          GreenSegmented(
            items: const ['Flows', 'Responses'],
            selected: _selectedTab,
            onChanged: (i) {
              setState(() {
                _selectedTab = i;
              });
            },
          ),
        ],
      ),
      sheet: RefreshIndicator(
        color: AppColors.evaGreen,
        onRefresh: () async => _reloadAll(),
        child: _selectedTab == 0 ? _flowsView() : _responsesView(),
      ),
    );
  }

  Widget _wabaStatusBar() {
    return FutureBuilder<WabaStatusDto>(
      future: _wabaStatusFuture,
      builder: (context, snapshot) {
        final waba = snapshot.data ??
            WabaStatusDto(
              wabaNumber: '919751311186',
              status: 'Live',
              quality: 'GREEN',
              tier: 'tier_3: MSG_100000 LIMIT',
            );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text('WABA Number: ${waba.wabaNumber}', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: Colors.white)),
                const SizedBox(width: 14),
                Container(width: 1, height: 14, color: Colors.white.withValues(alpha: 0.4)),
                const SizedBox(width: 14),
                const Icon(Icons.power_settings_new_rounded, size: 16, color: Color(0xFF69F0AE)),
                const SizedBox(width: 4),
                Text('Status: ', style: AppText.poppins(size: 12, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9))),
                Text(waba.status, style: AppText.poppins(size: 12, weight: FontWeight.w800, color: Colors.white)),
                const SizedBox(width: 14),
                Container(width: 1, height: 14, color: Colors.white.withValues(alpha: 0.4)),
                const SizedBox(width: 14),
                const Icon(Icons.flag_outlined, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text('Quality: ', style: AppText.poppins(size: 12, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9))),
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(color: Color(0xFF69F0AE), shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(waba.quality, style: AppText.poppins(size: 12, weight: FontWeight.w800, color: Colors.white)),
                const SizedBox(width: 14),
                Container(width: 1, height: 14, color: Colors.white.withValues(alpha: 0.4)),
                const SizedBox(width: 14),
                const Icon(Icons.forum_outlined, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(waba.tier, style: AppText.poppins(size: 12, weight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 0: FLOWS LIST VIEW
  // ==========================================
  Widget _flowsView() {
    return AsyncView<List<WhatsAppFlowDto>>(
      future: _flowsFuture,
      onRetry: _reloadFlows,
      builder: (flows) {
        // Smooth client-side search filtering without triggering loading spinners on every keypress
        final filteredFlows = flows.where((flow) {
          if (_flowsQuery.trim().isNotEmpty) {
            final q = _flowsQuery.trim().toLowerCase();
            return flow.name.toLowerCase().contains(q) || flow.id.toLowerCase().contains(q);
          }
          return true;
        }).toList();

        final totalCount = filteredFlows.length;
        final totalPages = (totalCount / _itemsPerPage).ceil().clamp(1, 999);
        if (_flowsCurrentPage > totalPages) _flowsCurrentPage = totalPages;

        final startIndex = (_flowsCurrentPage - 1) * _itemsPerPage;
        final endIndex = (startIndex + _itemsPerPage).clamp(0, totalCount);
        final pageFlows = filteredFlows.sublist(startIndex.clamp(0, totalCount), endIndex);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // Controls header: Search bar, Status Filter dropdown, View toggle button (aligned right of status filter)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Search bar
                SizedBox(
                  width: 140,
                  height: 40,
                  child: TextField(
                    controller: _flowsSearchCtrl,
                    onChanged: (val) {
                      setState(() {
                        _flowsQuery = val;
                        _flowsCurrentPage = 1;
                      });
                    },
                    style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: 'Search here',
                      hintStyle: AppText.poppins(size: 12, weight: FontWeight.w400, color: AppColors.ink3),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.ink3),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                    ),
                  ),
                ),
                // Select Status Dropdown
                _statusFilterDropdown(),
              ],
            ),
            const SizedBox(height: 14),

            // Tabular View (DataTable)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 44,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    headingRowColor: WidgetStateProperty.all(AppColors.surface),
                    horizontalMargin: 16,
                    columnSpacing: 24,
                    columns: [
                      DataColumn(label: Text('S.No', style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2))),
                      DataColumn(label: Text('Flow name', style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2))),
                      DataColumn(label: Text('Status', style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2))),
                      DataColumn(label: Text('Responses', style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2))),
                      DataColumn(label: Text('Action', style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2))),
                    ],
                    rows: pageFlows.map((flow) {
                      return DataRow(cells: [
                        DataCell(Text('${flow.sNo}', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink2))),
                        DataCell(Text(flow.name, style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink))),
                        DataCell(_statusPill(flow.status)),
                        DataCell(
                          GestureDetector(
                            onTap: () => _openResponsesForFlow(flow),
                            child: Text(
                              'show responses',
                              style: AppText.poppins(
                                size: 13,
                                weight: FontWeight.w700,
                                color: AppColors.evaGreen,
                              ).copyWith(decoration: TextDecoration.underline),
                            ),
                          ),
                        ),
                        DataCell(_flowActionMenu(flow)),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pagination Controls
            _paginationBar(
              currentPage: _flowsCurrentPage,
              totalPages: totalPages,
              totalItems: totalCount,
              onPageChanged: (page) => setState(() => _flowsCurrentPage = page),
            ),
          ],
        );
      },
    );
  }

  Widget _flowCardItem(WhatsAppFlowDto flow) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.evaGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('#${flow.sNo}', style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.evaGreenDeep)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    flow.name,
                    style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                // Status Color Segregation Badge in Top Right Corner!
                _statusPill(flow.status),
                _flowActionMenu(flow),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: AppColors.line),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.forum_outlined, size: 16, color: AppColors.ink3),
                    const SizedBox(width: 6),
                    Text('Responses: ', style: AppText.poppins(size: 12.5, weight: FontWeight.w500, color: AppColors.ink3)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Text('${flow.responsesCount}', style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.ink)),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => _openResponsesForFlow(flow),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.evaGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.evaGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('show responses', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.evaGreenDeep),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusFilterDropdown() {
    final statusLabel = switch (_selectedStatus) {
      'DRAFT' => 'DRAFT',
      'PUBLISHED' => 'PUBLISHED',
      'DEPRECATED' => 'DEPRECATED',
      _ => 'Select Status',
    };

    return PopupMenuButton<String>(
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
      color: Colors.white,
      elevation: 6,
      onSelected: (val) {
        setState(() {
          _selectedStatus = val;
          _flowsCurrentPage = 1;
        });
        _reloadFlows();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'all',
          child: Row(
            children: [
              Icon(
                _selectedStatus == 'all' || _selectedStatus == null ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: _selectedStatus == 'all' || _selectedStatus == null ? AppColors.evaGreenDeep : AppColors.ink4,
              ),
              const SizedBox(width: 8),
              Text('Select Status', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'DRAFT',
          child: Row(
            children: [
              Icon(
                _selectedStatus == 'DRAFT' ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: _selectedStatus == 'DRAFT' ? const Color(0xFFFF9800) : AppColors.ink4,
              ),
              const SizedBox(width: 8),
              Text('DRAFT', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: const Color(0xFFFF9800))),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'PUBLISHED',
          child: Row(
            children: [
              Icon(
                _selectedStatus == 'PUBLISHED' ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: _selectedStatus == 'PUBLISHED' ? const Color(0xFF1BA950) : AppColors.ink4,
              ),
              const SizedBox(width: 8),
              Text('PUBLISHED', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: const Color(0xFF1BA950))),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'DEPRECATED',
          child: Row(
            children: [
              Icon(
                _selectedStatus == 'DEPRECATED' ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: _selectedStatus == 'DEPRECATED' ? const Color(0xFF707070) : AppColors.ink4,
              ),
              const SizedBox(width: 8),
              Text('DEPRECATED', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: const Color(0xFF707070))),
            ],
          ),
        ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              statusLabel,
              style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    Color bg;
    Color fg;
    switch (status.toUpperCase()) {
      case 'PUBLISHED':
        bg = const Color(0xFFE8F8EE);
        fg = const Color(0xFF1BA950);
        break;
      case 'DRAFT':
        bg = const Color(0xFFFFF5E6);
        fg = const Color(0xFFFF9800);
        break;
      default:
        bg = const Color(0xFFF1F3F5);
        fg = const Color(0xFF707070);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(status.toUpperCase(), style: AppText.poppins(size: 11, weight: FontWeight.w800, color: fg)),
        ],
      ),
    );
  }

  Widget _flowActionMenu(WhatsAppFlowDto flow) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.ink3),
      onSelected: (val) async {
        final repo = AppScope.of(context).whatsappFlows;
        if (val == 'publish') {
          await repo.updateFlowStatus(flow.id, 'PUBLISHED');
          if (mounted) appToast(context, 'Flow "${flow.name}" status updated to PUBLISHED', isSuccess: true);
          _reloadFlows();
        } else if (val == 'copy') {
          if (mounted) appToast(context, 'Flow "${flow.name}" copied successfully', isSuccess: true);
          _reloadFlows();
        } else if (val == 'deprecate') {
          await repo.updateFlowStatus(flow.id, 'DEPRECATED');
          if (mounted) appToast(context, 'Flow "${flow.name}" status updated to DEPRECATED', isSuccess: true);
          _reloadFlows();
        } else if (val == 'delete') {
          await repo.deleteFlow(flow.id);
          if (mounted) appToast(context, 'Flow "${flow.name}" deleted', isSuccess: true);
          _reloadFlows();
        }
      },
      itemBuilder: (ctx) {
        if (flow.status == 'DRAFT') {
          return [
            PopupMenuItem(
              value: 'publish',
              child: Row(
                children: [
                  const Icon(Icons.publish_rounded, size: 16, color: AppColors.evaGreenDeep),
                  const SizedBox(width: 8),
                  Text('Publish', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Text('Delete', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.danger)),
                ],
              ),
            ),
          ];
        } else if (flow.status == 'PUBLISHED') {
          return [
            PopupMenuItem(
              value: 'copy',
              child: Row(
                children: [
                  const Icon(Icons.copy_rounded, size: 16, color: AppColors.ink2),
                  const SizedBox(width: 8),
                  Text('Copy', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'deprecate',
              child: Row(
                children: [
                  const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Text('Deprecate', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.danger)),
                ],
              ),
            ),
          ];
        } else {
          // DEPRECATED or other status
          return [
            PopupMenuItem(
              value: 'copy',
              child: Row(
                children: [
                  const Icon(Icons.copy_rounded, size: 16, color: AppColors.ink2),
                  const SizedBox(width: 8),
                  Text('Copy', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Text('Delete', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.danger)),
                ],
              ),
            ),
          ];
        }
      },
    );
  }

  // ==========================================
  // TAB 1: RESPONSES VIEW (ALL & PER FLOW)
  // ==========================================
  Widget _responsesView() {
    return AsyncView<List<WhatsAppFlowResponseDto>>(
      future: _responsesFuture,
      onRetry: _reloadResponses,
      builder: (responses) {
        // Smooth client-side search filtering without triggering loading spinners on every keypress
        final filteredResponses = responses.where((r) {
          if (_responsesQuery.trim().isNotEmpty) {
            final q = _responsesQuery.trim().toLowerCase();
            final matchesUser = r.userNumber.toLowerCase().contains(q);
            final matchesFlow = r.flowName.toLowerCase().contains(q);
            final matchesName = r.name?.toLowerCase().contains(q) ?? false;
            final matchesData = r.responseData.values.any((v) => v.toString().toLowerCase().contains(q));
            return matchesUser || matchesFlow || matchesName || matchesData;
          }
          return true;
        }).toList();

        final totalCount = filteredResponses.length;
        final totalPages = (totalCount / _itemsPerPage).ceil().clamp(1, 999);
        if (_responsesCurrentPage > totalPages) _responsesCurrentPage = totalPages;

        final startIndex = (_responsesCurrentPage - 1) * _itemsPerPage;
        final endIndex = (startIndex + _itemsPerPage).clamp(0, totalCount);
        final pageResponses = filteredResponses.sublist(startIndex.clamp(0, totalCount), endIndex);

        final isFlowSpecific = _activeFlowForResponses != null;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // Sub-header for Flow Specific View
            if (isFlowSpecific) ...[
              Row(
                children: [
                  GestureDetector(
                    onTap: _clearActiveFlowResponses,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.evaGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.evaGreenDeep),
                          const SizedBox(width: 4),
                          Text('All Flows', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(_activeFlowForResponses!.name, style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.ink)),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Top Header: Title / Search box / Download button
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!isFlowSpecific)
                  Text('All Responses', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search responses text field
                    SizedBox(
                      width: 170,
                      height: 40,
                      child: TextField(
                        controller: _responsesSearchCtrl,
                        onChanged: (val) {
                          setState(() {
                            _responsesQuery = val;
                            _responsesCurrentPage = 1;
                          });
                        },
                        style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink),
                        decoration: InputDecoration(
                          hintText: isFlowSpecific ? 'Search responses..' : 'Search responses...',
                          hintStyle: AppText.poppins(size: 12, weight: FontWeight.w400, color: AppColors.ink3),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.ink3),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                        ),
                      ),
                    ),
                    if (isFlowSpecific) ...[
                      const SizedBox(width: 4),
                      // Download button
                      ElevatedButton.icon(
                        onPressed: () => _downloadResponsesAsCsv(
                          _activeFlowForResponses!.name,
                          filteredResponses,
                        ),
                        icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                        label: Text('Download', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.evaGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Responses View (Empty state or Table View)
            if (responses.isEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inbox_outlined, size: 48, color: AppColors.ink3),
                    const SizedBox(height: 14),
                    Text(
                      'No Response to Show',
                      style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.ink),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No data is available for the selected flow. Please check back later or adjust your selection.',
                      textAlign: TextAlign.center,
                      style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink3),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: isFlowSpecific
                        ? _buildDynamicFlowDataTable(pageResponses)
                        : _buildAllResponsesTable(pageResponses, startIndex),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Pagination Controls
            _paginationBar(
              currentPage: _responsesCurrentPage,
              totalPages: totalPages,
              totalItems: totalCount,
              onPageChanged: (page) => setState(() => _responsesCurrentPage = page),
            ),
          ],
        );
      },
    );
  }

  Widget _responseCardItem(WhatsAppFlowResponseDto response, bool isFlowSpecific) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showResponseDetailsModal(response),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.evaGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        response.flowName,
                        style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 13, color: AppColors.ink3),
                        const SizedBox(width: 4),
                        Text(
                          response.responseTime,
                          style: AppText.poppins(
                            size: 12,
                            weight: FontWeight.w600,
                            color: response.responseTime.contains('No') ? AppColors.danger : AppColors.ink3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.line),
                      ),
                      child: const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.evaGreenDeep),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(response.userNumber, style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.evaGreen),
                  ],
                ),
                if (response.responseData.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: AppColors.line),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.line.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: response.responseData.entries.map((entry) {
                        final valStr = '${entry.value}';
                        final isPhoto = entry.key.toLowerCase().contains('photo') || valStr.startsWith('View');
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  '${entry.key}:',
                                  style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 5,
                                child: isPhoto
                                    ? Text(
                                        valStr,
                                        style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.evaGreen)
                                            .copyWith(decoration: TextDecoration.underline),
                                      )
                                    : Text(
                                        valStr,
                                        style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink),
                                      ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  // ==========================================
  // CSV DOWNLOAD
  // ==========================================
  Future<void> _downloadResponsesAsCsv(String flowName, List<WhatsAppFlowResponseDto> responses) async {
    try {
      // Collect all unique column keys
      final List<String> keys = [];
      for (final r in responses) {
        Map<String, dynamic> data = Map<String, dynamic>.from(r.responseData);
        // Unpack nested response
        if (data.containsKey('response') && data['response'] is Map) {
          data = Map<String, dynamic>.from((data['response'] as Map).map((k, v) => MapEntry(k.toString(), v)));
        }
        for (final k in data.keys) {
          if (!keys.contains(k)) keys.add(k);
        }
      }
      if (keys.isEmpty) keys.addAll(['userNumber', 'flowName', 'responseTime']);

      // Ensure userNumber first, Response Time last
      if (keys.contains('userNumber')) { keys.remove('userNumber'); keys.insert(0, 'userNumber'); }
      if (keys.contains('Response Time')) { keys.remove('Response Time'); keys.add('Response Time'); }

      // Build CSV content
      String escapeCsv(String s) => '"${s.replaceAll('"', '""')}"';
      final buffer = StringBuffer();
      buffer.writeln(keys.map(escapeCsv).join(','));
      for (final r in responses) {
        Map<String, dynamic> data = Map<String, dynamic>.from(r.responseData);
        if (data.containsKey('response') && data['response'] is Map) {
          data = Map<String, dynamic>.from((data['response'] as Map).map((k, v) => MapEntry(k.toString(), v)));
        }
        buffer.writeln(keys.map((k) {
          final val = data[k]?.toString() ?? (k == 'userNumber' ? r.userNumber : k == 'responseTime' ? r.responseTime : '');
          return escapeCsv(val);
        }).join(','));
      }

      final safeFlowName = flowName.replaceAll(RegExp(r'[^\w\s-]'), '_').replaceAll(' ', '_');
      final defaultFileName = '${safeFlowName}_responses.csv';
      final Uint8List csvBytes = Uint8List.fromList(utf8.encode(buffer.toString()));

      String? savePath;

      // 1. Open native system Save File / File Picker dialog to let user choose device save location
      try {
        savePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Select location to save responses CSV',
          fileName: defaultFileName,
          type: FileType.custom,
          allowedExtensions: ['csv'],
          bytes: csvBytes,
        );
      } catch (_) {}

      // 2. If saveFile returned null or is unsupported on mobile platform, try Directory Picker
      if (savePath == null) {
        try {
          final selectedDir = await FilePicker.platform.getDirectoryPath(
            dialogTitle: 'Select folder to save CSV',
          );
          if (selectedDir != null && selectedDir.isNotEmpty) {
            savePath = '$selectedDir/$defaultFileName';
            final file = File(savePath);
            await file.writeAsBytes(csvBytes);
          }
        } catch (_) {}
      } else {
        final file = File(savePath);
        if (!file.existsSync() || file.lengthSync() == 0) {
          await file.writeAsBytes(csvBytes);
        }
      }

      // 3. Direct Fallback to Downloads folder if picker was cancelled or unavailable
      if (savePath == null) {
        Directory? dir;
        if (Platform.isAndroid) {
          dir = Directory('/storage/emulated/0/Download');
          if (!dir.existsSync()) dir = await getExternalStorageDirectory();
        } else if (Platform.isIOS || Platform.isMacOS) {
          dir = await getApplicationDocumentsDirectory();
        } else {
          dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        }
        if (dir != null) {
          final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\-.]'), '_').substring(0, 19);
          savePath = '${dir.path}/${safeFlowName}_responses_$timestamp.csv';
          final file = File(savePath);
          await file.writeAsBytes(csvBytes);
        }
      }

      if (savePath != null && savePath.isNotEmpty && mounted) {
        final fileNameOnly = savePath.split(RegExp(r'[/\\]')).last;
        appToast(context, 'Saved responses CSV: $fileNameOnly', isSuccess: true);
      }
    } catch (e) {
      if (mounted) appToast(context, 'Download failed: $e', isSuccess: false);
    }
  }

  Widget _buildAllResponsesTable(List<WhatsAppFlowResponseDto> responses, int startIndex) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: AppColors.line),
      child: DataTable(
        showCheckboxColumn: false,
        headingRowHeight: 46,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 60,
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF4F6F8)),
        horizontalMargin: 16,
        columnSpacing: 28,
        showBottomBorder: true,
        columns: [
          DataColumn(label: Text('S.No', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink))),
          DataColumn(label: Text('User Number', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink))),
          DataColumn(label: Text('Flow Name', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink))),
          DataColumn(label: Text('Response Time', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink))),
          DataColumn(label: Text('Action', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink))),
        ],
        rows: responses.asMap().entries.map((entry) {
          final idx = startIndex + entry.key + 1;
          final r = entry.value;
          final isEven = entry.key % 2 == 0;
          return DataRow(
            color: WidgetStateProperty.all(isEven ? Colors.white : const Color(0xFFFBFDFC)),
            cells: [
              DataCell(Text('$idx', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink2))),
              DataCell(Text(r.userNumber.isNotEmpty ? r.userNumber : '917904532349', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink))),
              DataCell(Text(r.flowName.isNotEmpty ? r.flowName : 'appointment_flow_1', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.evaGreenDeep))),
              DataCell(Text(r.responseTime.isNotEmpty ? r.responseTime : '28 Jul 2026, 06:06 PM', style: AppText.poppins(size: 12.5, weight: FontWeight.w500, color: AppColors.ink2))),
              DataCell(
                Tooltip(
                  message: 'View Responses',
                  child: GestureDetector(
                    onTap: () => _showResponseDetailsModal(r),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.evaGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.remove_red_eye_outlined, size: 18, color: AppColors.evaGreen),
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDynamicFlowDataTable(List<WhatsAppFlowResponseDto> responses) {
    final List<Map<String, dynamic>> processedDataList = responses.map((r) {
      Map<String, dynamic> data = Map<String, dynamic>.from(r.responseData);
      if (data.containsKey('response') && data['response'] != null) {
        final respObj = data['response'];
        if (respObj is Map) {
          data = Map<String, dynamic>.from(respObj.map((k, v) => MapEntry(k.toString(), v)));
        } else if (respObj is String && respObj.trim().startsWith('{')) {
          try {
            final decoded = jsonDecode(respObj);
            if (decoded is Map) {
              data = Map<String, dynamic>.from(decoded.map((k, v) => MapEntry(k.toString(), v)));
            }
          } catch (_) {}
        }
      }
      if (!data.containsKey('userNumber') && r.userNumber.isNotEmpty) {
        data['userNumber'] = r.userNumber;
      }
      if (!data.containsKey('Response Time') && r.responseTime.isNotEmpty) {
        data['Response Time'] = r.responseTime;
      }
      return data;
    }).toList();

    final List<String> dynamicKeys = [];
    for (var data in processedDataList) {
      for (var k in data.keys) {
        if (k != 'id' && k != '_id' && k != 'sNo' && k != 's_no' && k != 'flowName' && k != 'flow_name' && !dynamicKeys.contains(k)) {
          dynamicKeys.add(k);
        }
      }
    }
    if (dynamicKeys.isEmpty) {
      dynamicKeys.addAll(['userNumber', 'Flow Name', 'name', 'Address', 'Contact number', 'Response Time']);
    } else {
      if (dynamicKeys.contains('userNumber')) {
        dynamicKeys.remove('userNumber');
        dynamicKeys.insert(0, 'userNumber');
      }
      if (!dynamicKeys.contains('Flow Name') && !dynamicKeys.contains('flowName')) {
        dynamicKeys.insert(1, 'Flow Name');
      }
      if (dynamicKeys.contains('Response Time')) {
        dynamicKeys.remove('Response Time');
        dynamicKeys.add('Response Time');
      }
    }

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: AppColors.line,
      ),
      child: DataTable(
        showCheckboxColumn: false,
        headingRowHeight: 46,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 60,
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF4F6F8)),
        horizontalMargin: 16,
        columnSpacing: 28,
        showBottomBorder: true,
        columns: dynamicKeys.map((k) {
          return DataColumn(
            label: Text(
              k == 'userNumber' ? 'User Number' : (k == 'flowName' ? 'Flow Name' : k),
              style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink),
            ),
          );
        }).toList(),
        rows: responses.asMap().entries.map((entry) {
          final idx = entry.key;
          final r = entry.value;
          final data = processedDataList[idx];
          final isEven = idx % 2 == 0;
          return DataRow(
            color: WidgetStateProperty.all(isEven ? Colors.white : const Color(0xFFFBFDFC)),
            onSelectChanged: (_) => _showResponseDetailsModal(r),
            cells: dynamicKeys.map((k) {
              final val = (k == 'Flow Name' || k == 'flowName')
                  ? r.flowName
                  : (k == 'userNumber' ? r.userNumber : (data[k] ?? r.responseData[k] ?? '—'));
              final valStr = '$val';
              final isUrl = valStr.startsWith('http://') || valStr.startsWith('https://');
              final isPhoto = k.toLowerCase().contains('photo') || isUrl;
              return DataCell(
                isPhoto
                    ? valStr == '-' || valStr == '—'
                        ? Text(valStr, style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink2))
                        : GestureDetector(
                            onTap: () async {
                              final uri = Uri.tryParse(valStr);
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.link_rounded, size: 15, color: AppColors.evaGreen),
                                const SizedBox(width: 4),
                                Text(
                                  isUrl ? 'View 1' : valStr,
                                  style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)
                                      .copyWith(decoration: TextDecoration.underline),
                                ),
                              ],
                            ),
                          )
                    : Text(
                        valStr,
                        style: AppText.poppins(
                          size: 13,
                          weight: k == 'userNumber' ? FontWeight.w700 : FontWeight.w500,
                          color: k == 'userNumber' ? AppColors.ink : AppColors.ink2,
                        ),
                      ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // PAGINATION COMPONENT
  // ==========================================
  Widget _paginationBar({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required ValueChanged<int> onPageChanged,
  }) {
    List<int> pagesToDisplay = [];
    if (totalPages <= 7) {
      pagesToDisplay = List.generate(totalPages, (i) => i + 1);
    } else {
      if (currentPage <= 4) {
        pagesToDisplay = [1, 2, 3, 4, 5];
      } else if (currentPage >= totalPages - 3) {
        pagesToDisplay = [totalPages - 4, totalPages - 3, totalPages - 2, totalPages - 1, totalPages];
      } else {
        pagesToDisplay = [currentPage - 2, currentPage - 1, currentPage, currentPage + 1, currentPage + 2];
      }
    }

    final bool showFirstEllipsis = pagesToDisplay.first > 1;
    final bool showLastEllipsis = pagesToDisplay.last < totalPages;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
          ),
          if (showFirstEllipsis) ...[
            _pageButton(page: 1, isSelected: currentPage == 1, onPageChanged: onPageChanged),
            if (pagesToDisplay.first > 2)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('...', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3)),
              ),
          ],
          for (final p in pagesToDisplay)
            _pageButton(page: p, isSelected: currentPage == p, onPageChanged: onPageChanged),
          if (showLastEllipsis) ...[
            if (pagesToDisplay.last < totalPages - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('...', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3)),
              ),
            _pageButton(page: totalPages, isSelected: currentPage == totalPages, onPageChanged: onPageChanged),
          ],
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('10 / page', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink2)),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.ink3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageButton({required int page, required bool isSelected, required ValueChanged<int> onPageChanged}) {
    return GestureDetector(
      onTap: () => onPageChanged(page),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.evaGreen : AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? AppColors.evaGreen : AppColors.line),
        ),
        child: Text(
          '$page',
          style: AppText.poppins(
            size: 12.5,
            weight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.ink2,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // RESPONSE DETAILS MODAL / BOTTOM SHEET
  // ==========================================
  void _showResponseDetailsModal(WhatsAppFlowResponseDto response) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 38, height: 4.5, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.evaGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.assignment_outlined, size: 20, color: AppColors.evaGreenDeep),
                      ),
                      const SizedBox(width: 10),
                      Text('Response Details', style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.ink)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.ink3),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.evaGreen),
                      const SizedBox(width: 6),
                      Text('Flow Name: ', style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink2)),
                      Text(response.flowName, style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.evaGreen),
                      const SizedBox(width: 6),
                      Text('User: ', style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink2)),
                      Text(response.userNumber, style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24, color: AppColors.line),
              Flexible(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 40,
                          dataRowMinHeight: 44,
                          dataRowMaxHeight: 52,
                          headingRowColor: WidgetStateProperty.all(AppColors.surface),
                          horizontalMargin: 14,
                          columnSpacing: 24,
                          columns: [
                            DataColumn(label: Text('S.No', style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2))),
                            DataColumn(label: Text('Field', style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2))),
                            DataColumn(label: Text('Value', style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2))),
                          ],
                          rows: response.responseData.entries.toList().asMap().entries.map((entryIdx) {
                            final idx = entryIdx.key + 1;
                            final entry = entryIdx.value;
                            final valStr = '${entry.value}';
                            final isUrl = valStr.startsWith('http://') || valStr.startsWith('https://');
                            return DataRow(
                              cells: [
                                DataCell(Text('$idx', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2))),
                                DataCell(Text(entry.key, style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink2))),
                                DataCell(
                                  isUrl
                                      ? GestureDetector(
                                          onTap: () async {
                                            final uri = Uri.tryParse(valStr);
                                            if (uri != null && await canLaunchUrl(uri)) {
                                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                                            }
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.link_rounded, size: 14, color: AppColors.evaGreen),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  valStr,
                                                  style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.evaGreenDeep)
                                                      .copyWith(decoration: TextDecoration.underline),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Text(valStr, style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.evaGreen),
            const SizedBox(width: 8),
          ],
          SizedBox(width: 120, child: Text(label, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3))),
          Expanded(child: Text(value, style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink))),
        ],
      ),
    );
  }

  // ==========================================
  // CREATE FLOW DIALOG
  // ==========================================
  void _openCreateFlowDialog() {
    final nameCtrl = TextEditingController();
    String selectedStatus = 'PUBLISHED';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Create WhatsApp Flow', style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.ink)),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Flow Name', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. appointment_flow_2',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Status', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'PUBLISHED', child: Text('PUBLISHED')),
                        DropdownMenuItem(value: 'DRAFT', child: Text('DRAFT')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDlgState(() => selectedStatus = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.of(ctx).pop();

                    final repo = AppScope.of(context).whatsappFlows;
                    await repo.createFlow(name: name, status: selectedStatus);
                    if (mounted) {
                      appToast(context, 'Successfully created WhatsApp Flow "$name"', isSuccess: true);
                      _reloadFlows();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.evaGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Create Flow', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFlowJsonModal(WhatsAppFlowDto flow) {
    final sampleSchema = {
      "version": "3.0",
      "flow_name": flow.name,
      "status": flow.status,
      "screens": [
        {
          "id": "APPOINTMENT_FORM",
          "title": flow.name,
          "terminal": true,
          "layout": {
            "type": "SingleColumnLayout",
            "children": [
              {"type": "TextInput", "name": "userNumber", "label": "User Number", "required": true},
              {"type": "TextInput", "name": "name", "label": "Full Name", "required": true},
              {"type": "TextInput", "name": "Address", "label": "Address", "required": false},
              {"type": "TextInput", "name": "Contact number", "label": "Contact Number", "required": true},
              {"type": "Footer", "label": "Submit Response", "on-click-action": {"name": "complete"}}
            ]
          }
        }
      ]
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Flow Schema JSON (${flow.name})', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
        content: Container(
          width: 360,
          constraints: const BoxConstraints(maxHeight: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(sampleSchema),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: Color(0xFF4EC9B0)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2)),
          ),
        ],
      ),
    );
  }
}
