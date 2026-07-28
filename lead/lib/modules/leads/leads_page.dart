import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../../theme/app_colors.dart';
import '../../services/leads_service.dart';
import 'lead_details_page.dart';
import 'widgets/add_lead_modal.dart';
import 'import_issues_screen.dart';
import 'widgets/import_leads_modal.dart';
import 'widgets/lead_filter_modal.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  String _viewMode = 'List';
  String _searchQuery = '';
  String? _statusFilter;
  String? _sourceFilter;
  String? _companyFilter;
  String? _assignedFilter;
  DateTimeRange? _dateRange;
  int _currentPage = 1;
  int _pageSize = 10;
  static const List<int> _pageSizeOptions = [10, 20, 50, 100];

  // Selection Mode
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  String? _pendingAction; // 'delete' or 'export'
  List<String> _currentPageItemIds = []; // ids on current page for Select all

  // Options for filter

  late Future<Map<String, dynamic>> _future;
  final TextEditingController _searchController = TextEditingController();
  int _filterVersion = 0; // Incremented on Apply so list always refreshes for new filters

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadData();
  }

  void _loadData() {
    if (kDebugMode) {
      debugPrint('[LeadsPage._loadData] FILTERS (client-side): '
          'q="$_searchQuery", status=$_statusFilter, source=$_sourceFilter, '
          'company=$_companyFilter, assignedTo=$_assignedFilter, '
          'dateRange=${_dateRange != null ? "${_dateRange!.start} to ${_dateRange!.end}" : null}, '
          'page=$_currentPage, limit=$_pageSize');
    }
    // Fetch all leads from backend (no filter params), then filter and paginate in Dart.
    _future = _fetchAllAndFilterLeads();
  }

  /// Returns full filtered list (no pagination slice). UI slices by _currentPage/_pageSize.
  Future<Map<String, dynamic>> _fetchAllAndFilterLeads() async {
    final all = await LeadsService.fetchAllLeads();
    final filtered = _applyFilters(all);
    final total = filtered.length;
    if (kDebugMode) {
      debugPrint('[LeadsPage] client-side filtered: total=$total');
    }
    return {'items': filtered, 'total': total};
  }

  List<dynamic> _applyFilters(List<dynamic> leads) {
    var list = List<dynamic>.from(leads);

    // Search q: name, email, fullMobile, mobile, company / company.name (case insensitive)
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((lead) {
        final name = (lead['name'] ?? '').toString().toLowerCase();
        final email = (lead['email'] ?? '').toString().toLowerCase();
        final fullMobile = (lead['fullMobile'] ?? '').toString().toLowerCase();
        final mobile = (lead['mobile'] ?? '').toString().toLowerCase();
        final company = lead['company'];
        final companyStr = company is String
            ? company.toLowerCase()
            : (company is Map ? (company['name'] ?? '').toString().toLowerCase() : '');
        return name.contains(q) ||
            email.contains(q) ||
            fullMobile.contains(q) ||
            mobile.contains(q) ||
            companyStr.contains(q);
      }).toList();
    }

    // Status (match "New Lead"/"New", and "Converted"/isConverted - same as web)
    if (_statusFilter != null && _statusFilter!.trim().isNotEmpty) {
      final s = _statusFilter!.trim();
      list = list.where((lead) {
        final leadStatus = (lead['status'] ?? '').toString();
        final isConverted = lead['isConverted'] == true || lead['isCoverted'] == true;
        if (s == 'Converted') return leadStatus == 'Converted' || isConverted;
        return leadStatus == s || (s == 'New Lead' && leadStatus == 'New');
      }).toList();
    }

    // Source
    if (_sourceFilter != null && _sourceFilter!.trim().isNotEmpty) {
      final v = _sourceFilter!.trim();
      list = list.where((lead) => (lead['source'] ?? '').toString() == v).toList();
    }

    // Company (string or company.name)
    if (_companyFilter != null && _companyFilter!.trim().isNotEmpty) {
      final v = _companyFilter!.trim().toLowerCase();
      list = list.where((lead) {
        final company = lead['company'];
        if (company == null) return false;
        if (company is String) return company.toLowerCase() == v;
        if (company is Map) {
          final name = (company['name'] ?? '').toString().toLowerCase();
          return name == v;
        }
        return false;
      }).toList();
    }

    // AssignedTo (id string or assignedTo._id / assignedTo.id / assigned / assignedAgent)
    if (_assignedFilter != null && _assignedFilter!.trim().isNotEmpty) {
      final id = _assignedFilter!.trim();
      list = list.where((lead) {
        final at = lead['assignedTo'];
        if (at == id) return true;
        if (at is Map) {
          if ((at['_id'] ?? at['id'])?.toString() == id) return true;
        }
        if ((lead['assigned'] ?? '').toString() == id) return true;
        if ((lead['assignedAgent'] ?? '').toString() == id) return true;
        return false;
      }).toList();
    }

    // Date range: createdAt >= start 00:00, <= end 23:59
    if (_dateRange != null) {
      final startDay = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
      final endDay = DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
        23,
        59,
        59,
        999,
      );
      list = list.where((lead) {
        final created = lead['createdAt'];
        if (created == null) return false;
        DateTime? dt;
        if (created is String) {
          dt = DateTime.tryParse(created);
        } else if (created is int) {
          dt = DateTime.fromMillisecondsSinceEpoch(created);
        }
        if (dt == null) return false;
        return !dt.isBefore(startDay) && !dt.isAfter(endDay);
      }).toList();
    }

    // Sort by createdAt descending (same as backend)
    list.sort((a, b) {
      final ca = _parseCreatedAt(a['createdAt']);
      final cb = _parseCreatedAt(b['createdAt']);
      return cb.compareTo(ca);
    });
    return list;
  }

  DateTime _parseCreatedAt(dynamic v) {
    if (v == null) return DateTime(0);
    if (v is String) return DateTime.tryParse(v) ?? DateTime(0);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime(0);
  }

  Future<void> _onRefresh() async {
    _loadData();
    setState(() {});
    await _future;
  }

  void _importLeads() {
    showDialog(
      context: context,
      builder: (dialogContext) => ImportLeadsModal(
        onSuccess: () {
          Navigator.of(dialogContext).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Leads imported and saved successfully')),
          );
          setState(() => _loadData());
        },
        onDuplicates: (duplicates) {
          Navigator.of(dialogContext).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ImportIssuesScreen(
                duplicates: duplicates,
                onImportAgain: () => setState(() => _loadData()),
              ),
            ),
          ).then((_) => setState(() => _loadData()));
        },
      ),
    );
  }

  Future<void> _showExportConfirmPopup() async {
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.download_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            const Text('Export leads?'),
          ],
        ),
        content: Text(
          'Export $count selected lead${count == 1 ? '' : 's'} to CSV?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.download, size: 20),
            label: const Text('Export'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _exportLeads();
    }
  }

  Future<void> _exportLeads() async {
    final rawIds = _selectionMode && _selectedIds.isNotEmpty
        ? _selectedIds.toList()
        : null;
    final ids = rawIds != null ? _validLeadIds(rawIds) : null;
    // Log for debugging export / leadId format issues
    debugPrint('[Leads export] rawIds: $rawIds');
    debugPrint('[Leads export] valid ids: $ids');
    if (ids != null && ids.length != (rawIds?.length ?? 0)) {
      debugPrint(
          '[Leads export] filtered out ${(rawIds!.length - ids.length)} invalid id(s)');
    }
    if (rawIds != null && rawIds.isNotEmpty && (ids == null || ids.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No valid lead IDs to export (invalid ID format)')),
        );
      }
      return;
    }
    try {
      final filePath = await LeadsService.exportLeadsAsCsv(ids: ids);
      _exitSelectionMode();
      if (mounted) {
        await OpenFilex.open(filePath);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ids != null
                  ? 'Exported ${ids.length} leads'
                  : 'Exported all leads',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteSelectedLeads() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_rounded, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 12),
            const Text('Delete leads?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete $count lead${count == 1 ? '' : 's'}? This cannot be undone.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            icon: const Icon(Icons.delete, size: 20),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final ids = _validLeadIds(_selectedIds.toList());
        if (ids.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No valid lead IDs to delete')),
            );
          }
          return;
        }
        await LeadsService.deleteLeads(ids);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leads deleted successfully')),
        );
        _exitSelectionMode();
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  void _enterSelectionMode(String action) {
    setState(() {
      _selectionMode = true;
      _pendingAction = action;
      _selectedIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Select leads to $action')),
    );
  }

  /// Enter selection mode without a pending action (e.g. after long press).
  /// User then taps Export or Delete icon to see popup.
  void _enterSelectionModeWithoutAction() {
    setState(() {
      _selectionMode = true;
      _pendingAction = null;
      _selectedIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Select leads, then tap Export or Delete')),
    );
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _pendingAction = null;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  /// Returns only ids that are valid 24-char hex (MongoDB ObjectId).
  List<String> _validLeadIds(List<String> ids) {
    final hex = RegExp(r'^[a-fA-F0-9]{24}$');
    return ids.where((id) => id.length == 24 && hex.hasMatch(id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _buildFAB(),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              key: ValueKey(
                'v$_filterVersion|$_searchQuery|$_statusFilter|$_sourceFilter|$_companyFilter|$_assignedFilter|'
                '${_dateRange != null ? _dateRange!.start.toIso8601String() : null}|'
                '${_dateRange != null ? _dateRange!.end.toIso8601String() : null}',
              ),
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: Center(child: Text('Error: ${snap.error}')),
                      ),
                    ),
                  );
                }
                final fullList = snap.data?['items'] as List<dynamic>? ?? [];
                final total = snap.data?['total'] as int? ?? fullList.length;
                final totalPages = _pageSize > 0 ? (total / _pageSize).ceil() : 1;
                final start = ((_currentPage - 1) * _pageSize).clamp(0, total);
                final end = (start + _pageSize).clamp(0, total);
                final items = start < end ? fullList.sublist(start, end) : <dynamic>[];

                // Keep current page ids for Select all
                _currentPageItemIds = items
                    .map((e) => (e['_id'] ?? e['id']).toString())
                    .toList();

                if (items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: const Center(child: Text('No leads found')),
                      ),
                    ),
                  );
                }

                Widget mainView;
                if (_viewMode == 'Table') {
                  mainView = _buildTableView(items);
                } else if (_viewMode == 'Kanban')
                  mainView = _buildKanbanView(items);
                else
                  mainView = _buildListView(items);

                final refreshedView = RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: mainView,
                );

                // Pagination above bottom navbar (server-side total)
                final paginationBar = _buildPaginationControls(totalPages, total);
                return Column(
                  children: [
                    Expanded(child: refreshedView),
                    if (paginationBar != null) paginationBar,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Search leads...',
                hintStyle: TextStyle(color: isDark ? cs.onSurface.withOpacity(0.8) : cs.onSurfaceVariant),
                prefixIcon: Icon(Icons.search_rounded, color: isDark ? cs.onSurface.withOpacity(0.8) : cs.onSurfaceVariant, size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.cancel, color: isDark ? cs.onSurface.withOpacity(0.8) : cs.onSurfaceVariant, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _searchQuery = '';
                          setState(() {
                            _currentPage = 1;
                            _loadData();
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) {
                _searchQuery = val.trim();
                setState(() {
                  _currentPage = 1;
                  _loadData();
                });
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_selectionMode) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_currentPageItemIds.isNotEmpty &&
                              _currentPageItemIds.every((id) => _selectedIds.contains(id))) {
                            _selectedIds.removeAll(_currentPageItemIds);
                          } else {
                            _selectedIds.addAll(_currentPageItemIds);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _currentPageItemIds.isNotEmpty &&
                                  _currentPageItemIds.every((id) => _selectedIds.contains(id)),
                              onChanged: (_) {
                                setState(() {
                                  if (_currentPageItemIds.isNotEmpty &&
                                      _currentPageItemIds.every((id) => _selectedIds.contains(id))) {
                                    _selectedIds.removeAll(_currentPageItemIds);
                                  } else {
                                    _selectedIds.addAll(_currentPageItemIds);
                                  }
                                });
                              },
                            ),
                            Text('Select all', style: TextStyle(fontSize: 14, color: cs.onSurface)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel Selection',
                    onPressed: _exitSelectionMode,
                  ),
                  const SizedBox(width: 8),
                  // Long-press case only: Export & Delete after Select all, before Filter
                  if (_pendingAction == null) ...[
                    _buildExportIconButton(),
                    const SizedBox(width: 8),
                    _buildDeleteIconButton(),
                    const SizedBox(width: 8),
                  ],
                ],
                // Filter
                IconButton.filledTonal(
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Filter',
                  onPressed: _showFilterModal,
                ),
                const SizedBox(width: 8),
                // Date Filter
                IconButton.filledTonal(
                  icon: const Icon(Icons.calendar_today),
                  tooltip: 'Date Range',
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      initialDateRange: _dateRange,
                    );
                    if (picked != null && mounted) {
                      setState(() {
                        _dateRange = picked;
                        _currentPage = 1;
                        _loadData();
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),

                // Refresh Icon (Clear Filters)
                IconButton.filledTonal(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh & Clear',
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _dateRange = null;
                      _searchQuery = '';
                      _assignedFilter = null;
                      _companyFilter = null;
                      _statusFilter = null;
                      _sourceFilter = null;
                      _currentPage = 1;
                      _loadData();
                    });
                  },
                ),

                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.upload_file),
                  tooltip: 'Import CSV',
                  onPressed: _importLeads,
                ),
                // Export after Import (Delete icon hidden next to view icons)
                if (!_selectionMode || _pendingAction != null) ...[
                  const SizedBox(width: 8),
                  _buildExportIconButton(),
                ],
                const SizedBox(width: 16),
                // List view
                IconButton.filledTonal(
                  icon: const Icon(Icons.list),
                  tooltip: 'List view',
                  onPressed: () {
                    setState(() => _viewMode = 'List');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Modal for global filters
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LeadFilterModal(
        initialDateRange: _dateRange,
        initialStatus: _statusFilter,
        initialSource: _sourceFilter,
        initialCompany: _companyFilter,
        initialAssignedTo: _assignedFilter,
        onApply: ({dateRange, status, source, company, assignedTo}) {
          setState(() {
            _dateRange = dateRange;
            _statusFilter = status?.trim().isNotEmpty == true ? status!.trim() : null;
            _sourceFilter = source?.trim().isNotEmpty == true ? source!.trim() : null;
            _companyFilter = company?.trim().isNotEmpty == true ? company!.trim() : null;
            _assignedFilter = assignedTo?.trim().isNotEmpty == true ? assignedTo!.trim() : null;
            _currentPage = 1;
            _filterVersion += 1; // Force FutureBuilder to refresh and show only filtered leads
            _loadData();
          });
        },
      ),
    );
  }

  Widget _buildFAB() {
    // Only show FAB when user tapped Export/Delete icon first (pending action set).
    if (_selectionMode && _pendingAction != null) {
      return FloatingActionButton.extended(
        onPressed: _pendingAction == 'delete'
            ? _deleteSelectedLeads
            : _exportLeads,
        backgroundColor: _pendingAction == 'delete'
            ? Colors.red
            : Theme.of(context).colorScheme.primary,
        icon: Icon(_pendingAction == 'delete' ? Icons.delete : Icons.download),
        label: Text(
          'Confirm ${_pendingAction == 'delete' ? 'Delete' : 'Export'} (${_selectedIds.length})',
        ),
      );
    }
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddLeadModal(
              onSuccess: () {
                setState(() {
                  _loadData();
                });
              },
            ),
          ),
        );
      },
      tooltip: 'Add Lead',
      child: const Icon(Icons.add),
    );
  }

  Widget _buildExportIconButton() {
    return IconButton.filledTonal(
      icon: Icon(
        Icons.download,
        color: _selectionMode && (_pendingAction == 'export' || _selectedIds.isNotEmpty)
            ? Colors.blue
            : null,
      ),
      tooltip: 'Export',
      onPressed: () {
        if (!_selectionMode) {
          _enterSelectionMode('export');
          return;
        }
        if (_pendingAction == 'export') {
          _exportLeads();
          return;
        }
        if (_pendingAction == null && _selectedIds.isNotEmpty) {
          _showExportConfirmPopup();
          return;
        }
        if (_pendingAction == null && _selectedIds.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select leads to export')),
          );
        }
      },
    );
  }

  Widget _buildDeleteIconButton() {
    return IconButton.filledTonal(
      icon: Icon(
        Icons.delete,
        color: _selectionMode && (_pendingAction == 'delete' || _selectedIds.isNotEmpty)
            ? Colors.red
            : null,
      ),
      tooltip: 'Delete',
      onPressed: () {
        if (!_selectionMode) {
          _enterSelectionMode('delete');
          return;
        }
        if (_pendingAction == 'delete') {
          _deleteSelectedLeads();
          return;
        }
        if (_pendingAction == null && _selectedIds.isNotEmpty) {
          _deleteSelectedLeads();
          return;
        }
        if (_pendingAction == null && _selectedIds.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select leads to delete')),
          );
        }
      },
    );
  }

  Widget _buildListView(List<dynamic> items) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = cs.surface;
    final borderColor = isDark ? cs.outline.withOpacity(0.5) : Colors.grey.shade300;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: items.length,
      itemBuilder: (context, idx) {
        final it = items[idx];
        final id = (it['_id'] ?? it['id']).toString();
        final name = it['name']?.toString() ?? 'Unknown';
        final companyName = it['company'] is Map
            ? (it['company']['name'] ?? 'No Company')
            : (it['company']?.toString() ?? 'No Company');
        // Backend may return assignedTo as Map (populated) or as id string; also check assigned/assignedAgent
        final bool hasAssignedId = (it['assignedTo'] is Map && ((it['assignedTo']['_id'] ?? it['assignedTo']['id']) != null)) ||
            (it['assignedTo'] != null && it['assignedTo'] is! Map && it['assignedTo'].toString().trim().isNotEmpty) ||
            (it['assigned'] != null && it['assigned'].toString().trim().isNotEmpty) ||
            (it['assignedAgent'] != null && it['assignedAgent'].toString().trim().isNotEmpty);
        final assignedName = (it['assignedTo'] is Map)
            ? (it['assignedTo']['name'] ?? it['assignedTo']['username'] ?? it['assignedTo']['email'] ?? 'Agent Assigned')
            : (hasAssignedId ? 'Agent Assigned' : 'No Agent Assigned');
        final hasAssignedAgent = hasAssignedId;
        final isConverted = it['isConverted'] == true || it['isCoverted'] == true;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onLongPress: () {
                if (!_selectionMode) {
                  _enterSelectionModeWithoutAction();
                }
              },
              onTap: _selectionMode
                  ? () => _toggleSelection(id)
                  : () => _openDetails(it),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectionMode)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Checkbox(
                              value: _selectedIds.contains(id),
                              onChanged: (v) => _toggleSelection(id),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            (name.isNotEmpty) ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.grey.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                companyName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? cs.onSurface.withOpacity(0.85) : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.more_vert,
                            color: isDark ? cs.onSurface.withOpacity(0.85) : cs.onSurfaceVariant,
                            size: 22,
                          ),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editLead(it);
                            } else if (value == 'delete') {
                              _deleteLead(it);
                            } else if (value == 'template') {
                              _sendTemplate(it);
                            }
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: Colors.blueGrey),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'template',
                              child: Row(
                                children: [
                                  Icon(Icons.send, color: Colors.blueGrey),
                                  SizedBox(width: 8),
                                  Text('Send Template'),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: _selectionMode ? 98 : 62,
                        ),
                        _buildStatusChip(
                          it['status'],
                          isConverted: isConverted,
                        ),
                        const SizedBox(width: 8),
                        _buildAgentCard(
                          assignedName: assignedName,
                          hasAssignedAgent: hasAssignedAgent,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAgentCard({
    required String assignedName,
    required bool hasAssignedAgent,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: hasAssignedAgent
            ? (isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50)
            : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasAssignedAgent
              ? Colors.blue.shade200
              : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasAssignedAgent ? Icons.badge_outlined : Icons.person_off_outlined,
            size: 16,
            color: hasAssignedAgent ? Colors.blue.shade700 : (isDark ? Colors.white70 : Colors.grey.shade600),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              assignedName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableView(List<dynamic> items) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn:
              _selectionMode, // Only show checkboxes in selection mode
          headingRowColor: WidgetStateProperty.all(
            Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withAlpha(100),
          ),
          columns: [
            const DataColumn(
              label: Text(
                'S.No',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const DataColumn(
              label: Text(
                'Name',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const DataColumn(
              label: Text(
                'Company',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const DataColumn(
              label: Text(
                'Mobile',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const DataColumn(
              label: Text(
                'Assigned',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const DataColumn(
              label: Text(
                'Status',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const DataColumn(
              label: Text(
                'Source',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const DataColumn(
              label: Text(
                'Actions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: items.asMap().entries.map((entry) {
            final idx = entry.key;
            final it = entry.value;
            final id = it['_id'] ?? it['id'];
            final sNo = ((_currentPage - 1) * _pageSize) + idx + 1;
            final bool hasAgentId = (it['assignedTo'] is Map && ((it['assignedTo']['_id'] ?? it['assignedTo']['id']) != null)) ||
                (it['assignedTo'] != null && it['assignedTo'] is! Map && it['assignedTo'].toString().trim().isNotEmpty) ||
                (it['assigned'] != null && it['assigned'].toString().trim().isNotEmpty) ||
                (it['assignedAgent'] != null && it['assignedAgent'].toString().trim().isNotEmpty);
            final assigned = it['assignedTo'] is Map
                ? (it['assignedTo']['name'] ?? it['assignedTo']['username'] ?? it['assignedTo']['email'])
                : null;
            final hasAgent = hasAgentId;
            final assignedDisplay = (assigned != null && assigned.toString().trim().isNotEmpty)
                ? assigned.toString()
                : (hasAgent ? 'Agent Assigned' : 'No Agent Assigned');
            return DataRow(
              selected: _selectedIds.contains(id),
              onSelectChanged: _selectionMode
                  ? (v) => _toggleSelection(id)
                  : null,
              cells: [
                DataCell(Text('$sNo')),
                DataCell(Text(it['name'] ?? ''), onTap: () => _openDetails(it)),
                DataCell(
                  Text(
                    it['company'] is Map
                        ? (it['company']['name'] ?? '')
                        : (it['company']?.toString() ?? ''),
                  ),
                ),
                DataCell(Text(it['mobile'] ?? '')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.support_agent,
                        size: 18,
                        color: hasAgent ? Colors.blue : Colors.red.shade200,
                      ),
                      const SizedBox(width: 6),
                      Text(assignedDisplay),
                    ],
                  ),
                ),
                DataCell(_buildStatusChip(it['status'], isConverted: it['isConverted'] == true || it['isCoverted'] == true)),
                DataCell(Text(it['source'] ?? '')),
                DataCell(
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editLead(it);
                      } else if (value == 'delete') {
                        _deleteLead(it);
                      } else if (value == 'template') {
                        _sendTemplate(it);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit,
                                  color: Colors.blueGrey,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'template',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.send,
                                  color: Colors.blueGrey,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text('Send Template'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                    icon: const Icon(Icons.more_vert),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildKanbanView(List<dynamic> items) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? cs.outline.withOpacity(0.5) : Colors.grey.shade300;
    final stages = ['New', 'Contacted', 'Qualified', 'Converted', 'Lost'];
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      itemCount: stages.length,
      itemBuilder: (context, idx) {
        final stage = stages[idx];
        final stageItems = items
            .where((i) => (i['status'] ?? 'New') == stage)
            .toList();
        return Container(
          width: 280,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Text(
                      stage,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        '${stageItems.length}',
                        style: TextStyle(color: cs.onSurface, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: borderColor),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: stageItems.length,
                  itemBuilder: (context, i) {
                    final it = stageItems[i];
                    final id = it['_id'] ?? it['id'];
                    final isSelected = _selectedIds.contains(id);
                    return Card(
                      elevation: isSelected ? 4 : 2,
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isSelected ? AppColors.primary.withOpacity(0.12) : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isSelected
                            ? BorderSide(color: AppColors.primary, width: 2)
                            : BorderSide.none,
                      ),
                      child: InkWell(
                        onTap: _selectionMode
                            ? () => _toggleSelection(id)
                            : () => _openDetails(it),
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    it['name'] ?? '',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    it['company'] is Map
                                        ? (it['company']['name'] ??
                                              'No Company')
                                        : (it['company']?.toString() ??
                                              'No Company'),
                                    style: TextStyle(
                                      color: isDark ? cs.onSurface.withOpacity(0.85) : cs.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectionMode)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (v) => _toggleSelection(id),
                                ),
                              ),
                          ],
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

  static const double _statusChipRadius = 6;

  Widget _buildStatusChip(String? status, {bool isConverted = false}) {
    Color bgColor;
    Color borderColor;
    Color textColor;
    String label;

    if (status == 'Converted' || isConverted) {
      label = 'Converted';
      bgColor = Colors.purple.shade50;
      borderColor = Colors.purple.shade200;
      textColor = Colors.purple.shade800;
    } else if (status == 'New' || status == 'New Lead' || status == null || status == '') {
      label = 'New Lead';
      bgColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade300;
      textColor = Colors.blue.shade800;
    } else if (status == 'Hot') {
      label = 'Hot';
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      textColor = Colors.red.shade800;
    } else if (status == 'Contacted') {
      label = status;
      bgColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade200;
      textColor = Colors.orange.shade800;
    } else if (status == 'Qualified') {
      label = status;
      bgColor = Colors.indigo.shade50;
      borderColor = Colors.indigo.shade200;
      textColor = Colors.indigo.shade800;
    } else if (status == 'Lost') {
      label = status;
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      textColor = Colors.red.shade800;
    } else {
      label = status.toString();
      final cs = Theme.of(context).colorScheme;
      bgColor = cs.surfaceContainerHighest;
      borderColor = cs.outline.withOpacity(0.5);
      textColor = cs.onSurface;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(_statusChipRadius),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Pagination bar above bottom navbar. Client-side: 10/20/50/100 per page.
  /// Right padding so FAB does not hide the "10/page" selector.
  Widget? _buildPaginationControls(int totalPages, int total) {
    if (total <= 0) return null;
    final pages = totalPages < 1 ? 1 : totalPages;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 72, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.5))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _currentPage > 1
                  ? () => setState(() => _currentPage--)
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '$_currentPage < $_pageSize > $total',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _currentPage < pages
                  ? () => setState(() => _currentPage++)
                  : null,
            ),
            const SizedBox(width: 2),
            PopupMenuButton<int>(
              tooltip: 'Leads per page',
              padding: EdgeInsets.zero,
              offset: const Offset(0, -40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onSelected: (int selected) {
                if (selected != _pageSize) {
                  setState(() {
                    _pageSize = selected;
                    _currentPage = 1;
                  });
                }
              },
              itemBuilder: (BuildContext context) => _pageSizeOptions
                  .map((size) => PopupMenuItem<int>(
                        value: size,
                        child: Text('$size / page'),
                      ))
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_pageSize / page',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down, size: 20, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteLead(Map<String, dynamic> lead) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lead?'),
        content: Text('Are you sure you want to delete ${lead['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await LeadsService.deleteLead(lead['_id'] ?? lead['id']);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Lead deleted')));
          setState(_loadData);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _editLead(Map<String, dynamic> lead) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddLeadModal(
          lead: lead,
          onSuccess: () {
            setState(() {
              _loadData();
            });
          },
        ),
      ),
    );
  }

  void _sendTemplate(Map<String, dynamic> lead) async {
    final template = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Template'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'Welcome Email'),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Welcome Email'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'Follow-up'),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Follow-up Check-in'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'Special Offer'),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Special Offer'),
            ),
          ),
        ],
      ),
    );

    if (template != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sending $template to ${lead['name']}...')),
        );
      }
      try {
        await LeadsService.sendTemplate(lead['_id'] ?? lead['id'], template);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Template sent successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _openDetails(Map<String, dynamic> lead) {
    final leadId = LeadsService.leadIdFromLead(lead);
    if (leadId == null || leadId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeadDetailsPage(leadId: leadId),
      ),
    );
  }
}
