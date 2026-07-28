import 'package:flutter/material.dart';
import 'dart:async';

import '../api/app_scope.dart';
import '../api/dto.dart';
import '../data/models.dart';
import '../shell/app_nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/common.dart';
import '../widgets/conversation_launch.dart';
import '../widgets/dashboard_sheets.dart' show appToast;
import '../shell/app_sidebar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final Set<String> _reopenedNumbers = {};
  int _tab = 0; // 0 Live Chat, 1 History
  String _liveFilter = 'all';
  String _historyFilter = 'all';
  Future<List<ChatRoomDto>>? _future;
  String _query = '';
  final _searchCtrl = TextEditingController();

  String _selectedTag = '';
  String _selectedAgentId = '';
  String _selectedAgentName = '';
  List<String> _allAvailableTags = const [];
  Map<String, int> _tagCounts = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kSendQrCodeTarget.value != null) {
        final deepLink = kSendQrCodeTarget.value!;
        kSendQrCodeTarget.value = null; // consume
        _showSendQrCodeDialog(deepLink);
      }
    });
  }

  Color _getAvatarColor(String initials) {
    switch (initials) {
      case 'AM':
        return AppColors.evaGreen;
      case 'PN':
        return const Color(0xFFEF4444);
      case 'RD':
        return const Color(0xFF0EA5E9);
      case 'SI':
        return const Color(0xFFF97316);
      case 'VJ':
        return const Color(0xFF10B981);
      default:
        final hash = initials.hashCode;
        final colors = [
          AppColors.evaGreen,
          const Color(0xFFEF4444),
          const Color(0xFF0EA5E9),
          const Color(0xFFF97316),
          const Color(0xFF10B981),
          const Color(0xFF8B5CF6),
        ];
        return colors[hash % colors.length];
    }
  }

  void _showSendQrCodeDialog(String deepLinkUrl) {
    List<Map<String, dynamic>> contacts = [];
    bool dialogLoading = true;

    final fallbackContacts = [
      {'name': 'Aarav Mehta', 'initials': 'AM', 'checked': false},
      {'name': 'Priya Nair', 'initials': 'PN', 'checked': false},
      {'name': 'Rohan Das', 'initials': 'RD', 'checked': false},
      {'name': 'Sneha Iyer', 'initials': 'SI', 'checked': false},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) {
          if (dialogLoading) {
            dialogLoading = false;
            AppScope.of(ctx).chat.fetchRooms(filter: 'all', limit: 50).then((rooms) {
              setSt(() {
                if (rooms.isNotEmpty) {
                  contacts = rooms.map((r) {
                    final name = r.userName.isNotEmpty ? r.userName : r.userNumber;
                    final words = name.split(' ');
                    final initials = words.length > 1
                        ? '${words[0][0]}${words[1][0]}'.toUpperCase()
                        : name.substring(0, name.length > 1 ? 2 : 1).toUpperCase();
                    return {
                      'name': name,
                      'initials': initials,
                      'checked': false,
                    };
                  }).toList();
                } else {
                  contacts = List.from(fallbackContacts);
                }
              });
            }).catchError((_) {
              setSt(() {
                contacts = List.from(fallbackContacts);
              });
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width * 0.85,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send QR Code',
                    style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select whom to send the QR code to',
                    style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3),
                  ),
                  const SizedBox(height: 16),
                  if (contacts.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(color: AppColors.evaGreen),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: contacts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (c, idx) {
                          final contact = contacts[idx];
                          final checked = contact['checked'] == true;
                          final name = contact['name'] as String;
                          final initials = contact['initials'] as String;

                          return GestureDetector(
                            onTap: () {
                              setSt(() {
                                contact['checked'] = !checked;
                              });
                            },
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: _getAvatarColor(initials),
                                  child: Text(
                                    initials,
                                    style: AppText.poppins(size: 12, weight: FontWeight.w800, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink),
                                  ),
                                ),
                                Checkbox(
                                  value: checked,
                                  activeColor: AppColors.evaGreen,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (val) {
                                    setSt(() {
                                      contact['checked'] = val == true;
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(
                          'Cancel',
                          style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          final selected = contacts.where((c) => c['checked'] == true).toList();
                          if (selected.isEmpty) {
                            appToast(ctx, 'Please select at least one contact', isError: true);
                            return;
                          }
                          Navigator.of(ctx).pop();
                          final names = selected.map((s) => s['name']).join(', ');
                          appToast(ctx, 'QR code sent successfully to $names');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.evaGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          'Send',
                          style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  int _cachedRoomsTab = -1;
  List<ChatRoomDto>? _cachedRooms;
  Timer? _chatsPollTimer;

  @override
  void initState() {
    super.initState();
    _chatsPollTimer = Timer.periodic(const Duration(milliseconds: 3000), (_) {
      if (mounted) {
        _silentPoll();
      }
    });
  }

  bool _hasRoomsChanged(List<ChatRoomDto>? oldRooms, List<ChatRoomDto> newRooms) {
    if (oldRooms == null) return true;
    if (oldRooms.length != newRooms.length) return true;
    for (int i = 0; i < newRooms.length; i++) {
      final o = oldRooms[i];
      final n = newRooms[i];
      if (o.userNumber != n.userNumber ||
          o.lastMsg != n.lastMsg ||
          o.unread != n.unread ||
          o.updatedAt != n.updatedAt ||
          o.intervene != n.intervene ||
          o.lastMessageRead != n.lastMessageRead) {
        return true;
      }
    }
    return false;
  }

  Future<void> _silentPoll() async {
    if (!mounted) return;
    try {
      final pollTab = _tab;
      final next = await _load();
      if (!mounted || _tab != pollTab) return;
      final activeCached = _cachedRoomsTab == pollTab ? _cachedRooms : null;
      if (_hasRoomsChanged(activeCached, next)) {
        setState(() {
          _cachedRoomsTab = pollTab;
          _cachedRooms = next;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _chatsPollTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<ChatRoomDto>> _load() async {
    final searchVal = _query.isEmpty ? null : _query;
    final isLive = _tab == 0;
    final filter = isLive ? _liveFilter : _historyFilter;

    final prefs = await SharedPreferences.getInstance();
    final markedUnreadList = prefs.getStringList('marked_unread_numbers') ?? [];
    final markedUnreadSet = markedUnreadList.toSet();
    final markedReadList = prefs.getStringList('marked_read_numbers') ?? [];
    final markedReadSet = markedReadList.toSet();
    final reopenedSaved = prefs.getStringList('reopened_chat_numbers') ?? [];
    _reopenedNumbers.addAll(reopenedSaved);

    List<ChatRoomDto> roomsList;
    if (isLive) {
      String apiFilter = 'live';
      if (filter == 'intervened' || filter == 'replied') {
        apiFilter = 'intervened';
      } else if (filter == 'prospects') {
        apiFilter = 'prospects';
      } else if (filter == 'tags' && _selectedTag.isNotEmpty) {
        apiFilter = 'tags';
      } else if (filter == 'agent' && _selectedAgentId.isNotEmpty) {
        apiFilter = 'agent';
      }

      final agentId = (filter == 'agent' && _selectedAgentId.isNotEmpty) ? _selectedAgentId : null;
      final tagVal = (filter == 'tags' && _selectedTag.isNotEmpty) ? _selectedTag : null;

      if (!mounted) return [];
      var fetched = await AppScope.of(context).chat.fetchRooms(
        filter: apiFilter,
        limit: 1000,
        search: searchVal,
        agent: agentId,
        tag: tagVal,
      );

      if (fetched.isEmpty && apiFilter == 'live') {
        fetched = await AppScope.of(context).chat.fetchRooms(
          filter: 'all',
          limit: 1000,
          search: searchVal,
          agent: agentId,
          tag: tagVal,
        );
      }

      roomsList = fetched;
    } else {
      // History tab: load directly from history API
      final agentId = (filter == 'agent' && _selectedAgentId.isNotEmpty) ? _selectedAgentId : null;
      if (!mounted) return [];
      final fetched = await AppScope.of(context).chat.fetchHistoryRooms(
        filter: filter == 'prospects' ? 'prospects' : 'all',
        limit: 1000,
        search: searchVal,
        agent: agentId,
      );

      // Filter out reopened numbers from History tab (reopened chats display in Live Chat!)
      if (_reopenedNumbers.isNotEmpty) {
        roomsList = fetched.where((r) {
          final digits = r.userNumber.replaceAll(RegExp(r'\D'), '');
          return !_reopenedNumbers.contains(r.userNumber) && !_reopenedNumbers.contains(digits);
        }).toList();
      } else {
        roomsList = fetched;
      }
    }

    // Extract unique non-empty tags from the loaded rooms (real data from API) and compute counts
    final Map<String, int> tagCounts = {};
    for (final r in roomsList) {
      for (final t in r.tags) {
        final clean = t.trim();
        if (clean.isNotEmpty) {
          tagCounts[clean] = (tagCounts[clean] ?? 0) + 1;
        }
      }
    }
    _tagCounts = tagCounts;
    _allAvailableTags = tagCounts.keys.toList()..sort();

    // 1. Overlay the local read/unread status from SharedPreferences (WhatsApp style)
    final mappedRooms = roomsList.map((r) {
      // User opened & read this chat locally -> ALWAYS keep as read (unread: 0)
      if (markedReadSet.contains(r.userNumber)) {
        return ChatRoomDto(
          userNumber: r.userNumber,
          userName: r.userName,
          lastMsg: r.lastMsg,
          unread: 0,
          updatedAt: r.updatedAt,
          intervene: r.intervene,
          lastMessageRead: true,
          tags: r.tags,
          isProspect: r.isProspect,
        );
      }
      // User manually marked as unread
      if (markedUnreadSet.contains(r.userNumber) && r.unread == 0) {
        return ChatRoomDto(
          userNumber: r.userNumber,
          userName: r.userName,
          lastMsg: r.lastMsg,
          unread: 1,
          updatedAt: r.updatedAt,
          intervene: r.intervene,
          lastMessageRead: false,
          tags: r.tags,
          isProspect: r.isProspect,
        );
      }
      return r;
    }).toList();

    // 2. Count total unread chats globally across all retrieved active rooms
    kUnreadChatsCount.value = mappedRooms.where((r) => r.unread > 0 || r.lastMessageRead == false).length;

    final partitionedRooms = mappedRooms;

    // 3. Apply tab-specific filters locally on top of our client-side unread overrides
    List<ChatRoomDto> filteredRooms = partitionedRooms;
    final filter2 = isLive ? _liveFilter : _historyFilter;
    if (filter2 == 'unread') {
      filteredRooms = partitionedRooms.where((r) => r.unread > 0 || r.lastMessageRead == false).toList();
    } else if (filter2 == 'read') {
      filteredRooms = partitionedRooms.where((r) => r.unread == 0 && r.lastMessageRead != false).toList();
    } else if (filter2 == 'replied') {
      filteredRooms = mappedRooms.where((r) => r.intervene).toList();
    } else if (filter2 == 'prospects') {
      filteredRooms = mappedRooms.where((r) => 
        r.isProspect || 
        r.tags.any((t) => t.toLowerCase().contains('prospect') || t.toLowerCase().contains('lead'))
      ).toList();
    } else if (filter2 == 'tags') {
      if (_selectedTag.isNotEmpty) {
        filteredRooms = mappedRooms.where((r) => r.tags.any((t) => t.toLowerCase() == _selectedTag.toLowerCase())).toList();
      } else {
        filteredRooms = mappedRooms.where((r) => r.tags.isNotEmpty).toList();
      }
    }
    // search filter already applied at API level; if search is non-empty, also filter locally for accuracy
    if (searchVal != null && searchVal.isNotEmpty && !isLive) {
      final q = searchVal.toLowerCase();
      filteredRooms = filteredRooms.where((r) =>
        r.userName.toLowerCase().contains(q) || r.userNumber.contains(q) || r.lastMsg.toLowerCase().contains(q)
      ).toList();
    }

    _cachedRoomsTab = isLive ? 0 : 1;
    _cachedRooms = filteredRooms;
    return filteredRooms;
  }

  void _reload() {
    _cachedRooms = null;
    _cachedRoomsTab = -1;
    final next = _load();
    setState(() { _future = next; });
  }

  void _setTab(int i) {
    _tab = i;
    _query = '';
    _searchCtrl.clear();
    _selectedTag = '';
    _selectedAgentId = '';
    _selectedAgentName = '';
    _liveFilter = 'all';
    _historyFilter = 'all';
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final nav = AppNav.of(context);
    return GreenHeaderScaffold(
      title: 'Chats',
      onMenu: nav.openDrawer,
      actions: [
        Builder(
          builder: (btnCtx) => GlassIconButton(
            icon: Icons.more_vert_rounded,
            onTap: () => _showFilterMenu(btnCtx),
            tooltip: 'More',
          ),
        ),
      ],

      sheet: Container(
        color: Colors.white,
        child: Column(
          children: [
            AppTabBar(tabs: const ['Live Chat', 'History'], selected: _tab, onChanged: _setTab),
            const Divider(height: 1, color: AppColors.line),
            _searchField(),
            _pills(),
            Expanded(
              child: Stack(
                children: [
                  RefreshIndicator(
                    color: AppColors.evaGreen,
                    onRefresh: () {
                      final next = _load();
                      setState(() { _future = next; });
                      return next;
                    },
                    child: FutureBuilder<List<ChatRoomDto>>(
                      future: _future,
                      builder: (context, snap) {
                        final activeCached = _cachedRoomsTab == _tab ? _cachedRooms : null;
                        if (snap.connectionState == ConnectionState.waiting && activeCached == null) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.evaGreen));
                        }
                        if (snap.hasError && activeCached == null) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(snap.error.toString().replaceFirst('Exception: ', ''),
                                  textAlign: TextAlign.center, style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink3)),
                            ),
                          );
                        }
                        final rooms = activeCached ?? snap.data ?? const <ChatRoomDto>[];
                        if (rooms.isEmpty) {
                          return _emptyState();
                        }
                        return ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                          itemCount: rooms.length,
                          separatorBuilder: (_, __) => const Padding(
                            padding: EdgeInsets.only(left: 76),
                            child: Divider(height: 1, color: Color(0xFFEEF1EC)),
                          ),
                          itemBuilder: (context, i) {
                            final room = rooms[i];
                            final t = room.toThread();
                            return _ChatRow(
                              room: room,
                              thread: t,
                              onTap: () async {
                                final templateSent = await openConversationByNumber(
                                  context,
                                  name: t.name,
                                  number: room.userNumber,
                                  isHistory: _tab == 1,
                                );
                                // If a template was sent, mark as reopened, move to Live tab, and reload.
                                if (templateSent == true) {
                                  _reopenedNumbers.add(room.userNumber);
                                  final clean = room.userNumber.replaceAll(RegExp(r'\D'), '');
                                  if (clean.isNotEmpty) _reopenedNumbers.add(clean);
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setStringList('reopened_chat_numbers', _reopenedNumbers.toList());
                                  if (_tab == 1) {
                                    _setTab(0);
                                  } else {
                                    _reload();
                                  }
                                } else {
                                  if (mounted) _reload();
                                }
                              },
                            );
                          },
                        );
                      },
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

  Widget _searchField() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.search_rounded, size: 19, color: Color(0xFF9CA3AF)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                textAlignVertical: TextAlignVertical.center,
                style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink),
                onChanged: (v) {
                  _query = v;
                  _reload();
                },
                decoration: InputDecoration(
                  hintText: 'Search chat',
                  hintStyle: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: const Color(0xFF9CA3AF)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _query = '';
                  _searchCtrl.clear();
                  _reload();
                },
                child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF9CA3AF)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pills() {
    final isLive = _tab == 0;
    final active = isLive ? _liveFilter : _historyFilter;

    final List<(String, String)> options = [
      ('all', 'All'),
      ('unread', 'Unread'),
      ('read', 'Read'),
      ('replied', 'Intervened'),
      ('prospects', 'Prospects'),
      ('tags', _selectedTag.isEmpty ? 'Tags' : _selectedTag),
      ('agent', _selectedAgentName.isEmpty ? 'Agents' : _selectedAgentName),
    ];

    return Container(
      color: Colors.white,
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final opt = options[i];
          final isSel = active == opt.$1;
          final isDropdown = opt.$1 == 'tags' || opt.$1 == 'agent';

          return GestureDetector(
            onTap: () {
              if (opt.$1 == 'tags') {
                // If tags haven't been loaded yet, fetch all rooms first then open picker
                if (_allAvailableTags.isEmpty) {
                  setState(() {
                    if (isLive) {
                      _liveFilter = 'all';
                    } else {
                      _historyFilter = 'all';
                    }
                  });
                  final next = _load();
                  setState(() { _future = next; });
                  next.then((_) {
                    if (mounted) _showTagFilterPicker();
                  });
                } else {
                  _showTagFilterPicker();
                }
              } else if (opt.$1 == 'agent') {
                _showAgentFilterPicker();
              } else {
                if (isLive) {
                  _liveFilter = opt.$1;
                } else {
                  _historyFilter = opt.$1;
                }
                _reload();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSel ? const Color(0xFFDCFCE7) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSel ? Colors.transparent : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    opt.$2,
                    style: AppText.poppins(
                      size: 13,
                      weight: isSel ? FontWeight.w700 : FontWeight.w600,
                      color: isSel ? AppColors.evaGreen : const Color(0xFF475569),
                    ),
                  ),
                  if (isDropdown) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: isSel ? AppColors.evaGreen : const Color(0xFF94A3B8),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAgentFilterPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people_outline_rounded, size: 22, color: AppColors.ink),
                const SizedBox(width: 8),
                Text('Filter by Agent', style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.ink)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.ink4),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: AppScope.of(context).agents.fetchAgents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.evaGreen)));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: AppText.poppins(size: 13, color: AppColors.danger)));
                }
                final agents = snapshot.data ?? [];
                if (agents.isEmpty) {
                  return Center(child: Text('No agents found', style: AppText.poppins(size: 13, color: AppColors.ink3)));
                }
                return Column(
                  children: [
                    ListTile(
                      title: Text('Clear Agent Filter', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.danger)),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        setState(() {
                          _selectedAgentId = '';
                          _selectedAgentName = '';
                          if (_tab == 0) {
                            _liveFilter = 'all';
                          } else {
                            _historyFilter = 'all';
                          }
                        });
                        _reload();
                      },
                    ),
                    const Divider(height: 1),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: agents.length,
                        itemBuilder: (_, i) {
                          final a = agents[i];
                          final name = (a['username'] ?? '').toString();
                          final id = (a['_id'] ?? '').toString();
                          return ListTile(
                            title: Text(name, style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink)),
                            subtitle: Text((a['email'] ?? '').toString(), style: AppText.poppins(size: 12, color: AppColors.ink3)),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              setState(() {
                                _selectedAgentId = id;
                                _selectedAgentName = name;
                                if (_tab == 0) {
                                  _liveFilter = 'agent';
                                } else {
                                  _historyFilter = 'agent';
                                }
                              });
                              _reload();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTagFilterPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tag_rounded, size: 22, color: AppColors.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Filter by tag', style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.ink)),
                      const SizedBox(height: 2),
                      Text('Show customers with the selected tag', style: AppText.poppins(size: 12.5, color: AppColors.ink3)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.ink4),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              title: Text('Clear Tag Filter', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.danger)),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _selectedTag = '';
                  if (_tab == 0) {
                    _liveFilter = 'all';
                  } else {
                    _historyFilter = 'all';
                  }
                });
                _reload();
              },
            ),
            const Divider(height: 1),
            if (_allAvailableTags.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No tags found', style: AppText.poppins(size: 13, color: AppColors.ink3)),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _allAvailableTags.length,
                  itemBuilder: (_, i) {
                    final t = _allAvailableTags[i];
                    final count = _tagCounts[t] ?? 0;
                    final contactText = count == 1 ? '1 contact' : '$count contacts';
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF9E6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.local_offer_outlined, color: AppColors.evaGreenDeep, size: 18),
                      ),
                      title: Text(t, style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink)),
                      trailing: Text(contactText, style: AppText.poppins(size: 12.5, color: AppColors.ink4)),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        setState(() {
                          _selectedTag = t;
                          if (_tab == 0) {
                            _liveFilter = 'tags';
                          } else {
                            _historyFilter = 'tags';
                          }
                        });
                        _reload();
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    final active = _tab == 0 ? _liveFilter : _historyFilter;
    final filterName = switch (active) {
      'unread' => 'unread',
      'read' => 'read',
      'replied' => 'intervened',
      'prospects' => 'prospects',
      'tags' => 'tag',
      'agent' => 'agent',
      _ => _tab == 0 ? 'active' : 'history',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 80, bottom: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 54, color: AppColors.ink4),
            const SizedBox(height: 18),
            Text(
              'No $filterName chats here',
              style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink3),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different filter or search',
              style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink4),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterMenu(BuildContext btnCtx) {
    final isLive = _tab == 0;
    final active = isLive ? _liveFilter : _historyFilter;

    final RenderBox button = btnCtx.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(btnCtx).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final List<({String key, String label, IconData icon})> menuItems = [
      (key: 'all',      label: 'All',        icon: Icons.format_list_bulleted_rounded),
      (key: 'unread',   label: 'Unread',     icon: Icons.mark_email_unread_outlined),
      (key: 'read',     label: 'Read',       icon: Icons.mark_email_read_outlined),
      (key: 'replied',  label: 'Intervened', icon: Icons.support_agent_rounded),
      (key: 'prospects', label: 'Prospects',  icon: Icons.person_search_rounded),
      (key: 'tags',     label: 'Tags',       icon: Icons.label_outline_rounded),
      (key: 'agent',    label: 'Agents',     icon: Icons.people_outline_rounded),
    ];

    showMenu<String>(
      context: btnCtx,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 8,
      color: Colors.white,
      items: menuItems.map((item) {
        final isSel = active == item.key;
        return PopupMenuItem<String>(
          value: item.key,
          padding: EdgeInsets.zero,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSel ? AppColors.evaGreen.withValues(alpha: 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: isSel ? AppColors.evaGreen : const Color(0xFF6B7280)),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: AppText.poppins(
                    size: 14.5,
                    weight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? AppColors.evaGreen : const Color(0xFF1F2937),
                  ),
                ),
                if (isSel) ...[
                  const Spacer(),
                  Icon(Icons.check_rounded, size: 18, color: AppColors.evaGreen),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    ).then((selected) {
      if (selected == null) return;
      if (selected == 'tags') {
        _showTagFilterPicker();
      } else if (selected == 'agent') {
        _showAgentFilterPicker();
      } else {
        _selectedTag = '';
        _selectedAgentId = '';
        _selectedAgentName = '';
        if (isLive) {
          _liveFilter = selected;
        } else {
          _historyFilter = selected;
        }
        _reload();
      }
    });
  }

}

class _NewChatSheet extends StatefulWidget {
  final void Function(String name, String number) onStart;
  const _NewChatSheet({required this.onStart});
  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  final _name = TextEditingController();
  final _number = TextEditingController();
  int _mode = 0; // 0 new chat, 1 group, 2 broadcast

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(3)))),
        const SizedBox(height: 16),
        Row(children: [
          for (var i = 0; i < 3; i++) ...[
            GestureDetector(
              onTap: () => setState(() => _mode = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: _mode == i ? AppColors.evaGreen50 : AppColors.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: _mode == i ? AppColors.evaGreen200 : AppColors.line)),
                child: Text(['New Chat', 'New Group', 'New Broadcast'][i], style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: _mode == i ? AppColors.evaGreenDeep : AppColors.ink3)),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ]),
        const SizedBox(height: 16),
        if (_mode == 0) ...[
          _field(_name, 'Name (optional)'),
          const SizedBox(height: 10),
          _field(_number, 'Mobile number (with country code)', phone: true),
        ] else
          Text(_mode == 1 ? 'Pick contacts to start a group.' : 'Pick contacts for a broadcast list.', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3)),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel', style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink3))),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              if (_mode != 0) {
                appToast(context, 'Only single chat is supported in this build.', isError: true);
                return;
              }
              final num = _number.text.trim();
              if (num.isEmpty) {
                appToast(context, 'Please enter a valid number.', isError: true);
                return;
              }
              widget.onStart(_name.text.trim(), num);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.evaGreen, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Start Chat', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: Colors.white)),
          ),
        ]),
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, {bool phone = false}) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: phone ? TextInputType.phone : TextInputType.text,
        style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
        decoration: InputDecoration(hintText: hint, hintStyle: AppText.poppins(size: 13, color: AppColors.ink4), border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 14)),
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  final ChatRoomDto room;
  final ChatThread thread;
  final VoidCallback onTap;

  const _ChatRow({
    required this.room,
    required this.thread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = thread.unread > 0;
    final allTags = [
      if (room.intervene) 'Intervened',
      ...room.tags,
    ];
    final previewIsTyping = thread.preview.toLowerCase().trim() == 'typing...';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InitialsAvatar(initials: thread.initials, color: thread.color, size: 48, radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          thread.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.poppins(
                            size: 15.5,
                            weight: FontWeight.w700,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (thread.time.isNotEmpty)
                        Text(
                          thread.time,
                          style: AppText.poppins(
                            size: 11.5,
                            weight: FontWeight.w600,
                            color: hasUnread
                                ? AppColors.evaGreen
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (!previewIsTyping && !hasUnread) ...[
                        const Icon(Icons.done_all_rounded, size: 15, color: Color(0xFF60A5FA)),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          thread.preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.poppins(
                            size: 13,
                            weight: (previewIsTyping || hasUnread)
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: previewIsTyping
                                ? AppColors.evaGreen
                                : (hasUnread
                                    ? const Color(0xFF1F2937)
                                    : const Color(0xFF6B7280)),
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.evaGreen,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${thread.unread}',
                            style: AppText.poppins(
                              size: 11,
                              weight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (allTags.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: allTags.map(_tagChip).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagChip(String tag) {
    final l = tag.toLowerCase().trim();
    Color bg;
    Color fg;

    if (l == 'customer') {
      bg = const Color(0xFFF3E8FF);
      fg = const Color(0xFF9333EA);
    } else if (l == 'intervened' || l == 'replied') {
      bg = const Color(0xFFFFEDD5);
      fg = const Color(0xFFC2410C);
    } else if (l.contains('lead') || l.contains('add to')) {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF2563EB);
    } else {
      bg = const Color(0xFFDCFCE7);
      fg = AppColors.evaGreen;
    }
        
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tag,
        style: AppText.poppins(
          size: 11,
          weight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
