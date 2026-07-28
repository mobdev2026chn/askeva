import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/app_scope.dart';
import '../api/dto.dart';
import '../data/models.dart';
import '../data/mock_data.dart';
import '../shell/app_nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'common.dart';
import 'dashboard_sheets.dart' show showAppSheet, appToast;

// Built-in lead statuses (mirrors the design's dropdown-driven set).
const List<String> kLeadStatuses = ['New', 'Hot', 'Warm', 'Cold', 'Customer'];

// ---------------------------------------------------------------------------
// Filter model
// ---------------------------------------------------------------------------

class LeadFilter {
  final String? status;
  final String? source;
  final String? company;
  final String? assigned;
  final String? industry;
  final String timePeriod;
  final List<DateTime>? dateRange;

  const LeadFilter({
    this.status,
    this.source,
    this.company,
    this.assigned,
    this.industry,
    this.timePeriod = 'All time',
    this.dateRange,
  });

  static const empty = LeadFilter();

  int get activeCount => [status, source, company, assigned, industry].where((e) => e != null).length + 
      (timePeriod != 'All time' ? 1 : 0) + 
      (dateRange != null ? 1 : 0);

  bool matches(LeadDto l) {
    if (status != null && l.status.label.toLowerCase() != status!.toLowerCase()) return false;
    if (source != null && l.source != source) return false;
    if (company != null && l.company != company) return false;
    if (assigned != null && (l.assignedTo ?? 'Unassigned') != assigned) return false;

    if (dateRange != null && dateRange!.length == 2) {
      if (l.createdAt == null) return false;
      final start = DateTime(dateRange![0].year, dateRange![0].month, dateRange![0].day);
      final end = DateTime(dateRange![1].year, dateRange![1].month, dateRange![1].day, 23, 59, 59);
      if (l.createdAt!.isBefore(start) || l.createdAt!.isAfter(end)) return false;
    }

    if (timePeriod != 'All time') {
      if (l.createdAt == null) return false;
      final now = DateTime.now();
      final limit = switch (timePeriod) {
        'Today' => DateTime(now.year, now.month, now.day),
        'Last 7 days' => now.subtract(const Duration(days: 7)),
        'Last 30 days' => now.subtract(const Duration(days: 30)),
        'Last 90 days' => now.subtract(const Duration(days: 90)),
        _ => DateTime(1970),
      };
      if (l.createdAt!.isBefore(limit)) return false;
    }
    return true;
  }

  LeadFilter copyWith({
    Object? status = _u,
    Object? source = _u,
    Object? company = _u,
    Object? assigned = _u,
    Object? industry = _u,
    String? timePeriod,
    Object? dateRange = _u,
  }) {
    return LeadFilter(
      status: status == _u ? this.status : status as String?,
      source: source == _u ? this.source : source as String?,
      company: company == _u ? this.company : company as String?,
      assigned: assigned == _u ? this.assigned : assigned as String?,
      industry: industry == _u ? this.industry : industry as String?,
      timePeriod: timePeriod ?? this.timePeriod,
      dateRange: dateRange == _u ? this.dateRange : dateRange as List<DateTime>?,
    );
  }
}

const Object _u = Object();

// ---------------------------------------------------------------------------
// Shared sheet primitives
// ---------------------------------------------------------------------------

Widget sheetScaffold(BuildContext context, {required String title, required IconData icon, required Widget body, Widget? footer}) {
  return SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.only(bottom: footer == null ? 12.0 : 0.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(children: [
              Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: AppColors.evaGreenDeep)),
              const SizedBox(width: 11),
              Expanded(child: Text(title, style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink))),
              InkWell(onTap: () => Navigator.of(context).maybePop(), borderRadius: BorderRadius.circular(10), child: Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.close_rounded, size: 18, color: AppColors.ink2))),
            ]),
          ),
          Flexible(child: body),
          if (footer != null) footer,
        ],
      ),
    ),
  );
}

Widget formLabel(String t) => Padding(padding: const EdgeInsets.only(bottom: 7, top: 14), child: Text(t, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)));

Widget formInput(TextEditingController c, {String? hint, TextInputType? keyboard, int maxLines = 1, List<TextInputFormatter>? formatters, ValueChanged<String>? onChanged}) => TextField(
      controller: c,
      keyboardType: keyboard,
      maxLines: maxLines,
      inputFormatters: formatters,
      onChanged: onChanged,
      style: AppText.poppins(size: 14.5, weight: FontWeight.w600, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.ink4),
        filled: true,
        fillColor: AppColors.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
      ),
    );

Widget formSelect<T>({required T? value, required String placeholder, required List<(T, String)> options, required ValueChanged<T> onChanged}) {
  return Builder(builder: (context) {
    final label = value == null ? placeholder : (options.where((o) => o.$1 == value).isEmpty ? placeholder : options.firstWhere((o) => o.$1 == value).$2);
    return PopupMenuButton<T>(
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(maxHeight: 360),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [for (final o in options) PopupMenuItem(value: o.$1, child: Text(o.$2))],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.line)),
        child: Row(children: [
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 14, weight: FontWeight.w600, color: value == null ? AppColors.ink4 : AppColors.ink))),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.ink3),
        ]),
      ),
    );
  });
}

Widget primaryButton(BuildContext context, String label, VoidCallback onTap, {IconData? icon}) => Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.evaGradient, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Color(0x4D3DC838), blurRadius: 16, offset: Offset(0, 7))]),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: onTap,
              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Icon(icon, size: 18, color: Colors.white), const SizedBox(width: 8)], Text(label, style: AppText.poppins(size: 15, weight: FontWeight.w800, color: Colors.white))])),
            ),
          ),
        ),
      ),
    );

// ---------------------------------------------------------------------------
// New / Edit Lead form
// ---------------------------------------------------------------------------

Future<bool?> showLeadForm(
  BuildContext context, {
  LeadDto? lead,
  required List<String> companies,
  required List<String> sources,
  required List<String> agents,
}) =>
    showAppSheet<bool>(context, _LeadForm(lead: lead, companies: companies, sources: sources, agents: agents));

class _LeadForm extends StatefulWidget {
  final LeadDto? lead;
  final List<String> companies, sources, agents;
  const _LeadForm({this.lead, required this.companies, required this.sources, required this.agents});
  @override
  State<_LeadForm> createState() => _LeadFormState();
}

class _LeadFormState extends State<_LeadForm> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _dropdownValues = {};
  final List<String> _tags = [];
  final TextEditingController _tagInputCtrl = TextEditingController();
  List<Map<String, dynamic>> _fields = [];
  bool _loadingFields = true;
  bool _saving = false;
  bool _newLeadAlert = true;

  List<String> _dynamicAgents = [];
  List<String> _dynamicCompanies = [];
  List<String> _dynamicSources = [];

  bool get _isEdit => widget.lead != null && widget.lead!.id.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initBuiltinControllers();
    _loadFields();
  }

  void _initBuiltinControllers() {
    final builtins = [
      ('Name', 'name'),
      ('Company', 'company'),
      ('Email', 'email'),
      ('Position', 'position'),
      ('Mobile', 'mobile'),
      ('Address', 'address'),
      ('City', 'city'),
      ('Country', 'country'),
      ('Website', 'website'),
      ('Lead Value', 'value'),
      ('Description', 'description'),
    ];
    for (final b in builtins) {
      final key = b.$2;
      if (!_controllers.containsKey(key)) {
        _controllers[key] = TextEditingController(text: getInitialValue(b.$1, key));
      }
    }
    _dropdownValues['countryCode'] = (widget.lead?.countryCode.isNotEmpty == true) ? widget.lead!.countryCode : '+91';
    _dropdownValues['status'] = (widget.lead?.statusRaw.isNotEmpty == true) ? widget.lead!.statusRaw : 'New';
    _dropdownValues['source'] = (widget.lead?.source.isNotEmpty == true) ? widget.lead!.source : 'Business Card';
    _dropdownValues['assigned'] = widget.lead?.assignedTo;
    _dropdownValues['company'] = (widget.lead?.company.isNotEmpty == true) ? widget.lead!.company : null;
  }

  String getFieldJsonKey(String fieldName) {
    final fn = fieldName.trim().toLowerCase();
    if (fn == 'name' || fn == 'full name' || fn == 'contact name' || fn == 'lead name') return 'name';
    if (fn == 'company' || fn == 'company name' || fn == 'organization' || fn == 'org') return 'company';
    if (fn == 'email' || fn == 'email address') return 'email';
    if (fn == 'status' || fn == 'lead status') return 'status';
    if (fn == 'source' || fn == 'lead source') return 'source';
    if (fn.contains('assign')) return 'assigned';
    if (fn == 'position' || fn == 'role' || fn == 'designation' || fn == 'job title' || fn == 'title') return 'position';
    if (fn.contains('country code') || fn == 'countrycode' || fn == 'country_code') return 'countryCode';
    if (fn == 'mobile' || fn == 'phone' || fn == 'whatsapp' || fn == 'contact' || fn == 'mobile number' || fn == 'phone number') return 'mobile';
    if (fn == 'address' || fn == 'full address' || fn == 'street address') return 'address';
    if (fn == 'city') return 'city';
    if (fn == 'country') return 'country';
    if (fn == 'website' || fn == 'web' || fn == 'website url') return 'website';
    if (fn.contains('value')) return 'value';
    if (fn == 'tags') return 'tags';
    if (fn == 'description' || fn == 'notes' || fn == 'note') return 'description';

    return 'cf_${fn.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '')}';
  }

  String getInitialValue(String fieldName, String key) {
    if (widget.lead == null) return '';
    final l = widget.lead!;
    final nameLower = fieldName.trim().toLowerCase();
    final keyLower = key.trim().toLowerCase();

    if (keyLower == 'name' || nameLower == 'name' || nameLower == 'full name' || nameLower == 'lead name') return l.name;
    if (keyLower == 'company' || nameLower == 'company' || nameLower == 'company name' || nameLower == 'organization') return l.company;
    if (keyLower == 'email' || nameLower == 'email' || nameLower == 'email address') return l.email;
    if (keyLower == 'status' || nameLower == 'status' || nameLower == 'lead status') return l.statusRaw.isNotEmpty ? l.statusRaw : 'New';
    if (keyLower == 'source' || nameLower == 'source' || nameLower == 'lead source') return l.source.isNotEmpty ? l.source : 'Business Card';
    if (keyLower.contains('assign') || nameLower.contains('assign')) return l.assignedTo ?? '';
    if (keyLower == 'position' || nameLower == 'position' || nameLower == 'role' || nameLower == 'designation' || nameLower == 'job title' || nameLower == 'title') return l.position;
    if (keyLower == 'countrycode' || keyLower == 'country_code' || nameLower.contains('country code')) {
      return l.countryCode.isNotEmpty ? l.countryCode : '+91';
    }
    if (keyLower == 'mobile' || keyLower == 'phone' || nameLower == 'mobile' || nameLower == 'phone' || nameLower == 'mobile number' || nameLower == 'phone number' || nameLower == 'whatsapp') return l.mobile;
    if (keyLower == 'address' || nameLower == 'address' || nameLower == 'full address') return l.address;
    if (keyLower == 'city' || nameLower == 'city') return l.city;
    if (keyLower == 'country' || nameLower == 'country') return l.country;
    if (keyLower == 'website' || nameLower == 'website' || nameLower == 'web') return l.website;
    if (keyLower == 'value' || nameLower.contains('value')) return l.value?.toString() ?? '';
    if (keyLower == 'description' || nameLower == 'description' || nameLower == 'notes' || nameLower == 'note') return l.description;

    return l.rawJson?[key]?.toString() ?? l.rawJson?[fieldName]?.toString() ?? '';
  }

  List<Map<String, dynamic>> _defaultFallbackFields() => [
    {'fieldName': 'Name', 'fieldKey': 'name', 'fieldType': 'input', 'displayInTable': true, 'mandatory': true},
    {'fieldName': 'Company', 'fieldKey': 'company', 'fieldType': 'input', 'displayInTable': true, 'mandatory': false},
    {'fieldName': 'Email', 'fieldKey': 'email', 'fieldType': 'input', 'displayInTable': true, 'mandatory': false},
    {'fieldName': 'Position', 'fieldKey': 'position', 'fieldType': 'input', 'displayInTable': true, 'mandatory': false},
    {'fieldName': 'Mobile', 'fieldKey': 'mobile', 'fieldType': 'input', 'displayInTable': true, 'mandatory': true},
    {'fieldName': 'Country Code', 'fieldKey': 'countryCode', 'fieldType': 'select', 'displayInTable': true, 'mandatory': true, 'options': ['+91', '+1', '+44', '+971', '+61', '+65']},
    {'fieldName': 'Address', 'fieldKey': 'address', 'fieldType': 'input', 'displayInTable': true, 'mandatory': false},
    {'fieldName': 'City', 'fieldKey': 'city', 'fieldType': 'input', 'displayInTable': true, 'mandatory': false},
    {'fieldName': 'Country', 'fieldKey': 'country', 'fieldType': 'input', 'displayInTable': true, 'mandatory': false},
    {'fieldName': 'Website', 'fieldKey': 'website', 'fieldType': 'input', 'displayInTable': true, 'mandatory': false},
    {'fieldName': 'Source', 'fieldKey': 'source', 'fieldType': 'select', 'displayInTable': true, 'mandatory': true, 'options': ['Business Card', 'Manual', 'Website', 'Referral']},
    {'fieldName': 'Status', 'fieldKey': 'status', 'fieldType': 'select', 'displayInTable': true, 'mandatory': true, 'options': ['New', 'Contacted', 'Qualified', 'Lost']},
    {'fieldName': 'Assigned', 'fieldKey': 'assigned', 'fieldType': 'select', 'displayInTable': true, 'mandatory': false},
    {'fieldName': 'Description', 'fieldKey': 'description', 'fieldType': 'textarea', 'displayInTable': true, 'mandatory': false},
  ];

  Future<void> _loadFields() async {
    List<Map<String, dynamic>> res = [];
    try {
      res = await AppScope.of(context).leads.fetchLeadFields();
    } catch (_) {}

    if (res.isEmpty) {
      res = _defaultFallbackFields();
    }

    if (!mounted) return;
      
    // Load agents dynamically (Only lead-accessed active agents)
    List<String> agentsList = [];
    try {
      final agentsRepo = AppScope.of(context).agents;
      final agentsData = await agentsRepo.fetchAgents();
      final rolesData = await agentsRepo.fetchRoles().catchError((_) => <Map<String, dynamic>>[]);
      
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

      for (final a in agentsData) {
        final email = (a['email'] ?? a['username'] ?? a['name'] ?? '').toString().trim();
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
          if (email.isNotEmpty && !agentsList.contains(email)) {
            agentsList.add(email);
          }
        }
      }

      if (widget.lead?.assignedTo != null && widget.lead!.assignedTo!.isNotEmpty) {
        if (!agentsList.contains(widget.lead!.assignedTo!)) {
          agentsList.add(widget.lead!.assignedTo!);
        }
      }

      if (agentsList.isEmpty) {
        for (final a in agentsData) {
          final email = (a['email'] ?? a['username'] ?? '').toString().trim();
          final status = (a['status'] ?? '').toString().toLowerCase();
          if (email.isNotEmpty && status != 'inactive' && status != 'disabled' && status != 'suspended') {
            agentsList.add(email);
          }
        }
      }
    } catch (_) {}
    
    // Load companies and sources dynamically from leadFields options
    List<String> companiesList = [];
    try {
      Map<String, dynamic>? companyField;
      for (final e in res) {
        final keyStr = (e['fieldKey'] ?? e['fieldName'] ?? e['name'] ?? '').toString().toLowerCase();
        if (keyStr == 'company') {
          companyField = e;
          break;
        }
      }
      if (companyField != null) {
        companiesList = (companyField['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
      }
    } catch (_) {}
    
    List<String> sourcesList = [];
    try {
      Map<String, dynamic>? sourceField;
      for (final e in res) {
        final keyStr = (e['fieldKey'] ?? e['fieldName'] ?? e['name'] ?? '').toString().toLowerCase();
        if (keyStr == 'source') {
          sourceField = e;
          break;
        }
      }
      if (sourceField != null) {
        sourcesList = (sourceField['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _fields = res;
        _dynamicAgents = agentsList;
        _dynamicCompanies = companiesList;
        _dynamicSources = sourcesList;
        for (final f in _fields) {
          final name = (f['fieldName'] ?? f['name'] ?? '').toString();
          if (name.isEmpty) continue;
          final key = getFieldJsonKey(name);
          final type = (f['fieldType'] ?? 'input').toString().toLowerCase();

          final initial = getInitialValue(name, key);
          if (type == 'select' || type == 'dropdown') {
            if (initial.isNotEmpty) {
              _dropdownValues[key] = initial;
            }
          } else {
            if (!_controllers.containsKey(key)) {
              _controllers[key] = TextEditingController(text: initial);
            } else if (initial.isNotEmpty && _controllers[key]!.text.isEmpty) {
              _controllers[key]!.text = initial;
            }
          }
        }

        if (widget.lead != null && widget.lead!.tags.isNotEmpty) {
          _tags.addAll(widget.lead!.tags);
        }

        if (_dropdownValues['countryCode'] == null || _dropdownValues['countryCode']!.isEmpty) {
          _dropdownValues['countryCode'] = '+91';
        }
        if (_dropdownValues['status'] == null || _dropdownValues['status']!.isEmpty) {
          _dropdownValues['status'] = 'New';
        }

        _loadingFields = false;
      });
    }
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    _tagInputCtrl.dispose();
    super.dispose();
  }

  bool _isFieldShown(String name) {
    final f = _fields.firstWhere((e) => (e['fieldName'] ?? e['name'] ?? '') == name, orElse: () => const {});
    if (f.isEmpty) return true;
    return f['displayInTable'] == true;
  }

  bool _isFieldRequired(String name) {
    final n = name.trim().toLowerCase();
    if (n == 'website' || n == 'website url' || n == 'web') return false;
    if (n == 'description' || n == 'description *') return true;
    final f = _fields.firstWhere((e) => (e['fieldName'] ?? e['name'] ?? '') == name, orElse: () => const {});
    if (f.isEmpty) return false;
    return f['mandatory'] == true;
  }

  Future<void> _save() async {
    final nameVal = _controllers['name']?.text.trim() ?? '';
    final mobileVal = _controllers['mobile']?.text.trim() ?? '';
    final codeVal = _dropdownValues['countryCode'] ?? '';
    final assignedVal = _dropdownValues['assigned'] ?? '';
    final statusVal = _dropdownValues['status'] ?? '';
    final sourceVal = _dropdownValues['source'] ?? '';
    final descVal = _controllers['description']?.text.trim() ?? '';

    if (_isFieldShown('Name') && _isFieldRequired('Name') && nameVal.isEmpty) {
      appToast(context, 'Enter the lead name');
      return;
    }
    if (_isFieldShown('Description') && _isFieldRequired('Description') && descVal.isEmpty) {
      appToast(context, 'Enter the description');
      return;
    }
    if (_isFieldShown('Mobile')) {
      if (_isFieldRequired('Mobile') && mobileVal.isEmpty) {
        appToast(context, 'Enter a valid mobile number');
        return;
      }
      if (mobileVal.isNotEmpty) {
        String digitsOnly = mobileVal.replaceAll(RegExp(r'[^\d]'), '');
        // Auto-sanitize country code prefixes if concatenated into mobile string
        if (codeVal == '+91' && digitsOnly.length == 12 && digitsOnly.startsWith('91')) {
          digitsOnly = digitsOnly.substring(2);
          _controllers['mobile']?.text = digitsOnly;
        } else if (codeVal == '+1' && digitsOnly.length == 11 && digitsOnly.startsWith('1')) {
          digitsOnly = digitsOnly.substring(1);
          _controllers['mobile']?.text = digitsOnly;
        } else if (codeVal == '+44' && digitsOnly.length == 12 && digitsOnly.startsWith('44')) {
          digitsOnly = digitsOnly.substring(2);
          _controllers['mobile']?.text = digitsOnly;
        } else if (codeVal == '+971' && digitsOnly.length == 12 && digitsOnly.startsWith('971')) {
          digitsOnly = digitsOnly.substring(3);
          _controllers['mobile']?.text = digitsOnly;
        } else if (codeVal == '+61' && digitsOnly.length == 11 && digitsOnly.startsWith('61')) {
          digitsOnly = digitsOnly.substring(2);
          _controllers['mobile']?.text = digitsOnly;
        } else if (codeVal == '+65' && digitsOnly.length == 10 && digitsOnly.startsWith('65')) {
          digitsOnly = digitsOnly.substring(2);
          _controllers['mobile']?.text = digitsOnly;
        }

        if (codeVal == '+91' && digitsOnly.length != 10) {
          appToast(context, 'Enter a valid 10-digit mobile number for India');
          return;
        } else if (codeVal == '+1' && digitsOnly.length != 10) {
          appToast(context, 'Enter a valid 10-digit mobile number for USA');
          return;
        } else if (codeVal == '+44' && (digitsOnly.length < 10 || digitsOnly.length > 11)) {
          appToast(context, 'Enter a valid 10 or 11-digit mobile number for UK');
          return;
        } else if (codeVal == '+971' && digitsOnly.length != 9) {
          appToast(context, 'Enter a valid 9-digit mobile number for UAE');
          return;
        } else if (codeVal == '+61' && digitsOnly.length != 9) {
          appToast(context, 'Enter a valid 9-digit mobile number for Australia');
          return;
        } else if (codeVal == '+65' && digitsOnly.length != 8) {
          appToast(context, 'Enter a valid 8-digit mobile number for Singapore');
          return;
        } else if (digitsOnly.length < 7 || digitsOnly.length > 15) {
          appToast(context, 'Enter a valid mobile number (7-15 digits)');
          return;
        }
      }
    }
    if (_isFieldShown('Assigned') && _isFieldRequired('Assigned') && assignedVal.isEmpty) {
      appToast(context, 'Select an assigned person');
      return;
    }
    if (assignedVal.isEmpty && statusVal != 'New' && statusVal.isNotEmpty) {
      appToast(context, 'Assign an agent before setting a status');
      return;
    }
    if (_isFieldShown('Status') && _isFieldRequired('Status') && statusVal.isEmpty) {
      appToast(context, 'Select a status');
      return;
    }
    if (_isFieldShown('Source') && _isFieldRequired('Source') && sourceVal.isEmpty) {
      appToast(context, 'Select a source');
      return;
    }
    if (_isFieldShown('Country Code') && _isFieldRequired('Country Code') && codeVal.isEmpty) {
      appToast(context, 'Select a country code');
      return;
    }

    final builtinsMapping = [
      ('Website', 'website', 'website URL'),
      ('Email', 'email', 'email address'),
      ('Company', 'company', 'company'),
      ('Position', 'position', 'position'),
      ('Address', 'address', 'address'),
      ('City', 'city', 'city'),
      ('Lead Value', 'value', 'lead value'),
      ('Country', 'country', 'country'),
      ('Description', 'description', 'description'),
    ];

    for (final opt in builtinsMapping) {
      final fName = opt.$1;
      final fKey = opt.$2;
      final label = opt.$3;
      if (_isFieldShown(fName) && _isFieldRequired(fName)) {
        final compText = _controllers['company']?.text.trim() ?? '';
        final val = fKey == 'company' ? (compText.isNotEmpty ? compText : _dropdownValues['company']) : _controllers[fKey]?.text.trim();
        if (val == null || val.isEmpty) {
          appToast(context, 'Enter $label');
          return;
        }
      }
    }

    final builtins = ["Name", "Full Name", "Company", "Company Name", "Email", "Status", "Source", "Assigned", "Position", "Designation", "Job Title", "Role", "Country Code", "Mobile", "Mobile Number", "Phone", "Product", "Address", "City", "Country", "Website", "Lead Value", "Tags", "Description"];
    for (final f in _fields) {
      final name = (f['fieldName'] ?? f['name'] ?? '').toString();
      if (builtins.contains(name)) continue;
      final key = getFieldJsonKey(name);
      if (f['displayInTable'] == true && f['mandatory'] == true) {
        final isSelect = (f['fieldType'] ?? '') == 'select';
        final val = isSelect ? _dropdownValues[key] : _controllers[key]?.text.trim();
        if (val == null || val.isEmpty) {
          appToast(context, 'Enter $name');
          return;
        }
      }
    }

    AppNav? nav;
    try {
      nav = AppNav.of(context);
    } catch (_) {}
    final repo = AppScope.of(context).leads;
    final navigator = Navigator.of(context);
    setState(() => _saving = true);

    final cleanCode = codeVal.replaceAll('+', '').trim();
    final rawCombined = mobileVal.startsWith(cleanCode) ? mobileVal : '$cleanCode$mobileVal';
    final cleanMobile = formatCleanMobileNumber(rawCombined.isNotEmpty ? rawCombined : mobileVal);

    final body = <String, dynamic>{
      'name': nameVal,
      'mobile': cleanMobile,
      'status': statusVal.isEmpty ? 'New' : statusVal,
      'countryCode': cleanCode.isEmpty ? '91' : cleanCode,
      if (sourceVal.isNotEmpty) 'source': sourceVal,
      if (assignedVal.isNotEmpty) 'assigned': assignedVal,
    };

    void setVal(String fieldName, String key, dynamic value) {
      if (_isFieldShown(fieldName)) {
        if (value != null) body[key] = value;
      } else if (widget.lead != null) {
        final oldVal = widget.lead!.rawJson?[key];
        if (oldVal != null) body[key] = oldVal;
      }
    }

    final companyText = _controllers['company']?.text.trim() ?? '';
    final companyVal = companyText.isNotEmpty ? companyText : _dropdownValues['company'];
    setVal('Company', 'company', companyVal);
    setVal('Position', 'position', _controllers['position']?.text.trim());
    setVal('Email', 'email', _controllers['email']?.text.trim());
    setVal('Address', 'address', _controllers['address']?.text.trim());
    setVal('Website', 'website', _controllers['website']?.text.trim());
    setVal('City', 'city', _controllers['city']?.text.trim());
    final valText = _controllers['value']?.text.trim() ?? _controllers['leadValue']?.text.trim() ?? '';
    final parsedVal = valText.isNotEmpty ? double.tryParse(valText) : null;
    if (parsedVal != null) {
      body['value'] = parsedVal;
      body['leadValue'] = parsedVal;
      body['lead_value'] = parsedVal;
    } else if (widget.lead != null && widget.lead!.value != null) {
      final oldVal = widget.lead!.value;
      body['value'] = oldVal;
      body['leadValue'] = oldVal;
      body['lead_value'] = oldVal;
    }
    setVal('Country', 'country', _controllers['country']?.text.trim());
    setVal('Description', 'description', _controllers['description']?.text.trim());
    setVal('Tags', 'tags', _tags);

    for (final f in _fields) {
      final name = (f['fieldName'] ?? f['name'] ?? '').toString();
      if (builtins.contains(name)) continue;
      final key = getFieldJsonKey(name);
      final isSelect = (f['fieldType'] ?? '') == 'select';
      final val = isSelect ? _dropdownValues[key] : _controllers[key]?.text.trim();
      
      if (f['displayInTable'] == true) {
        if (val != null) body[key] = val;
      } else if (widget.lead != null) {
        final oldVal = widget.lead!.rawJson?[key];
        if (oldVal != null) body[key] = oldVal;
      }
    }

    try {
      if (_isEdit) {
        await repo.updateLead(widget.lead!.id, body);
      } else {
        final existingLeadsPage = await repo.fetchLeads(limit: 100).catchError((_) => LeadsPage([], 0));
        final cleanDigits = mobileVal.replaceAll(RegExp(r'[^\d]'), '');
        final match = cleanDigits.isNotEmpty && existingLeadsPage.leads.any((l) {
          final existingDigits = l.mobile.replaceAll(RegExp(r'[^\d]'), '');
          if (cleanDigits.length >= 7 && existingDigits.length >= 7) {
            return existingDigits == cleanDigits || existingDigits.endsWith(cleanDigits) || cleanDigits.endsWith(existingDigits);
          }
          return existingDigits == cleanDigits;
        });
        if (match) {
          if (!mounted) return;
          setState(() => _saving = false);
          appToast(context, 'Lead with mobile $mobileVal already exists');
          return;
        }
        await repo.createLead(body);
      }
      if (!mounted) return;
      navigator.pop(true);
      if (nav != null) {
        nav.toast(_isEdit ? 'Lead updated' : 'Lead created');
      } else {
        appToast(context, _isEdit ? 'Lead updated' : 'Lead created');
      }
    } catch (e) {
      if (!_isEdit && (sourceVal.toLowerCase().contains('card') || sourceVal.toLowerCase().contains('business'))) {
        try {
          await repo.saveOfflineCard(body);
          if (!mounted) return;
          navigator.pop(true);
          appToast(context, '🎴 Business card saved offline locally! Will auto-sync when online.', isSuccess: true);
          return;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() => _saving = false);
      final errMsg = e.toString().replaceFirst('Exception: ', '');
      if (nav != null) {
        nav.toast(errMsg);
      } else {
        appToast(context, errMsg);
      }
    }
  }

  final List<(String, String)> kCountryCodes = [
    ('+91', '+91 (India)'),
    ('+1', '+1 (USA)'),
    ('+44', '+44 (UK)'),
    ('+971', '+971 (UAE)'),
    ('+61', '+61 (Australia)'),
    ('+65', '+65 (Singapore)'),
  ];

  Widget _buildFieldWidget(Map<String, dynamic> f) {
    final name = (f['fieldName'] ?? f['name'] ?? '').toString();
    if (name.isEmpty) return const SizedBox.shrink();
    final key = getFieldJsonKey(name);
    final type = (f['fieldType'] ?? 'input').toString().toLowerCase();
    final display = f['displayInTable'] == true;
    final mandatory = f['mandatory'] == true;

    if (!display) return const SizedBox.shrink();

    if (name == 'Country Code') {
      if (_isFieldShown('Mobile')) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          formLabel('$name${mandatory ? " *" : ""}'),
          formSelect<String>(
            value: _dropdownValues[key],
            placeholder: 'Select code',
            options: kCountryCodes,
            onChanged: (v) => setState(() => _dropdownValues[key] = v),
          ),
        ],
      );
    }

    if (name == 'Mobile') {
      final showCode = _isFieldShown('Country Code');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          formLabel('$name${mandatory ? " *" : ""}'),
          if (showCode)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: formSelect<String>(
                    value: _dropdownValues['countryCode'] ?? '+91',
                    placeholder: 'Code',
                    options: kCountryCodes,
                    onChanged: (v) => setState(() => _dropdownValues['countryCode'] = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: formInput(
                    _controllers['mobile']!,
                    hint: '91XXXXXXXXXX',
                    keyboard: TextInputType.phone,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            )
          else
            formInput(
              _controllers['mobile']!,
              hint: '91XXXXXXXXXX',
              keyboard: TextInputType.phone,
              formatters: [FilteringTextInputFormatter.digitsOnly],
            ),
        ],
      );
    }

    if (name == 'Status') {
      final isConverted = widget.lead != null && (widget.lead!.isConverted || widget.lead!.statusRaw.toLowerCase() == 'customer' || widget.lead!.statusRaw.toLowerCase() == 'converted');
      final currentStatus = widget.lead?.statusRaw ?? '';
      final isCurrentlyNew = currentStatus.isEmpty || currentStatus.toLowerCase() == 'new' || currentStatus.toLowerCase() == 'new lead';
      final hasAssignee = _dropdownValues['assigned'] != null && _dropdownValues['assigned']!.isNotEmpty;

      final statusField = _fields.firstWhere((e) => (e['fieldName'] ?? e['name'] ?? '') == 'Status', orElse: () => const {});
      final List<String> rawOptions = (statusField['options'] as List?)?.map((e) => e.toString()).toList() ?? const ['New', 'Hot', 'Warm', 'Cold', 'Customer'];

      List<String> statusOptions;
      if (isConverted) {
        statusOptions = const ['Customer'];
      } else if (!isCurrentlyNew) {
        statusOptions = rawOptions.where((s) => s.toLowerCase() != 'new' && s.toLowerCase() != 'new lead').toList();
      } else {
        statusOptions = rawOptions;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          formLabel('$name${mandatory ? " *" : ""}'),
          if (isConverted)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.ink4),
                    const SizedBox(width: 6),
                    Text(
                      'Customer (Converted - Locked)',
                      style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in statusOptions)
                  GestureDetector(
                    onTap: hasAssignee ? () => setState(() => _dropdownValues['status'] = s) : null,
                    child: Opacity(
                      opacity: hasAssignee ? 1.0 : 0.5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _dropdownValues['status'] == s ? AppColors.evaGreen50 : AppColors.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _dropdownValues['status'] == s ? AppColors.evaGreen : AppColors.line),
                        ),
                        child: Text(
                          s,
                          style: AppText.poppins(
                            size: 12.5,
                            weight: FontWeight.w700,
                            color: _dropdownValues['status'] == s ? AppColors.evaGreenDeep : AppColors.ink3,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          if (!hasAssignee && !isConverted)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Please assign a person before selecting status',
                style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: Colors.red.shade700),
              ),
            ),
        ],
      );
    }

    if (name == 'Assigned') {
      final list = _dynamicAgents.isNotEmpty ? _dynamicAgents : widget.agents;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          formLabel('Assigned To${mandatory ? " *" : ""}'),
          formSelect<String>(
            value: _dropdownValues['assigned'],
            placeholder: 'Select agent',
            options: [for (final a in list) (a, a)],
            onChanged: (v) {
              setState(() {
                _dropdownValues['assigned'] = v;
                if (v.isEmpty) {
                  _dropdownValues['status'] = 'New';
                }
              });
            },
          ),
        ],
      );
    }

    if (name == 'Source') {
      final baseList = _dynamicSources.isNotEmpty ? _dynamicSources : widget.sources;
      final List<String> list = List<String>.from(baseList);
      if (!list.any((s) => s.toLowerCase() == 'manual')) {
        list.add('Manual');
      }
      final currentSource = _dropdownValues['source'] ?? (widget.lead?.source.isNotEmpty == true ? widget.lead!.source : 'Business Card');
      if (currentSource.isNotEmpty && !list.contains(currentSource)) {
        list.add(currentSource);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          formLabel('Lead Source${mandatory ? " *" : ""}'),
          formSelect<String>(
            value: currentSource.isEmpty ? null : currentSource,
            placeholder: 'Select source',
            options: [for (final s in list) (s, s)],
            onChanged: (v) => setState(() => _dropdownValues['source'] = v),
          ),
        ],
      );
    }

    if (name == 'Company') {
      final List<String> compOpts = List<String>.from(_dynamicCompanies.isNotEmpty ? _dynamicCompanies : widget.companies);
      final currentComp = _controllers['company']?.text ?? _dropdownValues['company'] ?? '';
      if (currentComp.isNotEmpty && !compOpts.contains(currentComp)) {
        compOpts.add(currentComp);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          formLabel('$name${mandatory ? " *" : ""}'),
          Row(
            children: [
              Expanded(
                child: formInput(
                  _controllers['company'] ??= TextEditingController(text: currentComp),
                  hint: 'Company Name',
                  onChanged: (val) {
                    _dropdownValues['company'] = val;
                  },
                ),
              ),
              if (compOpts.isNotEmpty) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 130,
                  child: formSelect<String>(
                    value: compOpts.contains(currentComp) ? currentComp : null,
                    placeholder: 'Select',
                    options: [for (final c in compOpts) (c, c)],
                    onChanged: (v) {
                      setState(() {
                        _dropdownValues['company'] = v;
                        _controllers['company']?.text = v;
                      });
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      );
    }

    if (name == 'Tags') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          formLabel('$name${mandatory ? " *" : ""}'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagInputCtrl,
                  style: AppText.poppins(size: 14.5, weight: FontWeight.w600, color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: 'Add tag',
                    hintStyle: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.ink4),
                    filled: true,
                    fillColor: AppColors.surface2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.line)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
                  ),
                  onSubmitted: (val) {
                    final t = val.trim();
                    if (t.isNotEmpty && !_tags.contains(t)) {
                      setState(() {
                        _tags.add(t);
                        _tagInputCtrl.clear();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  final t = _tagInputCtrl.text.trim();
                  if (t.isNotEmpty && !_tags.contains(t)) {
                    setState(() {
                      _tags.add(t);
                      _tagInputCtrl.clear();
                    });
                  }
                },
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.evaGreenDeep),
              ),
            ],
          ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _tags.map((t) => Chip(
                label: Text(t, style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.evaGreenDeep)),
                backgroundColor: AppColors.evaGreen50,
                side: const BorderSide(color: AppColors.evaGreen200),
                onDeleted: () => setState(() => _tags.remove(t)),
                deleteIconColor: AppColors.evaGreenDeep,
              )).toList(),
            ),
          ],
        ],
      );
    }

    if (type == 'select' || type == 'dropdown') {
      final opts = ((f['options'] as List?) ?? []).map((e) => e.toString()).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          formLabel('$name${mandatory ? " *" : ""}'),
          formSelect<String>(
            value: _dropdownValues[key],
            placeholder: 'Select $name',
            options: [for (final o in opts) (o, o)],
            onChanged: (v) => setState(() => _dropdownValues[key] = v),
          ),
        ],
      );
    }

    if (type == 'textarea') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          formLabel('$name${mandatory ? " *" : ""}'),
          formInput(_controllers[key] ??= TextEditingController(text: getInitialValue(name, key)), hint: 'Enter $name', maxLines: 3),
        ],
      );
    }

    if (type == 'date') {
      final dateCtrl = _controllers[key] ??= TextEditingController(text: getInitialValue(name, key));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          formLabel('$name${mandatory ? " *" : ""}'),
          GestureDetector(
            onTap: () async {
              final initialDate = DateTime.tryParse(dateCtrl.text) ?? DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() {
                  dateCtrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                });
              }
            },
            child: AbsorbPointer(
              child: formInput(dateCtrl, hint: 'YYYY-MM-DD'),
            ),
          ),
        ],
      );
    }

    TextInputType? keyboard;
    List<TextInputFormatter>? formatters;
    if (name == 'Email') {
      keyboard = TextInputType.emailAddress;
    } else if (name == 'Lead Value' || type == 'number') {
      keyboard = TextInputType.number;
      formatters = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        formLabel('$name${mandatory ? " *" : ""}'),
        formInput(
          _controllers[key] ??= TextEditingController(text: getInitialValue(name, key)),
          hint: 'Enter $name',
          keyboard: keyboard,
          formatters: formatters,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingFields) {
      return sheetScaffold(
        context,
        title: _isEdit ? 'Edit Lead' : 'New Lead',
        icon: Icons.person_add_alt_1_rounded,
        body: const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator(color: AppColors.evaGreen)),
        ),
      );
    }

    return sheetScaffold(
      context,
      title: _isEdit ? 'Edit Lead' : 'New Lead',
      icon: Icons.person_add_alt_1_rounded,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final f in _fields)
              _buildFieldWidget(f),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => setState(() => _newLeadAlert = !_newLeadAlert),
              child: Row(children: [
                Icon(_newLeadAlert ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 20, color: _newLeadAlert ? AppColors.evaGreen : AppColors.ink4),
                const SizedBox(width: 8),
                Text('Send new-lead alert', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink2)),
              ]),
            ),
          ],
        ),
      ),
      footer: primaryButton(context, _saving ? 'Saving…' : (_isEdit ? 'Save Changes' : 'Create Lead'), _saving ? () {} : _save, icon: Icons.check_rounded),
    );
  }
}

// ---------------------------------------------------------------------------
// Reminders
// ---------------------------------------------------------------------------

Future<void> showReminderSheet(BuildContext context, LeadDto lead, {required List<String> agents}) => showAppSheet(context, _ReminderSheet(lead: lead, agents: agents));

class _ReminderSheet extends StatefulWidget {
  final LeadDto lead;
  final List<String> agents;
  const _ReminderSheet({required this.lead, required this.agents});
  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  final _desc = TextEditingController();
  DateTime? _when;
  String? _agent;
  List<Map<String, dynamic>> _list = [];
  List<Map<String, dynamic>> _quickReplies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  List<String> _dynamicAgents = [];

  Future<void> _load() async {
    try {
      final leadsRepo = AppScope.of(context).leads;
      final agentsRepo = AppScope.of(context).agents;

      final results = await Future.wait([
        leadsRepo.fetchLeadReminders(widget.lead.id),
        leadsRepo.fetchQuickReplies(),
        agentsRepo.fetchAgents().catchError((_) => <Map<String, dynamic>>[]),
        agentsRepo.fetchRoles().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      final List<Map<String, dynamic>> agentsData = (results[2] as List).cast<Map<String, dynamic>>();
      final List<Map<String, dynamic>> rolesData = (results[3] as List).cast<Map<String, dynamic>>();

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

      final List<String> loadedAgents = [];
      for (final a in agentsData) {
        final email = (a['email'] ?? a['username'] ?? a['name'] ?? '').toString().trim();
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
          if (email.isNotEmpty && !loadedAgents.contains(email)) {
            loadedAgents.add(email);
          }
        }
      }

      if (loadedAgents.isEmpty) {
        for (final a in agentsData) {
          final email = (a['email'] ?? a['username'] ?? '').toString().trim();
          final status = (a['status'] ?? '').toString().toLowerCase();
          if (email.isNotEmpty && status != 'inactive' && status != 'disabled' && status != 'suspended') {
            loadedAgents.add(email);
          }
        }
      }

      final bool isMockList = widget.agents.length == 4 && widget.agents.contains('Kavya Reddy');
      final List<String> finalAgentList = (widget.agents.isNotEmpty && !isMockList) ? widget.agents : loadedAgents;

      if (mounted) {
        setState(() {
          _list = results[0] as List<Map<String, dynamic>>;
          _quickReplies = results[1] as List<Map<String, dynamic>>;
          _dynamicAgents = finalAgentList;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        appToast(context, 'Failed to load data: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    }
  }

  Future<void> _pick() async {
    final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: DateTime.now());
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (!mounted) return;
    setState(() => _when = DateTime(d.year, d.month, d.day, t?.hour ?? 9, t?.minute ?? 0));
  }

  Future<void> _add() async {
    final description = _desc.text.trim();
    if (description.isEmpty) {
      appToast(context, 'Enter a reminder description');
      return;
    }
    if (_when == null) {
      appToast(context, 'Pick a date & time');
      return;
    }
    final dateStr = '${_when!.year}-${_when!.month.toString().padLeft(2, '0')}-${_when!.day.toString().padLeft(2, '0')} ${_when!.hour.toString().padLeft(2, '0')}:${_when!.minute.toString().padLeft(2, '0')}:00';
    final assignedAgent = _agent ?? '';

    setState(() => _loading = true);
    try {
      final body = {
        'description': description,
        'date': dateStr,
        'assigned': assignedAgent,
        'type': 'general',
        'isNotified': false,
      };
      await AppScope.of(context).leads.addLeadReminder(widget.lead.id, body);
      _desc.clear();
      _when = null;
      await _load();
      appToast(context, 'Reminder set');
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        appToast(context, 'Failed to set reminder: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    }
  }

  Future<void> _delete(String reminderId) async {
    setState(() => _loading = true);
    try {
      await AppScope.of(context).leads.deleteLeadReminder(widget.lead.id, reminderId);
      await _load();
      appToast(context, 'Reminder deleted');
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        appToast(context, 'Failed to delete reminder: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return sheetScaffold(
      context,
      title: 'Set New Reminder',
      icon: Icons.alarm_rounded,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _loading
            ? const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.evaGreen),
                ),
              )
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                formLabel('Description *'),
                formInput(_desc, hint: 'Follow up with ${widget.lead.name}…', maxLines: 4),
                const SizedBox(height: 10),
                formLabel('Quick Replies'),
                formSelect<String>(
                  value: null,
                  placeholder: 'Select a quick reply to insert in description...',
                  options: [
                    if (_quickReplies.isNotEmpty)
                      for (final r in _quickReplies)
                        (r['message']?.toString() ?? r['title']?.toString() ?? '', r['title']?.toString() ?? '')
                    else
                      for (final q in ['Call back', 'Send quotation', 'Follow up', 'Demo'])
                        (q, q)
                  ],
                  onChanged: (val) {
                    if (val != null && val.isNotEmpty) {
                      setState(() {
                        final currentValue = _desc.text;
                        final newValue = currentValue.isNotEmpty
                            ? '$currentValue\n\n--- Additional points ---\n$val'
                            : val;
                        _desc.text = newValue;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          formLabel('Date & Time *'),
                          GestureDetector(
                            onTap: _pick,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _when == null ? 'mm/dd/yyyy --:--' : fmt(_when!),
                                      style: AppText.poppins(
                                        size: 13,
                                        weight: FontWeight.w600,
                                        color: _when == null ? AppColors.ink4 : AppColors.ink,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.ink4),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          formLabel('Set reminder to'),
                          formSelect<String>(
                            value: _agent,
                            placeholder: 'Select an agent',
                            options: [for (final a in (_dynamicAgents.isNotEmpty ? _dynamicAgents : widget.agents)) (a, a)],
                            onChanged: (v) => setState(() => _agent = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Reminders', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2)),
                const SizedBox(height: 10),
                if (_list.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Center(
                      child: Text(
                        'No reminders found',
                        style: AppText.poppins(
                          size: 13.5,
                          weight: FontWeight.w600,
                          color: AppColors.ink3,
                        ),
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < _list.length; i++)
                    Builder(
                      builder: (context) {
                        final r = _list[i];
                        final desc = r['description']?.toString() ?? r['notes']?.toString() ?? '—';
                        final dateStr = r['date']?.toString() ?? '';
                        final agentStr = r['assigned']?.toString() ?? r['agent']?.toString() ?? 'Me';
                        String displayDate = dateStr;
                        final dt = DateTime.tryParse(dateStr);
                        if (dt != null) {
                          displayDate = fmt(dt);
                        }
                        final reminderId = r['reminderId']?.toString() ?? r['_id']?.toString() ?? r['id']?.toString() ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.alarm_rounded, size: 18, color: AppColors.evaGreenDeep),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(desc, style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink)),
                                    const SizedBox(height: 3),
                                    Text('$displayDate · Assigned to $agentStr', style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
                                  ],
                                ),
                              ),
                              if (reminderId.isNotEmpty)
                                GestureDetector(
                                  onTap: () => _delete(reminderId),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
                                    child: const Icon(Icons.close_rounded, size: 14, color: AppColors.ink3),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
              ]),
      ),
      footer: primaryButton(context, 'Add Reminder', _loading ? () {} : _add, icon: Icons.add_alarm_rounded),
    );
  }
}

// ---------------------------------------------------------------------------
// Notes (wired to /leads/{id}/notes)
// ---------------------------------------------------------------------------

Future<void> showNotesSheet(BuildContext context, LeadDto lead) => showAppSheet(context, _NotesSheet(lead: lead));

class _NotesSheet extends StatefulWidget {
  final LeadDto lead;
  const _NotesSheet({required this.lead});
  @override
  State<_NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends State<_NotesSheet> {
  final _note = TextEditingController();
  List<Map<String, dynamic>> _notes = [];
  bool _loading = true;
  bool _saving = false;
  String _selectedType = 'text';

  // Audio specific states
  String _audioOption = 'record'; // 'record' or 'upload'
  bool _recording = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  String? _recordedPath;
  final AudioRecorder _audioRecorder = AudioRecorder();

  // File upload specific states
  bool _uploadingFile = false;
  String? _uploadedFileUrl;
  String? _fileName;
  int? _fileSize;

  final List<(String, IconData)> _noteTypes = const [
    ('text', Icons.chat_bubble_outline_rounded),
    ('audio', Icons.mic_none_rounded),
    ('image', Icons.image_outlined),
    ('video', Icons.videocam_outlined),
    ('document', Icons.description_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final n = await AppScope.of(context).leads.fetchLeadNotes(widget.lead.id);
      if (mounted) {
        setState(() {
          _notes = n;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeType(String type) {
    if (_recording) {
      _cancelRecording();
    }
    setState(() {
      _selectedType = type;
      _uploadedFileUrl = null;
      _fileName = null;
      _fileSize = null;
      _recordedPath = null;
      _recordingDuration = 0;
      _note.clear();
    });
  }

  Future<void> _pickFile(String type) async {
    List<String> allowedExtensions = [];
    if (type == 'image') {
      allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'];
    } else if (type == 'video') {
      allowedExtensions = ['mp4'];
    } else if (type == 'document') {
      allowedExtensions = ['csv', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'pdf', 'txt'];
    } else if (type == 'audio') {
      allowedExtensions = ['mp3', 'wav', 'm4a', 'aac', 'ogg'];
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final path = file.path;
      if (path == null) return;

      final ext = file.extension?.toLowerCase();
      if (ext == null || !allowedExtensions.contains(ext)) {
        if (mounted) appToast(context, 'Invalid file type. Only ${allowedExtensions.join(', ').toUpperCase()} are allowed.', isError: true);
        return;
      }

      setState(() {
        _uploadingFile = true;
        _fileName = file.name;
        _fileSize = file.size;
        _uploadedFileUrl = null;
      });

      final bytes = await File(path).readAsBytes();
      final url = await AppScope.of(context).compose.uploadMedia(bytes, file.name);

      if (url != null) {
        setState(() {
          _uploadedFileUrl = url;
          _uploadingFile = false;
        });
        if (mounted) appToast(context, 'File uploaded successfully!', isSuccess: true);
      } else {
        setState(() {
          _uploadingFile = false;
          _fileName = null;
          _fileSize = null;
        });
        if (mounted) appToast(context, 'File upload failed.', isError: true);
      }
    } catch (e) {
      setState(() {
        _uploadingFile = false;
        _fileName = null;
        _fileSize = null;
      });
      if (mounted) appToast(context, 'Error picking/uploading file: $e', isError: true);
    }
  }

  Future<void> _startRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        appToast(context, 'Microphone permission is required to record audio.', isError: true);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/audio_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      setState(() {
        _recording = true;
        _recordingDuration = 0;
        _recordedPath = null;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration++;
          });
        }
      });
    } catch (e) {
      appToast(context, 'Failed to start recording: $e', isError: true);
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      setState(() {
        _recording = false;
        _recordedPath = path;
      });
    } catch (e) {
      appToast(context, 'Failed to stop recording: $e', isError: true);
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _recordingTimer?.cancel();
      await _audioRecorder.stop();
      setState(() {
        _recording = false;
        _recordingDuration = 0;
        _recordedPath = null;
      });
    } catch (e) {
      appToast(context, 'Failed to cancel recording: $e', isError: true);
    }
  }

  Future<void> _add() async {
    setState(() => _saving = true);

    Map<String, dynamic> noteData = {
      'type': _selectedType,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'createdAt': DateTime.now().toIso8601String(),
    };

    try {
      if (_selectedType == 'text') {
        final val = _note.text.trim();
        if (val.isEmpty) {
          appToast(context, 'Please enter note content');
          setState(() => _saving = false);
          return;
        }
        noteData['content'] = val;
      } else if (_selectedType == 'audio') {
        if (_audioOption == 'record') {
          if (_recordedPath == null) {
            appToast(context, 'Please record audio first', isError: true);
            setState(() => _saving = false);
            return;
          }
          final bytes = await File(_recordedPath!).readAsBytes();
          final url = await AppScope.of(context).compose.uploadMedia(bytes, 'recorded_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
          if (url == null) {
            throw Exception('Failed to upload recorded audio');
          }
          noteData['audioData'] = url;
          noteData['audioSource'] = 'record';
        } else {
          if (_uploadedFileUrl == null) {
            appToast(context, 'Please upload audio file first', isError: true);
            setState(() => _saving = false);
            return;
          }
          noteData['audioData'] = _uploadedFileUrl;
          noteData['audioSource'] = 'upload';
          noteData['mediaData'] = [
            {
              'name': _fileName ?? 'audio_file',
              'type': 'audio/${_fileName?.split('.').last ?? 'wav'}',
              'size': _fileSize,
              'url': _uploadedFileUrl,
            }
          ];
        }
      } else {
        if (_uploadedFileUrl == null) {
          appToast(context, 'Please select and upload a file first', isError: true);
          setState(() => _saving = false);
          return;
        }
        noteData['mediaData'] = [
          {
            'name': _fileName ?? 'file',
            'type': '${_selectedType}/${_fileName?.split('.').last ?? 'bin'}',
            'size': _fileSize,
            'url': _uploadedFileUrl,
          }
        ];
      }

      await AppScope.of(context).leads.addLeadNote(widget.lead.id, noteData);
      _note.clear();
      setState(() {
        _recordedPath = null;
        _uploadedFileUrl = null;
        _fileName = null;
        _fileSize = null;
      });
      appToast(context, '${_selectedType[0].toUpperCase() + _selectedType.substring(1)} note added successfully!', isSuccess: true);
      await _load();
    } catch (e) {
      if (mounted) appToast(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteNote(dynamic noteId) async {
    if (noteId == null) return;
    try {
      await AppScope.of(context).leads.deleteLeadNote(widget.lead.id, noteId.toString());
      appToast(context, 'Note deleted successfully!', isSuccess: true);
      await _load();
    } catch (e) {
      if (mounted) appToast(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _clearAllNotes() async {
    if (_notes.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear All Notes', style: AppText.poppins(size: 16, weight: FontWeight.bold, color: AppColors.ink)),
        content: Text('Are you sure you want to clear all notes for this lead?', style: AppText.poppins(size: 14, color: AppColors.ink2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppText.poppins(size: 14, color: AppColors.ink3)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Clear All', style: AppText.poppins(size: 14, weight: FontWeight.bold, color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final noteIds = _notes.map((n) => (n['id'] ?? n['_id'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
      if (noteIds.isNotEmpty) {
        await AppScope.of(context).leads.bulkDeleteLeadNotes(widget.lead.id, noteIds);
        appToast(context, 'All notes cleared successfully!', isSuccess: true);
      }
      await _load();
    } catch (e) {
      if (mounted) appToast(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'text': return Colors.blue;
      case 'audio': return Colors.green;
      case 'image': return Colors.orange;
      case 'video': return Colors.purple;
      case 'document': return Colors.blueGrey;
      default: return Colors.grey;
    }
  }

  String _formatDateTime(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.toString();
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _viewFile(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) appToast(context, 'Could not open URL: $url', isError: true);
      }
    } catch (e) {
      if (mounted) appToast(context, 'Error opening URL: $e', isError: true);
    }
  }

  Widget _buildNoteContentWidget(Map<String, dynamic> n) {
    final type = (n['type'] ?? 'text').toString().toLowerCase();
    if (type == 'text') {
      return Text(
        (n['content'] ?? n['note'] ?? n['text'] ?? '').toString(),
        style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink, height: 1.4),
      );
    } else if (type == 'audio') {
      final audioUrl = (n['audioData'] ?? '').toString();
      final audioSource = (n['audioSource'] ?? 'record').toString();
      return GestureDetector(
        onTap: () => _viewFile(audioUrl),
        child: Row(
          children: [
            const Icon(Icons.play_circle_fill_rounded, color: AppColors.evaGreenDeep, size: 18),
            const SizedBox(width: 6),
            Text(
              audioSource == 'record' ? 'Recorded Audio' : 'Uploaded Audio',
              style: AppText.poppins(size: 12.5, weight: FontWeight.bold, color: AppColors.evaGreenDeep).copyWith(decoration: TextDecoration.underline),
            ),
            if (audioUrl.isNotEmpty) ...[
              const SizedBox(width: 6),
              const Icon(Icons.open_in_new_rounded, color: AppColors.evaGreenDeep, size: 13),
            ],
          ],
        ),
      );
    } else if (type == 'image') {
      final List<dynamic> mediaList = n['mediaData'] ?? [];
      final firstMediaUrl = mediaList.isNotEmpty ? (mediaList[0]['url'] ?? '') : '';
      return GestureDetector(
        onTap: () => _viewFile(firstMediaUrl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (firstMediaUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    firstMediaUrl,
                    width: 100,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined, size: 30, color: AppColors.ink4),
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    firstMediaUrl.isNotEmpty ? firstMediaUrl : 'No image URL provided',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(size: 12, color: AppColors.ink3).copyWith(decoration: TextDecoration.underline),
                  ),
                ),
                if (firstMediaUrl.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.open_in_new_rounded, color: AppColors.ink3, size: 12),
                ],
              ],
            ),
          ],
        ),
      );
    } else if (type == 'video') {
      final List<dynamic> mediaList = n['mediaData'] ?? [];
      final firstMediaUrl = mediaList.isNotEmpty ? (mediaList[0]['url'] ?? '') : '';
      return GestureDetector(
        onTap: () => _viewFile(firstMediaUrl),
        child: Row(
          children: [
            const Icon(Icons.video_library_rounded, color: AppColors.evaGreenDeep, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                firstMediaUrl.isNotEmpty ? firstMediaUrl : 'No video URL provided',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.poppins(size: 12, color: AppColors.evaGreenDeep).copyWith(decoration: TextDecoration.underline),
              ),
            ),
            if (firstMediaUrl.isNotEmpty) ...[
              const SizedBox(width: 6),
              const Icon(Icons.open_in_new_rounded, color: AppColors.evaGreenDeep, size: 13),
            ],
          ],
        ),
      );
    } else {
      final List<dynamic> mediaList = n['mediaData'] ?? [];
      final firstMediaUrl = mediaList.isNotEmpty ? (mediaList[0]['url'] ?? '') : '';
      final docName = mediaList.isNotEmpty ? (mediaList[0]['name'] ?? 'Document') : 'Document';
      return GestureDetector(
        onTap: () => _viewFile(firstMediaUrl),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file_outlined, color: AppColors.evaGreenDeep, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                firstMediaUrl.isNotEmpty ? '$docName ($firstMediaUrl)' : 'No document URL provided',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.poppins(size: 12, color: AppColors.evaGreenDeep).copyWith(decoration: TextDecoration.underline),
              ),
            ),
            if (firstMediaUrl.isNotEmpty) ...[
              const SizedBox(width: 6),
              const Icon(Icons.open_in_new_rounded, color: AppColors.evaGreenDeep, size: 13),
            ],
          ],
        ),
      );
    }
  }

  Widget _buildFileSelectorZone(String type) {
    String fileLabel = '';
    String acceptedText = '';
    IconData fileIcon = Icons.upload_file_rounded;

    if (type == 'image') {
      fileLabel = 'Choose image file';
      acceptedText = 'Accepted: JPG, PNG, GIF, WebP, SVG...';
      fileIcon = Icons.image_outlined;
    } else if (type == 'video') {
      fileLabel = 'Choose video file';
      acceptedText = 'Accepted: MP4';
      fileIcon = Icons.videocam_outlined;
    } else if (type == 'document') {
      fileLabel = 'Choose document file';
      acceptedText = 'Accepted: CSV, Word, Excel, PPT, PDF or TXT';
      fileIcon = Icons.description_outlined;
    } else if (type == 'audio') {
      fileLabel = 'Choose audio file';
      acceptedText = 'Accepted: MP3, WAV, M4A, AAC, OGG';
      fileIcon = Icons.mic_none_rounded;
    }

    if (_uploadingFile) {
      return Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: AppColors.evaGreen, strokeWidth: 2),
            ),
            const SizedBox(height: 8),
            Text(
              'Uploading ${_fileName ?? 'file'}...',
              style: AppText.poppins(size: 12.5, color: AppColors.ink3),
            ),
          ],
        ),
      );
    }

    if (_uploadedFileUrl != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.evaGreen50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.evaGreen200),
        ),
        child: Row(
          children: [
            Icon(fileIcon, color: AppColors.evaGreenDeep, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_fileName ?? 'Uploaded file', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                  if (_fileSize != null)
                    Text('${(_fileSize! / 1024).toStringAsFixed(1)} KB', style: AppText.poppins(size: 11, color: AppColors.ink3)),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _uploadedFileUrl = null;
                  _fileName = null;
                  _fileSize = null;
                });
              },
              icon: const Icon(Icons.close_rounded, color: AppColors.ink3),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DottedDropzone(
          height: 100,
          onTap: () => _pickFile(type),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_upload_outlined, color: AppColors.evaGreenDeep, size: 28),
              const SizedBox(height: 6),
              Text(
                fileLabel,
                style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          acceptedText,
          style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink4),
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    if (_selectedType == 'text') {
      return formInput(
        _note,
        hint: 'Enter your note here...',
        maxLines: 3,
      );
    }

    if (_selectedType == 'audio') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose Audio Option:', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
          const SizedBox(height: 6),
          Row(
            children: [
              InkWell(
                onTap: () {
                  if (!_recording) setState(() => _audioOption = 'record');
                },
                child: Row(
                  children: [
                    Radio<String>(
                      value: 'record',
                      groupValue: _audioOption,
                      activeColor: AppColors.evaGreen,
                      onChanged: _recording ? null : (val) => setState(() => _audioOption = val!),
                    ),
                    Text('Record Audio', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              InkWell(
                onTap: () {
                  if (!_recording) setState(() => _audioOption = 'upload');
                },
                child: Row(
                  children: [
                    Radio<String>(
                      value: 'upload',
                      groupValue: _audioOption,
                      activeColor: AppColors.evaGreen,
                      onChanged: _recording ? null : (val) => setState(() => _audioOption = val!),
                    ),
                    Text('Upload Audio File', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_audioOption == 'record') ...[
            if (_recording) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fiber_manual_record, color: AppColors.danger, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Rec... ${_formatDuration(_recordingDuration)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.danger),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _cancelRecording,
                      child: Text('Cancel', style: AppText.poppins(size: 12.5, color: AppColors.ink3)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _stopRecording,
                      icon: const Icon(Icons.stop, size: 14),
                      label: Text('Stop', style: AppText.poppins(size: 12, weight: FontWeight.bold)),
                    ),
                  ],
                ),
              )
            ] else if (_recordedPath != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.evaGreen50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.evaGreen200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_fill_rounded, color: AppColors.evaGreenDeep, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Audio recorded successfully', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                          Text('Format: M4A', style: AppText.poppins(size: 11, color: AppColors.ink3)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _recordedPath = null),
                      icon: const Icon(Icons.close_rounded, color: AppColors.ink3),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.evaGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _startRecording,
                  icon: const Icon(Icons.mic, size: 18),
                  label: Text('Start Recording', style: AppText.poppins(size: 13.5, weight: FontWeight.bold)),
                ),
              ),
            ],
          ] else ...[
            _buildFileSelectorZone('audio'),
          ],
        ],
      );
    }

    return _buildFileSelectorZone(_selectedType);
  }

  @override
  Widget build(BuildContext context) {
    return sheetScaffold(
      context,
      title: 'Add New Note',
      icon: Icons.description_outlined,
      body: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Note Type Selector Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Note Type', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final t in _noteTypes) ...[
                          GestureDetector(
                            onTap: () => _changeType(t.$1),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedType == t.$1 ? AppColors.evaGreen50 : AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedType == t.$1 ? AppColors.evaGreen : AppColors.line,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    t.$2,
                                    size: 16,
                                    color: _selectedType == t.$1 ? AppColors.evaGreenDeep : AppColors.ink3,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    t.$1[0].toUpperCase() + t.$1.substring(1),
                                    style: AppText.poppins(
                                      size: 13,
                                      weight: FontWeight.w700,
                                      color: _selectedType == t.$1 ? AppColors.evaGreenDeep : AppColors.ink2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildInputSection(),
            ),

            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'All Notes (${_notes.length})',
                      style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ),
                  if (_notes.isNotEmpty)
                    TextButton(
                      onPressed: _clearAllNotes,
                      child: Text(
                        'Clear All Notes',
                        style: AppText.poppins(size: 12.5, weight: FontWeight.bold, color: AppColors.danger),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.evaGreen))
                  : _notes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.description_outlined, size: 40, color: AppColors.ink4),
                              const SizedBox(height: 8),
                              Text('No notes found', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink4)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _notes.length,
                          itemBuilder: (ctx, index) {
                            final n = _notes[index];
                            final type = (n['type'] ?? 'text').toString();
                            final typeColor = _getTypeColor(type);
                            final dateTimeStr = _formatDateTime(n['createdAt'] ?? n['date']);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: AppColors.surface2,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: AppText.poppins(size: 11, weight: FontWeight.bold, color: AppColors.ink3),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: typeColor.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                type.toUpperCase(),
                                                style: AppText.poppins(size: 10, weight: FontWeight.w800, color: typeColor),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              dateTimeStr,
                                              style: AppText.poppins(size: 11, color: AppColors.ink4),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        _buildNoteContentWidget(n),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _deleteNote(n['id'] ?? n['_id']),
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      footer: primaryButton(
        context,
        _saving ? 'Adding...' : 'Add Note',
        _saving ? () {} : _add,
        icon: Icons.check_rounded,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Activity logs (wired to /leads/{id}/audit-logs)
// ---------------------------------------------------------------------------

Future<void> showActivityLogs(BuildContext context, LeadDto lead) => showAppSheet(context, _ActivityLogs(lead: lead));

class _ActivityLogs extends StatefulWidget {
  final LeadDto lead;
  const _ActivityLogs({required this.lead});
  @override
  State<_ActivityLogs> createState() => _ActivityLogsState();
}

class _ActivityLogsState extends State<_ActivityLogs> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  final Set<String> _expandedLogIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await AppScope.of(context).leads.fetchAuditLogs(widget.lead.id);
      if (mounted) {
        setState(() {
          _logs = l;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _viewFile(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) appToast(context, 'Could not open URL: $url', isError: true);
      }
    } catch (e) {
      if (mounted) appToast(context, 'Error opening URL: $e', isError: true);
    }
  }

  String _formatDateOnly(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString());
      return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
    } catch (_) {
      return raw.toString().split('T').first;
    }
  }

  Widget _buildDetailRow(String label, String value, {bool isHeader = false}) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: AppText.poppins(size: 11.5, weight: isHeader ? FontWeight.w800 : FontWeight.w600, color: AppColors.ink2),
          ),
        ),
        Expanded(
          flex: 4,
          child: Text(
            value,
            style: AppText.poppins(
              size: 11.5,
              weight: isHeader ? FontWeight.w800 : FontWeight.w700,
              color: isHeader ? AppColors.ink : AppColors.evaGreenDeep,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaItemRow(String type, dynamic media) {
    if (media is! Map) return const SizedBox.shrink();
    final name = (media['name'] ?? 'File').toString();
    final url = (media['url'] ?? '').toString();

    IconData icon = Icons.insert_drive_file_outlined;
    if (type == 'image') icon = Icons.image_outlined;
    if (type == 'video') icon = Icons.videocam_outlined;
    if (type == 'audio') icon = Icons.play_circle_fill_rounded;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.evaGreenDeep, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 8),
          if (url.isNotEmpty)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.evaGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _viewFile(url),
              icon: const Icon(Icons.download_rounded, size: 12),
              label: Text(type == 'image' ? 'View' : 'Download', style: AppText.poppins(size: 10.5, weight: FontWeight.bold, color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedDetails(Map<String, dynamic> log, bool isFieldChange, bool isNote, bool isMediaUpload) {
    final metadata = log['metadata'] ?? {};

    if (isFieldChange) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Field', (metadata['field'] ?? '—').toString(), isHeader: true),
          const Divider(height: 12),
          _buildDetailRow('Old Value', (metadata['oldValue'] ?? '—').toString()),
          const Divider(height: 12),
          _buildDetailRow('Updated Value', (metadata['newValue'] ?? '—').toString()),
        ],
      );
    }

    if (isNote || isMediaUpload) {
      final noteType = (metadata['noteType'] ?? 'text').toString().toLowerCase();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Type: ', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3)),
              Text(noteType.toUpperCase(), style: AppText.poppins(size: 12, weight: FontWeight.bold, color: AppColors.ink)),
            ],
          ),
          if (noteType == 'text' && metadata['contentPreview'] != null) ...[
            const SizedBox(height: 6),
            Text(
              (metadata['contentPreview'] ?? '').toString(),
              style: AppText.poppins(size: 12.5, color: AppColors.ink),
            ),
          ],
          if (metadata['mediaData'] is List) ...[
            const SizedBox(height: 8),
            for (final media in (metadata['mediaData'] as List)) ...[
              _buildMediaItemRow(noteType, media),
              const SizedBox(height: 6),
            ],
          ],
          if (noteType == 'audio' && metadata['audioSource'] == 'record' && metadata['audioData'] != null) ...[
            const SizedBox(height: 8),
            _buildMediaItemRow('audio', {
              'url': metadata['audioData'] is Map ? metadata['audioData']['fileUrl'] : metadata['audioData'],
              'name': 'Recorded Audio'
            }),
          ],
        ],
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.lead.name.isEmpty ? (widget.lead.mobile.isEmpty ? 'Unknown' : widget.lead.mobile) : widget.lead.name;
    return sheetScaffold(
      context,
      title: 'Activity logs · $displayName',
      icon: Icons.timeline_rounded,
      body: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.evaGreen))
            : _logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timeline_rounded, size: 40, color: AppColors.ink4),
                        const SizedBox(height: 8),
                        Text('No activity recorded', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink4)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: _logs.length,
                    itemBuilder: (_, i) {
                      final log = _logs[i];
                      final logId = (log['id'] ?? log['_id'] ?? i.toString()).toString();
                      final isExpanded = _expandedLogIds.contains(logId);
                      final dateStr = _formatDateOnly(log['createdAt'] ?? log['date']);
                      final isFieldChange = log['metadata'] != null &&
                          log['metadata']['oldValue'] != null &&
                          log['metadata']['newValue'] != null;
                      final isNote = log['action'] != null &&
                          log['action'].toString().contains('note') &&
                          log['metadata'] != null &&
                          (log['metadata']['contentPreview'] != null ||
                              log['metadata']['noteType'] != null);
                      final isMediaUpload = log['action'] != null &&
                          log['action'].toString().contains('note_added') &&
                          log['metadata'] != null &&
                          log['metadata']['noteType'] != null &&
                          ['image', 'video', 'audio', 'document'].contains(log['metadata']['noteType'].toString().toLowerCase());

                      return Container(
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
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: AppColors.surface2,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.person_outline_rounded, color: AppColors.ink3, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (log['description'] ?? '').toString(),
                                        style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        (log['user'] ?? 'System').toString(),
                                        style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink4),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  dateStr,
                                  style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink3),
                                ),
                              ],
                            ),
                            if (isFieldChange || isNote || isMediaUpload) ...[
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isExpanded) {
                                      _expandedLogIds.remove(logId);
                                    } else {
                                      _expandedLogIds.add(logId);
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: AppColors.evaGreenDeep,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'View Details',
                                        style: AppText.poppins(
                                          size: 12,
                                          weight: FontWeight.w700,
                                          color: AppColors.evaGreenDeep,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (isExpanded) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.surface2,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: _buildExpandedDetails(log, isFieldChange, isNote, isMediaUpload),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Call logs + full-screen call
// ---------------------------------------------------------------------------

Future<void> showCallLogs(BuildContext context, LeadDto lead) => showAppSheet(context, _CallLogs(lead: lead));

class _CallLogs extends StatefulWidget {
  final LeadDto lead;
  const _CallLogs({required this.lead});
  @override
  State<_CallLogs> createState() => _CallLogsState();
}

class _CallLogsState extends State<_CallLogs> {
  List<Map<String, dynamic>> _calls = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final allCalls = await AppScope.of(context).chat.fetchCallLogs(limit: 100);
      final leadPhone = widget.lead.mobile.replaceAll(RegExp(r'[\s\-\(\)]'), '');

      final filtered = allCalls.where((c) {
        final from = (c['callFrom'] ?? c['from'] ?? '').toString().replaceAll(RegExp(r'[\s\-\(\)]'), '');
        final to = (c['callTo'] ?? c['to'] ?? '').toString().replaceAll(RegExp(r'[\s\-\(\)]'), '');
        final dial = (c['dialWhomNumber'] ?? '').toString().replaceAll(RegExp(r'[\s\-\(\)]'), '');
        return from.contains(leadPhone) || to.contains(leadPhone) || dial.contains(leadPhone) ||
            leadPhone.contains(from) || leadPhone.contains(to) || leadPhone.contains(dial);
      }).toList();

      if (mounted) {
        setState(() {
          _calls = filtered;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatCallDateFriendly(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString());
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0 && dt.day == now.day) {
        return 'Today';
      } else if (diff.inDays == 1 || (diff.inDays == 0 && dt.day != now.day)) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      } else {
        return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
      }
    } catch (_) {
      return raw.toString().split('T').first;
    }
  }

  String _formatCallDuration(int totalSecs) {
    if (totalSecs <= 0) return '0 sec';
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    if (m > 0) {
      return '$m min $s sec';
    }
    return '$s sec';
  }

  Future<void> _playRecording(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) appToast(context, 'Could not open URL: $url', isError: true);
      }
    } catch (e) {
      if (mounted) appToast(context, 'Error opening URL: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.lead.name.isEmpty ? (widget.lead.mobile.isEmpty ? 'Unknown' : widget.lead.mobile) : widget.lead.name;
    return sheetScaffold(
      context,
      title: 'Call logs · $displayName',
      icon: Icons.call_made_rounded,
      body: SizedBox(
        height: MediaQuery.of(context).size.height * 0.55,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.evaGreen))
            : _calls.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
                          child: const Icon(Icons.call_outlined, size: 28, color: AppColors.ink4),
                        ),
                        const SizedBox(height: 14),
                        Text('No call logs found for this lead', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink2)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: _calls.length,
                    itemBuilder: (_, i) {
                      final c = _calls[i];
                      final direction = (c['direction'] ?? c['type'] ?? 'outbound').toString().toLowerCase();
                      final status = (c['callStatus'] ?? c['status'] ?? '').toString().toLowerCase();
                      final durationSec = int.tryParse((c['callDuration'] ?? c['duration'] ?? '0').toString()) ?? 0;
                      final recUrl = c['recordingUrl']?.toString() ?? c['fullCallData']?['RecordingUrl']?.toString() ?? '';

                      String title = 'Outgoing call';
                      IconData icon = Icons.call_made_rounded;
                      Color iconColor = AppColors.evaGreenDeep;

                      if (status == 'missed' || status == 'no-answer' || status == 'failed') {
                        title = 'Missed call';
                        icon = Icons.call_missed_rounded;
                        iconColor = AppColors.danger;
                      } else if (direction == 'inbound' || direction == 'incoming') {
                        title = 'Incoming call';
                        icon = Icons.call_received_rounded;
                        iconColor = Colors.blue;
                      }

                      final subtitle = durationSec > 0 
                          ? _formatCallDuration(durationSec)
                          : (c['callFrom'] ?? c['from'] ?? widget.lead.mobile).toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: iconColor, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    subtitle,
                                    style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatCallDateFriendly(c['createdAt'] ?? c['date']),
                                  style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink3),
                                ),
                                if (recUrl.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () => _playRecording(recUrl),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.play_circle_outline, size: 14, color: AppColors.evaGreenDeep),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Recording',
                                          style: AppText.poppins(size: 10, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

void openCallScreen(BuildContext context, LeadDto lead) {
  Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => _CallScreen(lead: lead)));
}

class _CallScreen extends StatefulWidget {
  final LeadDto lead;
  const _CallScreen({required this.lead});
  @override
  State<_CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<_CallScreen> {
  bool _mute = false, _speaker = false, _hold = false;
  int _secs = 0;
  late final _ticker = Stream.periodic(const Duration(seconds: 1), (i) => i + 1);

  @override
  void initState() {
    super.initState();
    _dialNative();
  }

  Future<void> _dialNative() async {
    final phone = widget.lead.mobile.replaceAll(RegExp(r'[^\d\+]'), '');
    if (phone.isNotEmpty) {
      try {
        final uri = Uri.parse('tel:$phone');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final display = widget.lead.name.isEmpty ? widget.lead.mobile : widget.lead.name;
    String fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: AppColors.evaGreenDeep,
      body: SafeArea(
        child: StreamBuilder<int>(
          stream: _ticker,
          builder: (_, snap) {
            _secs = snap.data ?? 0;
            return Column(children: [
              const SizedBox(height: 50),
              InitialsAvatar(initials: _initials(display), color: Colors.white24, size: 110, radius: 55),
              const SizedBox(height: 22),
              Text(display, style: AppText.poppins(size: 24, weight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 6),
              Text(_hold ? 'On hold' : fmt(_secs), style: AppText.poppins(size: 15, weight: FontWeight.w600, color: Colors.white70)),
              const Spacer(),
              Wrap(spacing: 28, runSpacing: 24, alignment: WrapAlignment.center, children: [
                _ctl(_mute ? Icons.mic_off_rounded : Icons.mic_rounded, 'Mute', _mute, () => setState(() => _mute = !_mute)),
                _ctl(Icons.dialpad_rounded, 'Keypad', false, () {}),
                _ctl(_speaker ? Icons.volume_up_rounded : Icons.volume_down_rounded, 'Speaker', _speaker, () => setState(() => _speaker = !_speaker)),
                _ctl(Icons.pause_rounded, 'Hold', _hold, () => setState(() => _hold = !_hold)),
                _ctl(Icons.chat_rounded, 'WhatsApp', false, () async {
                  final phone = widget.lead.mobile.replaceAll(RegExp(r'[^\d\+]'), '');
                  if (phone.isNotEmpty) {
                    final cleanPhone = phone.replaceAll('+', '');
                    final url = 'https://wa.me/$cleanPhone';
                    try {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    } catch (_) {}
                  }
                }),
              ]),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(width: 70, height: 70, alignment: Alignment.center, decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle), child: const Icon(Icons.call_end_rounded, size: 32, color: Colors.white)),
              ),
              const SizedBox(height: 40),
            ]);
          },
        ),
      ),
    );
  }

  Widget _ctl(IconData icon, String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(children: [
            Container(width: 60, height: 60, alignment: Alignment.center, decoration: BoxDecoration(color: active ? Colors.white : Colors.white24, shape: BoxShape.circle), child: Icon(icon, size: 26, color: active ? AppColors.evaGreenDeep : Colors.white)),
            const SizedBox(height: 7),
            Text(label, style: AppText.poppins(size: 12, weight: FontWeight.w600, color: Colors.white70)),
          ]),
        ),
      );
}

// ---------------------------------------------------------------------------
// Import wizard (Upload -> Map -> Preview -> Import) + business-card scanner
// ---------------------------------------------------------------------------

Future<void> showImportWizard(BuildContext context, {VoidCallback? onDone}) => showAppSheet(context, _ImportWizard(onDone: onDone));

class _ImportWizard extends StatefulWidget {
  final VoidCallback? onDone;
  const _ImportWizard({this.onDone});
  @override
  State<_ImportWizard> createState() => _ImportWizardState();
}

class _ImportWizardState extends State<_ImportWizard> {
  int _step = 0; // 0: Upload, 1: Map fields, 2: Preview & Duplicates, 3: Import Complete
  bool _fileChosen = false;
  String _fileName = '';
  
  List<List<String>> _parsedRows = [];
  List<String> _headers = [];
  
  Map<String, String> _fieldMapping = {};
  List<Map<String, dynamic>> _allFields = [];

  bool _checkEmail = true;
  bool _checkName = false;
  bool _sendAlertMessage = false;

  int _previewTab = 0; // 0: Unique Records, 1: Duplicates
  String _duplicateAction = 'skip'; // 'skip', 'overwrite', 'include_all'
  int _duplicatePage = 1;
  static const int _pageSize = 5;

  bool _loading = false;
  List<LeadDto> _existingLeads = [];

  int _totalParsedCount = 0;
  int _successCount = 0;
  int _failedCount = 0;
  int _duplicateCount = 0;

  String _assignmentMode = 'manual';
  List<String> _agentNames = [];

  static const _steps = ['Upload File', 'Map Fields', 'Preview & Handle Duplicates', 'Import'];

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    try {
      final repo = AppScope.of(context).leads;
      try {
        final mode = await repo.fetchAssignmentMode();
        final agentsList = await AppScope.of(context).agents.fetchAgents();
        final names = agentsList
            .where((a) => (a['role'] ?? '').toString().toLowerCase() != 'superadmin')
            .map((a) => (a['name'] ?? a['username'] ?? a['email'] ?? '').toString().trim())
            .where((s) => s.isNotEmpty)
            .toList();
        _assignmentMode = mode;
        _agentNames = names.isNotEmpty ? names : MockData.agents.map((a) => a.name).toList();
      } catch (_) {}

      final custom = await repo.fetchLeadFields();
      final List<Map<String, dynamic>> fields = [
        {'key': 'name', 'label': 'Name', 'required': true},
        {'key': 'mobile', 'label': 'Mobile', 'required': true},
        {'key': 'email', 'label': 'Email', 'required': false},
        {'key': 'company', 'label': 'Company', 'required': false},
        {'key': 'countryCode', 'label': 'Country Code', 'required': false},
        {'key': 'position', 'label': 'Position', 'required': false},
        {'key': 'address', 'label': 'Address', 'required': false},
        {'key': 'city', 'label': 'City', 'required': false},
        {'key': 'country', 'label': 'Country', 'required': false},
        {'key': 'website', 'label': 'Website', 'required': false},
        {'key': 'leadValue', 'label': 'Lead Value', 'required': false},
        {'key': 'description', 'label': 'Description', 'required': false},
        {'key': 'source', 'label': 'Source', 'required': false},
        {'key': 'status', 'label': 'Status', 'required': false},
        {'key': 'assigned', 'label': 'Assigned', 'required': false},
        {'key': 'product', 'label': 'Product', 'required': false},
      ];
      for (final f in custom) {
        final key = (f['fieldKey'] ?? '').toString();
        final label = (f['fieldName'] ?? '').toString();
        final idx = fields.indexWhere((element) => element['key'] == key || element['label'].toString().toLowerCase() == label.toLowerCase());
        if (idx >= 0) {
          if (key != 'name' && key != 'mobile') {
            fields[idx]['required'] = false;
          }
        } else if (key.startsWith('custom_')) {
          fields.add({
            'key': key,
            'label': label,
            'required': false,
          });
        }
      }
      if (mounted) {
        setState(() {
          _allFields = fields;
        });
      }
    } catch (_) {}
  }

  Future<void> _runDuplicateDetection() async {
    setState(() => _loading = true);
    try {
      final repo = AppScope.of(context).leads;
      final page = await repo.fetchLeads(limit: 5000);
      if (mounted) {
        setState(() {
          _existingLeads = page.leads;
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _autoMapHeaders() {
    for (final header in _headers) {
      final lowerHeader = header.toLowerCase().trim();
      final matched = _allFields.firstWhere(
        (f) {
          final lowerLabel = f['label'].toString().toLowerCase().trim();
          final lowerKey = f['key'].toString().toLowerCase().trim();
          return lowerHeader == lowerLabel || lowerHeader == lowerKey ||
              lowerHeader.contains(lowerLabel) || lowerLabel.contains(lowerHeader) ||
              lowerHeader.contains(lowerKey) || lowerKey.contains(lowerHeader);
        },
        orElse: () => <String, dynamic>{},
      );
      if (matched.isNotEmpty) {
        _fieldMapping[header] = matched['key'].toString();
      }
    }
  }

  List<List<String>> _parseCsv(String content) {
    final List<List<String>> results = [];
    List<String> currentRow = [];
    final buffer = StringBuffer();
    bool inQuotes = false;
    
    final hasComma = content.contains(',');
    final hasSemicolon = content.contains(';');
    final delimiter = (hasSemicolon && !hasComma) ? ';' : ',';

    int i = 0;
    while (i < content.length) {
      final char = content[i];
      
      if (char == '"') {
        if (inQuotes && i + 1 < content.length && content[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == delimiter && !inQuotes) {
        currentRow.add(buffer.toString().trim());
        buffer.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        currentRow.add(buffer.toString().trim());
        buffer.clear();
        
        if (currentRow.isNotEmpty && currentRow.any((e) => e.isNotEmpty)) {
          results.add(List<String>.from(currentRow));
        }
        currentRow.clear();
        
        if (char == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
          i++;
        }
      } else {
        buffer.write(char);
      }
      i++;
    }
    
    if (buffer.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(buffer.toString().trim());
      if (currentRow.isNotEmpty && currentRow.any((e) => e.isNotEmpty)) {
        results.add(currentRow);
      }
    }
    
    return results;
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (!file.name.toLowerCase().endsWith('.csv')) {
          appToast(context, 'Please select a CSV file (.csv)', isError: true);
          return;
        }
        String content = '';
        if (file.bytes != null) {
          content = utf8.decode(file.bytes!, allowMalformed: true);
        } else if (file.path != null) {
          final f = File(file.path!);
          content = await f.readAsString();
        }
        if (content.startsWith('\uFEFF')) {
          content = content.substring(1);
        }
        final rows = _parseCsv(content);
        if (rows.isEmpty) {
          appToast(context, 'CSV file is empty', isError: true);
          return;
        }
        setState(() {
          _parsedRows = rows;
          _headers = rows.first;
          _fileName = file.name;
          _fileChosen = true;
          
          _fieldMapping = {};
          for (final h in _headers) {
            _fieldMapping[h] = '';
          }
          _autoMapHeaders();
        });
      }
    } catch (e) {
      appToast(context, 'Error reading file: $e', isError: true);
    }
  }

  List<Map<String, dynamic>> _buildLeadsToImport() {
    if (_parsedRows.length <= 1) return [];

    final mappingIndices = <String, int>{};
    for (final entry in _fieldMapping.entries) {
      final csvHeader = entry.key;
      final targetField = entry.value;
      if (targetField.isNotEmpty) {
        final idx = _headers.indexOf(csvHeader);
        if (idx >= 0) {
          mappingIndices[targetField] = idx;
        }
      }
    }

    final List<Map<String, dynamic>> list = [];
    for (int i = 1; i < _parsedRows.length; i++) {
      final row = _parsedRows[i];
      final Map<String, dynamic> lead = {};
      
      for (final entry in mappingIndices.entries) {
        final fieldKey = entry.key;
        final idx = entry.value;
        if (idx < row.length) {
          lead[fieldKey] = row[idx].toString().trim();
        }
      }

      final name = lead['name']?.toString() ?? '';
      final rawMobile = lead['mobile']?.toString() ?? '';
      if (name.isEmpty && rawMobile.isEmpty) continue;

      final cleanMobile = rawMobile.replaceAll(RegExp(r'\D'), '');
      
      var cleanCountryCode = lead['countryCode']?.toString().trim() ?? '';
      if (cleanCountryCode.isNotEmpty) {
        final hasPlus = cleanCountryCode.startsWith('+');
        cleanCountryCode = cleanCountryCode.replaceAll(RegExp(r'\D'), '');
        if (hasPlus) {
          cleanCountryCode = '+$cleanCountryCode';
        }
      }

      lead['name'] = name;
      lead['mobile'] = cleanMobile;
      if (cleanCountryCode.isNotEmpty) {
        lead['countryCode'] = cleanCountryCode;
      } else {
        lead['countryCode'] = '91'; // Default to 91 matching web
      }

      lead['status'] = (lead['status']?.toString().isNotEmpty == true) ? lead['status'] : 'New Lead';
      lead['source'] = (lead['source']?.toString().isNotEmpty == true) ? lead['source'] : 'Import';
      lead['isConverted'] = false;
      lead['tags'] = [];
      lead['description'] = lead['description']?.toString() ?? '';
      lead['notes'] = '';

      final mappedAssigned = (lead['assigned'] ?? lead['assignedTo'])?.toString().trim();
      if (_assignmentMode == 'round_robin') {
        if (mappedAssigned != null && mappedAssigned.isNotEmpty) {
          lead['assigned'] = mappedAssigned;
          lead['assignedTo'] = mappedAssigned;
        } else if (_agentNames.isNotEmpty) {
          final assignedAgent = _agentNames[list.length % _agentNames.length];
          lead['assigned'] = assignedAgent;
          lead['assignedTo'] = assignedAgent;
        }
      } else {
        if (mappedAssigned != null && mappedAssigned.isNotEmpty) {
          lead['assigned'] = mappedAssigned;
          lead['assignedTo'] = mappedAssigned;
        } else {
          lead['assigned'] = null;
          lead['assignedTo'] = null;
        }
      }

      list.add(lead);
    }
    return list;
  }

  bool _isDuplicate(Map<String, dynamic> lead) {
    final mob = (lead['mobile'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    final email = (lead['email'] ?? '').toString().trim().toLowerCase();
    final name = (lead['name'] ?? '').toString().trim().toLowerCase();

    for (final ex in _existingLeads) {
      final exMob = ex.mobile.replaceAll(RegExp(r'\D'), '');
      if (mob.isNotEmpty && exMob.isNotEmpty) {
        final mobLast10 = mob.length >= 10 ? mob.substring(mob.length - 10) : mob;
        final exMobLast10 = exMob.length >= 10 ? exMob.substring(exMob.length - 10) : exMob;
        if (mobLast10 == exMobLast10) return true;
      }
      if (_checkEmail && email.isNotEmpty && ex.email.trim().toLowerCase() == email) {
        return true;
      }
      if (_checkName && name.isNotEmpty && ex.name.trim().toLowerCase() == name) {
        return true;
      }
    }
    return false;
  }

  ({List<Map<String, dynamic>> unique, List<Map<String, dynamic>> duplicates}) _categorizeLeads() {
    final all = _buildLeadsToImport();
    final List<Map<String, dynamic>> unique = [];
    final List<Map<String, dynamic>> duplicates = [];

    for (final l in all) {
      if (_isDuplicate(l)) {
        duplicates.add(l);
      } else {
        unique.add(l);
      }
    }
    return (unique: unique, duplicates: duplicates);
  }

  Future<void> _exportDuplicates(List<Map<String, dynamic>> duplicates) async {
    if (duplicates.isEmpty) return;
    final csvHeader = 'Country Code,Mobile,Name,Email,Company\n';
    final csvRows = duplicates.map((d) {
      final cc = d['countryCode'] ?? '91';
      final mob = d['mobile'] ?? '';
      final name = d['name'] ?? '';
      final email = d['email'] ?? '';
      final comp = d['company'] ?? '';
      return '"$cc","$mob","$name","$email","$comp"';
    }).join('\n');
    final csvContent = csvHeader + csvRows;
    final bytes = Uint8List.fromList(utf8.encode(csvContent));
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Duplicates CSV',
        fileName: 'duplicates_export.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );
      if (path != null && mounted) {
        appToast(context, 'Duplicates exported successfully to $path');
      }
    } catch (e) {
      if (mounted) appToast(context, 'Error exporting duplicates: $e', isError: true);
    }
  }

  Future<void> _performImport() async {
    setState(() => _loading = true);
    try {
      final repo = AppScope.of(context).leads;
      final categorized = _categorizeLeads();

      List<Map<String, dynamic>> leadsToImport;
      if (_duplicateAction == 'skip') {
        leadsToImport = categorized.unique;
      } else if (_duplicateAction == 'overwrite') {
        leadsToImport = categorized.unique;
      } else {
        leadsToImport = [...categorized.unique, ...categorized.duplicates];
      }

      _totalParsedCount = _buildLeadsToImport().length;
      _duplicateCount = categorized.duplicates.length;

      final res = await repo.bulkCreateLeads(
        leadsToImport,
        duplicateAction: _duplicateAction == 'overwrite' ? 'update' : (_duplicateAction == 'skip' ? 'skip' : 'create'),
        assignmentMode: _assignmentMode,
        sendAlert: _sendAlertMessage,
      );

      _successCount = res['imported'] ?? leadsToImport.length;
      _failedCount = res['failed'] ?? 0;
      if (mounted) {
        setState(() {
          _step = 3;
        });
      }
    } catch (e) {
      if (mounted) appToast(context, 'Import failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categorized = _categorizeLeads();
    final int toImportCount = _duplicateAction == 'skip'
        ? categorized.unique.length
        : categorized.unique.length + categorized.duplicates.length;

    return sheetScaffold(
      context,
      title: 'Import Leads',
      icon: Icons.download_rounded,
      body: SizedBox(
        height: MediaQuery.of(context).size.height * 0.68,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
            child: Row(children: [
              for (var i = 0; i < _steps.length; i++) ...[
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: i <= _step ? AppColors.evaGreen : AppColors.surface2, shape: BoxShape.circle),
                  child: i < _step
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : Text('${i + 1}', style: AppText.poppins(size: 11, weight: FontWeight.w800, color: i == _step ? Colors.white : AppColors.ink4)),
                ),
                if (i != _steps.length - 1) Expanded(child: Container(height: 2, color: i < _step ? AppColors.evaGreen : AppColors.line)),
              ],
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.evaGreen))
                : SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 20), child: _stepBody(categorized)),
          ),
        ]),
      ),
      footer: _step == 3
          ? const SizedBox.shrink()
          : Row(
              children: [
                if (_step > 0 && _step < 3) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Back', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: primaryButton(
                    context,
                    _step == 2 ? 'Import $toImportCount Contacts' : 'Continue',
                    _next,
                    icon: Icons.arrow_forward_rounded,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _stepBody(({List<Map<String, dynamic>> unique, List<Map<String, dynamic>> duplicates}) categorized) {
    switch (_step) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 10),
          Center(
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.description_rounded, size: 30, color: AppColors.evaGreen),
                ),
                const SizedBox(height: 12),
                Text(
                  'Import Leads',
                  style: AppText.poppins(size: 16.5, weight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  'Upload a CSV file to import your contacts as leads',
                  textAlign: TextAlign.center,
                  style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD1FAE5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.file_upload_outlined, size: 18, color: AppColors.evaGreen),
                  const SizedBox(width: 8),
                  Text(
                    _fileChosen ? _fileName : 'Select File',
                    style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Duplicate Detection Settings',
                    style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink),
                  ),
                ),
                const Divider(height: 1, color: AppColors.line),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Check for duplicates based on:',
                        style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.check_box_rounded, color: AppColors.ink4.withValues(alpha: 0.5), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Mobile Number (Required)',
                            style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink4),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => setState(() => _checkEmail = !_checkEmail),
                        child: Row(
                          children: [
                            Icon(
                              _checkEmail ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                              color: _checkEmail ? AppColors.evaGreen : AppColors.ink4,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Email Address',
                              style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => setState(() => _checkName = !_checkName),
                        child: Row(
                          children: [
                            Icon(
                              _checkName ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                              color: _checkName ? AppColors.evaGreen : AppColors.ink4,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Name',
                              style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
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
        ]);

      case 1: // Map Fields step with mandatory column validation
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Map CSV columns to lead fields. Mandatory fields (*) must be mapped.',
              style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3),
            ),
            const SizedBox(height: 16),
            for (final header in _headers) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            header,
                            style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sample: ${_parsedRows.length > 1 && _headers.indexOf(header) < _parsedRows[1].length ? _parsedRows[1][_headers.indexOf(header)] : "-"}',
                            style: AppText.poppins(size: 11, weight: FontWeight.w500, color: AppColors.ink4),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 160,
                      child: formSelect<String>(
                        value: _fieldMapping[header] == '' ? null : _fieldMapping[header],
                        placeholder: 'Select field',
                        options: [
                          ('', "Don't import"),
                          for (final f in _allFields)
                            (
                              f['key'].toString(),
                              '${f['label']}${f['required'] == true ? " *" : ""}'
                            ),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _fieldMapping[header] = v ?? '';
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );

      case 2: // Preview & Handle Duplicates step (Matches Screenshots 1 & 2!)
        final uniqueList = categorized.unique;
        final duplicateList = categorized.duplicates;
        final totalPages = (duplicateList.length / _pageSize).ceil();
        final pagedDuplicates = duplicateList.skip((_duplicatePage - 1) * _pageSize).take(_pageSize).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preview Data', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text(
              'Review the mapped data before importing. Duplicates have been detected and separated.',
              style: AppText.poppins(size: 12.5, weight: FontWeight.w500, color: AppColors.ink4),
            ),
            const SizedBox(height: 14),

            // Tab bar: Unique Records (N) | Duplicates (M)
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _previewTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _previewTab == 0 ? const Color(0xFFE8FDF0) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _previewTab == 0 ? AppColors.evaGreen : AppColors.line),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 16, color: _previewTab == 0 ? AppColors.evaGreenDeep : AppColors.ink3),
                        const SizedBox(width: 6),
                        Text('Unique Records (${uniqueList.length})', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: _previewTab == 0 ? AppColors.evaGreenDeep : AppColors.ink3)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => setState(() => _previewTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _previewTab == 1 ? const Color(0xFFFEF3C7) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _previewTab == 1 ? const Color(0xFFF59E0B) : AppColors.line),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: _previewTab == 1 ? const Color(0xFFB45309) : AppColors.ink3),
                        const SizedBox(width: 6),
                        Text('Duplicates (${duplicateList.length})', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: _previewTab == 1 ? const Color(0xFFB45309) : AppColors.ink3)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_previewTab == 0) ...[
              // Unique Records Tab
              if (uniqueList.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.inbox_outlined, size: 40, color: AppColors.ink4),
                      const SizedBox(height: 8),
                      Text('No data', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink4)),
                    ],
                  ),
                ),
              ] else ...[
                for (final r in uniqueList.take(10))
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.line)),
                    child: Row(children: [
                      InitialsAvatar(initials: _initials(r['name'] ?? ''), color: avatarColorFor(r['name'] ?? ''), size: 34, radius: 10),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r['name'] ?? '', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink)),
                          const SizedBox(height: 2),
                          Text('+${r['countryCode']} ${r['mobile']} ${r['email'] != null ? "· ${r['email']}" : ""}', style: AppText.poppins(size: 11.5, color: AppColors.ink3)),
                        ]),
                      ),
                    ]),
                  ),
              ],
            ] else ...[
              // Duplicates Tab (Screenshot 2!)
              if (duplicateList.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 40, color: AppColors.evaGreen),
                      const SizedBox(height: 8),
                      Text('No duplicate records found!', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                    ],
                  ),
                ),
              ] else ...[
                // Yellow Notice Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Found ${duplicateList.length} duplicate records', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: const Color(0xFFB45309))),
                            Text('These records match existing leads based on the duplicate check criteria.', style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: const Color(0xFF92400E))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Duplicate Actions row: Dropdown + Export Button
                Row(
                  children: [
                    Text('Duplicate Action:', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.line)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _duplicateAction,
                            isExpanded: true,
                            style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink),
                            items: const [
                              DropdownMenuItem(value: 'skip', child: Text('Skip Duplicates')),
                              DropdownMenuItem(value: 'overwrite', child: Text('Overwrite Existing')),
                              DropdownMenuItem(value: 'include_all', child: Text('Import All (Include Duplicates)')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _duplicateAction = v);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _exportDuplicates(duplicateList),
                      icon: const Icon(Icons.download_rounded, size: 14, color: AppColors.ink),
                      label: Text('Export Duplicates', style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        side: const BorderSide(color: AppColors.line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Table of duplicates
                Container(
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        color: AppColors.surface2,
                        child: Row(
                          children: [
                            SizedBox(width: 50, child: Text('Country', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink3))),
                            Expanded(flex: 2, child: Text('Mobile', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink3))),
                            Expanded(flex: 3, child: Text('Name', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink3))),
                            SizedBox(width: 80, child: Text('Status', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink3))),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.line),
                      for (final item in pagedDuplicates)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line, width: 0.5))),
                          child: Row(
                            children: [
                              SizedBox(width: 50, child: Text('${item['countryCode']}', style: AppText.poppins(size: 11.5, color: AppColors.ink))),
                              Expanded(flex: 2, child: Text('${item['mobile']}', style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink))),
                              Expanded(flex: 3, child: Text('${item['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink))),
                              SizedBox(
                                width: 80,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFFCD34D))),
                                  child: Text('Duplicate', textAlign: TextAlign.center, style: AppText.poppins(size: 10, weight: FontWeight.w800, color: const Color(0xFFB45309))),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (totalPages > 1) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _duplicatePage > 1 ? () => setState(() => _duplicatePage--) : null,
                        icon: const Icon(Icons.chevron_left_rounded, size: 18),
                      ),
                      for (int p = 1; p <= totalPages; p++) ...[
                        GestureDetector(
                          onTap: () => setState(() => _duplicatePage = p),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _duplicatePage == p ? AppColors.evaGreen : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('$p', style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: _duplicatePage == p ? Colors.white : AppColors.ink2)),
                          ),
                        ),
                      ],
                      IconButton(
                        onPressed: _duplicatePage < totalPages ? () => setState(() => _duplicatePage++) : null,
                        icon: const Icon(Icons.chevron_right_rounded, size: 18),
                      ),
                    ],
                  ),
                ],
              ],
            ],

            const SizedBox(height: 16),
            // Send Alert Message checkbox
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBBF7D0))),
              child: GestureDetector(
                onTap: () => setState(() => _sendAlertMessage = !_sendAlertMessage),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _sendAlertMessage ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      color: _sendAlertMessage ? AppColors.evaGreen : AppColors.ink4,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Send new lead alert message for imported contacts', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink)),
                          const SizedBox(height: 2),
                          Text('This will trigger notifications for each successfully imported lead', style: AppText.poppins(size: 11, color: AppColors.ink3)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

      default: // Step 3: Import Complete (Screenshot 3!)
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Text('Import Complete', style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 24),

              // 4 Stat Metric Cards (Total | Success | Failed | Duplicates)
              Row(
                children: [
                  Expanded(
                    child: _statCard('Total', '$_totalParsedCount', AppColors.ink),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard('Success', '$_successCount', AppColors.evaGreenDeep),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard('Failed', '$_failedCount', AppColors.danger),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard('Duplicates', '$_duplicateCount', const Color(0xFFD97706)),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onDone?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.evaGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: Text('Close', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Text(label, style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3)),
          const SizedBox(height: 6),
          Text(value, style: AppText.poppins(size: 20, weight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Future<void> _next() async {
    if (_step == 0) {
      if (!_fileChosen) {
        appToast(context, 'Choose a CSV file first', isError: true);
        return;
      }
      _runDuplicateDetection();
      setState(() => _step = 1);
      return;
    }

    if (_step == 1) {
      // Validate mandatory fields (Name and Mobile are required for CSV lead import!)
      final missingRequired = <String>[];
      final mappedTargetFields = _fieldMapping.values.toSet();
      if (!mappedTargetFields.contains('name')) missingRequired.add('Name');
      if (!mappedTargetFields.contains('mobile')) missingRequired.add('Mobile');

      if (missingRequired.isNotEmpty) {
        appToast(context, 'Please map mandatory fields: ${missingRequired.join(", ")}', isError: true);
        return;
      }

      await _runDuplicateDetection();
      setState(() => _step = 2);
      return;
    }

    if (_step == 2) {
      await _performImport();
      return;
    }

    if (_step == 3) {
      Navigator.of(context).pop();
      widget.onDone?.call();
    }
  }
}

Future<void> showCardScanner(BuildContext context, {required List<String> companies, required List<String> sources, required List<String> agents}) => showAppSheet(context, _CardScanner(companies: companies, sources: sources, agents: agents));

class _CardScanner extends StatefulWidget {
  final List<String> companies, sources, agents;
  const _CardScanner({required this.companies, required this.sources, required this.agents});
  @override
  State<_CardScanner> createState() => _CardScannerState();
}

class _CardScannerState extends State<_CardScanner> {
  bool _scanning = false;

  Future<void> _scan() async {
    setState(() => _scanning = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    Navigator.of(context).pop();

    final scannedLead = LeadDto(
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

    // OCR-simulated prefill -> open the lead form with extracted values.
    showLeadForm(
      context,
      lead: scannedLead,
      companies: widget.companies,
      sources: ['Business Card', ...widget.sources],
      agents: widget.agents,
    );
  }

  @override
  Widget build(BuildContext context) {
    return sheetScaffold(
      context,
      title: 'Scan Business Card',
      icon: Icons.document_scanner_rounded,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AspectRatio(
            aspectRatio: 1.6,
            child: Container(
              decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(16)),
              child: Stack(alignment: Alignment.center, children: [
                if (_scanning)
                  const CircularProgressIndicator(color: AppColors.evaLimeGlow)
                else
                  const Icon(Icons.credit_card_rounded, size: 44, color: Colors.white30),
                // alignment frame
                Padding(padding: const EdgeInsets.all(22), child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.evaLimeGlow, width: 2)))),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Text(_scanning ? 'Reading card…' : 'Align the card inside the frame', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink2)),
        ]),
      ),
      footer: primaryButton(context, _scanning ? 'Scanning…' : 'Capture', _scanning ? () {} : _scan, icon: Icons.camera_alt_rounded),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
}

class CustomDateRangePicker extends StatefulWidget {
  final List<DateTime>? initialRange;
  const CustomDateRangePicker({super.key, this.initialRange});

  @override
  State<CustomDateRangePicker> createState() => CustomDateRangePickerState();
}

class CustomDateRangePickerState extends State<CustomDateRangePicker> {
  DateTime? _start;
  DateTime? _end;
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    if (widget.initialRange != null && widget.initialRange!.length == 2) {
      _start = widget.initialRange![0];
      _end = widget.initialRange![1];
    }
    _currentMonth = _start ?? DateTime.now();
  }

  void _onDayTapped(DateTime day) {
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        _start = day;
        _end = null;
      } else {
        if (day.isBefore(_start!)) {
          _start = day;
        } else {
          _end = day;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final startOffset = firstDay.weekday % 7; 
    final totalCells = startOffset + daysInMonth;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom + 10),
      child: SingleChildScrollView(
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
              Expanded(
                child: Text(
                  'Select date range',
                  style: AppText.poppins(size: 17.5, weight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 18, color: AppColors.ink4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.evaGreen50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.evaGreen200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      _start == null
                          ? 'Start date'
                          : '${_start!.day}/${_start!.month}/${_start!.year}',
                      style: AppText.poppins(
                        size: 14,
                        weight: FontWeight.w700,
                        color: _start == null ? AppColors.ink4 : AppColors.evaGreenDeep,
                      ),
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.evaGreenDeep),
                Expanded(
                  child: Center(
                    child: Text(
                      _end == null
                          ? 'End date'
                          : '${_end!.day}/${_end!.month}/${_end!.year}',
                      style: AppText.poppins(
                        size: 14,
                        weight: FontWeight.w700,
                        color: _end == null ? AppColors.ink4 : AppColors.evaGreenDeep,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)),
                icon: const Icon(Icons.chevron_left_rounded, color: AppColors.ink3),
              ),
              Text(
                '${_monthName(_currentMonth.month)} ${_currentMonth.year}',
                style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink),
              ),
              IconButton(
                onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)),
                icon: const Icon(Icons.chevron_right_rounded, color: AppColors.ink3),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: Center(child: Text('Su', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink4)))),
              Expanded(child: Center(child: Text('Mo', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink4)))),
              Expanded(child: Center(child: Text('Tu', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink4)))),
              Expanded(child: Center(child: Text('We', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink4)))),
              Expanded(child: Center(child: Text('Th', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink4)))),
              Expanded(child: Center(child: Text('Fr', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink4)))),
              Expanded(child: Center(child: Text('Sa', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink4)))),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (ctx, i) {
              if (i < startOffset) return const SizedBox();
              final dayNum = i - startOffset + 1;
              final dayDate = DateTime(_currentMonth.year, _currentMonth.month, dayNum);

              final isStart = _start != null && _isSameDay(dayDate, _start!);
              final isEnd = _end != null && _isSameDay(dayDate, _end!);
              final isBetween = _start != null && _end != null && dayDate.isAfter(_start!) && dayDate.isBefore(_end!);

              Color? bg;
              Color textCol = AppColors.ink;

              if (isStart || isEnd) {
                bg = AppColors.evaGreen;
                textCol = Colors.white;
              } else if (isBetween) {
                bg = AppColors.evaGreen50;
                textCol = AppColors.evaGreenDeep;
              }

              return GestureDetector(
                onTap: () => _onDayTapped(dayDate),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: (isStart || isEnd) ? BoxShape.circle : BoxShape.rectangle,
                      borderRadius: (isStart || isEnd) ? null : BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textCol,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _start = null;
                      _end = null;
                    });
                  },
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Clear',
                      style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_start != null && _end != null) {
                      Navigator.of(context).pop([_start!, _end!]);
                    } else if (_start != null) {
                      Navigator.of(context).pop([_start!, _start!]);
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.evaGreen,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Apply',
                      style: AppText.poppins(size: 14, weight: FontWeight.w700, color: Colors.white),
                    ),
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _monthName(int m) {
    return const [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ][m];
  }
}
