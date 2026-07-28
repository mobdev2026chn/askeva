import 'package:flutter/material.dart';
import '../api/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/common.dart';
import '../shell/app_nav.dart';
import '../widgets/dashboard_sheets.dart' show appToast;

// ─── Field category / type model ─────────────────────────────────────────────

class _FieldType {
  final String label;
  final String inputType;
  final String description;
  const _FieldType(this.label, this.inputType, this.description);
}

class _FieldCategory {
  final String name;
  final IconData icon;
  final List<_FieldType> types;
  const _FieldCategory(this.name, this.icon, this.types);
}

const List<_FieldCategory> _kCategories = [
  _FieldCategory('Text Answer', Icons.text_fields_rounded, [
    _FieldType('Short Answer', 'textinput', 'Single-line text input'),
    _FieldType('Paragraph', 'textarea', 'Multi-line text area'),
    _FieldType('Email', 'email', 'Email address input'),
  ]),
  _FieldCategory('Selections', Icons.checklist_rounded, [
    _FieldType('Single Choice', 'radio', 'Pick one from options'),
    _FieldType('Multiple Choice', 'checkbox', 'Pick many from options'),
    _FieldType('Dropdown', 'select', 'Dropdown selection'),
  ]),
  _FieldCategory('Special', Icons.auto_awesome_rounded, [
    _FieldType('Number', 'number', 'Numeric input'),
    _FieldType('Date', 'date', 'Date selection'),
    _FieldType('Document Upload', 'document', 'File & document upload'),
  ]),
];

const List<String> _kStaticTicketingKeys = [
  'department_field',
  'description',
  'document',
  'subject',
];

const List<String> _kStaticCustomerKeys = [
  'customer_description',
  'customer_documents',
];

class TicketFormScreen extends StatefulWidget {
  const TicketFormScreen({super.key});

  @override
  State<TicketFormScreen> createState() => _TicketFormScreenState();
}

class _TicketFormScreenState extends State<TicketFormScreen> {
  int _activeTab = 0; // 0 = Ticketing Flow, 1 = Customer Response Flow
  bool _loading = false;
  bool _publishing = false;
  List<Map<String, dynamic>> _fields = [];

  // Default fallback static fields – Ticketing Flow
  static const List<Map<String, dynamic>> _ticketingStatic = [
    {
      'fieldKey': 'subject',
      'fieldName': 'Subject',
      'fieldType': 'textinput',
      'mandatory': true,
      'displayInForm': true,
      'options': [],
      'isStatic': true,
    },
    {
      'fieldKey': 'description',
      'fieldName': 'Description',
      'fieldType': 'textarea',
      'mandatory': true,
      'displayInForm': true,
      'options': [],
      'isStatic': true,
    },
    {
      'fieldKey': 'document',
      'fieldName': 'Document',
      'fieldType': 'document',
      'mandatory': false,
      'placeholder': 'Document Upload',
      'displayInForm': true,
      'isStatic': true,
      'allowedFileTypes': ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      'maxFileSize': 100,
      'multipleFiles': true,
    },
    {
      'fieldKey': 'department_field',
      'fieldName': 'Department',
      'fieldType': 'select',
      'mandatory': true,
      'placeholder': 'Select department',
      'displayInForm': true,
      'options': [],
      'isStatic': true,
    },
  ];

  // Default fallback static fields – Customer Response Flow
  static const List<Map<String, dynamic>> _customerStatic = [
    {
      'fieldKey': 'customer_description',
      'fieldName': 'Description',
      'fieldType': 'textarea',
      'mandatory': true,
      'placeholder': 'Enter description',
      'displayInForm': true,
      'isStatic': true,
    },
    {
      'fieldKey': 'customer_documents',
      'fieldName': 'Documents',
      'fieldType': 'document',
      'mandatory': false,
      'placeholder': 'Upload supporting documents',
      'displayInForm': true,
      'isStatic': true,
      'allowedFileTypes': ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'xls', 'xlsx'],
      'maxFileSize': 10,
      'multipleFiles': true,
    }
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _snack(String msg) => appToast(context, msg);

  bool _isStatic(Map<String, dynamic> f) {
    final key = f['fieldKey']?.toString() ?? '';
    if (_activeTab == 0) {
      return _kStaticTicketingKeys.contains(key) || f['isStatic'] == true;
    } else {
      return _kStaticCustomerKeys.contains(key) || f['isStatic'] == true;
    }
  }

  bool get _hasDocumentField =>
      _fields.any((f) => f['fieldType']?.toString() == 'document');

  Future<void> _loadConfig() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final repo = AppScope.of(context).ticketing;
      if (_activeTab == 0) {
        final res = await repo.fetchTicketSettings();
        final raw = res['ticketingFields'];
        _fields = raw is List
            ? raw.map((f) => Map<String, dynamic>.from(f as Map)).toList()
            : List<Map<String, dynamic>>.from(_ticketingStatic);
      } else {
        final res = await repo.fetchCustomerResponseConfiguration();
        final raw = res['customerResponseFields'];
        _fields = raw is List
            ? raw.map((f) => Map<String, dynamic>.from(f as Map)).toList()
            : List<Map<String, dynamic>>.from(_customerStatic);
      }
    } catch (_) {
      _fields = _activeTab == 0
          ? List<Map<String, dynamic>>.from(_ticketingStatic)
          : List<Map<String, dynamic>>.from(_customerStatic);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    setState(() {
      final item = _fields.removeAt(oldIndex);
      _fields.insert(newIndex, item);
    });
    try {
      final repo = AppScope.of(context).ticketing;
      if (_activeTab == 0) {
        await repo.updateFieldOrder(_fields);
      } else {
        await repo.updateCustomerResponseFieldOrder(_fields);
      }
    } catch (_) {
      _snack('Failed to update field order');
      _loadConfig();
    }
  }

  Future<void> _publishFlow() async {
    setState(() => _publishing = true);
    try {
      final repo = AppScope.of(context).ticketing;
      if (_activeTab == 0) {
        await repo.updateAndPublishFlow(_fields);
      } else {
        await repo.updateAndPublishCustomerResponseFlow(_fields);
      }
      _snack('Flow published successfully');
    } catch (_) {
      _snack('Failed to publish flow');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _deleteField(String key) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Field',
            style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
        content: Text('Are you sure you want to delete this custom field? This action cannot be undone.',
            style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink3)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    final repo = AppScope.of(context).ticketing;
    try {
      if (_activeTab == 0) {
        await repo.deleteField(key);
      } else {
        await repo.deleteCustomerResponseField(key);
      }
      _snack('Field deleted successfully');
      _loadConfig();
    } catch (e) {
      _snack('Failed to delete: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ADD FIELD — 2-Step bottom sheet
  // ──────────────────────────────────────────────────────────────────────────

  void _showAddFieldSheet() {
    _FieldType? selType;
    _FieldCategory? selCategory;
    int step = 0; // 0 = pick category/type, 1 = configure

    // Config state
    final nameCtrl = TextEditingController();
    final placeholderCtrl = TextEditingController();
    bool mandatory = false;
    bool displayInForm = true;
    List<String> options = ['', ''];
    List<String> allowedFileTypes = ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'];
    bool multipleFiles = false;
    final minCtrl = TextEditingController();
    final maxCtrl = TextEditingController();
    final maxLengthCtrl = TextEditingController();
    final rowsCtrl = TextEditingController(text: '3');
    final maxFileSizeCtrl = TextEditingController(text: '10');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        final needsOptions = ['radio', 'checkbox', 'select'].contains(selType?.inputType);
        final isDocument = selType?.inputType == 'document';
        final isNumber = selType?.inputType == 'number';
        final isText = ['text', 'textarea', 'email'].contains(selType?.inputType);
        final isMultiLine = selType?.inputType == 'textarea';

        // ── Step 1: Category / type picker ──
        if (step == 0) {
          return _sheet(
            ctx,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetHandle(),
                const SizedBox(height: 14),
                // Stepper indicator
                _stepBar(currentStep: 0),
                const SizedBox(height: 16),
                Text('Select Type',
                    style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 4),
                Text('Select a field category and type to add to your ticket form',
                    style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.ink3)),
                const SizedBox(height: 20),

                // Categories
                ..._kCategories.map((cat) {
                  final selected = selCategory == cat;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => setSt(() {
                          selCategory = selected ? null : cat;
                          selType = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.evaGreen50 : AppColors.surface2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: selected ? AppColors.evaGreen : AppColors.line),
                          ),
                          child: Row(
                            children: [
                              Icon(cat.icon,
                                  size: 18,
                                  color: selected ? AppColors.evaGreenDeep : AppColors.ink3),
                              const SizedBox(width: 10),
                              Text(cat.name,
                                  style: AppText.poppins(
                                      size: 13.5,
                                      weight: FontWeight.w700,
                                      color: selected ? AppColors.evaGreenDeep : AppColors.ink)),
                              const Spacer(),
                              Icon(
                                selected
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: AppColors.ink3,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(height: 8),
                        ...cat.types.map((t) {
                          final isDocType = t.inputType == 'document';
                          final docBlocked = isDocType && _hasDocumentField;
                          return GestureDetector(
                            onTap: docBlocked
                                ? () => _snack('Only one document field can be added')
                                : () => setSt(() => selType = selType == t ? null : t),
                            child: Container(
                              margin: const EdgeInsets.only(left: 16, bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: selType == t
                                    ? AppColors.evaGreen50
                                    : (docBlocked
                                        ? AppColors.surface2
                                        : AppColors.surface),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: selType == t
                                        ? AppColors.evaGreen
                                        : AppColors.line),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                      selType == t
                                          ? Icons.radio_button_checked_rounded
                                          : Icons.radio_button_off_rounded,
                                      size: 18,
                                      color: docBlocked
                                          ? AppColors.ink4
                                          : (selType == t
                                              ? AppColors.evaGreenDeep
                                              : AppColors.ink3)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(t.label,
                                            style: AppText.poppins(
                                                size: 13,
                                                weight: FontWeight.w700,
                                                color: docBlocked
                                                    ? AppColors.ink4
                                                    : (selType == t
                                                        ? AppColors.evaGreenDeep
                                                        : AppColors.ink))),
                                        Text(t.description,
                                            style: AppText.poppins(
                                                size: 11,
                                                weight: FontWeight.w500,
                                                color: AppColors.ink3)),
                                      ],
                                    ),
                                  ),
                                  if (docBlocked)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(8)),
                                      child: Text('Limit 1',
                                          style: AppText.poppins(
                                              size: 9.5,
                                              weight: FontWeight.w700,
                                              color: const Color(0xFFD97706))),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 6),
                      ],
                    ],
                  );
                }),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: AppColors.line),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Cancel',
                            style: AppText.poppins(
                                size: 13, weight: FontWeight.w700, color: AppColors.ink3)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selType == null
                            ? null
                            : () => setSt(() {
                                  step = 1;
                                  // Pre-fill defaults for document
                                  if (selType!.inputType == 'document') {
                                    allowedFileTypes = [
                                      'pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'
                                    ];
                                    maxFileSizeCtrl.text = '10';
                                    multipleFiles = false;
                                  }
                                }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.evaGreen,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.line,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: Text('Next: Configure Field',
                            style: AppText.poppins(
                                size: 13, weight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // ── Step 2: Configure field ──
        return _sheet(
          ctx,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              const SizedBox(height: 14),
              _stepBar(currentStep: 1),
              const SizedBox(height: 16),

              // Header row with back
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setSt(() => step = 0),
                    child: const Icon(Icons.arrow_back_ios_rounded,
                        size: 16, color: AppColors.ink2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Configure Field',
                            style: AppText.poppins(
                                size: 16, weight: FontWeight.w800, color: AppColors.ink)),
                        Text(selType!.label,
                            style: AppText.poppins(
                                size: 11.5, weight: FontWeight.w600, color: AppColors.evaGreenDeep)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Field Label
              _fieldLabel('Field Label', required: true),
              const SizedBox(height: 6),
              _inputBox(
                child: TextField(
                  controller: nameCtrl,
                  style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                  decoration: _inputDeco('e.g. Order ID'),
                ),
              ),
              const SizedBox(height: 12),

              // Placeholder
              _fieldLabel('Placeholder Text'),
              const SizedBox(height: 6),
              _inputBox(
                child: TextField(
                  controller: placeholderCtrl,
                  style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                  decoration: _inputDeco('Enter placeholder text'),
                ),
              ),
              const SizedBox(height: 12),

              // Dropdown/Radio/Checkbox options
              if (needsOptions) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _fieldLabel('Options'),
                    TextButton.icon(
                      onPressed: () => setSt(() => options.add('')),
                      icon: const Icon(Icons.add_rounded, size: 14, color: AppColors.evaGreenDeep),
                      label: Text('Add',
                          style: AppText.poppins(
                              size: 12, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                      style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (c, i) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      height: 38,
                      child: Row(children: [
                        Expanded(
                          child: _inputBox(
                            child: TextField(
                              controller: TextEditingController(text: options[i])
                                ..selection =
                                    TextSelection.collapsed(offset: options[i].length),
                              onChanged: (v) => options[i] = v,
                              style: AppText.poppins(
                                  size: 12.5, weight: FontWeight.w600, color: AppColors.ink),
                              decoration: _inputDeco('Option ${i + 1}'),
                            ),
                          ),
                        ),
                        if (options.length > 1)
                          IconButton(
                            onPressed: () => setSt(() => options.removeAt(i)),
                            icon: const Icon(Icons.close_rounded,
                                size: 16, color: AppColors.danger),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Number min/max
              if (isNumber) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Min'),
                          const SizedBox(height: 6),
                          _inputBox(
                            child: TextField(
                              controller: minCtrl,
                              keyboardType: TextInputType.number,
                              style: AppText.poppins(
                                  size: 13, weight: FontWeight.w600, color: AppColors.ink),
                              decoration: _inputDeco('0'),
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
                          _fieldLabel('Max'),
                          const SizedBox(height: 6),
                          _inputBox(
                            child: TextField(
                              controller: maxCtrl,
                              keyboardType: TextInputType.number,
                              style: AppText.poppins(
                                  size: 13, weight: FontWeight.w600, color: AppColors.ink),
                              decoration: _inputDeco('100'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Max length for text types
              if (isText) ...[
                _fieldLabel('Maximum Length'),
                const SizedBox(height: 6),
                _inputBox(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: maxLengthCtrl,
                    style: AppText.poppins(
                        size: 13, weight: FontWeight.w600, color: AppColors.ink),
                    decoration: _inputDeco('Maximum character length'),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Number of rows for Paragraph (textarea)
              if (isMultiLine) ...[
                _fieldLabel('Number of Rows'),
                const SizedBox(height: 6),
                _inputBox(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: rowsCtrl,
                    style: AppText.poppins(
                        size: 13, weight: FontWeight.w600, color: AppColors.ink),
                    decoration: _inputDeco('Number of rows (default 3)'),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Document config
              if (isDocument) ...[
                _fieldLabel('Allowed File Types'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'xls', 'xlsx']
                      .map((ext) {
                    final sel = allowedFileTypes.contains(ext);
                    return GestureDetector(
                      onTap: () => setSt(() {
                        if (sel) {
                          allowedFileTypes.remove(ext);
                        } else {
                          allowedFileTypes.add(ext);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.evaGreen50 : AppColors.surface2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: sel ? AppColors.evaGreen : AppColors.line),
                        ),
                        child: Text(ext,
                            style: AppText.poppins(
                                size: 11.5,
                                weight: FontWeight.w700,
                                color: sel ? AppColors.evaGreenDeep : AppColors.ink3)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Max File Size (MB)'),
                          const SizedBox(height: 6),
                          _inputBox(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              controller: maxFileSizeCtrl,
                              style: AppText.poppins(
                                  size: 13, weight: FontWeight.w600, color: AppColors.ink),
                              decoration: _inputDeco('10'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _toggleRow(
                        label: 'Multiple Files',
                        value: multipleFiles,
                        onChanged: (v) => setSt(() => multipleFiles = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Mandatory toggle
              _checkRow(
                label: 'Mandatory Field',
                subtitle: 'Require this field before submitting',
                value: mandatory,
                onTap: () => setSt(() => mandatory = !mandatory),
              ),
              const SizedBox(height: 10),

              // Show in Form toggle
              _checkRow(
                label: 'Show in Ticket Form',
                subtitle: 'When unchecked, field is hidden from the form but stored in the database',
                value: displayInForm,
                onTap: () => setSt(() => displayInForm = !displayInForm),
              ),
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            _snack('Field label is required');
                            return;
                          }
                          // Check reserved names
                          final reservedNames = _activeTab == 0
                              ? ['Subject', 'Description', 'Document', 'Department']
                              : ['Description', 'Documents'];
                          if (reservedNames
                              .map((n) => n.toLowerCase())
                              .contains(name.toLowerCase())) {
                            _snack('This field name is reserved for static fields');
                            return;
                          }
                          setSt(() => saving = true);
                          final payload = {
                            'fieldName': name,
                            'fieldType': selType!.inputType,
                            'mandatory': mandatory,
                            'displayInForm': displayInForm,
                            'isStatic': false,
                            'placeholder': placeholderCtrl.text.trim().isEmpty
                                ? 'Enter $name'
                                : placeholderCtrl.text.trim(),
                            'options': options.where((o) => o.trim().isNotEmpty).toList(),
                            if (isNumber) 'min': int.tryParse(minCtrl.text),
                            if (isNumber) 'max': int.tryParse(maxCtrl.text),
                            if (isText) 'maxLength': int.tryParse(maxLengthCtrl.text),
                            if (isMultiLine) 'rows': int.tryParse(rowsCtrl.text) ?? 3,
                            if (isDocument) 'allowedFileTypes': allowedFileTypes,
                            if (isDocument) 'maxFileSize': int.tryParse(maxFileSizeCtrl.text) ?? 10,
                            if (isDocument) 'multipleFiles': multipleFiles,
                          };
                          try {
                            if (_activeTab == 0) {
                              await AppScope.of(context).ticketing.addCustomField(payload);
                            } else {
                              await AppScope.of(context).ticketing.addCustomerResponseField(payload);
                            }
                            _snack('Field added successfully');
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            _loadConfig();
                          } catch (e) {
                            _snack('Failed to add field: $e');
                            setSt(() => saving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.evaGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Save Field',
                          style: AppText.poppins(
                              size: 14, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // EDIT FIELD sheet
  // ──────────────────────────────────────────────────────────────────────────

  void _showEditSheet(Map<String, dynamic> field) {
    final isStatic = _isStatic(field);
    final nameCtrl =
        TextEditingController(text: field['fieldName']?.toString() ?? '');
    final placeholderCtrl =
        TextEditingController(text: field['placeholder']?.toString() ?? '');
    bool mandatory = field['mandatory'] == true;
    bool displayInForm =
        field['displayInForm'] != false; // default true if missing
    String rawType = field['fieldType']?.toString() ?? 'textinput';
    String selType = rawType == 'text' ? 'textinput' : rawType;
    List<String> options = [];
    if (field['options'] is List) {
      options = (field['options'] as List).map((o) => o.toString()).toList();
    }
    if (options.isEmpty) options = [''];
    List<String> allowedFileTypes = [];
    if (field['allowedFileTypes'] is List) {
      allowedFileTypes =
          (field['allowedFileTypes'] as List).map((o) => o.toString()).toList();
    }
    bool multipleFiles = field['multipleFiles'] == true;
    final minCtrl = TextEditingController(text: field['min']?.toString() ?? '');
    final maxCtrl = TextEditingController(text: field['max']?.toString() ?? '');
    final maxLengthCtrl = TextEditingController(text: field['maxLength']?.toString() ?? '');
    final rowsCtrl = TextEditingController(text: field['rows']?.toString() ?? '3');
    final maxFileSizeCtrl = TextEditingController(text: field['maxFileSize']?.toString() ?? '10');
    bool saving = false;

    final key = field['fieldKey']?.toString() ?? '';

    final List<(String, String)> typeOptions = [
      ('Short Answer', 'textinput'),
      ('Paragraph', 'textarea'),
      ('Email', 'email'),
      ('Single Choice', 'radio'),
      ('Multiple Choice', 'checkbox'),
      ('Dropdown', 'select'),
      ('Number', 'number'),
      ('Date', 'date'),
      ('Document Upload', 'document'),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        final needsOptions = ['radio', 'checkbox', 'select'].contains(selType);
        final isDocument = selType == 'document';
        final isNumber = selType == 'number';
        final isText = ['text', 'textinput', 'textarea', 'email'].contains(selType);
        final isMultiLine = selType == 'textarea';

        return _sheet(
          ctx,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              const SizedBox(height: 14),

              // Title row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Field Configuration',
                            style: AppText.poppins(
                                size: 16, weight: FontWeight.w800, color: AppColors.ink)),
                        if (isStatic)
                          Text('Static field — label and visibility editable',
                              style: AppText.poppins(
                                  size: 11, weight: FontWeight.w500, color: AppColors.ink3)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Field Label
              _fieldLabel('Field Label', required: true),
              const SizedBox(height: 6),
              _inputBox(
                child: TextField(
                  controller: nameCtrl,
                  style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                  decoration: _inputDeco('Field label'),
                ),
              ),
              const SizedBox(height: 4),
              if (isStatic)
                Text('This is a static field; you can edit the label but not the field type.',
                    style: AppText.poppins(size: 10.5, weight: FontWeight.w500, color: AppColors.ink3)),
              const SizedBox(height: 12),

              // Field Type
              _fieldLabel('Field Type'),
              const SizedBox(height: 6),
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isStatic ? AppColors.surface2 : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.line),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selType,
                    isExpanded: true,
                    onChanged: isStatic
                        ? null
                        : (v) {
                            if (v != null) {
                              setSt(() => selType = v);
                            }
                          },
                    style: AppText.poppins(
                        size: 13, weight: FontWeight.w600, color: AppColors.ink),
                    items: typeOptions.map((t) {
                      final isDoc = t.$2 == 'document';
                      final documentFieldExists = _hasDocumentField;
                      final isCurrentFieldDocument = field['fieldType']?.toString() == 'document';
                      final disableDocumentOption = documentFieldExists && !isCurrentFieldDocument;
                      final disabled = isDoc && disableDocumentOption;
                      return DropdownMenuItem<String>(
                        value: t.$2,
                        enabled: !disabled,
                        child: Text(
                          t.$1 + (disabled ? ' (Already exists)' : ''),
                          style: AppText.poppins(
                              size: 13,
                              weight: FontWeight.w600,
                              color: disabled ? AppColors.ink4 : AppColors.ink),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (isStatic) ...[
                const SizedBox(height: 4),
                Text('Field type cannot be changed for static fields.',
                    style: AppText.poppins(size: 10.5, weight: FontWeight.w500, color: AppColors.ink4)),
              ],
              const SizedBox(height: 12),

              // Placeholder
              _fieldLabel('Placeholder Text'),
              const SizedBox(height: 6),
              _inputBox(
                child: TextField(
                  controller: placeholderCtrl,
                  style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                  decoration: _inputDeco('Enter placeholder'),
                ),
              ),
              const SizedBox(height: 12),

              // Options (non-static select/radio/checkbox)
              if (needsOptions && !isStatic) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _fieldLabel('Options'),
                    TextButton.icon(
                      onPressed: () => setSt(() => options.add('')),
                      icon: const Icon(Icons.add_rounded, size: 14, color: AppColors.evaGreenDeep),
                      label: Text('Add',
                          style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                      style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (c, i) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      height: 38,
                      child: Row(children: [
                        Expanded(
                          child: _inputBox(
                            child: TextField(
                              controller: TextEditingController(text: options[i])
                                ..selection =
                                    TextSelection.collapsed(offset: options[i].length),
                              onChanged: (v) => options[i] = v,
                              style: AppText.poppins(
                                  size: 12.5, weight: FontWeight.w600, color: AppColors.ink),
                              decoration: _inputDeco('Option ${i + 1}'),
                            ),
                          ),
                        ),
                        if (options.length > 1)
                          IconButton(
                            onPressed: () => setSt(() => options.removeAt(i)),
                            icon: const Icon(Icons.close_rounded,
                                size: 16, color: AppColors.danger),
                            padding: EdgeInsets.zero,
                            constraints:
                                const BoxConstraints(minWidth: 30, minHeight: 30),
                          ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Number min/max (non-static)
              if (isNumber && !isStatic) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _fieldLabel('Min'),
                        const SizedBox(height: 6),
                        _inputBox(
                          child: TextField(
                            keyboardType: TextInputType.number,
                            controller: minCtrl,
                            style: AppText.poppins(
                                size: 13, weight: FontWeight.w600, color: AppColors.ink),
                            decoration: _inputDeco('0'),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _fieldLabel('Max'),
                        const SizedBox(height: 6),
                        _inputBox(
                          child: TextField(
                            keyboardType: TextInputType.number,
                            controller: maxCtrl,
                            style: AppText.poppins(
                                size: 13, weight: FontWeight.w600, color: AppColors.ink),
                            decoration: _inputDeco('100'),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Max length for text types (non-static)
              if (isText && !isStatic) ...[
                _fieldLabel('Maximum Length'),
                const SizedBox(height: 6),
                _inputBox(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: maxLengthCtrl,
                    style: AppText.poppins(
                        size: 13, weight: FontWeight.w600, color: AppColors.ink),
                    decoration: _inputDeco('Maximum character length'),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Number of rows for Paragraph (non-static textarea)
              if (isMultiLine && !isStatic) ...[
                _fieldLabel('Number of Rows'),
                const SizedBox(height: 6),
                _inputBox(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: rowsCtrl,
                    style: AppText.poppins(
                        size: 13, weight: FontWeight.w600, color: AppColors.ink),
                    decoration: _inputDeco('Number of rows (default 3)'),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Document config (non-static)
              if (isDocument && !isStatic) ...[
                _fieldLabel('Allowed File Types'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'xls', 'xlsx']
                      .map((ext) {
                    final sel = allowedFileTypes.contains(ext);
                    return GestureDetector(
                      onTap: () => setSt(() {
                        if (sel) {
                          allowedFileTypes.remove(ext);
                        } else {
                          allowedFileTypes.add(ext);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.evaGreen50 : AppColors.surface2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: sel ? AppColors.evaGreen : AppColors.line),
                        ),
                        child: Text(ext,
                            style: AppText.poppins(
                                size: 11.5,
                                weight: FontWeight.w700,
                                color: sel ? AppColors.evaGreenDeep : AppColors.ink3)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Max File Size (MB)'),
                          const SizedBox(height: 6),
                          _inputBox(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              controller: maxFileSizeCtrl,
                              style: AppText.poppins(
                                  size: 13, weight: FontWeight.w600, color: AppColors.ink),
                              decoration: _inputDeco('10'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _toggleRow(
                        label: 'Allow Multiple Files',
                        value: multipleFiles,
                        onChanged: (v) => setSt(() => multipleFiles = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Mandatory toggle
              _checkRow(
                label: 'Mandatory Field',
                subtitle: 'Require this field before submitting',
                value: mandatory,
                onTap: () => setSt(() => mandatory = !mandatory),
              ),
              const SizedBox(height: 10),

              // Show in Form toggle
              _checkRow(
                label: 'Show in Ticket Form',
                subtitle: 'When unchecked, field is hidden from the form but still saved',
                value: displayInForm,
                onTap: () => setSt(() => displayInForm = !displayInForm),
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: AppColors.line),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Cancel',
                          style: AppText.poppins(
                              size: 13, weight: FontWeight.w700, color: AppColors.ink3)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) {
                                _snack('Field label is required');
                                return;
                              }
                              setSt(() => saving = true);
                              final payload = {
                                ...field,
                                'fieldName': name,
                                'mandatory': mandatory,
                                'displayInForm': displayInForm,
                                'placeholder': placeholderCtrl.text.trim().isEmpty
                                    ? 'Enter $name'
                                    : placeholderCtrl.text.trim(),
                                if (!isStatic) 'fieldType': selType,
                                if (!isStatic && needsOptions)
                                  'options': options.where((o) => o.trim().isNotEmpty).toList(),
                                if (!isStatic && isDocument)
                                  'allowedFileTypes': allowedFileTypes,
                                if (!isStatic && isDocument)
                                  'maxFileSize': int.tryParse(maxFileSizeCtrl.text) ?? 10,
                                if (!isStatic && isDocument) 'multipleFiles': multipleFiles,
                                if (!isStatic && isNumber) 'min': int.tryParse(minCtrl.text),
                                if (!isStatic && isNumber) 'max': int.tryParse(maxCtrl.text),
                                if (!isStatic && isText) 'maxLength': int.tryParse(maxLengthCtrl.text),
                                if (!isStatic && isMultiLine) 'rows': int.tryParse(rowsCtrl.text) ?? 3,
                              };
                              try {
                                if (_activeTab == 0) {
                                  await AppScope.of(context).ticketing.updateField(key, payload);
                                } else {
                                  await AppScope.of(context)
                                      .ticketing
                                      .updateCustomerResponseField(key, payload);
                                }
                                _snack('Field updated successfully');
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                _loadConfig();
                              } catch (e) {
                                _snack('Failed to update: $e');
                                setSt(() => saving = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.evaGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text('Update Field',
                              style: AppText.poppins(
                                  size: 13, weight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helper widgets
  // ──────────────────────────────────────────────────────────────────────────

  Widget _sheet(BuildContext ctx, {required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 10, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(child: child),
    );
  }

  Widget _sheetHandle() => Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
              color: AppColors.line, borderRadius: BorderRadius.circular(2)),
        ),
      );

  Widget _stepBar({required int currentStep}) => Row(
        children: List.generate(2, (i) {
          final active = i == currentStep;
          final done = i < currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i == 0 ? 4 : 0, left: i == 1 ? 4 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: done || active ? AppColors.evaGreen : AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      );

  Widget _fieldLabel(String text, {bool required = false}) => RichText(
        text: TextSpan(children: [
          TextSpan(
              text: text,
              style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
          if (required)
            TextSpan(
                text: ' *',
                style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.danger)),
        ]),
      );

  Widget _inputBox({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: child,
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink4),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: InputBorder.none,
      );

  Widget _checkRow({
    required String label,
    required String subtitle,
    required bool value,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: value ? AppColors.evaGreen50 : const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: value ? AppColors.evaGreen : AppColors.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  value ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  color: value ? AppColors.evaGreenDeep : AppColors.ink3,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppText.poppins(
                            size: 13,
                            weight: FontWeight.w700,
                            color: value ? AppColors.evaGreenDeep : AppColors.ink2)),
                    Text(subtitle,
                        style: AppText.poppins(
                            size: 11, weight: FontWeight.w500, color: AppColors.ink3)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _toggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppText.poppins(
                    size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.evaGreenDeep,
            activeTrackColor: AppColors.evaGreen,
          ),
        ],
      );

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final nav = AppNav.maybeOf(context);

    final totalFields = _fields.length;
    final staticCount = _fields.where(_isStatic).length;
    final customCount = totalFields - staticCount;
    final requiredCount = _fields.where((f) => f['mandatory'] == true).length;

    return Scaffold(
      backgroundColor: AppColors.surface2,
      body: GreenHeaderScaffold(
        title: 'Ticketing',
        onMenu: nav?.openDrawer,
        headerChild: GreenSegmented(
          items: const ['Dashboard', 'Tickets', 'Settings'],
          selected: 2,
          onChanged: (i) {
            if (i != 2) Navigator.of(context).pop(i);
          },
        ),
        sheet: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadConfig,
                color: AppColors.evaGreen,
                backgroundColor: Colors.white,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
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
                                    size: 13, weight: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Page Title
                    Text('Ticket Form',
                        style: AppText.poppins(
                            size: 20, weight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 14),

                    // Tab switcher
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: const Color(0xFFEEF1EC),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          _tabButton('Ticketing Flow', 0),
                          _tabButton('Customer Response Flow', 1),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Main card
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
                          // Card header
                          Text(
                            _activeTab == 0
                                ? 'Ticketing Form Configuration'
                                : 'Customer Response Flow Configuration',
                            style: AppText.poppins(
                                size: 15, weight: FontWeight.w800, color: AppColors.ink),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _activeTab == 0
                                ? 'Configure the fields for your ticket creation form'
                                : 'Configure the fields for your customer response form',
                            style: AppText.poppins(
                                size: 12, weight: FontWeight.w600, color: AppColors.ink4),
                          ),
                          const SizedBox(height: 16),

                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 42,
                                  child: ElevatedButton.icon(
                                    onPressed: _publishing ? null : _publishFlow,
                                    icon: _publishing
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2, color: Colors.white))
                                        : const Icon(Icons.publish_rounded,
                                            size: 16, color: Colors.white),
                                    label: Text(
                                        _publishing ? 'Publishing…' : 'Publish Flow',
                                        style: AppText.poppins(
                                            size: 13,
                                            weight: FontWeight.w700,
                                            color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.evaGreen,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 42,
                                  child: ElevatedButton.icon(
                                    onPressed: _showAddFieldSheet,
                                    icon: const Icon(Icons.add_rounded,
                                        size: 16, color: Colors.white),
                                    label: Text('Add Field',
                                        style: AppText.poppins(
                                            size: 13,
                                            weight: FontWeight.w700,
                                            color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.evaGreen,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Drag hint
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              children: [
                                const Icon(Icons.drag_indicator_rounded,
                                    size: 14, color: AppColors.ink3),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Drag and drop to reorder fields. Changes are saved automatically.',
                                    style: AppText.poppins(
                                        size: 11.5,
                                        weight: FontWeight.w600,
                                        color: AppColors.ink3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Field list
                          if (_loading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(30),
                                child: CircularProgressIndicator(color: AppColors.evaGreen),
                              ),
                            )
                          else if (totalFields == 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Text('No fields configured.',
                                    style: AppText.poppins(
                                        size: 13,
                                        weight: FontWeight.w600,
                                        color: AppColors.ink4)),
                              ),
                            )
                          else
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              itemCount: totalFields,
                              onReorder: _onReorder,
                              itemBuilder: (c, idx) => _fieldCard(idx),
                            ),

                          const SizedBox(height: 14),
                          const Divider(height: 1, color: AppColors.line),
                          const SizedBox(height: 14),

                          // Stats footer
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              _stat('Total Fields', '$totalFields'),
                              _stat('Static Fields', '$staticCount'),
                              _stat('Custom Fields', '$customCount'),
                              _stat('Required Fields', '$requiredCount'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index) => Expanded(
        child: GestureDetector(
          onTap: () {
            if (_activeTab != index) {
              setState(() => _activeTab = index);
              _loadConfig();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: _activeTab == index ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                label,
                style: AppText.poppins(
                  size: 12.5,
                  weight: FontWeight.w800,
                  color: _activeTab == index ? AppColors.evaGreenDeep : AppColors.ink3,
                ),
              ),
            ),
          ),
        ),
      );

  Widget _fieldCard(int idx) {
    final field = _fields[idx];
    final isStatic = _isStatic(field);
    final key = field['fieldKey']?.toString() ?? '';
    final name = field['fieldName']?.toString() ?? 'Field';
    final type = field['fieldType']?.toString() ?? 'text';
    final req = field['mandatory'] == true;
    final hidden = field['displayInForm'] == false;
    final placeholder = field['placeholder']?.toString() ?? '';
    final allowedTypes = field['allowedFileTypes'];
    final maxSize = field['maxFileSize'];

    return Container(
      key: ValueKey(key.isEmpty ? idx : key),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hidden ? const Color(0xFFFFFBF0) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: hidden ? const Color(0xFFF59E0B).withAlpha(80) : AppColors.line),
      ),
      child: Row(
        children: [
          // Drag handle
          ReorderableDragStartListener(
            index: idx,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFFF9FBF9),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, size: 14, color: AppColors.ink3),
                  Text('Drag',
                      style: AppText.poppins(
                          size: 9, weight: FontWeight.w700, color: AppColors.ink3)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.poppins(
                              size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
                    ),
                    if (req)
                      Text(' *',
                          style: AppText.poppins(
                              size: 13, weight: FontWeight.w800, color: AppColors.danger)),
                    const SizedBox(width: 6),
                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE5EEFD),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(type,
                          style: AppText.poppins(
                              size: 9.5,
                              weight: FontWeight.w700,
                              color: const Color(0xFF2563EB))),
                    ),
                    if (hidden) ...[
                      const SizedBox(width: 4),
                      // Hidden badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('Hidden',
                            style: AppText.poppins(
                                size: 9.5,
                                weight: FontWeight.w700,
                                color: const Color(0xFFD97706))),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),

                // Static/Custom badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isStatic ? AppColors.evaGreen50 : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isStatic ? 'Static Field' : 'Custom',
                    style: AppText.poppins(
                        size: 9.5,
                        weight: FontWeight.w700,
                        color: isStatic
                            ? AppColors.evaGreenDeep
                            : const Color(0xFFD97706)),
                  ),
                ),

                // Placeholder info
                if (placeholder.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Placeholder: $placeholder',
                      style: AppText.poppins(
                          size: 11, weight: FontWeight.w500, color: AppColors.ink3)),
                ],

                // Document specifics
                if (type == 'document') ...[
                  if (allowedTypes is List && (allowedTypes).isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'File Types: ${(allowedTypes).join(', ')}',
                      style: AppText.poppins(
                          size: 10.5, weight: FontWeight.w500, color: AppColors.ink3),
                    ),
                  ],
                  if (maxSize != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Max File Size: ${maxSize}MB',
                      style: AppText.poppins(
                          size: 10.5, weight: FontWeight.w500, color: AppColors.ink3),
                    ),
                  ],
                ],
              ],
            ),
          ),

          // Edit button
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(8)),
            child: IconButton(
              onPressed: () => _showEditSheet(field),
              icon: const Icon(Icons.edit_note_outlined, size: 20, color: Colors.blue),
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              padding: EdgeInsets.zero,
            ),
          ),

          // Delete button (custom only)
          if (!isStatic) ...[
            const SizedBox(width: 6),
            Container(
              decoration: BoxDecoration(
                  border: Border.all(color: AppColors.danger.withAlpha(60)),
                  borderRadius: BorderRadius.circular(8)),
              child: IconButton(
                onPressed: () => _deleteField(key),
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.danger),
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => RichText(
        text: TextSpan(children: [
          TextSpan(
              text: '$label: ',
              style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink)),
          TextSpan(
              text: value,
              style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
        ]),
      );
}
