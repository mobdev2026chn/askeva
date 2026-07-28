import 'package:flutter/material.dart';
import '../api/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/dashboard_sheets.dart' show appToast;
import '../widgets/common.dart';
import '../shell/app_nav.dart';

class WebhookScreen extends StatefulWidget {
  const WebhookScreen({super.key});

  @override
  State<WebhookScreen> createState() => _WebhookScreenState();
}

class _WebhookScreenState extends State<WebhookScreen> {
  bool _loading = false;
  bool _saving = false;
  bool _testing = false;
  bool _isEditing = false;

  final _urlCtrl = TextEditingController();
  bool _enabled = true;
  String _eventType = 'All'; // 'All' or 'Custom'
  
  // Custom events
  bool _ticketCreated = true;
  bool _ticketUpdated = true;
  bool _ticketCompleted = true;

  // Header parameters
  List<Map<String, String>> _headers = [{'key': '', 'value': ''}];

  // Sample JSON Payload
  final String _samplePayload = '''{
  "event": "ticket_created",
  "timestamp": "2025-10-06T09:41:22.594Z",
  "userId": "user_123",
  "data": {
    "ticket_id": "TKT_67890",
    "ticketId": "TK001",
    "subject": "Unable to login to my account",
    "description": "I'm getting an error message when trying to login with my credentials.",
    "priority": "high",
    "status": "open",
    "customer": {
      "name": "John Doe",
      "email": "john.doe@example.com",
      "phone": "+1234567890"
    },
    "department": "Technical Support",
    "assignedTo": "agent@example.com",
    "source": "web",
    "dueDate": "2025-10-08T09:41:22.594Z",
    "created_at": "2025-10-06T09:41:22.594Z",
    "updated_at": "2025-10-06T09:41:22.594Z"
  }
}''';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _snack(String msg, {bool err = false}) {
    appToast(context, msg);
  }

  Future<void> _loadConfig() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final repo = AppScope.of(context).ticketing;
      final res = await repo.fetchWebhookSettings();
      if (mounted) {
        setState(() {
          _urlCtrl.text = res['webhookUrl']?.toString() ?? '';
          _enabled = res['webhookEnabled'] != false;
          _eventType = res['eventType']?.toString() ?? 'All';

          final evts = res['webhookEvents'] as List?;
          if (evts != null) {
            _ticketCreated = evts.contains('ticket_created');
            _ticketUpdated = evts.contains('ticket_updated');
            _ticketCompleted = evts.contains('ticket_completed');
          }

          final hdrs = res['headerParameters'] as List?;
          if (hdrs != null && hdrs.isNotEmpty) {
            _headers = hdrs.map((h) {
              if (h is Map) {
                return {
                  'key': h['key']?.toString() ?? '',
                  'value': h['value']?.toString() ?? '',
                };
              }
              return {'key': '', 'value': ''};
            }).toList();
          } else {
            _headers = [{'key': '', 'value': ''}];
          }
        });
      }
    } catch (e) {
      _snack('Failed to load webhook configuration: $e', err: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveConfig() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      _snack('Webhook URL is required', err: true);
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAbsolutePath) {
      _snack('Please enter a valid URL', err: true);
      return;
    }

    // Validate headers
    final validHeaders = _headers.where((h) => h['key']!.trim().isNotEmpty && h['value']!.trim().isNotEmpty).toList();
    final hasInvalidHeaders = _headers.any((h) =>
        (h['key']!.trim().isNotEmpty && h['value']!.trim().isEmpty) ||
        (h['key']!.trim().isEmpty && h['value']!.trim().isNotEmpty));

    if (hasInvalidHeaders) {
      _snack('All header parameters must have both key and value filled or be empty', err: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = AppScope.of(context).ticketing;
      final events = _eventType == 'All'
          ? ['ticket_created', 'ticket_updated', 'ticket_completed']
          : [
              if (_ticketCreated) 'ticket_created',
              if (_ticketUpdated) 'ticket_updated',
              if (_ticketCompleted) 'ticket_completed',
            ];

      final payload = {
        'webhookUrl': url,
        'webhookEnabled': _enabled,
        'eventType': _eventType,
        'webhookEvents': events,
        'headerParameters': validHeaders,
      };

      await repo.updateWebhookSettings(payload);
      _snack('Webhook configuration saved successfully');
      setState(() {
        _isEditing = false;
        _saving = false;
      });
      _loadConfig();
    } catch (e) {
      _snack('Failed to save configuration: $e', err: true);
      setState(() => _saving = false);
    }
  }

  Future<void> _testWebhook() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      _snack('Please configure a webhook URL first', err: true);
      return;
    }

    setState(() => _testing = true);
    try {
      final repo = AppScope.of(context).ticketing;
      final validHeaders = _headers.where((h) => h['key']!.trim().isNotEmpty && h['value']!.trim().isNotEmpty).toList();

      final res = await repo.testWebhook({
        'webhookUrl': url,
        'headerParameters': validHeaders,
      });

      if (res['success'] == true) {
        _snack('Webhook test successful!');
      } else {
        _snack('Webhook test failed: ${res['message'] ?? 'Unknown error'}', err: true);
      }
    } catch (e) {
      _snack('Webhook test failed: $e', err: true);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _resetConfig() {
    setState(() {
      _urlCtrl.clear();
      _eventType = 'All';
      _enabled = true;
      _ticketCreated = true;
      _ticketUpdated = true;
      _ticketCompleted = true;
      _headers = [{'key': '', 'value': ''}];
      _isEditing = true;
    });
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
            : SingleChildScrollView(
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
                    Text('Webhook Configuration',
                        style: AppText.poppins(
                            size: 20,
                            weight: FontWeight.w800,
                            color: AppColors.ink)),
                    const SizedBox(height: 14),

                    // Main config card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                        boxShadow: AppColors.shadowSm,
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Card title and enabled switch
                        Row(children: [
                          const Icon(Icons.link_rounded, size: 24, color: AppColors.evaGreen),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Webhook Configuration', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                          ),
                          Text('Enabled', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3)),
                          const SizedBox(width: 6),
                          IgnorePointer(
                            ignoring: !_isEditing,
                            child: Switch(
                              value: _enabled,
                              activeColor: AppColors.evaGreen,
                              onChanged: (v) => setState(() => _enabled = v),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),

                        // Webhook URL field
                        RichText(text: TextSpan(children: [
                          TextSpan(text: 'Webhook URL', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                          TextSpan(text: ' *', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.danger)),
                        ])),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: _isEditing ? AppColors.surface : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: TextField(
                            controller: _urlCtrl,
                            enabled: _isEditing,
                            style: AppText.poppins(size: 13, weight: FontWeight.w600, color: _isEditing ? AppColors.ink : AppColors.ink2),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Enter webhook URL (e.g., https://api.example.com/webhook)',
                              hintStyle: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink4),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Event Type dropdown
                        RichText(text: TextSpan(children: [
                          TextSpan(text: 'Event Type', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                          TextSpan(text: ' *', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.danger)),
                        ])),
                        const SizedBox(height: 6),
                        Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: _isEditing ? AppColors.surface : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _eventType,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.ink4),
                              style: AppText.poppins(size: 13, weight: FontWeight.w600, color: _isEditing ? AppColors.ink : AppColors.ink2),
                              items: const [
                                DropdownMenuItem(value: 'All', child: Text('All Events')),
                                DropdownMenuItem(value: 'Custom', child: Text('Custom Events')),
                              ],
                              onChanged: _isEditing ? (v) => setState(() => _eventType = v ?? 'All') : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Custom Events checkboxes (visible if eventType == Custom)
                        if (_eventType == 'Custom') ...[
                          Text('Select Events to Send', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                          const SizedBox(height: 6),
                          Row(children: [
                            Expanded(
                              child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                value: _ticketCreated,
                                activeColor: AppColors.evaGreen,
                                enabled: _isEditing,
                                title: Text('Ticket Created', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink2)),
                                onChanged: (v) => setState(() => _ticketCreated = v == true),
                              ),
                            ),
                            Expanded(
                              child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                value: _ticketUpdated,
                                activeColor: AppColors.evaGreen,
                                enabled: _isEditing,
                                title: Text('Ticket Updated', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink2)),
                                onChanged: (v) => setState(() => _ticketUpdated = v == true),
                              ),
                            ),
                          ]),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _ticketCompleted,
                            activeColor: AppColors.evaGreen,
                            enabled: _isEditing,
                            title: Text('Ticket Completed', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink2)),
                            onChanged: (v) => setState(() => _ticketCompleted = v == true),
                          ),
                          const SizedBox(height: 14),
                        ],
                        const Divider(height: 1, color: AppColors.line),
                        const SizedBox(height: 14),

                        // Header Parameters section
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Expanded(
                            child: Text('Header Parameters (Optional)', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink)),
                          ),
                          const SizedBox(width: 8),
                          if (_isEditing)
                            TextButton.icon(
                              onPressed: () => setState(() => _headers.add({'key': '', 'value': ''})),
                              icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                              label: Text('Add Header', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: Colors.white)),
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.evaGreen,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 10),

                        ...List.generate(_headers.length, (idx) {
                          final header = _headers[idx];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Row(children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _isEditing ? AppColors.surface : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.line),
                                  ),
                                  child: TextField(
                                    controller: TextEditingController(text: header['key'])..selection = TextSelection.collapsed(offset: header['key']!.length),
                                    enabled: _isEditing,
                                    onChanged: (v) => _headers[idx]['key'] = v,
                                    style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: _isEditing ? AppColors.ink : AppColors.ink2),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: 'Header Key',
                                      hintStyle: AppText.poppins(size: 12.5, weight: FontWeight.w500, color: AppColors.ink4),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _isEditing ? AppColors.surface : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.line),
                                  ),
                                  child: TextField(
                                    controller: TextEditingController(text: header['value'])..selection = TextSelection.collapsed(offset: header['value']!.length),
                                    enabled: _isEditing,
                                    onChanged: (v) => _headers[idx]['value'] = v,
                                    style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: _isEditing ? AppColors.ink : AppColors.ink2),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: 'Header Value',
                                      hintStyle: AppText.poppins(size: 12.5, weight: FontWeight.w500, color: AppColors.ink4),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                              if (_isEditing && _headers.length > 1)
                                IconButton(
                                  onPressed: () => setState(() => _headers.removeAt(idx)),
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                                ),
                            ]),
                          );
                        }),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppColors.line),
                        const SizedBox(height: 16),

                        // Sample JSON payload box
                        Text('Sample Payload Structure', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F8FA),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE1E4E8)),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: buildSyntaxHighlightJson(_samplePayload),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your webhook endpoint should accept POST requests with JSON payloads',
                          style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink4),
                        ),
                        const SizedBox(height: 20),

                        // Bottom configuration triggers
                        if (!_isEditing) ...[
                          // View mode buttons
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: () => setState(() => _isEditing = true),
                              icon: const Icon(Icons.edit_note_rounded, size: 18),
                              label: const Text('Edit Configuration'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.evaGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _testing ? null : _testWebhook,
                                icon: _testing
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink2))
                                    : const Icon(Icons.play_arrow_rounded, size: 16),
                                label: const Text('Test Webhook'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.ink2,
                                  side: const BorderSide(color: AppColors.line),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _resetConfig,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(color: AppColors.danger),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                child: const Text('Reset'),
                              ),
                            ),
                          ]),
                        ] else ...[
                          // Edit mode buttons
                          Row(children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() => _isEditing = false);
                                  _loadConfig();
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.ink2,
                                  side: const BorderSide(color: AppColors.line),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _saving ? null : _saveConfig,
                                icon: _saving
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Save Configuration'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.evaGreen,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                ),
                              ),
                            ),
                          ]),
                        ],
                      ]),
                    ),
                  ]),
                ),
      ),
    );
  }
}
