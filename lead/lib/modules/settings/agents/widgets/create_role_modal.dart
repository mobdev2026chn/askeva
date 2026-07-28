import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';
import '../../../../services/agents_service.dart';

class CreateRoleModal extends StatefulWidget {
  final Map<String, dynamic>? role;
  final VoidCallback onSuccess;

  const CreateRoleModal({super.key, this.role, required this.onSuccess});

  @override
  State<CreateRoleModal> createState() => _CreateRoleModalState();
}

class _CreateRoleModalState extends State<CreateRoleModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _isLoading = false;

  // Matching backend displayNames
  final Map<String, List<String>> _permissionBlueprint = {
    'dashboard': ["Full Access"],
    'chat': [
      "Live chat - Global Access",
      "Live Chat - Self Assigned",
      "History - Global Access",
      "History - Self Assigned",
    ],
    'leadsMain': ["Full Access", "View Only Access"],
    'leadsConfigurations': ["Full Access", "View Only Access"],
    'agentSetting': ["Full Access", "View Only Access"],
    'appointmentsDashboard': ["Full Access"],
    'bookings': ["Full Access", "Self Assigned", "View Only Access"],
    'contacts': ["Full access", "View Only", "Create and View"],
    // Add more as needed, keeping it concise for UI
    'billing': ["Full Access"],
    'apiSettings': ["Full Access", "View Only Access"],
  };

  final Map<String, String> _moduleRef = {
    'dashboard': 'Dashboard',
    'chat': 'Chat',
    'leadsMain': 'Leads',
    'leadsConfigurations': 'Lead Config',
    'agentSetting': 'Agent Settings',
    'appointmentsDashboard': 'Appt Dashboard',
    'bookings': 'Bookings',
    'contacts': 'Contacts',
    'billing': 'Billing',
    'apiSettings': 'API Settings',
  };

  // Stores selection: module -> permissionKey (camelCase) -> bool
  Map<String, Map<String, bool>> _selectedPermissions = {};

  @override
  void initState() {
    super.initState();
    _initPermissionsState();
    if (widget.role != null) {
      _initEditMode();
    }
  }

  void _initPermissionsState() {
    _permissionBlueprint.forEach((module, perms) {
      _selectedPermissions[module] = {};
      for (var p in perms) {
        _selectedPermissions[module]![_toCamelCase(p)] = false;
      }
    });
  }

  String _toCamelCase(String str) {
    // Basic implementation matching backend usually
    // "Live chat - Global Access" -> "liveChatGlobalAccess"
    return str
        .toLowerCase()
        .replaceAllMapped(
          RegExp(r'[^a-z0-9]+(.)'),
          (match) => match.group(1)!.toUpperCase(),
        )
        .replaceAllMapped(
          RegExp(r'^[A-Z]'),
          (match) => match.group(0)!.toLowerCase(),
        );
  }

  void _initEditMode() {
    final r = widget.role!;
    _nameCtrl.text = r['role_name'] ?? '';
    _descCtrl.text = r['description'] ?? '';

    // Load existing permissions
    final existing = r['permissions'];
    if (existing is Map) {
      existing.forEach((module, pMap) {
        if (_selectedPermissions.containsKey(module) && pMap is Map) {
          pMap.forEach((key, val) {
            // key is permKey (camelCase)
            if (_selectedPermissions[module]!.containsKey(key)) {
              _selectedPermissions[module]![key] = val == true;
            }
          });
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      'role_name': _nameCtrl.text,
      'description': _descCtrl.text,
      'permissions': _selectedPermissions,
      'active': true, // Default active on create
    };

    try {
      if (widget.role == null) {
        await AgentsService.createRole(data);
      } else {
        data['active'] =
            widget.role!['active'] ?? true; // Preserve active state
        await AgentsService.updateRole(
          widget.role!['_id'] ?? widget.role!['id'],
          data,
        );
      }

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 650,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.role == null
                        ? Icons.security_outlined
                        : Icons.admin_panel_settings_outlined,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.role == null
                        ? 'Define New Access Role'
                        : 'Modify Role Permissions',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: _nameCtrl,
                        label: 'Role Name (e.g. Senior Agent)',
                        icon: Icons.label_important_outline,
                        validator: (v) =>
                            v!.isEmpty ? 'Role name is required' : null,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _descCtrl,
                        label: 'Description of Responsibilities',
                        icon: Icons.description_outlined,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 32),

                      Row(
                        children: [
                          Icon(
                            Icons.lock_open_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Permission Matrix',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      ..._permissionBlueprint.entries.map((entry) {
                        final module = entry.key;
                        final perms = entry.value;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              leading: Icon(
                                Icons.apps_outlined,
                                color: Colors.green.shade600,
                                size: 20,
                              ),
                              title: Text(
                                _moduleRef[module] ?? module,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              expandedAlignment: Alignment.topLeft,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: perms.map((permDisplay) {
                                    final permKey = _toCamelCase(permDisplay);
                                    final isChecked =
                                        _selectedPermissions[module]?[permKey] ??
                                        false;

                                    return ChoiceChip(
                                      label: Text(permDisplay),
                                      selected: isChecked,
                                      onSelected: (val) => setState(
                                        () =>
                                            _selectedPermissions[module]![permKey] =
                                                val,
                                      ),
                                      selectedColor: Colors.green.shade100,
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: isChecked
                                              ? Colors.green.shade300
                                              : Colors.grey.shade300,
                                        ),
                                      ),
                                      labelStyle: TextStyle(
                                        color: isChecked
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontWeight: isChecked
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Cancel Request',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              widget.role == null
                                  ? 'Initialize Role'
                                  : 'Confirm Updates',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: 20),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.green.shade400, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(fontSize: 14),
      ),
    );
  }
}
