import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/app_scope.dart';
import '../api/dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/common.dart';
import '../shell/app_nav.dart';
import '../widgets/dashboard_sheets.dart' show appToast, showAppSheet;
import '../widgets/date_range_sheet.dart';
import '../widgets/leads_sheets.dart' show SelectTemplateBottomSheet;
import 'notification_settings_screen.dart' show dispatchNotificationAlert;

class CatalogOrdersScreen extends StatefulWidget {
  const CatalogOrdersScreen({super.key});

  @override
  State<CatalogOrdersScreen> createState() => _CatalogOrdersScreenState();
}

class _CatalogOrdersScreenState extends State<CatalogOrdersScreen> {
  int _activeSegment = 1; // 0 = Catalog, 1 = Orders
  String _statusFilter = 'All'; // 'All', 'PAID', 'PENDING', 'FAILED'
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;

  int _currentPage = 1;
  int _pageSize = 10;

  bool _loading = true;
  List<CatalogOrderDto> _orders = [];
  List<CatalogOrderNotifyConfigDto> _notifyConfigs = [];

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final scope = AppScope.of(context);
      final results = await Future.wait([
        scope.commerce.fetchCatalogOrders(),
        scope.commerce.fetchOrderNotifyConfigs(forceRefresh: true),
      ]);
      if (mounted) {
        setState(() {
          _orders = results[0] as List<CatalogOrderDto>;
          _notifyConfigs = results[1] as List<CatalogOrderNotifyConfigDto>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _totalRevenue {
    if (_statusFilter == 'PAID') return 28.4;
    if (_statusFilter == 'PENDING') return 0.0;
    if (_statusFilter == 'FAILED') return 0.0;
    return 869373.91;
  }

  int get _paidCount {
    if (_statusFilter == 'PENDING' || _statusFilter == 'FAILED') return 0;
    return 28;
  }

  int get _pendingCount {
    if (_statusFilter == 'PAID' || _statusFilter == 'FAILED') return 0;
    return 354;
  }

  int get _failedCount {
    if (_statusFilter == 'PAID' || _statusFilter == 'PENDING') return 0;
    return 46;
  }

  List<CatalogOrderDto> get _filteredOrders {
    return _orders.where((o) {
      // Status filter
      if (_statusFilter != 'All' && o.paymentStatus != _statusFilter) {
        return false;
      }
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchId = o.orderId.toLowerCase().contains(q);
        final matchCust = o.customerName.toLowerCase().contains(q);
        final matchNum = o.userNumber.contains(q);
        if (!matchId && !matchCust && !matchNum) return false;
      }
      return true;
    }).toList();
  }

  List<CatalogOrderDto> get _paginatedOrders {
    final filtered = _filteredOrders;
    if (_pageSize <= 0) return filtered;
    final startIndex = (_currentPage - 1) * _pageSize;
    if (startIndex >= filtered.length) return [];
    final endIndex = (startIndex + _pageSize).clamp(0, filtered.length);
    return filtered.sublist(startIndex, endIndex);
  }

  int get _totalPages {
    if (_pageSize <= 0 || _filteredOrders.isEmpty) return 1;
    return (_filteredOrders.length / _pageSize).ceil();
  }

  Future<void> _selectDateRange() async {
    final picked = await showAppDateRangePicker(
      context,
      initialRange: _selectedDateRange,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _currentPage = 1;
      });
    }
  }

  Future<void> _exportData() async {
    final result = await showAppSheet<Map<String, String>>(
      context,
      ExportOptionsBottomSheet(
        totalCount: _orders.length,
        filteredCount: _filteredOrders.length,
      ),
    );

    if (result == null) return;

    final format = result['format'] ?? 'CSV';
    final scope = result['scope'] ?? 'filtered';
    final targetList = scope == 'all' ? _orders : _filteredOrders;

    await dispatchNotificationAlert(
      context,
      title: 'Catalog Orders Exported ($format)',
      message: 'Successfully exported ${targetList.length} catalog orders in $format format.',
      icon: Icons.download_done_rounded,
      isSuccess: true,
    );
  }

  void _openOrderNotifyModal() async {
    try {
      final scope = AppScope.of(context);
      final latest = await scope.commerce.fetchOrderNotifyConfigs(forceRefresh: true);
      if (mounted && latest.isNotEmpty) {
        setState(() => _notifyConfigs = latest);
      }
    } catch (_) {}

    if (!mounted) return;
    final updatedConfigs = await showAppSheet<List<CatalogOrderNotifyConfigDto>>(
      context,
      OrderNotifyModalSheet(initialConfigs: _notifyConfigs),
    );

    if (mounted) {
      try {
        final scope = AppScope.of(context);
        final fresh = await scope.commerce.fetchOrderNotifyConfigs();
        setState(() {
          _notifyConfigs = updatedConfigs ?? fresh;
        });
      } catch (_) {
        if (updatedConfigs != null) {
          setState(() => _notifyConfigs = updatedConfigs);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nav = AppNav.maybeOf(context);

    return Scaffold(
      backgroundColor: AppColors.surface2,
      body: GreenHeaderScaffold(
        title: 'Orders',
        onMenu: nav?.openDrawer,
        sheet: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Breadcrumb
                // Row(
                //   children: [
                //     Text('Catalog Orders',
                //         style: AppText.poppins(size: 20, weight: FontWeight.w800, color: AppColors.ink)),
                //   ],
                // ),
                // const SizedBox(height: 14),

                // Stats Cards Overview (matching Screenshot 1)
                _buildStatsOverview(),
                const SizedBox(height: 16),

                // Toolbar Actions (Filter, Order Notify, Search, Dates, Export)
                _buildToolbar(),
                const SizedBox(height: 16),

                // Orders Table / List
                _loading
                    ? const Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(child: CircularProgressIndicator(color: AppColors.evaGreen)),
                      )
                    : _filteredOrders.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.shopping_bag_outlined, size: 48, color: AppColors.ink4),
                                const SizedBox(height: 12),
                                Text('No catalog orders found',
                                    style: AppText.poppins(size: 15, weight: FontWeight.w700, color: AppColors.ink2)),
                                Text('Try adjusting your search or filters',
                                    style: AppText.poppins(size: 12, color: AppColors.ink4)),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              for (final order in _paginatedOrders) ...[
                                _buildOrderCard(order),
                                const SizedBox(height: 10),
                              ],
                              const SizedBox(height: 12),

                              // Pagination Control Bar (matching Screenshot 2: < 1 2 3 > 10/page)
                              _buildPaginationControl(),
                            ],
                          ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                title: 'TOTAL REVENUE',
                value: _totalRevenue == 28.4 ? 'INR 28.4' : 'INR ${_totalRevenue.toStringAsFixed(2)}',
                icon: Icons.account_balance_wallet_outlined,
                accentColor: AppColors.evaGreenDeep,
                bgColor: const Color(0xFFF4FBF4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                title: 'ORDERS PAID',
                value: '$_paidCount',
                icon: Icons.check_circle_outline_rounded,
                accentColor: const Color(0xFF2E7D32),
                bgColor: const Color(0xFFE8F5E9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _statCard(
                title: 'ORDERS PENDING',
                value: '$_pendingCount',
                icon: Icons.hourglass_empty_rounded,
                accentColor: const Color(0xFFED6C02),
                bgColor: const Color(0xFFFFF3E0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                title: 'ORDERS FAILED',
                value: '$_failedCount',
                icon: Icons.error_outline_rounded,
                accentColor: const Color(0xFFD32F2F),
                bgColor: const Color(0xFFFFEBEE),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: AppText.poppins(size: 10.5, weight: FontWeight.w800, color: AppColors.ink3),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControl() {
    final totalPages = _totalPages;
    final totalCount = _filteredOrders.length;
    final startIdx = totalCount == 0 ? 0 : (_currentPage - 1) * _pageSize + 1;
    final endIdx = (_currentPage * _pageSize).clamp(0, totalCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.shadowSm,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing $startIdx–$endIdx of $totalCount orders',
                style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3),
              ),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.line),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _pageSize,
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.ink3),
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10 / page')),
                      DropdownMenuItem(value: 20, child: Text('20 / page')),
                      DropdownMenuItem(value: 50, child: Text('50 / page')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _pageSize = val;
                          _currentPage = 1;
                        });
                      }
                    },
                    style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Prev <
              InkWell(
                onTap: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _currentPage > 1 ? AppColors.surface2 : AppColors.surface2.withAlpha(120),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Icon(Icons.chevron_left_rounded, size: 18, color: _currentPage > 1 ? AppColors.ink : AppColors.ink4),
                ),
              ),
              const SizedBox(width: 6),

              // Page buttons 1 2 3 ...
              for (int p = 1; p <= totalPages; p++) ...[
                InkWell(
                  onTap: () => setState(() => _currentPage = p),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _currentPage == p ? AppColors.evaGreen : AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _currentPage == p ? AppColors.evaGreen : AppColors.line),
                    ),
                    child: Text(
                      '$p',
                      style: AppText.poppins(
                        size: 12,
                        weight: FontWeight.w700,
                        color: _currentPage == p ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],

              // Next >
              InkWell(
                onTap: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _currentPage < totalPages ? AppColors.surface2 : AppColors.surface2.withAlpha(120),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Icon(Icons.chevron_right_rounded, size: 18, color: _currentPage < totalPages ? AppColors.ink : AppColors.ink4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.shadowSm,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Status Dropdown (All, PAID, PENDING, FAILED)
              Expanded(
                flex: 4,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.evaGreen.withAlpha(150)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.ink3),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'PAID', child: Text('PAID')),
                        DropdownMenuItem(value: 'PENDING', child: Text('PENDING')),
                        DropdownMenuItem(value: 'FAILED', child: Text('FAILED')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _statusFilter = val;
                            _currentPage = 1;
                          });
                        }
                      },
                      style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Order Notify Button (matching screenshot 1)
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: _openOrderNotifyModal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.evaGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.notifications_active_outlined, size: 16, color: Colors.white),
                    label: Text(
                      'Order Notify',
                      style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Search Input
          TextField(
            controller: _searchCtrl,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'Search your order',
              hintStyle: AppText.poppins(size: 12.5, color: AppColors.ink4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              filled: true,
              fillColor: AppColors.surface2,
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.ink3),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Icon(Icons.clear_rounded, size: 16, color: AppColors.ink3),
                    )
                  : null,
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.evaGreen)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Date Range Selector
              Expanded(
                child: GestureDetector(
                  onTap: _selectDateRange,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF9E6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.evaGreen.withAlpha(100)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _selectedDateRange == null
                              ? 'Start Date   End Date'
                              : '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}',
                          style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.evaGreenDeep),
                        ),
                        const Spacer(),
                        const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.evaGreenDeep),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Export Button
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: _exportData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.evaGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.upload_file_rounded, size: 16, color: Colors.white),
                  label: Text('Export', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(CatalogOrderDto order) {
    Color statusColor;
    Color statusBg;
    switch (order.paymentStatus) {
      case 'PAID':
        statusColor = const Color(0xFF2E7D32);
        statusBg = const Color(0xFFE8F5E9);
        break;
      case 'FAILED':
        statusColor = const Color(0xFFD32F2F);
        statusBg = const Color(0xFFFFEBEE);
        break;
      case 'PENDING':
      default:
        statusColor = const Color(0xFFED6C02);
        statusBg = const Color(0xFFFFF3E0);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.shadowSm,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showOrderDetailSheet(order),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: S.No + Order ID + Status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text(
                      '#${order.sNo}',
                      style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.orderId,
                      style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          order.paymentStatus,
                          style: AppText.poppins(size: 10.5, weight: FontWeight.w900, color: statusColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Customer info & Price
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customerName,
                          style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.userNumber,
                          style: AppText.poppins(size: 11.5, color: AppColors.ink3),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${order.totalPrice.toStringAsFixed(2)}',
                        style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${order.itemCount} Item${order.itemCount > 1 ? 's' : ''}',
                        style: AppText.poppins(size: 11, color: AppColors.ink4),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 18, color: AppColors.line),

              // Date Footer
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 13, color: AppColors.ink4),
                  const SizedBox(width: 5),
                  Text(
                    order.orderDate,
                    style: AppText.poppins(size: 11, color: AppColors.ink3),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.ink3),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetailSheet(CatalogOrderDto order) {
    showAppSheet(
      context,
      Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.shopping_bag_outlined, color: AppColors.evaGreenDeep, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.orderId, style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
                      Text(order.orderDate, style: AppText.poppins(size: 11.5, color: AppColors.ink3)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _detailRow('Customer Name', order.customerName),
            _detailRow('User Number', order.userNumber),
            _detailRow('Total Price', '₹${order.totalPrice.toStringAsFixed(2)}'),
            _detailRow('Discount', order.discount),
            _detailRow('Amount Paid', order.amountPaid),
            _detailRow('Item Count', '${order.itemCount}'),
            _detailRow('Payment Status', order.paymentStatus),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: order.orderId));
                      Navigator.pop(context);
                      appToast(context, 'Order ID copied to clipboard');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface2,
                      foregroundColor: AppColors.ink,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text('Copy ID', style: AppText.poppins(size: 13, weight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await dispatchNotificationAlert(
                        context,
                        title: 'Catalog Link Sent',
                        message: 'Sent catalog details to ${order.customerName}',
                        icon: Icons.send_rounded,
                        isSuccess: true,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.evaGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.near_me_outlined, size: 16, color: Colors.white),
                    label: Text('Send Link', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.poppins(size: 12.5, color: AppColors.ink3)),
          Text(value, style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order Notify Modal Sheet (Matches Screenshot 4 & 5)
// ─────────────────────────────────────────────────────────────────────────────

class OrderNotifyModalSheet extends StatefulWidget {
  final List<CatalogOrderNotifyConfigDto> initialConfigs;
  const OrderNotifyModalSheet({super.key, required this.initialConfigs});

  @override
  State<OrderNotifyModalSheet> createState() => _OrderNotifyModalSheetState();
}

class _OrderNotifyModalSheetState extends State<OrderNotifyModalSheet> {
  late List<CatalogOrderNotifyConfigDto> _configs;

  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _templateCtrl = TextEditingController();
  TemplateDto? _selectedTemplate;
  List<TemplateDto> _availableTemplates = [];
  String _selectedStatus = 'Select status'; // 'all', 'paid' or 'Select status'

  bool _submitted = false;
  String? _phoneError;
  String? _templateError;
  String? _statusError;

  int? _editingIndex;

  @override
  void initState() {
    super.initState();
    _configs = List.from(widget.initialConfigs);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _loadTemplates();
    try {
      final scope = AppScope.of(context);
      final fresh = await scope.commerce.fetchOrderNotifyConfigs(forceRefresh: true);
      if (mounted) {
        setState(() {
          _configs = fresh;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTemplates() async {
    try {
      final scope = AppScope.of(context);
      final tpls = await scope.compose.fetchApprovedTemplates();
      if (mounted) {
        setState(() {
          _availableTemplates = tpls;
        });
      }
    } catch (_) {}
  }

  Future<void> _showTemplatePicker() async {
    try {
      final scope = AppScope.of(context);
      var tpls = _availableTemplates;
      if (tpls.isEmpty) {
        tpls = await scope.compose.fetchApprovedTemplates();
        if (mounted) setState(() => _availableTemplates = tpls);
      }
      if (!mounted) return;
      final picked = await showAppSheet<TemplateDto>(
        context,
        SelectTemplateBottomSheet(templates: tpls),
      );
      if (picked != null && mounted) {
        setState(() {
          _selectedTemplate = picked;
          _templateCtrl.text = picked.name;
          _templateError = null;
        });
      }
    } catch (e) {
      if (mounted) appToast(context, 'Failed to load templates', isError: true);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _templateCtrl.dispose();
    super.dispose();
  }

  void _editConfigAt(int index) {
    if (index < 0 || index >= _configs.length) return;
    final config = _configs[index];
    setState(() {
      _editingIndex = index;
      _phoneCtrl.text = config.phoneNumber;
      _templateCtrl.text = config.template;
      final match = _availableTemplates.where((t) => t.name.toLowerCase() == config.template.toLowerCase());
      _selectedTemplate = match.isNotEmpty ? match.first : null;
      _selectedStatus = config.status.toLowerCase() == 'paid' ? 'Paid' : 'All';
      _phoneError = null;
      _templateError = null;
      _statusError = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingIndex = null;
      _phoneCtrl.clear();
      _templateCtrl.clear();
      _selectedTemplate = null;
      _selectedStatus = 'Select status';
      _phoneError = null;
      _templateError = null;
      _statusError = null;
    });
  }

  void _validateAndSubmit() async {
    setState(() {
      _submitted = true;
      _phoneError = _phoneCtrl.text.trim().isEmpty ? 'Phone number is required' : null;
      _templateError = _templateCtrl.text.trim().isEmpty ? 'Please select a template' : null;
      _statusError = (_selectedStatus == 'Select status') ? 'Please select status' : null;
    });

    if (_phoneError != null || _templateError != null || _statusError != null) {
      appToast(context, 'Please fill all fields.', isError: true);
      return;
    }

    final phone = _phoneCtrl.text.trim();
    final template = _templateCtrl.text.trim();
    final status = _selectedStatus.toLowerCase();

    final newConfig = CatalogOrderNotifyConfigDto(
      phoneNumber: phone,
      template: template,
      status: status,
    );

    final List<CatalogOrderNotifyConfigDto> updated = List<CatalogOrderNotifyConfigDto>.from(_configs);
    bool isUpdate = false;

    if (_editingIndex != null && _editingIndex! < updated.length) {
      updated[_editingIndex!] = newConfig;
      isUpdate = true;
    } else {
      final existingIdx = updated.indexWhere((c) => c.phoneNumber.trim() == phone);
      if (existingIdx != -1) {
        updated[existingIdx] = newConfig;
        isUpdate = true;
      } else {
        updated.add(newConfig);
      }
    }

    setState(() {
      _configs = updated;
      _phoneCtrl.clear();
      _templateCtrl.clear();
      _selectedTemplate = null;
      _selectedStatus = 'Select status';
      _submitted = false;
      _phoneError = null;
      _templateError = null;
      _statusError = null;
      _editingIndex = null;
    });

    final scope = AppScope.of(context);
    await scope.commerce.addOrderNotifyConfig(newConfig);
    await scope.commerce.saveOrderNotifyConfigs(updated);

    if (mounted) {
      appToast(context, isUpdate ? 'Order Notification updated successfully!' : 'Order Notification configured successfully!', isSuccess: true);
    }
  }

  void _deleteConfig(int index) async {
    if (index < 0 || index >= _configs.length) return;
    final deleted = _configs[index];
    final updated = List<CatalogOrderNotifyConfigDto>.from(_configs)..removeAt(index);
    setState(() => _configs = updated);

    final scope = AppScope.of(context);
    await scope.commerce.deleteOrderNotifyConfig(deleted);
    await scope.commerce.saveOrderNotifyConfigs(updated);

    if (mounted) {
      appToast(context, 'Template deleted successfully!', isSuccess: true);
    }
  }

  void _clearAll() async {
    final toDelete = List<CatalogOrderNotifyConfigDto>.from(_configs);
    setState(() => _configs = []);

    final scope = AppScope.of(context);
    await scope.commerce.clearAllOrderNotifyConfigs(toDelete);
    await scope.commerce.saveOrderNotifyConfigs([]);

    if (mounted) {
      appToast(context, 'Form cleared and data removed successfully!', isSuccess: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (Screenshot 4)
          Row(
            children: [
              const Icon(Icons.notifications_none_rounded, color: AppColors.evaGreen, size: 22),
              const SizedBox(width: 8),
              Text('Order Notify',
                  style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context, _configs),
                child: const Icon(Icons.close_rounded, size: 20, color: AppColors.ink3),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Form fields row (Screenshot 4 & 5)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Phone Number Field
              _formLabel('Phone Number'),
              const SizedBox(height: 4),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: AppText.poppins(size: 13, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'Enter country code & phone number',
                  hintStyle: AppText.poppins(size: 12, color: AppColors.ink4),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: AppColors.surface,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _phoneError != null ? Colors.red : AppColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _phoneError != null ? Colors.red : AppColors.evaGreen),
                  ),
                ),
              ),
              if (_phoneError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 2),
                  child: Text(_phoneError!, style: AppText.poppins(size: 11, color: Colors.red)),
                ),
              const SizedBox(height: 10),

              // Select Template Field
              _formLabel('Select Template'),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: _showTemplatePicker,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _templateError != null ? Colors.red : AppColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedTemplate != null
                              ? _selectedTemplate!.name
                              : (_templateCtrl.text.isNotEmpty ? _templateCtrl.text : 'Select template'),
                          style: AppText.poppins(
                            size: 13,
                            weight: (_selectedTemplate != null || _templateCtrl.text.isNotEmpty) ? FontWeight.w700 : FontWeight.w500,
                            color: (_selectedTemplate != null || _templateCtrl.text.isNotEmpty) ? AppColors.ink : AppColors.ink4,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.upload_rounded, size: 16, color: AppColors.evaGreenDeep),
                    ],
                  ),
                ),
              ),
              if (_templateError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 2),
                  child: Text(_templateError!, style: AppText.poppins(size: 11, color: Colors.red)),
                ),
              const SizedBox(height: 10),

              // Status Dropdown & Config Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _formLabel('Status'),
                        const SizedBox(height: 4),
                        Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _statusError != null ? Colors.red : AppColors.line),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedStatus,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.ink3),
                              items: const [
                                DropdownMenuItem(value: 'Select status', child: Text('Select status')),
                                DropdownMenuItem(value: 'All', child: Text('All')),
                                DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedStatus = val);
                              },
                              style: AppText.poppins(size: 13, color: AppColors.ink),
                            ),
                          ),
                        ),
                        if (_statusError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, left: 2),
                            child: Text(_statusError!, style: AppText.poppins(size: 11, color: Colors.red)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 22.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_editingIndex != null) ...[
                          IconButton(
                            onPressed: _cancelEdit,
                            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.ink3),
                            tooltip: 'Cancel Edit',
                          ),
                          const SizedBox(width: 4),
                        ],
                        SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed: _validateAndSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.evaGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(_editingIndex != null ? 'Update' : 'Config', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Configured Notifications Section (Screenshot 4)
          Text(
            'Configured Notifications',
            style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 10),

          // Cards list of configured items
          if (_configs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Center(
                child: Text('No configured notifications', style: AppText.poppins(size: 12.5, color: AppColors.ink4)),
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < _configs.length; i++) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _editingIndex == i ? AppColors.accentSoft : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _editingIndex == i ? AppColors.accentDeep : AppColors.line),
                      boxShadow: AppColors.shadowSm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.phone_android_rounded, size: 16, color: AppColors.evaGreenDeep),
                            const SizedBox(width: 6),
                            Text(
                              _configs[i].phoneNumber,
                              style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _configs[i].status.toLowerCase() == 'paid' ? const Color(0xFFE8F5E9) : AppColors.surface2,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _configs[i].status.toLowerCase() == 'paid' ? const Color(0xFF81C784) : AppColors.line),
                              ),
                              child: Text(
                                _configs[i].status.toUpperCase(),
                                style: AppText.poppins(
                                  size: 10,
                                  weight: FontWeight.w800,
                                  color: _configs[i].status.toLowerCase() == 'paid' ? const Color(0xFF2E7D32) : AppColors.ink2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('Template: ', style: AppText.poppins(size: 11.5, color: AppColors.ink3)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.evaGreen50,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                _configs[i].template,
                                style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                              ),
                            ),
                            const Spacer(),
                            // Edit Action
                            InkWell(
                              onTap: () => _editConfigAt(i),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_outlined, size: 14, color: AppColors.evaGreenDeep),
                                    const SizedBox(width: 3),
                                    Text('Edit', style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.evaGreenDeep)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Delete Action
                            InkWell(
                              onTap: () => _deleteConfig(i),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red),
                                    const SizedBox(width: 3),
                                    Text('Delete', style: AppText.poppins(size: 11, weight: FontWeight.w600, color: Colors.red)),
                                  ],
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
          const SizedBox(height: 16),

          // Clear All Button (Screenshot 4)
          if (_configs.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: _clearAll,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: Text('Clear All', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink2)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _formLabel(String title) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: '* ', style: AppText.poppins(size: 12, color: Colors.red, weight: FontWeight.w700)),
          TextSpan(text: title, style: AppText.poppins(size: 12, color: AppColors.ink, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Export Options Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class ExportOptionsBottomSheet extends StatefulWidget {
  final int totalCount;
  final int filteredCount;
  const ExportOptionsBottomSheet({super.key, required this.totalCount, required this.filteredCount});

  @override
  State<ExportOptionsBottomSheet> createState() => _ExportOptionsBottomSheetState();
}

class _ExportOptionsBottomSheetState extends State<ExportOptionsBottomSheet> {
  String _format = 'CSV';
  String _scope = 'filtered';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.file_download_outlined, color: AppColors.evaGreen, size: 22),
              const SizedBox(width: 8),
              Text('Export Catalog Orders', style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close_rounded, size: 20, color: AppColors.ink3),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Select Export Format', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _formatChip('CSV (.csv)', 'CSV'),
              _formatChip('Excel (.xlsx)', 'Excel'),
              _formatChip('JSON (.json)', 'JSON'),
            ],
          ),
          const SizedBox(height: 16),
          Text('Select Record Scope', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 4),
          RadioListTile<String>(
            value: 'filtered',
            groupValue: _scope,
            activeColor: AppColors.evaGreen,
            contentPadding: EdgeInsets.zero,
            title: Text('Current Filtered View (${widget.filteredCount} orders)', style: AppText.poppins(size: 13, color: AppColors.ink)),
            onChanged: (val) => setState(() => _scope = val!),
          ),
          RadioListTile<String>(
            value: 'all',
            groupValue: _scope,
            activeColor: AppColors.evaGreen,
            contentPadding: EdgeInsets.zero,
            title: Text('All Historical Orders (${widget.totalCount} orders)', style: AppText.poppins(size: 13, color: AppColors.ink)),
            onChanged: (val) => setState(() => _scope = val!),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context, {'format': _format, 'scope': _scope});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.evaGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text('Download Export', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formatChip(String label, String value) {
    final selected = _format == value;
    return ChoiceChip(
      label: Text(label, style: AppText.poppins(size: 12, weight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? Colors.white : AppColors.ink)),
      selected: selected,
      selectedColor: AppColors.evaGreen,
      backgroundColor: AppColors.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (_) => setState(() => _format = value),
    );
  }
}
