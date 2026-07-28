import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';

import '../api/app_scope.dart';
import '../api/dto.dart';
import '../screens/lead_detail_screen.dart';
import '../shell/app_nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'common.dart';
import 'dashboard_sheets.dart' show appToast, showAppSheet;
import 'leads_extra.dart';

// ---------------------------------------------------------------------------
// Lead Filters sheet  (returns the chosen LeadFilter, or LeadFilter.empty on Clear)
// ---------------------------------------------------------------------------

Future<LeadFilter?> showLeadFilters(
  BuildContext context, {
  required LeadFilter current,
  required List<String> sources,
  required List<String> companies,
  required List<String> agents,
}) {
  return showModalBottomSheet<LeadFilter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LeadFiltersSheet(current: current, sources: sources, companies: companies, agents: agents),
  );
}

class _LeadFiltersSheet extends StatefulWidget {
  final LeadFilter current;
  final List<String> sources, companies, agents;
  const _LeadFiltersSheet({required this.current, required this.sources, required this.companies, required this.agents});
  @override
  State<_LeadFiltersSheet> createState() => _LeadFiltersSheetState();
}

class _LeadFiltersSheetState extends State<_LeadFiltersSheet> {
  late LeadFilter _f = widget.current;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close_rounded, size: 22, color: AppColors.ink2),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.filter_alt_outlined, size: 19, color: AppColors.ink),
              const SizedBox(width: 8),
              Text(
                'Filters',
                style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _label('Created Date Range'),
          GestureDetector(
            onTap: () async {
              final picked = await showModalBottomSheet<List<DateTime>>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (ctx) => CustomDateRangePicker(initialRange: _f.dateRange),
              );
              if (picked != null && picked.length == 2) {
                setState(() => _f = _f.copyWith(dateRange: picked));
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4FBF7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD1FAE5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _f.dateRange == null
                          ? 'Start date → End date'
                          : '${_f.dateRange![0].day}/${_f.dateRange![0].month}/${_f.dateRange![0].year} → ${_f.dateRange![1].day}/${_f.dateRange![1].month}/${_f.dateRange![1].year}',
                      style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: const Color(0xFF047857)),
                    ),
                  ),
                  const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF047857)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _label('Time Period'),
          formSelect<String>(
            value: _f.timePeriod,
            placeholder: 'All time',
            options: const [
              ('All time', 'All time'),
              ('Today', 'Today'),
              ('Last 7 days', 'Last 7 days'),
              ('Last 30 days', 'Last 30 days'),
            ],
            onChanged: (v) => setState(() {
              _f = _f.copyWith(timePeriod: v);
              if (v != 'All time') _f = _f.copyWith(dateRange: null);
            }),
          ),
          _label('Company'),
          formSelect<String>(
            value: _f.company,
            placeholder: 'All Companies',
            options: [
              ('All Companies', 'All Companies'),
              for (final c in widget.companies) (c, c)
            ],
            onChanged: (v) => setState(() => _f = _f.copyWith(company: v == 'All Companies' ? null : v)),
          ),
          const SizedBox(height: 12),
          _label('Assigned To'),
          formSelect<String>(
            value: _f.assigned,
            placeholder: 'All Agents',
            options: [
              ('All Agents', 'All Agents'),
              for (final a in widget.agents) (a, a)
            ],
            onChanged: (v) => setState(() => _f = _f.copyWith(assigned: v == 'All Agents' ? null : v)),
          ),
          const SizedBox(height: 12),
          _label('Lead Source'),
          formSelect<String>(
            value: _f.source,
            placeholder: 'All Sources',
            options: [
              ('All Sources', 'All Sources'),
              for (final s in widget.sources) (s, s)
            ],
            onChanged: (v) => setState(() => _f = _f.copyWith(source: v == 'All Sources' ? null : v)),
          ),
          const SizedBox(height: 12),
          _label('Lead Status'),
          formSelect<String>(
            value: _f.status,
            placeholder: 'All Status',
            options: [
              ('All Status', 'All Status'),
              for (final s in kLeadStatuses) (s, s)
            ],
            onChanged: (v) => setState(() => _f = _f.copyWith(status: v == 'All Status' ? null : v)),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(LeadFilter.empty),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Clear All', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_f),
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

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 12),
        child: Text(t, style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3)),
      );
}

// ---------------------------------------------------------------------------
// Lead actions sheet
// ---------------------------------------------------------------------------

Future<void> showLeadActions(
  BuildContext context,
  LeadDto lead, {
  VoidCallback? onChanged,
  List<String> companies = const [],
  List<String> sources = const [],
  List<String> agents = const [],
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LeadActionsSheet(lead: lead, onChanged: onChanged, companies: companies, sources: sources, agents: agents),
  );
}

class _LeadActionsSheet extends StatelessWidget {
  final LeadDto lead;
  final VoidCallback? onChanged;
  final List<String> companies, sources, agents;
  const _LeadActionsSheet({required this.lead, this.onChanged, required this.companies, required this.sources, required this.agents});

  Future<void> _convert(BuildContext context) async {
    final leads = AppScope.of(context).leads;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Convert to Customer', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
        content: Text('Are you sure you want to convert this lead to a customer? This will also remove the current agent assignment.', style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink2)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Convert', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep))),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await leads.convertLead(lead.id);
      if (context.mounted) {
        appToast(context, 'Converted to customer');
        Navigator.of(context).pop();
      }
      onChanged?.call();
    } catch (e) {
      if (context.mounted) {
        appToast(context, e.toString().replaceFirst('Exception: ', 'Failed to convert: '));
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final leads = AppScope.of(context).leads;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete lead', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
        content: Text('Delete this lead permanently? This cannot be undone.', style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink2)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Delete', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await leads.deleteLead(lead.id);
      if (context.mounted) {
        appToast(context, 'Lead deleted');
        Navigator.of(context).pop();
      }
      onChanged?.call();
    } catch (e) {
      if (context.mounted) {
        appToast(context, e.toString().replaceFirst('Exception: ', 'Failed to delete: '));
      }
    }
  }

  void _handle(BuildContext context, String label) {
    Navigator.of(context).pop();
    switch (label) {
      case 'Call':
        final phone = lead.mobile.replaceAll(RegExp(r'[^\d\+]'), '');
        if (phone.isNotEmpty) {
          try {
            final uri = Uri.parse('tel:$phone');
            launchUrl(uri);
          } catch (_) {}
        } else {
          appToast(context, 'No mobile number configured for this lead', isError: true);
        }
      case 'Reminders':
        showReminderSheet(context, lead, agents: agents);
      case 'Profile':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead)));
      case 'Send Template':
        showTemplateSheet(context, lead);
      case 'Notes':
        showNotesSheet(context, lead);
      case 'Activity Logs':
        showActivityLogs(context, lead);
      case 'Call Logs':
        showCallLogs(context, lead);
    }
  }

  @override
  Widget build(BuildContext context) {
    final display = lead.name.isEmpty ? (lead.mobile.isEmpty ? 'Unknown' : lead.mobile) : lead.name;
    final actions = <(IconData, String, Color, Color)>[
      (Icons.call_rounded, 'Call', AppColors.evaGreenDeep, AppColors.evaGreen50),
      (Icons.alarm_rounded, 'Reminders', const Color(0xFFF5A623), const Color(0xFFFDF3E0)),
      (Icons.person_outline_rounded, 'Profile', const Color(0xFF3B82F6), const Color(0xFFE7F0FE)),
      (Icons.cloud_upload_outlined, 'Send Template', const Color(0xFF7C5CFC), const Color(0xFFEEEAFE)),
      (Icons.description_outlined, 'Notes', const Color(0xFFE5489B), const Color(0xFFFCE7F2)),
      (Icons.timeline_rounded, 'Activity Logs', const Color(0xFF1E9BB0), const Color(0xFFE2F4F7)),
      (Icons.call_made_rounded, 'Call Logs', AppColors.evaGreenDeep, AppColors.evaGreen50),
    ];
    return Container(
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.of(context).padding.bottom + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(3)))),
          const SizedBox(height: 14),
          Row(children: [
            Text('Lead actions', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
            const Spacer(),
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                showLeadForm(context, lead: lead, companies: companies, sources: sources, agents: agents).then((ok) {
                  if (ok == true) onChanged?.call();
                });
              },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6), decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(999)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.edit_outlined, size: 14, color: AppColors.evaGreenDeep), const SizedBox(width: 5), Text('Edit', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.evaGreenDeep))])),
            ),
            const SizedBox(width: 10),
            InkWell(onTap: () => Navigator.of(context).pop(), child: const Icon(Icons.close_rounded, size: 20, color: AppColors.ink3)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            InitialsAvatar(initials: _initials(display), color: avatarColorFor(display), size: 44, radius: 13),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(display, style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 3),
                Row(children: [const Icon(Icons.call_outlined, size: 12, color: AppColors.ink4), const SizedBox(width: 4), Text(lead.mobile.isEmpty ? '—' : lead.mobile, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3))]),
              ]),
            ),
            StatusPill(status: lead.status),
          ]),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: actions.map((a) {
              return GestureDetector(
                onTap: () => _handle(context, a.$2),
                child: Container(
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.line)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: a.$4, borderRadius: BorderRadius.circular(12)), child: Icon(a.$1, size: 20, color: a.$3)),
                    const SizedBox(height: 8),
                    Text(a.$2, textAlign: TextAlign.center, style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink2)),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          lead.isConverted
              ? SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: AppColors.line),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_rounded, size: 19, color: AppColors.evaGreenDeep),
                        const SizedBox(width: 8),
                        Text(
                          'Already a customer',
                          style: AppText.poppins(
                            size: 15,
                            weight: FontWeight.w800,
                            color: AppColors.ink4,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: AppColors.evaGradient, borderRadius: BorderRadius.circular(13)),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: () => _convert(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.check_rounded, size: 19, color: Colors.white), const SizedBox(width: 8), Text('Convert as customer', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: Colors.white))]),
                        ),
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _delete(context),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger), const SizedBox(width: 8), Text('Delete lead', style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: AppColors.danger))]),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showTemplateSheet(BuildContext context, LeadDto lead) {
  return showAppSheet(
    context,
    _SendTemplateSheet(lead: lead),
  );
}

class _AdditionalRecipientInput {
  final TextEditingController nameCtrl = TextEditingController();
  String countryCode = '91';
  final TextEditingController mobileCtrl = TextEditingController();
  bool createAsLead = false;

  void dispose() {
    nameCtrl.dispose();
    mobileCtrl.dispose();
  }
}

class _SendTemplateSheet extends StatefulWidget {
  final LeadDto lead;
  const _SendTemplateSheet({required this.lead});
  @override
  State<_SendTemplateSheet> createState() => _SendTemplateSheetState();
}

class _SendTemplateSheetState extends State<_SendTemplateSheet> {
  TemplateDto? _selectedTemplate;
  List<TemplateDto> _allTemplates = [];
  bool _loadingTemplates = true;
  bool _sending = false;

  final Map<String, TextEditingController> _varControllers = {};
  final TextEditingController _fileUrlCtrl = TextEditingController();
  final List<_AdditionalRecipientInput> _additionalRecipients = [];

  final List<(String, String)> kCountryCodes = const [
    ('91', '+91 India'),
    ('1', '+1 USA'),
    ('44', '+44 UK'),
    ('971', '+971 UAE'),
    ('61', '+61 Australia'),
    ('65', '+65 Singapore'),
  ];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    for (final ctrl in _varControllers.values) {
      ctrl.dispose();
    }
    _fileUrlCtrl.dispose();
    for (final r in _additionalRecipients) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    try {
      final list = await AppScope.of(context).compose.fetchApprovedTemplates();
      if (mounted) {
        setState(() {
          _allTemplates = list;
          _loadingTemplates = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingTemplates = false);
      }
    }
  }

  TextEditingController _getVarController(String key) {
    if (!_varControllers.containsKey(key)) {
      _varControllers[key] = TextEditingController();
    }
    return _varControllers[key]!;
  }

  void _reset() {
    setState(() {
      _selectedTemplate = null;
      _varControllers.clear();
      _fileUrlCtrl.clear();
      for (final r in _additionalRecipients) {
        r.dispose();
      }
      _additionalRecipients.clear();
    });
  }

  Future<void> _send() async {
    if (_selectedTemplate == null) {
      appToast(context, 'Please select a template');
      return;
    }

    final Map<String, String> variables = {};
    for (final v in _selectedTemplate!.variables) {
      final ctrl = _varControllers[v];
      final val = ctrl?.text.trim() ?? '';
      if (val.isEmpty) {
        appToast(context, 'Please fill: $v');
        return;
      }
      variables[v] = val;
    }

    if (_selectedTemplate!.needsMedia && _fileUrlCtrl.text.trim().isEmpty) {
      appToast(context, 'Please enter ${_selectedTemplate!.headerType} URL');
      return;
    }

    final List<Map<String, dynamic>> validAdditional = [];
    for (final r in _additionalRecipients) {
      final name = r.nameCtrl.text.trim();
      final mobile = r.mobileCtrl.text.trim();
      if (mobile.isEmpty) {
        appToast(context, 'Please enter mobile number for all additional recipients');
        return;
      }
      if (mobile.length < 7) {
        appToast(context, 'Please enter a valid mobile number');
        return;
      }
      validAdditional.add({
        'name': name.isEmpty ? 'Additional Contact' : name,
        'countryCode': r.countryCode,
        'mobile': mobile,
        'createAsLead': r.createAsLead,
      });
    }

    setState(() => _sending = true);

    var cleanMobile = widget.lead.mobile.replaceAll(RegExp(r'[^\d]'), '').trim();
    var cleanCc = widget.lead.countryCode.replaceAll(RegExp(r'[^\d]'), '').trim();
    if (cleanCc.isEmpty) cleanCc = '91';

    if (cleanCc == '91' && cleanMobile.startsWith('9191') && cleanMobile.length >= 14) {
      cleanMobile = cleanMobile.substring(4);
    } else if (cleanMobile.startsWith(cleanCc) && cleanMobile.length == (cleanCc.length + 10)) {
      cleanMobile = cleanMobile.substring(cleanCc.length);
    } else if (cleanCc == '91' && cleanMobile.length == 12 && cleanMobile.startsWith('91')) {
      cleanMobile = cleanMobile.substring(2);
    }

    final body = {
      'templateId': _selectedTemplate!.id,
      'recipientData': {
        'name': widget.lead.name.isEmpty ? 'Primary Contact' : widget.lead.name,
        'countryCode': cleanCc,
        'mobile': cleanMobile,
        'leadId': widget.lead.id,
      },
      'variableValues': variables,
      'fileUrl': _fileUrlCtrl.text.trim(),
      'headerType': _selectedTemplate!.headerType,
      'additionalRecipients': validAdditional,
    };

    try {
      final res = await AppScope.of(context).leads.sendTemplateMessage(body);
      if (!mounted) return;
      if (res['success'] == true) {
        final successCount = res['data']?['success'] ?? (1 + validAdditional.length);
        final totalCount = res['data']?['total'] ?? (1 + validAdditional.length);
        appToast(context, 'Template sent to $successCount of $totalCount recipient(s) successfully!', isSuccess: true);
        Navigator.of(context).pop();
      } else {
        appToast(context, res['message'] ?? 'Failed to send template', isError: true);
      }
    } catch (e) {
      if (mounted) {
        appToast(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingTemplates) {
      return sheetScaffold(
        context,
        title: 'Send Template',
        icon: Icons.cloud_upload_outlined,
        body: const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator(color: AppColors.evaGreen)),
        ),
      );
    }

    final totalRecipients = 1 + _additionalRecipients.length;

    return sheetScaffold(
      context,
      title: 'Send Template',
      icon: Icons.cloud_upload_outlined,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.evaGradient, borderRadius: BorderRadius.circular(10)),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        final picked = await showAppSheet<TemplateDto>(
                          context,
                          SelectTemplateBottomSheet(templates: _allTemplates),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedTemplate = picked;
                            _varControllers.clear();
                            _fileUrlCtrl.clear();
                          });
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Text('Select Template', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (widget.lead.statusRaw.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text('Status: ${widget.lead.statusRaw}', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3)),
                  ),
              ],
            ),
            if (_selectedTemplate != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.evaGreen50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.evaGreen200),
                ),
                child: Text(
                  'Selected: ${_selectedTemplate!.name}',
                  style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                ),
              ),
              if (_selectedTemplate!.variables.isNotEmpty) ...[
                const SizedBox(height: 14),
                formLabel('Template Variables'),
                const SizedBox(height: 6),
                for (final v in _selectedTemplate!.variables) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: formInput(
                      _getVarController(v),
                      hint: 'Enter value for $v',
                    ),
                  ),
                ],
              ],
              if (_selectedTemplate!.needsMedia) ...[
                const SizedBox(height: 14),
                formLabel('Header ${firstLetterCapital(_selectedTemplate!.headerType)} URL'),
                const SizedBox(height: 6),
                formInput(
                  _fileUrlCtrl,
                  hint: 'Enter ${_selectedTemplate!.headerType} URL',
                ),
              ],
            ],

            const SizedBox(height: 20),
            formLabel('Primary Mobile Number'),
            const SizedBox(height: 6),
            AbsorbPointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.lead.countryCode.isNotEmpty 
                            ? '+${widget.lead.countryCode} ${widget.lead.mobile}' 
                            : widget.lead.mobile,
                        style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink3),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            formLabel('Additional Recipients'),
            const SizedBox(height: 10),

            for (int i = 0; i < _additionalRecipients.length; i++) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    formInput(
                      _additionalRecipients[i].nameCtrl,
                      hint: 'Name',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: formSelect<String>(
                            value: _additionalRecipients[i].countryCode,
                            placeholder: 'Code',
                            options: kCountryCodes,
                            onChanged: (v) => setState(() => _additionalRecipients[i].countryCode = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: formInput(
                            _additionalRecipients[i].mobileCtrl,
                            hint: 'Mobile Number',
                            keyboard: TextInputType.phone,
                            formatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _additionalRecipients[i].dispose();
                              _additionalRecipients.removeAt(i);
                            });
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => setState(() => _additionalRecipients[i].createAsLead = !_additionalRecipients[i].createAsLead),
                      child: Row(
                        children: [
                          Icon(
                            _additionalRecipients[i].createAsLead 
                                ? Icons.check_box_rounded 
                                : Icons.check_box_outline_blank_rounded,
                            size: 18,
                            color: _additionalRecipients[i].createAsLead ? AppColors.evaGreen : AppColors.ink4,
                          ),
                          const SizedBox(width: 6),
                          Text('Create as Lead', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_additionalRecipients.length < 3)
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _additionalRecipients.add(_AdditionalRecipientInput());
                  });
                },
                icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.evaGreenDeep),
                label: Text('Add Recipient', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  side: const BorderSide(color: AppColors.evaGreenDeep, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            const SizedBox(height: 14),
          ],
        ),
      ),
      footer: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 10, top: 12, bottom: 14),
              child: OutlinedButton(
                onPressed: _reset,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                ),
                child: Text('Reset', style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: AppColors.ink2)),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: primaryButton(
              context, 
              _sending ? 'Sending...' : 'Send to ($totalRecipients)', 
              _sending ? () {} : _send, 
              icon: Icons.send_rounded
            ),
          ),
        ],
      ),
    );
  }
}

class SelectTemplateBottomSheet extends StatefulWidget {
  final List<TemplateDto> templates;
  const SelectTemplateBottomSheet({super.key, required this.templates});
  State<SelectTemplateBottomSheet> createState() => _SelectTemplateBottomSheetState();
}

class _SelectTemplateBottomSheetState extends State<SelectTemplateBottomSheet> {
  String _category = 'ALL';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  List<TemplateDto> _fetchedTemplates = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchedTemplates = widget.templates;
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text;
      });
    });
    if (_fetchedTemplates.isEmpty) {
      _loadTemplates();
    }
  }

  Future<void> _loadTemplates() async {
    setState(() => _loading = true);
    try {
      final composeRepo = AppScope.of(context).compose;
      final tpls = await composeRepo.fetchApprovedTemplates();
      if (mounted) {
        setState(() {
          _fetchedTemplates = tpls;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _fetchedTemplates.where((t) {
      if (_category != 'ALL' && !t.category.toUpperCase().contains(_category)) return false;
      if (_searchQuery.isNotEmpty) {
        return t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            t.message.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList();

    return sheetScaffold(
      context,
      title: 'Select template',
      icon: Icons.article_outlined,
      body: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _tab('All', 'ALL'),
                  const SizedBox(width: 8),
                  _tab('Marketing', 'MARKETING'),
                  const SizedBox(width: 8),
                  _tab('Utility', 'UTILITY'),
                  const SizedBox(width: 8),
                  _tab('Authentication', 'AUTHENTICATION'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: formInput(
                _searchCtrl,
                hint: 'Search templates...',
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.evaGreen))
                  : filtered.isEmpty
                      ? Center(
                          child: Text('No templates found', style: AppText.poppins(size: 13.5, color: AppColors.ink4)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, index) {
                            final t = filtered[index];
                            IconData icon = Icons.text_fields_rounded;
                            String typeLabel = t.headerType.toUpperCase();
                            if (t.headerType.toLowerCase() == 'image') {
                              icon = Icons.image_rounded;
                            } else if (t.headerType.toLowerCase() == 'video') {
                              icon = Icons.video_collection_rounded;
                            } else if (t.headerType.toLowerCase() == 'file' || t.headerType.toLowerCase() == 'document') {
                              icon = Icons.description_rounded;
                            }
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.evaGreen50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(icon, color: AppColors.evaGreenDeep, size: 20),
                                ),
                                title: Text(t.name, style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(t.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 12, color: AppColors.ink3)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface2,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(typeLabel, style: AppText.poppins(size: 10, weight: FontWeight.w700, color: AppColors.ink3)),
                                    ),
                                  ],
                                ),
                                trailing: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    color: AppColors.evaGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                                ),
                                onTap: () => Navigator.of(context).pop(t),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, String value) {
    final active = _category == value;
    return GestureDetector(
      onTap: () => setState(() => _category = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.evaGreen : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: AppText.poppins(
            size: 13.5,
            weight: active ? FontWeight.w800 : FontWeight.bold,
            color: active ? AppColors.evaGreenDeep : AppColors.ink3,
          ),
        ),
      ),
    );
  }
}

String firstLetterCapital(String str) {
  if (str.isEmpty) return '';
  return str[0].toUpperCase() + str.substring(1);
}

// ---------------------------------------------------------------------------
// Leads → Settings (Reminders / Configuration / Webhooks / Quick Reply)
// ---------------------------------------------------------------------------

class LeadsSettingsView extends StatefulWidget {
  final int tab;
  final ValueChanged<int>? onChanged;
  const LeadsSettingsView({super.key, this.tab = 0, this.onChanged});
  @override
  State<LeadsSettingsView> createState() => _LeadsSettingsViewState();
}

class _LeadsSettingsViewState extends State<LeadsSettingsView> {
  List<TemplateDto> _approvedTemplates = [];

  // Business Alert State
  bool _businessAlert = true;
  TemplateDto? _businessTemplate;
  Map<String, String> _businessMappings = {};
  bool _businessExpanded = false;
  bool _businessSaving = false;

  // New Lead Creation Alert State
  bool _newLeadAlert = true;
  TemplateDto? _newLeadTemplate;
  Map<String, String> _newLeadMappings = {};
  bool _newLeadExpanded = false;
  bool _newLeadSaving = false;

  // Configuration — loaded from GET /lead-configuration (leadFields array)
  List<Map<String, dynamic>> _leadFields = [];
  bool _cfgLoading = false;
  int _cfgSubTab = 0; // 0 = Lead Fields, 1 = Dropdown Fields
  String _cfgSearch = '';
  // add-field controls
  final TextEditingController _cfgNameCtrl = TextEditingController();
  String _cfgFieldType = 'input'; // input | textarea | select
  // per-dropdown add-option input controllers (keyed by fieldKey)
  final Map<String, TextEditingController> _optionCtrl = {};

  // Real quick replies: (id, title, message). Loaded from /lead-configuration/quick-replies.
  List<({String id, String title, String message})> _quickReplies = [];

  // Webhook state
  String _webhookUrl = '';
  bool _webhookEditMode = false;
  String _webhookEventType = 'All'; // 'All' | 'Custom'
  Map<String, bool> _webhookEvents = {
    'leadCreation': true,
    'leadUpdation': true,
    'leadDeletion': true,
    'convertedToCustomer': true,
  };
  List<Map<String, String>> _webhookHeaders = [{'key': '', 'value': ''}];
  bool _webhookTesting = false;

  // Assignment mode state
  String _assignmentMode = 'manual';
  bool _assignmentLoading = false;

  @override
  void dispose() {
    _cfgNameCtrl.dispose();
    for (final c in _optionCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConfig());
  }

  Future<void> _loadConfig() async {
    final repo = AppScope.of(context).leads;
    final composeRepo = AppScope.of(context).compose;

    // Assignment mode
    try {
      final mode = await repo.fetchAssignmentMode();
      if (mounted) {
        setState(() => _assignmentMode = (mode == 'round_robin') ? 'round_robin' : 'manual');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _assignmentMode = 'manual');
      }
    }

    // Quick replies
    try {
      final qr = await repo.fetchQuickReplies();
      if (mounted) {
        setState(() => _quickReplies = qr.map((q) => (
          id: (q['_id'] ?? q['id'] ?? '').toString(),
          title: (q['title'] ?? '').toString(),
          message: (q['message'] ?? '').toString(),
        )).toList());
      }
    } catch (_) {}

    // Webhook
    try {
      final wh = await repo.fetchWebhook();
      if (mounted) {
        setState(() {
          _webhookUrl = (wh['url'] ?? '').toString();
          _webhookEventType = (wh['eventType'] ?? 'All').toString();
          if (wh['events'] is Map) {
            final ev = wh['events'] as Map;
            _webhookEvents = {
              'leadCreation': ev['leadCreation'] == true,
              'leadUpdation': ev['leadUpdation'] == true,
              'leadDeletion': ev['leadDeletion'] == true,
              'convertedToCustomer': ev['convertedToCustomer'] == true,
            };
          }
          if (wh['headerParameters'] is List) {
            final headers = (wh['headerParameters'] as List).whereType<Map>().map((h) => {
              'key': (h['key'] ?? '').toString(),
              'value': (h['value'] ?? '').toString(),
            }).toList();
            _webhookHeaders = headers.isEmpty ? [{'key': '', 'value': ''}] : headers;
          }
        });
      }
    } catch (_) {}

    // Templates & Alerts
    try {
      final results = await Future.wait([
        composeRepo.fetchApprovedTemplates().catchError((_) => <TemplateDto>[]),
        repo.fetchAlerts().catchError((_) => <String, dynamic>{}),
      ]);
      final tpls = results[0] as List<TemplateDto>;
      final al = results[1] as Map<String, dynamic>;

      TemplateDto? foundBiz;
      Map<String, String> bizMap = {};
      bool bizActive = true;

      final bizConfig = al['reminderConfiguration'] ?? al['businessAlert'];
      if (bizConfig is Map && bizConfig.isNotEmpty) {
        bizActive = bizConfig['active'] != false && bizConfig['enabled'] != false;
        final tid = (bizConfig['templateId'] ?? bizConfig['id'] ?? (bizConfig['template'] is Map ? bizConfig['template']['id'] : '') ?? '').toString();
        final tname = (bizConfig['templateName'] ?? (bizConfig['template'] is Map ? bizConfig['template']['name'] : bizConfig['template']) ?? '').toString();
        foundBiz = tpls.cast<TemplateDto?>().firstWhere(
          (t) => (tid.isNotEmpty && t!.id == tid) || (tname.isNotEmpty && t!.name == tname),
          orElse: () => null,
        );
        final rawMap = bizConfig['variableMappings'] ?? bizConfig['formData']?['variableMappings'];
        if (rawMap is Map) {
          bizMap = Map<String, String>.from(rawMap.map((k, v) => MapEntry(k.toString(), v.toString())));
        }
      }

      TemplateDto? foundLead;
      Map<String, String> leadMap = {};
      bool leadActive = true;

      final leadConfig = al['newLeadCreationAlert'];
      if (leadConfig is Map && leadConfig.isNotEmpty) {
        leadActive = leadConfig['active'] != false && leadConfig['enabled'] != false;
        final tid = (leadConfig['templateId'] ?? leadConfig['id'] ?? (leadConfig['template'] is Map ? leadConfig['template']['id'] : '') ?? '').toString();
        final tname = (leadConfig['templateName'] ?? (leadConfig['template'] is Map ? leadConfig['template']['name'] : leadConfig['template']) ?? '').toString();
        foundLead = tpls.cast<TemplateDto?>().firstWhere(
          (t) => (tid.isNotEmpty && t!.id == tid) || (tname.isNotEmpty && t!.name == tname),
          orElse: () => null,
        );
        final rawMap = leadConfig['variableMappings'] ?? leadConfig['formData']?['variableMappings'];
        if (rawMap is Map) {
          leadMap = Map<String, String>.from(rawMap.map((k, v) => MapEntry(k.toString(), v.toString())));
        }
      }

      if (mounted) {
        setState(() {
          _approvedTemplates = tpls;

          _businessAlert = bizActive;
          _businessTemplate = foundBiz;
          _businessMappings = bizMap;

          _newLeadAlert = leadActive;
          _newLeadTemplate = foundLead;
          _newLeadMappings = leadMap;
        });
      }
    } catch (_) {}

    // Lead fields (for Configuration tab)
    await _reloadFields();
  }

  Future<void> _reloadFields() async {
    if (!mounted) return;
    setState(() => _cfgLoading = true);
    try {
      final fields = await AppScope.of(context).leads.fetchLeadFields();
      if (mounted) setState(() => _leadFields = fields);
    } catch (_) {} finally {
      if (mounted) setState(() => _cfgLoading = false);
    }
  }

  Future<void> _toggleAlert(String alertType, bool active) async {
    final isBiz = alertType == 'reminderConfiguration' || alertType == 'businessAlert';
    final currentActive = isBiz ? _businessAlert : _newLeadAlert;

    if (!active && currentActive) {
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

    setState(() {
      if (isBiz) {
        _businessAlert = active;
      } else {
        _newLeadAlert = active;
      }
    });

    final tpl = isBiz ? _businessTemplate : _newLeadTemplate;
    final map = isBiz ? _businessMappings : _newLeadMappings;

    if (!mounted) return;
    try {
      await AppScope.of(context).leads.saveAlert(alertType, {


        'active': active,
        'enabled': active,
        if (tpl != null) ...{
          'template': {
            'id': tpl.id,
            'name': tpl.name,
            'headerType': tpl.headerType,
            'type': tpl.category,
            'category': tpl.category,
            'message': tpl.message,
          },
          'formData': {'variableMappings': map},
          'variableMappings': map,
        }
      });
    } catch (_) {}
  }

  Future<void> _saveAlertConfig(String alertType) async {
    final isBiz = alertType == 'reminderConfiguration' || alertType == 'businessAlert';
    final tpl = isBiz ? _businessTemplate : _newLeadTemplate;
    final map = isBiz ? _businessMappings : _newLeadMappings;
    final active = isBiz ? _businessAlert : _newLeadAlert;

    if (tpl == null) {
      appToast(context, 'Please select a template first', isError: true);
      return;
    }

    for (final v in tpl.variables) {
      if ((map[v] ?? '').isEmpty) {
        appToast(context, 'Please map variable "$v"', isError: true);
        return;
      }
    }

    setState(() {
      if (isBiz) _businessSaving = true; else _newLeadSaving = true;
    });

    try {
      await AppScope.of(context).leads.saveAlert(alertType, {
        'active': active,
        'enabled': active,
        'status': active ? 'active' : 'inactive',
        'recipientType': isBiz ? 'agent' : 'primary_contact',
        'templateName': tpl.name,
        'templateId': tpl.id,
        'template': {
          'id': tpl.id,
          'name': tpl.name,
          'headerType': tpl.headerType,
          'type': tpl.category,
          'category': tpl.category,
          'message': tpl.message,
          'body': tpl.message,
        },
        'formData': {
          'variableMappings': map,
          'templateName': tpl.name,
          'templateId': tpl.id,
        },
        'variableMappings': map,
      });
      if (mounted) appToast(context, 'Alert configuration saved successfully');
    } catch (e) {
      if (mounted) appToast(context, 'Failed to save alert: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          if (isBiz) _businessSaving = false; else _newLeadSaving = false;
        });
      }
    }
  }

  Future<void> _resetAlertConfig(String alertType) async {
    final isBiz = alertType == 'reminderConfiguration' || alertType == 'businessAlert';
    final alertName = isBiz ? 'Business Alert' : 'New Lead Creation Alert';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Configuration'),
        content: Text('Reset $alertName? This will clear the selected template and settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await AppScope.of(context).leads.deleteAlert(alertType);
      if (mounted) {
        setState(() {
          if (isBiz) {
            _businessTemplate = null;
            _businessMappings = {};
            _businessAlert = true;
          } else {
            _newLeadTemplate = null;
            _newLeadMappings = {};
            _newLeadAlert = true;
          }
        });
        appToast(context, 'Configuration reset successfully');
      }
    } catch (e) {
      if (mounted) appToast(context, 'Failed to reset: $e', isError: true);
    }
  }

  Future<void> _selectTemplateForAlert(String alertType) async {
    final isBiz = alertType == 'reminderConfiguration' || alertType == 'businessAlert';
    final picked = await showAppSheet<TemplateDto>(
      context,
      SelectTemplateBottomSheet(templates: _approvedTemplates),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isBiz) {
          _businessTemplate = picked;
          final prevMap = _businessMappings;
          _businessMappings = {for (final v in picked.variables) v: prevMap[v] ?? ''};
        } else {
          _newLeadTemplate = picked;
          final prevMap = _newLeadMappings;
          _newLeadMappings = {for (final v in picked.variables) v: prevMap[v] ?? ''};
        }
      });
    }
  }

  Future<void> _setAssignmentMode(String mode) async {
    if (_assignmentMode == mode && !_assignmentLoading) return;
    setState(() {
      _assignmentMode = mode;
      _assignmentLoading = true;
    });
    try {
      await AppScope.of(context).leads.saveAssignmentMode(mode);
      if (mounted) {
        appToast(
          context,
          mode == 'round_robin'
              ? 'Round Robin assignment mode activated'
              : 'Manual assignment mode activated',
        );
      }
    } catch (e) {
      if (mounted) appToast(context, 'Failed to save assignment mode: $e');
    } finally {
      if (mounted) setState(() => _assignmentLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _body();
  }

  Widget _body() {
    switch (widget.tab) {
      case 0:
        return _reminders();
      case 1:
        return _configuration();
      case 2:
        return _webhooks();
      case 3:
        return _quickReply();
      case 4:
        return _assignmentModeView();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _reminders() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _alertCard(
            icon: Icons.calendar_today_outlined,
            title: 'Business Alert',
            desc: 'Track and manage all new leads in your system with real-time updates.',
            recipientLabel: 'Agent Contact Number',
            value: _businessAlert,
            onChanged: (v) => _toggleAlert('reminderConfiguration', v),
            template: _businessTemplate,
            variableMappings: _businessMappings,
            onSelectTemplate: () => _selectTemplateForAlert('reminderConfiguration'),
            onSave: () => _saveAlertConfig('reminderConfiguration'),
            onReset: () => _resetAlertConfig('reminderConfiguration'),
            isSaving: _businessSaving,
            expanded: _businessExpanded,
            onToggleExpand: () => setState(() => _businessExpanded = !_businessExpanded),
          ),
          const SizedBox(height: 14),
          _alertCard(
            icon: Icons.event_outlined,
            title: 'New Lead Creation Alert',
            desc: 'Monitor lead progression and send automated updates.',
            recipientLabel: 'Primary Contact',
            value: _newLeadAlert,
            onChanged: (v) => _toggleAlert('newLeadCreationAlert', v),
            template: _newLeadTemplate,
            variableMappings: _newLeadMappings,
            onSelectTemplate: () => _selectTemplateForAlert('newLeadCreationAlert'),
            onSave: () => _saveAlertConfig('newLeadCreationAlert'),
            onReset: () => _resetAlertConfig('newLeadCreationAlert'),
            isSaving: _newLeadSaving,
            expanded: _newLeadExpanded,
            onToggleExpand: () => setState(() => _newLeadExpanded = !_newLeadExpanded),
          ),
        ],
      );




  // ---- Configuration ----
  Widget _configuration() {
    // sub-tab selector
    Widget subTabBar = Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
      child: Row(children: [
        _cfgTabPill('Lead Fields', 0),
        const SizedBox(width: 4),
        _cfgTabPill('Dropdown Fields', 1),
      ]),
    );

    if (_cfgLoading) {
      return Column(children: [
        subTabBar,
        const Expanded(child: Center(child: CircularProgressIndicator())),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        subTabBar,
        const SizedBox(height: 12),
        Expanded(child: _cfgSubTab == 0 ? _leadFieldsTab() : _dropdownFieldsTab()),
      ],
    );
  }

  Widget _cfgTabPill(String label, int i) {
    final active = _cfgSubTab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _cfgSubTab = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))] : null,
          ),
          child: Text(label, style: AppText.poppins(size: 13, weight: active ? FontWeight.w700 : FontWeight.w600, color: active ? AppColors.ink : AppColors.ink3)),
        ),
      ),
    );
  }

  // ---- Lead Fields sub-tab ----
  Widget _leadFieldsTab() {
    final q = _cfgSearch.toLowerCase();
    final visible = _leadFields.where((f) {
      final name = (f['fieldName'] ?? f['name'] ?? '').toString();
      return q.isEmpty || name.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        // Search + Add row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            // Search
            TextField(
              onChanged: (v) => setState(() => _cfgSearch = v),
              style: AppText.poppins(size: 13, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'Search fields...',
                hintStyle: AppText.poppins(size: 13, color: AppColors.ink4),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.ink4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.evaGreen, width: 1.3)),
                filled: true, fillColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: 10),
            // Custom field name
            TextField(
              controller: _cfgNameCtrl,
              style: AppText.poppins(size: 13, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'Custom field name',
                hintStyle: AppText.poppins(size: 13, color: AppColors.ink4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.evaGreen, width: 1.3)),
                filled: true, fillColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: 10),
            // Type dropdown + Add button
            Row(children: [
              // Type selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.evaGreen, width: 1.3)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _cfgFieldType,
                    items: const [
                      DropdownMenuItem(value: 'input', child: Text('Input')),
                      DropdownMenuItem(value: 'textarea', child: Text('Textarea')),
                      DropdownMenuItem(value: 'select', child: Text('Dropdown')),
                    ],
                    onChanged: (v) { if (v != null) setState(() => _cfgFieldType = v); },
                    style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.evaGreenDeep),
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.evaGreenDeep),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // + Add button
              FilledButton(
                onPressed: _addCustomField,
                style: FilledButton.styleFrom(backgroundColor: AppColors.evaGreen, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: Text('+ Add', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.white)),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        // Hint
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Input — e.g. Name, Email, Phone Number.', style: AppText.poppins(size: 11.5, color: AppColors.ink4)),
        ),
        const SizedBox(height: 8),
        // Fields list
        Expanded(
          child: visible.isEmpty
              ? Center(child: Text('No fields found', style: AppText.poppins(size: 13, color: AppColors.ink4)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: visible.length,
                  separatorBuilder: (c, idx) => const SizedBox(height: 8),
                  itemBuilder: (c, idx) => _apiFieldRow(visible[idx], idx),
                ),
        ),
      ],
    );
  }

  Widget _apiFieldRow(Map<String, dynamic> f, int displayIdx) {
    final key = (f['fieldKey'] ?? '').toString();
    final name = (f['fieldName'] ?? f['name'] ?? key).toString();
    final type = (f['fieldType'] ?? 'input').toString();
    final display = f['displayInTable'] == true;
    final mandatory = f['mandatory'] == true;
    final isCustom = key.startsWith('custom_');
    // Always-mandatory keys
    const alwaysMandatory = {'name', 'status', 'source', 'assigned', 'countryCode', 'mobile'};
    final locked = alwaysMandatory.contains(key);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.line)),
      child: Row(children: [
        // Index badge
        Container(
          width: 24, height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(6)),
          child: Text('${displayIdx + 1}', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink4)),
        ),
        const SizedBox(width: 10),
        // Name + type badge
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: type == 'select' ? AppColors.evaGreen50 : AppColors.surface2,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(type == 'select' ? 'Dropdown' : _capitalize(type), style: AppText.poppins(size: 10, weight: FontWeight.w700, color: type == 'select' ? AppColors.evaGreenDeep : AppColors.ink4)),
          ),
        ])),
        // Display toggle
        Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text('Display', style: AppText.poppins(size: 9.5, weight: FontWeight.w600, color: AppColors.ink4)),
          Switch(
            value: display,
            onChanged: locked ? null : (v) => _toggleFieldDisplay(key, f, v),
            activeTrackColor: AppColors.evaGreen,
            activeThumbColor: Colors.white,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
        const SizedBox(width: 4),
        // Required toggle
        Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text('Required', style: AppText.poppins(size: 9.5, weight: FontWeight.w600, color: AppColors.ink4)),
          Switch(
            value: mandatory || locked,
            onChanged: (locked || !display) ? null : (v) => _toggleFieldMandatory(key, f, v),
            activeTrackColor: AppColors.evaGreen,
            activeThumbColor: Colors.white,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
        // Delete (custom fields only)
        if (isCustom) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _deleteCustomField(key),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(padding: EdgeInsets.all(5), child: Icon(Icons.delete_outline_rounded, size: 17, color: AppColors.ink4)),
          ),
        ],
      ]),
    );
  }

  Future<void> _toggleFieldDisplay(String key, Map<String, dynamic> f, bool newVal) async {
    // Optimistic update
    setState(() => f['displayInTable'] = newVal);
    try {
      await AppScope.of(context).leads.updateField(key, {'displayInTable': newVal});
    } catch (e) {
      setState(() => f['displayInTable'] = !newVal);
      if (mounted) AppNav.of(context).toast('Failed to update field');
    }
  }

  Future<void> _toggleFieldMandatory(String key, Map<String, dynamic> f, bool newVal) async {
    setState(() => f['mandatory'] = newVal);
    try {
      await AppScope.of(context).leads.updateField(key, {'mandatory': newVal});
    } catch (e) {
      setState(() => f['mandatory'] = !newVal);
      if (mounted) AppNav.of(context).toast('Failed to update field');
    }
  }

  Future<void> _addCustomField() async {
    final name = _cfgNameCtrl.text.trim();
    if (name.isEmpty) {
      AppNav.of(context).toast('Enter a field name');
      return;
    }
    try {
      await AppScope.of(context).leads.createField({
        'fieldName': name,
        'fieldType': _cfgFieldType,
        'mandatory': false,
        'displayInTable': true,
        if (_cfgFieldType == 'select') 'options': <String>[],
      });
      _cfgNameCtrl.clear();
      setState(() => _cfgFieldType = 'input');
      await _reloadFields();
    } catch (e) {
      if (mounted) AppNav.of(context).toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteCustomField(String key) async {
    try {
      await AppScope.of(context).leads.deleteField(key);
      await _reloadFields();
    } catch (e) {
      if (mounted) AppNav.of(context).toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ---- Dropdown Fields sub-tab ----
  Widget _dropdownFieldsTab() {
    // Only fields with type == 'select'
    final dropdowns = _leadFields.where((f) => (f['fieldType'] ?? '').toString() == 'select').toList();

    if (dropdowns.isEmpty) {
      return const Center(child: Text('No dropdown fields found'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: dropdowns.length,
      separatorBuilder: (c, idx) => const SizedBox(height: 12),
      itemBuilder: (c, idx) {
        final f = dropdowns[idx];
        final key = (f['fieldKey'] ?? '').toString();
        final name = (f['fieldName'] ?? key).toString();
        final opts = ((f['options'] as List?) ?? []).map((o) => o.toString()).toList();
        _optionCtrl.putIfAbsent(key, () => TextEditingController());
        return _dropdownFieldCard(f, key, name, opts);
      },
    );
  }

  Widget _dropdownFieldCard(Map<String, dynamic> f, String key, String name, List<String> opts) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Text(name, style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(999)),
            child: Text('Dropdown', style: AppText.poppins(size: 10.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
          ),
        ]),
        const SizedBox(height: 10),
        // Options chips
        if (opts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('No options yet', style: AppText.poppins(size: 12.5, color: AppColors.ink4)),
          )
        else
          Wrap(spacing: 8, runSpacing: 8, children: opts.map((opt) {
            return Container(
              padding: const EdgeInsets.fromLTRB(11, 6, 6, 6),
              decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.evaGreen200)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(opt, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _removeDropdownOption(f, key, opt),
                  child: const Icon(Icons.close_rounded, size: 14, color: AppColors.evaGreenDeep),
                ),
              ]),
            );
          }).toList()),
        const SizedBox(height: 10),
        // Add option row
        Row(children: [
          Expanded(
            child: TextField(
              controller: _optionCtrl[key],
              style: AppText.poppins(size: 13, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'Add option...',
                hintStyle: AppText.poppins(size: 13, color: AppColors.ink4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.line)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.line)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.evaGreen, width: 1.3)),
                filled: true, fillColor: AppColors.surface2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => _addDropdownOption(f, key),
            style: FilledButton.styleFrom(backgroundColor: AppColors.evaGreen, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Add', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.white)),
          ),
        ]),
      ]),
    );
  }

  Future<void> _addDropdownOption(Map<String, dynamic> f, String key) async {
    final ctrl = _optionCtrl[key];
    final newOpt = ctrl?.text.trim() ?? '';
    if (newOpt.isEmpty) return;
    final current = ((f['options'] as List?) ?? []).map((o) => o.toString()).toList();
    if (current.contains(newOpt)) {
      AppNav.of(context).toast('Option already exists');
      return;
    }
    final updated = [...current, newOpt];
    setState(() {
      f['options'] = updated;
      ctrl?.clear();
    });
    try {
      await AppScope.of(context).leads.updateField(key, {'options': updated});
    } catch (e) {
      setState(() => f['options'] = current);
      if (mounted) AppNav.of(context).toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _removeDropdownOption(Map<String, dynamic> f, String key, String opt) async {
    final current = ((f['options'] as List?) ?? []).map((o) => o.toString()).toList();
    final updated = current.where((o) => o != opt).toList();
    setState(() => f['options'] = updated);
    try {
      await AppScope.of(context).leads.updateField(key, {'options': updated});
    } catch (e) {
      setState(() => f['options'] = current);
      if (mounted) AppNav.of(context).toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ---- Webhooks ----
  Widget _webhooks() {
    final samplePayload = const JsonEncoder.withIndent('  ').convert({
      'event': 'lead_created',
      'timestamp': '2026-06-05T12:34:56Z',
      'data': {
        'leadId': '507f1f77bcf86cd799439011',
        'name': 'John Doe',
        'email': 'john@example.com',
        'mobile': '1234567890',
        'company': 'Example Corp',
        'status': 'New Lead',
      },
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            const Icon(Icons.link_rounded, size: 20, color: AppColors.evaGreenDeep),
            const SizedBox(width: 8),
            Text(
              'Webhook Configuration',
              style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // ── URL ──────────────────────────────────────
        Row(
          children: [
            Text('Webhook URL', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3)),
            Text(' *', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.danger)),
          ],
        ),
        const SizedBox(height: 8),
        _webhookEditMode
            ? TextField(
                controller: TextEditingController(text: _webhookUrl)
                  ..selection = TextSelection.collapsed(offset: _webhookUrl.length),
                onChanged: (v) => setState(() => _webhookUrl = v),
                style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'https://api.example.com/webhook',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.evaGreen, width: 1.5)),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                child: Text(
                  _webhookUrl.isEmpty ? 'Not configured' : _webhookUrl,
                  style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: _webhookUrl.isEmpty ? AppColors.ink4 : AppColors.ink),
                ),
              ),

        const SizedBox(height: 16),

        // ── Events dropdown ───────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: [
                  Text('Events', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3)),
                  Text(' *', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.danger)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: _webhookEditMode ? AppColors.surface : AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _webhookEventType,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All')),
                      DropdownMenuItem(value: 'Custom', child: Text('Custom')),
                    ],
                    onChanged: _webhookEditMode ? (v) {
                      if (v != null) { setState(() {
                        _webhookEventType = v;
                        if (v == 'All') {
                          _webhookEvents = {
                            'leadCreation': true,
                            'leadUpdation': true,
                            'leadDeletion': true,
                            'convertedToCustomer': true,
                          };
                        }
                      }); }
                    } : null,
                    style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
                  ),
                ),
              ),
            ]),
          ),
        ]),

        // ── Custom events checkboxes ───────────────────
        if (_webhookEditMode && _webhookEventType == 'Custom') ...[
          const SizedBox(height: 12),
          Text('Select Events', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final entry in [
              ('leadCreation', 'Lead Creation'),
              ('leadUpdation', 'Lead Updation'),
              ('leadDeletion', 'Lead Deletion'),
              ('convertedToCustomer', 'Converted to Customer'),
            ])
              Row(mainAxisSize: MainAxisSize.min, children: [
                Checkbox(
                  value: _webhookEvents[entry.$1] ?? false,
                  activeColor: AppColors.evaGreen,
                  onChanged: (v) => setState(() => _webhookEvents[entry.$1] = v ?? false),
                ),
                Text(entry.$2, style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink2)),
              ]),
          ]),
        ],

        const SizedBox(height: 18),

        // ── Header Parameters ─────────────────────────
        Row(children: [
          Text('Header Parameters (Optional)', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3)),
          const Spacer(),
          if (_webhookEditMode)
            GestureDetector(
              onTap: () => setState(() => _webhookHeaders.add({'key': '', 'value': ''})),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_rounded, size: 14, color: AppColors.evaGreenDeep),
                  const SizedBox(width: 4),
                  Text('Add', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        for (var i = 0; i < _webhookHeaders.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                flex: 2,
                child: TextField(
                  readOnly: !_webhookEditMode,
                  controller: TextEditingController(text: _webhookHeaders[i]['key'])
                    ..selection = TextSelection.collapsed(offset: (_webhookHeaders[i]['key'] ?? '').length),
                  onChanged: (v) => setState(() => _webhookHeaders[i]['key'] = v),
                  style: AppText.poppins(size: 12.5, color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: 'Header Key',
                    hintStyle: AppText.poppins(size: 12.5, color: AppColors.ink4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.line)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.line)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.evaGreen, width: 1.3)),
                    filled: true,
                    fillColor: _webhookEditMode ? AppColors.surface : AppColors.surface2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  readOnly: !_webhookEditMode,
                  controller: TextEditingController(text: _webhookHeaders[i]['value'])
                    ..selection = TextSelection.collapsed(offset: (_webhookHeaders[i]['value'] ?? '').length),
                  onChanged: (v) => setState(() => _webhookHeaders[i]['value'] = v),
                  style: AppText.poppins(size: 12.5, color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: 'Header Value',
                    hintStyle: AppText.poppins(size: 12.5, color: AppColors.ink4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.line)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.line)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.evaGreen, width: 1.3)),
                    filled: true,
                    fillColor: _webhookEditMode ? AppColors.surface : AppColors.surface2,
                  ),
                ),
              ),
              if (_webhookEditMode && _webhookHeaders.length > 1) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => setState(() => _webhookHeaders.removeAt(i)),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.close_rounded, size: 16, color: AppColors.danger)),
                ),
              ],
            ]),
          ),

        const SizedBox(height: 18),

        // ── Sample Payload ────────────────────────────
        Text('Sample Payload', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: buildSyntaxHighlightJson(samplePayload),
          ),
        ),

        const SizedBox(height: 20),

        // ── Action buttons ────────────────────────────
        Row(children: [
          // Edit / Save
          Expanded(child: _webhookEditMode
              ? FilledButton(
                  onPressed: _saveWebhook,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.evaGreen, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text('Save', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: Colors.white)),
                )
              : FilledButton(
                  onPressed: () => setState(() => _webhookEditMode = true),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.evaGreen, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text('Edit', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: Colors.white)),
                )),
          const SizedBox(width: 8),
          // Test
          Expanded(child: FilledButton(
            onPressed: _webhookTesting ? null : _testWebhook,
            style: FilledButton.styleFrom(backgroundColor: AppColors.evaGreen, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _webhookTesting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Test Webhook', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: Colors.white)),
          )),
          const SizedBox(width: 8),
          // Reset
          Expanded(child: FilledButton(
            onPressed: () => setState(() {
              _webhookUrl = '';
              _webhookEventType = 'All';
              _webhookEvents = {'leadCreation': true, 'leadUpdation': true, 'leadDeletion': true, 'convertedToCustomer': true};
              _webhookHeaders = [{'key': '', 'value': ''}];
              _webhookEditMode = true;
            }),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Reset', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: Colors.white)),
          )),
        ]),
      ],
    );
  }

  Future<void> _saveWebhook() async {
    if (_webhookUrl.trim().isEmpty) {
      AppNav.of(context).toast('Please enter a webhook URL');
      return;
    }
    final validHeaders = _webhookHeaders.where((h) => (h['key'] ?? '').isNotEmpty && (h['value'] ?? '').isNotEmpty).toList();
    final nav = AppNav.of(context);
    try {
      await AppScope.of(context).leads.saveWebhook({
        'url': _webhookUrl.trim(),
        'eventType': _webhookEventType,
        'events': _webhookEventType == 'All'
            ? {'leadCreation': true, 'leadUpdation': true, 'leadDeletion': true, 'convertedToCustomer': true}
            : Map<String, dynamic>.from(_webhookEvents),
        'headerParameters': validHeaders,
      });
      if (mounted) setState(() => _webhookEditMode = false);
      nav.toast('Webhook configuration saved');
    } catch (e) {
      nav.toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _testWebhook() async {
    if (_webhookUrl.trim().isEmpty) {
      AppNav.of(context).toast('Please configure a webhook URL first');
      return;
    }
    final nav = AppNav.of(context);
    setState(() => _webhookTesting = true);
    try {
      await AppScope.of(context).leads.testWebhook();
      nav.toast('Webhook test successful!');
    } catch (e) {
      nav.toast('Webhook test failed');
    } finally {
      if (mounted) setState(() => _webhookTesting = false);
    }
  }

  // ---- Quick Reply ----
  Widget _quickReply() => Column(
        children: [
          // Header bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              const Icon(Icons.chat_outlined, size: 20, color: AppColors.evaGreenDeep),
              const SizedBox(width: 8),
              Text('Quick Reply', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
              const Spacer(),
              GestureDetector(
                onTap: () => _showQuickReplyModal(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.evaGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('Add', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _quickReplies.isEmpty
                ? Center(child: Text('No quick replies yet', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink4)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _quickReplies.length,
                    separatorBuilder: (ctx2, idx) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final q = _quickReplies[i];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.line)),
                        child: Row(children: [
                          Container(
                            width: 40, height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDF3E0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.schedule_rounded, size: 20, color: Color(0xFFF5A623)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(q.title, style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink)),
                            if (q.message.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(q.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 12.5, weight: FontWeight.w500, color: AppColors.ink3, height: 1.35)),
                            ],
                          ])),
                          const SizedBox(width: 8),
                          // Edit
                          GestureDetector(
                            onTap: () => _showQuickReplyModal(existing: q),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.ink3),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Delete
                          GestureDetector(
                            onTap: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppColors.surface,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: Text('Delete Quick Reply', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
                                  content: Text('Are you sure you want to delete this quick reply? This cannot be undone.', style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink2)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: Text('Cancel', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      child: Text('Delete', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.danger)),
                                    ),
                                  ],
                                ),
                              );
                              if (ok != true) return;
                              try {
                                if (q.id.isNotEmpty) await AppScope.of(context).leads.deleteQuickReply(q.id);
                                await _loadConfig();
                              } catch (e) {
                                if (mounted) AppNav.of(context).toast(e.toString().replaceFirst('Exception: ', ''));
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                            ),
                          ),
                        ]),
                      );
                    },
                  ),
          ),
        ],
      );

  Future<void> _showQuickReplyModal({({String id, String title, String message})? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final msgCtrl = TextEditingController(text: existing?.message ?? '');
    final isEdit = existing != null;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEdit ? 'Edit Quick Reply' : 'Add Quick Reply', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Title', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)),
          const SizedBox(height: 6),
          TextField(
            controller: titleCtrl,
            autofocus: true,
            style: AppText.poppins(size: 13.5, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'Enter quick reply title',
              hintStyle: AppText.poppins(size: 13, color: AppColors.ink4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.evaGreen, width: 1.5)),
            ),
          ),
          const SizedBox(height: 14),
          Text('Message', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)),
          const SizedBox(height: 6),
          TextField(
            controller: msgCtrl,
            maxLines: 4,
            style: AppText.poppins(size: 13.5, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'Enter quick reply message',
              hintStyle: AppText.poppins(size: 13, color: AppColors.ink4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.evaGreen, width: 1.5)),
            ),
          ),
        ]),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11), side: const BorderSide(color: AppColors.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Cancel', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3)),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () async {
              final t = titleCtrl.text.trim();
              final m = msgCtrl.text.trim();
              if (t.isEmpty || m.isEmpty) {
                AppNav.of(ctx).toast('Title and message are required');
                return;
              }
              Navigator.of(ctx).pop();
              final repo = AppScope.of(context).leads;
              try {
                if (isEdit && existing.id.isNotEmpty) {
                  await repo.updateQuickReply(existing.id, t, m);
                } else {
                  await repo.createQuickReply(t, m);
                }
                await _loadConfig();
              } catch (e) {
                if (mounted) AppNav.of(context).toast(e.toString().replaceFirst('Exception: ', ''));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.evaGreen, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(isEdit ? 'Save changes' : 'Add reply', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }


  Widget _alertCard({
    required IconData icon,
    required String title,
    required String desc,
    required String recipientLabel,
    required bool value,
    required ValueChanged<bool> onChanged,
    required TemplateDto? template,
    required Map<String, String> variableMappings,
    required VoidCallback onSelectTemplate,
    required VoidCallback onSave,
    required VoidCallback onReset,
    required bool isSaving,
    bool expanded = false,
    VoidCallback? onToggleExpand,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 19, color: AppColors.evaGreenDeep)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink))),
            Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: AppColors.evaGreen, activeThumbColor: Colors.white),
          ]),
          const SizedBox(height: 8),
          Text(desc, style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink3, height: 1.45)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onToggleExpand,
            child: Row(children: [
              Text('Configure templates & follow-ups', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
              Icon(expanded ? Icons.expand_less_rounded : Icons.chevron_right_rounded, size: 18, color: AppColors.evaGreenDeep),
            ]),
          ),
          if (expanded) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink2),
                      children: [
                        const TextSpan(text: 'Recipient Number: '),
                        TextSpan(
                          text: recipientLabel,
                          style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink),
                          children: const [
                            TextSpan(text: 'Select Template '),
                            TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: onSelectTemplate,
                        icon: const Icon(Icons.cloud_upload_outlined, size: 16, color: AppColors.evaGreenDeep),
                        label: Text(
                          template == null ? 'Select Template' : 'Change Template',
                          style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          side: const BorderSide(color: AppColors.evaGreenDeep),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        ),
                      ),
                    ],
                  ),
                  if (template != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.evaGreen50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  template.name,
                                  style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                template.category.toUpperCase(),
                                style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            template.message,
                            style: AppText.poppins(size: 12.5, color: AppColors.ink2, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    if (template.variables.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Variable Mappings', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)),
                      const SizedBox(height: 8),
                      for (final v in template.variables) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 90,
                                child: Text(
                                  '{{$v}} :',
                                  style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2),
                                ),
                              ),
                              Expanded(
                                child: formSelect<String>(
                                  value: (variableMappings[v] ?? '').isNotEmpty ? variableMappings[v] : null,
                                  placeholder: 'Select lead variable',
                                  options: const [
                                    ('name', 'Lead Name'),
                                    ('mobile', 'Mobile Number'),
                                    ('email', 'Email Address'),
                                    ('company', 'Company'),
                                    ('status', 'Lead Status'),
                                    ('source', 'Lead Source'),
                                    ('position', 'Position'),
                                    ('address', 'Address'),
                                    ('city', 'City'),
                                    ('country', 'Country'),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      variableMappings[v] = val;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onReset,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            side: const BorderSide(color: AppColors.line),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Reset', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.danger)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: isSaving ? null : onSave,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.evaGreen,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            isSaving ? 'Saving...' : 'Save',
                            style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.white),
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
    );
  }

  Widget _assignmentModeView() {
    final isManual = _assignmentMode == 'manual';
    final isRoundRobin = _assignmentMode == 'round_robin';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lead Assignment Mode',
                style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose how incoming leads are assigned to agents. Only one mode can be active at a time.',
                style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink3, height: 1.45),
              ),
              const SizedBox(height: 20),
              
              // Manual Mode Card
              _assignmentOptionCard(
                title: 'Manual Mode',
                description: 'Agents are assigned manually from the lead detail or during import. No automatic distribution.',
                isActive: isManual,
                onTap: () => _setAssignmentMode('manual'),
                onChanged: (v) => _setAssignmentMode(v ? 'manual' : 'round_robin'),
              ),
              
              const SizedBox(height: 14),

              // Round Robin Method Card
              _assignmentOptionCard(
                title: 'Round Robin Method',
                description: 'All leads are automatically distributed evenly across all eligible agents (excludes superadmin). Agents must have Leads access enabled.',
                isActive: isRoundRobin,
                onTap: () => _setAssignmentMode('round_robin'),
                onChanged: (v) => _setAssignmentMode(v ? 'round_robin' : 'manual'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _assignmentOptionCard({
    required String title,
    required String description,
    required bool isActive,
    required VoidCallback onTap,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.evaGreen : AppColors.line,
            width: isActive ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: AppColors.ink),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.evaGreen,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Active',
                            style: AppText.poppins(size: 10.5, weight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isActive,
                  onChanged: onChanged,
                  activeTrackColor: AppColors.evaGreen,
                  activeThumbColor: Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: AppText.poppins(size: 12.5, weight: FontWeight.w500, color: AppColors.ink3, height: 1.4),
            ),
          ],
        ),
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
