import 'package:flutter/material.dart';
import '../utils/snackbar_above.dart';
import '../../../theme/app_colors.dart';
import '../../../services/chat_service.dart';
import 'template_selection_modal.dart';

/// One reminder card (Business Alert or New Lead Creation Alert).
/// When active: Recipient, Select Template (web-style modal), template preview,
/// variable mapping, Save/Reset.
class ReminderAlertCard extends StatefulWidget {
  final String alertType;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool active;
  final Map<String, dynamic>? savedAlert; // from config.alerts[alertType]
  final List<dynamic> leadFields; // for "Map X to Lead Field" dropdowns
  final Future<void> Function(bool) onToggle;
  final Future<void> Function(Map<String, dynamic> alertData) onSave;
  final Future<void> Function() onReset;

  const ReminderAlertCard({
    super.key,
    required this.alertType,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.active,
    this.savedAlert,
    this.leadFields = const [],
    required this.onToggle,
    required this.onSave,
    required this.onReset,
  });

  @override
  State<ReminderAlertCard> createState() => _ReminderAlertCardState();
}

class _ReminderAlertCardState extends State<ReminderAlertCard> {
  Map<String, dynamic>? _draftTemplate;
  bool _loadingTemplates = false;
  List<dynamic> _templates = [];
  bool _saving = false;
  bool _resetting = false;
  Map<String, String> _draftVariableMappings = {};

  Map<String, dynamic>? get _effectiveTemplate =>
      _draftTemplate ?? (widget.savedAlert?['template'] as Map<String, dynamic>?);

  List<String> get _templateVariables {
    final template = _effectiveTemplate;
    if (template == null) return [];
    final ex = template['examples'];
    if (ex is Map && ex.isNotEmpty) return ex.keys.map((k) => k.toString()).toList();
    if (ex is List && ex.isNotEmpty) return ex.map((e) => e.toString()).toList();

    // Regex extraction from message / body text for {{1}}, {{2}} or {{varName}}
    final msg = (template['message'] ?? template['body'] ?? '').toString();
    if (msg.isNotEmpty) {
      final matches = RegExp(r'\{\{([^}]+)\}\}').allMatches(msg);
      final vars = <String>{};
      for (final m in matches) {
        final varName = m.group(1)?.trim();
        if (varName != null && varName.isNotEmpty) {
          vars.add(varName);
        }
      }
      if (vars.isNotEmpty) {
        final sorted = vars.toList();
        sorted.sort();
        return sorted;
      }
    }
    return [];
  }

  Map<String, String> get _effectiveVariableMappings {
    final saved = widget.savedAlert?['formData']?['variableMappings'] as Map<String, dynamic>?;
    final savedStr = saved?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? <String, String>{};
    return {...savedStr, ..._draftVariableMappings};
  }

  @override
  void initState() {
    super.initState();
    if (widget.active) _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    if (_templates.isNotEmpty) return;
    setState(() => _loadingTemplates = true);
    try {
      final list = await ChatService.getApprovedTemplates();
      if (mounted) {
        setState(() {
          _templates = list;
          _loadingTemplates = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingTemplates = false);
      }
    }
  }

  Future<void> _pickTemplate() async {
    await _loadTemplates();
    if (!mounted || _templates.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => TemplateSelectionModal(
          templates: _templates,
          onSelect: (t) {
            Navigator.pop(ctx);
            if (mounted) {
              setState(() {
                _draftTemplate = t;
                _draftVariableMappings = {};
              });
            }
          },
          onClose: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final template = _effectiveTemplate;
    if (template == null) {
      showSnackBarAbove(context, 'Please select a template first');
      return;
    }
    setState(() => _saving = true);
    try {
      final formData = Map<String, dynamic>.from(widget.savedAlert?['formData'] ?? {});
      formData['variableMappings'] = _effectiveVariableMappings;
      await widget.onSave({
        'active': widget.active,
        'template': template,
        'formData': formData,
      });
      if (mounted) {
        setState(() {
          _draftTemplate = null;
          _saving = false;
        });
        showSnackBarAbove(context, 'Alert configuration saved');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnackBarAbove(
          context,
          e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Failed to save: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _reset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset configuration?'),
        content: const Text(
          'This will clear the template and settings for this alert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _resetting = true);
    try {
      await widget.onReset();
      if (mounted) {
        setState(() {
          _draftTemplate = null;
          _draftVariableMappings = {};
          _resetting = false;
        });
        showSnackBarAbove(context, 'Alert configuration reset');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _resetting = false);
        showSnackBarAbove(
          context,
          e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Failed to reset: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = _effectiveTemplate;
    final recipientLabel = widget.alertType == 'newLeadCreationAlert'
        ? 'Primary Contact'
        : 'Agent Contact Number';

    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outline.withOpacity(0.5)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: widget.active,
                    onChanged: (v) async {
                      if (!v && widget.active) {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
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
                        if (confirm == true) {
                          await widget.onToggle(false);
                        }
                      } else {
                        await widget.onToggle(v);
                      }
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
              if (widget.active) ...[
                const Divider(height: 24),
                Text(
                  'Recipient Number',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recipientLabel,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Template *',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                if (template != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Template Name: ${(template['name'] ?? template['message'] ?? 'Template').toString()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: _loadingTemplates ? null : _pickTemplate,
                        icon: _loadingTemplates
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, color: AppColors.primary),
                        tooltip: 'Change template',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (template['type'] != null)
                          _templateRow('Type:', template['type'].toString()),
                        if (template['headerType'] != null)
                          _templateRow('Header:', template['headerType'].toString()),
                        if (template['footer'] != null)
                          _templateRow('Footer:', template['footer'].toString()),
                        if (template['message'] != null)
                          _templateRow('Body:', template['message'].toString()),
                      ],
                    ),
                  ),
                  // Variable mapping: Map 'VarName' to Lead Field
                  if (_templateVariables.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ..._templateVariables.map((variable) {
                      final currentMapping = _effectiveVariableMappings[variable] ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Map "$variable" to Lead Field',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: currentMapping.isEmpty ? null : currentMapping,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              hint: const Text('-- No Mapping --'),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('-- No Mapping --'),
                                ),
                                ...widget.leadFields
                                    .where((f) => (f['fieldType'] ?? '').toString() != 'tags')
                                    .map((f) {
                                  final key = (f['fieldKey'] ?? '').toString();
                                  final name = (f['fieldName'] ?? key).toString();
                                  return DropdownMenuItem<String>(
                                    value: key,
                                    child: Text('$name ($key)'),
                                  );
                                }),
                              ],
                              onChanged: (v) => setState(() {
                                if (v == null || v.isEmpty) {
                                  _draftVariableMappings.remove(variable);
                                } else {
                                  _draftVariableMappings[variable] = v;
                                }
                              }),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ] else
                  OutlinedButton.icon(
                    onPressed: _loadingTemplates ? null : _pickTemplate,
                    icon: _loadingTemplates
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add, size: 18),
                    label: const Text('Select template'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _resetting ? null : _reset,
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: _resetting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Reset'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _saving || template == null ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: _saving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
    );
  }

  Widget _templateRow(String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value.length > 200 ? '${value.substring(0, 200)}...' : value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
