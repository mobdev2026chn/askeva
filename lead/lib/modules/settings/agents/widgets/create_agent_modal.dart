import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';
import '../../../../services/agents_service.dart';

class CreateAgentModal extends StatefulWidget {
  final Map<String, dynamic>? agent; // Null for create
  final VoidCallback onSuccess;

  const CreateAgentModal({super.key, this.agent, required this.onSuccess});

  @override
  State<CreateAgentModal> createState() => _CreateAgentModalState();
}

class _CreateAgentModalState extends State<CreateAgentModal> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();

  String? _selectedRole;
  List<String> _roles = []; // Populated from API

  final Map<String, bool> _types = {
    'Chat Agent': false,
    'Appointment': false,
    'Leads': false,
    'Ticketing': false,
  };

  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchRoles();
    if (widget.agent != null) {
      _initEditMode();
    }
  }

  Future<void> _fetchRoles() async {
    try {
      final rolesData = await AgentsService.getRoles();
      // Inspect structure, usually roles list has 'role_name'
      final roleNames = rolesData
          .map<String>((r) => r['role_name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      // Add default reserved roles if not present (backend check handles reserved, but useful for creation)
      // Actually backend roles API should return created roles.
      // Standard roles 'admin', 'agent' might not be in the custom list if they are hardcoded system roles.
      // I'll add 'Agent' and 'Super Agent' as defaults if list is empty?
      // No, better to trust the API.

      if (mounted) {
        setState(() {
          _roles = roleNames;
          // Ensure selected role exists in list for edit mode
          if (_selectedRole != null && !_roles.contains(_selectedRole)) {
            _roles.add(_selectedRole!);
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() {});
    }
  }

  void _initEditMode() {
    final a = widget.agent!;
    _nameCtrl.text = a['name'] ?? a['username'] ?? '';
    _emailCtrl.text = a['email'] ?? '';
    _mobileCtrl.text = a['mobilenumber'] ?? '';
    _selectedRole = a['role'];
    _isActive = a['active'] ?? true;

    // Init types from agentType Map
    final t = a['agentType'];
    if (t is Map) {
      if (t['chatAgent'] == true) _types['Chat Agent'] = true;
      if (t['appointment'] == true) _types['Appointment'] = true;
      if (t['leads'] == true) _types['Leads'] = true;
      if (t['ticketing'] == true) _types['Ticketing'] = true;
    } else if (t is List) {
      // Fallback for list if any
      for (var type in t) {
        if (_types.containsKey(type)) {
          _types[type] = true;
        }
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a role')));
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'name': _nameCtrl.text,
      'email': _emailCtrl.text,
      'mobilenumber': _mobileCtrl.text,
      'role': _selectedRole,
      'isActive':
          _isActive, // Flutter side for local state, service might transform
      'active': _isActive, // Backend property
      'agentType': {
        'chatAgent': _types['Chat Agent'] ?? false,
        'appointment': _types['Appointment'] ?? false,
        'leads': _types['Leads'] ?? false,
        'ticketing': _types['Ticketing'] ?? false,
      },
    };

    try {
      if (widget.agent == null) {
        // Create (also needs password usually! I forgot password field for creation)
        // I should add a password field for creation only.
        if (_passwordCtrl.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password is required for new agents'),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
        data['password'] = _passwordCtrl.text;
        await AgentsService.createAgent(data);
      } else {
        // Edit (ID required)
        data['id'] =
            widget.agent!['_id'] ??
            widget.agent!['id']; // Match backend expectation
        await AgentsService.updateAgent(data);
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

  final _passwordCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
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
                    widget.agent == null
                        ? Icons.person_add_outlined
                        : Icons.edit_note_outlined,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.agent == null
                        ? 'Create New Agent'
                        : 'Edit Agent Profile',
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

            // Content
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
                        label: 'Full Name',
                        icon: Icons.person_outline,
                        validator: (v) =>
                            v!.isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _emailCtrl,
                        label: 'Email Address',
                        icon: Icons.alternate_email,
                        readOnly: widget.agent != null,
                        validator: (v) =>
                            v!.isEmpty ? 'Email is required' : null,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      if (widget.agent == null) ...[
                        _buildTextField(
                          controller: _passwordCtrl,
                          label: 'Security Password',
                          icon: Icons.key_outlined,
                          obscureText: true,
                          validator: (v) => (v == null || v.length < 6)
                              ? 'Min 6 characters'
                              : null,
                        ),
                        const SizedBox(height: 20),
                      ],
                      _buildTextField(
                        controller: _mobileCtrl,
                        label: 'Primary mobile',
                        icon: Icons.phone_android_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 20),

                      // Role Autocomplete
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return RawAutocomplete<String>(
                            initialValue: TextEditingValue(
                              text: _selectedRole ?? '',
                            ),
                            optionsBuilder:
                                (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty)
                                    return _roles;
                                  return _roles.where(
                                    (s) => s.toLowerCase().contains(
                                      textEditingValue.text.toLowerCase(),
                                    ),
                                  );
                                },
                            onSelected: (s) =>
                                setState(() => _selectedRole = s),
                            fieldViewBuilder: (ctx, ctrl, node, onSub) {
                              return TextFormField(
                                controller: ctrl,
                                focusNode: node,
                                decoration: InputDecoration(
                                  labelText: 'Functional Role',
                                  prefixIcon: const Icon(
                                    Icons.verified_user_outlined,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  suffixIcon: const Icon(Icons.expand_more),
                                  filled: true,
                                  fillColor: Colors.green.shade50.withOpacity(
                                    0.3,
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty)
                                    return 'Role selection required';
                                  if (!_roles.contains(val))
                                    return 'Please select valid role from list';
                                  return null;
                                },
                                onChanged: (val) {
                                  if (val.isEmpty)
                                    setState(() => _selectedRole = null);
                                  else if (_roles.contains(val))
                                    setState(() => _selectedRole = val);
                                  else if (_selectedRole != null)
                                    setState(() => _selectedRole = null);
                                },
                              );
                            },
                            optionsViewBuilder: (ctx, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(8),
                                  shadowColor: Colors.black26,
                                  child: Container(
                                    width: constraints.maxWidth,
                                    constraints: const BoxConstraints(
                                      maxHeight: 200,
                                    ),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (ctx, idx) {
                                        final opt = options.elementAt(idx);
                                        return ListTile(
                                          title: Text(
                                            opt,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                          onTap: () => onSelected(opt),
                                          dense: true,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Module Access Permissions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _types.keys.map((type) {
                          final isSel = _types[type]!;
                          return ChoiceChip(
                            label: Text(type),
                            selected: isSel,
                            onSelected: (v) => setState(() => _types[type] = v),
                            selectedColor: Colors.green.shade100,
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSel
                                    ? Colors.green.shade300
                                    : Colors.grey.shade300,
                              ),
                            ),
                            labelStyle: TextStyle(
                              color: isSel
                                  ? Colors.green.shade900
                                  : Colors.black54,
                              fontWeight: isSel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Active Status',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  _isActive ? 'Enabled' : 'Disabled',
                                  style: TextStyle(
                                    color: _isActive
                                        ? Colors.green
                                        : Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Switch(
                              value: _isActive,
                              activeColor: Colors.green,
                              onChanged: (v) => setState(() => _isActive = v),
                            ),
                          ],
                        ),
                      ),
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
                        'Discard',
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
                              widget.agent == null
                                  ? 'Create Agent'
                                  : 'Save Profile',
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
    bool readOnly = false,
    bool obscureText = false,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      obscureText: obscureText,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
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
        fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
        labelStyle: const TextStyle(fontSize: 14),
      ),
    );
  }
}
