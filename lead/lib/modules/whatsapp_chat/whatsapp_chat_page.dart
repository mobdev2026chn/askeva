import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import '../../services/chat_service.dart';
import '../../services/socket_service.dart';
import '../../services/auth_service.dart';
import '../../services/leads_service.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../theme/app_colors.dart';
import 'template_page.dart';
import 'quick_reply_page.dart';

/// Shows a snackbar/banner at the top of the screen **above** any open form (dialog/bottom sheet).
/// Uses overlay so it appears on top of the current route.
void _showTopBanner(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  void remove() {
    try {
      entry.remove();
    } catch (_) {}
  }

  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: isError ? Colors.red.shade700 : AppColors.primary,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.check_circle,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    remove();
                  },
                  child: const Text(
                    'DISMISS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 3), remove);
}

class WhatsAppChatPage extends StatefulWidget {
  final String contactNumber;
  final String profileName;

  const WhatsAppChatPage({
    super.key,
    required this.contactNumber,
    required this.profileName,
  });

  @override
  State<WhatsAppChatPage> createState() => _WhatsAppChatPageState();
}

class _WhatsAppChatPageState extends State<WhatsAppChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  String? _error;
  bool _intervened = false;
  bool _isIntervening = false; // For button loading state
  bool _isTyping = false;

  // Media & Recording state
  bool _isRecording = false;
  bool _isPaused = false;
  int _recordDuration = 0;
  bool _showAttachmentMenu = false;
  Timer? _recordTimer;
  late AudioRecorder _audioRecorder;

  // Search & Scroll features
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showScrollToBottom = false;

  // Profile Sidebar state
  bool _showProfileSidebar = false;

  /// Set when createLead returns "Lead already exists" so we show Active Lead.
  bool _leadExistsForContact = false;
  List<dynamic> _agents = [];
  List<String> _assignedAgentIds = []; // Changed to List for multiple agents
  List<dynamic> _catalogs = [];
  List<dynamic> _products = [];
  Map<String, List<dynamic>> _catalogProducts = {};
  Map<String, bool> _loadingCatalogProducts = {};
  List<dynamic> _notes = [];
  List<dynamic> _customerJourney = [];
  Map<String, dynamic>? _contactInfo;

  bool _isProfileLoading = false;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  double _taxRate = 0.0;
  Map<String, dynamic>? _sessionDoc;
  String? _username;
  String? _email;
  String? _role;

  // Payment form state
  List<Map<String, dynamic>> _paymentProducts = [
    {'name': '', 'price': 0.0, 'quantity': 1},
  ];
  double _paymentSubtotal = 0.0;
  double _paymentDiscount = 0.0;
  double _paymentShipping = 0.0;
  String _paymentDescription = '';
  double _paymentTotal = 0.0;

  Timer? _countdownTimer;
  final ValueNotifier<DateTime> _currentTimeNotifier = ValueNotifier(
    DateTime.now(),
  );

  // Statistics for Profile Sidebar (pre-calculated for performance)
  int _templateMsgCount = 0;
  int _sessionMsgCount = 0;
  String _firstUserMsg = 'N/A';
  DateTime? _lastUserActivity;

  // Download chat state
  bool _isBlocked = false;

  /// Message being replied to (full message map for id + preview text). Null when not replying.
  dynamic _replyingToMessage;

  @override
  void didUpdateWidget(WhatsAppChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contactNumber != widget.contactNumber) {
      _leadExistsForContact = false;
      // Reset messages and sidebar stats so we show this user's data, not the previous contact's
      _messages = [];
      _lastUserActivity = null;
      _templateMsgCount = 0;
      _sessionMsgCount = 0;
      _firstUserMsg = 'N/A';
      _sessionDoc = null;
      _contactInfo = null;
      _isLoading = true;
      _error = null;
      _fetchMessages();
      _fetchProfileData();
    }
  }

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _fetchMessages();
    _fetchProfileData();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _currentTimeNotifier.value = DateTime.now();
      }
    });
    _messageController.addListener(() {
      final isTyping = _messageController.text.trim().isNotEmpty;
      if (isTyping != _isTyping) {
        setState(() {
          _isTyping = isTyping;
        });
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final show = _scrollController.offset > 300;
        if (show != _showScrollToBottom) {
          setState(() {
            _showScrollToBottom = show;
          });
        }
      }
    });
    _initSocket();
    _loadUserMetadata();
  }

  void _initSocket() {
    SocketService().init();
    SocketService().onMessage((payload) {
      if (mounted) {
        final messageData = payload['messageData'];
        if (messageData == null) return;

        // Determine which contact this message belongs to
        final fromNum = payload['fromNumber']?.toString();
        final sentTo = messageData['sentTo']?.toString();
        final dataTo = messageData['data']?['to']?.toString();

        final msgContactNumber = fromNum ?? sentTo ?? dataTo;

        if (msgContactNumber == widget.contactNumber) {
          setState(() {
            _messages.insert(0, messageData);
          });
          _updateSidebarStats();
          _scrollToBottom();
        }
      }
    });
  }

  Future<void> _loadUserMetadata() async {
    final role = await AuthService.getRole();
    final username = await AuthService.getUsername();
    final email = await AuthService.getEmail();
    if (mounted) {
      setState(() {
        _username = username;
        _email = email;
        _role = role;
      });
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _recordTimer?.cancel();
    _countdownTimer?.cancel();
    _currentTimeNotifier.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _noteController.dispose();
    SocketService().offMessage();
    super.dispose();
  }

  static const _placeholderFirstMessages = [
    'business initiated msg.',
    'business initiated message',
    'n/a',
    '',
  ];

  void _updateSidebarStats() {
    int tCount = 0;
    int sCount = 0;
    String fMsg = 'N/A';
    DateTime? lastActivity;
    // First user message: chronologically first user message with real content (pick from messages)
    DateTime? firstUserMsgTime;
    String? firstUserMsgText;

    for (var msg in _messages) {
      final sentBy = msg['sentBy']?.toString();
      // Parse and convert to local time so profile matches the time shown in chat bubbles
      final DateTime? createdAt = msg['createdAt'] != null
          ? DateTime.tryParse(msg['createdAt'].toString())?.toLocal()
          : null;

      // Last Active Conversation: use latest message time from any sender (from messages)
      if (createdAt != null &&
          (lastActivity == null || createdAt.isAfter(lastActivity))) {
        lastActivity = createdAt;
      }

      if (sentBy == 'system') {
        if (msg['messageKey'] != null) {
          tCount++;
        } else {
          sCount++;
        }
      } else if (sentBy == 'user') {
        final text = _getMessageText(msg).trim();
        final fallback = msg['data']?['caption'] != null
            ? _resolveText(msg['data']!['caption']).trim()
            : (text.isEmpty ? 'Media message' : text);
        final displayText = text.isNotEmpty ? text : fallback;
        final isPlaceholder = displayText.isEmpty ||
            _placeholderFirstMessages
                .contains(displayText.toLowerCase().trim());
        if (!isPlaceholder &&
            createdAt != null &&
            (firstUserMsgTime == null || createdAt.isBefore(firstUserMsgTime))) {
          firstUserMsgTime = createdAt;
          firstUserMsgText = displayText;
        }
      }
    }

    if (firstUserMsgText != null && firstUserMsgText.isNotEmpty) {
      fMsg = firstUserMsgText;
    }

    if (mounted) {
      setState(() {
        _templateMsgCount = tCount;
        _sessionMsgCount = sCount;
        _firstUserMsg = fMsg;
        _lastUserActivity = lastActivity;
      });
    }
  }

  Future<void> _fetchProfileData() async {
    setState(() => _isProfileLoading = true);
    try {
      final results = await Future.wait([
        ChatService.getContactByNumber(widget.contactNumber),
        ChatService.getAllAgents(),
        ChatService.getAssignedAgents(widget.contactNumber),
        ChatService.getCustomerJourney(widget.contactNumber),
        ChatService.getCatalogs(),
        ChatService.getShippingPrice(),
        ChatService.getAllProducts(),
      ]);

      debugPrint('=== Profile Data Loaded ===');
      debugPrint('Contact: ${results[0]}');
      debugPrint('All Agents: ${results[1]}');
      debugPrint('Assigned: ${results[2]}');
      debugPrint('Journey: ${results[3]}');
      debugPrint('Catalogs: ${results[4]}');
      debugPrint('Shipping: ${results[5]}');
      debugPrint('Products: ${results[6]}');

      if (mounted) {
        setState(() {
          // Contact data - always a Map
          final contactResult = results[0] as Map<String, dynamic>;
          final contactData =
              (contactResult['data'] ?? contactResult) as Map<String, dynamic>;
          final contact = contactData['contact'] as Map<String, dynamic>?;
          _contactInfo = contact != null
              ? Map<String, dynamic>.from(contact)
              : null;
          // If API returns linked lead info, use it so we show Active Lead
          final leadInfo = contactData['lead'];
          if (_contactInfo != null && leadInfo is Map) {
            if (leadInfo['_id'] != null)
              _contactInfo!['leadId'] = leadInfo['_id'].toString();
            if (leadInfo['id'] != null)
              _contactInfo!['leadId'] = leadInfo['id'].toString();
            if (leadInfo['isConverted'] != null)
              _contactInfo!['isConverted'] = leadInfo['isConverted'];
            if (leadInfo['isCoverted'] != null)
              _contactInfo!['isCoverted'] = leadInfo['isCoverted'];
          }
          final session = contactData['session'];
          _isBlocked =
              session?['isBlocked'] == true ||
              session?['blocked'] == true ||
              session?['blocked'] == 1 ||
              _contactInfo?['blocked'] == true;

          // Update session data if available in contact response
          if (contactData['session'] != null) {
            _sessionDoc = contactData['session'];
          }

          // All Agents - Map with data array
          final agentsResult = results[1];
          List<dynamic> allAgents = [];
          if (agentsResult is Map<String, dynamic>) {
            allAgents = (agentsResult['data'] as List<dynamic>?) ?? [];
          } else if (agentsResult is List<dynamic>) {
            allAgents = agentsResult;
          }
          _agents = allAgents
              .where(
                (agent) =>
                    ['agent', 'superagent', 'admin'].contains(agent['role']),
              )
              .toList();

          // Assigned agents - Map with data
          final assignedResult = results[2] as Map<String, dynamic>;
          final assignedData =
              (assignedResult['data'] ?? assignedResult)
                  as Map<String, dynamic>;
          // Handle multiple assigned agents
          final assignedAgents =
              assignedData['assignedAgents'] as List<dynamic>?;
          _assignedAgentIds =
              assignedAgents?.map((id) => id.toString()).toList() ?? [];
          _notes = (assignedData['notes'] as List<dynamic>?) ?? [];

          // Customer Journey - can be Map with data or direct List
          final journeyResult = results[3];
          List<dynamic> rawJourney = [];
          if (journeyResult is Map<String, dynamic>) {
            rawJourney = (journeyResult['data'] as List<dynamic>?) ?? [];
          } else if (journeyResult is List<dynamic>) {
            rawJourney = journeyResult;
          }

          // Sort by createdAt descending (newest first)
          rawJourney.sort((a, b) {
            final dateA =
                DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
                DateTime(0);
            final dateB =
                DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
                DateTime(0);
            return dateB.compareTo(dateA);
          });

          _customerJourney = rawJourney;

          // Catalogs - can be Map with data or direct List
          final catalogsResult = results[4];
          if (catalogsResult is Map<String, dynamic>) {
            _catalogs = (catalogsResult['data'] as List<dynamic>?) ?? [];
          } else if (catalogsResult is List<dynamic>) {
            _catalogs = catalogsResult;
          } else {
            _catalogs = [];
          }

          // Products
          final productsResult = results[6];
          if (productsResult is Map<String, dynamic>) {
            _products = (productsResult['data'] as List<dynamic>?) ?? [];
          } else if (productsResult is List<dynamic>) {
            _products = productsResult;
          } else {
            _products = [];
          }

          // _shippingPrice = (results[5] as num).toDouble();
          _isProfileLoading = false;
        });

        // Proactively check if a lead already exists for this contact (so we show Active Lead without user tapping Add)
        final hasStatus = _contactInfo?['status']?.toString().isNotEmpty ?? false;
        final isConverted =
            _contactInfo?['isConverted'] == true ||
            _contactInfo?['isCoverted'] == true ||
            _contactInfo?['status']?.toString().toLowerCase() == 'converted';
        final hasLeadId =
            _contactInfo?['leadId'] != null || _contactInfo?['lead_id'] != null;
        if (hasStatus || isConverted || hasLeadId) {
          if (mounted) {
            setState(() {
              _leadExistsForContact = true;
            });
          }
        }

        // If contact API didn't return lead, check leads by contact number (backend getLeads supports q on fullMobile)
        if (!_leadExistsForContact &&
            (_contactInfo?['contactNumber'] != null ||
                widget.contactNumber.isNotEmpty)) {
          final rawDigits = (_contactInfo?['contactNumber'] ??
                  widget.contactNumber)
              .toString()
              .replaceAll(RegExp(r'\D'), '');
          if (rawDigits.isNotEmpty) {
            // Search with full international form so backend fullMobile matches (backend stores countryCode+mobile)
            final String searchDigits = _normalizeToFullInternational(rawDigits);
            try {
              final res = await LeadsService.getLeads(
                page: 1,
                limit: 5,
                q: searchDigits,
              );
              final items = res['items'] as List<dynamic>? ?? [];
              for (final item in items) {
                final lead = item as Map<String, dynamic>;
                final leadFullMobile = lead['fullMobile']
                    ?.toString()
                    .replaceAll(RegExp(r'\D'), '');
                if (leadFullMobile == null || leadFullMobile.isEmpty) continue;
                // Match: exact same number, or contact is local (e.g. 9495204766) and lead is full (919495204766)
                final isMatch = leadFullMobile == rawDigits ||
                    leadFullMobile == searchDigits ||
                    (rawDigits.length >= 10 &&
                        leadFullMobile.endsWith(rawDigits)) ||
                    (searchDigits.length >= 10 &&
                        leadFullMobile.endsWith(searchDigits));
                if (isMatch && mounted) {
                  setState(() {
                    _leadExistsForContact = true;
                    // Ensure we have a map to store lead fields so "Customer" vs "Active Lead" shows correctly
                    _contactInfo ??= <String, dynamic>{};
                    _contactInfo!['leadId'] =
                        lead['id']?.toString() ?? lead['_id']?.toString();
                    _contactInfo!['isConverted'] = lead['isConverted'] == true;
                    _contactInfo!['isCoverted'] = lead['isCoverted'] == true;
                    _contactInfo!['status'] = lead['status']?.toString();
                  });
                  break;
                }
              }
            } catch (_) {
              // Ignore; profile still shows Add to Leads
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile data: $e');
      if (mounted) {
        setState(() => _isProfileLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile info: $e')),
        );
      }
    }
  }

  Future<void> _assignAgents(List<String> agentIds) async {
    try {
      await ChatService.assignAgent(widget.contactNumber, agentIds);
      setState(() => _assignedAgentIds = agentIds);
      _fetchProfileData(); // Refetch to update journey and assigned agents data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agents assigned successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error assigning agents: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to assign agents: $e')));
      }
    }
  }

  /// Refreshes only notes in the drawer (no full profile refetch).
  Future<void> _refreshDrawerNotes() async {
    try {
      final assignedResult =
          await ChatService.getAssignedAgents(widget.contactNumber);
      final assignedData =
          (assignedResult['data'] ?? assignedResult) as Map<String, dynamic>;
      final notes = (assignedData['notes'] as List<dynamic>?) ?? [];
      if (mounted) setState(() => _notes = notes);
    } catch (_) {}
  }

  Future<void> _addNote() async {
    final noteText = _noteController.text.trim();
    if (noteText.isEmpty) return;

    try {
      await ChatService.addNote(
        widget.contactNumber,
        noteText,
        _username ?? 'Agent',
        _email ?? '',
      );
      _noteController.clear();
      await _refreshDrawerNotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add note: $e')),
        );
      }
    }
  }

  void _addTag(String tag) {
    final value = tag.trim();
    if (value.isEmpty) return;

    final currentTags = _getCurrentTags();
    if (!currentTags.contains(value)) {
      _updateTags([...currentTags, value]);
    }
    _tagController.clear();
  }

  void _removeTag(String tag) {
    final currentTags = _getCurrentTags();
    _updateTags(currentTags.where((t) => t != tag).toList());
  }

  Future<void> _updateTags(List<String> newTags) async {
    final contactId = _contactInfo?['_id']?.toString();
    final sessionId = _sessionDoc?['_id']?.toString();

    if (contactId == null && sessionId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No contact or session found to update tags'),
          ),
        );
      }
      return;
    }

    try {
      if (contactId != null) {
        await ChatService.updateContactTags(contactId, newTags);
      } else {
        final sessionReqBody = {
          'countryCode': _sessionDoc?['countryCode'],
          'phoneNumber':
              _sessionDoc?['contactNumber'] ?? widget.contactNumber,
          'contactName':
              _sessionDoc?['profileName'] ?? widget.profileName,
          'groups': _sessionDoc?['groups'] ?? [],
          'tags': newTags,
        };
        await ChatService.updateContactWithBody(
          sessionId!,
          {'session': sessionReqBody},
        );
      }
      if (!mounted) return;
      setState(() {
        if (_contactInfo != null) _contactInfo!['tags'] = newTags;
        if (_sessionDoc != null) _sessionDoc!['tags'] = newTags;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tags updated successfully')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update tags: $e')),
        );
      }
    }
  }

  List<String> _getCurrentTags() {
    final contactTags = _contactInfo?['tags'] as List<dynamic>?;
    final sessionTags = _sessionDoc?['tags'] as List<dynamic>?;
    return (contactTags ?? sessionTags ?? []).map((e) => e.toString()).toList();
  }

  List<String> _getCurrentGroups() {
    final contactGroups = _contactInfo?['groups'] as List<dynamic>?;
    final sessionGroups = _sessionDoc?['groups'] as List<dynamic>?;
    return (contactGroups ?? sessionGroups ?? [])
        .map((e) => e.toString())
        .toList();
  }

  Future<void> _updateGroups(List<String> newGroups) async {
    final contactId = _contactInfo?['_id']?.toString();
    final sessionId = _sessionDoc?['_id']?.toString();
    final idToSend = contactId ?? sessionId;

    if (idToSend == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No contact or session found to update groups'),
          ),
        );
      }
      return;
    }

    final reqBody = {
      'countryCode':
          _contactInfo?['countryCode'] ?? _sessionDoc?['countryCode'],
      'phoneNumber':
          _contactInfo?['phoneNumber'] ??
          _sessionDoc?['contactNumber'] ??
          widget.contactNumber,
      'contactName':
          _contactInfo?['contactName'] ??
          _sessionDoc?['profileName'] ??
          widget.profileName,
      'groups': newGroups,
      'tags': _getCurrentTags(),
    };

    try {
      if (contactId != null) {
        await ChatService.updateContactWithBody(idToSend, {'contact': reqBody});
      } else {
        await ChatService.updateContactWithBody(
            sessionId!, {'session': reqBody});
      }
      if (!mounted) return;
      setState(() {
        if (_contactInfo != null) _contactInfo!['groups'] = newGroups;
        if (_sessionDoc != null) _sessionDoc!['groups'] = newGroups;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Groups updated successfully')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update groups: $e')),
        );
      }
    }
  }

  void _showAddGroupDialog() {
    // Controller for the Autocomplete text field
    final TextEditingController groupController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<String>>(
        future: ChatService.getContactGroups(),
        builder: (context, snapshot) {
          // While loading, we can still show the dialog structure to avoid flicker
          // But maybe disable input? Or just show spinner.
          // Using empty list if loading or error for simplicity + spinner overlay if needed?
          // Let's just pass empty list if data not ready.
          final List<String> availableGroups = snapshot.data ?? [];

          final cs = Theme.of(context).colorScheme;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: cs.outline.withOpacity(0.5))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Contact to Groups',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        border: Border.all(color: const Color(0xFFFFEDD5)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xFFEA580C),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This contact will be created and added to the selected groups',
                              style: TextStyle(
                                color: const Color(0xFFC2410C),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                        children: [
                          TextSpan(
                            text: 'Contact: ',
                            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
                          ),
                          TextSpan(text: widget.profileName, style: TextStyle(color: cs.onSurface)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                        children: [
                          TextSpan(
                            text: 'Phone: ',
                            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
                          ),
                          TextSpan(text: widget.contactNumber, style: TextStyle(color: cs.onSurface)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Autocomplete for Groups
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return availableGroups;
                            }
                            return availableGroups.where((String option) {
                              return option.toLowerCase().contains(
                                textEditingValue.text.toLowerCase(),
                              );
                            });
                          },
                          onSelected: (String selection) {
                            groupController.text = selection;
                          },
                          fieldViewBuilder:
                              (
                                context,
                                textEditingController,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                textEditingController.addListener(() {
                                  groupController.text =
                                      textEditingController.text;
                                });

                                return TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  style: TextStyle(color: cs.onSurface),
                                  decoration: InputDecoration(
                                    hintText: 'Select or create groups',
                                    hintStyle: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                    filled: true,
                                    fillColor: cs.surfaceContainerHighest,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide(
                                        color: cs.outline.withOpacity(0.5),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide(
                                        color: cs.outline.withOpacity(0.5),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF1EA443),
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    suffixIcon: Icon(
                                      Icons.keyboard_arrow_down,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              },
                          optionsViewBuilder: (context, onSelected, options) {
                            final dropdownCs = Theme.of(context).colorScheme;
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                child: Container(
                                  width: constraints.maxWidth,
                                  constraints: const BoxConstraints(
                                    maxHeight: 200,
                                  ),
                                  color: dropdownCs.surface,
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                          final String option = options
                                              .elementAt(index);
                                          return InkWell(
                                            onTap: () {
                                              onSelected(option);
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Text(
                                                option,
                                                style: TextStyle(color: dropdownCs.onSurface),
                                              ),
                                            ),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'You can select existing groups or type new group names',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final text = groupController.text.trim();
                      if (text.isNotEmpty) {
                        final currentGroups = _getCurrentGroups();
                        if (!currentGroups.contains(text)) {
                          _updateGroups([...currentGroups, text]);
                        }
                      }
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1EA443),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Create Contact & Add to Groups',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _calculatePaymentTotal() {
    // Calculate subtotal from products
    _paymentSubtotal = _paymentProducts.fold(0.0, (sum, product) {
      final price = product['price'] ?? 0.0;
      final quantity = product['quantity'] ?? 1;
      return sum + (price * quantity);
    });

    // Apply discount
    final afterDiscount = _paymentSubtotal - _paymentDiscount;

    // Calculate tax
    final taxAmount = (afterDiscount * _taxRate) / 100;

    // Calculate total
    _paymentTotal = afterDiscount + taxAmount + _paymentShipping;
  }

  Future<void> _notifyPayment() async {
    try {
      // Validate that we have at least one product with data
      if (_paymentProducts.isEmpty ||
          _paymentProducts.every(
            (p) => (p['name'] ?? '').toString().trim().isEmpty,
          )) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please add at least one product')),
          );
        }
        return;
      }

      // Calculate tax amount
      final afterDiscount = _paymentSubtotal - _paymentDiscount;
      final taxAmount = (afterDiscount * _taxRate) / 100;

      // Prepare products array matching backend format
      final products = _paymentProducts
          .where((p) => (p['name'] ?? '').toString().trim().isNotEmpty)
          .map(
            (p) => {
              'name': p['name'] ?? '',
              'price': p['price'] ?? 0.0,
              'quantity': p['quantity'] ?? 1,
            },
          )
          .toList();

      // Prepare payment data matching backend controller expectations
      final Map<String, dynamic> paymentData = {
        'userNumber': widget.contactNumber,
        'products': products,
        'shippingPrice': _paymentShipping,
        'taxRate': _taxRate,
        'taxAmount': taxAmount,
        'totalAmount': _paymentTotal,
        'discount': _paymentDiscount,
        'description': _paymentDescription.isNotEmpty
            ? _paymentDescription
            : 'Please complete your payment to proceed',
      };

      debugPrint('Sending payment notification: $paymentData');

      await ChatService.notifyPayment(paymentData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment notification sent successfully'),
            backgroundColor: const Color(0xFF1EA443),
          ),
        );

        // Reset form
        setState(() {
          _paymentProducts = [
            {'name': '', 'price': 0.0, 'quantity': 1},
          ];
          _paymentDiscount = 0.0;
          _paymentShipping = 0.0;
          _paymentDescription = '';
          _taxRate = 0.0;
          _calculatePaymentTotal();
        });
      }
    } catch (e) {
      debugPrint('Payment notification error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to notify payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchMessages() async {
    try {
      final result = await ChatService.getChatMessages(
        widget.contactNumber,
        limit: 1000,
      );
      if (mounted) {
        final List<dynamic> rawData = result['data'] ?? [];

        // 1. Filter out backend's weird dayBreakFlags and sort newest first
        // 1. Filter out backend's weird dayBreakFlags, sort, and remove empty messages
        final List<dynamic> cleanMessages = rawData.where((m) {
          if (m['type'] == 'dayBreakFlag') return false;
          return _isValidMessage(m);
        }).toList();

        cleanMessages.sort((a, b) {
          final dateA =
              DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
              DateTime(0);
          final dateB =
              DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
              DateTime(0);
          return dateB.compareTo(dateA); // Newest first (index 0 is newest)
        });

        // 2. Re-add day headers (in a reverse:true list, "above" means "higher index")
        final List<dynamic> processed = [];
        for (int i = 0; i < cleanMessages.length; i++) {
          final m = cleanMessages[i];
          processed.add(m);

          final currentDay = DateFormat('yyyy-MM-dd').format(
            DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
                DateTime.now(),
          );

          bool isEndOfDay = false;
          if (i == cleanMessages.length - 1) {
            isEndOfDay = true;
          } else {
            final nextM = cleanMessages[i + 1];
            final nextDay = DateFormat('yyyy-MM-dd').format(
              DateTime.tryParse(nextM['createdAt']?.toString() ?? '') ??
                  DateTime.now(),
            );
            if (currentDay != nextDay) {
              isEndOfDay = true;
            }
          }

          if (isEndOfDay) {
            processed.add({'type': 'dayBreakFlag', 'day': currentDay});
          }
        }

        setState(() {
          _messages = processed;
          final session = result['sessionDoc'];
          _sessionDoc = session;
          _intervened = session != null ? session['intervene'] == true : false;
          if (session != null) {
            _isBlocked =
                session['isBlocked'] == true ||
                session['blocked'] == true ||
                session['blocked'] == 1;
          }
          _isLoading = false;
        });
        _updateSidebarStats();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading messages: $e')));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Returns the unique id of a message (_id, id, or wamid).
  String? _getMessageId(dynamic message) {
    if (message == null || message is! Map) return null;
    final id = message['_id'] ?? message['id'] ?? message['wamid'];
    return id?.toString();
  }

  /// Returns the id of the message being replied to (for scroll-to-message).
  String? _getRepliedToMessageId(dynamic message) {
    if (message == null || message is! Map) return null;
    final contextReply = message['contextReply'];
    if (contextReply is Map) {
      final id = contextReply['id'] ?? contextReply['repliedWamid'] ?? contextReply['repliedMessageId'];
      if (id != null) return id.toString();
    }
    final replyTo = message['replyTo'];
    if (replyTo == null) return null;
    if (replyTo is Map) {
      return _getMessageId(replyTo);
    }
    return replyTo.toString();
  }

  /// Scrolls the chat to the message with [id] (like WhatsApp: tap reply preview to jump to original).
  void _scrollToMessageById(String? id) {
    if (id == null || id.isEmpty) return;
    final filtered = _messages.where((m) {
      if (m['type'] == 'dayBreakFlag') return true;
      if (_searchQuery.isEmpty) return true;
      final text = _getMessageText(m).toLowerCase();
      return text.contains(_searchQuery);
    }).toList();
    int targetIndex = -1;
    for (int i = 0; i < filtered.length; i++) {
      final m = filtered[i];
      if (m['type'] == 'dayBreakFlag') continue;
      if (_getMessageId(m) == id) {
        targetIndex = i;
        break;
      }
    }
    if (targetIndex < 0 || !_scrollController.hasClients) return;
    const double estimatedItemHeight = 100.0;
    final targetOffset = (targetIndex * estimatedItemHeight).clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    String? replyToId;
    if (_replyingToMessage != null) {
      replyToId = _replyingToMessage['_id']?.toString() ?? _replyingToMessage['id']?.toString();
      setState(() => _replyingToMessage = null);
    }

    try {
      if (!_intervened) {
        await ChatService.updateIntervene(widget.contactNumber, true);
        setState(() => _intervened = true);
      }

      await ChatService.sendMessage(
        toNumber: widget.contactNumber,
        type: 'text',
        data: {'body': text},
        replyTo: replyToId,
      );
      _fetchMessages();
      _fetchProfileData(); // Refetch to show intervention in journey
    } catch (e) {
      // Silently handle errors - don't show error messages to user
      debugPrint('Failed to send message: $e');
    }
  }

  Future<void> _interveneChat() async {
    setState(() => _isIntervening = true);
    try {
      await ChatService.updateIntervene(widget.contactNumber, true);
      setState(() => _intervened = true);
      _fetchMessages();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to intervene: $e')));
    } finally {
      if (mounted) setState(() => _isIntervening = false);
    }
  }

  Future<void> _disintervene() async {
    setState(() => _isIntervening = true);
    try {
      await ChatService.updateIntervene(widget.contactNumber, false);
      setState(() => _intervened = false);
      _fetchMessages();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to disintervene: $e')));
    } finally {
      if (mounted) setState(() => _isIntervening = false);
    }
  }

  void _showCloseChatOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Chat'),
        content: const Text(
          'Do you want to just close the chat or move it to admin?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _disintervene();
            },
            child: const Text('Close', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _closeAndMoveToAdmin();
            },
            child: const Text(
              'Close and Move to Admin',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _closeChat() async {
    if (_role == 'agent') {
      _showCloseChatOptions();
    } else {
      _disintervene();
    }
  }

  Future<void> _closeAndMoveToAdmin() async {
    setState(() => _isIntervening = true);
    try {
      await ChatService.updateIntervene(widget.contactNumber, false);
      await ChatService.closeChat(widget.contactNumber);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat closed and moved to admin')),
      );
      _fetchMessages();
      _fetchProfileData(); // Refetch to show closure in journey
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to close: $e')));
    } finally {
      if (mounted) setState(() => _isIntervening = false);
    }
  }

  void _startRecordTimer() {
    _recordTimer?.cancel();
    _recordDuration = 0;
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordDuration++;
        });
      }
    });
  }

  Future<void> _startRecording() async {
    try {
      if (await Permission.microphone.request().isGranted) {
        final dir = await getTemporaryDirectory();
        // Use .ogg for Opus voice notes to match web/WhatsApp
        final path =
            '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.ogg';

        final config = RecordConfig(
          encoder: AudioEncoder.opus,
          bitRate: 16000,
          sampleRate: 16000,
          numChannels: 1,
        );

        await _audioRecorder.start(config, path: path);

        setState(() {
          _isRecording = true;
          _isPaused = false;
        });
        _startRecordTimer();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable mic to send recording.')),
        );
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _audioRecorder.pause();
      _recordTimer?.cancel();
      setState(() {
        _isPaused = true;
      });
    } catch (e) {
      debugPrint('Error pausing recording: $e');
    }
  }

  Future<void> _resumeRecording() async {
    try {
      await _audioRecorder.resume();
      _startRecordTimer();
      setState(() {
        _isPaused = false;
      });
    } catch (e) {
      debugPrint('Error resuming recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _recordTimer?.cancel();

      setState(() {
        _isRecording = false;
        _isPaused = false;
        _recordDuration = 0;
      });

      if (path != null) {
        // Folder must be 'chat' to match web backend
        await _sendMediaMessage(path, 'audio', isVoice: true);
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _cancelRecording() async {
    await _audioRecorder.stop();
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _recordDuration = 0;
    });
  }

  Future<void> _sendMediaMessage(
    String filePath,
    String type, {
    bool isVoice = false,
    String? caption,
  }) async {
    try {
      if (!_intervened) {
        await ChatService.updateIntervene(widget.contactNumber, true);
        setState(() => _intervened = true);
      }

      final url = await ChatService.uploadFile(
        filePath,
        'chat', // Matches web: upload/chat
        isVoice: isVoice,
      );
      if (url != null) {
        final data = {
          'link': url,
          if (isVoice) 'voice': true,
          if (!isVoice) 'caption': caption ?? '',
          if (type == 'document') 'filename': filePath.split('/').last,
        };
        // Pass reply wamid when replying (same as web) so backend stores contextReply.
        String? replyToWamid;
        if (_replyingToMessage != null) {
          replyToWamid = _replyingToMessage!['wamid']?.toString() ??
              _replyingToMessage!['_id']?.toString() ??
              _replyingToMessage!['id']?.toString();
          setState(() => _replyingToMessage = null);
        }
        await ChatService.sendMessage(
          toNumber: widget.contactNumber,
          type: type,
          data: data,
          replyTo: replyToWamid,
        );
        _fetchMessages();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send media: $e')));
    }
  }

  Future<void> _pickAndSendImage({bool fromCamera = false}) async {
    setState(() {
      _showAttachmentMenu = false;
    });
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );
    if (image != null) {
      if (mounted) {
        _showImageUploadBottomSheet(image.path);
      }
    }
  }

  void _showImageUploadBottomSheet(String imagePath) {
    final TextEditingController captionController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Preview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(imagePath), fit: BoxFit.contain),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: captionController,
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Add a caption...',
                          hintStyle: TextStyle(color: cs.onSurfaceVariant),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      backgroundColor: const Color(0xFF1EA443),
                      radius: 24,
                      child: IconButton(
                        icon: Icon(Icons.send, color: cs.onPrimary),
                      onPressed: () {
                        Navigator.pop(context);
                        _sendMediaMessage(
                          imagePath,
                          'image',
                          caption: captionController.text.trim(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  },
  );
  }

  Future<void> _pickAndSendFile(String type) async {
    setState(() {
      _showAttachmentMenu = false;
    });
    FileType fileType = FileType.any;
    if (type == 'video') fileType = FileType.video;
    if (type == 'audio') fileType = FileType.audio;

    final result = await FilePicker.platform.pickFiles(type: fileType);
    if (result != null && result.files.single.path != null) {
      await _sendMediaMessage(result.files.single.path!, type);
    }
  }

  void _handleMenuAction(String action) async {
    if (action == 'download') {
      await _downloadChat();
    } else if (action == 'block') {
      _showBlockConfirmation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final headerBg = cs.surface;
    final whatsAppBg = cs.surface;
    const primaryColor = Color(0xFF1EA443);
    final textColor = cs.onSurface;

    return Scaffold(
      backgroundColor: whatsAppBg,
      appBar: AppBar(
        elevation: 0.5,
        titleSpacing: 0,
        backgroundColor: headerBg,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: cs.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cs.outline.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: primaryColor.withOpacity(0.12),
                      child: Text(
                        widget.profileName.isNotEmpty
                            ? widget.profileName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Color(0xFF1EA443),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? cs.surfaceContainerHighest
                            : const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(color: cs.onSurface, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Search in conversation...',
                          hintStyle: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: cs.onSurfaceVariant,
                            size: 20,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 4,
                          ),
                          suffixIcon: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.close_rounded,
                              color: cs.onSurfaceVariant,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _isSearching = false;
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          ),
                        ),
                        onChanged: (val) =>
                            setState(() => _searchQuery = val.toLowerCase()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              )
            : InkWell(
                onTap: () =>
                    setState(() => _showProfileSidebar = !_showProfileSidebar),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cs.outline.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 19,
                        backgroundColor: primaryColor.withOpacity(0.08),
                        child: Text(
                          widget.profileName.isNotEmpty
                              ? widget.profileName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.profileName,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Text(
                            'online',
                            style: TextStyle(
                              color: Color(0xFF1EA443),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        iconTheme: IconThemeData(color: cs.onSurface),
        actions: [
          if (!_isSearching) ...[
            IconButton(
              icon: Icon(Icons.search_rounded, color: cs.onSurface),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          ],
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: cs.onSurface),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'download',
                child: Text('Download Chat'),
              ),
              PopupMenuItem(
                value: 'block',
                child: Text(_isBlocked ? 'Unblock' : 'Spam & Block'),
              ),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          final sidebarWidth = isNarrow ? constraints.maxWidth * 0.85 : 320.0;

          return Stack(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              _buildMessageList(
                                constraints.maxWidth -
                                    (_showProfileSidebar && !isNarrow
                                        ? sidebarWidth
                                        : 0),
                              ),
                              if (_showScrollToBottom)
                                Positioned(
                                  bottom: 20,
                                  left: 20,
                                  child: GestureDetector(
                                    onTap: () => _scrollController.animateTo(
                                      0,
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeOut,
                                    ),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1EA443),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.2,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ),
                              // Tap outside (on chat area) closes the document medias / attachment card
                              if (_showAttachmentMenu)
                                Positioned.fill(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () =>
                                        setState(() => _showAttachmentMenu = false),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_isBlocked)
                          _buildBlockedFooter()
                        else if (_intervened) ...[
                          _buildInputArea(),
                        ] else
                          _buildInterveneButton(),
                      ],
                    ),
                  ),
                  if (!isNarrow && _showProfileSidebar)
                    _buildProfileSidebar(sidebarWidth),
                ],
              ),
              if (isNarrow && _showProfileSidebar)
                GestureDetector(
                  onTap: () => setState(() => _showProfileSidebar = false),
                  child: Container(color: Colors.black26),
                ),
              if (isNarrow && _showProfileSidebar)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: _buildProfileSidebar(sidebarWidth),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageList(double availableWidth) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1EA433)),
      );
    }

    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    final filteredMessages = _messages.where((m) {
      if (m['type'] == 'dayBreakFlag') return true;
      if (_searchQuery.isEmpty) return true;
      final text = _getMessageText(m).toLowerCase();
      return text.contains(_searchQuery);
    }).toList();

    if (filteredMessages.isEmpty) {
      return const Center(child: Text('No messages found'));
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const bgLight = 'assets/images/whatsappChatbgLighttheme.jpg';
    const bgDark = 'assets/images/whatsappChatbgDarktheme.jpg';
    final chatBgAsset = isDark ? bgDark : bgLight;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            chatBgAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => ColoredBox(color: cs.surface),
          ),
        ),
        Positioned.fill(
          child: RefreshIndicator(
            onRefresh: _fetchMessages,
            color: const Color(0xFF1EA443),
            child: RawScrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              thickness: 10,
              radius: const Radius.circular(5),
              thumbColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              trackColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
              trackRadius: const Radius.circular(5),
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount:
                  filteredMessages.length + 1, // Add 1 for the encryption banner
                reverse: true, // Newest messages at bottom
                itemBuilder: (context, index) {
                if (index == filteredMessages.length) {
                  return _buildEncryptionBanner();
                }
                final message = filteredMessages[index];

                if (message['type'] == 'dayBreakFlag') {
                  return _buildDateHeader(message['day']);
                }

                final bool isMe = message['sentBy'] != 'user';
                try {
                  return GestureDetector(
                    onLongPress: () => _showMessageOptions(message),
                    child: _buildMessageBubble(message, isMe, availableWidth),
                  );
                } catch (e, st) {
                  debugPrint('Chat: error building message bubble: $e\n$st');
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.outline.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Message',
                        style: TextStyle(color: cs.onSurface, fontSize: 14),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          ),
        ),
      ],
    );
  }

  Widget _buildEncryptionBanner() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outline.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Messages are end-to-end encrypted. No one outside of this chat, not even WhatsApp, can read or listen to them.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: cs.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterveneButton() {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: InkWell(
          onTap: _isIntervening ? null : _interveneChat,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1EA443),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isIntervening)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else ...[
                  const Icon(
                    Icons.person_add_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Intervene',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Center(
        child: InkWell(
          onTap: _isIntervening ? null : _closeChat,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1EA443), // App green for close
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isIntervening)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else
                  const Icon(Icons.cancel, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateHeader(dynamic dayStr) {
    if (dayStr == null) return const SizedBox();
    final cs = Theme.of(context).colorScheme;
    final day = DateTime.tryParse(dayStr.toString()) ?? DateTime.now();
    String label = DateFormat('dd/MM/yyyy').format(day);

    final now = DateTime.now();
    if (now.year == day.year && now.month == day.month && now.day == day.day) {
      label = 'TODAY';
    } else if (now.difference(day).inDays == 1) {
      label = 'YESTERDAY';
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outline.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: cs.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  void _showTopNotification(String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.download_done,
                  color: Color(0xFF1EA443),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 18,
                  ),
                  onPressed:
                      () {}, // Close handled by timer or simple tap outside if complex
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 4), () => overlayEntry.remove());
  }

  Future<void> _downloadChat() async {
    try {
      // Show downloading notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Downloading chat history...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Format chat data similar to web implementation
      String formattedText = 'Chat Conversation Report\n';
      formattedText +=
          'Contact: ${widget.profileName} (${widget.contactNumber})\n';
      formattedText +=
          'Report Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}\n\n';

      String currentDateHeader = '';

      for (var message in _messages.reversed) {
        try {
          // Check for date breaks
          final createdAt = message['createdAt'];
          if (createdAt != null) {
            final msgDate = DateTime.tryParse(createdAt.toString());
            if (msgDate != null) {
              final dateString = DateFormat('EEEE, MMMM d').format(msgDate);
              if (dateString != currentDateHeader) {
                currentDateHeader = dateString;
                formattedText += '\n=== $dateString ===\n';
              }
            }
          }

          // Get timestamp
          final timestamp = createdAt != null
              ? DateFormat('HH:mm').format(
                  DateTime.tryParse(createdAt.toString())?.toLocal() ??
                      DateTime.now(),
                )
              : 'Unknown time';

          // Get sender
          final sender = message['sentBy'] == 'user' ? 'User' : 'System';

          // Get message content
          String messageContent = '';
          String campaignInfo = '';

          if (message['campaignId'] != null) {
            campaignInfo = '[Campaign: ${message['campaignId']}] ';
            if (message['data']?['template']?['name'] != null) {
              campaignInfo += '"${message['data']['template']['name']}" - ';
            }
          }

          // Extract message text from various possible locations
          if (message['data']?['text']?['body'] != null) {
            messageContent = message['data']['text']['body'];
          } else if (message['data']?['template']?['message'] != null) {
            messageContent = message['data']['template']['message'];
          } else if (message['data']?['interactive']?['body']?['text'] !=
              null) {
            messageContent = message['data']['interactive']['body']['text'];
          } else if (message['data']?['interactive']?['type'] == 'flow') {
            messageContent = 'Form submitted';
          } else if (message['data']?['type'] == 'image' ||
              message['data']?['interactive']?['header']?['type'] == 'image') {
            messageContent = '[Image attachment]';
          } else if (message['data']?['type'] == 'video') {
            messageContent = '[Video attachment]';
          } else if (message['data']?['type'] == 'audio') {
            messageContent = '[Audio attachment]';
          } else if (message['data']?['type'] == 'document') {
            messageContent = '[Document attachment]';
            if (message['data']?['document']?['filename'] != null) {
              messageContent += ': ${message['data']['document']['filename']}';
            }
          } else if (message['status'] == 'failed') {
            messageContent = '[Message failed to send]';
            if (message['error']?['title'] != null) {
              messageContent += ' (${message['error']['title']})';
            }
          } else {
            messageContent = '[Unsupported message type]';
          }

          if (messageContent.isNotEmpty) {
            formattedText +=
                '[$timestamp] $sender: $campaignInfo$messageContent\n';
          }
        } catch (e) {
          formattedText += '[Error processing message]\n';
        }
      }

      // Save to Downloads directory (or fallback to app documents)
      Directory? directory;
      try {
        // Try to get Downloads directory
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
        } else if (Platform.isWindows) {
          final userProfile = Platform.environment['USERPROFILE'];
          if (userProfile != null) {
            directory = Directory('$userProfile\\Downloads');
          }
        }

        // Check if directory exists, fallback if not
        if (directory == null || !await directory.exists()) {
          directory = await getApplicationDocumentsDirectory();
        }
      } catch (e) {
        directory = await getApplicationDocumentsDirectory();
      }

      final fileName =
          'Chat_${widget.profileName}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.txt';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(formattedText);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.download_done, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Downloaded: $fileName')),
              ],
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Open Folder',
              onPressed: () async {
                // Try to open the directory
                try {
                  await OpenFilex.open(directory!.path);
                } catch (e) {
                  debugPrint('Could not open folder: $e');
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to download chat: $e')));
      }
    }
  }

  /// Open document (file) from chat - view in browser or system app.
  Future<void> _openDocument(String link, String filename) async {
    String url = link.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = '${AuthService.baseUrl}${url.startsWith('/') ? '' : '/'}$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    try {
      // Prefer opening in external app/browser (same as web - user can view there).
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    // Fallback: download with auth and open locally (for API URLs that need token).
    try {
      final token = await AuthService.getToken();
      final resp = await http.get(
        uri,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        final dir = await getTemporaryDirectory();
        final safeName = filename.replaceAll(RegExp(r'[^\w\.\-]'), '_');
        final file = File('${dir.path}/$safeName');
        await file.writeAsBytes(resp.bodyBytes);
        await OpenFilex.open(file.path);
        if (mounted) {
          _showTopBanner(context, 'Document opened');
        }
      } else if (mounted) {
        _showTopBanner(context, 'Could not open document', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showTopBanner(
          context,
          'Could not open document: ${e.toString().split('\n').first}',
          isError: true,
        );
      }
    }
  }

  void _showBlockConfirmation() {
    final title = _isBlocked ? 'Unblock User' : 'Confirmation';
    final content = _isBlocked
        ? 'Are you sure you want to unblock this user?'
        : 'Are you sure you want to block this user?';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF1EA443)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1EA443),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              if (_isBlocked) {
                _unblockUser();
              } else {
                _blockUser();
              }
            },
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _unblockUser() async {
    try {
      await ChatService.blockUser(widget.contactNumber, 'unblock');
      if (mounted) {
        setState(() => _isBlocked = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unblocked successfully')),
        );
        _fetchProfileData(); // Refresh to ensure state is consistent
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to unblock user: $e')));
      }
    }
  }

  Future<void> _blockUser() async {
    try {
      await ChatService.blockUser(widget.contactNumber, 'block');
      if (mounted) {
        setState(() => _isBlocked = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked successfully')),
        );
        _fetchProfileData(); // Refresh to ensure state is consistent
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to block user: $e')));
      }
    }
  }

  Widget _buildMessageBubble(
    dynamic message,
    bool isMe,
    double availableWidth,
  ) {
    final cs = Theme.of(context).colorScheme;
    final text = _getMessageText(message);
    String timeStr = '';
    try {
      if (message['createdAt'] != null) {
        final dt = DateTime.parse(message['createdAt'].toString()).toLocal();
        timeStr = DateFormat('hh:mm a').format(dt);
      }
    } catch (e) {
      debugPrint('Error parsing date: $e');
    }
    final data = message['data'] ?? {};
    var type = (message['type'] ?? data['type'] ?? '').toString().toLowerCase();

    // Infer type if it's missing but media data is present
    if (type == '' || type == 'null') {
      if (data['image'] != null) {
        type = 'image';
      } else if (data['video'] != null) {
        type = 'video';
      } else if (data['audio'] != null) {
        type = 'audio';
      } else if (data['document'] != null) {
        type = 'document';
      }
    }

    final isMedia =
        type == 'image' ||
        type == 'video' ||
        type == 'audio' ||
        type == 'document' ||
        data['image'] != null ||
        data['video'] != null ||
        data['document'] != null;
    final isInteractive =
        type == 'interactive' ||
        type == 'button' ||
        type == 'template' ||
        type == 'list' ||
        type == 'order_details' ||
        type == 'marketing' ||
        type == 'authentication' ||
        type == 'utility' ||
        data['template'] != null ||
        data['interactive'] != null ||
        message['template'] != null ||
        message['interactive'] != null;

    // Time and tick: dark on light green (sent) for clear visibility; high-contrast on received in dark theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleBg = isMe
        ? const Color(0xFFD9FDD3)
        : (isDark ? cs.surfaceContainerHighest : cs.surface);
    final timeTickColor = isMe
        ? const Color(0xFF1A1A1A)
        : (isDark ? Colors.white70 : cs.onSurface);
    final contentColor = isMe
        ? const Color(0xFF0D0D0D)
        : (isDark ? Colors.white : cs.onSurface);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4, top: 4, left: 8, right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: availableWidth * 0.75),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withOpacity(0.06),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message['contextReply'] != null &&
                  message['contextReply']['repliedMessage'] != null)
                _wrapReplyPreview(
                  child: _buildContextReplyBlock(message),
                  onTap: () => _scrollToMessageById(_getRepliedToMessageId(message)),
                ),
              if (message['replyTo'] != null)
                _wrapReplyPreview(
                  child: _buildQuotedMessage(message['replyTo'], isMe),
                  onTap: () => _scrollToMessageById(_getRepliedToMessageId(message)),
                ),
              if (isMedia)
                _buildMediaContent(message, isMe)
              else if (isInteractive)
                _buildInteractiveContent(message, isMe)
              else
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    color: contentColor,
                  ),
                ),
              Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(color: timeTickColor, fontSize: 10),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildMessageStatusIcon(message, timeTickColor),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the message status icon for outgoing messages: failed (red icon with tooltip),
  /// sent (gray double tick), or read (blue double tick) — matches web behavior.
  /// On failed: tap shows a tooltip above the icon with the delivery issue and a close button.
  /// [timeTickColor] is used for sent/delivered so it matches the timestamp and is visible on the bubble.
  Widget _buildMessageStatusIcon(dynamic message, Color timeTickColor) {
    final statusStr = message['status']?.toString().toLowerCase();
    final isFailed = statusStr == 'failed';
    if (isFailed) {
      final errorReason = _getFailedMessageReason(message);
      return Tooltip(
        message: errorReason,
        preferBelow: false,
        child: Builder(
          builder: (ctx) {
            return InkWell(
              onTap: () => _showFailedMessageReasonOverlay(ctx, errorReason),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Icon(
                  Icons.error_outline,
                  size: 14,
                  color: const Color(0xFFE53935), // Same red as web failure icon
                ),
              ),
            );
          },
        ),
      );
    }
    // Blue tick only when message is read (match web: chat?.status === "read")
    final isRead = statusStr == 'read' || message['lastMessageRead'] == true;
    return Icon(
      Icons.done_all,
      size: 14,
      color: isRead
          ? const Color(0xFF34B7F1) // WhatsApp-style blue when read (same as web)
          : timeTickColor, // Visible on bubble (sent/delivered)
    );
  }

  /// Extracts the failure reason from message.error (matches web/backend: title, message, reason, or raw error).
  String _getFailedMessageReason(dynamic message) {
    final err = message['error'];
    if (err == null) return 'Message not sent';
    if (err is String && err.trim().isNotEmpty) return err.trim();
    if (err is Map) {
      final title = err['title']?.toString().trim();
      final msg = err['message']?.toString().trim();
      final reason = err['reason']?.toString().trim();
      if (title?.isNotEmpty == true) return title!;
      if (msg?.isNotEmpty == true) return msg!;
      if (reason?.isNotEmpty == true) return reason!;
    }
    return 'Message not sent';
  }

  /// Shows the failed message reason in a dark tooltip above the error icon, with a small close icon at top right.
  void _showFailedMessageReasonOverlay(BuildContext iconContext, String reason) {
    final RenderBox? box = iconContext.findRenderObject() as RenderBox?;
    if (box == null || !mounted) return;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    final overlay = Overlay.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    const padding = 12.0;
    const maxWidth = 280.0;
    const gapAboveIcon = 8.0;

    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: (offset.dx + size.width / 2 - maxWidth / 2).clamp(padding, screenWidth - maxWidth - padding),
        bottom: screenHeight - offset.dy + gapAboveIcon,
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF424242),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      reason,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      overlayEntry?.remove();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(overlayEntry);
  }

  /// Opens a full-screen preview for the given image URL (chat images tap-to-preview).
  void _showImagePreview(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 64, color: Colors.white70),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 8),
                    child: Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(24),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 24),
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMessageCaption(dynamic message) {
    final data = message['data'] ?? {};
    final type = (message['type'] ?? data['type'] ?? '')
        .toString()
        .toLowerCase();

    if (type == 'image' && data['image'] != null) {
      return data['image']['caption'] ?? '';
    }
    if (type == 'video' && data['video'] != null) {
      return data['video']['caption'] ?? '';
    }
    if (type == 'document' && data['document'] != null) {
      return data['document']['caption'] ?? '';
    }

    // Try fallback locations
    return data['caption'] ?? '';
  }

  Widget _buildMediaContent(dynamic message, bool isMe) {
    final data = message['data'] ?? {};
    var type = (message['type'] ?? data['type'] ?? '').toString().toLowerCase();

    // Infer type if it's missing
    if (type == '' || type == 'null') {
      if (data['image'] != null) {
        type = 'image';
      } else if (data['video'] != null) {
        type = 'video';
      } else if (data['audio'] != null) {
        type = 'audio';
      } else if (data['document'] != null) {
        type = 'document';
      }
    }

    final caption = _getMessageCaption(message);

    debugPrint('Chat Debug: Building Media Content');
    debugPrint('Chat Debug: Message Type: ${message['type']}');
    debugPrint('Chat Debug: Data Type: ${data['type']}');
    debugPrint('Chat Debug: Combined Type: $type');
    debugPrint('Chat Debug: Media Data: $data');
    debugPrint('Chat Debug: Caption: $caption');

    // Check for image in multiple locations (matching web implementation)
    String? imageLink;
    if (type == 'image') {
      imageLink = data['image']?['link'] ?? data['link'];
    } else if (data['interactive']?['header']?['type'] == 'image') {
      imageLink = data['interactive']['header']['image']?['link'];
    } else if (data['template'] != null) {
      // Sometimes templates have images in components. API may return components as List or Map.
      final raw = data['template']['components'];
      final List<dynamic> components = raw is List
          ? raw
          : (raw is Map ? raw.values.toList() : <dynamic>[]);
      for (var comp in components) {
        if (comp is! Map) continue;
        if (comp['type'] == 'HEADER' && comp['format'] == 'IMAGE') {
          final handle = comp['example']?['header_handle'];
          imageLink = (handle is List && handle.isNotEmpty)
              ? handle[0]?.toString()
              : (handle is Map ? handle[0] ?? handle['0'] : null);
          imageLink ??= comp['link']?.toString();
          if (imageLink != null && imageLink.isNotEmpty) break;
        }
      }
    }

    debugPrint('Chat Debug: Detected imageLink: $imageLink');

    Widget? mediaWidget;

    if (imageLink != null && imageLink.isNotEmpty) {
      mediaWidget = GestureDetector(
        onTap: () => _showImagePreview(context, imageLink!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageLink,
            width: 280,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading image: $error');
            final errCs = Theme.of(context).colorScheme;
            return Container(
              width: 280,
              height: 200,
              decoration: BoxDecoration(
                color: errCs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 50, color: errCs.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text(
                    'Image not available',
                    style: TextStyle(color: errCs.onSurfaceVariant),
                  ),
                ],
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            final loadCs = Theme.of(context).colorScheme;
            return Container(
              width: 280,
              height: 200,
              decoration: BoxDecoration(
                color: loadCs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        ),
        ),
      );
    }

    // Check for video
    String? videoLink;
    if (type == 'video') {
      videoLink =
          data['video']?['link'] ??
          message['video']?['link'] ??
          data['link'] ??
          data['url'] ??
          message['url'] ??
          data['file'];
    } else if (data['interactive']?['header']?['type'] == 'video' ||
        data['interactive']?['type'] == 'video') {
      videoLink =
          data['interactive']?['header']?['video']?['link'] ??
          data['interactive']?['video']?['link'] ??
          data['interactive']?['header']?['video']?['url'] ??
          data['interactive']?['video']?['url'];
    }

    debugPrint('Chat Debug: Detected videoLink: $videoLink');

    if (videoLink != null && videoLink.isNotEmpty) {
      mediaWidget = VideoMessagePlayer(videoUrl: videoLink);
    }

    // Check for audio
    String? audioLink;
    if (type == 'audio') {
      audioLink = data['audio']?['link'] ?? data['link'];
    } else if (data['interactive']?['header']?['type'] == 'audio') {
      audioLink = data['interactive']['header']['audio']?['link'];
    }

    debugPrint('Chat Debug: Detected audioLink: $audioLink');

    if (audioLink != null && audioLink.isNotEmpty) {
      mediaWidget = VoiceMessagePlayer(audioUrl: audioLink, isMe: isMe);
    }

    // Check for document
    String? documentLink;
    String? documentFilename;
    if (type == 'document') {
      documentLink = data['document']?['link'] ?? data['link'];
      documentFilename = data['document']?['filename'];
    } else if (data['interactive']?['header']?['type'] == 'document') {
      documentLink = data['interactive']['header']['document']?['link'];
      documentFilename = data['interactive']['header']['document']?['filename'];
    }

    debugPrint('Chat Debug: Detected documentLink: $documentLink');

    if (documentLink != null && documentLink.isNotEmpty) {
      final docUrl = documentLink;
      final docName = documentFilename ?? 'Document';
      final docCs = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final docTextColor = isMe
          ? const Color(0xFF0D0D0D)
          : (isDark ? Colors.white : docCs.onSurface);
      final docIconColor = isMe
          ? const Color(0xFF1A1A1A)
          : (isDark ? Colors.white70 : docCs.onSurfaceVariant);
      mediaWidget = InkWell(
        onTap: () => _openDocument(docUrl, docName),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFE8F5E9) : docCs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isMe ? const Color(0xFFC8E6C9) : docCs.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file, color: Colors.red, size: 32),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  docName,
                  style: TextStyle(fontSize: 14, color: docTextColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.open_in_new, size: 18, color: docIconColor),
            ],
          ),
        ),
      );
    }

    if (mediaWidget != null) {
      final cs = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final captionColor = isMe
          ? const Color(0xFF0D0D0D)
          : (isDark ? Colors.white : cs.onSurface);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          mediaWidget,
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
              child: Text(
                caption,
                style: TextStyle(
                  fontSize: 15,
                  color: captionColor,
                ),
              ),
            ),
        ],
      );
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fallbackColor = isMe
        ? const Color(0xFF0D0D0D)
        : (isDark ? Colors.white70 : cs.onSurfaceVariant);
    return Text(
      '[Media: $type]',
      style: TextStyle(color: fallbackColor),
    );
  }

  Widget _buildInteractiveContent(dynamic message, bool isMe) {
    final data = message['data'] ?? {};

    // Interactive data
    var interactive = data['interactive'];
    if (interactive == null && message['interactive'] != null) {
      interactive = message['interactive'];
    }
    interactive ??= {};

    final body = interactive['body'] ?? {};
    final header = interactive['header'] ?? {};
    final footer = interactive['footer'] ?? {};
    final action = interactive['action'] ?? {};

    // Template data
    var template = data['template'];
    if (template == null && message['template'] != null) {
      template = message['template'];
    }
    template ??= {};

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryBtnColor = const Color(0xFF1EA443);
    final Color contentMutedColor = isMe
        ? const Color(0xFF1A1A1A)
        : (isDark ? Colors.white70 : cs.onSurfaceVariant);
    final Color secondaryTextColor = contentMutedColor;
    final Color btnBgColor = cs.surface;
    final Color btnBorderColor = cs.outline.withOpacity(0.5);
    final Color dividerColor = isMe ? const Color(0xFF1EA443) : cs.outline;
    final Color contentTextColor = isMe
        ? const Color(0xFF0D0D0D)
        : (isDark ? Colors.white : cs.onSurface);

    if (interactive['type'] == 'product_list') {
      return _buildProductList(interactive, isMe);
    }

    if (interactive['type'] == 'order_details' ||
        message['type'] == 'order_details') {
      return _buildOrderDetails(message, isMe);
    }

    // Check for List type (standard list message)
    if (interactive['type'] == 'list') {
      final listButtonText = _resolveText(action['button'] ?? 'Menu');
      final headerText = _resolveText(header['text'] ?? header);
      final bodyTextList = _resolveText(body['text'] ?? body);
      final footerTextList = _resolveText(footer['text'] ?? footer);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (headerText.isNotEmpty)
            Text(
              headerText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: contentTextColor,
              ),
            ),
          if (bodyTextList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                bodyTextList,
                style: TextStyle(
                  fontSize: 16,
                  color: contentTextColor,
                ),
              ),
            ),
          if (footerTextList.isNotEmpty)
            Text(
              footerTextList,
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list, color: primaryBtnColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    listButtonText,
                    style: TextStyle(
                      color: primaryBtnColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Handle Carousel
    if (template['subType'] == 'carousel' ||
        (template['cards'] as List?)?.isNotEmpty == true) {
      return _buildCarousel(template, isMe);
    }

    // Determine content to show with variable substitution (resolve localized text like web)
    var bodyText = _resolveText(body['text'] ?? body);
    if (bodyText.isEmpty) bodyText = _resolveText(template['message']);
    final footerText = _resolveText(footer['text'] ?? footer);

    if (bodyText.isNotEmpty && template['variables'] != null) {
      final vars = template['variables'];
      if (vars is Map) {
        vars.forEach((k, v) {
          bodyText = bodyText.replaceAll('{{$k}}', v.toString());
        });
      }
    }

    // Handle header (text or media)
    final hType = (template['headerType'] ?? '').toString().toLowerCase();
    final hValue = template['header']?.toString();
    Widget? headerWidget;
    final hasHeaderText = header['text'] != null ||
        header['en'] != null ||
        header['ar'] != null;
    final headerResolved = _resolveText(header['text'] ?? header);

    if (hasHeaderText && headerResolved.isNotEmpty) {
      headerWidget = Text(
        headerResolved,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: contentTextColor,
        ),
      );
    } else if (hValue != null && hValue.isNotEmpty) {
      if (hType == 'image') {
        headerWidget = _buildTemplateMediaHeader(
          hValue,
          Icons.image,
          onImageTap: () => _showImagePreview(context, hValue),
        );
      } else if (hType == 'video') {
        headerWidget = _buildTemplateMediaHeader(
          hValue,
          Icons.videocam,
          isVideo: true,
        );
      } else if (hType == 'document') {
        headerWidget = _buildTemplateMediaHeader(hValue, Icons.description);
      } else if (hType == 'text') {
        headerWidget = Text(
          hValue,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: contentTextColor,
          ),
        );
      }
    } else if (template['title'] != null && hType != 'none') {
      headerWidget = Text(
        template['title'],
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: contentTextColor,
        ),
      );
    }

    // Combine buttons - prioritizing template actions as per Web
    final buttons = action['buttons'] as List<dynamic>? ?? [];
    final templateActions = template['actions'] as List<dynamic>? ?? [];

    final List<dynamic> allButtons = [];

    if (templateActions.isNotEmpty) {
      allButtons.addAll(templateActions);
    } else if (buttons.isNotEmpty) {
      allButtons.addAll(buttons);
    } else {
      // Fallback: check template['buttons'] or template['components']
      final templateButtons = template['buttons'] as List<dynamic>? ?? [];
      if (templateButtons.isNotEmpty) {
        allButtons.addAll(templateButtons);
      } else {
        final rawComp = template['components'];
        final List<dynamic> components = rawComp is List
            ? rawComp
            : (rawComp is Map ? rawComp.values.toList() : <dynamic>[]);
        for (var c in components) {
          if (c is! Map) continue;
          if (c['type'] == 'BUTTONS') {
            final compButtons = c['buttons'] is List
                ? (c['buttons'] as List).cast<dynamic>()
                : <dynamic>[];
            allButtons.addAll(compButtons);
          }
        }
      }
    }

    // Check for Flow text (special interactive type)
    if (interactive['type'] == 'flow') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (headerWidget != null) headerWidget,
        if (bodyText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              bodyText,
              style: TextStyle(
                fontSize: 16,
                color: contentTextColor,
              ),
            ),
          ),
          if (footerText.isNotEmpty)
            Text(
              footerText,
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Icon(Icons.open_in_new, color: primaryBtnColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  action['parameters']?['flow_cta'] ?? 'Open',
                  style: TextStyle(
                    color: primaryBtnColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Check for CTA URL type (special interactive type)
    if (interactive['type'] == 'cta_url') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (headerWidget != null) headerWidget,
        if (bodyText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              bodyText,
              style: TextStyle(
                fontSize: 16,
                color: contentTextColor,
              ),
            ),
          ),
          if (footerText.isNotEmpty)
            Text(
              footerText,
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Icon(Icons.link, color: primaryBtnColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  action['parameters']?['display_text'] ?? 'Visit Website',
                  style: TextStyle(
                    color: primaryBtnColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (headerWidget != null) headerWidget,
        if (bodyText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              bodyText,
              style: TextStyle(
                fontSize: 16,
                color: contentTextColor,
              ),
            ),
          ),
        if (footerText.isNotEmpty)
          Text(
            footerText,
            style: TextStyle(fontSize: 12, color: secondaryTextColor),
          ),
        const SizedBox(height: 8),
        // Render All Buttons
        ...allButtons.map((btn) {
          String btnTitle = 'Button';
          // Normalize type for robustness
          String btnType = (btn['type'] ?? 'reply').toString();
          String typeLower = btnType.toLowerCase();

          if (btn.containsKey('reply')) {
            btnTitle = btn['reply']['title'] ?? 'Button';
          } else if (btn.containsKey('text')) {
            btnTitle = btn['text'] ?? 'Button';
          }

          // Variable substitution in buttons
          if (template['variables'] != null) {
            final vars = template['variables'];
            if (vars is Map) {
              vars.forEach((k, v) {
                btnTitle = btnTitle.replaceAll('{{$k}}', v.toString());
              });
            }
          }

          IconData btnIcon = Icons.reply;

          if (typeLower == 'phone' || typeLower == 'phone_number') {
            btnIcon = Icons.phone;
          } else if (typeLower == 'url') {
            btnIcon = Icons.open_in_new;
          } else if (typeLower == 'flow') {
            btnIcon = Icons.edit;
          } else if (typeLower == 'quickreply' ||
              typeLower == 'quick_reply' ||
              typeLower == 'reply') {
            // Contextual icons based on title
            if (btnTitle.toLowerCase().contains('ticket')) {
              btnIcon = Icons.confirmation_number_outlined;
            } else if (btnTitle.toLowerCase().contains('choose')) {
              btnIcon = Icons.check_circle_outline;
            } else if (btnTitle.toLowerCase().contains('test')) {
              btnIcon = Icons.edit_outlined;
            } else if (btnTitle.toLowerCase().contains('fill')) {
              btnIcon = Icons.edit_note;
            } else {
              btnIcon = Icons.reply;
            }
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: double.infinity,
              decoration: BoxDecoration(
                color: btnBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: btnBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withOpacity(0.06),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () => _handleButtonClick(btn),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(btnIcon, size: 18, color: primaryBtnColor),
                      const SizedBox(width: 8),
                      Text(
                        btnTitle,
                        style: TextStyle(
                          color: primaryBtnColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        // Review and Pay Special Action
        if (action['name'] == 'review_and_pay')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              width: double.infinity,
              decoration: BoxDecoration(
                color: btnBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: btnBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withOpacity(0.06),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payment, color: primaryBtnColor),
                  const SizedBox(width: 8),
                  Text(
                    'Review and Pay',
                    style: TextStyle(
                      color: primaryBtnColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: primaryBtnColor, size: 18),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProductList(dynamic interactive, bool isMe) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentColor = isMe ? const Color(0xFF1A1A1A) : cs.onSurface;
    final mutedColor = isMe ? const Color(0xFF2D2D2D) : (isDark ? Colors.white70 : cs.onSurfaceVariant);
    final cardBg = isMe ? const Color(0xFFC1F0C1) : (isDark ? cs.surfaceContainerHighest : cs.surface);
    final body = interactive['body'] ?? {};
    final action = interactive['action'] ?? {};
    final sections = action['sections'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_resolveText(body['text'] ?? body).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              _resolveText(body['text'] ?? body),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: contentColor,
              ),
            ),
          ),
        ...sections.map((section) {
          final items = section['product_items'] as List<dynamic>? ?? [];
          final sectionTitle = _resolveText(section['title'] ?? section);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sectionTitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    sectionTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: contentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ...items.map((item) {
                final retailerId = item['product_retailer_id']?.toString();
                // Try to find matching product in our global list
                final matchedProduct = _products.firstWhere(
                  (p) =>
                      p['productId']?.toString() == retailerId ||
                      p['retailerId']?.toString() == retailerId,
                  orElse: () => null,
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isMe
                          ? const Color(0xFF1EA443)
                          : cs.outline.withOpacity(0.3),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child:
                          matchedProduct != null &&
                              matchedProduct['productImage'] != null
                          ? GestureDetector(
                              onTap: () => _showImagePreview(
                                context,
                                matchedProduct!['productImage'].toString(),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  matchedProduct['productImage'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) =>
                                      const Icon(Icons.shopping_bag_outlined),
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.shopping_bag_outlined,
                              color: const Color(0xFF1EA443),
                            ),
                    ),
                    title: Text(
                      matchedProduct != null
                          ? (matchedProduct['name'] ?? 'Product')
                          : (retailerId ?? 'Product'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: contentColor,
                      ),
                    ),
                    subtitle: matchedProduct != null
                        ? Text(
                            '${matchedProduct['price']} ${matchedProduct['currency'] ?? 'INR'}',
                            style: TextStyle(color: mutedColor),
                          )
                        : null,
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: mutedColor,
                    ),
                    onTap: () {
                      if (matchedProduct != null &&
                          matchedProduct['link'] != null) {
                        final uri = Uri.tryParse(matchedProduct['link']);
                        if (uri != null) launchUrl(uri);
                      }
                    },
                  ),
                );
              }),
            ],
          );
        }),
      ],
    );
  }

  Future<void> _handleButtonClick(dynamic btn) async {
    String type = (btn['type'] ?? 'reply').toString().toLowerCase();
    String? url;
    String? phone;
    String? text;

    if (btn.containsKey('url')) {
      url = btn['url'];
    } else if (btn['parameters'] != null && btn['parameters']['url'] != null) {
      url = btn['parameters']['url'];
    }

    if (btn.containsKey('phone_number')) {
      phone = btn['phone_number'];
    }

    if (btn['reply'] != null) {
      text = btn['reply']['title'];
    } else if (btn.containsKey('text')) {
      text = btn['text'];
    }

    if (type == 'url' && url != null) {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } else if ((type == 'phone' || type == 'phone_number') && phone != null) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } else {
      // Quick Reply - send message
      if (text != null) {
        _messageController.text = text;
        _sendMessage();
      }
    }
  }

  Widget _buildOrderDetails(dynamic message, bool isMe) {
    final cs = Theme.of(context).colorScheme;
    final data = message['data'] ?? {};
    final interactive = data['interactive'] ?? {};
    final action = interactive['action'] ?? {};
    final parameters = action['parameters'] ?? {};
    final order = parameters['order'] ?? {};
    final items = order['items'] as List<dynamic>? ?? [];

    // Fallback or specific values
    final totalAmount =
        order['total_amount']?['value'] ??
        parameters['total_amount']?['value'] ??
        0;
    final currency =
        order['total_amount']?['currency'] ??
        parameters['total_amount']?['currency'] ??
        'INR';
    final itemCount = items.length;
    final firstItemName = items.isNotEmpty ? items[0]['name'] : 'Item';
    final orderId = parameters['reference_id'] ?? 'ORDER-XXXX';
    // Default status is pending

    // Try to get image from first item
    String? imageUrl;
    if (items.isNotEmpty && items[0]['image'] != null) {
      imageUrl = items[0]['image']['link'];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Cart Summary Bubble
        Container(
          width: 260,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withOpacity(0.06),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF1EA443),
                    radius: 20,
                    child: Icon(
                      Icons.shopping_cart,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$itemCount item${itemCount != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          '$currency ${(totalAmount / 100).toStringAsFixed(2)} (estimated total)',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(height: 1),
              ),
              InkWell(
                onTap: () {}, // Action for viewing cart
                child: const Row(
                  children: [
                    Icon(Icons.list_alt, size: 16, color: Color(0xFF1EA443)),
                    SizedBox(width: 8),
                    Text(
                      'View sent cart',
                      style: TextStyle(
                        color: const Color(0xFF1EA443),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. Order Details Card (Light Green)
        Container(
          width: 260,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE7FFDB), // Light green background
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1EA443).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Image
              if (imageUrl != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: GestureDetector(
                    onTap: () => _showImagePreview(context, imageUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          height: 140,
                          color: Colors.grey[200],
                          child: const Icon(Icons.shopping_bag, size: 40),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Center(
                    child: Icon(
                      Icons.request_quote_outlined,
                      size: 60,
                      color: const Color(0xFF1EA443),
                    ),
                  ),
                ),

              // Order text (light green card: use dark text for readability)
              Text(
                'ORDER',
                style: TextStyle(
                  fontSize: 11,
                  color: isMe ? const Color(0xFF2D2D2D) : const Color(0xFF5A5A5A),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '#$orderId',
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              const Divider(height: 1),
              const SizedBox(height: 8),

              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.outline.withOpacity(0.3)),
                    ),
                    child: imageUrl != null
                        ? GestureDetector(
                            onTap: () => _showImagePreview(context, imageUrl!),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(imageUrl, fit: BoxFit.cover),
                            ),
                          )
                        : const Icon(
                            Icons.shopping_bag_outlined,
                            color: const Color(0xFF1EA443),
                            size: 20,
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstItemName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$itemCount item${itemCount != 1 ? 's' : ''}',
                          style: TextStyle(
                            color: isMe ? const Color(0xFF2D2D2D) : const Color(0xFF5A5A5A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isMe ? const Color(0xFF1A1A1A) : null,
                    ),
                  ),
                  Text(
                    '$currency ${(totalAmount / 100).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isMe ? const Color(0xFF1A1A1A) : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),

              // Review and Pay Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () =>
                      _handleButtonClick({'text': 'Review and pay'}),
                  child: const Text(
                    'Review and pay',
                    style: TextStyle(
                      color: const Color(0xFF1EA443),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const Divider(height: 1),

              // Pay Now
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _handleButtonClick({'text': 'Pay now'}),
                  child: const Text(
                    'Pay now',
                    style: TextStyle(
                      color: const Color(0xFF1EA443),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Wraps the reply preview so tapping it scrolls to the original message (WhatsApp-style).
  Widget _wrapReplyPreview({required Widget child, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );
  }

  /// Builds the reply preview block for messages with contextReply (repliedWamid, repliedMessage).
  /// Matches web: grey background #f0f2f5, green left border #25D366, 13px text color #444.
  Widget _buildContextReplyBlock(dynamic message) {
    final replyText = _getRepliedTextFromContextReply(message);
    if (replyText.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFF25D366), width: 4),
        ),
      ),
      child: Text(
        replyText,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF444444),
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildQuotedMessage(dynamic message, bool isMe) {
    final cs = Theme.of(context).colorScheme;
    final contextData = message['context'] ?? {};
    // Prefer full message text (replyTo can be full message object), then context.body
    String replyToText = _getMessageText(message);
    if (replyToText.isEmpty) {
      replyToText = _resolveText(contextData['body']);
    }
    if (replyToText.isEmpty) replyToText = 'Original message';

    // Split into first line (green bold header) and rest (grey subtext), like reference
    final firstNewLine = replyToText.indexOf('\n');
    String quotedHeader;
    String quotedBody;
    if (firstNewLine >= 0) {
      quotedHeader = replyToText.substring(0, firstNewLine).trim();
      quotedBody = replyToText.substring(firstNewLine + 1).trim();
    } else if (replyToText.length > 50) {
      quotedHeader = '${replyToText.substring(0, 50).trim()}...';
      quotedBody = replyToText.substring(50).trim();
    } else {
      quotedHeader = replyToText;
      quotedBody = '';
    }
    if (quotedHeader.isEmpty) {
      quotedHeader = replyToText;
      quotedBody = '';
    }

    const greenAccent = Color(0xFF1EA443);
    const darkGreen = Color(0xFF0D5C1F);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: cs.brightness == Brightness.dark
            ? cs.onSurface.withOpacity(0.08)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          left: BorderSide(color: greenAccent, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isMe ? 'You' : widget.profileName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: greenAccent,
            ),
          ),
          if (quotedHeader.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                quotedHeader,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: darkGreen,
                ),
              ),
            ),
          if (quotedBody.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                quotedBody,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: isMe ? const Color(0xFF0D0D0D) : cs.onSurfaceVariant,
                ),
              ),
            ),
          if (quotedBody.isEmpty && quotedHeader.isNotEmpty)
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildBlockedFooter() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline.withOpacity(0.5))),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'This user is blocked',
            style: TextStyle(
              color: Color(0xFFDC3545),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Unblock to resume conversation',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showBlockConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC3545),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Unblock User',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Resolves display text from API value that may be a string or a map with language keys
  /// (e.g. { "en": "English text", "ar": "Arabic text" }). Prefers 'en' then 'text' to match web.
  /// Never returns "{}" or object-like strings so chat never shows bracket placeholders.
  static String _resolveText(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is Map) {
      final en = value['en']?.toString().trim();
      if (en != null && en.isNotEmpty) return en;
      final text = value['text']?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
      final ar = value['ar']?.toString().trim();
      if (ar != null && ar.isNotEmpty) return ar;
      for (final v in value.values) {
        if (v is Map) continue; // skip nested objects
        final s = v?.toString().trim();
        if (s != null && s.isNotEmpty && s != '{}') return s;
      }
      return ''; // never return "{}" for Map
    }
    final s = value.toString().trim();
    if (s == '{}' || s.startsWith('Instance of ')) return '';
    return s;
  }

  /// Extracts display text from a message, combining all parts (header + body, template components)
  /// so app shows the same content as web. Handles data.body and data.text.body to avoid "{}" display.
  String _getMessageText(dynamic message) {
    if (message == null) return '';

    if (message['text'] != null && message['text']['body'] != null) {
      final t = _resolveText(message['text']['body']);
      if (t.isNotEmpty && t != '{}') return t;
    }

    if (message['data'] != null) {
      final data = message['data'] as Map;

      if (data['text'] != null && data['text']['body'] != null) {
        final t = _resolveText(data['text']['body']);
        if (t.isNotEmpty && t != '{}') return t;
      }

      // Direct body (some APIs/store use data.body)
      if (data['body'] != null) {
        final t = _resolveText(data['body']);
        if (t.isNotEmpty && t != '{}') return t;
      }

      if (data['message'] != null) {
        final t = _resolveText(data['message']);
        if (t.isNotEmpty && t != '{}') return t;
      }

      if (data['interactive'] != null) {
        final i = data['interactive'];
        final header = _resolveText(i['header']?['text'] ?? i['header']);
        final body = _resolveText(i['body']?['text'] ?? i['body']);
        if (header.isNotEmpty && body.isNotEmpty) {
          return '$header\n$body';
        }
        return body.isNotEmpty ? body : (header.isNotEmpty ? header : '[Interactive]');
      }

      if (data['template'] != null) {
        final t = data['template'];
        final parts = <String>[];
        if (t['message'] != null) parts.add(_resolveText(t['message']));
        final comps = t['components'];
        if (comps is List) {
          for (final c in comps) {
            if (c is! Map) continue;
            final type = (c['type'] ?? '').toString().toUpperCase();
            dynamic textVal = c['text'];
            if (textVal == null && c['parameters'] is List && (c['parameters'] as List).isNotEmpty) {
              final param = (c['parameters'] as List).first;
              if (param is Map) textVal = param['text'];
            }
            final text = _resolveText(textVal);
            if (type == 'HEADER' && text.isNotEmpty) {
              parts.insert(0, text);
            } else if ((type == 'BODY' || type == 'TEXT') && text.isNotEmpty) {
              parts.add(text);
            }
          }
        }
        if (parts.isNotEmpty) return parts.join('\n');
      }
    }

    if (message['message'] != null) {
      final t = _resolveText(message['message']);
      if (t.isNotEmpty && t != '{}') return t;
    }

    if (message['body'] != null) {
      final t = _resolveText(message['body']);
      if (t.isNotEmpty && t != '{}') return t;
    }

    final type = message['type'];
    if (type == 'image') return '[Image]';
    if (type == 'video') return '[Video]';
    if (type == 'audio') return '[Audio]';
    if (type == 'document') return '[Document]';

    return '';
  }

  /// Returns display text for contextReply.repliedMessage (reply messages from API).
  /// Matches web getRepliedText: text, template, interactive (body/header/footer), image, video, document, audio.
  String _getRepliedTextFromContextReply(dynamic message) {
    final contextReply = message?['contextReply'];
    if (contextReply == null) return '';
    final reply = contextReply['repliedMessage'];
    if (reply == null || reply is! Map) return '';

    // repliedMessage can be top-level payload (type, text, interactive, ...) or under data
    final data = reply['data'] ?? reply;
    if (data is! Map) return '';

    final type = (reply['type'] ?? data['type'] ?? '').toString().toLowerCase();

    if (type == 'text' || data['text'] != null) {
      final body = data['text']?['body'] ?? reply['text']?['body'];
      final t = _resolveText(body);
      if (t.isNotEmpty) return t;
    }

    if (type == 'marketing' || data['template'] != null || reply['template'] != null) {
      final t = data['template'] ?? reply['template'];
      if (t is Map) {
        final msg = _resolveText(t['message'] ?? t['header']);
        if (msg.isNotEmpty) return msg;
      }
    }

    if (type == 'interactive' || data['interactive'] != null || reply['interactive'] != null) {
      final i = data['interactive'] ?? reply['interactive'];
      if (i is Map) {
        final body = _resolveText(i['body']?['text'] ?? i['body']);
        final header = _resolveText(i['header']?['text'] ?? i['header']);
        final footer = _resolveText(i['footer']?['text'] ?? i['footer']);
        if (body.isNotEmpty) return body;
        if (header.isNotEmpty) return header;
        if (footer.isNotEmpty) return footer;
      }
    }

    if (type == 'image' || data['image'] != null) {
      final cap = data['image']?['caption'] ?? reply['image']?['caption'];
      return _resolveText(cap).isNotEmpty ? _resolveText(cap) : 'Image';
    }
    if (type == 'video' || data['video'] != null) {
      final cap = data['video']?['caption'] ?? reply['video']?['caption'];
      return _resolveText(cap).isNotEmpty ? _resolveText(cap) : 'Video';
    }
    if (type == 'document' || data['document'] != null) {
      final cap = data['document']?['caption'] ?? reply['document']?['caption'];
      return _resolveText(cap).isNotEmpty ? _resolveText(cap) : 'Document';
    }
    if (type == 'audio' || data['audio'] != null) return 'Audio';

    return 'Unsupported message';
  }

  bool _isValidMessage(dynamic message) {
    if (message == null) return false;
    final data = message['data'] ?? {};
    final type = (message['type'] ?? data['type'] ?? '')
        .toString()
        .toLowerCase();

    // Check for Media
    if (type == 'image' ||
        type == 'video' ||
        type == 'audio' ||
        type == 'document' ||
        data['image'] != null ||
        data['video'] != null ||
        data['document'] != null ||
        data['sticker'] != null) {
      return true;
    }

    // Check for Interactive/Template
    if (type == 'interactive' ||
        type == 'button' ||
        type == 'template' ||
        type == 'list' ||
        type == 'order_details' ||
        type == 'marketing' ||
        type == 'authentication' ||
        type == 'utility' ||
        data['template'] != null ||
        data['interactive'] != null ||
        message['template'] != null ||
        message['interactive'] != null) {
      return true;
    }

    // Check for Text
    final text = _getMessageText(message);
    if (text.trim().isNotEmpty) return true;

    return false;
  }

  void _showMessageOptions(dynamic message) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: Color(0xFF1EA443)),
              title: const Text('Reply'),
              onTap: () {
                setState(() => _replyingToMessage = message);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyingToBar() {
    final cs = Theme.of(context).colorScheme;
    final msg = _replyingToMessage;
    if (msg == null) return const SizedBox.shrink();
    final preview = _getMessageText(msg);
    final previewText = preview.isEmpty
        ? 'Original message'
        : (preview.length > 60 ? '${preview.substring(0, 60)}...' : preview);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.8),
        border: Border(
          left: BorderSide(color: const Color(0xFF1EA443), width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (msg['sentBy'] == 'system' || msg['fromMe'] == true)
                      ? 'Replying to yourself'
                      : 'Replying to ${widget.profileName}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: const Color(0xFF1EA443),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  previewText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => setState(() => _replyingToMessage = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showAttachmentMenu) _buildAttachmentMenu(),
        if (_replyingToMessage != null) _buildReplyingToBar(),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: cs.outline.withOpacity(0.5), width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isRecording
                      ? _buildRecordingBar()
                      : _buildNormalInputRow(),
                ),
              ),
              const SizedBox(width: 6),
              _buildMainActionButton(),
            ],
          ),
        ),
        // Centered cross icon below message input to close intervene (only when intervene is open)
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
          child: Center(
            child: Material(
              color: const Color(0xFF1EA443),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: _isIntervening ? null : _closeChat,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.close_rounded,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalInputRow() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _messageController,
            style: TextStyle(color: cs.onSurface, fontSize: 17),
            onTap: () {
              setState(() {
                if (_showAttachmentMenu) _showAttachmentMenu = false;
              });
            },
            onChanged: (val) {
              setState(() {
                _isTyping = val.isNotEmpty;
              });
            },
            decoration: InputDecoration(
              hintText: 'Message',
              hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 17),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 16,
              ),
            ),
          ),
        ),
        IconButton(
          icon: Transform.rotate(
            angle: -0.7,
            child: Icon(
              Icons.attach_file_rounded,
              color: cs.onSurfaceVariant,
              size: 24,
            ),
          ),
          onPressed: () {
            setState(() {
              _showAttachmentMenu = !_showAttachmentMenu;
            });
          },
        ),
        if (!_isTyping)
          IconButton(
            icon: Icon(
              Icons.camera_alt_rounded,
              color: cs.onSurfaceVariant,
              size: 24,
            ),
            onPressed: () {
              FocusScope.of(context).unfocus();
              _pickAndSendImage(fromCamera: true);
            },
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildRecordingBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recordingTextColor = isDark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Blinking red dot
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: 0.3),
            duration: const Duration(seconds: 1),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: _isPaused ? 1.0 : value,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
            onEnd: () {
              if (mounted && _isRecording && !_isPaused) setState(() {});
            },
          ),
          const SizedBox(width: 12),
          Text(
            _isPaused ? 'Paused' : 'Recording... ${_recordDuration}s',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: recordingTextColor,
            ),
          ),
          const Spacer(),
          // Pause/Resume button (white in dark theme for visibility)
          IconButton(
            icon: Icon(
              _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: isDark ? Colors.white : (_isPaused ? const Color(0xFF1EA443) : Colors.orange),
              size: 24,
            ),
            onPressed: _isPaused ? _resumeRecording : _pauseRecording,
          ),
          // Discard button (white in dark theme for visibility)
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: isDark ? Colors.white : Colors.red,
              size: 24,
            ),
            onPressed: _cancelRecording,
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionButton() {
    return GestureDetector(
      onTap: () {
        if (_isTyping) {
          _sendMessage();
        } else if (_isRecording) {
          _stopRecording();
        } else {
          _startRecording();
        }
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: const Color(0xFF1EA443),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _isTyping ? Icons.send : (_isRecording ? Icons.send : Icons.mic),
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildAttachmentMenu() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // In dark theme use light grey card (not white) so it matches the theme
    final menuBg = isDark ? const Color(0xFF4A4A4A) : Colors.white;
    final labelColor = isDark ? cs.onSurface : const Color(0xFF1F2937);
    final row1 = [
      (Icons.insert_drive_file_rounded, const Color(0xFF7C3AED), 'Document', () => _pickAndSendFile('document')),
      (Icons.photo_library_rounded, const Color(0xFF2563EB), 'Gallery', () => _pickAndSendImage(fromCamera: false)),
      (Icons.camera_alt_rounded, const Color(0xFFE11D48), 'Camera', () => _pickAndSendImage(fromCamera: true)),
      (Icons.videocam_rounded, const Color(0xFFE11D48), 'Video', () => _pickAndSendFile('video')),
    ];
    final row2 = [
      (Icons.headset_rounded, const Color(0xFFF97316), 'Audio', () => _pickAndSendFile('audio')),
      (Icons.description_outlined, const Color(0xFF1EA443), 'Template', _showTemplateDialog),
      (Icons.reply_rounded, const Color(0xFF1EA443), 'Quick Reply', _showQuickReplyDialog),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: menuBg,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: cs.outline.withOpacity(0.3)) : null,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(isDark ? 0.2 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row1.map((item) => Expanded(
              child: _buildAttachmentGridItem(item.$1, item.$2, item.$3, item.$4, labelColor),
            )).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ...row2.map((item) => Expanded(
                child: _buildAttachmentGridItem(item.$1, item.$2, item.$3, item.$4, labelColor),
              )),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentGridItem(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
    Color labelColor,
  ) {
    return InkWell(
      onTap: () {
        setState(() => _showAttachmentMenu = false);
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: labelColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalAttachmentItem(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: () {
        setState(() => _showAttachmentMenu = false);
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentItem(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSidebar(double width) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // In dark theme use a somewhat lighter grey for the scroll form for better visibility.
    final panelBg = isDark ? cs.surfaceContainerHighest : cs.surface;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: panelBg,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: panelBg,
              border: Border(bottom: BorderSide(color: cs.outline.withOpacity(0.5))),
            ),
            child: Row(
              children: [
                Text(
                  'Profile Details',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _showProfileSidebar = false),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.close,
                        color: cs.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isProfileLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildProfileOverview(),
                      _buildSidebarSection(
                        'Assigned Agent',
                        _buildAgentDropdown(),
                      ),
                      _buildSidebarSection(
                        'Status Details',
                        _buildStatusDetails(),
                      ),
                      _buildSidebarSection(
                        'Active Sessions',
                        _buildActiveSessions(),
                      ),
                      _buildSidebarSection('Payments', _buildPaymentsSection()),
                      _buildSidebarSection('Catalogs', _buildCatalogsSection()),
                      _buildSidebarSection(
                        'Customer Journey',
                        _buildJourneySection(),
                      ),
                      _buildSidebarSection('Tags', _buildTagsSection()),
                      _buildSidebarSection('Notes', _buildNotesSection()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOverview() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      width: double.infinity,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1EA443), width: 2),
            ),
            child: CircleAvatar(
              radius: 42,
              backgroundColor: cs.surface,
              child: Text(
                widget.profileName.isNotEmpty
                    ? widget.profileName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 36,
                  color: Color(0xFF1EA443),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.profileName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.contactNumber,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarSection(String title, Widget child) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionBg = isDark ? cs.surfaceContainerHighest : cs.surface;
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: sectionBg,
        border: Border(bottom: BorderSide(color: cs.outline.withOpacity(0.3))),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedBackgroundColor: sectionBg,
          backgroundColor: sectionBg,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: cs.onSurfaceVariant,
              letterSpacing: 1.1,
            ),
          ),
          iconColor: cs.onSurfaceVariant,
          collapsedIconColor: cs.onSurfaceVariant,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentDropdown() {
    final cs = Theme.of(context).colorScheme;
    if (_agents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No agents found',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_assignedAgentIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _assignedAgentIds.map((agentId) {
                final agent = _agents.firstWhere(
                  (a) => a['_id'] == agentId,
                  orElse: () => {'username': 'Unknown', '_id': agentId},
                );
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: cs.outline.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        agent['username'] ?? agent['email'] ?? 'Unknown',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          final newList = List<String>.from(_assignedAgentIds)
                            ..remove(agentId);
                          _assignAgents(newList);
                        },
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        DropdownButtonFormField<String>(
          value: null,
          decoration: InputDecoration(
            hintText: 'Select agent to assign',
            hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
            ),
          ),
          items: _agents.map((agent) {
            final agentId = agent['_id'] as String;
            final isAssigned = _assignedAgentIds.contains(agentId);
            return DropdownMenuItem<String>(
              value: agentId,
              child: Text(
                agent['username'] ?? agent['email'] ?? 'Unknown',
                style: TextStyle(
                  color: isAssigned ? const Color(0xFF1EA443) : cs.onSurface,
                  fontWeight: isAssigned ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            );
          }).toList(),
          onChanged: (agentId) {
            if (agentId != null) {
              final newList = List<String>.from(_assignedAgentIds);
              if (!newList.contains(agentId)) {
                newList.add(agentId);
                _assignAgents(newList);
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildStatusDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<DateTime>(
          valueListenable: _currentTimeNotifier,
          builder: (context, now, child) {
            String activityStatus = 'No user activity';
            if (_lastUserActivity != null) {
              final diff = now.difference(_lastUserActivity!).inSeconds;
              if (diff < 60) {
                activityStatus = 'Active now';
              } else if (diff < 3600) {
                final mins = diff ~/ 60;
                activityStatus = '$mins ${mins == 1 ? "min" : "mins"} ago';
              } else if (diff < 86400) {
                final hrs = diff ~/ 3600;
                activityStatus = '$hrs ${hrs == 1 ? "hr" : "hrs"} ago';
              } else if (diff < 2592000) {
                final days = diff ~/ 86400;
                activityStatus = '$days ${days == 1 ? "day" : "days"} ago';
              } else {
                activityStatus = DateFormat(
                  'dd MMM',
                ).format(_lastUserActivity!);
              }
            }
            return _buildStatusRow(
              'User Active Status',
              activityStatus,
              isHighlighted: activityStatus == 'Active now',
            );
          },
        ),
        const SizedBox(height: 14),
        _buildStatusRow(
          'Last Active Conversation',
          _lastUserActivity != null
              ? DateFormat('dd/MM/yyyy hh:mm a').format(_lastUserActivity!)
              : '-',
        ),
        const SizedBox(height: 14),
        _buildStatusRow('Template Messages', _templateMsgCount.toString()),
        const SizedBox(height: 14),
        _buildStatusRow('Session Messages', _sessionMsgCount.toString()),
        const SizedBox(height: 14),
        _buildStatusRow(
          'First User Message',
          _firstUserMsg.isEmpty || _firstUserMsg == 'N/A' ? '-' : _firstUserMsg,
          maxLines: 2,
        ),
        const SizedBox(height: 14),
        _buildLeadStatusRow(),
        const SizedBox(height: 14),
        _buildGroupsRow(),
      ],
    );
  }

  Future<void> _handleAddToLeads() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add to Leads'),
        content: Text(
          'Create a new lead for ${_contactInfo?['contactName'] ?? _contactInfo?['contactNumber'] ?? 'this contact'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1EA443),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Backend expects fullMobile = countryCode + mobile (mobile = local digits only)
        final rawNumber =
            _contactInfo?['contactNumber'] ?? widget.contactNumber ?? '';
        final fullDigits =
            rawNumber.toString().replaceAll(RegExp(r'\D'), '');
        String countryCode =
            _contactInfo?['countryCode']?.toString().replaceAll(RegExp(r'\D'), '') ??
                '91';
        String mobile;
        if (fullDigits.startsWith(countryCode) &&
            fullDigits.length > countryCode.length) {
          mobile = fullDigits.substring(countryCode.length);
        } else if (countryCode == '91' &&
            fullDigits.length > 10 &&
            fullDigits.startsWith('91')) {
          mobile = fullDigits.substring(2);
        } else {
          mobile = fullDigits;
        }

        final leadData = {
          'name': _contactInfo?['contactName'] ?? widget.profileName ?? '',
          'mobile': mobile,
          'countryCode': countryCode,
          'email': _contactInfo?['email'] ?? '',
          'source': 'WhatsApp',
          'status': 'New Lead',
          'assignedAgent': _contactInfo?['assignedAgent'] ?? '',
        };

        await ChatService.createLead(leadData);
        if (mounted) {
          _showTopBanner(context, 'Lead created successfully');
          _fetchProfileData();
        }
      } catch (e) {
        if (!mounted) return;
        final msg = e.toString().toLowerCase();
        // Same logic as backend: if lead already exists, treat as active lead
        if (msg.contains('already exists') ||
            msg.contains('lead already exists')) {
          setState(() => _leadExistsForContact = true);
          _fetchProfileData();
          _showTopBanner(context, 'Already a lead');
        } else {
          _showTopBanner(
            context,
            'Error: ${e.toString().split('\n').first}',
            isError: true,
          );
        }
      }
    }
  }

  Future<void> _showAddGroupDialogNew() async {
    final availableGroups = await ChatService.getContactGroups();
    if (!mounted) return;
    final navigator = Navigator.of(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final groupNameNotifier = ValueNotifier<String>('');
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(sheetContext).brightness == Brightness.dark
                  ? Theme.of(sheetContext).colorScheme.surfaceContainerHighest
                  : Theme.of(sheetContext).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                final cs = Theme.of(sheetContext).colorScheme;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add Contact to Groups',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                            ),
                          ),
                          IconButton(
                            onPressed: () => navigator.pop(),
                            icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFFFEDD5),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Color(0xFFC2410C),
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'This contact will be created and added to the selected groups',
                                      style: TextStyle(
                                        color: Color(0xFF9A3412),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Contact: ${_contactInfo?['contactName'] ?? 'Unknown'}',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                            ),
                            Text(
                              'Phone: ${_contactInfo?['contactNumber'] ?? 'Unknown'}',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Autocomplete<String>(
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text == '') {
                                      return const Iterable<String>.empty();
                                    }
                                    return availableGroups.where((
                                      String option,
                                    ) {
                                      return option.toLowerCase().contains(
                                        textEditingValue.text.toLowerCase(),
                                      );
                                    });
                                  },
                              onSelected: (String selection) {
                                groupNameNotifier.value = selection;
                              },
                              fieldViewBuilder:
                                  (
                                    context,
                                    controller,
                                    focusNode,
                                    onEditingComplete,
                                  ) {
                                    controller.addListener(() {
                                      groupNameNotifier.value = controller.text;
                                    });
                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      onEditingComplete: onEditingComplete,
                                      style: TextStyle(color: cs.onSurface),
                                      decoration: InputDecoration(
                                        hintText: 'Select or create groups',
                                        hintStyle: TextStyle(
                                          color: cs.onSurfaceVariant,
                                        ),
                                        filled: true,
                                        fillColor: cs.surfaceContainerHighest,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                      ),
                                    );
                                  },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You can select existing groups or type new group names',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => navigator.pop(),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(color: cs.onSurfaceVariant),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: SizedBox(
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final groupName = groupNameNotifier
                                            .value
                                            .trim();
                                        if (groupName.isEmpty) {
                                          _showTopBanner(
                                            sheetContext,
                                            'Please enter or select a group',
                                            isError: true,
                                          );
                                          return;
                                        }
                                        navigator.pop();
                                        try {
                                          if (!availableGroups.contains(
                                            groupName,
                                          )) {
                                            await ChatService.createContactGroup(
                                              groupName,
                                            );
                                          }
                                          final currentGroups =
                                              (_contactInfo?['groups'] as List?)
                                                  ?.map((e) => e.toString())
                                                  .toList() ??
                                              [];
                                          if (!currentGroups.contains(
                                            groupName,
                                          )) {
                                            final newGroups = [
                                              ...currentGroups,
                                              groupName,
                                            ];
                                            final String fullContactNumber =
                                                _contactInfo?['contactNumber']
                                                    ?.toString() ??
                                                '';
                                            String phoneNumber =
                                                _contactInfo?['phoneNumber']
                                                    ?.toString() ??
                                                '';
                                            final String countryCode =
                                                _contactInfo?['countryCode']
                                                    ?.toString() ??
                                                '';
                                            if (phoneNumber.isEmpty &&
                                                fullContactNumber.isNotEmpty &&
                                                countryCode.isNotEmpty) {
                                              if (fullContactNumber.startsWith(
                                                countryCode,
                                              )) {
                                                phoneNumber = fullContactNumber
                                                    .substring(
                                                      countryCode.length,
                                                    );
                                              } else if (fullContactNumber
                                                  .startsWith(
                                                    '+$countryCode',
                                                  )) {
                                                phoneNumber = fullContactNumber
                                                    .substring(
                                                      countryCode.length + 1,
                                                    );
                                              } else {
                                                phoneNumber = fullContactNumber;
                                              }
                                            }
                                            final reqBody = {
                                              'countryCode': countryCode,
                                              'phoneNumber': phoneNumber,
                                              'contactNumber':
                                                  fullContactNumber,
                                              'contactName':
                                                  _contactInfo?['contactName'],
                                              'groups': newGroups,
                                              'tags': _getCurrentTags(),
                                            };
                                            final idToSend =
                                                _contactInfo?['_id'] ??
                                                _sessionDoc?['_id'];
                                            if (idToSend != null) {
                                              await ChatService.updateContact(
                                                idToSend,
                                                reqBody,
                                              );
                                              if (mounted) {
                                                _showTopBanner(
                                                  context,
                                                  'Group added successfully',
                                                );
                                                _fetchProfileData();
                                              }
                                            }
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            _showTopBanner(
                                              context,
                                              'Failed to add group: $e',
                                              isError: true,
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size.fromHeight(48),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Create & Add'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Normalize digits to full international for lead search (backend fullMobile is countryCode+mobile).
  /// e.g. "9495204766" -> "919495204766", "919495204766" -> "919495204766".
  static String _normalizeToFullInternational(String digits) {
    if (digits.length == 10 &&
        int.tryParse(digits.substring(0, 1)) != null &&
        ['6', '7', '8', '9'].contains(digits.substring(0, 1))) {
      return '91$digits';
    }
    return digits;
  }

  static const double _profilePillRadius = 20;

  Widget _buildLeadStatusRow() {
    final hasStatus = _contactInfo?['status']?.toString().isNotEmpty ?? false;
    // API v1/lead-configuration/leads may return isConverted or isCoverted
    final isConverted =
        _contactInfo?['isConverted'] == true ||
        _contactInfo?['isCoverted'] == true ||
        _contactInfo?['status']?.toString().toLowerCase() == 'converted' ||
        _contactInfo?['leadStatus']?.toString().toLowerCase() == 'customer' ||
        _contactInfo?['leadStatus']?.toString().toLowerCase() == 'converted' ||
        _contactInfo?['lead_status']?.toString().toLowerCase() == 'customer' ||
        _contactInfo?['lead_status']?.toString().toLowerCase() == 'converted';
    final hasLeadId =
        _contactInfo?['leadId'] != null || _contactInfo?['lead_id'] != null;
    // Show Active Lead when API says so, or when createLead returned "already exists"
    final showActiveLead =
        hasStatus || isConverted || hasLeadId || _leadExistsForContact;
    // Match web: show "Customer" when lead is converted, "Active Lead" otherwise
    final leadStatusLabel =
        isConverted ? 'Customer' : 'Active Lead';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            'Lead Status :',
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (showActiveLead)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1EA443),
                    borderRadius: BorderRadius.circular(_profilePillRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        leadStatusLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                InkWell(
                  onTap: _handleAddToLeads,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1EA443),
                      borderRadius: BorderRadius.circular(_profilePillRadius),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Add to Leads',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupsRow() {
    final groups = _contactInfo?['groups'] as List<dynamic>?;
    final list = groups ?? [];
    final hasGroups = list.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            'Groups :',
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 6,
            runSpacing: 6,
            children: [
              if (!hasGroups)
                Text(
                  'Not in contacts',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ...list.map((g) {
                final cs = Theme.of(context).colorScheme;
                final name = g is Map
                    ? (g['name'] ?? g['label'] ?? g.toString())
                    : g.toString();
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(_profilePillRadius),
                    border: Border.all(color: cs.outline.withOpacity(0.3)),
                  ),
                  child: Text(
                    name.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                );
              }),
              InkWell(
                onTap: _showAddGroupDialogNew,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1EA443),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(
    String label,
    String value, {
    int maxLines = 1,
    bool isHighlighted = false,
    Widget? trailing,
  }) {
    final cs = Theme.of(context).colorScheme;
    // Match web: "User Active Status : 3 days ago"
    final labelWithColon = '$label :';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            labelWithColon,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 13,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: maxLines,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isHighlighted
                        ? const Color(0xFF1EA443)
                        : cs.onSurface,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionTimeCard({
    required String value,
    required String label,
    required bool isDisabled,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? cs.surfaceContainerHighest
        : (isDisabled ? Colors.grey.shade100 : const Color(0xFFF0FDF4));
    final borderColor = isDark
        ? cs.outline.withOpacity(0.5)
        : (isDisabled ? Colors.grey.shade300 : const Color(0xFFDCFCE7));
    final valueColor = isDisabled
        ? cs.onSurfaceVariant
        : const Color(0xFF1EA443);
    final labelColor = cs.onSurfaceVariant;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: 0.5,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: labelColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Resolves session expiration for SERVICE WINDOW - UTILITY (match web/backend).
  /// Prefers utility.expiration, then service.expiration, then sessionExpiration.
  /// If none from backend, calculates 24h from last user message (app session window).
  int? _getServiceWindowExpirationSeconds() {
    // 1) From session doc: utility (for "utility" window) then service then sessionExpiration
    if (_sessionDoc != null) {
      final utility = _sessionDoc!['utility'];
      final service = _sessionDoc!['service'] ?? {};
      var raw = utility is Map ? utility['expiration'] : null;
      raw ??= service['expiration'];
      raw ??= _sessionDoc!['sessionExpiration'];

      if (raw != null) {
        if (raw is int) return raw;
        final parsed = DateTime.tryParse(raw.toString());
        if (parsed != null) return parsed.millisecondsSinceEpoch ~/ 1000;
        return int.tryParse(raw.toString());
      }
    }
    // 2) App-calculated session window: 24 hours from last user message (same as WhatsApp session)
    if (_lastUserActivity != null) {
      final exp = _lastUserActivity!.millisecondsSinceEpoch ~/ 1000 +
          (24 * 3600);
      return exp;
    }
    return null;
  }

  Widget _buildActiveSessions() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SERVICE WINDOW - UTILITY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<DateTime>(
          valueListenable: _currentTimeNotifier,
          builder: (context, now, child) {
            String serviceCountdown = '00:00:00';
            bool isDisabled = true;
            final expValue = _getServiceWindowExpirationSeconds();
            if (expValue != null) {
              final nowSec = now.millisecondsSinceEpoch ~/ 1000;
              final timeLeft = expValue - nowSec;
              if (timeLeft > 0) {
                isDisabled = false;
                final h = (timeLeft ~/ 3600).toString().padLeft(2, '0');
                final m =
                    ((timeLeft % 3600) ~/ 60).toString().padLeft(2, '0');
                final s = (timeLeft % 60).toString().padLeft(2, '0');
                serviceCountdown = '$h:$m:$s';
              }
            }
            return Row(
              children: [
                _buildSessionTimeCard(
                  value: serviceCountdown.split(':').elementAt(0),
                  label: 'HH',
                  isDisabled: isDisabled,
                ),
                const SizedBox(width: 6),
                _buildSessionTimeCard(
                  value: serviceCountdown.split(':').length > 1
                      ? serviceCountdown.split(':')[1]
                      : '00',
                  label: 'MM',
                  isDisabled: isDisabled,
                ),
                const SizedBox(width: 6),
                _buildSessionTimeCard(
                  value: serviceCountdown.split(':').length > 2
                      ? serviceCountdown.split(':')[2]
                      : '00',
                  label: 'SS',
                  isDisabled: isDisabled,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPaymentsSection() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product list
        ..._paymentProducts.asMap().entries.map((entry) {
          final index = entry.key;
          final product = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Item #${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (_paymentProducts.length > 1)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _paymentProducts.removeAt(index);
                            _calculatePaymentTotal();
                          });
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildPaymentField(
                  label: 'Product Name',
                  onChanged: (val) =>
                      setState(() => _paymentProducts[index]['name'] = val),
                  hint: 'Enter product name',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildPaymentField(
                        label: 'Price',
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          setState(() {
                            _paymentProducts[index]['price'] =
                                double.tryParse(val) ?? 0.0;
                            _calculatePaymentTotal();
                          });
                        },
                        hint: '0.00',
                        prefix: '₹ ',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _buildPaymentField(
                        label: 'Qty',
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          setState(() {
                            _paymentProducts[index]['quantity'] =
                                int.tryParse(val) ?? 1;
                            _calculatePaymentTotal();
                          });
                        },
                        hint: '1',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.outline.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Item Total',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '₹${((product['price'] ?? 0.0) * (product['quantity'] ?? 1)).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),

        // Add button and Subtotal
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _paymentProducts.add({
                    'name': '',
                    'price': 0.0,
                    'quantity': 1,
                  });
                });
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1EA443),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Subtotal',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
                Text(
                  '₹${_paymentSubtotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Divider(color: cs.outline.withOpacity(0.5)),
        ),

        _buildPaymentField(
          label: 'Description (optional)',
          maxLines: 2,
          onChanged: (val) => setState(() => _paymentDescription = val),
          hint: 'Add some details...',
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildPaymentField(
                label: 'Discount',
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  setState(() {
                    _paymentDiscount = double.tryParse(val) ?? 0.0;
                    _calculatePaymentTotal();
                  });
                },
                prefix: '₹ ',
                hint: '0',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPaymentField(
                label: 'Shipping',
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  setState(() {
                    _paymentShipping = double.tryParse(val) ?? 0.0;
                    _calculatePaymentTotal();
                  });
                },
                prefix: '₹ ',
                hint: '0',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildPaymentField(
          label: 'Tax Rate (%)',
          keyboardType: TextInputType.number,
          onChanged: (val) {
            setState(() {
              _taxRate = double.tryParse(val) ?? 0.0;
              _calculatePaymentTotal();
            });
          },
          hint: '0',
        ),

        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline.withOpacity(0.5), width: 1),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL AMOUNT',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '₹${_paymentTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.surface,
                    foregroundColor: const Color(0xFF1EA443),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(
                      color: Color(0xFF1EA443),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _notifyPayment,
                  child: const Text(
                    'Notify Payment',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentField({
    required String label,
    required Function(String) onChanged,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? prefix,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          style: TextStyle(color: cs.onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF1EA443),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            isDense: true,
          ),
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _fetchProductsForCatalog(String catalogId) async {
    if (_catalogProducts.containsKey(catalogId) ||
        _loadingCatalogProducts[catalogId] == true)
      return;

    setState(() {
      _loadingCatalogProducts[catalogId] = true;
    });

    final products = await ChatService.getProductsByCatalogId(catalogId);

    if (mounted) {
      setState(() {
        _catalogProducts[catalogId] = products;
        _loadingCatalogProducts[catalogId] = false;
      });
    }
  }

  Widget _buildCatalogsSection() {
    // Web logic: Only show connected catalogs
    final connectedCatalogs = _catalogs
        .where((cat) => cat['isConnected'] == true)
        .toList();

    if (connectedCatalogs.isEmpty) return const Text('No connected catalogs');

    return Column(
      children: connectedCatalogs.map((cat) {
        final catalogId = cat['catalogId'].toString();
        final products = _catalogProducts[catalogId] ?? [];
        final isLoading = _loadingCatalogProducts[catalogId] ?? false;

        return ExpansionTile(
          onExpansionChanged: (expanded) {
            if (expanded) {
              _fetchProductsForCatalog(catalogId);
            }
          },
          leading: cat['defaultImage'] != null || cat['image'] != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    cat['defaultImage'] ?? cat['image'],
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Icon(Icons.store),
                  ),
                )
              : const Icon(Icons.store),
          title: Text(cat['name'] ?? 'Catalog'),
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cat['shippingPrice'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
                      child: Text('Shipping Price: ${cat['shippingPrice']}'),
                    ),
                  if (isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (products.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('No products in this catalog'),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.6,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          elevation: 1,
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: product['productImage'] != null
                                    ? Image.network(
                                        product['productImage'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(
                                          color: Colors.grey[200],
                                          child: const Icon(
                                            Icons.broken_image,
                                            size: 20,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.image,
                                          size: 20,
                                        ),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product['name'] ?? 'Product',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${product['salePrice'] ?? product['price'] ?? 0} ${product['currency'] ?? 'INR'}',
                                      style: TextStyle(
                                        color: const Color(0xFF1EA443),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildJourneySection() {
    final cs = Theme.of(context).colorScheme;
    if (_customerJourney.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history, color: cs.onSurfaceVariant.withOpacity(0.6), size: 40),
              const SizedBox(height: 12),
              Text(
                'No journey data available',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final displayedJourney = _customerJourney.take(20).toList();

    return Stack(
      children: [
        Positioned(
          left: 17,
          top: 0,
          bottom: 0,
          child: Container(width: 2, color: cs.outline.withOpacity(0.5)),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...displayedJourney.map((item) {
              final title = _getJourneyTitle(item);

              Color indicatorColor = cs.onSurfaceVariant;

              if (title.contains('Intervene On')) {
                indicatorColor = const Color(0xFF1EA443);
              } else if (title.contains('Completed')) {
                indicatorColor = const Color(0xFF3B82F6);
              } else if (title.contains('Assigned')) {
                indicatorColor = const Color(0xFFF59E0B);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 24, left: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: cs.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: indicatorColor, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: indicatorColor.withOpacity(0.2),
                            blurRadius: 4,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outline.withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: cs.shadow.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatJourneyTime(item['createdAt']),
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  String _getJourneyTitle(dynamic itemData) {
    if (itemData is! Map<String, dynamic>) return 'Interaction';
    final item = itemData;

    if (item.containsKey('mode')) {
      final mode = item['mode'] ?? 'Intervene';
      final status = (item['intervene'] == true) ? 'On' : 'Off';
      return 'Mode: $mode $status';
    }

    if (item.containsKey('action')) {
      final agentName = item['agentName']?.toString() ?? '';
      final action = item['action']?.toString() ?? '';
      final removedBy = item['removedBy']?.toString() ?? '';

      switch (action) {
        case 'agent_assigned':
          return 'Status: Assigned to ${agentName.isNotEmpty ? agentName : "Agent"}';
        case 'agent_removed':
          String msg = 'Status: Removed from $agentName';
          if (removedBy.isNotEmpty) msg += ' by $removedBy';
          return msg;
        case 'user_blocked':
          return 'Status: User Blocked${agentName.isNotEmpty ? " by $agentName" : ""}';
        case 'user_unblocked':
          return 'Status: User Unblocked${agentName.isNotEmpty ? " by $agentName" : ""}';
        case 'user_unsubscribed':
          return 'Status: User Unsubscribed';
        case 'agent_switched':
          return 'Status: Switched to $agentName';
        case 'moved_to_admin':
          return 'Status: Completed by ${agentName.isNotEmpty ? agentName : "Agent"}';
        default:
          return 'Status: ${action.replaceAll('_', ' ')}';
      }
    }

    return 'Interaction';
  }

  String _formatJourneyTime(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt.toString()).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (e) {
      return createdAt.toString();
    }
  }

  Widget _buildTagsSection() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tags = _getCurrentTags();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? cs.primaryContainer.withOpacity(0.4)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark
                            ? cs.primary.withOpacity(0.5)
                            : const Color(0xFFDBEAFE),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t,
                          style: TextStyle(
                            color: isDark ? cs.onPrimaryContainer : const Color(0xFF2563EB),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _removeTag(t),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: isDark ? cs.onPrimaryContainer : const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        if (tags.isNotEmpty) const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                style: TextStyle(color: cs.onSurface, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Add a tag...',
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
                  ),
                ),
                onSubmitted: _addTag,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _addTag(_tagController.text),
              icon: const Icon(Icons.add_circle, color: Color(0xFF1EA443)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _noteController,
                maxLines: 2,
                minLines: 1,
                style: TextStyle(color: cs.onSurface, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Type a note...',
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addNote,
              icon: const Icon(Icons.add_circle, color: Color(0xFF1EA443)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._notes.map((n) {
          final noteId = n['_id']?.toString() ?? n['note'] ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outline.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        n['note'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: cs.primary,
                          ),
                          onPressed: () =>
                              _showEditNoteDialog(noteId, n['note'] ?? ''),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: Colors.red,
                          ),
                          onPressed: () => _deleteNote(noteId),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      n['username'] ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      n['createdAt'] != null
                          ? DateFormat('MMM d, h:mm a').format(
                              DateTime.tryParse(
                                    n['createdAt'].toString(),
                                  )?.toLocal() ??
                                  DateTime.now(),
                            )
                          : '',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showEditNoteDialog(String noteId, String currentNote) {
    showDialog(
      context: context,
      builder: (context) => _EditNoteDialog(
        currentNote: currentNote,
        onSave: (newVal) {
          if (newVal.isNotEmpty) {
            _editNote(noteId, newVal);
          }
        },
      ),
    );
  }

  Future<void> _editNote(String oldNoteId, String newNote) async {
    try {
      await ChatService.deleteNote(widget.contactNumber, oldNoteId);
      await ChatService.addNote(
        widget.contactNumber,
        newNote,
        _username ?? 'Agent',
        _email ?? '',
        isEdited: true,
      );
      await _refreshDrawerNotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update note: $e')),
        );
      }
    }
  }

  Future<void> _deleteNote(String noteContent) async {
    try {
      await ChatService.deleteNote(widget.contactNumber, noteContent);
      await _refreshDrawerNotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete note: $e')),
        );
      }
    }
  }

  Widget _buildTemplateMediaHeader(
    String url,
    IconData fallbackIcon, {
    bool isVideo = false,
    VoidCallback? onImageTap,
  }) {
    final content = Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(maxHeight: 200),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isVideo)
              VideoMessagePlayer(videoUrl: url)
            else
              Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (c, e, s) =>
                    Center(child: Icon(fallbackIcon, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
    if (!isVideo && onImageTap != null) {
      return GestureDetector(
        onTap: onImageTap,
        child: content,
      );
    }
    return content;
  }

  Widget _buildCarousel(Map<String, dynamic> template, bool isMe) {
    final cs = Theme.of(context).colorScheme;
    final contentColor = isMe ? const Color(0xFF1A1A1A) : cs.onSurface;
    final cards = template['cards'] as List<dynamic>? ?? [];
    final templateMessage = _resolveText(template['message']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (templateMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              templateMessage,
              style: TextStyle(color: contentColor),
            ),
          ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              final headerUrl = card['header']?.toString();
              final headerType = card['headerType']?.toString().toLowerCase();
              final cardBody = _resolveText(card['message'] ?? card);
              final actions = card['actions'] as List<dynamic>? ?? [];

              return Container(
                width: 180,
                margin: const EdgeInsets.only(right: 12),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (headerUrl != null && headerUrl.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          if (headerType != 'video') {
                            _showImagePreview(context, headerUrl);
                          }
                        },
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10),
                          ),
                          child: SizedBox(
                            height: 100,
                            width: double.infinity,
                            child: Image.network(
                              headerUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                height: 100,
                                color: Colors.grey[100],
                                child: Icon(
                                  headerType == 'video'
                                      ? Icons.videocam
                                      : Icons.image,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        cardBody,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: contentColor),
                      ),
                    ),
                    const Spacer(),
                    ...actions.take(1).map((action) {
                      return Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: cs.outline.withOpacity(0.5)),
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _handleButtonClick(action),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              action['text'] ?? 'Action',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showQuickReplyDialog() async {
    setState(() => _showAttachmentMenu = false);
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuickReplyPage(contactNumber: widget.contactNumber),
        fullscreenDialog: true,
      ),
    );
    if (sent == true) _fetchMessages();
  }

  Future<void> _sendQuickReply(Map<String, dynamic> reply) async {
    try {
      final type = (reply['type'] ?? 'text').toString().toLowerCase();
      final data = {
        'body': reply['content'],
        'link': reply['fileUrl'],
        'caption': reply['content'],
        'filename': reply['title'],
      };

      await ChatService.sendMessage(
        toNumber: widget.contactNumber,
        type: type,
        data: data,
      );
      _fetchMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    }
  }

  Future<void> _showTemplateDialog() async {
    setState(() => _showAttachmentMenu = false);
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TemplatePage(
          contactNumber: widget.contactNumber,
          isIntervened: _intervened,
        ),
      ),
    );
    if (sent == true) _fetchMessages();
  }
}

class _EditNoteDialog extends StatefulWidget {
  final String currentNote;
  final Function(String) onSave;

  const _EditNoteDialog({required this.currentNote, required this.onSave});

  @override
  _EditNoteDialogState createState() => _EditNoteDialogState();
}

class _EditNoteDialogState extends State<_EditNoteDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Note'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Enter note',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1EA443),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            widget.onSave(_controller.text.trim());
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class VideoMessagePlayer extends StatefulWidget {
  final String videoUrl;
  const VideoMessagePlayer({super.key, required this.videoUrl});

  @override
  State<VideoMessagePlayer> createState() => _VideoMessagePlayerState();
}

class _VideoMessagePlayerState extends State<VideoMessagePlayer> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await _videoPlayerController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        placeholder: Container(color: Colors.black),
        autoInitialize: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        width: 280,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 50, color: Colors.grey),
            SizedBox(height: 8),
            Text('Video unavailable', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized) {
      return Container(
        width: 280,
        constraints: const BoxConstraints(maxHeight: 400),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: _videoPlayerController.value.aspectRatio,
            child: Chewie(controller: _chewieController!),
          ),
        ),
      );
    } else {
      return Container(
        width: 280,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
  }
}

class VoiceMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final bool isMe;

  const VoiceMessagePlayer({
    super.key,
    required this.audioUrl,
    required this.isMe,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {
    if (_playerState == PlayerState.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(widget.audioUrl));
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Sent (isMe) bubbles have light green bg: use dark text/icons for clear visibility.
    final Color tintColor = widget.isMe
        ? const Color(0xFF0D0D0D)
        : (isDark ? Colors.white : const Color(0xFF1EA443));
    final Color textColor = widget.isMe
        ? const Color(0xFF0D0D0D)
        : (isDark ? Colors.white : cs.onSurface);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _playerState == PlayerState.playing
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: textColor,
              size: 32,
            ),
            onPressed: _playPause,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 150,
                height: 3,
                child: LinearProgressIndicator(
                  value: _duration.inMilliseconds > 0
                      ? _position.inMilliseconds / _duration.inMilliseconds
                      : 0,
                  backgroundColor: widget.isMe
                      ? Colors.black.withOpacity(0.12)
                      : cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(tintColor),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _playerState == PlayerState.playing
                    ? _formatDuration(_position)
                    : (_duration == Duration.zero
                          ? "0:00"
                          : _formatDuration(_duration)),
                style: TextStyle(fontSize: 11, color: textColor),
              ),
            ],
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: widget.isMe
                ? Colors.black.withOpacity(0.08)
                : cs.surfaceContainerHighest,
            child: Icon(Icons.mic, color: tintColor, size: 16),
          ),
        ],
      ),
    );
  }
}
