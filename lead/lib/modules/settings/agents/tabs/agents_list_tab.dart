import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';
import '../../../../services/agents_service.dart';
import '../widgets/create_agent_modal.dart';
import '../widgets/change_password_modal.dart';

class AgentsListTab extends StatefulWidget {
  const AgentsListTab({super.key});

  @override
  State<AgentsListTab> createState() => _AgentsListTabState();
}

class _AgentsListTabState extends State<AgentsListTab> {
  bool _isLoading = false;
  List<dynamic> _agents = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final agents = await AgentsService.getAgents();
      if (mounted) {
        setState(() {
          _agents = agents;
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

  Future<void> _toggleStatus(String id, bool active) async {
    try {
      await AgentsService.toggleAgentStatus(id, active);
      _loadAgents(); // Reload to confirm state
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAgent(Map<String, dynamic> agent) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          'Are you sure you want to delete agent "${agent['name']}"?',
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
        await AgentsService.deleteAgent(agent['_id'] ?? agent['id']);
        _loadAgents();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Agent deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showCreateEditModal({Map<String, dynamic>? agent}) {
    showDialog(
      context: context,
      builder: (context) => CreateAgentModal(
        agent: agent,
        onSuccess: () {
          _loadAgents(); // Refresh list on success
        },
      ),
    );
  }

  void _showChangePasswordModal(Map<String, dynamic> agent) {
    showDialog(
      context: context,
      builder: (context) => ChangePasswordModal(email: agent['email'] ?? ''),
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
            ElevatedButton(onPressed: _loadAgents, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Team Members',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateEditModal(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Add Member',
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
            ],
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
                      'Name',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Email',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Mobile',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Role',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Type',
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
                rows: _agents
                    .asMap()
                    .entries
                    .map((entry) {
                      final index = entry.key;
                      final agent = entry.value;
                      final isActive = agent['active'] == true;

                      return DataRow(
                        cells: [
                          DataCell(Text('${index + 1}')),
                          DataCell(
                            Text(agent['username'] ?? agent['name'] ?? ''),
                          ),
                          DataCell(Text(agent['email'] ?? '')),
                          DataCell(Text(agent['mobilenumber'] ?? '')),
                          DataCell(Text(agent['role'] ?? '')), // Role name
                          DataCell(
                            _buildTypeBadges(agent['agentType']),
                          ), // Assuming 'agentType' is a map from backend
                          DataCell(
                            Center(
                              child: Switch(
                                value: isActive,
                                activeColor: Colors.green,
                                onChanged: (val) => _toggleStatus(
                                  agent['_id'] ?? agent['id'],
                                  val,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit')
                                  _showCreateEditModal(agent: agent);
                                if (value == 'password')
                                  _showChangePasswordModal(agent);
                                if (value == 'delete') _deleteAgent(agent);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'password',
                                  child: Row(
                                    children: [
                                      Icon(Icons.lock, size: 20),
                                      SizedBox(width: 8),
                                      Text('Change Password'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              icon: const Icon(Icons.more_vert),
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

  Widget _buildTypeBadges(dynamic typeData) {
    List<String> activeTypes = [];
    if (typeData is Map) {
      if (typeData['chatAgent'] == true) activeTypes.add('Chat');
      if (typeData['leads'] == true) activeTypes.add('Leads');
      if (typeData['appointment'] == true) activeTypes.add('Appt');
      if (typeData['ticketing'] == true) activeTypes.add('Tickets');
    } else if (typeData is List) {
      activeTypes = typeData.map((e) => e.toString()).toList();
    } else if (typeData is String) {
      activeTypes = [typeData];
    }

    if (activeTypes.isEmpty)
      return const Text('-', style: TextStyle(color: Colors.grey));

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: activeTypes
          .map(
            (t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                t,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
