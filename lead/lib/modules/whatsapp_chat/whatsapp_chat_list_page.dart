import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import 'whatsapp_chat_page.dart';
import 'package:intl/intl.dart';
import '../../services/socket_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/drawer_menu_icon.dart';

class WhatsAppChatListPage extends StatefulWidget {
  final Widget? drawer;
  const WhatsAppChatListPage({super.key, this.drawer});

  @override
  State<WhatsAppChatListPage> createState() => _WhatsAppChatListPageState();
}

class _WhatsAppChatListPageState extends State<WhatsAppChatListPage> {
  final ScrollController _listScrollController = ScrollController();
  List<dynamic> _chats = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all'; // all, unread, read, intervened, prospects
  String? _selectedAgentId;
  List<dynamic> _agents = [];

  @override
  void initState() {
    super.initState();
    _fetchChats();
    _initSocket();
  }

  void _initSocket() {
    SocketService().init();
    SocketService().onMessage((data) {
      if (mounted) {
        // Refresh the chat list to get updated last message, unread status, etc.
        _fetchChats();
      }
    });
  }

  Future<void> _fetchChats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await ChatService.getLiveChatRooms(
        filter: _selectedFilter,
        search: _searchQuery.isEmpty ? 'null' : _searchQuery,
        agentId: _selectedAgentId,
      );

      if (mounted) {
        setState(() {
          _chats = result['data'] ?? [];
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

  Future<void> _fetchAgents() async {
    try {
      final result = await ChatService.getActiveAgents();
      if (mounted) {
        setState(() {
          _agents = result['data'] ?? [];
        });
        print('Fetched ${_agents.length} agents');
      }
    } catch (e) {
      print('Error fetching agents: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load agents: ${e.toString()}')),
        );
      }
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption(Icons.list, 'All', 'all'),
            _buildFilterOption(Icons.mail_outline, 'Unread', 'unread'),
            _buildFilterOption(Icons.drafts_outlined, 'Read', 'read'),
            _buildFilterOption(
              Icons.chat_bubble_outline,
              'Intervened',
              'intervened',
            ),
            _buildFilterOption(
              Icons.business_center_outlined,
              'Prospects',
              'prospects',
            ),
            _buildFilterOption(
              Icons.people_outline,
              'Agents',
              'agents',
              isAgents: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(
    IconData icon,
    String label,
    String value, {
    bool isAgents = false,
  }) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pop(context);
        if (isAgents) {
          _showAgentSelectionDialog();
        } else {
          setState(() {
            _selectedFilter = value;
            _selectedAgentId = null;
          });
          _fetchChats();
        }
      },
    );
  }

  void _showAgentSelectionDialog() async {
    if (_agents.isEmpty) {
      await _fetchAgents();
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agents'),
        content: SizedBox(
          width: double.maxFinite,
          child: _agents.isEmpty
              ? const Center(child: Text('No agents available'))
              : DropdownButtonFormField<String>(
                  value: _selectedAgentId,
                  decoration: const InputDecoration(
                    labelText: 'Select an Agent',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  hint: const Text('Select an Agent'),
                  isExpanded: true,
                  items: [
                    // Add "All" option at the top
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        'All',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    // Add all agents
                    ..._agents.map<DropdownMenuItem<String>>((agent) {
                      return DropdownMenuItem<String>(
                        value: agent['_id'],
                        child: Text(
                          '${agent['username']} - ${agent['email']}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedAgentId = value;
                    });
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                if (_selectedAgentId == null) {
                  // "All" selected - clear agent filter
                  _selectedFilter = 'all';
                } else {
                  // Specific agent selected
                  _selectedFilter = 'agent';
                }
              });
              _fetchChats();
            },
            child: const Text('Apply Filter'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    SocketService().offMessage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      drawer: widget.drawer,
      appBar: AppBar(
        leading: const DrawerMenuIcon(),
        elevation: 0,
        centerTitle: true,
        title: const Text('Live Chat'),
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: TextField(
                      onChanged: (val) {
                        _searchQuery = val;
                        _fetchChats();
                      },
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 22,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        hintText: 'Search chat',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.filter_list, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  onPressed: _showFilterBottomSheet,
                ),
              ],
            ),
          ),
          // Filter Chips
          Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('All', 'all', count: _chats.length),
                _buildFilterChip('Unread', 'unread'),
                _buildFilterChip('Read', 'read'),
                _buildFilterChip('Intervened', 'intervened'),
                _buildFilterChip('Prospects', 'prospects'),
              ],
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: cs.outline.withOpacity(0.5)),
          Expanded(
            child: _isLoading
                ? RefreshIndicator(
                    onRefresh: _fetchChats,
                    color: const Color(0xFF1EA443),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: const Center(
                          child: CircularProgressIndicator(color: Color(0xFF1EA443)),
                        ),
                      ),
                    ),
                  )
                : _error != null
                    ? RefreshIndicator(
                        onRefresh: _fetchChats,
                        color: const Color(0xFF1EA443),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: Center(child: Text('Error: $_error')),
                          ),
                        ),
                      )
                    : _buildChatList(_chats),
          ),
        ],
      ),
    );
  }

  String _searchQuery = '';

  Widget _buildFilterChip(String label, String value, {int? count}) {
    final cs = Theme.of(context).colorScheme;
    final bool isSelected = _selectedFilter == value;
    final String displayLabel = count != null ? '$label ($count)' : label;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = value;
          });
          _fetchChats();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : cs.outline.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              displayLabel,
              style: TextStyle(
                color: isSelected ? AppColors.onPrimary : cs.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatList(List<dynamic> chats) {
    if (chats.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchChats,
        color: const Color(0xFF1EA443),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: const Center(child: Text('No chats found')),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchChats,
      color: const Color(0xFF1EA443),
      child: RawScrollbar(
        controller: _listScrollController,
        thumbVisibility: true,
        thickness: 10,
        radius: const Radius.circular(5),
        thumbColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
        trackColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
        trackRadius: const Radius.circular(5),
        child: ListView.separated(
          controller: _listScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: chats.length,
          separatorBuilder: (context, index) {
            final cs = Theme.of(context).colorScheme;
            return Divider(height: 1, thickness: 0.5, color: cs.outline.withOpacity(0.3));
          },
          itemBuilder: (context, index) {
            final cs = Theme.of(context).colorScheme;
            final room = chats[index];
            final contactNumber = room['contactNumber'] ?? '';
            final profileName = room['profileName'] ?? contactNumber;
            final lastTimeStr = room['lastMessageTime'];

            DateTime? lastTime;
            if (lastTimeStr != null) {
              lastTime = DateTime.tryParse(lastTimeStr);
            }

            return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: (room['lastMessageRead'] == false)
                      ? AppColors.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: _getAvatarColor(profileName),
                child: Text(
                  profileName.isNotEmpty ? profileName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    profileName,
                    style: TextStyle(
                      fontWeight: (room['lastMessageRead'] == false)
                          ? FontWeight.w800
                          : FontWeight.w600,
                      fontSize: 16,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (lastTime != null)
                  Text(
                    _formatTime(lastTime),
                    style: TextStyle(
                      color: (room['lastMessageRead'] == false)
                          ? AppColors.primary
                          : cs.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: (room['lastMessageRead'] == false)
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _getChatSummary(room),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight: (room['lastMessageRead'] == false)
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (room['lastMessageRead'] == false)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: const Color(0xFF1EA443),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WhatsAppChatPage(
                    contactNumber: contactNumber,
                    profileName: profileName,
                  ),
                ),
              );
            },
          );
        },
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFEF4444), // Red
      const Color(0xFF1EA443), // Green
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF6366F1), // Indigo
      const Color(0xFFEC4899), // Pink
      const Color(0xFF8B5CF6), // Violet
      const Color(0xFF06B6D4), // Cyan
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (now.year == time.year &&
        now.month == time.month &&
        now.day == time.day) {
      return DateFormat('jm').format(time);
    } else if (now.difference(time).inDays == 1) {
      return 'Yesterday';
    } else {
      return DateFormat('dd/MM/yy').format(time);
    }
  }

  String _getChatSummary(dynamic room) {
    final lastMsg = room['lastMessage'] ?? '';
    final type = room['lastMessageType'] ?? 'text';

    if (type == 'image') return '📷 Photo';
    if (type == 'video') return '🎥 Video';
    if (type == 'audio') return '🎤 Audio';
    if (type == 'document') return '📄 Document';
    if (type == 'interactive' || type == 'order_details') {
      return '🔘 Interactive Message';
    }

    return lastMsg;
  }
}

// Search delegate for chat search
class ChatSearchDelegate extends SearchDelegate<String> {
  final List<dynamic> chats;
  final Function(String contactNumber, String profileName) onChatSelected;

  ChatSearchDelegate({required this.chats, required this.onChatSelected});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = chats.where((chat) {
      final contactNumber =
          chat['contactNumber']?.toString().toLowerCase() ?? '';
      final profileName = chat['profileName']?.toString().toLowerCase() ?? '';
      final searchLower = query.toLowerCase();
      return contactNumber.contains(searchLower) ||
          profileName.contains(searchLower);
    }).toList();

    if (results.isEmpty) {
      return const Center(child: Text('No chats found'));
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (context, index) {
        final chat = results[index];
        final contactNumber = chat['contactNumber'] ?? '';
        final profileName = chat['profileName'] ?? contactNumber;

        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          title: Text(
            profileName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            contactNumber,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          onTap: () {
            close(context, '');
            onChatSelected(contactNumber, profileName);
          },
        );
      },
    );
  }
}
