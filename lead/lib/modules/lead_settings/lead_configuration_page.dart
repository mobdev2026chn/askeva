import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'utils/snackbar_above.dart';
import 'widgets/webhook_form.dart';
import 'widgets/quick_reply_table.dart';
import 'widgets/facebook_connect_card.dart';
import 'widgets/quick_reply_modal.dart';
import 'widgets/reminder_alert_card.dart';
import '../../services/lead_configuration_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/drawer_menu_icon.dart';
import '../../widgets/modern_dialog.dart';

class LeadConfigurationPage extends StatefulWidget {
  final String? email;
  final String? name;
  /// When true, shows a full Scaffold with AppBar (e.g. when pushed from Settings).
  /// When false, only the content is shown (embedded in Leads tab).
  final bool showAppBar;
  /// When true (and showAppBar is false), hide drawer/settings icon and show only Quick Reply screen.
  final bool showOnlyQuickReply;
  const LeadConfigurationPage({
    super.key,
    this.email,
    this.name,
    this.showAppBar = true,
    this.showOnlyQuickReply = false,
  });

  @override
  State<LeadConfigurationPage> createState() => _LeadConfigurationPageState();
}

enum _SettingsSection {
  quickReply,
  settings,
  facebookSync,
  remainders,
  webhook,
}

class _LeadConfigurationPageState extends State<LeadConfigurationPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;
  Map<String, dynamic>? _config;
  List<dynamic> _quickReplies = [];
  bool _isFacebookLoading = false;
  _SettingsSection _selectedSection = _SettingsSection.quickReply;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _openSettingsDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final config = await LeadConfigurationService.getConfiguration();
      final quickReplies = await LeadConfigurationService.getQuickReplies();
      final alerts = await LeadConfigurationService.getAlertConfig();

      if (config.containsKey('alerts')) {
        config['alerts'] = alerts; // Override or merge
      } else {
        config['alerts'] = alerts;
      }

      setState(() {
        _config = config;
        _quickReplies = quickReplies;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Don't show error snackbar on first load if it's just empty data
      }
    }
  }

  Future<void> _saveWebhook(Map<String, dynamic> webhookConfig) async {
    try {
      await LeadConfigurationService.updateWebhookConfig(webhookConfig);
      if (mounted) {
        showSnackBarAbove(context, 'Webhook configuration updated successfully');
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        showSnackBarAbove(
          context,
          e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Failed to update webhook: $e',
          isError: true,
        );
      }
    }
  }

  String? _quickReplyId(dynamic item) {
    if (item == null) return null;
    dynamic id = item['_id'] ?? item['id'];
    if (id == null) return null;
    if (id is String) return id.trim().isEmpty ? null : id.trim();
    if (id is Map && id.containsKey(r'$oid')) {
      final oid = id[r'$oid'] as String?;
      return (oid != null && oid.trim().isNotEmpty) ? oid.trim() : null;
    }
    final s = id.toString().trim();
    return s.isEmpty ? null : s;
  }

  void _showQuickReplyModal([dynamic item]) {
    // Capture id when opening modal so save callback uses correct id (matches backend PUT /quick-replies/:id)
    final editId = item != null ? _quickReplyId(item) : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickReplyModal(
        initialData: item,
        editId: editId,
        onSave: (data) async {
          try {
            if (editId != null && editId.isNotEmpty) {
              // Backend expects PUT /v1/lead-configuration/quick-replies/:id with body { title, message }
              await LeadConfigurationService.updateQuickReply(
                editId,
                {'title': data['title'], 'message': data['message']},
              );
            } else {
              await LeadConfigurationService.createQuickReply(data);
            }
            if (mounted) {
              Navigator.pop(context);
              _loadData();
              showSnackBarAbove(
                context,
                editId != null ? 'Quick reply updated' : 'Quick reply created',
              );
            }
          } catch (e) {
            if (mounted) {
              showSnackBarAbove(
                context,
                e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Error: $e',
                isError: true,
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteQuickReply(dynamic item) async {
    final confirm = await showModernConfirmDialog(
      context: context,
      title: 'Delete Quick Reply',
      message: 'Are you sure you want to delete "${item['title']}"?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        final id = _quickReplyId(item);
        if (id != null) await LeadConfigurationService.deleteQuickReply(id);
        _loadData();
        if (mounted) {
          showSnackBarAbove(context, 'Quick reply deleted');
        }
      } catch (e) {
        if (mounted) {
          showSnackBarAbove(
            context,
            e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Error: $e',
            isError: true,
          );
        }
      }
    }
  }

  Future<void> _connectFacebook() async {
    setState(() => _isFacebookLoading = true);
    try {
      final res = await LeadConfigurationService.getFacebookAuthUrl();
      // In a real app, you'd launch the URL in a browser or webview
      // For now, we simulate success
      if (mounted) {
        showSnackBarAbove(context, 'Facebook Auth URL generated: ${res['authUrl']}');
      }
    } catch (e) {
      if (mounted) {
        showSnackBarAbove(
          context,
          e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Failed to connect Facebook: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isFacebookLoading = false);
    }
  }

  static const double _drawerWidth = 320;

  static const _sectionItems = [
    (_SettingsSection.quickReply, Icons.quickreply_rounded, 'Quick Reply'),
    (_SettingsSection.settings, Icons.tune_rounded, 'Settings'),
    (_SettingsSection.facebookSync, Icons.facebook_rounded, 'Facebook Sync'),
    (_SettingsSection.remainders, Icons.notifications_active_rounded, 'Reminders'),
    (_SettingsSection.webhook, Icons.webhook_rounded, 'Webhook'),
  ];

  void _selectSection(_SettingsSection section) {
    setState(() => _selectedSection = section);
    Navigator.of(context).pop();
  }

  Widget _buildQuickReplyOnlyBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Loading…',
              style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildQuickReplyTab(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Loading configuration…',
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildSectionContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionContent() {
    switch (_selectedSection) {
      case _SettingsSection.quickReply:
        return KeyedSubtree(key: const ValueKey('quickReply'), child: _buildQuickReplyTab());
      case _SettingsSection.settings:
        return _sectionCard(
          child: SizedBox(key: const ValueKey('settings'), height: 700, child: _buildSettingsTab()),
        );
      case _SettingsSection.facebookSync:
        return KeyedSubtree(key: const ValueKey('facebook'), child: _buildFacebookSyncTab());
      case _SettingsSection.remainders:
        return KeyedSubtree(key: const ValueKey('remainders'), child: _buildRemindersTab());
      case _SettingsSection.webhook:
        return KeyedSubtree(key: const ValueKey('webhook'), child: _buildWebhookTab());
    }
  }

  Widget _buildSettingsDrawer() {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width > 600;
    return Container(
      width: isWide ? _drawerWidth : double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.settings_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Lead Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
                    style: IconButton.styleFrom(
                      backgroundColor: cs.surfaceContainerHighest,
                      foregroundColor: cs.onSurfaceVariant,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outline.withOpacity(0.5)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                children: _sectionItems.map((item) {
                  final section = item.$1;
                  final icon = item.$2;
                  final title = item.$3;
                  final isSelected = _selectedSection == section;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => _selectSection(section),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Icon(
                                icon,
                                size: 22,
                                color: isSelected ? AppColors.primary : cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected ? cs.onSurface : cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle_rounded, size: 20, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    if (!widget.showAppBar) {
      final hideDrawerAndIcon = widget.showOnlyQuickReply;
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: scaffoldBg,
        endDrawer: hideDrawerAndIcon ? null : Drawer(child: _buildSettingsDrawer()),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hideDrawerAndIcon)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Lead Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: _openSettingsDrawer,
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.settings_rounded, size: 24, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: hideDrawerAndIcon ? _buildQuickReplyOnlyBody() : _buildBody(),
              ),
            ],
          ),
        ),
        floatingActionButton: (hideDrawerAndIcon || _selectedSection == _SettingsSection.quickReply)
            ? FloatingActionButton(
                onPressed: () => _showQuickReplyModal(),
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.add_rounded, color: Colors.white),
                tooltip: 'Add Quick Reply',
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );
    }
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: scaffoldBg,
      drawer: AppDrawer(email: widget.email, name: widget.name),
      endDrawer: Drawer(
        child: _buildSettingsDrawer(),
      ),
      appBar: AppBar(
        leading: const DrawerMenuIcon(),
        title: const Text('Lead Configuration'),
        elevation: 0,
        toolbarHeight: 56,
        actions: [
          IconButton(
            onPressed: _openSettingsDrawer,
            icon: const Icon(Icons.settings_rounded, size: 24),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _selectedSection == _SettingsSection.quickReply
          ? FloatingActionButton(
              onPressed: () => _showQuickReplyModal(),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_rounded, color: Colors.white),
              tooltip: 'Add Quick Reply',
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Future<void> _updateAlertConfig(String alertType, bool value) async {
    try {
      final currentData = _config?['alerts']?[alertType] ?? {};
      final newData = Map<String, dynamic>.from(currentData);
      newData['active'] = value;

      await LeadConfigurationService.updateAlertConfig(alertType, newData);

      setState(() {
        if (_config != null) {
          if (_config!['alerts'] == null) _config!['alerts'] = {};
          if (_config!['alerts'][alertType] == null) {
            _config!['alerts'][alertType] = {};
          }
          _config!['alerts'][alertType]['active'] = value;
        }
      });
    } catch (e) {
      if (mounted) {
        showSnackBarAbove(
          context,
          e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Failed to update settings: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _saveAlertConfig(
    String alertType,
    Map<String, dynamic> alertData,
  ) async {
    await LeadConfigurationService.updateAlertConfig(alertType, alertData);
    await _loadData();
  }

  Future<void> _resetAlertConfig(String alertType) async {
    await LeadConfigurationService.deleteAlertConfig(alertType);
    await _loadData();
  }

  Widget _buildRemindersTab() {
    final alerts = _config?['alerts'] ?? {};
    final businessAlert = alerts['businessAlert'] as Map<String, dynamic>?;
    final newLeadAlert = alerts['newLeadCreationAlert'] as Map<String, dynamic>?;
    final leadFields = (_config?['leadFields'] as List<dynamic>?) ?? [];

    return _sectionCard(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
        builder: (context, constraints) {
          final useHorizontal = constraints.maxWidth > 600;
          final cards = [
            ReminderAlertCard(
              alertType: 'businessAlert',
              title: 'Business Alert',
              subtitle:
                  'Track and manage all new leads in your system with real-time updates.',
              icon: Icons.calendar_today,
              active: businessAlert?['active'] ?? false,
              savedAlert: businessAlert,
              leadFields: leadFields,
              onToggle: (v) => _updateAlertConfig('businessAlert', v),
              onSave: (data) => _saveAlertConfig('businessAlert', data),
              onReset: () => _resetAlertConfig('businessAlert'),
            ),
            ReminderAlertCard(
              alertType: 'newLeadCreationAlert',
              title: 'New Lead Creation Alert',
              subtitle:
                  'Monitor lead progression and send automated updates.',
              icon: Icons.calendar_view_month,
              active: newLeadAlert?['active'] ?? false,
              savedAlert: newLeadAlert,
              leadFields: leadFields,
              onToggle: (v) => _updateAlertConfig('newLeadCreationAlert', v),
              onSave: (data) => _saveAlertConfig('newLeadCreationAlert', data),
              onReset: () => _resetAlertConfig('newLeadCreationAlert'),
            ),
          ];
          return useHorizontal
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 16),
                      Expanded(child: cards[1]),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    cards[0],
                    cards[1],
                  ],
                );
        },
      ),
    ),
    );
  }

  Future<void> _toggleFieldDisplay(String fieldKey, bool newValue) async {
    try {
      await LeadConfigurationService.updateField(
        fieldKey,
        {'displayInTable': newValue},
      );
      setState(() {
        if (_config != null && _config!['leadFields'] != null) {
          final list = _config!['leadFields'] as List<dynamic>;
          for (var i = 0; i < list.length; i++) {
            if (list[i]['fieldKey'] == fieldKey) {
              list[i]['displayInTable'] = newValue;
              break;
            }
          }
        }
      });
      if (mounted) {
        showSnackBarAbove(context, 'Field updated');
      }
    } catch (e) {
      if (mounted) {
        showSnackBarAbove(
          context,
          e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Failed to update: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _toggleFieldMandatory(String fieldKey, bool newValue) async {
    try {
      await LeadConfigurationService.updateField(
        fieldKey,
        {'mandatory': newValue},
      );
      setState(() {
        if (_config != null && _config!['leadFields'] != null) {
          final list = _config!['leadFields'] as List<dynamic>;
          for (var i = 0; i < list.length; i++) {
            if (list[i]['fieldKey'] == fieldKey) {
              list[i]['mandatory'] = newValue;
              break;
            }
          }
        }
      });
      if (mounted) {
        showSnackBarAbove(context, 'Mandatory status updated');
      }
    } catch (e) {
      if (mounted) {
        showSnackBarAbove(
          context,
          e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Failed to update: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _addCustomField(String fieldName, String fieldType) async {
    if (fieldName.trim().isEmpty) return;
    try {
      await LeadConfigurationService.addCustomField({
        'fieldName': fieldName.trim(),
        'fieldType': fieldType,
        'mandatory': false,
        'displayInTable': true,
        if (fieldType == 'select') 'options': [],
      });
      await _loadData();
      if (mounted) {
        showSnackBarAbove(context, 'Custom field added');
      }
    } catch (e) {
      if (mounted) {
        showSnackBarAbove(
          context,
          e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Failed to add field: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _deleteCustomField(String fieldKey) async {
    try {
      await LeadConfigurationService.deleteField(fieldKey);
      await _loadData();
      if (mounted) {
        showSnackBarAbove(context, 'Field deleted');
      }
    } catch (e) {
      if (mounted) {
        showSnackBarAbove(
          context,
          e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Failed to delete: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _updateDropdownOptions(String fieldKey, List<String> options) async {
    try {
      await LeadConfigurationService.updateFieldOptions(fieldKey, options);
      await _loadData();
      if (mounted) {
        showSnackBarAbove(context, 'Options updated');
      }
    } catch (e) {
      if (mounted) {
        showSnackBarAbove(
          context,
          e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Failed to update options: $e',
          isError: true,
        );
      }
    }
  }

  Widget _buildSettingsTab() {
    final fields = (_config?['leadFields'] as List<dynamic>?) ?? [];
    final alwaysMandatory = {'name', 'status', 'source', 'assigned', 'countryCode', 'mobile'};
    return _SettingsConfigurationContent(
      fields: fields,
      alwaysMandatory: alwaysMandatory,
      onToggleDisplay: _toggleFieldDisplay,
      onToggleMandatory: _toggleFieldMandatory,
      onAddCustomField: _addCustomField,
      onDeleteCustomField: _deleteCustomField,
      onUpdateDropdownOptions: _updateDropdownOptions,
    );
  }

  Future<void> _testWebhook() async {
    try {
      await LeadConfigurationService.testWebhook();
      if (mounted) {
        showSnackBarAbove(context, 'Webhook test successful');
      }
    } catch (e) {
      if (mounted) {
        showSnackBarAbove(
          context,
          e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Webhook test failed: $e',
          isError: true,
        );
      }
    }
  }

  Widget _buildWebhookTab() {
    return _sectionCard(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: WebhookForm(
          initialConfig: _config?['webhook'],
          onSave: _saveWebhook,
          onTest: _testWebhook,
        ),
      ),
    );
  }

  Widget _buildQuickReplyTab() {
    return _sectionCard(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: QuickReplyTable(
          quickReplies: _quickReplies,
          onAdd: _showQuickReplyModal,
          onEdit: _showQuickReplyModal,
          onDelete: _deleteQuickReply,
        ),
      ),
    );
  }

  Widget _buildFacebookSyncTab() {
    return _sectionCard(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FacebookConnectCard(
              onConnect: _connectFacebook,
              isLoading: _isFacebookLoading,
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: AppColors.primary))
            else ...[
              Text(
                'Connected Pages',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    'No Facebook pages connected yet.\nConnect your account to start syncing leads.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.45),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Settings tab: sub-tabs "Lead Field Configuration" and "Dropdown Field Configuration" (matches web).
class _SettingsConfigurationContent extends StatefulWidget {
  final List<dynamic> fields;
  final Set<String> alwaysMandatory;
  final Future<void> Function(String fieldKey, bool newValue) onToggleDisplay;
  final Future<void> Function(String fieldKey, bool newValue) onToggleMandatory;
  final Future<void> Function(String fieldName, String fieldType) onAddCustomField;
  final Future<void> Function(String fieldKey) onDeleteCustomField;
  final Future<void> Function(String fieldKey, List<String> options) onUpdateDropdownOptions;

  const _SettingsConfigurationContent({
    required this.fields,
    required this.alwaysMandatory,
    required this.onToggleDisplay,
    required this.onToggleMandatory,
    required this.onAddCustomField,
    required this.onDeleteCustomField,
    required this.onUpdateDropdownOptions,
  });

  @override
  State<_SettingsConfigurationContent> createState() =>
      _SettingsConfigurationContentState();
}

class _SettingsConfigurationContentState
    extends State<_SettingsConfigurationContent>
    with SingleTickerProviderStateMixin {
  late TabController _settingsSubTabController;

  @override
  void initState() {
    super.initState();
    _settingsSubTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _settingsSubTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        elevation: 0,
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.outline.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Settings Configuration',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _settingsSubTabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: cs.onSurfaceVariant,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(text: 'Lead Field Configuration'),
                Tab(text: 'Dropdown Field Configuration'),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: TabBarView(
                controller: _settingsSubTabController,
                children: [
                  _SettingsTabContent(
                    fields: widget.fields,
                    alwaysMandatory: widget.alwaysMandatory,
                    onToggleDisplay: widget.onToggleDisplay,
                    onToggleMandatory: widget.onToggleMandatory,
                    onAddCustomField: widget.onAddCustomField,
                    onDeleteCustomField: widget.onDeleteCustomField,
                  ),
                  _DropdownFieldConfigContent(
                    fields: widget.fields,
                    onUpdateDropdownOptions: widget.onUpdateDropdownOptions,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Display label for field type (match web: Input, Select, Textarea).
String _fieldTypeLabel(String type) {
  switch (type.toString().toLowerCase()) {
    case 'input':
      return 'Input';
    case 'select':
      return 'Select';
    case 'textarea':
      return 'Textarea';
    case 'number':
      return 'Number';
    default:
      return type.isEmpty ? 'Input' : (type[0].toUpperCase() + type.substring(1).toLowerCase());
  }
}

/// Lead Field Configuration sub-tab (table + add custom field).
class _SettingsTabContent extends StatefulWidget {
  final List<dynamic> fields;
  final Set<String> alwaysMandatory;
  final Future<void> Function(String fieldKey, bool newValue) onToggleDisplay;
  final Future<void> Function(String fieldKey, bool newValue) onToggleMandatory;
  final Future<void> Function(String fieldName, String fieldType) onAddCustomField;
  final Future<void> Function(String fieldKey) onDeleteCustomField;

  const _SettingsTabContent({
    required this.fields,
    required this.alwaysMandatory,
    required this.onToggleDisplay,
    required this.onToggleMandatory,
    required this.onAddCustomField,
    required this.onDeleteCustomField,
  });

  @override
  State<_SettingsTabContent> createState() => _SettingsTabContentState();
}

class _SettingsTabContentState extends State<_SettingsTabContent> {
  final _customNameController = TextEditingController();
  final _searchController = TextEditingController();
  String _customType = 'input';
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchText = _searchController.text);
    });
  }

  @override
  void dispose() {
    _customNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredFields {
    if (_searchText.trim().isEmpty) return widget.fields;
    final q = _searchText.trim().toLowerCase();
    return widget.fields
        .where((f) =>
            (f['fieldName'] ?? '').toString().toLowerCase().contains(q) ||
            (f['fieldKey'] ?? '').toString().toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final fields = _filteredFields;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Lead Fields Configuration',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search fields...',
            prefixIcon: Icon(Icons.search_rounded, size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 400;
            final fieldRow = [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _customNameController,
                  decoration: InputDecoration(
                    hintText: 'Enter custom field name',
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _customType,
                  decoration: InputDecoration(
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'input', child: Text('Input')),
                    DropdownMenuItem(value: 'textarea', child: Text('Text Area')),
                    DropdownMenuItem(value: 'select', child: Text('Dropdown')),
                  ],
                  onChanged: (v) => setState(() => _customType = v ?? 'input'),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  final name = _customNameController.text.trim();
                  if (name.isEmpty) return;
                  widget.onAddCustomField(name, _customType);
                  _customNameController.clear();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Add Field'),
              ),
            ];
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _customNameController,
                    decoration: InputDecoration(
                      hintText: 'Custom field name',
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _customType,
                          decoration: InputDecoration(
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'input', child: Text('Input')),
                            DropdownMenuItem(value: 'textarea', child: Text('Text Area')),
                            DropdownMenuItem(value: 'select', child: Text('Dropdown')),
                          ],
                          onChanged: (v) => setState(() => _customType = v ?? 'input'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          final name = _customNameController.text.trim();
                          if (name.isEmpty) return;
                          widget.onAddCustomField(name, _customType);
                          _customNameController.clear();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Add Field'),
                      ),
                    ],
                  ),
                ],
              );
            }
            return Row(children: fieldRow);
          },
        ),
        const SizedBox(height: 20),
        if (widget.fields.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No lead fields configured. Add a custom field above.'),
            ),
          )
        else if (fields.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No fields match your search.'),
            ),
          )
        else if (isNarrow)
          ...fields.map((field) {
            final key = (field['fieldKey'] ?? '') as String;
            final name = (field['fieldName'] ?? key) as String;
            final type = (field['fieldType'] ?? 'input') as String;
            final display = field['displayInTable'] ?? true;
            final mandatory = field['mandatory'] ?? false;
            final isCustom = key.startsWith('custom_');
            final isAlwaysMandatory = widget.alwaysMandatory.contains(key);
            final isTags = key == 'tags';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${_fieldTypeLabel(type)} • ${mandatory ? 'Mandatory' : 'Optional'}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Display in Table: ', style: TextStyle(fontSize: 13, color: cs.onSurface)),
                        Switch(
                          value: display,
                          onChanged: isAlwaysMandatory
                              ? null
                              : (v) => widget.onToggleDisplay(key, v),
                          activeTrackColor: AppColors.primary,
                          activeColor: cs.onPrimary,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text('Mandatory: ', style: TextStyle(fontSize: 13, color: cs.onSurface)),
                        Switch(
                          value: isTags ? false : (mandatory || isAlwaysMandatory),
                          onChanged: (isTags || isAlwaysMandatory || !display)
                              ? null
                              : (v) => widget.onToggleMandatory(key, v),
                          activeTrackColor: AppColors.primary,
                          activeColor: cs.onPrimary,
                        ),
                      ],
                    ),
                    if (isCustom)
                      TextButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Field'),
                              content: Text(
                                  'Delete custom field "$name"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            widget.onDeleteCustomField(key);
                          }
                        },
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
            );
          })
        else
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border.all(color: cs.outline.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(cs.surfaceContainerHighest),
                columns: [
                  DataColumn(label: Text('S.No.', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface))),
                  DataColumn(label: Text('Field Name', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface))),
                  DataColumn(label: Text('Field Type', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface))),
                  DataColumn(label: Text('Display in Table', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface))),
                  DataColumn(label: Text('Mandatory', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface))),
                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface))),
                ],
                rows: fields.asMap().entries.map((entry) {
                  final index = entry.key;
                  final field = entry.value as Map<String, dynamic>;
                  final key = (field['fieldKey'] ?? '') as String;
                  final name = (field['fieldName'] ?? key) as String;
                  final type = (field['fieldType'] ?? 'input') as String;
                  final display = field['displayInTable'] ?? true;
                  final mandatory = field['mandatory'] ?? false;
                  final isCustom = key.startsWith('custom_');
                  final isAlwaysMandatory = widget.alwaysMandatory.contains(key);
                  final isTags = key == 'tags';
                  return DataRow(
                    cells: [
                      DataCell(Text('${index + 1}')),
                      DataCell(Text(name)),
                      DataCell(Text(_fieldTypeLabel(type))),
                      DataCell(
                        Switch(
                          value: display,
                          onChanged: isAlwaysMandatory
                              ? null
                              : (v) => widget.onToggleDisplay(key, v),
                          activeTrackColor: AppColors.primary,
                          activeColor: cs.onPrimary,
                        ),
                      ),
                      DataCell(
                        Switch(
                          value: isTags ? false : (mandatory || isAlwaysMandatory),
                          onChanged: (isTags || isAlwaysMandatory || !display)
                              ? null
                              : (v) => widget.onToggleMandatory(key, v),
                          activeTrackColor: AppColors.primary,
                          activeColor: cs.onPrimary,
                        ),
                      ),
                      DataCell(
                        isCustom
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Field'),
                                      content: Text('Delete custom field "$name"?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    widget.onDeleteCustomField(key);
                                  }
                                },
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

/// Dropdown Field Configuration sub-tab: list dropdown fields, manage options.
class _DropdownFieldConfigContent extends StatefulWidget {
  final List<dynamic> fields;
  final Future<void> Function(String fieldKey, List<String> options) onUpdateDropdownOptions;

  const _DropdownFieldConfigContent({
    required this.fields,
    required this.onUpdateDropdownOptions,
  });

  @override
  State<_DropdownFieldConfigContent> createState() =>
      _DropdownFieldConfigContentState();
}

class _DropdownFieldConfigContentState extends State<_DropdownFieldConfigContent> {
  String? _selectedFieldKey;
  final _newOptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dropdownFields = widget.fields
          .where((f) => (f['fieldType'] ?? '') == 'select')
          .toList();
      if (dropdownFields.isNotEmpty && _selectedFieldKey == null) {
        final firstKey = dropdownFields.first['fieldKey'] as String?;
        if (firstKey != null) {
          setState(() => _selectedFieldKey = firstKey);
        }
      }
    });
  }

  @override
  void dispose() {
    _newOptionController.dispose();
    super.dispose();
  }

  /// Icon for dropdown field (match web: Source = people, Product = box).
  static IconData _iconForDropdownField(String fieldKey) {
    switch (fieldKey.toLowerCase()) {
      case 'source':
        return Icons.people_outline;
      case 'product':
        return Icons.inventory_2_outlined;
      case 'status':
        return Icons.flag_outlined;
      case 'company':
        return Icons.business_outlined;
      default:
        return Icons.list;
    }
  }

  List<Map<String, dynamic>> get _dropdownFields {
    return widget.fields
        .where((f) => (f['fieldType'] ?? '') == 'select')
        .map((f) => f as Map<String, dynamic>)
        .toList();
  }

  Map<String, dynamic>? get _selectedField {
    if (_selectedFieldKey == null) return null;
    for (final f in widget.fields) {
      if (f['fieldKey'] == _selectedFieldKey) return f as Map<String, dynamic>;
    }
    return null;
  }

  List<String> get _selectedOptions {
    final opts = _selectedField?['options'];
    if (opts is List) {
      return opts.map((e) => e.toString()).toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final dropdownFields = _dropdownFields;
    final selected = _selectedField;
    final options = _selectedOptions;
    final isNarrow = MediaQuery.of(context).size.width < 600;

    if (dropdownFields.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No dropdown fields. Add a field with type "Dropdown" in Lead Field Configuration.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (isNarrow) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Dropdown Fields',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...dropdownFields.map((f) {
            final key = (f['fieldKey'] ?? '') as String;
            final name = (f['fieldName'] ?? key) as String;
            final opts = f['options'] is List ? (f['options'] as List).length : 0;
            final isSelected = _selectedFieldKey == key;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isSelected ? AppColors.primary.withOpacity(0.08) : null,
              child: ListTile(
                leading: Icon(
                  _iconForDropdownField(key),
                  color: isSelected ? AppColors.primary : Colors.grey,
                ),
                title: Text(name),
                trailing: Chip(
                  label: Text('$opts'),
                  backgroundColor: isSelected ? AppColors.primary : Colors.grey[300],
                ),
                onTap: () => setState(() => _selectedFieldKey = key),
              ),
            );
          }),
          if (selected != null) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(_iconForDropdownField(_selectedFieldKey!), color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  '${selected['fieldName'] ?? ''} Options',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newOptionController,
                    decoration: InputDecoration(
                      hintText: 'Add new ${(selected['fieldName'] ?? '').toString().toLowerCase()} option',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    final v = _newOptionController.text.trim();
                    if (v.isEmpty) return;
                    final newOpts = [...options, v];
                    widget.onUpdateDropdownOptions(
                      _selectedFieldKey!,
                      newOpts,
                    );
                    _newOptionController.clear();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Option'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Available Options (${options.length})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (options.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text(
                        'No options added yet',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add your first option using the input above',
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...options.map((opt) => ListTile(
                    leading: Icon(Icons.circle, size: 8, color: AppColors.primary),
                    title: Text(opt),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        final newOpts = options.where((o) => o != opt).toList();
                        widget.onUpdateDropdownOptions(
                          _selectedFieldKey!,
                          newOpts,
                        );
                      },
                    ),
                  )),
          ],
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dropdown Fields',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 12),
                  ...dropdownFields.map((f) {
                    final key = (f['fieldKey'] ?? '') as String;
                    final name = (f['fieldName'] ?? key) as String;
                    final opts = f['options'] is List ? (f['options'] as List).length : 0;
                    final isSelected = _selectedFieldKey == key;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        _iconForDropdownField(key),
                        size: 20,
                        color: isSelected ? AppColors.primary : Colors.grey,
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : null,
                          color: isSelected ? AppColors.primary : null,
                        ),
                      ),
                      trailing: Chip(
                        label: Text('$opts', style: const TextStyle(fontSize: 12)),
                        backgroundColor: isSelected ? AppColors.primary : Colors.grey[300],
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onTap: () => setState(() => _selectedFieldKey = key),
                    );
                  }),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: selected == null
              ? const Card(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Select a dropdown field to manage options.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                )
              : Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _iconForDropdownField(_selectedFieldKey!),
                              color: AppColors.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${selected['fieldName'] ?? ''} Options',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newOptionController,
                                decoration: InputDecoration(
                                  hintText:
                                      'Add new ${(selected['fieldName'] ?? '').toString().toLowerCase()} option',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                final v = _newOptionController.text.trim();
                                if (v.isEmpty) return;
                                final newOpts = [...options, v];
                                widget.onUpdateDropdownOptions(
                                  _selectedFieldKey!,
                                  newOpts,
                                );
                                _newOptionController.clear();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Option'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Available Options (${options.length})',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        if (options.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inbox_outlined, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No options added yet',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Add your first option using the input above',
                                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...options.map((opt) => ListTile(
                                dense: true,
                                leading: Icon(Icons.circle, size: 8, color: AppColors.primary),
                                title: Text(opt),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () {
                                    final newOpts = options.where((o) => o != opt).toList();
                                    widget.onUpdateDropdownOptions(
                                      _selectedFieldKey!,
                                      newOpts,
                                    );
                                  },
                                ),
                              )),
                      ],
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
