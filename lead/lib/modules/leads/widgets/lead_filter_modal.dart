import 'package:flutter/material.dart';
import '../../../services/leads_service.dart';

/// Sentinel value for "All" in dropdowns; when applied, we pass null so all values show.
const String _kAllValue = '__all__';

class LeadFilterModal extends StatefulWidget {
  final DateTimeRange? initialDateRange;
  final String? initialStatus;
  final String? initialSource;
  final String? initialCompany;
  final String? initialAssignedTo;
  final Function({
    DateTimeRange? dateRange,
    String? status,
    String? source,
    String? company,
    String? assignedTo,
  })
  onApply;

  const LeadFilterModal({
    super.key,
    this.initialDateRange,
    this.initialStatus,
    this.initialSource,
    this.initialCompany,
    this.initialAssignedTo,
    required this.onApply,
  });

  @override
  State<LeadFilterModal> createState() => _LeadFilterModalState();
}

class _LeadFilterModalState extends State<LeadFilterModal> {
  DateTimeRange? _dateRange;
  String? _status;
  String? _source;
  String? _company;
  String? _assignedTo;

  List<String> _statuses = [];
  List<String> _sources = [];
  List<dynamic> _companies = [];
  List<dynamic> _agents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _dateRange = widget.initialDateRange;
    _status = widget.initialStatus ?? _kAllValue;
    _source = widget.initialSource ?? _kAllValue;
    _company = widget.initialCompany ?? _kAllValue;
    _assignedTo = widget.initialAssignedTo ?? _kAllValue;
    _loadOptions();
  }

  bool get _hasActiveFilters =>
      _dateRange != null ||
      (_status != null && _status != _kAllValue) ||
      (_source != null && _source != _kAllValue) ||
      (_company != null && _company != _kAllValue) ||
      (_assignedTo != null && _assignedTo != _kAllValue);

  List<MapEntry<String, String>> get _activeFilterTags {
    final list = <MapEntry<String, String>>[];
    if (_dateRange != null) {
      final s = _dateRange!.start.toString().split(' ')[0];
      final e = _dateRange!.end.toString().split(' ')[0];
      list.add(MapEntry('dateRange', 'Date: $s → $e'));
    }
    if (_status != null && _status != _kAllValue) list.add(MapEntry('status', 'Status: $_status'));
    if (_source != null && _source != _kAllValue) list.add(MapEntry('source', 'Source: $_source'));
    if (_company != null && _company != _kAllValue) {
      final matches = _companies.cast<Map<String, dynamic>>().where((c) => (c['_id'] ?? c['id']?.toString()) == _company).toList();
      final name = matches.isEmpty ? _company! : (matches.first['name'] ?? 'Unknown');
      list.add(MapEntry('company', 'Company: $name'));
    }
    if (_assignedTo != null && _assignedTo != _kAllValue) {
      final matches = _agents.cast<Map<String, dynamic>>().where((a) => (a['_id'] ?? a['id']?.toString()) == _assignedTo).toList();
      final name = matches.isEmpty ? _assignedTo! : (matches.first['name'] ?? matches.first['username'] ?? 'Unknown');
      list.add(MapEntry('assignedTo', 'Assigned: $name'));
    }
    return list;
  }

  void _removeFilter(String key) {
    setState(() {
      switch (key) {
        case 'dateRange': _dateRange = null; break;
        case 'status': _status = _kAllValue; break;
        case 'source': _source = _kAllValue; break;
        case 'company': _company = _kAllValue; break;
        case 'assignedTo': _assignedTo = _kAllValue; break;
      }
    });
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait([
        LeadsService.getStatuses(),
        LeadsService.getSources(),
        LeadsService.getCompanies(),
        LeadsService.getAgents(),
      ]);

      if (mounted) {
        setState(() {
          _statuses = results[0] as List<String>;
          _sources = results[1] as List<String>;
          _companies = results[2];
          _agents = results[3];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: screenWidth,
      constraints: BoxConstraints(maxWidth: screenWidth),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  'Global Filter',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface),
                ),
                if (_hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_activeFilterTags.length}',
                      style: TextStyle(color: cs.onError, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: screenWidth - 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    _buildLabel('Date Range'),
                    const SizedBox(height: 8),
                    _buildDatePicker(),
                    const SizedBox(height: 20),

                    _buildLabel('Assigned To'),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: _assignedTo,
                      hint: 'Select assigned person',
                      items: [
                        {'id': _kAllValue, 'name': 'All'},
                        ..._agents.map(
                          (a) => {
                            'id': (a['_id'] ?? a['id']).toString(),
                            'name': a['name'] ?? a['username'] ?? 'Unknown',
                          },
                        ),
                      ],
                      onChanged: (val) => setState(() => _assignedTo = val ?? _kAllValue),
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Company'),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: _company,
                      hint: 'Select company',
                      items: [
                        {'id': _kAllValue, 'name': 'All'},
                        ..._companies.map(
                          (c) => {
                            'id': (c['_id'] ?? c['id']).toString(),
                            'name': c['name'] ?? 'Unknown',
                          },
                        ),
                      ],
                      onChanged: (val) => setState(() => _company = val ?? _kAllValue),
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Lead Status'),
                    const SizedBox(height: 8),
                    _buildSimpleDropdown(
                      value: _status,
                      hint: 'Select status',
                      items: _statuses,
                      onChanged: (val) => setState(() => _status = val ?? _kAllValue),
                      allOption: true,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Source'),
                    const SizedBox(height: 8),
                    _buildSimpleDropdown(
                      value: _source,
                      hint: 'Select source',
                      items: _sources,
                      onChanged: (val) => setState(() => _source = val ?? _kAllValue),
                      allOption: true,
                    ),
                    const SizedBox(height: 24),

                    // Active filters (above buttons)
                    if (_hasActiveFilters) ...[
                      Text(
                        '${_activeFilterTags.length} filter(s) active',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _activeFilterTags.map((e) {
                          return Chip(
                            label: Text(e.value, style: const TextStyle(fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => _removeFilter(e.key),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    ],
                  ),
                ),
              ),
            ),

          // Footer Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: cs.outline.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _dateRange = null;
                        _status = _kAllValue;
                        _source = _kAllValue;
                        _company = _kAllValue;
                        _assignedTo = _kAllValue;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: cs.error,
                      foregroundColor: cs.onError,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Clear All'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final dateRange = _dateRange;
                      final status = _status == _kAllValue ? null : _status;
                      final source = _source == _kAllValue ? null : _source;
                      final company = _company == _kAllValue ? null : _company;
                      final assignedTo = _assignedTo == _kAllValue ? null : _assignedTo;
                      Navigator.pop(context);
                      widget.onApply(
                        dateRange: dateRange,
                        status: status,
                        source: source,
                        company: company,
                        assignedTo: assignedTo,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          initialDateRange: _dateRange,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.primary,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => _dateRange = picked);
        }
      },
      child: Builder(
        builder: (ctx) {
          final cs2 = Theme.of(ctx).colorScheme;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: cs2.outline.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(
                  _dateRange == null
                      ? 'Start date   →   End date'
                      : '${_dateRange!.start.toString().split(' ')[0]}   →   ${_dateRange!.end.toString().split(' ')[0]}',
                  style: TextStyle(
                    color: _dateRange == null ? cs2.onSurfaceVariant : cs2.onSurface,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.calendar_month_outlined,
                  size: 20,
                  color: cs2.onSurfaceVariant,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<Map<String, dynamic>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    final validValue = value != null && items.any((i) => (i['id'] ?? i['_id'])?.toString() == value) ? value : (items.isNotEmpty ? (items.first['id'] ?? items.first['_id'])?.toString() : null);
    return DropdownButtonFormField<String>(
      value: validValue,
      isExpanded: true,
      hint: Text(
        hint,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        overflow: TextOverflow.ellipsis,
      ),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
        ),
      ),
      items: items.map((i) {
        return DropdownMenuItem<String>(
          value: i['id'] as String,
          child: Text(
            (i['name'] as String? ?? 'Unknown'),
            style: TextStyle(fontSize: 14, color: cs.onSurface),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      icon: Icon(Icons.expand_more, color: cs.onSurfaceVariant),
    );
  }

  Widget _buildSimpleDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool allOption = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final effectiveValue = value ?? _kAllValue;
    final validValue = effectiveValue == _kAllValue || items.contains(effectiveValue) ? effectiveValue : (allOption ? _kAllValue : (items.isNotEmpty ? items.first : null));
    final dropdownItems = [
      if (allOption) DropdownMenuItem<String>(value: _kAllValue, child: Text('All', style: TextStyle(fontSize: 14, color: cs.onSurface))),
      ...items.map((i) => DropdownMenuItem<String>(
        value: i,
        child: Text(i, style: TextStyle(fontSize: 14, color: cs.onSurface), overflow: TextOverflow.ellipsis, maxLines: 1),
      )),
    ];
    return DropdownButtonFormField<String>(
      value: validValue,
      isExpanded: true,
      hint: Text(
        hint,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        overflow: TextOverflow.ellipsis,
      ),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outline.withOpacity(0.5))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outline.withOpacity(0.5))),
      ),
      items: dropdownItems,
      onChanged: onChanged,
      icon: Icon(Icons.expand_more, color: cs.onSurfaceVariant),
    );
  }
}
