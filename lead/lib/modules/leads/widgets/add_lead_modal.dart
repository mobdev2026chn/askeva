import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:askeva/widgets/app_drawer.dart';
import 'package:askeva/widgets/drawer_menu_icon.dart';
import '../../../services/leads_service.dart';

class AddLeadModal extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback? onCancel;
  final String? initialPhoneNumber;

  const AddLeadModal({
    super.key,
    required this.onSuccess,
    this.onCancel,
    this.initialPhoneNumber,
    this.lead,
    this.isFromScan = false,
    this.initialAgentName,
  });

  final Map<String, dynamic>? lead;
  final bool isFromScan;
  final String? initialAgentName;

  @override
  State<AddLeadModal> createState() => _AddLeadModalState();
}

class _AddLeadModalState extends State<AddLeadModal> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  bool get _hasAssignee => _assignedId != null && _agentSearchCtrl.text.trim().isNotEmpty;

  // Form Fields
  String? _status;
  String? _source;
  String? _assignedId; // User ID
  String? _companyId;
  String? _countryCode = '91'; // Default India
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  // Tags
  final List<String> _tags = [];
  final _tagCtrl = TextEditingController();

  // Smart Agent/Company Input
  final _agentSearchCtrl = TextEditingController();
  final _companySearchCtrl = TextEditingController();

  // Checkbox
  bool _sendWelcomeMessage = false;
  String? _rawOcrText;

  // Dynamic API Configuration Fields
  final Map<String, TextEditingController> _customControllers = {};
  final Map<String, String?> _customDropdownValues = {};
  List<dynamic> _fields = [];
  bool _loadingFields = true;

  // Data Options (country codes default so dropdown has values before fetch)
  List<String> _statuses = [];
  List<String> _sources = [];
  List<dynamic> _agents = [];
  List<dynamic> _companies = [];
  List<Map<String, String>> _countryCodes = [
    {'code': '91', 'name': 'India'},
    {'code': '1', 'name': 'USA'},
    {'code': '44', 'name': 'UK'},
    {'code': '81', 'name': 'Japan'},
    {'code': '61', 'name': 'Australia'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoneNumber != null) {
      _mobileCtrl.text = widget.initialPhoneNumber!;
    }

    if (widget.lead != null) {
      final l = widget.lead!;
      // Use only lead's own name/email; never show assignedTo (agent) name/email in lead fields
      final assigned = l['assignedTo'];
      final agentName = assigned is Map ? (assigned['name'] ?? assigned['username'])?.toString() : null;
      final agentEmail = assigned is Map ? (assigned['email'])?.toString() : null;
      var leadName = l['name'] is String ? l['name'] as String? : (l['name']?.toString());
      var leadEmail = l['email'] is String ? l['email'] as String? : (l['email']?.toString());
      if (agentName != null && leadName == agentName) leadName = null;
      if (agentEmail != null && leadEmail == agentEmail) leadEmail = null;
      _nameCtrl.text = leadName ?? '';
      _mobileCtrl.text = l['mobile']?.toString() ?? '';
      _emailCtrl.text = leadEmail ?? '';
      _status = widget.isFromScan ? 'New Lead' : l['status'];
      _source = widget.isFromScan ? 'Business Card' : l['source'];
      if (l['company'] is Map) {
        _companyId = l['company']['_id'] ?? l['company']['id'];
        _companySearchCtrl.text = l['company']['name'] ?? '';
      } else {
        _companyId = l['company'];
      }
      _positionCtrl.text = l['position'] ?? '';
      _addressCtrl.text = l['address'] ?? '';
      _websiteCtrl.text = l['website'] ?? '';
      _cityCtrl.text = l['city'] ?? '';
      _valueCtrl.text = l['value']?.toString() ?? l['leadValue']?.toString() ?? '';
      _countryCtrl.text = l['country'] ?? '';
      _descCtrl.text = l['description'] ?? '';

      if (l['tags'] != null) {
        _tags.addAll((l['tags'] as List).map((e) => e.toString()));
      }

      // Assigned: backend may return assignedTo as object {_id, email, name} or as id string; also check assigned
      final assignedRaw = l['assignedTo'] ?? l['assigned'];
      if (assignedRaw != null) {
        if (assignedRaw is Map) {
          final id = assignedRaw['\$oid'] ?? assignedRaw['_id'] ?? assignedRaw['id'];
          _assignedId = id?.toString();
          _agentSearchCtrl.text = (assignedRaw['email'] ?? assignedRaw['name'] ?? assignedRaw['username'] ?? '').toString();
          if (kDebugMode) {
            debugPrint('[AddLeadModal] initState assignedTo (Map): id=$_assignedId, display=${_agentSearchCtrl.text}');
          }
        } else {
          _assignedId = assignedRaw.toString().trim();
          if (_assignedId!.isEmpty) _assignedId = null;
          // Display text will be set in _fetchOptions when agents load (match by id)
          if (kDebugMode) {
            debugPrint('[AddLeadModal] initState assignedTo (string): _assignedId=$_assignedId');
          }
        }
      }
      _rawOcrText = l['rawOcrText'];
    }

    if (widget.isFromScan) {
      _sources = ['Business Card'];
      _statuses = ['New Lead'];
    }

    if (widget.isFromScan && widget.initialAgentName != null) {
      _agentSearchCtrl.text = widget.initialAgentName!;
    }

    _fetchOptions();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _websiteCtrl.dispose();
    _positionCtrl.dispose();
    _cityCtrl.dispose();
    _valueCtrl.dispose();
    _descCtrl.dispose();
    _countryCtrl.dispose();
    _tagCtrl.dispose();
    _agentSearchCtrl.dispose();
    _companySearchCtrl.dispose();
    for (final ctrl in _customControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  String getFieldJsonKey(String fieldName) {
    switch (fieldName) {
      case 'Name': return 'name';
      case 'Company': return 'company';
      case 'Email': return 'email';
      case 'Status': return 'status';
      case 'Source': return 'source';
      case 'Assigned': return 'assigned';
      case 'Position': return 'position';
      case 'Country Code': return 'countryCode';
      case 'Mobile': return 'mobile';
      case 'Address': return 'address';
      case 'City': return 'city';
      case 'Country': return 'country';
      case 'Website': return 'website';
      case 'Lead Value': return 'value';
      case 'Tags': return 'tags';
      case 'Description': return 'description';
      default:
        return 'cf_${fieldName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '')}';
    }
  }

  bool _isBuiltin(String name) {
    const builtins = ["Name", "Company", "Email", "Status", "Source", "Assigned", "Position", "Country Code", "Mobile", "Product", "Address", "City", "Country", "Website", "Lead Value", "Tags", "Description"];
    return builtins.contains(name);
  }

  bool _isFieldShown(String name) {
    final f = _fields.firstWhere((e) => (e['fieldName'] ?? e['name'] ?? '') == name, orElse: () => null);
    if (f == null) return true;
    return f['displayInTable'] == true;
  }

  bool _isFieldRequired(String name) {
    final f = _fields.firstWhere((e) => (e['fieldName'] ?? e['name'] ?? '') == name, orElse: () => null);
    if (f == null) return false;
    return f['mandatory'] == true;
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _fetchOptions() async {
    try {
      final fields = await LeadsService.getLeadFields();
      final statuses = await LeadsService.getStatuses();
      final sources = await LeadsService.getSources();
      final agents = await LeadsService.getAgents();
      final companies = await LeadsService.getCompanies();
      final countryCodes = await LeadsService.getCountryCodeOptions();

      if (mounted) {
        setState(() {
          _fields = fields;
          for (final f in _fields) {
            final name = (f['fieldName'] ?? f['name'] ?? '').toString();
            if (name.isEmpty || _isBuiltin(name)) continue;
            final key = getFieldJsonKey(name);
            final type = (f['fieldType'] ?? 'input').toString().toLowerCase();
            
            final initialVal = widget.lead?[key]?.toString() ?? '';
            if (type == 'select' || type == 'dropdown') {
              _customDropdownValues[key] = initialVal.isEmpty ? null : initialVal;
            } else {
              _customControllers[key] = TextEditingController(text: initialVal);
            }
          }
          _loadingFields = false;

          if (widget.isFromScan) {
            _statuses = ['New Lead'];
          } else {
            _statuses = statuses;
          }
          _sources = sources;
          _agents = agents;
          _companies = companies;
          _countryCodes = countryCodes.isNotEmpty
              ? countryCodes
              : [
                  {'code': '1', 'name': 'USA'},
                  {'code': '91', 'name': 'India'},
                  {'code': '44', 'name': 'UK'},
                  {'code': '61', 'name': 'Australia'},
                  {'code': '81', 'name': 'Japan'},
                ];
          if (_countryCode != null &&
              !_countryCodes.any((e) => e['code'] == _countryCode)) {
            _countryCode = _countryCodes.isNotEmpty ? _countryCodes.first['code'] : '91';
          }

          if (widget.isFromScan && !_sources.contains('Business Card')) {
            _sources.add('Business Card');
          }

          if (_assignedId == null && widget.initialAgentName != null) {
            final me = _agents.firstWhere(
              (a) {
                final name = (a['name'] ?? a['username'] ?? '').toString().toLowerCase();
                final email = (a['email'] ?? '').toString().toLowerCase();
                final q = widget.initialAgentName!.toLowerCase();
                return name == q || email == q;
              },
              orElse: () => null,
            );
            if (me != null) {
              _assignedId = (me['_id'] ?? me['id'])?.toString();
              _agentSearchCtrl.text = (me['email'] ?? me['name'] ?? me['username'] ?? '').toString();
            }
          }
          if (_assignedId != null && _assignedId!.isNotEmpty && _agentSearchCtrl.text.trim().isEmpty) {
            final agent = _agents.cast<Map<String, dynamic>>().where((a) {
              final aid = (a['_id'] ?? a['id'])?.toString();
              return aid != null && aid == _assignedId;
            }).toList();
            if (agent.isNotEmpty) {
              _agentSearchCtrl.text = (agent.first['email'] ?? agent.first['name'] ?? agent.first['username'] ?? '').toString();
              if (kDebugMode) {
                debugPrint('[AddLeadModal] _fetchOptions resolved assigned display: _assignedId=$_assignedId, display=${_agentSearchCtrl.text}');
              }
            } else if (kDebugMode) {
              debugPrint('[AddLeadModal] _fetchOptions no agent match for _assignedId=$_assignedId, agentsCount=${_agents.length}');
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingFields = false;
          if (_statuses.isEmpty) {
            _statuses = ['New Lead', 'Hot', 'Warm', 'Cold', 'Invalid'];
          }
          if (_sources.isEmpty) {
            _sources = ['Website', 'Referral', 'Social Media', 'Business Card'];
          }
          if (_countryCodes.isEmpty) {
            _countryCodes = [
              {'code': '1', 'name': 'USA'},
              {'code': '91', 'name': 'India'},
              {'code': '44', 'name': 'UK'},
              {'code': '61', 'name': 'Australia'},
              {'code': '81', 'name': 'Japan'},
            ];
          }
        });
      }
    }
  }

  void _addTag(String tag) {
    if (tag.trim().isNotEmpty && !_tags.contains(tag.trim())) {
      setState(() {
        _tags.add(tag.trim());
        _tagCtrl.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _showError('Please fill all required fields');
      return;
    }

    final nameVal = _nameCtrl.text.trim();
    final mobileVal = _mobileCtrl.text.trim();
    final codeVal = _countryCode ?? '91';
    final assignedVal = _assignedId ?? '';
    final statusVal = _status ?? '';
    final sourceVal = _source ?? '';

    // Builtin validation
    if (_isFieldShown('Name') && _isFieldRequired('Name') && nameVal.isEmpty) {
      _showError('Name is required');
      return;
    }
    if (_isFieldShown('Mobile') && _isFieldRequired('Mobile') && mobileVal.isEmpty) {
      _showError('Mobile number is required');
      return;
    }
    if (_isFieldShown('Country Code') && _isFieldRequired('Country Code') && codeVal.isEmpty) {
      _showError('Country code is required');
      return;
    }
    if (_isFieldShown('Status') && _isFieldRequired('Status') && statusVal.isEmpty) {
      _showError('Status is required');
      return;
    }
    if (assignedVal.isEmpty && statusVal != 'New' && statusVal.isNotEmpty) {
      _showError('Assignee is required before choosing status');
      return;
    }
    if (_isFieldShown('Source') && _isFieldRequired('Source') && sourceVal.isEmpty) {
      _showError('Source is required');
      return;
    }
    if (_isFieldShown('Assigned') && _isFieldRequired('Assigned') && assignedVal.isEmpty) {
      _showError('Assignee is required');
      return;
    }

    // Optional builtins validation
    final builtinsMapping = [
      ('Website', _websiteCtrl, 'website URL'),
      ('Email', _emailCtrl, 'email address'),
      ('Position', _positionCtrl, 'position'),
      ('Address', _addressCtrl, 'address'),
      ('City', _cityCtrl, 'city'),
      ('Lead Value', _valueCtrl, 'lead value'),
      ('Country', _countryCtrl, 'country'),
      ('Description', _descCtrl, 'description'),
    ];

    for (final opt in builtinsMapping) {
      final fName = opt.$1;
      final ctrl = opt.$2;
      final label = opt.$3;
      if (_isFieldShown(fName) && _isFieldRequired(fName) && ctrl.text.trim().isEmpty) {
        _showError('Enter $label');
        return;
      }
    }

    // Custom fields validation
    for (final f in _fields) {
      final name = (f['fieldName'] ?? f['name'] ?? '').toString();
      if (_isBuiltin(name)) continue;
      final key = getFieldJsonKey(name);
      if (f['displayInTable'] == true && f['mandatory'] == true) {
        final isSelect = (f['fieldType'] ?? '') == 'select';
        final val = isSelect ? _customDropdownValues[key] : _customControllers[key]?.text.trim();
        if (val == null || val.isEmpty) {
          _showError('$name is required');
          return;
        }
      }
    }

    if (_companyId == null &&
        _companySearchCtrl.text.isNotEmpty &&
        _companySearchCtrl.text.toLowerCase() != 'no company') {
      try {
        setState(() => _isLoading = true);
        final newCompany = await LeadsService.createCompany(
          _companySearchCtrl.text,
        );
        if (mounted) {
          setState(() {
            _companyId = newCompany['_id'] ?? newCompany['id'];
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showError('Error creating company: $e');
        }
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final assignedIdStr = _assignedId?.toString();
      if (kDebugMode) {
        debugPrint('[AddLeadModal] _submit assignedIdStr=$assignedIdStr, assignedDisplay=${_agentSearchCtrl.text.trim()}');
      }
      final data = <String, dynamic>{
        'name': nameVal,
        'status': statusVal.isEmpty ? 'New' : statusVal,
        'mobile': mobileVal,
        'countryCode': codeVal,
        if (sourceVal.isNotEmpty) 'source': sourceVal,
        if (assignedVal.isNotEmpty) 'assignedTo': assignedIdStr,
        if (assignedVal.isNotEmpty) 'assigned': assignedIdStr,
        'isConverted': false,
      };

      void setVal(String fieldName, String key, dynamic value) {
        if (_isFieldShown(fieldName)) {
          if (value != null) data[key] = value;
        } else if (widget.lead != null) {
          final oldVal = widget.lead![key];
          if (oldVal != null) data[key] = oldVal;
        }
      }

      setVal('Email', 'email', _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim());
      setVal('Company', 'company', _companyId ?? (_companySearchCtrl.text.trim().isEmpty ? null : _companySearchCtrl.text.trim()));
      setVal('Position', 'position', _positionCtrl.text.trim().isEmpty ? null : _positionCtrl.text.trim());
      setVal('Address', 'address', _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim());
      setVal('Website', 'website', _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim());
      setVal('City', 'city', _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim());
      setVal('Lead Value', 'value', double.tryParse(_valueCtrl.text));
      setVal('Lead Value', 'leadValue', double.tryParse(_valueCtrl.text));
      setVal('Country', 'country', _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim());
      setVal('Description', 'description', _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim());
      setVal('Tags', 'tags', _tags);

      for (final f in _fields) {
        final name = (f['fieldName'] ?? f['name'] ?? '').toString();
        if (_isBuiltin(name)) continue;
        final key = getFieldJsonKey(name);
        final isSelect = (f['fieldType'] ?? '') == 'select';
        final val = isSelect ? _customDropdownValues[key] : _customControllers[key]?.text.trim();
        
        if (f['displayInTable'] == true) {
          if (val != null) data[key] = val;
        } else if (widget.lead != null) {
          final oldVal = widget.lead![key];
          if (oldVal != null) data[key] = oldVal;
        }
      }

      if (widget.lead == null) {
        data['sendAlert'] = _sendWelcomeMessage;
      }

      if (widget.lead != null && !widget.isFromScan) {
        final leadId = (widget.lead!['_id'] ?? widget.lead!['id'])?.toString();
        if (leadId == null || leadId.isEmpty) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showError('Invalid lead id');
          }
          return;
        }
        if (kDebugMode) {
          debugPrint('[AddLeadModal] updateLead PUT leadId=$leadId, assignedTo=${data['assignedTo']}, assigned=${data['assigned']}');
        }
        await LeadsService.updateLead(leadId, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lead updated successfully')),
          );
        }
      } else {
        await LeadsService.createLead(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lead successfully added')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        _showError('Error adding lead: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildDynamicFieldWidget(Map<String, dynamic> f, ColorScheme cs, Color textColor) {
    final name = (f['fieldName'] ?? f['name'] ?? '').toString();
    if (name.isEmpty) return const SizedBox.shrink();
    final key = getFieldJsonKey(name);
    final type = (f['fieldType'] ?? 'input').toString().toLowerCase();
    final display = f['displayInTable'] == true;
    final mandatory = f['mandatory'] == true;

    if (!display) return const SizedBox.shrink();

    if (name == 'Assigned') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assigned${mandatory ? " *" : ""}',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            _buildAgentSearchDropdown(context),
          ],
        ),
      );
    }

    if (name == 'Status') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdown(
              'Status${mandatory ? " *" : ""}',
              _hasAssignee ? _status : null,
              _statuses,
              _hasAssignee ? (v) => setState(() => _status = v) : null,
              hint: 'Select status (assign lead first)',
              enabled: _hasAssignee,
            ),
            if (!_hasAssignee)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Please assign a person before selecting status',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.red.shade700),
                ),
              ),
          ],
        ),
      );
    }

    if (name == 'Source') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildDropdown(
          'Source${mandatory ? " *" : ""}',
          _source,
          _sources,
          (v) => setState(() => _source = v),
          hint: 'Select source',
        ),
      );
    }

    if (name == 'Tags') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tags',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags
                  .map(
                    (t) => Chip(
                      label: Text(t, style: TextStyle(color: cs.onSurface)),
                      onDeleted: () => _removeTag(t),
                      backgroundColor: cs.surfaceContainerHighest,
                      side: BorderSide(color: cs.outline.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagCtrl,
                    decoration: _inputDecoration('Add tag'),
                    onSubmitted: _addTag,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addTag(_tagCtrl.text),
                  tooltip: 'Add tag',
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (name == 'Company') {
      final companyNames = _companies.map((e) => (e['name'] ?? '').toString()).where((name) => name.isNotEmpty).toSet().toList();
      final currentComp = _companySearchCtrl.text.trim();
      if (currentComp.isNotEmpty && !companyNames.contains(currentComp)) {
        companyNames.add(currentComp);
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildDropdown(
          'Company${mandatory ? " *" : ""}',
          currentComp.isEmpty ? null : currentComp,
          companyNames,
          (v) {
            setState(() {
              _companySearchCtrl.text = v ?? '';
              final match = _companies.firstWhere((e) => (e['name'] ?? '').toString() == v, orElse: () => null);
              if (match != null) {
                _companyId = (match['id'] ?? match['_id'])?.toString();
              } else {
                _companyId = null;
              }
            });
          },
          hint: 'Select company',
        ),
      );
    }

    if (name == 'Country Code') {
      if (_isFieldShown('Mobile')) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Country Code${mandatory ? " *" : ""}',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _countryCode,
              isExpanded: true,
              style: TextStyle(fontSize: 13, color: textColor),
              items: _countryCodes
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e['code'],
                      child: Text(
                        '+${e['code']} ${e['name']}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: textColor),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _countryCode = v),
              decoration: _inputDecoration('Country Code', hint: 'Select country...'),
              dropdownColor: Theme.of(context).brightness == Brightness.light ? Colors.white : cs.surface,
            ),
          ],
        ),
      );
    }

    if (name == 'Mobile') {
      final showCode = _isFieldShown('Country Code');
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showCode)
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      value: _countryCode,
                      isExpanded: true,
                      style: TextStyle(fontSize: 13, color: textColor),
                      items: _countryCodes
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e['code'],
                              child: Text(
                                '+${e['code']}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: textColor),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _countryCode = v),
                      decoration: _inputDecoration('Code'),
                      dropdownColor: Theme.of(context).brightness == Brightness.light ? Colors.white : cs.surface,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _mobileCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration(
                        'Mobile Number${mandatory ? " *" : ""}',
                        hint: 'Enter mobile number',
                        prefixIcon: const Icon(Icons.phone_outlined, size: 22),
                      ),
                    ),
                  ),
                ],
              )
            else
              TextFormField(
                controller: _mobileCtrl,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration(
                  'Mobile Number${mandatory ? " *" : ""}',
                  hint: 'Enter mobile number',
                  prefixIcon: const Icon(Icons.phone_outlined, size: 22),
                ),
              ),
          ],
        ),
      );
    }

    final builtinTextfields = {
      'Name': (_nameCtrl, 'Name', 'Enter name', Icons.person_outline, TextInputType.text),
      'Email': (_emailCtrl, 'Email Address', 'Enter email address', Icons.email_outlined, TextInputType.emailAddress),
      'Position': (_positionCtrl, 'Position', 'Enter position', Icons.work_outline, TextInputType.text),
      'Address': (_addressCtrl, 'Address', 'Enter address', Icons.location_on_outlined, TextInputType.text),
      'Website': (_websiteCtrl, 'Website', 'Enter website URL', Icons.language, TextInputType.url),
      'City': (_cityCtrl, 'City', 'Enter city', null, TextInputType.text),
      'Lead Value': (_valueCtrl, 'Lead Value', 'Enter lead value', null, TextInputType.number),
      'Country': (_countryCtrl, 'Country', 'Enter country', null, TextInputType.text),
      'Description': (_descCtrl, 'Description', 'Enter description', null, TextInputType.text),
    };

    if (builtinTextfields.containsKey(name)) {
      final info = builtinTextfields[name]!;
      final ctrl = info.$1;
      final label = info.$2;
      final hint = info.$3;
      final icon = info.$4;
      final keyboard = info.$5;

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          maxLines: (name == 'Address' || name == 'Description') ? 3 : 1,
          maxLength: (name == 'Description') ? 200 : null,
          decoration: _inputDecoration(
            '$label${mandatory ? " *" : ""}',
            hint: hint,
            prefixIcon: icon != null ? Icon(icon, size: 22) : null,
          ),
        ),
      );
    }

    if (type == 'select' || type == 'dropdown') {
      final opts = ((f['options'] as List?) ?? []).map((e) => e.toString()).toList();
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildDropdown(
          '$name${mandatory ? " *" : ""}',
          _customDropdownValues[key],
          opts,
          (v) => setState(() => _customDropdownValues[key] = v),
          hint: 'Select $name',
        ),
      );
    }

    if (type == 'textarea') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: _customControllers[key]!,
          maxLines: 3,
          decoration: _inputDecoration(
            '$name${mandatory ? " *" : ""}',
            hint: 'Enter $name',
          ),
        ),
      );
    }

    if (type == 'date') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GestureDetector(
          onTap: () async {
            final initialDate = DateTime.tryParse(_customControllers[key]?.text ?? '') ?? DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setState(() {
                _customControllers[key]?.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
              });
            }
          },
          child: AbsorbPointer(
            child: TextFormField(
              controller: _customControllers[key]!,
              decoration: _inputDecoration(
                '$name${mandatory ? " *" : ""}',
                hint: 'YYYY-MM-DD',
              ),
            ),
          ),
        ),
      );
    }

    TextInputType? customKeyboard;
    List<TextInputFormatter>? customFormatters;
    if (type == 'number') {
      customKeyboard = TextInputType.number;
      customFormatters = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _customControllers[key]!,
        keyboardType: customKeyboard,
        inputFormatters: customFormatters,
        decoration: _inputDecoration(
          '$name${mandatory ? " *" : ""}',
          hint: 'Enter $name',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textColor = isLight ? const Color(0xFF1C1B1F) : cs.onSurface;
    final scaffoldBg = isLight ? Colors.white : cs.surface;

    if (_loadingFields) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          elevation: 0,
          leading: const DrawerMenuIcon(),
          title: Text(
            (widget.lead != null && !widget.isFromScan)
                ? 'Edit Lead'
                : 'Add New Lead',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: cs.onSurface,
            ),
          ),
          centerTitle: true,
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          surfaceTintColor: Colors.transparent,
        ),
        drawer: const AppDrawer(),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        leading: const DrawerMenuIcon(),
        title: Text(
          (widget.lead != null && !widget.isFromScan)
              ? 'Edit Lead'
              : 'Add New Lead',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: cs.onSurface,
          ),
        ),
        centerTitle: true,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      drawer: const AppDrawer(),
      body: Container(
        color: scaffoldBg,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    textTheme: Theme.of(context).textTheme.copyWith(
                      bodyLarge: TextStyle(fontSize: _formFontSize, color: cs.onSurface),
                      bodyMedium: TextStyle(fontSize: _formFontSize, color: cs.onSurface),
                      titleMedium: TextStyle(fontSize: _formFontSize, color: cs.onSurface),
                    ),
                    inputDecorationTheme: InputDecorationTheme(
                      filled: true,
                      fillColor: isLight ? Colors.white : cs.surfaceContainerHighest,
                      labelStyle: TextStyle(fontSize: _labelFontSize, color: cs.onSurface),
                      hintStyle: TextStyle(fontSize: _formFontSize, color: cs.onSurface.withOpacity(0.6)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final f in _fields)
                          _buildDynamicFieldWidget(f, cs, textColor),
                        if (widget.lead == null)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Send new lead alert message to this lead',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              'This will send a welcome message to the new lead using your configured template',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            value: _sendWelcomeMessage,
                            onChanged: (v) =>
                                setState(() => _sendWelcomeMessage = v ?? false),
                            activeColor: Theme.of(context).colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Builder(
              builder: (ctx) {
                final cs = Theme.of(ctx).colorScheme;
                final isLight = Theme.of(ctx).brightness == Brightness.light;
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  decoration: BoxDecoration(
                    color: isLight ? Colors.white : cs.surface,
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            if (widget.onCancel != null) {
                              widget.onCancel!();
                            } else {
                              Navigator.pop(context);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: cs.outline.withOpacity(0.5)),
                            foregroundColor: cs.onSurfaceVariant,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    color: cs.onPrimary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  (widget.lead != null && !widget.isFromScan)
                                      ? 'Update Lead'
                                      : 'Add Lead',
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentSearchDropdown(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textColor = isLight ? const Color(0xFF1C1B1F) : cs.onSurface;
    final hasSelection = _assignedId != null && _agentSearchCtrl.text.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _showAgentSelectionDialog(context),
            child: IgnorePointer(
              child: TextFormField(
                key: const ValueKey('assigned_agent_field'),
                controller: _agentSearchCtrl,
                style: TextStyle(fontSize: _formFontSize, color: textColor),
                decoration: _inputDecoration(
                  'Assigned',
                  hint: 'Select assigned person',
                ).copyWith(
                  suffixIcon: Icon(Icons.arrow_drop_down, color: textColor),
                ),
                validator: (v) {
                  if (!widget.isFromScan && (_assignedId == null || _agentSearchCtrl.text.trim().isEmpty)) {
                    return 'Assigned is required';
                  }
                  return null;
                },
              ),
            ),
          ),
        ),
        if (hasSelection)
          IconButton(
            icon: Icon(Icons.close, size: 22, color: cs.onSurface),
            onPressed: () {
              setState(() {
                _assignedId = null;
                _agentSearchCtrl.clear();
                _status = null;
              });
            },
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(40, 40),
            ),
            tooltip: 'Clear assigned agent',
          ),
      ],
    );
  }

  void _showAgentSelectionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final q = _searchQuery.trim().toLowerCase();
            final filteredAgents = q.isEmpty
                ? List<dynamic>.from(_agents)
                : _agents.where((a) {
                    final name = (a['name'] ?? a['username'] ?? '').toString().toLowerCase();
                    final email = (a['email'] ?? '').toString().toLowerCase();
                    return name.contains(q) || email.contains(q);
                  }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        autofocus: true,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Search Agent...',
                          hintStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: filteredAgents.isEmpty
                          ? Center(
                              child: Text(
                                'No agents found',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: filteredAgents.length,
                              itemBuilder: (context, index) {
                                final agent = filteredAgents[index];
                                final email = (agent['email'] ?? '').toString();
                                final name = (agent['name'] ?? agent['username'] ?? '').toString();
                                final displayText = email.isNotEmpty ? email : (name.isNotEmpty ? name : 'Unknown');
                                final idRaw = agent['_id'] ?? agent['id'];
                                final idStr = idRaw?.toString() ?? '';
                                final isSelected = _assignedId != null && _assignedId == idStr;

                                return ListTile(
                                  title: Text(
                                    displayText,
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                  ),
                                  trailing: isSelected
                                      ? Icon(
                                          Icons.check_circle,
                                          color: Theme.of(context).colorScheme.primary,
                                        )
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _assignedId = idStr.isNotEmpty ? idStr : null;
                                      _agentSearchCtrl.text = displayText;
                                    });
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    ).then((_) {
      // Clear search query when dialog closes
      _searchQuery = "";
    });
  }

  String _searchQuery = "";

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?>? onChanged, {
    String? hint,
    bool enabled = true,
  }) {
    final uniqueItems = items.toSet().toList();
    if (value != null && value.isNotEmpty && !uniqueItems.contains(value)) {
      uniqueItems.add(value);
    }

    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textColor = isLight ? const Color(0xFF1C1B1F) : cs.onSurface;
    return DropdownButtonFormField<String>(
      key: ValueKey('${label}_$value'),
      value: value != null && uniqueItems.contains(value) ? value : null,
      style: TextStyle(fontSize: _formFontSize, color: textColor),
      items: uniqueItems
          .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e, style: TextStyle(color: textColor)),
              ))
          .toList(),
      onChanged: enabled ? onChanged : null,
      decoration: _inputDecoration(label, hint: hint),
      dropdownColor: isLight ? Colors.white : cs.surface,
      validator: (v) {
        if (!enabled) return null;
        return (v == null || v.isEmpty) ? 'Required' : null;
      },
    );
  }

  static const double _formFontSize = 13;
  static const double _labelFontSize = 12;

  InputDecoration _inputDecoration(String label, {Widget? prefixIcon, String? hint}) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final fillColor = isLight ? Colors.white : cs.surfaceContainerHighest;
    final borderColor = isLight ? Colors.grey.shade300 : cs.outline.withOpacity(0.5);
    final textColor = isLight ? const Color(0xFF1C1B1F) : cs.onSurface;
    final hintColor = isLight ? Colors.black54 : cs.onSurface.withOpacity(0.7);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      labelStyle: TextStyle(fontSize: _labelFontSize, color: textColor),
      hintStyle: TextStyle(fontSize: _formFontSize, color: hintColor),
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final sectionBg = isLight ? Colors.white : cs.surfaceContainerHighest;
    final sectionBorder = isLight ? Colors.grey.shade200 : cs.outline.withOpacity(0.3);
    final titleColor = isLight ? Colors.black54 : cs.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sectionBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
