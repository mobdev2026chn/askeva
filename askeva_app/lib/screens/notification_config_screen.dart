import 'package:flutter/material.dart';
import '../api/app_scope.dart';
import '../api/dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/common.dart';
import '../shell/app_nav.dart';
import '../widgets/dashboard_sheets.dart' show appToast, showAppSheet;
import '../widgets/leads_sheets.dart' show SelectTemplateBottomSheet;

class NotificationConfigScreen extends StatefulWidget {
  const NotificationConfigScreen({super.key});

  @override
  State<NotificationConfigScreen> createState() =>
      _NotificationConfigScreenState();
}

class _NotificationConfigScreenState extends State<NotificationConfigScreen> {
  static const _events = [
    _EventInfo('Ticket Assigned', Icons.assignment_ind_outlined,
        hasUserAlert: true),
    _EventInfo('Ticket Awaiting for Customer', Icons.hourglass_top_outlined,
        hasUserAlert: true),
    _EventInfo('Ticket Pending', Icons.pending_actions_outlined,
        hasUserAlert: true),
    _EventInfo('Ticket In Progress', Icons.autorenew_outlined,
        hasUserAlert: true),
    _EventInfo('Ticket Completed', Icons.check_circle_outline,
        hasUserAlert: true),
    _EventInfo('Ticket Reopened', Icons.refresh_outlined, hasUserAlert: true),
    _EventInfo('Agent Response Delay', Icons.timer_off_outlined,
        hasUserAlert: false),
    _EventInfo('Ticket Resolve Time', Icons.alarm_outlined,
        hasUserAlert: false),
  ];

  _EventInfo _selected = _events[0];
  int _refreshCount = 0;

  Future<void> _handleRefresh() async {
    setState(() {
      _refreshCount++;
    });
    await Future.delayed(const Duration(milliseconds: 800));
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
        sheet: RefreshIndicator(
          onRefresh: _handleRefresh,
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

                // Screen Title
                Text('Notification Configuration',
                    style: AppText.poppins(
                        size: 20,
                        weight: FontWeight.w800,
                        color: AppColors.ink)),
                const SizedBox(height: 14),

                // Pills
                _buildPills(),
                const SizedBox(height: 16),

                // Notification Cards Stacked (no TabBar)
                _NotificationFormCard(
                  key: ValueKey('${_selected.title}-businessAlert-$_refreshCount'),
                  event: _selected,
                  alertType: 'businessAlert',
                ),
                if (_selected.hasUserAlert) ...[
                  const SizedBox(height: 16),
                  _NotificationFormCard(
                    key: ValueKey('${_selected.title}-userAlert-$_refreshCount'),
                    event: _selected,
                    alertType: 'userAlert',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPills() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _events.map((e) {
        final sel = e == _selected;
        return GestureDetector(
          onTap: () => setState(() => _selected = e),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFFEAF9E6) : AppColors.surface,
              border: Border.all(
                  color: sel ? AppColors.evaGreen : AppColors.line),
              borderRadius: BorderRadius.circular(20),
              boxShadow: !sel ? AppColors.shadowSm : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(e.icon,
                    size: 14,
                    color: sel ? AppColors.evaGreenDeep : AppColors.ink3),
                const SizedBox(width: 6),
                Text(e.title,
                    style: AppText.poppins(
                        size: 12,
                        weight: FontWeight.w700,
                        color: sel ? AppColors.evaGreenDeep : AppColors.ink3)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _NotificationFormCard  — a stateful card representing one configuration
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationFormCard extends StatefulWidget {
  final _EventInfo event;
  final String alertType; // 'businessAlert' | 'userAlert'
  const _NotificationFormCard({super.key, required this.event, required this.alertType});

  @override
  State<_NotificationFormCard> createState() => _NotificationFormCardState();
}

class _NotificationFormCardState extends State<_NotificationFormCard> {
  bool _loading = true;
  bool _saving = false;

  List<TemplateDto> _templates = [];
  TemplateDto? _tpl;
  Map<String, String> _map = {};
  bool _enabled = true;

  String get _apiEventType =>
      widget.event.title == 'Ticket Completed'
          ? 'Ticket Resolved'
          : widget.event.title;

  static const _fields = [
    ('customerName', 'Customer Name'),
    ('mobileNumber', 'Customer Mobile'),
    ('custom_field_1759410270994', 'Customer Email'),
    ('department_field', 'Department'),
    ('subject', 'Subject'),
    ('status', 'Ticket Status'),
    ('source', 'Ticket Source'),
    ('ticketId', 'Ticket ID'),
    ('priority', 'Ticket Priority'),
    ('assignedTo', 'Assignee Name'),
    ('reason', 'On change Reason'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    try {
      final results = await Future.wait([
        scope.compose.fetchApprovedTemplates(),
        scope.ticketing.fetchReminderConfiguration(_apiEventType),
      ]);
      final tpls = results[0] as List<TemplateDto>;
      final cfg = results[1] as Map<String, dynamic>;

      TemplateDto? found;
      Map<String, String> mappings = {};
      bool enabled = true;

      final ac = cfg[widget.alertType];
      if (ac is Map && ac.isNotEmpty) {
        enabled = ac['enabled'] != false && ac['active'] != false;
        final tid = (ac['templateId'] ?? ac['id'] ?? '').toString();
        final tname = (ac['templateName'] ?? ac['template']?['name'] ?? ac['template'] ?? '').toString();
        found = tpls.cast<TemplateDto?>().firstWhere(
            (t) => (tid.isNotEmpty && t!.id == tid) || (tname.isNotEmpty && t!.name == tname),
            orElse: () => null);
        final rawMap = ac['variableMappings'] ?? ac['formData']?['variableMappings'];
        if (rawMap is Map) {
          mappings = Map<String, String>.from(
            rawMap.map((k, v) => MapEntry(k.toString(), v.toString())),
          );
        }
      }

      if (mounted) {
        setState(() {
          _templates = tpls;
          _tpl = found;
          _map = mappings;
          _enabled = enabled;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_tpl == null) {
      appToast(context, 'Please select a template first', isError: true);
      return;
    }
    for (final v in _tpl!.variables) {
      if ((_map[v] ?? '').isEmpty) {
        appToast(context, 'Please map the variable "$v"', isError: true);
        return;
      }
    }
    setState(() => _saving = true);
    final scope = AppScope.of(context);
    try {
      await scope.ticketing.saveReminderConfiguration({
        'eventType': _apiEventType,
        'alertType': widget.alertType,
        'configData': {
          'templateId': _tpl!.id,
          'templateName': _tpl!.name,
          'templateType': '',
          'headerType': _tpl!.headerType,
          'message': _tpl!.message,
          'variableMappings': _map,
          'fileUrl': '',
          'enabled': _enabled,
          'active': _enabled,
          'actions': _tpl!.actions,
        },
      });
      if (mounted) appToast(context, 'Configuration saved successfully');
    } catch (e) {
      if (mounted) appToast(context, 'Failed to save: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    if (!value && _enabled) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('Confirm Change', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: const Text('Are you sure you want to turn OFF this alert?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final prev = _enabled;
    setState(() => _enabled = value);

    if (!mounted) return;
    final scope = AppScope.of(context);

    try {
      await scope.ticketing.saveReminderConfiguration({
        'eventType': _apiEventType,
        'alertType': widget.alertType,
        'configData': {
          'templateId': _tpl!.id,
          'templateName': _tpl!.name,
          'templateType': '',
          'headerType': _tpl!.headerType,
          'message': _tpl!.message,
          'variableMappings': _map,
          'fileUrl': '',
          'enabled': value,
          'active': value,
          'actions': _tpl!.actions,
        },
      });
    } catch (_) {
      if (mounted) setState(() => _enabled = prev);
    }
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Configuration'),
        content: Text(
            'Reset the ${widget.alertType == "businessAlert" ? "Business" : "User"} Alert? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, Reset',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final scope = AppScope.of(context);
    try {
      await scope.ticketing
          .resetReminderConfiguration(_apiEventType, widget.alertType);
      setState(() {
        _tpl = null;
        _map = {};
        _enabled = true;
      });
      if (mounted) appToast(context, 'Configuration reset successfully');
    } catch (e) {
      if (mounted) appToast(context, 'Failed to reset: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: const CircularProgressIndicator(color: AppColors.evaGreen),
      );
    }

    final isUser = widget.alertType == 'userAlert';
    final cardTitle =
        '${widget.event.title} - ${isUser ? "User Alert" : "Business Alert"}';

    return Container(
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
          // Header Row with Switch
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(cardTitle,
                    style: AppText.poppins(
                        size: 14.5,
                        weight: FontWeight.w800,
                        color: AppColors.ink)),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _toggleEnabled(!_enabled),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _enabled ? const Color(0xFF2CB63F) : const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        left: _enabled ? 32 : 4,
                        top: 3,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: _enabled ? 0 : 20,
                            right: _enabled ? 20 : 0,
                          ),
                          child: Text(
                            _enabled ? 'ON' : 'OFF',
                            style: AppText.poppins(
                              size: 9.5,
                              weight: FontWeight.w900,
                              color: _enabled ? Colors.white : const Color(0xFF8E8E93),
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
          const SizedBox(height: 14),

          // Select Template Label
          RichText(
            text: TextSpan(children: [
              TextSpan(
                  text: 'Select Template ',
                  style: AppText.poppins(
                      size: 13,
                      weight: FontWeight.w700,
                      color: AppColors.ink)),
              TextSpan(
                  text: '*',
                  style: AppText.poppins(
                      size: 13, weight: FontWeight.w700, color: Colors.red)),
            ]),
          ),
          const SizedBox(height: 8),

          // Selected / Unselected Template trigger
          GestureDetector(
            onTap: _showPicker,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _tpl != null
                        ? AppColors.evaGreen.withAlpha(128)
                        : AppColors.line),
              ),
              child: Row(
                children: [
                  Text('Template: ',
                      style: AppText.poppins(
                          size: 12.5,
                          weight: FontWeight.w500,
                          color: AppColors.ink3)),
                  Expanded(
                    child: Text(
                        _tpl != null
                            ? _tpl!.name
                            : 'Choose a WhatsApp template…',
                        style: AppText.poppins(
                            size: 12.5,
                            weight: _tpl != null
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color:
                                _tpl != null ? AppColors.ink : AppColors.ink4),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.upload_rounded,
                      size: 16, color: AppColors.evaGreenDeep),
                ],
              ),
            ),
          ),

          if (_tpl != null) ...[
            const SizedBox(height: 14),
            _buildPreview(),
            if (_tpl!.variables.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildMappings(),
            ],
          ],

          const SizedBox(height: 18),
          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.evaGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.description_outlined, size: 17, color: Colors.white),
                  label: Text(
                      _saving ? 'Saving…' : 'Save Configuration',
                      style: AppText.poppins(
                          size: 13.5, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _reset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text('Reset',
                      style: AppText.poppins(
                          size: 13.5, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showPicker() async {
    List<TemplateDto> tpls = _templates;
    if (tpls.isEmpty) {
      try {
        tpls = await AppScope.of(context).compose.fetchApprovedTemplates();
        if (mounted) setState(() => _templates = tpls);
      } catch (_) {}
    }
    if (!mounted) return;
    final picked = await showAppSheet<TemplateDto>(
      context,
      SelectTemplateBottomSheet(templates: tpls),
    );
    if (picked != null) {
      _onTemplateSelected(picked);
    }
  }

  void _onTemplateSelected(TemplateDto t) {
    setState(() {
      _tpl = t;
      final prev = _map;
      _map = {for (final v in t.variables) v: prev[v] ?? ''};
    });
  }

  Widget _buildPreview() {
    final t = _tpl!;
    final typeColor = switch (t.category.toLowerCase()) {
      'marketing' => const Color(0xFF1E3A8A), // Blue for marketing as in screenshot
      'utility' => const Color(0xFF2563EB), // Blue for utility
      _ => AppColors.ink2,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF9E6),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.evaGreen.withAlpha(64)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type + Header row
          Row(
            children: [
              Text('Type: ',
                  style: AppText.poppins(
                      size: 11.5, color: AppColors.ink3)),
              Text(t.category.toUpperCase(),
                  style: AppText.poppins(
                      size: 11.5,
                      weight: FontWeight.w800,
                      color: typeColor)),
              const Spacer(),
              Text('Header: ',
                  style: AppText.poppins(
                      size: 11.5, color: AppColors.ink3)),
              Text(t.headerType.toLowerCase(),
                  style: AppText.poppins(
                      size: 11.5,
                      weight: FontWeight.w800,
                      color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Message:',
              style: AppText.poppins(
                  size: 11.5, color: AppColors.ink3)),
          const SizedBox(height: 4),
          // Message body in white bubble
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(t.message,
                style: AppText.poppins(
                    size: 12.5,
                    color: AppColors.ink,
                    height: 1.55)),
          ),
          // Variables line
          if (t.variables.isNotEmpty) ...[
            const SizedBox(height: 10),
            RichText(
              text: TextSpan(children: [
                TextSpan(
                    text: 'Variables: ',
                    style: AppText.poppins(
                        size: 11.5, color: AppColors.ink3)),
                TextSpan(
                    text: t.variables.join(', '),
                    style: AppText.poppins(
                        size: 11.5,
                        weight: FontWeight.w800,
                        color: AppColors.ink)),
              ]),
            ),
          ],
          // Actions line
          if (t.actionsLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(children: [
                TextSpan(
                    text: 'Actions: ',
                    style: AppText.poppins(
                        size: 11.5, color: AppColors.ink3)),
                TextSpan(
                    text: t.actionsLabel,
                    style: AppText.poppins(
                        size: 11.5,
                        weight: FontWeight.w800,
                        color: AppColors.ink)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMappings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _tpl!.variables
          .map((v) => _mapRow(v))
          .toList(),
    );
  }

  Widget _mapRow(String variable) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(children: [
              TextSpan(
                  text: 'Map ${variable.toUpperCase()} ',
                  style: AppText.poppins(
                      size: 13,
                      weight: FontWeight.w700,
                      color: AppColors.ink)),
              TextSpan(
                  text: '*',
                  style: AppText.poppins(
                      size: 13,
                      weight: FontWeight.w700,
                      color: Colors.red)),
            ]),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: (_map[variable]?.isEmpty ?? true)
                    ? null
                    : _map[variable],
                isExpanded: true,
                hint: Text('Select field…',
                    style: AppText.poppins(
                        size: 13, color: AppColors.ink3)),
                dropdownColor: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                items: _fields
                    .map((f) => DropdownMenuItem(
                          value: f.$1,
                          child: Text(f.$2,
                              style: AppText.poppins(
                                  size: 13, color: AppColors.ink)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _map[variable] = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventInfo {
  final String title;
  final IconData icon;
  final bool hasUserAlert;
  const _EventInfo(this.title, this.icon, {required this.hasUserAlert});
}
