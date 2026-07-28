import 'package:flutter/material.dart';
import '../utils/snackbar_above.dart';
import '../../../theme/app_colors.dart';

class WebhookForm extends StatefulWidget {
  final Map<String, dynamic>? initialConfig;
  final Future<void> Function(Map<String, dynamic>) onSave;
  /// Called when user taps "Test Webhook". Backend uses saved config.
  final Future<void> Function()? onTest;

  const WebhookForm({
    super.key,
    this.initialConfig,
    required this.onSave,
    this.onTest,
  });

  @override
  State<WebhookForm> createState() => _WebhookFormState();
}

class _WebhookFormState extends State<WebhookForm> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  /// Header rows: list of {key, value} for mutable updates
  late List<Map<String, String>> _headerRows;
  bool _isLoading = false;
  bool _isTesting = false;
  /// 'All' | 'Custom' - backend expects exactly these
  String _eventType = 'All';

  final Map<String, bool> _events = {
    'leadCreation': false,
    'leadUpdation': false,
    'leadDeletion': false,
    'convertedToCustomer': false,
  };

  @override
  void initState() {
    super.initState();
    _headerRows = [];
    if (widget.initialConfig != null) {
      _urlController.text = widget.initialConfig!['url'] ?? '';
      _eventType = widget.initialConfig!['eventType'] == 'Custom' ? 'Custom' : 'All';
      final events = widget.initialConfig!['events'];
      if (events is Map) {
        for (final e in events.entries) {
          if (_events.containsKey(e.key)) {
            _events[e.key] = e.value == true;
          }
        }
      }
      if (_eventType == 'All') {
        _events['leadCreation'] = true;
        _events['leadUpdation'] = true;
        _events['leadDeletion'] = true;
        _events['convertedToCustomer'] = true;
      }
      final headers = widget.initialConfig!['headerParameters'];
      if (headers is List && headers.isNotEmpty) {
        for (var i = 0; i < headers.length; i++) {
          final h = headers[i];
          if (h is Map) {
            _headerRows.add({
              'key': (h['key'] ?? '').toString(),
              'value': (h['value'] ?? '').toString(),
            });
          }
        }
      }
    }
    if (_headerRows.isEmpty) {
      _headerRows.add({'key': '', 'value': ''});
    }
  }

  void _addHeader() {
    setState(() {
      _headerRows.add({'key': '', 'value': ''});
    });
  }

  void _removeHeader(int index) {
    setState(() {
      if (_headerRows.length > 1) {
        _headerRows.removeAt(index);
      }
    });
  }

  void _updateHeader(int index, String field, String value) {
    setState(() {
      _headerRows[index] = {..._headerRows[index], field: value};
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final events = _eventType == 'All'
          ? {
              'leadCreation': true,
              'leadUpdation': true,
              'leadDeletion': true,
              'convertedToCustomer': true,
            }
          : Map<String, bool>.from(_events);

      if (_eventType == 'Custom') {
        final atLeastOne = events.values.any((v) => v == true);
        if (!atLeastOne) {
          if (mounted) {
            showSnackBarAbove(context, 'Select at least one event for Custom');
          }
          return;
        }
      }

      final validHeaders = _headerRows
          .where((h) => (h['key'] ?? '').trim().isNotEmpty && (h['value'] ?? '').trim().isNotEmpty)
          .map((h) => {'key': (h['key'] ?? '').trim(), 'value': (h['value'] ?? '').trim()})
          .toList();

      final config = {
        'url': _urlController.text.trim(),
        'eventType': _eventType,
        'events': events,
        'headerParameters': validHeaders,
      };
      await widget.onSave(config);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _testWebhook() async {
    if (widget.onTest == null) return;
    setState(() => _isTesting = true);
    try {
      await widget.onTest!();
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  void _reset() {
    setState(() {
      _urlController.clear();
      _eventType = 'All';
      _events['leadCreation'] = true;
      _events['leadUpdation'] = true;
      _events['leadDeletion'] = true;
      _events['convertedToCustomer'] = true;
      _headerRows = [{'key': '', 'value': ''}];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const Text(
            'Webhook Configuration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'Webhook URL *',
              hintText: 'https://api.example.com/webhook',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.link, color: AppColors.primary),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'URL is required';
              final u = Uri.tryParse(value);
              if (u == null || !u.hasAbsolutePath) return 'Invalid URL';
              return null;
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Events *',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _eventType,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All')),
              DropdownMenuItem(value: 'Custom', child: Text('Custom')),
            ],
            onChanged: (v) {
              setState(() {
                _eventType = v ?? 'All';
                if (_eventType == 'All') {
                  _events['leadCreation'] = true;
                  _events['leadUpdation'] = true;
                  _events['leadDeletion'] = true;
                  _events['convertedToCustomer'] = true;
                }
              });
            },
          ),
          if (_eventType == 'Custom') ...[
            const SizedBox(height: 12),
            ..._events.keys.map((event) {
              String label = event;
              if (event == 'leadCreation') label = 'Lead Creation';
              if (event == 'leadUpdation') label = 'Lead Updation';
              if (event == 'leadDeletion') label = 'Lead Deletion';
              if (event == 'convertedToCustomer') label = 'Converted to Customer';
              return CheckboxListTile(
                title: Text(label),
                value: _events[event],
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() => _events[event] = val ?? false);
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              );
            }),
          ],
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              const Text(
                'Header Parameters (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton.icon(
                onPressed: _addHeader,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
          ...List.generate(_headerRows.length, (index) {
            final row = _headerRows[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: row['key'],
                      decoration: const InputDecoration(
                        labelText: 'Header Key',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (val) => _updateHeader(index, 'key', val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: row['value'],
                      decoration: const InputDecoration(
                        labelText: 'Header Value',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (val) => _updateHeader(index, 'value', val),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed:
                        _headerRows.length > 1 ? () => _removeHeader(index) : null,
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          const Text(
            'Sample Payload',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (ctx) {
              final cs = Theme.of(ctx).colorScheme;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.outline.withOpacity(0.5)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    '{\n  "event": "lead_created",\n  "timestamp": "2023-07-20T12:34:56Z",\n  "data": {\n    "leadId": "507f1f77bcf86cd799439011",\n    "name": "John Doe",\n    "email": "john@example.com",\n    "mobile": "1234567890",\n    "company": "Example Corp",\n    "status": "New Lead"\n  }\n}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
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
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary)
                        : const Text('Save'),
                  ),
                ),
              ),
              if (widget.onTest != null) ...[
                const SizedBox(width: 12),
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _isTesting ? null : _testWebhook,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isTesting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Test Webhook'),
                  ),
                ),
              ],
              const SizedBox(width: 12),
              SizedBox(
                height: 50,
                child: TextButton(
                  onPressed: _isLoading ? null : _reset,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Reset'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
