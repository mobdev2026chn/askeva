import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';
import '../../../../services/agents_service.dart';
import '../widgets/create_role_modal.dart';

class RolesListTab extends StatefulWidget {
  const RolesListTab({super.key});

  @override
  State<RolesListTab> createState() => _RolesListTabState();
}

class _RolesListTabState extends State<RolesListTab> {
  bool _isLoading = false;
  List<dynamic> _roles = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final roles = await AgentsService.getRoles();
      if (mounted) {
        setState(() {
          _roles = roles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteRole(Map<String, dynamic> role) async {
    // Check usage ? Backend handles it and returns error "Found existing agent".
    // I will catch that error and show it.

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          'Are you sure you want to delete role "${role['role_name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AgentsService.deleteRole(role['_id'] ?? role['id']);
        _loadRoles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Role deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$e'),
              backgroundColor: Colors.red,
            ), // e already contains message
          );
        }
      }
    }
  }

  void _showCreateEditModal({Map<String, dynamic>? role}) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental close for complex form
      builder: (context) => CreateRoleModal(
        role: role,
        onSuccess: () {
          _loadRoles();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadRoles, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => _showCreateEditModal(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Create Role',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                minimumSize: const Size(140, 45),
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(
                    label: Text(
                      'S.No',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Role Name',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Description',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Permissions',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Actions',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: _roles
                    .asMap()
                    .entries
                    .map((entry) {
                      final index = entry.key;
                      final role = entry.value;

                      // Permissions count
                      int permCount = 0;
                      final perms = role['permissions'];
                      if (perms is Map) {
                        perms.forEach((key, val) {
                          if (val is Map) {
                            val.forEach((k, v) {
                              if (v == true) permCount++;
                            });
                          }
                        });
                      }

                      final isActive =
                          role['active'] == true ||
                          role['isActive'] == true; // Adjust key based on API

                      return DataRow(
                        cells: [
                          DataCell(Text('${index + 1}')),
                          DataCell(Text(role['role_name'] ?? '')),
                          DataCell(
                            Text(role['description'] ?? '-'),
                          ), // Description might not exist in backend model, check later
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$permCount permissions',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Center(
                              child: Switch(
                                value: isActive,
                                activeColor: Colors.green,
                                onChanged: (val) async {
                                  try {
                                    await AgentsService.updateRole(
                                      role['_id'] ?? role['id'],
                                      {'active': val}, // or 'isActive'
                                    );
                                    _loadRoles();
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Update failed: $e'),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () =>
                                      _showCreateEditModal(role: role),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteRole(role),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    })
                    .toList()
                    .cast<DataRow>(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
