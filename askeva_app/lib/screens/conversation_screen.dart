import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_filex/open_filex.dart';

import '../api/app_scope.dart';
import '../api/dto.dart';
import '../api/local_notification_service.dart';
import '../theme/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/common.dart';
import '../widgets/conversation_profile_sheet.dart';
import '../widgets/dashboard_sheets.dart' show appToast;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shell/app_sidebar.dart' show kUnreadChatsCount, refreshUnreadChatsCount;
import '../api/payment_launcher.dart';

/// WhatsApp-style conversation surface backed by the live chat API.
class ConversationScreen extends StatefulWidget {
  final String name;
  final String number;
  final bool isHistory;
  const ConversationScreen({super.key, required this.name, required this.number, this.isHistory = false});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  Future<List<MessageDto>>? _future;
  final _input = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _aiHandling = true; // AI is auto-handling until the agent intervenes
  bool _manuallyIntervened = false;
  bool _templateSent = false;
  bool _searching = false;
  String _searchQ = '';
  bool _muted = false;
  bool _showEmoji = false;
  bool _needsScrollToBottom = true;
  bool _isLead = false;
  bool _isBlocked = false;
  final List<MessageDto> _extra = []; // locally-appended (sent attachments etc.)
  String _selectedTemplateCategory = 'Marketing';
  String _searchTemplateQuery = '';
  bool _showCatalogue = false;
  List<ProductDto> _catalogProducts = [];
  Map<ProductDto, int> _draftOrderProducts = {};
  String? _topError;

  bool _recording = false;
  bool _recordingPaused = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  int _recordingDuration = 0;
  Timer? _recordingTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  List<MessageDto> _messages = const [];

  Future<List<MessageDto>> _load() {
    if (widget.number.isEmpty) return Future.value(<MessageDto>[]);

    // Fetch catalog products robustly with fallback (matches CatalogueSheet)
    _loadCatalogProducts();

    // Mark chat as read locally in SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      final unreadList = prefs.getStringList('marked_unread_numbers') ?? [];
      if (unreadList.contains(widget.number)) {
        unreadList.remove(widget.number);
        prefs.setStringList('marked_unread_numbers', unreadList);
      }
      final readList = prefs.getStringList('marked_read_numbers') ?? [];
      if (!readList.contains(widget.number)) {
        readList.add(widget.number);
        prefs.setStringList('marked_read_numbers', readList);
      }
      prefs.setInt('read_time_${widget.number}', DateTime.now().millisecondsSinceEpoch);
      if (mounted) refreshUnreadChatsCount(context);
    }).catchError((_) {});

    // Check if user is a lead
    AppScope.of(context).leads.fetchLeads(q: widget.number).then((page) {
      final exists = page.leads.any((l) => l.mobile == widget.number);
      if (mounted) {
        setState(() => _isLead = exists);
      }
    }).catchError((_) {});

    // Check if user is blocked
    AppScope.of(context).contacts.fetchUnsubscribedContacts().then((list) {
      final numClean = widget.number.replaceAll(RegExp(r'\D'), '');
      final isBlk = list.any((c) {
        final cNum = c.contactNumber.replaceAll(RegExp(r'\D'), '');
        return cNum.isNotEmpty && (cNum == numClean || (cNum.length >= 10 && numClean.endsWith(cNum.substring(cNum.length - 10))));
      });
      if (mounted) {
        setState(() => _isBlocked = isBlk);
      }
    }).catchError((_) {});

    final chat = AppScope.of(context).chat;
    final f = chat.fetchMessages(widget.number);
    f.then((m) {
      if (mounted) setState(() => _messages = m);
    }).catchError((_) {});
    // Live agent-intervene status: intervened == agent has taken over from Eva.
    chat.fetchInterveneStatus(widget.number).then((intervened) {
      if (mounted) {
        setState(() {
          if (_manuallyIntervened) {
            _aiHandling = false;
          } else {
            _aiHandling = !intervened;
            if (intervened) {
              _manuallyIntervened = true;
            }
          }
        });
      }
    }).catchError((_) {});
    return f;
  }

  void _reload() {
    _needsScrollToBottom = true;
    setState(() { _future = _load(); });
    _scrollToBottom();
  }

  void _scrollToBottom({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        if (animate) {
          _scrollController.animateTo(max, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        } else {
          _scrollController.jumpTo(max);
        }
      }
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted && _scrollController.hasClients) {
          final max = _scrollController.position.maxScrollExtent;
          if (animate) {
            _scrollController.animateTo(max, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
          } else {
            _scrollController.jumpTo(max);
          }
        }
      });
    });
  }

  /// The 24-hour WhatsApp service window: if the last customer message is
  /// older than a day, the session is closed and only a template can re-open it.
  bool get _sessionClosed {
    // Once a template is sent OR agent has intervened, the session is re-opened locally.
    if (_manuallyIntervened || _templateSent) return false;
    // History chats are always treated as closed (no active 24h window).
    if (widget.isHistory) return true;
    DateTime? lastIncoming;
    for (final m in _messages) {
      if (m.outgoing || m.timestamp == null) continue;
      if (lastIncoming == null || m.timestamp!.isAfter(lastIncoming)) lastIncoming = m.timestamp;
    }
    if (lastIncoming == null) return false;
    return DateTime.now().difference(lastIncoming) > const Duration(hours: 24);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || widget.number.isEmpty) return;
    setState(() => _sending = true);
    try {
      await AppScope.of(context).chat.sendText(widget.number, text);
      _input.clear();
      _reload();
    } catch (e) {
      if (mounted) {
        appToast(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _silentPollMessages();
    });
  }

  Future<void> _silentPollMessages() async {
    if (widget.number.isEmpty || _sending) return;
    try {
      final chat = AppScope.of(context).chat;
      final m = await chat.fetchMessages(widget.number, limit: 100);
      if (mounted && m.isNotEmpty) {
        final oldLast = _messages.isNotEmpty ? _messages.last : null;
        final newLast = m.last;
        final hasNew = _messages.length != m.length ||
            oldLast?.id != newLast.id ||
            oldLast?.text != newLast.text ||
            oldLast?.timestamp != newLast.timestamp;

        if (hasNew && oldLast != null && !newLast.outgoing) {
          // Play in-app chat sound if enabled
          final email = AppScope.of(context).session.email ?? 'global';
          final prefs = await SharedPreferences.getInstance();
          final soundsEnabled = prefs.getBool('in_app_sounds_enabled_$email') ?? true;
          if (soundsEnabled) {
            try {
              SystemSound.play(SystemSoundType.click);
              HapticFeedback.lightImpact();
            } catch (_) {}
          }
          // Show mobile system bar notification
          LocalNotificationService.showNotification(
            title: widget.name,
            body: newLast.text.isNotEmpty ? newLast.text : 'New message received',
            email: email,
          );
        }

        if (hasNew || _messages.isEmpty) {
          setState(() {
            _messages = List.from(m);
            _needsScrollToBottom = true;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _input.dispose();
    _searchCtrl.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }


  String get _statusText {
    DateTime? lastMsgTime;
    for (final m in _messages) {
      if (m.timestamp != null) {
        if (lastMsgTime == null || m.timestamp!.isAfter(lastMsgTime)) {
          lastMsgTime = m.timestamp;
        }
      }
    }

    if (lastMsgTime == null) {
      return widget.isHistory ? 'last seen recently' : 'online';
    }

    if (!widget.isHistory && !_sessionClosed) {
      final diffMin = DateTime.now().difference(lastMsgTime).inMinutes;
      if (diffMin < 5) {
        return 'online';
      }
    }

    final local = lastMsgTime.toLocal();
    final now = DateTime.now();
    final sameDay = now.year == local.year && now.month == local.month && now.day == local.day;
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final timeStr = '$h:$m ${local.hour < 12 ? 'AM' : 'PM'}';

    if (sameDay) {
      return 'last seen today at $timeStr';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final sameYesterday = yesterday.year == local.year && yesterday.month == local.month && yesterday.day == local.day;
    if (sameYesterday) {
      return 'last seen yesterday at $timeStr';
    }

    return 'last seen ${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} at $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final color = avatarColorFor(widget.name);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_templateSent || _manuallyIntervened);
      },
      child: Scaffold(
        backgroundColor: AppColors.waBg,
        body: DragTarget<ProductDto>(
          onWillAcceptWithDetails: (details) => true,
          onAcceptWithDetails: (details) {
            _sendCatalogProduct(details.data);
          },
          builder: (context, candidateData, rejectedData) {
            return Column(
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(6, topPad + 8, 8, 12),
                  decoration: const BoxDecoration(gradient: AppColors.evaGradient),
                  child: _searching
                      ? Row(children: [
                          IconButton(onPressed: () => setState(() { _searching = false; _searchQ = ''; _searchCtrl.clear(); }), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24)),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              autofocus: true,
                              onChanged: (v) => setState(() => _searchQ = v),
                              style: AppText.poppins(size: 15, weight: FontWeight.w600, color: Colors.white),
                              decoration: InputDecoration(border: InputBorder.none, hintText: 'Search in chat…', hintStyle: AppText.poppins(size: 15, weight: FontWeight.w500, color: Colors.white70)),
                            ),
                          ),
                          if (_searchQ.isNotEmpty) IconButton(onPressed: () => setState(() { _searchQ = ''; _searchCtrl.clear(); }), icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22)),
                        ])
                      : Row(
                          children: [
                            IconButton(onPressed: () => Navigator.of(context).pop(_templateSent || _manuallyIntervened), icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28)),
                            InitialsAvatar(initials: _initials(widget.name), color: color, size: 40, radius: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  await showConversationProfile(context, name: widget.name, number: widget.number, sessionClosed: _sessionClosed);
                                  if (mounted) _reload();
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 16, weight: FontWeight.w700, color: Colors.white)),
                                    Text(_statusText, style: AppText.poppins(size: 12, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9))),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(onPressed: () => setState(() => _searching = true), icon: const Icon(Icons.search_rounded, color: Colors.white, size: 22)),
                            _headerMenu(),
                          ],
                        ),
                ),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(AppAssets.chatBgLight),
                        fit: BoxFit.cover,
                        opacity: 0.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FutureBuilder<List<MessageDto>>(
                            future: _future,
                            builder: (context, snap) {
                              if (snap.connectionState == ConnectionState.waiting && _messages.isEmpty) {
                                return const Center(child: CircularProgressIndicator(color: AppColors.waHeader));
                              }
                              if (snap.hasError && _messages.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(snap.error.toString().replaceFirst('Exception: ', ''),
                                        textAlign: TextAlign.center, style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink3)),
                                  ),
                                );
                              }
                              final activeMsgs = _messages.isNotEmpty ? _messages : (snap.data ?? const <MessageDto>[]);
                              var msgs = [...activeMsgs, ..._extra]
                                  .where((m) => m.type != 'dayBreakFlag')
                                  .toList();
                              if (_searchQ.isNotEmpty) {
                                final q = _searchQ.toLowerCase();
                                msgs = msgs.where((m) => m.text.toLowerCase().contains(q)).toList();
                              }
                              if (msgs.isEmpty) {
                                return Center(child: Text(_searchQ.isNotEmpty ? 'No matches' : 'No messages yet', style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink3)));
                              }
                              if (msgs.isNotEmpty && _needsScrollToBottom) {
                                _needsScrollToBottom = false;
                                _scrollToBottom();
                              }
                              return ListView(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                children: _withSeparators(msgs),
                              );
                            },
                          ),
                        ),
                        if (_topError != null)
                          Positioned(
                            top: 10,
                            left: 0,
                            right: 0,
                            child: _topErrorCard(),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_isBlocked)
                  _blockedBanner()
                else if (_sessionClosed)
                  _sendTemplateBar()
                else if (_aiHandling)
                  _aiBar()
                else if (_draftOrderProducts.isNotEmpty)
                  _newOrderDrawer()
                else ...[
                  if (_showEmoji) _emojiPicker(),
                  _inputBar(),
                  _closeBar(),
                ],
                if (_showCatalogue)
                  _CatalogueSheet(
                    onSendProduct: _sendCatalogProduct,
                    onClose: () => setState(() => _showCatalogue = false),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // AI-handling state: full-width green Intervene pill.
  Widget _aiBar() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      width: double.infinity,
      color: AppColors.waBg,
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPad + 10),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _aiHandling = false;
            _manuallyIntervened = true;
          });
          AppScope.of(context).chat.setIntervene(widget.number, true).catchError((_) {});
        },
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: AppColors.evaGradient,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.support_agent_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('Intervene', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: Colors.white)),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // After intervene: compact "X Close" pill that hands back to Eva.
  Widget _closeBar() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      width: double.infinity,
      color: AppColors.waBg,
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad + 8),
      child: Center(
        child: GestureDetector(
          onTap: _handleClose,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.line, width: 1.2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.close_rounded, size: 16, color: AppColors.ink2),
                const SizedBox(width: 6),
                Text('Close', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _newOrderDrawer() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final totalItems = _draftOrderProducts.values.fold(0, (sum, q) => sum + q);
    final itemsText = totalItems == 1 ? '1 item' : '$totalItems items';
    final double subtotal = _draftOrderProducts.entries.fold(0.0, (sum, entry) => sum + (entry.key.price * entry.value));

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, -2)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Color(0xFFE8FDF0), shape: BoxShape.circle),
                child: const Icon(Icons.shopping_bag_outlined, color: AppColors.evaGreenDeep, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New order', style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                    Text('$itemsText · Tunepath Technologies', style: AppText.poppins(size: 12, color: AppColors.ink3)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _clearDraftOrder,
                child: Text('Clear', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView(
              shrinkWrap: true,
              children: _draftOrderProducts.entries.map((entry) {
                final p = entry.key;
                final qty = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.evaGreen50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: p.image.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(p.image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, color: AppColors.evaGreenDeep, size: 20)),
                              )
                            : const Icon(Icons.shopping_bag_outlined, color: AppColors.evaGreenDeep, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(p.name, style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink)),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _updateDraftQty(p, -1),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.line),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.remove, size: 12, color: AppColors.ink),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('$qty', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                          ),
                          GestureDetector(
                            onTap: () => _updateDraftQty(p, 1),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.line),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.add, size: 12, color: AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Text('₹${(p.price * qty).toStringAsFixed(0)}', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal ₹${subtotal.toStringAsFixed(0)}', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
              ElevatedButton.icon(
                onPressed: _sendDraftOrder,
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 14),
                label: Text('Send order', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.evaGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleClose() async {
    final session = AppScope.of(context).chat.session;
    final isAgent = session.role == 'agent';

    if (isAgent) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Close Conversation', style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
          content: Text('Do you want to just close the chat or close and move to admin?', style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink2)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: Text('Cancel', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink3)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('close'),
              child: Text('Close', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('admin'),
              child: Text('Close and Move to Admin', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.danger)),
            ),
          ],
        ),
      );

      if (choice == 'close') {
        setState(() {
          _aiHandling = true;
          _manuallyIntervened = false;
        });
        await AppScope.of(context).chat.setIntervene(widget.number, false).catchError((_) {});
      } else if (choice == 'admin') {
        setState(() {
          _aiHandling = true;
          _manuallyIntervened = false;
        });
        await AppScope.of(context).chat.closeConversation(widget.number).catchError((_) {});
      }
    } else {
      setState(() {
        _aiHandling = true;
        _manuallyIntervened = false;
      });
      await AppScope.of(context).chat.setIntervene(widget.number, false).catchError((_) {});
    }
  }

  Widget _emojiPicker() {
    const emojis = ['😀', '😁', '😂', '🤣', '😊', '😍', '😎', '🤩', '👍', '🙏', '🔥', '🎉', '❤️', '✅', '👏', '🙌', '💯', '😅', '🤝', '📦', '💳', '📍', '⏰', '⭐'];
    return Container(
      height: 200,
      color: AppColors.surface,
      child: GridView.count(
        crossAxisCount: 8,
        padding: const EdgeInsets.all(8),
        children: [
          for (final e in emojis)
            GestureDetector(
              onTap: () => setState(() => _input.text = _input.text + e),
              child: Center(child: Text(e, style: const TextStyle(fontSize: 24))),
            ),
        ],
      ),
    );
  }

  Widget _sendTemplateBar() {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).padding.bottom + 14),
      child: Column(
        children: [
          Text('Chat Conversation closed!', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 4),
          Text('Please send a template to initiate a chat conversation',
              textAlign: TextAlign.center, style: AppText.poppins(size: 12.5, weight: FontWeight.w500, color: AppColors.ink3)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.evaGradient, borderRadius: BorderRadius.circular(13)),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: _pickTemplate,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_upload_outlined, size: 19, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Send template', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    if (_recording) {
      final mins = _recordingDuration ~/ 60;
      final secs = _recordingDuration % 60;
      final timerStr = '$mins:${secs.toString().padLeft(2, '0')}';

      return Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        color: AppColors.waBg,
        child: Row(
          children: [
            // Delete / cancel
            GestureDetector(
              onTap: _cancelRecording,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Color(0xFFEF5350), shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            // Recording pill
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Row(
                  children: [
                    if (!_recordingPaused) const _BlinkingRedDot() else const Icon(Icons.mic_off_rounded, size: 14, color: AppColors.ink3),
                    const SizedBox(width: 8),
                    Text(
                      timerStr,
                      style: AppText.poppins(size: 15, weight: FontWeight.w700, color: AppColors.ink),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _recordingPaused ? 'Paused' : 'Recording…',
                        style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink3),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Pause / Resume toggle
                    GestureDetector(
                      onTap: _togglePauseRecording,
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.evaGreen.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _recordingPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          size: 20,
                          color: AppColors.evaGreenDeep,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            GestureDetector(
              onTap: _stopAndSendRecording,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.evaGreen, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      color: AppColors.waBg,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _showEmoji = !_showEmoji),
                    child: Icon(_showEmoji ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined, color: AppColors.ink4, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      onTap: () => setState(() => _showEmoji = false),
                      onSubmitted: (_) => _send(),
                      style: AppText.poppins(size: 15, weight: FontWeight.w500, color: AppColors.ink),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Message',
                        hintStyle: AppText.poppins(size: 15, weight: FontWeight.w500, color: AppColors.ink4),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _openAttachments,
                    child: const Icon(Icons.attach_file_rounded, color: AppColors.ink4, size: 21),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _captureAndSendCameraPhoto,
                    child: const Icon(Icons.camera_alt_outlined, color: AppColors.ink4, size: 21),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sending
                ? null
                : (_input.text.trim().isEmpty ? _startRecording : _send),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.evaGreen, shape: BoxShape.circle),
              child: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                  : Icon(_input.text.trim().isEmpty ? Icons.mic_rounded : Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  String _formatChatHistory() {
    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('Chat History with: ${widget.name}');
    buffer.writeln('Phone Number: ${widget.number}');
    buffer.writeln('Export Date: ${DateTime.now().toLocal()}');
    buffer.writeln('========================================\n');

    for (final m in _messages) {
      final time = m.timestamp != null ? m.timestamp!.toLocal().toString() : 'N/A';
      final sender = m.outgoing ? 'Agent' : widget.name;
      buffer.writeln('[$time] $sender: ${m.text}');
    }
    return buffer.toString();
  }

  Future<void> _handleDownload(String format) async {
    try {
      final history = _formatChatHistory();
      await Clipboard.setData(ClipboardData(text: history));
      
      Directory? downloadDir;
      if (Platform.isAndroid) {
        final publicDownload = Directory('/storage/emulated/0/Download');
        if (await publicDownload.exists()) {
          downloadDir = publicDownload;
        } else {
          downloadDir = await getDownloadsDirectory();
        }
      } else {
        downloadDir = await getDownloadsDirectory();
      }
      downloadDir ??= await getApplicationDocumentsDirectory();
      
      final sanitizedNumber = widget.number.replaceAll(RegExp(r'[^0-9]'), '');
      
      if (format == '.TXT') {
        final file = File("${downloadDir.path}/chat_$sanitizedNumber.txt");
        await file.writeAsString(history);
        _snack('Saved to: ${file.path}');
        
        try {
          await OpenFilex.open(file.path);
        } catch (e) {
          debugPrint('OpenFilex failed: $e');
          try {
            final fileUri = Uri.file(file.path);
            if (await canLaunchUrl(fileUri)) {
              await launchUrl(fileUri);
            }
          } catch (_) {}
        }
      } else if (format == '.PDF') {
        final pdf = pw.Document();
        final lines = history.split('\n');
        
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return [
                pw.Header(
                  level: 0,
                  child: pw.Text('Chat Export with ${widget.name}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                ),
                pw.SizedBox(height: 10),
                ...lines.map((line) {
                  final cleanLine = line.replaceAll(RegExp(r'[^\u0000-\uFFFF]'), '');
                  return pw.Paragraph(
                    text: cleanLine,
                    style: pw.TextStyle(fontSize: 10),
                    margin: const pw.EdgeInsets.symmetric(vertical: 2),
                  );
                }),
              ];
            },
          ),
        );
        
        final file = File("${downloadDir.path}/chat_$sanitizedNumber.pdf");
        await file.writeAsBytes(await pdf.save());
        _snack('Saved to: ${file.path}');
        
        try {
          await OpenFilex.open(file.path);
        } catch (e) {
          debugPrint('OpenFilex failed: $e');
          try {
            final fileUri = Uri.file(file.path);
            if (await canLaunchUrl(fileUri)) {
              await launchUrl(fileUri);
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      _snack('Failed to export: $e');
    }
  }

  void _showDownloadDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Download chat', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'Export your conversation with ${widget.name} — includes name, phone, timestamps, sender type and full message history.',
          style: AppText.poppins(size: 14, color: AppColors.ink3, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _handleDownload('.TXT');
                },
                child: Text('Download\n.TXT', textAlign: TextAlign.center, style: AppText.poppins(size: 15, weight: FontWeight.w800, color: const Color(0xFF757575))),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _handleDownload('.PDF');
                },
                child: Text('Download\n.PDF', textAlign: TextAlign.center, style: AppText.poppins(size: 15, weight: FontWeight.w800, color: const Color(0xFF1E7036))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBlockUser(bool block) async {
    try {
      _snack(block ? 'Blocking contact...' : 'Unblocking contact...');
      await AppScope.of(context).chat.blockUser(widget.number, block: block);
      if (mounted) {
        setState(() => _isBlocked = block);
        _snack(block ? 'Contact blocked' : 'Contact unblocked');
      }
    } catch (e) {
      if (mounted) _snack('Action failed: $e');
    }
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Block ${widget.name}?', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
        content: Text(
          'Blocked contacts will no longer be able to message you. You can unblock them anytime.',
          style: AppText.poppins(size: 14, color: AppColors.ink3, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: const Color(0xFF757575))),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _toggleBlockUser(true);
            },
            child: Text('Block', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: const Color(0xFFD32F2F))),
          ),
        ],
      ),
    );
  }

  Widget _blockedBanner() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF0F0),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad + 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.block_rounded, size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Text(
            'You blocked this contact',
            style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: () => _toggleBlockUser(false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.evaGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Unblock',
                style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        switch (v) {
          case 'lead':
            AppScope.of(context).leads.createLead({
              'name': widget.name,
              'mobile': widget.number,
              'status': 'New Lead',
              'isConverted': false,
            }).then((_) {
              setState(() => _isLead = true);
              _snack('Added to Leads');
            }).catchError((e) {
              _snack('$e'.replaceFirst('Exception: ', ''));
            });
          case 'unread':
            () async {
              try {
                final prefs = await SharedPreferences.getInstance();
                final list = prefs.getStringList('marked_unread_numbers') ?? [];
                if (!list.contains(widget.number)) {
                  list.add(widget.number);
                  await prefs.setStringList('marked_unread_numbers', list);
                  // Immediately bump the sidebar badge count
                  kUnreadChatsCount.value = kUnreadChatsCount.value + 1;
                }
                if (mounted) Navigator.of(context).pop();
              } catch (e) {
                _snack('Failed to mark as unread');
              }
            }();
          case 'export':
            _showDownloadDialog();
          case 'block':
            _showBlockDialog();
          case 'unblock':
            _toggleBlockUser(false);
        }
      },
      itemBuilder: (_) => [
        if (!_isLead)
          _mi('lead', Icons.person_add_alt_1_outlined, 'Add to Leads'),
        _mi('unread', Icons.mail_outline_rounded, 'Mark as unread'),
        _mi('export', Icons.download_rounded, 'Download chat'),
        const PopupMenuDivider(height: 1),
        if (_isBlocked)
          _mi('unblock', Icons.check_circle_outline_rounded, 'Unblock', isDanger: false)
        else
          _mi('block', Icons.block_rounded, 'Block', isDanger: true),
      ],
    );
  }

  PopupMenuItem<String> _mi(String v, IconData icon, String label, {bool isDanger = false}) => PopupMenuItem(
        value: v,
        child: Row(
          children: [
            Icon(icon, size: 18, color: isDanger ? AppColors.danger : AppColors.ink2),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppText.poppins(
                size: 13.5,
                weight: FontWeight.w600,
                color: isDanger ? AppColors.danger : AppColors.ink,
              ),
            ),
          ],
        ),
      );

  void _snack(String m) => appToast(context, m);

  // Interleave day separators + an E2E note before the first message.
  List<Widget> _withSeparators(List<MessageDto> msgs) {
    final out = <Widget>[_e2eBanner()];
    String? lastDay;
    for (final m in msgs) {
      final day = _dayKey(m.timestamp);
      if (day != lastDay) {
        out.add(_dayPill(day));
        lastDay = day;
      }
      out.add(_bubble(m));
    }
    return out;
  }

  String _dayKey(DateTime? dt) {
    if (dt == null) return 'Today';
    final d = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Widget _dayPill(String label) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xFFD7E7DB), borderRadius: BorderRadius.circular(8)),
          child: Text(label, style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink2)),
        ),
      );

  Widget _e2eBanner() => Center(
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: const Color(0xFFFDF6D8), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_rounded, size: 12, color: Color(0xFF8A7B2E)),
            const SizedBox(width: 6),
            Flexible(child: Text('Messages are end-to-end encrypted', textAlign: TextAlign.center, style: AppText.poppins(size: 11, weight: FontWeight.w600, color: const Color(0xFF8A7B2E)))),
          ]),
        ),
      );

  void _openAttachments() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttachmentSheet(
        onCatalogue: () {
          Navigator.of(context).pop();
          _openCatalogue();
        },
        onPick: (type, label) {
          Navigator.of(context).pop();
          if (type == 'template') {
            _pickTemplate();
            return;
          }
          if (type == 'text') {
            _pickQuickReply();
            return;
          }
          _pickAndUploadAttachment(type, label);
        },
      ),
    );
  }

  Future<void> _pickAndUploadAttachment(String type, String label) async {
    try {
      List<int> fileBytes;
      String filename;
      String contentType;

      if (type == 'image' || type == 'video') {
        final picker = ImagePicker();
        final XFile? file = type == 'image'
            ? await picker.pickImage(source: ImageSource.gallery)
            : await picker.pickVideo(source: ImageSource.gallery);
        
        if (file == null) return;
        fileBytes = await file.readAsBytes();
        filename = file.name;
        contentType = type == 'image' ? 'image/jpeg' : 'video/mp4';
      } else {
        final FilePickerResult? res = await FilePicker.platform.pickFiles(
          type: type == 'audio'
              ? FileType.audio
              : FileType.any,
        );

        if (res == null || res.files.isEmpty) {
          return;
        }

        final file = res.files.first;
        final bytes = file.bytes;
        final path = file.path;
        
        if (bytes != null) {
          fileBytes = bytes;
        } else if (path != null) {
          fileBytes = await File(path).readAsBytes();
        } else {
          throw Exception('Could not read file data');
        }
        filename = file.name;
        contentType = file.extension != null ? 'application/${file.extension}' : 'application/octet-stream';
      }

      setState(() => _sending = true);
      _snack('Uploading $label...');

      final chat = AppScope.of(context).chat;
      final fileUrl = await chat.uploadChatFile(
        fileBytes,
        filename,
        contentType,
      );

      if (fileUrl.isEmpty) {
        throw Exception('Failed to get file URL from server');
      }

      _snack('Sending $label...');
      await chat.sendAttachment(
        widget.number,
        type,
        fileUrl,
        filename: filename,
      );

      _reload();
      _snack('$label sent successfully!');
    } catch (e) {
      _snack('Failed to send attachment: $e');
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _startRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _snack('Microphone permission denied. Please enable it in Settings.');
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      setState(() {
        _recording = true;
        _recordingDuration = 0;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && !_recordingPaused) {
          setState(() {
            _recordingDuration++;
          });
        }
      });
    } catch (e) {
      _snack('Failed to start recording: $e');
    }
  }

  Future<void> _togglePauseRecording() async {
    try {
      if (_recordingPaused) {
        await _audioRecorder.resume();
        setState(() => _recordingPaused = false);
      } else {
        await _audioRecorder.pause();
        setState(() => _recordingPaused = true);
      }
    } catch (e) {
      _snack('Pause/resume failed: $e');
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _recordingTimer?.cancel();
      await _audioRecorder.stop();
      setState(() {
        _recording = false;
        _recordingPaused = false;
        _recordingDuration = 0;
      });
    } catch (e) {
      _snack('Failed to cancel recording: $e');
    }
  }

  Future<void> _stopAndSendRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      setState(() {
        _recording = false;
        _recordingPaused = false;
      });

      if (path == null) {
        _snack('Recording failed');
        return;
      }

      final file = File(path);
      if (!await file.exists()) {
        _snack('Recording file not found');
        return;
      }

      final bytes = await file.readAsBytes();
      final filename = path.split('/').last;

      setState(() => _sending = true);
      _snack('Uploading voice note...');

      final chat = AppScope.of(context).chat;
      final fileUrl = await chat.uploadChatFile(
        bytes,
        filename,
        'audio/mp4',
      );

      if (fileUrl.isEmpty) {
        throw Exception('Failed to upload audio file');
      }

      _snack('Sending voice note...');
      await chat.sendAttachment(
        widget.number,
        'audio',
        fileUrl,
        filename: filename,
      );

      _reload();
      _snack('Voice note sent successfully!');
    } catch (e) {
      _snack('Failed to send recording: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _captureAndSendCameraPhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null) return;
      
      final bytes = await photo.readAsBytes();
      
      setState(() => _sending = true);
      _snack('Uploading photo...');

      final chat = AppScope.of(context).chat;
      final fileUrl = await chat.uploadChatFile(
        bytes,
        photo.name,
        'image/jpeg',
      );

      if (fileUrl.isEmpty) {
        throw Exception('Failed to get file URL from server');
      }

      _snack('Sending photo...');
      await chat.sendAttachment(
        widget.number,
        'image',
        fileUrl,
        filename: photo.name,
      );

      _reload();
      _snack('Photo sent successfully!');
    } catch (e) {
      _snack('Failed to capture photo: $e');
    } finally {
      setState(() => _sending = false);
    }
  }

  void _pickQuickReply() {
    final chat = AppScope.of(context).chat;
    String activeTab = 'All';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(sheetCtx).padding.bottom + 20),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(3)))),
                const SizedBox(height: 16),
                Text('Quick replies', style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
                Text('Tap to send instantly', style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.ink3)),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Text', 'Image', 'File', 'Video'].map((tab) {
                      final isSel = activeTab == tab;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(tab),
                          selected: isSel,
                          onSelected: (_) {
                            setSheetState(() {
                              activeTab = tab;
                            });
                          },
                          labelStyle: AppText.poppins(
                            size: 13,
                            weight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel ? Colors.white : AppColors.ink2,
                          ),
                          selectedColor: AppColors.evaGreen,
                          backgroundColor: const Color(0xFFF3F4F6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          side: BorderSide.none,
                          showCheckmark: false,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final res = await showDialog<Map<String, String>>(
                      context: context,
                      builder: (ctx) {
                        final titleCtrl = TextEditingController();
                        final msgCtrl = TextEditingController();
                        return AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Text('Add quick reply', style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: titleCtrl,
                                decoration: const InputDecoration(labelText: 'Title (shortcut)'),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: msgCtrl,
                                decoration: const InputDecoration(labelText: 'Message text'),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                if (titleCtrl.text.isNotEmpty && msgCtrl.text.isNotEmpty) {
                                  Navigator.of(ctx).pop({'title': titleCtrl.text, 'message': msgCtrl.text});
                                }
                              },
                              child: const Text('Add'),
                            ),
                          ],
                        );
                      },
                    );
                    if (res != null) {
                      try {
                        await chat.client.post('/chat/quick-reply', body: res);
                        _snack('Quick reply added');
                        Navigator.of(sheetCtx).pop();
                        _pickQuickReply();
                      } catch (e) {
                        _snack('Failed to save quick reply: $e');
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8FDF0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.evaGreen.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: const BoxDecoration(color: Color(0xFFFFF6ED), shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: const Icon(Icons.add_rounded, color: Color(0xFFE28A37), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Add quick reply', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
                              Text('Create one for this chat', style: AppText.poppins(size: 11.5, color: AppColors.ink3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: chat.fetchQuickReplies(),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.evaGreen));
                      }
                      var replies = snap.data ?? const [];
                      if (replies.isEmpty) {
                        replies = [
                          {'title': 'Greeting', 'message': 'Hi! 👋 Thanks for messaging us. How can I help you today?', 'type': 'text'},
                          {'title': 'One moment', 'message': 'Sure — give me a moment while I check that for you.', 'type': 'text'},
                          {'title': 'Anything else', 'message': 'Is there anything else I can help you with?', 'type': 'text'},
                          {'title': 'Thanks', 'message': 'Thank you for reaching out! Have a great day. 🙌', 'type': 'text'},
                        ];
                      }

                      final filtered = replies.where((r) {
                        if (activeTab == 'All') return true;
                        final type = (r['type'] ?? 'text').toString().toLowerCase();
                        if (activeTab == 'Text' && type == 'text') return true;
                        if (activeTab == 'Image' && type == 'image') return true;
                        if (activeTab == 'File' && (type == 'file' || type == 'document')) return true;
                        if (activeTab == 'Video' && type == 'video') return true;
                        return false;
                      }).toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No quick replies found for "$activeTab"',
                              style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink4),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final rep = filtered[idx];
                          final title = rep['title'] ?? rep['shortcut'] ?? 'Shortcut';
                          final text = rep['content'] ?? rep['message'] ?? rep['text'] ?? '';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 40, height: 40,
                              decoration: const BoxDecoration(color: Color(0xFFFFF6ED), shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: const Icon(Icons.schedule_rounded, color: Color(0xFFE28A37), size: 20),
                            ),
                            title: Text(title.toString(), style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
                            subtitle: Text(text.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 12, color: AppColors.ink3)),
                            onTap: () async {
                              Navigator.of(sheetCtx).pop();
                              try {
                                setState(() => _sending = true);
                                final qType = (rep['type'] ?? 'text').toString().toLowerCase();
                                final qContent = (rep['content'] ?? rep['message'] ?? rep['text'] ?? '').toString();
                                if (qType == 'text') {
                                  await chat.sendText(widget.number, qContent);
                                } else {
                                  final link = (rep['fileUrl'] ?? rep['link'] ?? '').toString();
                                  await chat.sendAttachment(
                                    widget.number,
                                    qType,
                                    link,
                                    filename: title.toString(),
                                    caption: qContent,
                                  );
                                }
                                _reload();
                              } catch (e) {
                                _snack(e.toString());
                              } finally {
                                setState(() => _sending = false);
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
          );
        },
      ),
    );
  }

  List<String> _extractVariables(String text) {
    final List<String> vars = [];
    int start = text.indexOf('{{');
    while (start != -1) {
      final end = text.indexOf('}}', start);
      if (end == -1) break;
      final variable = text.substring(start + 2, end).trim();
      if (variable.isNotEmpty && !vars.contains(variable)) {
        vars.add(variable);
      }
      start = text.indexOf('{{', end);
    }
    return vars;
  }

  List<InlineSpan> _buildPreviewSpans(String bodyText, Map<String, String> values) {
    final List<InlineSpan> spans = [];
    int start = 0;
    final reg = RegExp(r'\{\{([^}]+)\}\}');
    final matches = reg.allMatches(bodyText);
    for (final m in matches) {
      if (m.start > start) {
        spans.add(TextSpan(
          text: bodyText.substring(start, m.start),
          style: AppText.poppins(size: 13, color: AppColors.ink),
        ));
      }
      final varName = m.group(1)!.trim();
      final userVal = values[varName] ?? '';
      spans.add(TextSpan(
        text: userVal.isNotEmpty ? userVal : '{{$varName}}',
        style: AppText.poppins(
          size: 13,
          weight: FontWeight.w700,
          color: AppColors.evaGreenDeep,
        ),
      ));
      start = m.end;
    }
    if (start < bodyText.length) {
      spans.add(TextSpan(
        text: bodyText.substring(start),
        style: AppText.poppins(size: 13, color: AppColors.ink),
      ));
    }
    return spans;
  }

  void _pickTemplate() {
    final chat = AppScope.of(context).chat;
    String _sheetMode = 'list'; // 'list' or 'variables'
    Map<String, dynamic>? _activeTemplate;
    Map<String, String> _variableValues = {};
    String _selectedVariable = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(sheetCtx).padding.bottom + 20),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * 0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(3)))),
                const SizedBox(height: 16),
                if (_sheetMode == 'variables') ...[
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            _sheetMode = 'list';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.ink),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Fill variables', style: AppText.poppins(size: 16.5, weight: FontWeight.w800, color: AppColors.ink)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.of(sheetCtx).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 18, color: AppColors.ink3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF9E6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD3F2CD)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.center,
                          child: const Icon(Icons.text_fields_rounded, color: AppColors.evaGreenDeep, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((_activeTemplate!['name'] ?? 'template').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
                              const SizedBox(height: 2),
                              Text('${_activeTemplate!['category'] ?? 'Marketing'} · ${(_activeTemplate!['components'] is List ? _extractVariables((_activeTemplate!['components'] as List).firstWhere((c) => c['type'] == 'BODY', orElse: () => const {})['text'] ?? '').length : 1)} variable', style: AppText.poppins(size: 11.5, color: AppColors.ink3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _extractVariables((_activeTemplate!['components'] is List)
                        ? (_activeTemplate!['components'] as List).firstWhere((c) => c['type'] == 'BODY', orElse: () => const {})['text'] ?? ''
                        : (_activeTemplate!['message'] ?? _activeTemplate!['text'] ?? '').toString()).map((v) {
                      final isSel = _selectedVariable == v;
                      return GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            _selectedVariable = v;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFFEAF9E6) : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: isSel ? AppColors.evaGreenDeep : AppColors.line, width: 1.2),
                          ),
                          child: Text(
                            '{{$v}}',
                            style: AppText.poppins(
                              size: 12.5,
                              weight: isSel ? FontWeight.w800 : FontWeight.w600,
                              color: isSel ? AppColors.evaGreenDeep : AppColors.ink3,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 14, color: AppColors.ink3),
                            const SizedBox(width: 6),
                            Text('Enter value', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2)),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppColors.ink3),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: ValueKey(_selectedVariable),
                          controller: TextEditingController(text: _variableValues[_selectedVariable] ?? '')
                            ..selection = TextSelection.fromPosition(TextPosition(offset: (_variableValues[_selectedVariable] ?? '').length)),
                          onChanged: (val) {
                            setSheetState(() {
                              _variableValues[_selectedVariable] = val;
                            });
                          },
                          style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
                          decoration: InputDecoration(
                            hintText: 'Value for {{$_selectedVariable}}',
                            hintStyle: AppText.poppins(size: 12.5, color: AppColors.ink4),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            filled: true,
                            fillColor: AppColors.surface2,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Preview', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF9E6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: _buildPreviewSpans(
                          ((_activeTemplate!['components'] is List)
                              ? (_activeTemplate!['components'] as List).firstWhere((c) => c['type'] == 'BODY', orElse: () => const {})['text'] ?? ''
                              : (_activeTemplate!['message'] ?? _activeTemplate!['text'] ?? '').toString()).toString(),
                          _variableValues,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final bodyText = ((_activeTemplate!['components'] is List)
                            ? (_activeTemplate!['components'] as List).firstWhere((c) => c['type'] == 'BODY', orElse: () => const {})['text'] ?? ''
                            : (_activeTemplate!['message'] ?? _activeTemplate!['text'] ?? '').toString()).toString();
                        final vars = _extractVariables(bodyText);
                        for (final v in vars) {
                          if ((_variableValues[v] ?? '').trim().isEmpty) {
                            _snack('Please fill value for {{$v}}');
                            return;
                          }
                        }
                        
                        final id = (_activeTemplate!['_id'] ?? _activeTemplate!['id'] ?? _activeTemplate!['name'] ?? '').toString();
                        Navigator.of(sheetCtx).pop();
                        try {
                          setState(() => _sending = true);
                          final rawNumber = widget.number.split('@').first.replaceAll(RegExp(r'\D'), '');
                          String countryCode = '91';
                          String mobile = rawNumber;
                          if (rawNumber.startsWith('91') && rawNumber.length == 12) {
                            countryCode = '91';
                            mobile = rawNumber.substring(2);
                          } else if (rawNumber.startsWith('1') && rawNumber.length == 11) {
                            countryCode = '1';
                            mobile = rawNumber.substring(1);
                          } else if (rawNumber.length == 10) {
                            countryCode = '91';
                            mobile = rawNumber;
                          }

                          String finalSentence = bodyText;
                          _variableValues.forEach((variable, val) {
                            finalSentence = finalSentence.replaceAll('{{$variable}}', val);
                          });

                          final reqBody = {
                            'countryCode': countryCode,
                            'contactNumber': mobile,
                            'mobile': mobile,
                            'toNumber': rawNumber.length == 10 ? '91$mobile' : rawNumber,
                            'fullMobile': rawNumber.length == 10 ? '91$mobile' : rawNumber,
                            'method': 'single',
                            'campaignId': 'intervene-send',
                            'header': finalSentence,
                            'templateId': id,
                            ..._variableValues,
                          };

                          await chat.sendTemplate(id, reqBody);

                          // Persist reopened number locally
                          final prefs = await SharedPreferences.getInstance();
                          final reopened = prefs.getStringList('reopened_chat_numbers') ?? [];
                          if (!reopened.contains(widget.number)) {
                            reopened.add(widget.number);
                            if (mobile.isNotEmpty && !reopened.contains(mobile)) reopened.add(mobile);
                            await prefs.setStringList('reopened_chat_numbers', reopened);
                          }

                          if (mounted) {
                            setState(() {
                              _templateSent = true;
                              _aiHandling = true;
                              _manuallyIntervened = true;
                            });
                          }
                          _reload();
                          _snack('Template sent successfully');
                        } catch (e) {
                          _snack(e.toString().replaceFirst('Exception: ', ''));
                        } finally {
                          if (mounted) setState(() => _sending = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.evaGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text('Use template', style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Send a template', style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
                      GestureDetector(
                        onTap: () => Navigator.of(sheetCtx).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 18, color: AppColors.ink3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (val) => setSheetState(() => _searchTemplateQuery = val),
                    style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.ink3),
                      hintText: 'Search templates...',
                      hintStyle: AppText.poppins(size: 12.5, color: AppColors.ink4),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: AppColors.surface2,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _categoryTab('Marketing', setSheetState),
                      const SizedBox(width: 14),
                      _categoryTab('Utility', setSheetState),
                      const SizedBox(width: 14),
                      _categoryTab('Authentication', setSheetState),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: chat.fetchApprovedTemplates(),
                      builder: (sheetContext, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.evaGreen));
                        }
                        final allTemplates = snap.data ?? const [];
                        final filtered = allTemplates.where((t) {
                          final cat = (t['category'] ?? 'marketing').toString().toLowerCase();
                          final name = (t['name'] ?? t['templateName'] ?? '').toString().toLowerCase();
                          final activeCat = _selectedTemplateCategory.toLowerCase();
                          
                          final matchesCat = cat.startsWith(activeCat) || (activeCat == 'marketing' && cat == 'marketing') || (activeCat == 'utility' && cat == 'utility') || (activeCat == 'authentication' && cat == 'authentication');
                          final matchesQuery = _searchTemplateQuery.isEmpty || name.contains(_searchTemplateQuery.toLowerCase());
                          
                          return matchesCat && matchesQuery;
                        }).toList();

                        if (filtered.isEmpty) {
                          return Center(
                            child: Text(
                              _searchTemplateQuery.isNotEmpty ? 'No matches' : 'No templates in this category',
                              style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink3),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, idx) {
                            final t = filtered[idx];
                            final name = (t['name'] ?? t['templateName'] ?? 'template').toString();
                            final body = (t['components'] is List)
                                ? (t['components'] as List).firstWhere((c) => c['type'] == 'BODY', orElse: () => const {})['text'] ?? ''
                                : (t['message'] ?? t['text'] ?? '').toString();
                            
                            String type = 'Text';
                            IconData icon = Icons.text_fields_rounded;
                            
                            final lowerBody = body.toString().toLowerCase();
                            if (lowerBody.contains('.png') || lowerBody.contains('.jpg') || lowerBody.contains('image')) {
                              type = 'Image';
                              icon = Icons.image_outlined;
                            } else if (lowerBody.contains('.mp4') || lowerBody.contains('video')) {
                              type = 'Video';
                              icon = Icons.videocam_outlined;
                            } else if (lowerBody.contains('.pdf') || lowerBody.contains('document')) {
                              type = 'Document';
                              icon = Icons.insert_drive_file_outlined;
                            }

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42, height: 42,
                                    decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(10)),
                                    alignment: Alignment.center,
                                    child: Icon(icon, color: AppColors.evaGreenDeep, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
                                        const SizedBox(height: 2),
                                        Text(body.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 11.5, color: AppColors.ink3)),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(6)),
                                          child: Text(type, style: AppText.poppins(size: 9.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () async {
                                      final id = (t['_id'] ?? t['id'] ?? t['name'] ?? '').toString();
                                      final vars = _extractVariables(body.toString());
                                      if (vars.isNotEmpty) {
                                        setSheetState(() {
                                          _sheetMode = 'variables';
                                          _activeTemplate = t;
                                          _variableValues = {for (var v in vars) v: ''};
                                          _selectedVariable = vars.first;
                                        });
                                      } else {
                                        Navigator.of(sheetCtx).pop();
                                        try {
                                           setState(() => _sending = true);
                                           final rawNumber = widget.number.split('@').first.replaceAll(RegExp(r'\D'), '');
                                           String countryCode = '91';
                                           String mobile = rawNumber;
                                           if (rawNumber.startsWith('91') && rawNumber.length == 12) {
                                             countryCode = '91';
                                             mobile = rawNumber.substring(2);
                                           } else if (rawNumber.startsWith('1') && rawNumber.length == 11) {
                                             countryCode = '1';
                                             mobile = rawNumber.substring(1);
                                           } else if (rawNumber.length == 10) {
                                             countryCode = '91';
                                             mobile = rawNumber;
                                           }

                                           final reqBody = {
                                             'countryCode': countryCode,
                                             'contactNumber': mobile,
                                             'mobile': mobile,
                                             'toNumber': rawNumber.length == 10 ? '91$mobile' : rawNumber,
                                             'fullMobile': rawNumber.length == 10 ? '91$mobile' : rawNumber,
                                             'method': 'single',
                                             'campaignId': 'intervene-send',
                                             'header': body.toString(),
                                             'templateId': id,
                                           };

                                           await chat.sendTemplate(id, reqBody);

                                           // Persist reopened number locally
                                           final prefs = await SharedPreferences.getInstance();
                                           final reopened = prefs.getStringList('reopened_chat_numbers') ?? [];
                                           if (!reopened.contains(widget.number)) {
                                             reopened.add(widget.number);
                                             if (mobile.isNotEmpty && !reopened.contains(mobile)) reopened.add(mobile);
                                             await prefs.setStringList('reopened_chat_numbers', reopened);
                                           }

                                           if (mounted) {
                                             setState(() {
                                               _templateSent = true;
                                               _aiHandling = true;
                                               _manuallyIntervened = true;
                                             });
                                           }
                                           _reload();
                                           _snack('Template sent successfully');
                                         } catch (e) {
                                           _snack(e.toString().replaceFirst('Exception: ', ''));
                                         } finally {
                                           if (mounted) setState(() => _sending = false);
                                         }
                                      }
                                    },
                                    child: Container(
                                      width: 32, height: 32,
                                      decoration: const BoxDecoration(color: AppColors.evaGreen, shape: BoxShape.circle),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _categoryTab(String label, StateSetter setSheetState) {
    final active = _selectedTemplateCategory == label;
    return GestureDetector(
      onTap: () => setSheetState(() => _selectedTemplateCategory = label),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.poppins(size: 13.5, weight: active ? FontWeight.w800 : FontWeight.w600, color: active ? AppColors.evaGreenDeep : AppColors.ink3)),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 24,
            color: active ? AppColors.evaGreenDeep : Colors.transparent,
          ),
        ],
      ),
    );
  }

  void _openCatalogue() {
    setState(() {
      _showCatalogue = true;
    });
  }

  Widget _defaultHeaderLogo() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.storefront_outlined, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text(
            'AskEva',
            style: AppText.poppins(size: 16.5, weight: FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _addToDraftOrder(ProductDto p) {
    setState(() {
      ProductDto? existingKey;
      for (final k in _draftOrderProducts.keys) {
        if (k == p) {
          existingKey = k;
          break;
        }
      }
      if (existingKey != null) {
        _draftOrderProducts[existingKey] = _draftOrderProducts[existingKey]! + 1;
      } else {
        _draftOrderProducts[p] = 1;
      }
      // Keep Catalogue sheet open so they can drag/add multiple items
    });
  }

  void _updateDraftQty(ProductDto p, int delta) {
    setState(() {
      ProductDto? targetKey;
      for (final k in _draftOrderProducts.keys) {
        if (k == p) {
          targetKey = k;
          break;
        }
      }
      if (targetKey != null) {
        final newQty = _draftOrderProducts[targetKey]! + delta;
        if (newQty <= 0) {
          _draftOrderProducts.remove(targetKey);
        } else {
          _draftOrderProducts[targetKey] = newQty;
        }
      }
    });
  }

  void _clearDraftOrder() {
    setState(() {
      _draftOrderProducts.clear();
    });
  }

  Widget _topErrorCard() {
    final errText = _topError ?? '24-Hour WhatsApp Session Expired';
    final isSessionError = errText.contains('sesison') || errText.contains('session') || errText.contains('24-Hour');
    final displayText = isSessionError
        ? '24-Hour Session Expired — Please send a Template message to re-open the chat window.'
        : errText;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E8F5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFEBF3FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF0066FF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayText,
                  style: AppText.poppins(
                    size: 13,
                    weight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _topError = null),
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.ink3,
                ),
              ),
            ],
          ),
          if (isSessionError) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() => _topError = null);
                  _pickTemplate();
                },
                icon: const Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.white),
                label: Text('Send Template Message', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.evaGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendDraftOrder() async {
    if (_draftOrderProducts.isEmpty) return;
    if (_sessionClosed) {
      setState(() {
        _topError = '24-Hour Session Expired — Please send a Template message to re-open the chat window.';
      });
      _pickTemplate();
      return;
    }
    try {
      setState(() => _sending = true);
      final chat = AppScope.of(context).chat;
      final commerce = AppScope.of(context).commerce;
      
      final catalogs = await commerce.fetchCatalogs();
      final defaultCatalogId = catalogs.isNotEmpty
          ? (catalogs.first['catalogId'] ?? catalogs.first['_id'] ?? '').toString()
          : '';

      final Map<String, List<String>> productsByCatalog = {};
      _draftOrderProducts.forEach((p, qty) {
        final cId = p.catalogId.isNotEmpty ? p.catalogId : defaultCatalogId;
        if (cId.isEmpty) return;
        final pId = p.productId.isNotEmpty ? p.productId : p.id;
        productsByCatalog.putIfAbsent(cId, () => []);
        for (int i = 0; i < qty; i++) {
          productsByCatalog[cId]!.add(pId);
        }
      });

      if (productsByCatalog.isEmpty) {
        throw Exception('No active catalog connected to send this order');
      }

      final cleanNumber = widget.number.split('@').first.replaceAll(RegExp(r'[^0-9]'), '');

      for (final entry in productsByCatalog.entries) {
        await chat.sendCatalog(
          catalogId: entry.key,
          productItems: entry.value,
          userNumber: cleanNumber,
        );
      }
      
      try {
        await chat.setIntervene(cleanNumber, true);
        setState(() {
          _aiHandling = false;
          _manuallyIntervened = true;
        });
      } catch (_) {}
      
      setState(() {
        _draftOrderProducts.clear();
        _showCatalogue = false; // Auto close Catalogue sheet on send order
      });
      _reload();
      _snack('Order sent');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _sendCatalogProduct(ProductDto p) async {
    _addToDraftOrder(p);
  }

  double _parsePrice(dynamic val) {
    if (val == null) return 0.0;
    final numVal = val is num ? val.toDouble() : (double.tryParse(val.toString()) ?? 0.0);
    if (numVal <= 0) return 0.0;
    // If value is in paise (e.g. >= 10000 or integer > 5000 divisible by 100), convert to Rupees:
    if (numVal >= 10000 || (numVal > 5000 && numVal % 100 == 0)) {
      return numVal / 100.0;
    }
    return numVal;
  }

  String _fmtRs(double amount) {
    if (amount <= 0) return '₹0';
    if (amount == amount.truncateToDouble()) {
      final str = amount.toInt().toString();
      if (str.length > 3) {
        final last3 = str.substring(str.length - 3);
        final otherDigits = str.substring(0, str.length - 3);
        final formattedOther = otherDigits.replaceAllMapped(
          RegExp(r'(\d)(?=(\d\d)+(?!\d))'),
          (m) => '${m[1]},',
        );
        return '₹$formattedOther,$last3';
      }
      return '₹$str';
    }
    return '₹${amount.toStringAsFixed(2)}';
  }

  Future<void> _loadCatalogProducts() async {
    try {
      final commerce = AppScope.of(context).commerce;
      final catalogs = await commerce.fetchCatalogs();
      final List<ProductDto> allProducts = [];

      for (final cat in catalogs) {
        final mongoId = (cat['_id'] ?? cat['id'] ?? '').toString();
        final fbCatalogId = (cat['catalogId'] ?? '').toString();
        final resolvedCatalogId = fbCatalogId.isNotEmpty ? fbCatalogId : mongoId;

        List<ProductDto> fetched = [];
        if (mongoId.isNotEmpty) {
          try {
            fetched = await commerce.fetchProductsByCatalog(mongoId);
          } catch (_) {}
        }
        if (fetched.isEmpty && fbCatalogId.isNotEmpty) {
          try {
            fetched = await commerce.fetchProductsByCatalog(fbCatalogId);
          } catch (_) {}
        }

        for (final p in fetched) {
          allProducts.add(ProductDto(
            id: p.id,
            name: p.name,
            price: p.price,
            image: p.image,
            currency: p.currency,
            catalogId: resolvedCatalogId,
            productId: p.productId,
          ));
        }
      }

      if (allProducts.isEmpty) {
        try {
          final fallback = await commerce.fetchProducts();
          allProducts.addAll(fallback);
        } catch (_) {}
      }

      final Map<String, ProductDto> unique = {};
      for (final p in allProducts) {
        final key = p.productId.isNotEmpty ? p.productId : (p.id.isNotEmpty ? p.id : p.name);
        unique.putIfAbsent(key, () => p);
      }

      if (mounted) {
        setState(() => _catalogProducts = unique.values.toList());
      }
    } catch (e) {
      debugPrint('[Chat] Error loading catalog products: $e');
    }
  }

  void _showOrderDetailsSheet(MessageDto m) {
    final data = m.rawJson['data'] ?? const {};
    final interactive = data['interactive'] ?? const {};
    final action = interactive['action'] ?? const {};
    final params = action['parameters'] ?? const {};
    final order = params['order'] ?? const {};
    final referenceId = (params['reference_id'] ?? m.id).toString();

    final rawSubtotal = params['subtotal']?['value'] ?? order['subtotal']?['value'] ?? 0;
    double subtotal = _parsePrice(rawSubtotal);

    final List<dynamic> rawItems = order['items'] ?? const [];
    final Map<String, ({String name, int qty, double price})> grouped = {};

    for (final j in rawItems) {
      final name = (j is Map ? (j['name'] ?? j['title'] ?? j['product_name'] ?? 'Product') : 'Product').toString();
      final qty = (j is Map && j['quantity'] is num) ? (j['quantity'] as num).toInt() : (int.tryParse(j?['quantity']?.toString() ?? '1') ?? 1);
      
      dynamic rawPrice;
      if (j is Map) {
        for (final k in ['unit_price', 'item_price', 'price', 'amount', 'total_price', 'value', 'cost']) {
          if (j.containsKey(k) && j[k] != null) {
            final p = _parsePrice(j[k]);
            if (p > 0) {
              rawPrice = j[k];
              break;
            }
          }
        }
      }
      
      double price = _parsePrice(rawPrice);

      // Always look up actual catalogue price from _catalogProducts
      final rId = (j is Map ? (j['retailer_id'] ?? j['product_retailer_id'] ?? j['productId'] ?? '') : '').toString().trim();
      final normName = name.toLowerCase().trim();

      final match = _catalogProducts.firstWhere(
        (p) {
          final pId = p.id.trim();
          final pProdId = p.productId.trim();
          final pNormName = p.name.toLowerCase().trim();

          if (rId.isNotEmpty && (pId == rId || pProdId == rId || pId.toLowerCase() == rId.toLowerCase())) {
            return true;
          }
          if (normName.isNotEmpty && pNormName.isNotEmpty) {
            if (pNormName == normName) return true;
            if (pNormName.contains(normName) || normName.contains(pNormName)) return true;
          }
          return false;
        },
        orElse: () => ProductDto(id: '', name: '', price: 0),
      );

      if (match.id.isNotEmpty && match.price > 0) {
        price = match.price;
      }

      final key = rId.isNotEmpty ? rId : normName;
      if (grouped.containsKey(key)) {
        final existing = grouped[key]!;
        grouped[key] = (
          name: existing.name.length >= name.length ? existing.name : name,
          qty: existing.qty + qty,
          price: existing.price > 0 ? existing.price : price,
        );
      } else {
        grouped[key] = (name: name, qty: qty, price: price);
      }
    }

    final items = grouped.values.toList();

    if (subtotal <= 0) {
      subtotal = items.fold(0.0, (sum, item) => sum + (item.price * item.qty));
    }

    // Auto-distribute subtotal among items if item prices are zero
    final hasZeroPrice = items.any((it) => it.price <= 0);
    if (hasZeroPrice && subtotal > 0) {
      final totalQty = items.fold<int>(0, (sum, it) => sum + it.qty);
      final avgUnit = totalQty > 0 ? (subtotal / totalQty) : 0.0;
      for (int i = 0; i < items.length; i++) {
        if (items[i].price <= 0) {
          items[i] = (name: items[i].name, qty: items[i].qty, price: avgUnit);
        }
      }
    }

    final rawShipping = params['shipping']?['value'] ?? order['shipping']?['value'] ?? 0;
    final shipping = _parsePrice(rawShipping);

    final rawDiscount = params['discount']?['value'] ?? order['discount']?['value'] ?? 0;
    final discount = _parsePrice(rawDiscount);

    final rawTax = params['tax']?['value'] ?? order['tax']?['value'] ?? 0;
    final tax = _parsePrice(rawTax);

    final rawTotal = order['total_amount']?['value'] ?? params['total_amount']?['value'] ?? 0;
    double totalAmount = _parsePrice(rawTotal);
    if (totalAmount <= 0) {
      totalAmount = subtotal + shipping + tax - discount;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).padding.bottom + 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.ink2),
                ),
                const SizedBox(width: 8),
                Text('Order details', style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(color: AppColors.evaGreen, shape: BoxShape.circle),
                    child: const Icon(Icons.storefront_outlined, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text('Tunepath Technologies', style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 4),
                  Text('Order #${referenceId.substring(0, referenceId.length.clamp(0, 8))}', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8FDF0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule_rounded, size: 14, color: AppColors.evaGreenDeep),
                        const SizedBox(width: 6),
                        Text('Awaiting payment', style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.evaGreenDeep)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 16),
            for (final it in items) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.shopping_bag_outlined, color: AppColors.evaGreenDeep, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.name, style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink)),
                        Text('Qty ${it.qty} · ${_fmtRs(it.price)}', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3)),
                      ],
                    ),
                  ),
                  Text(_fmtRs(it.price * it.qty), style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
                ],
              ),
              const SizedBox(height: 14),
            ],
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtotal', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3)),
                Text(_fmtRs(subtotal), style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
              ],
            ),
            if (shipping > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Shipping', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3)),
                  Text(_fmtRs(shipping), style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                ],
              ),
            ],
            if (tax > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tax', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3)),
                  Text(_fmtRs(tax), style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                ],
              ),
            ],
            if (discount > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Discount', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3)),
                  Text('-${_fmtRs(discount)}', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.danger)),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
                Text(_fmtRs(totalAmount), style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _launchPayUCheckout(totalAmount);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.evaGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text('Continue to pay - ${_fmtRs(totalAmount)}', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Future<void> _launchPayUCheckout(double amount) async {
    try {
      final scope = AppScope.of(context);
      final html = await scope.payments.addWallet(amount);
      final opened = await openGatewayHtml(html);
      if (mounted) {
        if (opened) {
          appToast(context, 'Opening secure PayU gateway for ₹${amount.toStringAsFixed(2)}…', isSuccess: true);
        } else {
          appToast(context, 'Could not open the PayU gateway. Please try again.', isError: true);
        }
      }
      final parts = widget.number.split('@');
      final digits = parts.first.replaceAll(RegExp(r'[^0-9+]'), '');
      await scope.payments.notifyPayment({
        'userNumber': digits,
        'totalAmount': amount,
        'status': 'completed',
      });
      _reload();
    } catch (e) {
      if (mounted) appToast(context, 'Failed to initiate payment: $e', isError: true);
    }
  }



  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  Widget _bubble(MessageDto m) {
    final t = m.type.toLowerCase();
    final data = m.rawJson['data'] ?? const {};
    final interactive = data['interactive'] ?? const {};
    final interactiveType = (interactive['type'] ?? '').toString().toLowerCase();
    final isOrderOrProduct = t.contains('order') || 
        t.contains('catalog') || 
        interactiveType == 'order' || 
        interactiveType == 'product' || 
        interactiveType == 'product_list' ||
        data['catalogId'] != null ||
        data['productItems'] != null ||
        (interactive['action'] != null && 
            (interactive['action']['product_retailer_id'] != null || 
             interactive['action']['sections'] != null ||
             interactive['action']['parameters'] != null));
             
    if (isOrderOrProduct) return _orderBubble(m);
    if (t.contains('template') || t.contains('interactive') || t.contains('button')) return _templateBubble(m);
    if (t.contains('image') || t.contains('photo') || t == 'aiimage') return _mediaBubble(m, Icons.image_rounded, 'Photo');
    if (t.contains('video')) return _mediaBubble(m, Icons.videocam_rounded, 'Video', tall: false);
    if (t.contains('voice')) return _voiceBubble(m);
    if (t.contains('audio')) return _fileBubble(m, Icons.headphones_rounded);
    if (t.contains('document') || t.contains('file')) return _fileBubble(m, Icons.description_rounded);
    if (t.contains('location')) return _locationBubble(m);
    if (t.contains('contact')) return _contactBubble(m);
    if (t.contains('poll')) return _pollBubble(m);
    if (t.contains('payment')) return _paymentBubble(m);
    if (t.contains('feedback') || t.contains('rating')) return _feedbackBubble(m);
    if (t.contains('reminder') || t.contains('system')) return _systemBubble(m);
    return _wrap(m, Text(m.text.isEmpty ? '[${m.type}]' : m.text, style: AppText.poppins(size: 14.5, weight: FontWeight.w500, color: AppColors.ink, height: 1.35)));
  }

  /// Common bubble shell with timestamp + ticks.
  Widget _wrap(MessageDto m, Widget child, {EdgeInsets pad = const EdgeInsets.fromLTRB(11, 8, 11, 7), double maxW = 280}) {
    return Align(
      alignment: m.outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxW),
        margin: const EdgeInsets.only(bottom: 8),
        padding: pad,
        decoration: BoxDecoration(
          color: m.outgoing ? AppColors.waBubbleOut : AppColors.waBubbleIn,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(10),
            topRight: const Radius.circular(10),
            bottomLeft: Radius.circular(m.outgoing ? 10 : 2),
            bottomRight: Radius.circular(m.outgoing ? 2 : 10),
          ),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 1, offset: Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            const SizedBox(height: 2),
            Row(mainAxisSize: MainAxisSize.min, children: [Text(_fmt(m.timestamp), style: AppText.poppins(size: 10.5, weight: FontWeight.w500, color: AppColors.ink4)), if (m.outgoing) ...[const SizedBox(width: 3), _tick(m.status)]]),
          ],
        ),
      ),
    );
  }

  /// 5-state delivery ticks: sending / sent / delivered / read / failed.
  Widget _tick(String status) {
    switch (status.toLowerCase()) {
      case 'sending':
      case 'pending':
        return const Icon(Icons.schedule_rounded, size: 13, color: AppColors.ink4);
      case 'failed':
      case 'error':
        return const Icon(Icons.error_outline_rounded, size: 13, color: AppColors.danger);
      case 'read':
        return const Icon(Icons.done_all_rounded, size: 15, color: AppColors.waTickBlue);
      case 'delivered':
        return const Icon(Icons.done_all_rounded, size: 15, color: AppColors.ink4);
      default: // sent
        return const Icon(Icons.done_rounded, size: 15, color: AppColors.ink4);
    }
  }

  String _getMediaUrl(MessageDto m) {
    final data = m.rawJson['data'];
    if (data is Map) {
      final type = m.type.toLowerCase();
      final typeObj = data[type];
      if (typeObj is Map && typeObj['link'] != null) {
        return typeObj['link'].toString();
      }
      if (data['link'] != null) {
        return data['link'].toString();
      }
      for (final key in ['image', 'video', 'document', 'audio', 'voice', 'file']) {
        final val = data[key];
        if (val is Map && val['link'] != null) {
          return val['link'].toString();
        }
      }
    }
    if (m.rawJson['link'] != null) {
      return m.rawJson['link'].toString();
    }
    if (m.rawJson['fileUrl'] != null) {
      return m.rawJson['fileUrl'].toString();
    }
    return '';
  }

  String _getFileName(MessageDto m) {
    final data = m.rawJson['data'];
    if (data is Map) {
      final type = m.type.toLowerCase();
      final typeObj = data[type];
      if (typeObj is Map && typeObj['filename'] != null) {
        return typeObj['filename'].toString();
      }
      if (data['filename'] != null) {
        return data['filename'].toString();
      }
    }
    if (m.rawJson['filename'] != null) {
      return m.rawJson['filename'].toString();
    }
    final url = _getMediaUrl(m);
    if (url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final decoded = Uri.decodeComponent(uri.pathSegments.last);
        final index = decoded.indexOf('Z-');
        if (index != -1 && index + 2 < decoded.length) {
          return decoded.substring(index + 2);
        }
        return decoded;
      }
    }
    return '';
  }

  String _getFileMeta(MessageDto m, String url) {
    String ext = 'Document';
    if (url.isNotEmpty) {
      final parts = url.split('.');
      if (parts.length > 1) {
        ext = parts.last.split('?').first.toUpperCase();
      }
    }
    return '$ext · Tap to view';
  }

  Future<void> _openMediaUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _snack('Could not open: $e');
    }
  }

  Widget _mediaBubble(MessageDto m, IconData icon, String label, {bool tall = true}) {
    final url = _getMediaUrl(m);
    final hasUrl = url.isNotEmpty;
    final isVideo = m.type.toLowerCase().contains('video');

    return _wrap(
      m,
      pad: const EdgeInsets.all(4),
      GestureDetector(
        onTap: () => _openMediaUrl(url),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 220,
                height: tall ? 180 : 130,
                color: AppColors.surface3,
                child: hasUrl
                    ? (isVideo
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(color: Colors.black87),
                              Center(
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: AppColors.waHeader,
                                    size: 32,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.videocam_rounded, color: Colors.white, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Video',
                                        style: AppText.poppins(size: 10, weight: FontWeight.w600, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(child: Icon(icon, size: 40, color: AppColors.ink4)),
                          ))
                    : Center(child: Icon(icon, size: 40, color: AppColors.ink4)),
              ),
            ),
            if (m.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(7, 6, 7, 0),
                child: Text(
                  m.text,
                  style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.ink),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _voiceBubble(MessageDto m) {
    return _wrap(
      m,
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 34, height: 34, alignment: Alignment.center, decoration: const BoxDecoration(color: AppColors.evaGreen, shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, size: 22, color: Colors.white)),
        const SizedBox(width: 8),
        SizedBox(width: 120, child: Row(children: List.generate(22, (i) => Expanded(child: Container(height: (i % 4 + 1) * 5.0, margin: const EdgeInsets.symmetric(horizontal: 0.6), decoration: BoxDecoration(color: AppColors.evaGreenDeep.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2))))))),
        const SizedBox(width: 8),
        Text('0:14', style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
      ]),
    );
  }

  Widget _fileBubble(MessageDto m, IconData icon) {
    final url = _getMediaUrl(m);
    var name = _getFileName(m);
    if (name.isEmpty) {
      name = m.text.isNotEmpty ? m.text : 'Document';
    }
    final meta = _getFileMeta(m, url);

    return _wrap(
      m,
      GestureDetector(
        onTap: () => _openMediaUrl(url),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 20, color: AppColors.evaGreenDeep),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink),
                  ),
                ),
                Text(
                  meta,
                  style: AppText.poppins(size: 11, weight: FontWeight.w500, color: AppColors.ink3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationBubble(MessageDto m) {
    return _wrap(
      m,
      pad: const EdgeInsets.all(4),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: Container(width: 220, height: 120, color: const Color(0xFFDDE7DD), child: const Center(child: Icon(Icons.location_on_rounded, size: 36, color: AppColors.danger)))),
        Padding(padding: const EdgeInsets.fromLTRB(7, 6, 7, 0), child: Text(m.text.isEmpty ? 'Shared location' : m.text, style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink))),
      ]),
    );
  }

  Widget _contactBubble(MessageDto m) {
    return _wrap(
      m,
      Row(mainAxisSize: MainAxisSize.min, children: [
        InitialsAvatar(initials: _initials(m.text.isEmpty ? 'Contact' : m.text), color: AppColors.evaGreenDark, size: 38, radius: 19),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(m.text.isEmpty ? 'Contact card' : m.text, style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink)),
          Text('Tap to view contact', style: AppText.poppins(size: 11, weight: FontWeight.w500, color: AppColors.ink3)),
        ]),
      ]),
    );
  }

  Widget _pollBubble(MessageDto m) {
    final opts = ['Yes, interested', 'Maybe later', 'No thanks'];
    return _wrap(
      m,
      maxW: 250,
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(m.text.isEmpty ? 'Poll' : m.text, style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
        const SizedBox(height: 8),
        for (var i = 0; i < opts.length; i++) ...[
          Text(opts[i], style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2)),
          const SizedBox(height: 3),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: [0.6, 0.3, 0.1][i], minHeight: 6, backgroundColor: AppColors.surface3, color: AppColors.evaGreen)),
          const SizedBox(height: 7),
        ],
      ]),
    );
  }

  Widget _paymentBubble(MessageDto m) {
    return _wrap(
      m,
      maxW: 240,
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [const Icon(Icons.payments_rounded, size: 18, color: AppColors.evaGreenDeep), const SizedBox(width: 6), Text('Payment request', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink))]),
        const SizedBox(height: 6),
        Text(m.text.isEmpty ? '₹ 499.00' : m.text, style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.evaGreenDeep)),
        const SizedBox(height: 8),
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8), alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.evaGreen, borderRadius: BorderRadius.circular(8)), child: Text('Pay now', style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: Colors.white))),
      ]),
    );
  }

  Widget _feedbackBubble(MessageDto m) {
    return _wrap(
      m,
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(m.text.isEmpty ? 'How was your experience?' : m.text, style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink)),
        const SizedBox(height: 6),
        Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < 5; i++) Icon(i < 4 ? Icons.star_rounded : Icons.star_border_rounded, size: 20, color: AppColors.warning)]),
      ]),
    );
  }

  Widget _systemBubble(MessageDto m) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFFE8F0E8), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.alarm_rounded, size: 13, color: AppColors.ink3), const SizedBox(width: 6), Flexible(child: Text(m.text.isEmpty ? 'Reminder' : m.text, style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink2)))]),
        ),
      );

  String _findRetailerId(dynamic json) {
    if (json is Map) {
      if (json.containsKey('product_retailer_id') && json['product_retailer_id'] != null) {
        return json['product_retailer_id'].toString();
      }
      if (json.containsKey('retailer_id') && json['retailer_id'] != null) {
        return json['retailer_id'].toString();
      }
      if (json.containsKey('productId') && json['productId'] != null) {
        return json['productId'].toString();
      }
      for (final val in json.values) {
        final found = _findRetailerId(val);
        if (found.isNotEmpty) return found;
      }
    } else if (json is List) {
      for (final val in json) {
        final found = _findRetailerId(val);
        if (found.isNotEmpty) return found;
      }
    }
    return '';
  }

  ProductDto? _findProductInJson(dynamic json) {
    if (json is Map) {
      for (final entry in json.entries) {
        final key = entry.key.toString().toLowerCase();
        final val = entry.value;
        if (key == 'name' || key == 'title' || key == 'productname' || key == 'item_name') {
          final valStr = val.toString().trim();
          if (valStr.isNotEmpty && valStr.toLowerCase() != 'null') {
            final match = _catalogProducts.firstWhere(
              (p) => p.name.toLowerCase().trim() == valStr.toLowerCase() ||
                     p.id.toLowerCase() == valStr.toLowerCase() ||
                     p.productId.toLowerCase() == valStr.toLowerCase(),
              orElse: () => ProductDto(id: '', name: '', price: 0),
            );
            if (match.id.isNotEmpty) return match;
            return ProductDto(id: '', name: valStr, price: 0);
          }
        }
        final found = _findProductInJson(val);
        if (found != null) return found;
      }
    } else if (json is List) {
      for (final val in json) {
        final found = _findProductInJson(val);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Interactive order card (WhatsApp "Review and pay" message).
  Widget _orderBubble(MessageDto m) {
    final data = m.rawJson['data'] ?? const {};
    final interactive = data['interactive'] ?? const {};
    final action = interactive['action'] ?? const {};
    final params = action['parameters'] ?? const {};
    final order = params['order'] ?? const {};
    
    // Total Amount:
    final rawTotal = order['total_amount']?['value'] ?? params['total_amount']?['value'];
    double totalAmount = _parsePrice(rawTotal);
    
    // Items:
    final List<dynamic> rawItems = order['items'] ?? const [];
    if (totalAmount <= 0 && rawItems.isNotEmpty) {
      for (final it in rawItems) {
        if (it is Map) {
          final p = _parsePrice(it['item_price'] ?? it['price'] ?? it['amount']);
          final q = it['quantity'] is num ? (it['quantity'] as num).toInt() : (int.tryParse(it['quantity'].toString()) ?? 1);
          totalAmount += p * q;
        }
      }
    }

    final String retailerId = (rawItems.isNotEmpty 
        ? (rawItems.first['retailer_id'] ?? rawItems.first['product_retailer_id'] ?? '')
        : (action['product_retailer_id'] ?? '')).toString();
    
    String name = '';
    String imgUrl = '';

    if (rawItems.isNotEmpty && rawItems.first is Map) {
      final firstItem = rawItems.first as Map;
      final itemName = (firstItem['name'] ?? firstItem['title'] ?? firstItem['item_name'] ?? '').toString().trim();
      if (itemName.isNotEmpty) {
        name = itemName;
      }
    }
    
    final scannedId = _findRetailerId(m.rawJson);
    final lookupId = scannedId.isNotEmpty ? scannedId : retailerId;
    
    if (lookupId.isNotEmpty) {
      final p = _catalogProducts.firstWhere(
        (prod) => prod.id == lookupId || 
                  prod.productId == lookupId || 
                  prod.id.toLowerCase() == lookupId.toLowerCase() ||
                  prod.productId.toLowerCase() == lookupId.toLowerCase() ||
                  prod.name.toLowerCase() == lookupId.toLowerCase(),
        orElse: () => ProductDto(id: '', name: '', price: 0),
      );
      if (p.id.isNotEmpty) {
        if (name.isEmpty) name = p.name;
        if (imgUrl.isEmpty) imgUrl = p.image;
      }
    }
    
    if (name.isEmpty || imgUrl.isEmpty) {
      final matchedProd = _findProductInJson(m.rawJson);
      if (matchedProd != null) {
        if (name.isEmpty && matchedProd.name.isNotEmpty) name = matchedProd.name;
        if (imgUrl.isEmpty && matchedProd.image.isNotEmpty) imgUrl = matchedProd.image;
      }
    }

    if (name.isEmpty) {
      final headerText = (interactive['header']?['text'] ?? interactive['body']?['text'] ?? '').toString().trim();
      if (headerText.isNotEmpty) {
        name = headerText;
      } else if (m.text.isNotEmpty) {
        name = m.text;
      } else if (_catalogProducts.isNotEmpty) {
        name = _catalogProducts.first.name;
      } else {
        name = 'Catalog Product';
      }
    }
    
    int totalQty = 0;
    if (rawItems.isNotEmpty) {
      for (final it in rawItems) {
        if (it is Map) {
          final q = it['quantity'] is num ? (it['quantity'] as num).toInt() : (int.tryParse(it['quantity']?.toString() ?? '1') ?? 1);
          totalQty += q;
        } else {
          totalQty += 1;
        }
      }
    } else {
      totalQty = 1;
    }

    final itemsText = totalQty == 1 ? '1 item' : '$totalQty items';
    final distinctCount = rawItems.length;
    final String titleText = distinctCount > 1 ? '$name +${distinctCount - 1} more' : (totalQty > 1 ? '$name (Qty $totalQty)' : name);

    return Align(
      alignment: m.outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: m.outgoing ? AppColors.waBubbleOut : AppColors.waBubbleIn,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 1, offset: Offset(0, 1))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              width: double.infinity,
              color: AppColors.evaGreen,
              child: imgUrl.isNotEmpty
                  ? Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultHeaderLogo())
                  : _defaultHeaderLogo(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ORDER #${m.id.isEmpty ? 'DETAILS' : m.id.substring(0, m.id.length.clamp(0, 6)).toUpperCase()}',
                      style: AppText.poppins(size: 9.5, weight: FontWeight.w700, color: AppColors.ink4, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.evaGreen,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: imgUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                              )
                            : const SizedBox(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(titleText, style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
                            const SizedBox(height: 2),
                            Text(itemsText, style: AppText.poppins(size: 11.5, color: AppColors.ink3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppColors.line),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3)),
                      Text(_fmtRs(totalAmount), style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppColors.line),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _showOrderDetailsSheet(m),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Review and pay', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.line),
                  InkWell(
                    onTap: () => _launchPayUCheckout(totalAmount),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Pay now', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
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

  Widget _templateBubble(MessageDto m) {
    return Align(
      alignment: m.outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 270),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: m.outgoing ? AppColors.waBubbleOut : AppColors.waBubbleIn,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 1, offset: Offset(0, 1))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 14, color: AppColors.ink3),
                      const SizedBox(width: 6),
                      Flexible(child: Text(m.type, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink2))),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(999)),
                        child: Text(m.type.contains('interactive') ? 'Interactive' : 'Marketing', style: AppText.poppins(size: 9.5, weight: FontWeight.w700, color: AppColors.ink3)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(m.text.isEmpty ? 'Template message' : m.text, style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.ink, height: 1.35)),
                ],
              ),
            ),
            if (m.buttons.isNotEmpty) ...[
              for (final btn in m.buttons) ...[
                const Divider(height: 1, color: Color(0xFFE0E0E0)),
                InkWell(
                  onTap: () {
                    setState(() {
                      _input.text = btn.text;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (btn.type == 'phone')
                          const Icon(Icons.phone, size: 14, color: Color(0xFF0077E6))
                        else if (btn.type == 'url')
                          const Icon(Icons.open_in_new, size: 14, color: Color(0xFF0077E6))
                        else if (btn.type == 'flow')
                          const Icon(Icons.edit, size: 14, color: Color(0xFF0077E6))
                        else
                          const Icon(Icons.reply, size: 14, color: Color(0xFF0077E6)),
                        const SizedBox(width: 8),
                        Text(
                          btn.text,
                          style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: const Color(0xFF0077E6)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '';
    final l = dt.toLocal();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    return '$h:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'AM' : 'PM'}';
  }
}

/// WhatsApp-style attachment grid (`Document / Picture / Video / …`).
class _AttachmentSheet extends StatelessWidget {
  final VoidCallback onCatalogue;
  final void Function(String type, String label) onPick;
  const _AttachmentSheet({required this.onCatalogue, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, Color, Color, VoidCallback?)>[
      (Icons.insert_drive_file_outlined, 'Document', const Color(0xFF7C5CFC), Colors.white, () => onPick('document', 'Document')),
      (Icons.image_outlined, 'Picture', const Color(0xFF5271FF), Colors.white, () => onPick('image', 'Photo')),
      (Icons.videocam_outlined, 'Video', const Color(0xFFEF5350), Colors.white, () => onPick('video', 'Video')),
      (Icons.headphones_rounded, 'Audio', const Color(0xFF03A9F4), Colors.white, () => onPick('audio', 'Audio')),
      (Icons.description_outlined, 'Template', const Color(0xFF00B09B), Colors.white, () => onPick('template', 'Template')),
      (Icons.bolt_rounded, 'Quick Reply', const Color(0xFFFFA726), Colors.white, () => onPick('text', 'Quick reply')),
      (Icons.storefront_outlined, 'Catalogue', const Color(0xFFEAF9E6), const Color(0xFF177A36), onCatalogue),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 22),
          Wrap(
            spacing: 0,
            runSpacing: 22,
            children: items.map((it) {
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 40) / 3,
                child: GestureDetector(
                  onTap: () {
                    if (it.$5 != null) {
                      it.$5!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 58, height: 58, alignment: Alignment.center,
                        decoration: BoxDecoration(color: it.$3, shape: BoxShape.circle),
                        child: Icon(it.$1, color: it.$4, size: 25),
                      ),
                      const SizedBox(height: 8),
                      Text(it.$2, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _CatalogueSheet extends StatefulWidget {
  final void Function(ProductDto) onSendProduct;
  final VoidCallback? onClose;
  const _CatalogueSheet({required this.onSendProduct, this.onClose});

  @override
  State<_CatalogueSheet> createState() => _CatalogueSheetState();
}

class _CatalogueSheetState extends State<_CatalogueSheet> {
  List<ProductDto> _products = [];
  List<Map<String, dynamic>> _catalogs = [];
  String _selectedCatalogId = 'all';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final commerce = AppScope.of(context).commerce;
      final fetchedCatalogs = await commerce.fetchCatalogs();
      final List<ProductDto> allProducts = [];

      for (final cat in fetchedCatalogs) {
        final mongoId = (cat['_id'] ?? cat['id'] ?? '').toString();
        final fbCatalogId = (cat['catalogId'] ?? '').toString();
        final resolvedCatalogId = fbCatalogId.isNotEmpty ? fbCatalogId : mongoId;
        
        List<ProductDto> fetched = [];
        if (mongoId.isNotEmpty) {
          try {
            fetched = await commerce.fetchProductsByCatalog(mongoId);
          } catch (e) {
            debugPrint('Error fetching products by mongoId $mongoId: $e');
          }
        }
        if (fetched.isEmpty && fbCatalogId.isNotEmpty) {
          try {
            fetched = await commerce.fetchProductsByCatalog(fbCatalogId);
          } catch (e) {
            debugPrint('Error fetching products by fbCatalogId $fbCatalogId: $e');
          }
        }

        final products = fetched.map((p) => ProductDto(
          id: p.id,
          name: p.name,
          price: p.price,
          image: p.image,
          currency: p.currency,
          catalogId: resolvedCatalogId,
          productId: p.productId,
        )).toList();
        allProducts.addAll(products);
      }

      // Fallback: If no products were found per catalog, fetch all commerce products directly
      if (allProducts.isEmpty) {
        try {
          final fallbackProducts = await commerce.fetchProducts();
          if (fallbackProducts.isNotEmpty) {
            allProducts.addAll(fallbackProducts);
          }
        } catch (e) {
          debugPrint('Error fetching fallback commerce products: $e');
        }
      }

      // Deduplicate products by id/productId
      final Map<String, ProductDto> unique = {};
      for (final p in allProducts) {
        final key = p.productId.isNotEmpty ? p.productId : (p.id.isNotEmpty ? p.id : p.name);
        unique.putIfAbsent(key, () => p);
      }

      if (mounted) {
        setState(() {
          _catalogs = fetchedCatalogs;
          _products = unique.values.toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading catalogs in CatalogueSheet: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _selectedCatalogId == 'all'
        ? _products
        : _products.where((p) => p.catalogId == _selectedCatalogId).toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).padding.bottom + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(3)))),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 38, height: 38, alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.storefront_outlined, size: 19, color: AppColors.evaGreenDeep),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Catalogue', style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
                    Text(
                      _loading ? 'Loading products…' : '${filteredProducts.length} product${filteredProducts.length == 1 ? '' : 's'} available',
                      style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: widget.onClose ?? () => Navigator.of(context).pop(),
                child: const Icon(Icons.close_rounded, size: 20, color: AppColors.ink3),
              ),
            ],
          ),

          // Catalog filter chips if multiple catalogs exist
          if (_catalogs.length > 1) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('All Catalogs', style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: _selectedCatalogId == 'all' ? Colors.white : AppColors.ink2)),
                    selected: _selectedCatalogId == 'all',
                    selectedColor: AppColors.evaGreen,
                    backgroundColor: AppColors.surface2,
                    onSelected: (_) => setState(() => _selectedCatalogId = 'all'),
                  ),
                  const SizedBox(width: 8),
                  ..._catalogs.map((cat) {
                    final cId = (cat['catalogId'] ?? cat['_id'] ?? cat['id'] ?? '').toString();
                    final cName = (cat['name'] ?? 'Catalog').toString();
                    final isSel = _selectedCatalogId == cId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cName, style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: isSel ? Colors.white : AppColors.ink2)),
                        selected: isSel,
                        selectedColor: AppColors.evaGreen,
                        backgroundColor: AppColors.surface2,
                        onSelected: (_) => setState(() => _selectedCatalogId = cId),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.open_with_rounded, size: 14, color: AppColors.evaGreenDeep),
              const SizedBox(width: 6),
              Expanded(child: Text('Drag a product into the chat, or tap + to build an order', style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.ink3))),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const SizedBox(
              height: 168,
              child: Center(child: CircularProgressIndicator(color: AppColors.evaGreen)),
            )
          else if (filteredProducts.isEmpty)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'No products found in this catalog.',
                  style: AppText.poppins(size: 13, color: AppColors.ink4),
                ),
              ),
            )
          else
            SizedBox(
              height: 168,
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                itemCount: filteredProducts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final p = filteredProducts[i];
                  final card = Container(
                    width: 132,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 92,
                          width: double.infinity,
                          color: AppColors.surface2,
                          child: p.image.isNotEmpty
                              ? Image.network(p.image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, size: 24, color: AppColors.ink4))
                              : const Icon(Icons.image_outlined, size: 24, color: AppColors.ink4),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink)),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('₹${p.price.toStringAsFixed(0)}', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink)),
                                  InkWell(
                                    onTap: () {
                                      widget.onSendProduct(p);
                                    },
                                    child: Container(
                                      width: 26, height: 26, alignment: Alignment.center,
                                      decoration: const BoxDecoration(color: AppColors.evaGreen, shape: BoxShape.circle),
                                      child: const Icon(Icons.add_rounded, size: 17, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );

                  return Draggable<ProductDto>(
                    data: p,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Opacity(
                        opacity: 0.85,
                        child: SizedBox(
                          width: 132,
                          height: 168,
                          child: card,
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.35,
                      child: card,
                    ),
                    child: card,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _BlinkingRedDot extends StatefulWidget {
  const _BlinkingRedDot();

  @override
  State<_BlinkingRedDot> createState() => _BlinkingRedDotState();
}

class _BlinkingRedDotState extends State<_BlinkingRedDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
