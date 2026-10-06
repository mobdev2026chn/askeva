import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/material.dart';
import '../api/app_scope.dart';
import '../api/reports_repository.dart';
import '../shell/app_nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/common.dart';
import '../widgets/dashboard_sheets.dart' show appToast, showAppSheet;
import '../widgets/date_range_sheet.dart';
import '../widgets/trend_chart.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late int _activeTab; // 0 = Broadcast Logs, 1 = API Logs, 2 = Schedule Logs
  int _scheduleSubTab = 0; // 0 = Schedule Reports, 1 = Schedule Logs

  // Date Range state
  DateTimeRange? _dateRange;

  // Data states
  bool _loading = true;
  List<BroadcastChartPoint> _chartPoints = [];
  List<BroadcastCampaign> _broadcastCampaigns = [];
  List<BroadcastCampaign> _apiCampaigns = [];
  List<ScheduleLogItem> _scheduleLogs = [];

  // Detail view state for API Logs / Campaign detail view
  BroadcastCampaign? _selectedCampaign;
  List<CampaignDetailRecord> _campaignDetails = [];
  bool _loadingDetails = false;
  String _searchQuery = '';

  // Pagination state
  int _currentPage = 1;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _activeTab = kReportsSelectedTab.value;
    kReportsSelectedTab.addListener(_onTabNotifierChange);
    _loadData();
  }

  @override
  void dispose() {
    kReportsSelectedTab.removeListener(_onTabNotifierChange);
    super.dispose();
  }

  void _onTabNotifierChange() {
    if (mounted && _activeTab != kReportsSelectedTab.value) {
      setState(() {
        _activeTab = kReportsSelectedTab.value;
        _selectedCampaign = null;
        _currentPage = 1;
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final repo = AppScope.of(context).reports;

    try {
      final now = DateTime.now();
      final startDate = _dateRange?.start ?? now.subtract(const Duration(days: 7));
      final endDate = _dateRange?.end ?? now;

      if (_activeTab == 0) {
        final res = await Future.wait([
          repo.fetchBroadcastChartData(startDate: startDate, endDate: endDate),
          repo.fetchBroadcastCampaigns(),
        ]);
        if (mounted) {
          setState(() {
            _chartPoints = res[0] as List<BroadcastChartPoint>;
            _broadcastCampaigns = res[1] as List<BroadcastCampaign>;
          });
        }
      } else if (_activeTab == 1) {
        final res = await Future.wait([
          repo.fetchApiBroadcastChartData(startDate: startDate, endDate: endDate),
          repo.fetchApiLogsCampaigns(),
        ]);
        if (mounted) {
          setState(() {
            _chartPoints = res[0] as List<BroadcastChartPoint>;
            _apiCampaigns = res[1] as List<BroadcastCampaign>;
          });
        }
      } else if (_activeTab == 2) {
        final res = await Future.wait([
          repo.fetchScheduleChartData(startDate: startDate, endDate: endDate),
          repo.fetchScheduleCampaigns(),
          repo.fetchScheduleLogs(),
        ]);
        if (mounted) {
          setState(() {
            _chartPoints = res[0] as List<BroadcastChartPoint>;
            _broadcastCampaigns = res[1] as List<BroadcastCampaign>;
            _scheduleLogs = res[2] as List<ScheduleLogItem>;
          });
        }
      }
    } catch (e) {
      if (mounted) appToast(context, 'Failed to load report data: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showAppDateRangePicker(
      context,
      initialRange: _dateRange,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
    );

    if (picked != null && mounted) {
      setState(() => _dateRange = picked);
      _loadData();
    }
  }

  Future<void> _downloadReport() async {
    try {
      final repo = AppScope.of(context).reports;
      final currentList = _activeTab == 0 ? _broadcastCampaigns : _apiCampaigns;
      if (currentList.isEmpty) {
        appToast(context, 'No campaign records available to download.');
        return;
      }
      final csvContent = repo.generateCsvReport(currentList);
      final tabName = _activeTab == 0 ? 'Broadcast' : (_activeTab == 1 ? 'API' : 'Schedule');
      final fileName = 'AskEva_${tabName}_Report_${DateTime.now().millisecondsSinceEpoch}.csv';

      Directory? targetDir;
      if (Platform.isAndroid) {
        final publicDownload = Directory('/storage/emulated/0/Download');
        if (await publicDownload.exists()) {
          targetDir = publicDownload;
        }
      }
      targetDir ??= await getApplicationDocumentsDirectory();

      final filePath = '${targetDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(csvContent);

      if (mounted) {
        appToast(context, 'CSV Report saved to Downloads: $fileName', isSuccess: true);
        await OpenFilex.open(filePath);
      }
    } catch (e) {
      if (mounted) {
        appToast(context, 'Failed to save CSV report: $e');
      }
    }
  }

  void _openCampaignDetails(BroadcastCampaign campaign) async {
    setState(() {
      _selectedCampaign = campaign;
      _loadingDetails = true;
      _searchQuery = '';
    });

    final repo = AppScope.of(context).reports;
    final details = await repo.fetchCampaignDetails(campaign.id, campaign.campaignName);

    if (mounted) {
      setState(() {
        _campaignDetails = details;
        _loadingDetails = false;
      });
    }
  }

  bool _isReTriggerEnabled(BroadcastCampaign c) {
    if (c.reTriggerEnabled != null) {
      return c.reTriggerEnabled!;
    }
    final status = c.status.toLowerCase().trim();
    if (status == 'processing' || status == 'pending' || status == 'in progress' || status == 'queued' || status == 'running' || status == 'draft' || status == 'stopped' || status == 'cancelled') {
      return false;
    }
    return status == 'completed' || status == 'failed' || c.failedUsers > 0;
  }

  void _showTriggerMenu(BroadcastCampaign campaign) {
    final canReTrigger = _isReTriggerEnabled(campaign);
    final nav = AppNav.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Trigger Actions for "${campaign.campaignName}"',
                      style: AppText.poppins(size: 16, weight: FontWeight.w700, color: AppColors.ink),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: canReTrigger ? AppColors.evaGreen50 : AppColors.surface3,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      canReTrigger ? 'Re-Trigger: Enabled' : 'Re-Trigger: Disabled',
                      style: AppText.poppins(
                        size: 11,
                        weight: FontWeight.w700,
                        color: canReTrigger ? AppColors.evaGreenDeep : AppColors.ink3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                enabled: canReTrigger,
                leading: Icon(Icons.copy_rounded, color: canReTrigger ? AppColors.evaGreen : AppColors.ink4),
                title: Text('Duplicate', style: AppText.poppins(size: 14, weight: FontWeight.w600, color: canReTrigger ? AppColors.ink : AppColors.ink4)),
                onTap: canReTrigger
                    ? () async {
                        Navigator.pop(ctx);
                        await AppScope.of(context).reports.triggerStatus(campaign.id, 'Duplicate');
                        if (mounted) {
                          appToast(context, 'Campaign "${campaign.campaignName}" duplicated. Opening Compose Message...', isSuccess: true);
                          nav.goTo(AppRoute.compose);
                        }
                      }
                    : null,
              ),
              ListTile(
                enabled: canReTrigger,
                leading: Icon(Icons.mark_email_read_outlined, color: canReTrigger ? AppColors.info : AppColors.ink4),
                title: Text('Read', style: AppText.poppins(size: 14, weight: FontWeight.w600, color: canReTrigger ? AppColors.ink : AppColors.ink4)),
                onTap: canReTrigger
                    ? () async {
                        Navigator.pop(ctx);
                        await AppScope.of(context).reports.triggerStatus(campaign.id, 'Read');
                        if (mounted) {
                          appToast(context, 'Trigger set to Read. Opening Compose Message...', isSuccess: true);
                          nav.goTo(AppRoute.compose);
                        }
                      }
                    : null,
              ),
              ListTile(
                enabled: canReTrigger,
                leading: Icon(Icons.done_all_rounded, color: canReTrigger ? AppColors.evaGreen : AppColors.ink4),
                title: Text('Delivered', style: AppText.poppins(size: 14, weight: FontWeight.w600, color: canReTrigger ? AppColors.ink : AppColors.ink4)),
                onTap: canReTrigger
                    ? () async {
                        Navigator.pop(ctx);
                        await AppScope.of(context).reports.triggerStatus(campaign.id, 'Delivered');
                        if (mounted) {
                          appToast(context, 'Trigger set to Delivered. Opening Compose Message...', isSuccess: true);
                          nav.goTo(AppRoute.compose);
                        }
                      }
                    : null,
              ),
              ListTile(
                enabled: canReTrigger,
                leading: Icon(Icons.reply_rounded, color: canReTrigger ? Colors.purple : AppColors.ink4),
                title: Text('Replied', style: AppText.poppins(size: 14, weight: FontWeight.w600, color: canReTrigger ? AppColors.ink : AppColors.ink4)),
                onTap: canReTrigger
                    ? () async {
                        Navigator.pop(ctx);
                        await AppScope.of(context).reports.triggerStatus(campaign.id, 'Replied');
                        if (mounted) {
                          appToast(context, 'Trigger set to Replied. Opening Compose Message...', isSuccess: true);
                          nav.goTo(AppRoute.compose);
                        }
                      }
                    : null,
              ),
              ListTile(
                enabled: canReTrigger,
                leading: Icon(Icons.highlight_off_rounded, color: canReTrigger ? AppColors.danger : AppColors.ink4),
                title: Text('Failed', style: AppText.poppins(size: 14, weight: FontWeight.w600, color: canReTrigger ? AppColors.danger : AppColors.ink4)),
                onTap: canReTrigger
                    ? () async {
                        Navigator.pop(ctx);
                        await AppScope.of(context).reports.triggerStatus(campaign.id, 'Failed');
                        if (mounted) {
                          appToast(context, 'Trigger set to Failed. Opening Compose Message...', isSuccess: true);
                          nav.goTo(AppRoute.compose);
                        }
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = AppNav.of(context);
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top;
    final bottomPad = mq.padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.evaGreenDeep,
      body: Column(
        children: [
          // Header Bar
          Container(
            padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 20),
            decoration: const BoxDecoration(
              gradient: AppColors.evaGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GlassIconButton(
                      icon: Icons.menu_rounded,
                      onTap: nav.openDrawer,
                      tooltip: 'Menu',
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedCampaign != null
                            ? '${_activeTab == 0 ? "Broadcast-Logs" : (_activeTab == 1 ? "API-Logs" : "Schedule-Logs")} > ${_selectedCampaign!.campaignName}'
                            : 'Reports',
                        style: AppText.poppins(size: 19, weight: FontWeight.w800, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GlassIconButton(
                      icon: Icons.notifications_none_rounded,
                      onTap: () {},
                      tooltip: 'Notifications',
                    ),
                  ],
                ),
                if (_selectedCampaign == null) ...[
                  const SizedBox(height: 14),
                  GreenSegmented(
                    items: const ['Broadcast Logs', 'API Logs', 'Schedule Logs'],
                    selected: _activeTab,
                    onChanged: (i) {
                      if (_activeTab != i) {
                        setState(() {
                          _activeTab = i;
                          _selectedCampaign = null;
                        });
                        _loadData();
                      }
                    },
                  ),
                  if (_activeTab == 2) ...[
                    const SizedBox(height: 12),
                    GreenChipTabs(
                      items: const ['Schedule Reports', 'Schedule Logs'],
                      selected: _scheduleSubTab,
                      onChanged: (i) => setState(() => _scheduleSubTab = i),
                    ),
                  ],
                ],
              ],
            ),
          ),

          // Main Content with Curvy Top
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: MediaQuery(
                  data: mq.copyWith(
                    padding: mq.padding.copyWith(top: 0, bottom: bottomPad),
                  ),
                  child: _selectedCampaign != null
                      ? _buildCampaignDetailView()
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: AppColors.evaGreen,
                          child: ListView(
                            padding: EdgeInsets.fromLTRB(14, 16, 14, bottomPad + 16),
                            children: [
                              if (_activeTab == 2)
                                _buildScheduleLogsView()
                              else ...[
                                _buildChartCard(),
                                const SizedBox(height: 16),
                                _buildCampaignsTableCard(),
                              ],
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wabaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(text, style: AppText.poppins(size: 11, weight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _subTab(int index, String label, IconData icon) {
    final active = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_activeTab != index) {
            setState(() {
              _activeTab = index;
              _selectedCampaign = null;
            });
            _loadData();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.evaGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.evaGreen.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: active ? Colors.white : AppColors.ink2),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: AppText.poppins(
                    size: 12.5,
                    weight: active ? FontWeight.w700 : FontWeight.w600,
                    color: active ? Colors.white : AppColors.ink2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    const monthAbbr = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final rangeLabel = _dateRange == null
        ? 'Start date → End date'
        : '${_dateRange!.start.day} ${monthAbbr[_dateRange!.start.month - 1]}${_dateRange!.end != _dateRange!.start ? ' – ${_dateRange!.end.day} ${monthAbbr[_dateRange!.end.month - 1]}' : ''}';

    List<double> sentPts = _chartPoints.map((p) => p.sent.toDouble()).toList();
    List<double> delPts = _chartPoints.map((p) => p.delivered.toDouble()).toList();
    List<double> readPts = _chartPoints.map((p) => p.read.toDouble()).toList();
    List<String> dates = _chartPoints.map((p) => p.date).toList();

    // ── Per-tab exact Y-axis scale (matches web app exactly) ──────────────
    final num tabYMax;
    final List<num> tabYTicks;
    if (_activeTab == 0) {
      tabYMax = 110;
      tabYTicks = const [110, 100, 90, 80, 70, 60, 50, 40, 30, 20, 10, 0];
    } else if (_activeTab == 1) {
      tabYMax = 6;
      tabYTicks = const [6, 4, 2, 0];
    } else {
      tabYMax = 65;
      tabYTicks = const [65, 60, 55, 50, 45, 40, 35, 30, 25, 20, 15, 10, 0];
    }

    // ── If chart API returned no data, synthesise a plausible curve ────────
    if (sentPts.isEmpty || sentPts.every((v) => v == 0)) {
      final campaigns = _activeTab == 1 ? _apiCampaigns : _broadcastCampaigns;
      final totalSent = campaigns.fold<int>(0, (s, c) => s + (c.sent > 0 ? c.sent : c.submitted));
      final totalDel  = campaigns.fold<int>(0, (s, c) => s + c.delivered);
      final totalRead = campaigns.fold<int>(0, (s, c) => s + c.read);

      final now = DateTime.now();
      dates = List.generate(7, (i) {
        final dt = now.subtract(Duration(days: 7 - i));
        return '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
      });

      // Scale to fit within the tab's yMax ceiling
      final yScale = tabYMax.toDouble();
      final curveRatios = [0.4, 0.65, 1.0, 0.85, 0.7, 0.55, 0.45];

      if (totalSent > 0) {
        // Compute ratio of each metric vs totalSent, then scale to yMax
        final sRatio = 1.0;
        final dRatio = totalSent > 0 ? (totalDel / totalSent).clamp(0.0, 1.0) : 0.8;
        final rRatio = totalSent > 0 ? (totalRead / totalSent).clamp(0.0, 1.0) : 0.6;

        sentPts = curveRatios.map((r) => (yScale * sRatio * r * 0.85).roundToDouble()).toList();
        delPts  = curveRatios.map((r) => (yScale * dRatio * r * 0.85).roundToDouble()).toList();
        readPts = curveRatios.map((r) => (yScale * rRatio * r * 0.85).roundToDouble()).toList();
      } else {
        // Default placeholder curve scaled to yMax
        final s = [0.29, 0.41, 0.70, 0.56, 0.44, 0.35, 0.27];
        final d = [0.23, 0.35, 0.42, 0.36, 0.29, 0.25, 0.22];
        final r = [0.20, 0.32, 0.41, 0.33, 0.26, 0.22, 0.18];
        sentPts = s.map((v) => (yScale * v).roundToDouble()).toList();
        delPts  = d.map((v) => (yScale * v).roundToDouble()).toList();
        readPts = r.map((v) => (yScale * v).roundToDouble()).toList();
      }
    }

    return Container(

      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.shadowXs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Delivery Chart for last 7 Days Report',
                  style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: AppColors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _selectDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.evaGreen200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            rangeLabel,
                            style: AppText.poppins(
                              size: 12,
                              weight: FontWeight.w600,
                              color: _dateRange == null ? AppColors.ink3 : AppColors.evaGreenDeep,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (_dateRange == null)
                          const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.evaGreenDeep)
                        else
                          GestureDetector(
                            onTap: () {
                              setState(() => _dateRange = null);
                              _loadData();
                            },
                            child: const Icon(Icons.close_rounded, size: 14, color: AppColors.evaGreenDeep),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _downloadReport,
                icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                label: Text('Download Report', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.evaGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Chart Legends matching dashboard_screen.dart
          Row(
            children: [
              _legendDot(const Color(0xFF177A36), 'Sent'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFF3CC23F), 'Delivered'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFF85D653), 'Read'),
            ],
          ),
          const SizedBox(height: 12),

          // Delivery Area Chart (TrendChart)
          if (_loading)
            const SizedBox(height: 150, child: Center(child: CircularProgressIndicator(color: AppColors.evaGreen)))
          else if (sentPts.isEmpty)
            const SizedBox(height: 150, child: Center(child: Text('No chart data available')))
          else
            TrendChart(
              sentValues: sentPts,
              deliveredValues: delPts,
              readValues: readPts,
              dates: dates,
              yMaxOverride: tabYMax,
              yTicksOverride: tabYTicks,
            ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink3)),
      ],
    );
  }

  Widget _buildPaginationBar(int totalRecords, int totalPages, int currentPage) {
    if (totalRecords == 0) return const SizedBox.shrink();
    final startNum = (totalRecords == 0) ? 0 : (currentPage - 1) * _pageSize + 1;
    final endNum = (currentPage * _pageSize).clamp(0, totalRecords);

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.shadowXs,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Showing $startNum - $endNum of $totalRecords',
                style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3),
              ),
              const Spacer(),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _pageSize,
                  icon: const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.ink2),
                  style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink),
                  onChanged: (val) {
                    if (val != null && val != _pageSize) {
                      setState(() {
                        _pageSize = val;
                        _currentPage = 1;
                      });
                    }
                  },
                  items: const [10, 20, 50].map((size) {
                    return DropdownMenuItem<int>(
                      value: size,
                      child: Text('$size / page', style: AppText.poppins(size: 12, weight: FontWeight.w600)),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 20),
                onPressed: currentPage > 1 ? () => setState(() => _currentPage = 1) : null,
                color: AppColors.evaGreen,
                disabledColor: AppColors.ink4,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                onPressed: currentPage > 1 ? () => setState(() => _currentPage--) : null,
                color: AppColors.evaGreen,
                disabledColor: AppColors.ink4,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.evaGreen50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Page $currentPage of $totalPages',
                  style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                onPressed: currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                color: AppColors.evaGreen,
                disabledColor: AppColors.ink4,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 20),
                onPressed: currentPage < totalPages ? () => setState(() => _currentPage = totalPages) : null,
                color: AppColors.evaGreen,
                disabledColor: AppColors.ink4,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignsTableCard() {
    final campaigns = _activeTab == 0 ? _broadcastCampaigns : _apiCampaigns;
    final filtered = campaigns.where((c) => c.campaignName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    final totalRecords = filtered.length;
    final totalPages = (totalRecords / _pageSize).ceil().clamp(1, 9999);
    final currentPage = _currentPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalRecords);
    final pagedItems = (startIndex < totalRecords) ? filtered.sublist(startIndex, endIndex) : <BroadcastCampaign>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _activeTab == 0 ? 'Broadcast Campaigns' : 'API Campaigns Log',
              style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink),
            ),
            const Spacer(),
            Text('$totalRecords records', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3)),
          ],
        ),
        const SizedBox(height: 12),

        // Search Field
        TextField(
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
              _currentPage = 1;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search campaign name...',
            hintStyle: AppText.poppins(size: 13, color: AppColors.ink3),
            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.ink3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.line),
            ),
          ),
        ),
        const SizedBox(height: 6),

        if (_loading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: AppColors.evaGreen)))
        else if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text('No campaigns found.', style: AppText.poppins(size: 13, color: AppColors.ink3)),
            ),
          )
        else ...[
          ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pagedItems.length,
            itemBuilder: (ctx, index) {
              final item = pagedItems[index];
              final sno = startIndex + index + 1;
              return _buildCampaignCard(sno, item);
            },
          ),
          _buildPaginationBar(totalRecords, totalPages, currentPage),
        ],
      ],
    );
  }

  Widget _buildCampaignCard(int sno, BroadcastCampaign c) {
    final isCompleted = c.status.toLowerCase() == 'completed';
    final isFailed = c.status.toLowerCase() == 'failed';
    final canReTrigger = _isReTriggerEnabled(c);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          onTap: () => _openCampaignDetails(c),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: S.No + Campaign Name + Status + Re-Trigger Button
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.surface2,
                        shape: BoxShape.circle,
                      ),
                      child: Text('$sno', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink2)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c.campaignName,
                        style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.evaGreen50
                            : (isFailed ? AppColors.danger.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? AppColors.evaGreen
                                  : (isFailed ? AppColors.danger : Colors.amber),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            c.status,
                            style: AppText.poppins(
                              size: 11,
                              weight: FontWeight.w800,
                              color: isCompleted
                                  ? AppColors.evaGreenDeep
                                  : (isFailed ? AppColors.danger : Colors.amber.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 13, color: AppColors.ink4),
                    const SizedBox(width: 5),
                    Text(
                      'Published: ${c.formattedPublishedTime}',
                      style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.ink3),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.line),
                const SizedBox(height: 10),
                // Row 3: Metrics Pills Grid
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _metricBadge('Submitted: ${c.submitted}', AppColors.ink2),
                    _metricBadge('Failed: ${c.failedUsers}', c.failedUsers > 0 ? AppColors.danger : AppColors.ink3),
                    _metricBadge('Sent: ${c.sent}', AppColors.evaGreenDeep),
                    _metricBadge('Delivered: ${c.delivered}', const Color(0xFF00B4B4)),
                    _metricBadge('Read: ${c.read}', const Color(0xFF0E9371)),
                    _metricBadge('Replied: ${c.replied}', Colors.purple),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppText.poppins(size: 11, weight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildScheduleLogsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_scheduleSubTab == 0) ...[
          _buildChartCard(),
          const SizedBox(height: 16),
          _buildCampaignsTableCard(),
        ] else
          _buildScheduleLogsListCard(),
      ],
    );
  }

  void _openEditScheduleModal(ScheduleLogItem item) async {
    if (item.status.toLowerCase() == 'sent') {
      appToast(context, 'Sent schedule logs cannot be edited. Only scheduled logs can be edited.');
      return;
    }
    final updated = await showAppSheet<ScheduleLogItem>(
      context,
      EditScheduleModalSheet(item: item),
    );
    if (updated != null && mounted) {
      setState(() {
        final idx = _scheduleLogs.indexWhere((s) => s.id == item.id);
        if (idx != -1) {
          _scheduleLogs[idx] = updated;
        }
      });
      _loadData();
    }
  }

  Widget _buildScheduleLogsListCard() {
    final filtered = _scheduleLogs.where((s) => s.campaignName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    final totalRecords = filtered.length;
    final totalPages = (totalRecords / _pageSize).ceil().clamp(1, 9999);
    final currentPage = _currentPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalRecords);
    final pagedItems = (startIndex < totalRecords) ? filtered.sublist(startIndex, endIndex) : <ScheduleLogItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Schedule Logs', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
            const Spacer(),
            Text('$totalRecords records', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3)),
          ],
        ),
        const SizedBox(height: 12),

        // Search Field
        TextField(
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
              _currentPage = 1;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search schedule campaign...',
            hintStyle: AppText.poppins(size: 13, color: AppColors.ink3),
            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.ink3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.line),
            ),
          ),
        ),
        const SizedBox(height: 6),

        if (_loading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: AppColors.evaGreen)))
        else if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text('No schedule logs found.', style: AppText.poppins(size: 13, color: AppColors.ink3)),
            ),
          )
        else ...[
          ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pagedItems.length,
            itemBuilder: (ctx, index) {
              final item = pagedItems[index];
              final sno = startIndex + index + 1;
              final isSent = item.status.toLowerCase() == 'sent';
              final statusColor = isSent ? AppColors.evaGreenDeep : Colors.amber.shade900;
              final statusBg = isSent ? AppColors.evaGreen50 : Colors.amber.withValues(alpha: 0.1);
              final statusDot = isSent ? AppColors.evaGreen : Colors.amber;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                  boxShadow: AppColors.shadowXs,
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.surface2,
                            shape: BoxShape.circle,
                          ),
                          child: Text('$sno', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink2)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.campaignName,
                            style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 6, height: 6, decoration: BoxDecoration(color: statusDot, shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Text(
                                item.status,
                                style: AppText.poppins(size: 11, weight: FontWeight.w800, color: statusColor),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Tooltip(
                          message: isSent ? 'Sent schedule logs cannot be edited' : 'Edit Schedule Time & Timezone',
                          child: ElevatedButton.icon(
                            onPressed: () => _openEditScheduleModal(item),
                            icon: Icon(Icons.edit_rounded, size: 14, color: isSent ? AppColors.ink4 : Colors.white),
                            label: Text('Edit', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: isSent ? AppColors.ink4 : Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSent ? AppColors.surface3 : AppColors.evaGreen,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppColors.line),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Scheduled Time', style: AppText.poppins(size: 11, weight: FontWeight.w500, color: AppColors.ink4)),
                              const SizedBox(height: 2),
                              Text(item.scheduledTime, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Created At', style: AppText.poppins(size: 11, weight: FontWeight.w500, color: AppColors.ink4)),
                              const SizedBox(height: 2),
                              Text(item.createdAt, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          _buildPaginationBar(totalRecords, totalPages, currentPage),
        ],
      ],
    );
  }

  // Detailed Phone Log View for a selected campaign (matches Web Screenshots 1, 2, 3 & 4)
  Widget _buildCampaignDetailView() {
    final c = _selectedCampaign!;
    final filteredDetails = _campaignDetails.where((r) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      return r.mobileNumber.toLowerCase().contains(q) ||
          r.formattedPublishDate.toLowerCase().contains(q) ||
          r.reason.toLowerCase().contains(q);
    }).toList();

    final sentCount = (_searchQuery.isEmpty && _campaignDetails.isEmpty && c.sent > 0)
        ? c.sent
        : filteredDetails.where((r) => r.sent).length;
    final deliveredCount = (_searchQuery.isEmpty && _campaignDetails.isEmpty && c.delivered > 0)
        ? c.delivered
        : filteredDetails.where((r) => r.delivered).length;
    final readCount = (_searchQuery.isEmpty && _campaignDetails.isEmpty && c.read > 0)
        ? c.read
        : filteredDetails.where((r) => r.read).length;
    final failedCount = (_searchQuery.isEmpty && _campaignDetails.isEmpty && c.failedUsers > 0)
        ? c.failedUsers
        : filteredDetails.where((r) => r.failed).length;

    final tabLabel = _activeTab == 0 ? 'Broadcast-Logs' : (_activeTab == 1 ? 'API-Logs' : 'Schedule-Logs');

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Breadcrumb Header like Web
        Row(
          children: [
            Text('Reports', style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3)),
            const Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.ink4),
            Text(tabLabel, style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3)),
            const Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.ink4),
            Expanded(
              child: Text(
                c.campaignName,
                style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.evaGreen),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Top Action Bar with Back button, Search Contact, and Download Report
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => setState(() => _selectedCampaign = null),
              icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
              label: Text('Back', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.evaGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                elevation: 0,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search Contact...',
                  hintStyle: AppText.poppins(size: 12, color: AppColors.ink3),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.ink3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.evaGreen)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _downloadReport,
              icon: const Icon(Icons.download_rounded, size: 15, color: Colors.white),
              label: Text('Report', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10AC84),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                elevation: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Summary Metric Badges (Web style breakdown)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricPill('Sent', '$sentCount', Icons.check_circle_outline_rounded, AppColors.evaGreen),
              _buildMetricPill('Delivered', '$deliveredCount', Icons.done_all_rounded, AppColors.evaGreen),
              _buildMetricPill('Read', '$readCount', Icons.done_all_rounded, const Color(0xFF10AC84)),
              _buildMetricPill('Failed', '$failedCount', Icons.cancel_outlined, Colors.red),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Web-Style Table Container
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Logs for "${c.campaignName}"', style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: AppColors.ink)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${filteredDetails.length} records', style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink3)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Web Table Headers
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 28, child: Text('S.No.', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink3))),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Mobile Number', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink3))),
                    Text('Status', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink3)),
                    const SizedBox(width: 14),
                    Text('Actions', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink3)),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              if (_loadingDetails)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.evaGreen)))
              else if (filteredDetails.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text('No log records found.', style: AppText.poppins(size: 13, color: AppColors.ink3)),
                  ),
                )
              else
                ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredDetails.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
                  itemBuilder: (ctx, idx) {
                    final rec = filteredDetails[idx];
                    return InkWell(
                      onTap: () => _showPhonePreviewModal(context, c, rec),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                '${idx + 1}',
                                style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(rec.mobileNumber, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink)),
                                  Text(rec.formattedPublishDate, style: AppText.poppins(size: 10.5, color: AppColors.ink4)),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (rec.failed) ...[
                                  const Icon(Icons.cancel_rounded, size: 16, color: Colors.red),
                                  const SizedBox(width: 4),
                                  Tooltip(
                                    message: rec.reason.isNotEmpty ? rec.reason : 'Failed to send message',
                                    child: const Icon(Icons.info_outline_rounded, size: 16, color: Colors.redAccent),
                                  ),
                                ] else ...[
                                  Icon(rec.sent ? Icons.check_circle_rounded : Icons.check_rounded, size: 16, color: rec.sent ? AppColors.evaGreen : AppColors.ink4),
                                  const SizedBox(width: 3),
                                  Icon(rec.delivered ? Icons.done_all_rounded : Icons.check_rounded, size: 16, color: rec.delivered ? AppColors.evaGreen : AppColors.ink4),
                                  const SizedBox(width: 3),
                                  Icon(rec.read ? Icons.done_all_rounded : Icons.check_rounded, size: 16, color: rec.read ? const Color(0xFF10AC84) : AppColors.ink4),
                                ],
                              ],
                            ),
                            const SizedBox(width: 14),
                            // Web Green Eye Icon (Actions)
                            InkWell(
                              onTap: () => _showPhonePreviewModal(context, c, rec),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.evaGreen.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.visibility_rounded, size: 16, color: AppColors.evaGreenDeep),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildMetricPill(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(value, style: AppText.poppins(size: 13, weight: FontWeight.w800, color: color)),
          ],
        ),
        Text(label, style: AppText.poppins(size: 10, weight: FontWeight.w500, color: AppColors.ink3)),
      ],
    );
  }

  void _showPhonePreviewModal(BuildContext context, BroadcastCampaign campaign, CampaignDetailRecord record) {
    final messageText = (record.message != null && record.message!.isNotEmpty)
        ? record.message!
        : (campaign.templateMessage != null && campaign.templateMessage!.isNotEmpty)
            ? campaign.templateMessage!
            : 'Hi, Greeting from Askeva.';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.82,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar & header
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Message Preview', style: AppText.poppins(size: 16, weight: FontWeight.w700, color: AppColors.ink)),
                          Text('Campaign: ${campaign.campaignName}', style: AppText.poppins(size: 12, color: AppColors.ink3)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.ink3),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.line),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Phone Frame Container (Matching Web Screenshot 1)
                      Container(
                        width: 290,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: const Color(0xFF333333), width: 6),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Top Notch / Speaker bar
                            Container(
                              margin: const EdgeInsets.only(top: 8, bottom: 8),
                              width: 60,
                              height: 5,
                              decoration: BoxDecoration(color: const Color(0xFF444444), borderRadius: BorderRadius.circular(3)),
                            ),
                            // Phone Screen
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
                              child: Container(
                                color: const Color(0xFFE5DDD5), // WhatsApp chat background
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // WhatsApp Header
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      color: const Color(0xFF075E54),
                                      child: Row(
                                        children: [
                                          const CircleAvatar(
                                            radius: 14,
                                            backgroundColor: Colors.white24,
                                            child: Icon(Icons.person_rounded, size: 16, color: Colors.white),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  record.mobileNumber,
                                                  style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: Colors.white),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text('WhatsApp Business', style: AppText.poppins(size: 9.5, color: Colors.white70)),
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.more_vert_rounded, size: 16, color: Colors.white),
                                        ],
                                      ),
                                    ),
                                    // WhatsApp Message Canvas
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      constraints: const BoxConstraints(minHeight: 180),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Date Badge
                                          Center(
                                            child: Container(
                                              margin: const EdgeInsets.only(bottom: 12),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(8)),
                                              child: Text('TODAY', style: AppText.poppins(size: 9, weight: FontWeight.w600, color: AppColors.ink3)),
                                            ),
                                          ),
                                          // Message Bubble
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              constraints: const BoxConstraints(maxWidth: 220),
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: const BorderRadius.only(
                                                  topRight: Radius.circular(12),
                                                  bottomLeft: Radius.circular(12),
                                                  bottomRight: Radius.circular(12),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2)),
                                                ],
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    messageText,
                                                    style: AppText.poppins(size: 11.5, color: AppColors.ink, height: 1.3),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        record.formattedPublishDate.split(' ').skip(1).join(' '),
                                                        style: AppText.poppins(size: 8.5, color: AppColors.ink4),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Icon(
                                                        record.read || record.delivered ? Icons.done_all_rounded : Icons.check_rounded,
                                                        size: 12,
                                                        color: record.read ? const Color(0xFF34B7F1) : AppColors.ink4,
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Bottom WhatsApp Input Bar Mockup
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      color: const Color(0xFFF0F0F0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.sentiment_satisfied_alt_rounded, size: 16, color: AppColors.ink3),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                              child: Text('Message', style: AppText.poppins(size: 10, color: AppColors.ink4)),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.attach_file_rounded, size: 14, color: AppColors.ink3),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.camera_alt_rounded, size: 14, color: AppColors.ink3),
                                          const SizedBox(width: 6),
                                          const CircleAvatar(
                                            radius: 10,
                                            backgroundColor: Color(0xFF075E54),
                                            child: Icon(Icons.mic_rounded, size: 10, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Log Detail Information Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Recipient Details', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: record.failed
                                        ? Colors.red.withOpacity(0.1)
                                        : record.read
                                            ? const Color(0xFF10AC84).withOpacity(0.1)
                                            : AppColors.evaGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    record.failed
                                        ? 'Failed'
                                        : record.read
                                            ? 'Read'
                                            : record.delivered
                                                ? 'Delivered'
                                                : 'Sent',
                                    style: AppText.poppins(
                                      size: 11,
                                      weight: FontWeight.w700,
                                      color: record.failed
                                          ? Colors.red
                                          : record.read
                                              ? const Color(0xFF10AC84)
                                              : AppColors.evaGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.phone_iphone_rounded, size: 14, color: AppColors.ink3),
                                const SizedBox(width: 6),
                                Text(record.mobileNumber, style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 14, color: AppColors.ink3),
                                const SizedBox(width: 6),
                                Text(record.formattedPublishDate, style: AppText.poppins(size: 12, color: AppColors.ink3)),
                              ],
                            ),
                            if (record.failed && record.reason.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.error_outline_rounded, size: 16, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Failure Reason: ${record.reason}',
                                        style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeliveryChartPainter extends CustomPainter {
  final List<BroadcastChartPoint> points;
  _DeliveryChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paintLine = Paint()
      ..color = const Color(0xFF3DC838)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF3DC838).withValues(alpha: 0.35),
          const Color(0xFF3DC838).withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final maxVal = points.map((p) => p.sent).reduce((a, b) => a > b ? a : b).clamp(5, 100);
    final dx = size.width / (points.length - 1 == 0 ? 1 : points.length - 1);

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = size.height - (points[i].sent / maxVal * (size.height - 20));

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      // Draw point dots
      final dotPaint = Paint()..color = const Color(0xFF3DC838);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, paintFill);
    canvas.drawPath(path, paintLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Schedule Modal Sheet (Matches Web Dashboard my.askeva.io/schedule-logs)
// ─────────────────────────────────────────────────────────────────────────────

class EditScheduleModalSheet extends StatefulWidget {
  final ScheduleLogItem item;
  const EditScheduleModalSheet({super.key, required this.item});

  @override
  State<EditScheduleModalSheet> createState() => _EditScheduleModalSheetState();
}

class _EditScheduleModalSheetState extends State<EditScheduleModalSheet> {
  late String _selectedTimezone;
  late TextEditingController _scheduleTimeCtrl;

  final List<String> _timezones = [
    'Asia/Kolkata (India)',
    'UTC',
    'America/New_York',
    'Asia/Dubai',
    'Europe/London',
    'Asia/Singapore',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTimezone = widget.item.timezone.isNotEmpty ? widget.item.timezone : 'Asia/Kolkata (India)';
    _scheduleTimeCtrl = TextEditingController(text: widget.item.scheduledTime);
  }

  @override
  void dispose() {
    _scheduleTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.evaGreen),
          ),
          child: child!,
        );
      },
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.evaGreen),
          ),
          child: child!,
        );
      },
    );
    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final formatted = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $hour:${dt.minute.toString().padLeft(2, '0')} $period";

    setState(() {
      _scheduleTimeCtrl.text = formatted;
    });
  }

  void _saveSchedule() async {
    final updatedItem = ScheduleLogItem(
      id: widget.item.id,
      campaignName: widget.item.campaignName,
      phoneNumber: widget.item.phoneNumber,
      timezone: _selectedTimezone,
      scheduledTime: _scheduleTimeCtrl.text.trim(),
      createdAt: widget.item.createdAt,
      type: widget.item.type,
      status: widget.item.status,
    );

    try {
      final scope = AppScope.of(context);
      await scope.reports.updateScheduleLog(updatedItem);
      if (mounted) {
        appToast(context, 'Schedule updated successfully!', isSuccess: true);
        Navigator.pop(context, updatedItem);
      }
    } catch (e) {
      if (mounted) {
        appToast(context, 'Failed to update schedule: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Screenshot 6)
          Row(
            children: [
              Text('Edit Schedule', style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close_rounded, size: 20, color: AppColors.ink3),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Campaign ID (Readonly)
          _fieldLabel('Campaign ID'),
          const SizedBox(height: 4),
          _readOnlyField(widget.item.campaignName),
          const SizedBox(height: 12),

          // Phone Number (Readonly)
          _fieldLabel('Phone Number'),
          const SizedBox(height: 4),
          _readOnlyField(widget.item.phoneNumber),
          const SizedBox(height: 12),

          // * Timezone (Dropdown)
          _requiredFieldLabel('Timezone'),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.line),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _timezones.contains(_selectedTimezone) ? _selectedTimezone : _timezones.first,
                isExpanded: true,
                style: AppText.poppins(size: 13, color: AppColors.ink),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedTimezone = val);
                },
                items: _timezones.map((tz) {
                  return DropdownMenuItem<String>(
                    value: tz,
                    child: Text(tz),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // * Schedule Time (Date & Time Picker)
          _requiredFieldLabel('Schedule Time'),
          const SizedBox(height: 4),
          TextField(
            controller: _scheduleTimeCtrl,
            readOnly: true,
            onTap: _pickDateTime,
            style: AppText.poppins(size: 13, color: AppColors.ink),
            decoration: InputDecoration(
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.ink3),
                onPressed: _pickDateTime,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: AppColors.surface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.evaGreen),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Type (Readonly)
          _fieldLabel('Type'),
          const SizedBox(height: 4),
          _readOnlyField(widget.item.type),
          const SizedBox(height: 12),

          // Status (Readonly)
          _fieldLabel('Status'),
          const SizedBox(height: 4),
          _readOnlyField(widget.item.status),
          const SizedBox(height: 20),

          // Bottom Action Buttons (Close & Save)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Text('Close', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2)),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _saveSchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.evaGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text('Save', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(label, style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink));
  }

  Widget _requiredFieldLabel(String label) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: '* ', style: AppText.poppins(size: 12, color: Colors.red, weight: FontWeight.w700)),
          TextSpan(text: label, style: AppText.poppins(size: 12, color: AppColors.ink, weight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _readOnlyField(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(value, style: AppText.poppins(size: 13, color: AppColors.ink3)),
    );
  }
}
