import 'package:flutter/material.dart';
import '../api/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/common.dart';
import '../shell/app_nav.dart';
import '../widgets/dashboard_sheets.dart' show appToast;

class DepartmentsScreen extends StatefulWidget {
  const DepartmentsScreen({super.key});

  @override
  State<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<DepartmentsScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _departments = [];
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final repo = AppScope.of(context).ticketing;
      final data = await repo.fetchAllDepartments();
      if (mounted) {
        setState(() {
          _departments = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Failed to load departments: $e', err: true);
      }
    }
  }

  void _snack(String m, {bool err = false}) {
    appToast(context, m);
  }

  Future<void> _deleteDept(Map<String, dynamic> dept) async {
    final id = dept['id'] ?? dept['_id'] ?? '';
    final name = dept['name'] ?? 'Department';
    final repo = AppScope.of(context).ticketing;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Department',
            style: AppText.poppins(
                size: 16, weight: FontWeight.w800, color: AppColors.ink)),
        content: Text('Are you sure you want to delete department "$name"?',
            style: AppText.poppins(
                size: 13.5, weight: FontWeight.w500, color: AppColors.ink2)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: AppText.poppins(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: AppColors.ink3))),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: AppText.poppins(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await repo.deleteDepartment(id);
      _snack('Department deleted successfully');
      _loadData();
    } catch (e) {
      _snack('Failed to delete department: $e', err: true);
    }
  }

  String _fmtDate(dynamic v) {
    if (v == null) return 'N/A';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString();

    // Format to "MMM dd, yyyy" e.g. "Oct 22, 2025"
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    bool saving = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Add New Department',
                  style: AppText.poppins(
                      size: 15.5,
                      weight: FontWeight.w800,
                      color: AppColors.ink)),
              GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: const Icon(Icons.close_rounded,
                    size: 20, color: AppColors.ink3),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                  text: TextSpan(children: [
                TextSpan(
                    text: 'Department Name',
                    style: AppText.poppins(
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: AppColors.ink2)),
                TextSpan(
                    text: ' *',
                    style: AppText.poppins(
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: AppColors.danger)),
              ])),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line)),
                child: TextField(
                  controller: nameCtrl,
                  maxLength: 50,
                  style: AppText.poppins(
                      size: 13, weight: FontWeight.w600, color: AppColors.ink),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText:
                        'Enter department name [e.g. Sales, Support, Tech...]',
                    hintStyle: AppText.poppins(
                        size: 11.5,
                        weight: FontWeight.w500,
                        color: AppColors.ink4),
                    contentPadding: const EdgeInsets.all(12),
                    counterText: '',
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setSt(() {}),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text('${nameCtrl.text.length}/50',
                    style: AppText.poppins(
                        size: 10.5,
                        weight: FontWeight.w600,
                        color: AppColors.ink4)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel',
                  style: AppText.poppins(
                      size: 13, weight: FontWeight.w700, color: AppColors.ink3)),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        _snack('Department Name is required', err: true);
                        return;
                      }
                      setSt(() => saving = true);
                      try {
                        await AppScope.of(context)
                            .ticketing
                            .createDepartment({'name': name});
                        _snack('Department created successfully');
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        _loadData();
                      } catch (e) {
                        _snack('Failed to create department: $e', err: true);
                        setSt(() => saving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.evaGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Add Department',
                      style: AppText.poppins(
                          size: 13, weight: FontWeight.w700)),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = AppNav.maybeOf(context);

    // Computations
    final totalDepts = _departments.length;
    final totalAgents = _departments.fold<int>(0, (sum, d) {
      final cnt = int.tryParse(d['agentsCount']?.toString() ?? '0') ?? 0;
      return sum + cnt;
    });

    final totalPages = (totalDepts / _pageSize).ceil();
    final startIdx = (_currentPage - 1) * _pageSize;
    final endIdx = startIdx + _pageSize > totalDepts
        ? totalDepts
        : startIdx + _pageSize;
    final pagedList = totalDepts > 0
        ? _departments.sublist(startIdx, endIdx)
        : <Map<String, dynamic>>[];

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
              Navigator.of(context).pop(i);
            }
          },
        ),
        sheet: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.evaGreen))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button row
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
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
                    // Screen Title
                    Text('Department Configuration',
                        style: AppText.poppins(
                            size: 20,
                            weight: FontWeight.w800,
                            color: AppColors.ink)),
                    const SizedBox(height: 14),

                    // Main card container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line),
                        boxShadow: AppColors.shadowSm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Department Management Title & Pills
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text('Department Management',
                                              overflow: TextOverflow.ellipsis,
                                              style: AppText.poppins(
                                                  size: 15,
                                                  weight: FontWeight.w800,
                                                  color: AppColors.ink)),
                                        ),
                                        const SizedBox(width: 8),
                                        // Blue Pill
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                              color: const Color(0xFFE8F2FF),
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          child: Text('$totalDepts departments',
                                              style: AppText.poppins(
                                                  size: 10.5,
                                                  weight: FontWeight.w700,
                                                  color:
                                                      const Color(0xFF1E3A8A))),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // Green Pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: AppColors.evaGreen50,
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Text('$totalAgents total agents',
                                          style: AppText.poppins(
                                              size: 10.5,
                                              weight: FontWeight.w700,
                                              color: AppColors.evaGreenDeep)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Refresh and Add Department Buttons
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 52,
                                  child: OutlinedButton(
                                    onPressed: _loadData,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.ink2,
                                      side: const BorderSide(
                                          color: AppColors.line),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.refresh_rounded,
                                            size: 18, color: AppColors.ink2),
                                        const SizedBox(width: 6),
                                        Text('Refresh',
                                            style: AppText.poppins(
                                                size: 13,
                                                weight: FontWeight.w700,
                                                color: AppColors.ink2)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _showAddDialog,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.evaGreen,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      elevation: 0,
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.add_rounded,
                                            size: 18, color: Colors.white),
                                        const SizedBox(width: 6),
                                        Text('Add\nDepartment',
                                            textAlign: TextAlign.center,
                                            style: AppText.poppins(
                                                size: 12,
                                                weight: FontWeight.w700,
                                                color: Colors.white,
                                                height: 1.15)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: AppColors.line),
                          const SizedBox(height: 12),

                          // Table Headers
                          Row(
                            children: [
                              Expanded(
                                  child: Text('Department',
                                      style: AppText.poppins(
                                          size: 12,
                                          weight: FontWeight.w700,
                                          color: AppColors.ink3))),
                              Container(
                                width: 50,
                                alignment: Alignment.center,
                                child: Text('Agents',
                                    style: AppText.poppins(
                                        size: 12,
                                        weight: FontWeight.w700,
                                        color: AppColors.ink3)),
                              ),
                              const SizedBox(width: 92), // align with delete
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Department Rows
                          if (totalDepts == 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                  child: Text('No departments found.',
                                      style: AppText.poppins(
                                          size: 13,
                                          weight: FontWeight.w600,
                                          color: AppColors.ink4))),
                            )
                          else
                            ...pagedList.map((dept) {
                              final count = int.tryParse(
                                      dept['agentsCount']?.toString() ??
                                          '0') ??
                                  0;
                              final canDelete = count == 0;
                              return Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: const BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                          color: AppColors.line, width: 0.8)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              dept['name']?.toString() ??
                                                  'Department',
                                              style: AppText.poppins(
                                                  size: 13.5,
                                                  weight: FontWeight.w700,
                                                  color: AppColors.ink)),
                                          const SizedBox(height: 3),
                                          Text(
                                              _fmtDate(dept['createdAt'] ??
                                                  dept['created']),
                                              style: AppText.poppins(
                                                  size: 11,
                                                  weight: FontWeight.w500,
                                                  color: AppColors.ink3)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      alignment: Alignment.center,
                                      width: 50,
                                      child: Text(
                                        '$count',
                                        style: AppText.poppins(
                                            size: 14,
                                            weight: FontWeight.w800,
                                            color: count > 0
                                                ? const Color(0xFFD97706)
                                                : AppColors.ink3),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 80,
                                      height: 30,
                                      child: OutlinedButton(
                                        onPressed: canDelete
                                            ? () => _deleteDept(dept)
                                            : null,
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                              color: canDelete
                                                  ? AppColors.danger
                                                  : AppColors.line),
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.delete_outline_rounded,
                                                size: 14,
                                                color: canDelete
                                                    ? AppColors.danger
                                                    : AppColors.ink4),
                                            const SizedBox(width: 2),
                                            Text(
                                              'Delete',
                                              style: AppText.poppins(
                                                  size: 11,
                                                  weight: FontWeight.w700,
                                                  color: canDelete
                                                      ? AppColors.danger
                                                      : AppColors.ink4),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          const SizedBox(height: 16),

                          // Pagination row
                          if (totalPages > 1)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${startIdx + 1}-$endIdx of $totalDepts',
                                  style: AppText.poppins(
                                      size: 12,
                                      weight: FontWeight.w600,
                                      color: AppColors.ink3),
                                ),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: _currentPage > 1
                                          ? () => setState(() => _currentPage--)
                                          : null,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: AppColors.line),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Icon(Icons.chevron_left_rounded,
                                            size: 18,
                                            color: _currentPage > 1
                                                ? AppColors.ink2
                                                : AppColors.ink4),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    ...List.generate(totalPages, (index) {
                                      final pg = index + 1;
                                      final active = pg == _currentPage;
                                      return GestureDetector(
                                        onTap: () =>
                                            setState(() => _currentPage = pg),
                                        child: Container(
                                          margin:
                                              const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: active
                                                    ? AppColors.evaGreen
                                                    : AppColors.line),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '$pg',
                                            style: AppText.poppins(
                                                size: 12,
                                                weight: FontWeight.w700,
                                                color: active
                                                    ? AppColors.evaGreenDeep
                                                    : AppColors.ink2),
                                          ),
                                        ),
                                      );
                                    }),
                                    GestureDetector(
                                      onTap: _currentPage < totalPages
                                          ? () => setState(() => _currentPage++)
                                          : null,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: AppColors.line),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Icon(Icons.chevron_right_rounded,
                                            size: 18,
                                            color: _currentPage < totalPages
                                                ? AppColors.ink2
                                                : AppColors.ink4),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                          const SizedBox(height: 18),

                          // Disclaimer inside the card container at the bottom
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    size: 16, color: AppColors.ink3),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Departments are used to categorize and assign tickets. Departments with agents assigned cannot be deleted.',
                                    style: AppText.poppins(
                                        size: 11.5,
                                        weight: FontWeight.w600,
                                        color: AppColors.ink3,
                                        height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
