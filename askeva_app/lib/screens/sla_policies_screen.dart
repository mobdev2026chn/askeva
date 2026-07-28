import 'package:flutter/material.dart';
import '../api/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/dashboard_sheets.dart' show appToast;
import '../widgets/common.dart';
import '../shell/app_nav.dart';

class SlaPoliciesScreen extends StatefulWidget {
  const SlaPoliciesScreen({super.key});

  @override
  State<SlaPoliciesScreen> createState() => _SlaPoliciesScreenState();
}

class _SlaPoliciesScreenState extends State<SlaPoliciesScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _policies = [];
  List<Map<String, dynamic>> _departments = [];
  final Map<String, bool> _expanded = {};

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
      final policies = await repo.fetchSlaPolicies();
      debugPrint('SLA POLICIES DATA FROM API: $policies');
      final depts = await repo.fetchAllDepartments();
      if (mounted) {
        setState(() {
          _policies = policies;
          _departments = depts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Failed to load SLA Policies: $e', err: true);
      }
    }
  }

  void _snack(String m, {bool err = false}) {
    appToast(context, m);
  }

  Future<void> _toggleStatus(Map<String, dynamic> policy) async {
    final id = policy['id'] ?? policy['_id'] ?? '';
    final active = policy['active'] == true;
    try {
      await AppScope.of(context).ticketing.toggleSlaPolicyStatus(id);
      _snack('Policy ${!active ? "activated" : "deactivated"} successfully');
      _loadData();
    } catch (e) {
      _snack('Failed to update status: $e', err: true);
    }
  }

  Future<void> _deletePolicy(Map<String, dynamic> policy) async {
    final id = policy['id'] ?? policy['_id'] ?? '';
    final name = policy['name'] ?? 'Policy';
    final repo = AppScope.of(context).ticketing;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete SLA Policy', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
        content: Text('Are you sure you want to delete SLA policy "$name"?', style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink2)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink3))),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await repo.deleteSlaPolicy(id);
      _snack('SLA policy deleted successfully');
      _loadData();
    } catch (e) {
      _snack('Failed to delete SLA policy: $e', err: true);
    }
  }

  String _fmtDate(dynamic v) {
    if (v == null) return 'N/A';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _priorityMiniCard(String priority, Color color, dynamic frTime, dynamic frUnit, dynamic resTime, dynamic resUnit) {
    final frText = frTime != null ? '$frTime ${frUnit ?? "mins"}' : 'N/A';
    final resText = resTime != null ? '$resTime ${resUnit ?? "mins"}' : 'N/A';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(priority, style: AppText.poppins(size: 11, weight: FontWeight.w800, color: color)),
                      const SizedBox(height: 3),
                      Text('FR: $frText', style: AppText.poppins(size: 9.5, weight: FontWeight.w600, color: AppColors.ink)),
                      Text('Res: $resText', style: AppText.poppins(size: 9.5, weight: FontWeight.w600, color: AppColors.ink)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActionsSheet(Map<String, dynamic> policy) {
    final name = policy['name']?.toString() ?? 'SLA Policy';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.evaGreen50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_outlined, size: 20, color: AppColors.evaGreenDeep),
              ),
              title: Text(
                'Edit policy',
                style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink),
              ),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                Navigator.of(ctx).pop();
                _showFormModal(policy);
              },
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
              ),
              title: Text(
                'Delete policy',
                style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.danger),
              ),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                Navigator.of(ctx).pop();
                _deletePolicy(policy);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFormModal([Map<String, dynamic>? policy]) {
    final nameCtrl = TextEditingController(text: policy?['name']?.toString() ?? '');
    final descCtrl = TextEditingController(text: policy?['description']?.toString() ?? '');
    String? selDept = policy?['department']?.toString();
    bool active = policy?['active'] ?? true;

    String normalizeTime(dynamic v) {
      if (v == null) return '';
      return v.toString().trim();
    }

    String normalizeUnit(dynamic v) {
      if (v == null) return '';
      final s = v.toString().trim().toLowerCase();
      if (s.contains('minute')) return 'minutes';
      if (s.contains('hour')) return 'hours';
      if (s.contains('day')) return 'days';
      return '';
    }

    // Priorities
    final times = <String, TextEditingController>{
      'criticalFirstResponseTime': TextEditingController(text: normalizeTime(policy?['criticalFirstResponseTime'])),
      'criticalResolutionTime': TextEditingController(text: normalizeTime(policy?['criticalResolutionTime'] ?? policy?['criticalResponseTime'] ?? policy?['responseTime'])),
      'highFirstResponseTime': TextEditingController(text: normalizeTime(policy?['highFirstResponseTime'])),
      'highResolutionTime': TextEditingController(text: normalizeTime(policy?['highResolutionTime'] ?? policy?['highResponseTime'])),
      'mediumFirstResponseTime': TextEditingController(text: normalizeTime(policy?['mediumFirstResponseTime'])),
      'mediumResolutionTime': TextEditingController(text: normalizeTime(policy?['mediumResolutionTime'] ?? policy?['mediumResponseTime'] ?? policy?['resolutionTime'])),
      'lowFirstResponseTime': TextEditingController(text: normalizeTime(policy?['lowFirstResponseTime'])),
      'lowResolutionTime': TextEditingController(text: normalizeTime(policy?['lowResolutionTime'] ?? policy?['lowResponseTime'])),
    };

    final units = <String, String>{
      'criticalFirstResponseTimeUnit': normalizeUnit(policy?['criticalFirstResponseTimeUnit'] ?? policy?['criticalFirstResponseUnit']),
      'criticalResolutionTimeUnit': normalizeUnit(policy?['criticalResolutionTimeUnit'] ?? policy?['criticalResolutionUnit'] ?? policy?['criticalResponseTimeUnit'] ?? policy?['responseTimeUnit']),
      'highFirstResponseTimeUnit': normalizeUnit(policy?['highFirstResponseTimeUnit'] ?? policy?['highFirstResponseUnit']),
      'highResolutionTimeUnit': normalizeUnit(policy?['highResolutionTimeUnit'] ?? policy?['highResolutionUnit'] ?? policy?['highResponseTimeUnit']),
      'mediumFirstResponseTimeUnit': normalizeUnit(policy?['mediumFirstResponseTimeUnit'] ?? policy?['mediumFirstResponseUnit']),
      'mediumResolutionTimeUnit': normalizeUnit(policy?['mediumResolutionTimeUnit'] ?? policy?['mediumResolutionUnit'] ?? policy?['mediumResponseTimeUnit'] ?? policy?['resolutionTimeUnit']),
      'lowFirstResponseTimeUnit': normalizeUnit(policy?['lowFirstResponseTimeUnit'] ?? policy?['lowFirstResponseUnit']),
      'lowResolutionTimeUnit': normalizeUnit(policy?['lowResolutionTimeUnit'] ?? policy?['lowResolutionUnit'] ?? policy?['lowResponseTimeUnit']),
    };

    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        Widget label(String text, {bool required = false}) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(TextSpan(children: [
                if (required) TextSpan(text: '* ', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.danger)),
                TextSpan(text: text, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
              ])),
            );

        Widget fieldInput(TextEditingController ctrl, {String hint = '', TextInputType? kbd, IconData? prefix}) => Container(
              height: 38,
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
              child: TextField(
                controller: ctrl,
                keyboardType: kbd,
                style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: hint,
                  hintStyle: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink4),
                  prefixIcon: prefix != null ? Icon(prefix, size: 16, color: AppColors.ink4) : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  border: InputBorder.none,
                ),
              ),
            );

        Widget unitDropdown(String key, ValueChanged<String?> onChanged) => Container(
              height: 38,
              width: 90,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: ['minutes', 'hours', 'days'].contains(units[key]) ? units[key] : null,
                  hint: Text('Unit', style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.ink4)),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.ink4),
                  items: const [
                    DropdownMenuItem(value: 'minutes', child: Text('Minutes')),
                    DropdownMenuItem(value: 'hours', child: Text('Hours')),
                    DropdownMenuItem(value: 'days', child: Text('Days')),
                  ],
                  style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink),
                  onChanged: onChanged,
                ),
              ),
            );

        Widget priorityCard(String title, Color color, String frTimeKey, String frUnitKey, String resTimeKey, String resUnitKey) => Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 4, color: color),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: color)),
                              const SizedBox(height: 12),
                              label('First Response Time', required: true),
                              Row(children: [
                                Expanded(child: fieldInput(times[frTimeKey]!, hint: 'First Response Time', kbd: TextInputType.number)),
                                const SizedBox(width: 8),
                                unitDropdown(frUnitKey, (v) => setSt(() => units[frUnitKey] = v ?? 'hours')),
                              ]),
                              const SizedBox(height: 12),
                              label('Resolution Time', required: true),
                              Row(children: [
                                Expanded(child: fieldInput(times[resTimeKey]!, hint: 'Resolution Time', kbd: TextInputType.number)),
                                const SizedBox(width: 8),
                                unitDropdown(resUnitKey, (v) => setSt(() => units[resUnitKey] = v ?? 'days')),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.92,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(children: [
                GestureDetector(onTap: () => Navigator.of(ctx).pop(), child: const Icon(Icons.close_rounded, size: 22, color: AppColors.ink)),
                Expanded(child: Center(child: Text(policy == null ? 'Create New SLA Policy' : 'Edit SLA Policy', style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)))),
                const SizedBox(width: 22),
              ]),
            ),
            const Divider(height: 1, color: AppColors.line),
            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Policy Name
                  label('Policy Name', required: true),
                  fieldInput(nameCtrl, hint: 'Enter policy name', prefix: Icons.local_offer_outlined),
                  const SizedBox(height: 14),

                  // Description
                  label('Description'),
                  Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
                    child: TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Enter policy description (optional)',
                        hintStyle: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink4),
                        contentPadding: const EdgeInsets.all(12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Department
                  label('Department', required: true),
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
                    child: DropdownButtonHideUnderline(
                      child: Builder(
                        builder: (context) {
                          final deptNames = _departments.map((d) => (d['name'] ?? '').toString()).toSet().toList();
                          if (selDept != null && !deptNames.contains(selDept)) {
                            deptNames.add(selDept!);
                          }
                          return DropdownButton<String>(
                            value: selDept,
                            hint: Text('Select department', style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink4)),
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.ink4),
                            style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                            items: deptNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                            onChanged: (v) => setSt(() => selDept = v),
                          );
                        }
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Time Configuration Divider
                  Center(
                    child: Text('Time Configuration', style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.ink3)),
                  ),
                  const SizedBox(height: 12),
                  Text('Priority Resolution Times', style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 12),

                  // Priority Cards
                  priorityCard('Critical Priority', const Color(0xFFC2261A), 'criticalFirstResponseTime', 'criticalFirstResponseTimeUnit', 'criticalResolutionTime', 'criticalResolutionTimeUnit'),
                  priorityCard('High Priority', const Color(0xFFD6492B), 'highFirstResponseTime', 'highFirstResponseTimeUnit', 'highResolutionTime', 'highResolutionTimeUnit'),
                  priorityCard('Medium Priority', const Color(0xFFC8881A), 'mediumFirstResponseTime', 'mediumFirstResponseTimeUnit', 'mediumResolutionTime', 'mediumResolutionTimeUnit'),
                  priorityCard('Low Priority', AppColors.evaGreen, 'lowFirstResponseTime', 'lowFirstResponseTimeUnit', 'lowResolutionTime', 'lowResolutionTimeUnit'),

                  // Status Toggle Section
                  const SizedBox(height: 14),
                  Text('Status', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Switch(
                        value: active,
                        activeTrackColor: AppColors.evaGreen200,
                        activeThumbColor: AppColors.evaGreenDeep,
                        onChanged: (val) => setSt(() => active = val),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        active ? 'ON' : 'OFF',
                        style: AppText.poppins(
                          size: 13,
                          weight: FontWeight.w800,
                          color: active ? AppColors.evaGreenDeep : AppColors.ink3,
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
            ),
            // Footer
            Container(
              decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.line)), boxShadow: AppColors.shadowMd),
              padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.of(ctx).padding.bottom),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink2,
                      backgroundColor: const Color(0xFFF9FAFB),
                      side: const BorderSide(color: AppColors.line),
                      minimumSize: const Size.fromHeight(45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Cancel', style: AppText.poppins(size: 13.5, weight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 45,
                    child: ElevatedButton.icon(
                      onPressed: saving ? null : () async {
                        final name = nameCtrl.text.trim();
                        final desc = descCtrl.text.trim();

                        if (name.isEmpty || selDept == null) {
                          _snack('Policy Name and Department are required', err: true);
                          return;
                        }

                        final payload = <String, dynamic>{
                          'name': name,
                          'description': desc,
                          'department': selDept,
                          'active': active,
                        };

                        for (final k in times.keys) {
                          final valStr = times[k]!.text.trim();
                          if (valStr.isEmpty) {
                            _snack('All priority targets are required', err: true);
                            return;
                          }
                          final parsed = int.tryParse(valStr);
                          if (parsed == null || parsed <= 0) {
                            _snack('Targets must be positive numbers', err: true);
                            return;
                          }
                          payload[k] = parsed;
                        }

                        for (final k in units.keys) {
                          payload[k] = units[k];
                        }

                        setSt(() => saving = true);
                        try {
                          final repo = AppScope.of(context).ticketing;
                          if (policy == null) {
                            await repo.createSlaPolicy(payload);
                            _snack('SLA policy created successfully');
                          } else {
                            final id = policy['id'] ?? policy['_id'] ?? '';
                            await repo.updateSlaPolicy(id, payload);
                            _snack('SLA policy updated successfully');
                          }
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          _loadData();
                        } catch (e) {
                          _snack('Failed to save SLA policy: $e', err: true);
                          setSt(() => saving = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.evaGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: saving ? const SizedBox.shrink() : const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                      label: saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(policy == null ? 'Create' : 'Save', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        );
      }),
    );
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
              Navigator.of(context).pop(i);
            }
          },
        ),
        sheet: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.evaGreen))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.evaGreen,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
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

                      // Screen Title & Action
                      Row(
                        children: [
                          Expanded(
                            child: Text('SLA Policies',
                                style: AppText.poppins(
                                    size: 20,
                                    weight: FontWeight.w800,
                                    color: AppColors.ink)),
                          ),
                          GestureDetector(
                            onTap: () => _showFormModal(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(color: AppColors.evaGreen, borderRadius: BorderRadius.circular(8)),
                              child: Row(children: [
                                const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                                const SizedBox(width: 4),
                                Text('Add Policy', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.white)),
                              ]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Policies List
                      if (_policies.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: Text('No SLA Policies found', style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink4))),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: _policies.length,
                          itemBuilder: (ctx, i) {
                            final p = _policies[i];
                            final id = p['id'] ?? p['_id'] ?? '';
                            final active = p['active'] == true;
                            final name = p['name']?.toString() ?? 'SLA Policy';
                            final isExpanded = _expanded[id] == true;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line), boxShadow: AppColors.shadowSm),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(
                                      '${i + 1}  $name',
                                      style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _showActionsSheet(p),
                                    child: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.ink3),
                                  ),
                                ]),
                                const SizedBox(height: 10),
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F2FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Text(
                                      (p['department'] ?? 'General').toString(),
                                      style: AppText.poppins(size: 11, weight: FontWeight.w700, color: const Color(0xFF1E88E5)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      p['description']?.toString() ?? 'No description',
                                      style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: const Color(0xFF1E88E5)),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 12),
                                const Divider(height: 1, color: AppColors.line),
                                const SizedBox(height: 8),
                                Row(children: [
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Created', style: AppText.poppins(size: 10, weight: FontWeight.w600, color: AppColors.ink4)),
                                    const SizedBox(height: 2),
                                    Text(_fmtDate(p['createdAt'] ?? p['created']), style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink)),
                                  ]),
                                  const SizedBox(width: 20),
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Updated', style: AppText.poppins(size: 10, weight: FontWeight.w600, color: AppColors.ink4)),
                                    const SizedBox(height: 2),
                                    Text(_fmtDate(p['updatedAt'] ?? p['updated']), style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink)),
                                  ]),
                                  const Spacer(),
                                  Switch(
                                    value: active,
                                    activeTrackColor: AppColors.evaGreen200,
                                    activeThumbColor: AppColors.evaGreenDeep,
                                    onChanged: (_) => _toggleStatus(p),
                                  ),
                                  Text(active ? 'Active' : 'Inactive', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: active ? AppColors.evaGreenDeep : AppColors.ink3)),
                                ]),

                                // Collapsible priority times section
                                const SizedBox(height: 10),
                                const Divider(height: 1, color: AppColors.line),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      final current = _expanded[id] ?? false;
                                      _expanded[id] = !current;
                                    });
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        isExpanded ? 'Hide Priority Details' : 'Show Priority Details',
                                        style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink3),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: AppColors.ink3,
                                      ),
                                    ],
                                  ),
                                ),
                                  if (isExpanded) ...[
                                    const SizedBox(height: 12),
                                    Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _priorityMiniCard(
                                                'Critical',
                                                const Color(0xFFC2261A),
                                                p['criticalFirstResponseTime'],
                                                p['criticalFirstResponseTimeUnit'] ?? p['criticalFirstResponseUnit'],
                                                p['criticalResolutionTime'] ?? p['criticalResponseTime'] ?? p['responseTime'],
                                                p['criticalResolutionTimeUnit'] ?? p['criticalResponseTimeUnit'] ?? p['responseTimeUnit'],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _priorityMiniCard(
                                                'High',
                                                const Color(0xFFD6492B),
                                                p['highFirstResponseTime'],
                                                p['highFirstResponseTimeUnit'] ?? p['highFirstResponseUnit'],
                                                p['highResolutionTime'] ?? p['highResponseTime'],
                                                p['highResolutionTimeUnit'] ?? p['highResponseTimeUnit'],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _priorityMiniCard(
                                                'Medium',
                                                const Color(0xFFC8881A),
                                                p['mediumFirstResponseTime'],
                                                p['mediumFirstResponseTimeUnit'] ?? p['mediumFirstResponseUnit'],
                                                p['mediumResolutionTime'] ?? p['mediumResponseTime'] ?? p['resolutionTime'],
                                                p['mediumResolutionTimeUnit'] ?? p['mediumResponseTimeUnit'] ?? p['resolutionTimeUnit'],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _priorityMiniCard(
                                                'Low',
                                                AppColors.evaGreen,
                                                p['lowFirstResponseTime'],
                                                p['lowFirstResponseTimeUnit'] ?? p['lowFirstResponseUnit'],
                                                p['lowResolutionTime'] ?? p['lowResponseTime'],
                                                p['lowResolutionTimeUnit'] ?? p['lowResponseTimeUnit'],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                              ]),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

}
