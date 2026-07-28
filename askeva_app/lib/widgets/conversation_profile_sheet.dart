import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:characters/characters.dart';

import '../api/app_scope.dart';
import '../api/dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'common.dart';

Future<void> showConversationProfile(BuildContext context, {required String name, required String number, bool sessionClosed = false}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'ConversationProfile',
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.86,
          height: double.infinity,
          child: _ConversationProfileSheet(name: name, number: number, sessionClosed: sessionClosed),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      );
    },
  );
}

class _ConversationProfileSheet extends StatefulWidget {
  final String name;
  final String number;
  final bool sessionClosed;
  _ConversationProfileSheet({required this.name, required String number, this.sessionClosed = false})
      : number = number.replaceAll(RegExp(r'\D'), '');

  @override
  State<_ConversationProfileSheet> createState() => _ConversationProfileSheetState();
}

class _PaymentProductItem {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController(text: '0');
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
}

class _ConversationProfileSheetState extends State<_ConversationProfileSheet> {
  String get name => widget.name;
  String get number => widget.number;

  Map<String, dynamic>? _contactDetails;
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _assignedAgents = [];
  List<Map<String, dynamic>> _catalogs = [];
  final Map<String, bool> _expandedCatalogs = {};
  Map<String, List<ProductDto>> _catalogProducts = {};
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  bool _isMuted = false;

  // Track expanded state for accordion sections
  final Map<String, bool> _expanded = {
    'Assigned Agent': false,
    'Status Details': false,
    'Active Sessions': false,
    'Payments': false,
    'Catalogs': false,
    'Customer Journey': false,
    'Tags': false,
    'Notes': false,
  };

  final _noteController = TextEditingController();
  final _tagController = TextEditingController();
  
  // Payment Form Controllers
  final List<_PaymentProductItem> _paymentProducts = [];
  final _descriptionCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _shippingCtrl = TextEditingController(text: '0');
  final _taxRateCtrl = TextEditingController(text: '5');

  int systemNonInteractiveCount = 0;
  int userCount = 0;
  String firstUserMessageText = '—';
  String activityStatus = 'No user activity';
  String readableTimestamp = '—';
  DateTime? _lastIncomingMessageAt; // last customer message timestamp for 24-hr countdown
  
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _paymentProducts.add(_PaymentProductItem());
    _paymentProducts[0].priceCtrl.addListener(_onPaymentFormChanged);
    _paymentProducts[0].qtyCtrl.addListener(_onPaymentFormChanged);
    _discountCtrl.addListener(_onPaymentFormChanged);
    _shippingCtrl.addListener(_onPaymentFormChanged);
    _taxRateCtrl.addListener(_onPaymentFormChanged);
    _noteController.addListener(_onPaymentFormChanged);
    _tagController.addListener(_onPaymentFormChanged);
    
    _loadAll();
    _startTimer();
  }

  @override
  void dispose() {
    _noteController.removeListener(_onPaymentFormChanged);
    _tagController.removeListener(_onPaymentFormChanged);
    _noteController.dispose();
    _tagController.dispose();
    _descriptionCtrl.dispose();
    _discountCtrl.dispose();
    _shippingCtrl.dispose();
    _taxRateCtrl.dispose();
    for (final item in _paymentProducts) {
      item.priceCtrl.removeListener(_onPaymentFormChanged);
      item.qtyCtrl.removeListener(_onPaymentFormChanged);
      item.nameCtrl.dispose();
      item.priceCtrl.dispose();
      item.qtyCtrl.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _onPaymentFormChanged() {
    setState(() {});
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // Always rebuild so the Active Sessions countdown ticks every second
        setState(() {});
      }
    });
  }

  void _addPaymentProduct() {
    final item = _PaymentProductItem();
    item.priceCtrl.addListener(_onPaymentFormChanged);
    item.qtyCtrl.addListener(_onPaymentFormChanged);
    setState(() {
      _paymentProducts.add(item);
    });
  }

  void _removePaymentProduct(int index) {
    if (_paymentProducts.length <= 1) return;
    final item = _paymentProducts[index];
    item.priceCtrl.removeListener(_onPaymentFormChanged);
    item.qtyCtrl.removeListener(_onPaymentFormChanged);
    item.nameCtrl.dispose();
    item.priceCtrl.dispose();
    item.qtyCtrl.dispose();
    setState(() {
      _paymentProducts.removeAt(index);
    });
  }

  double get _subtotal {
    double sum = 0.0;
    for (final item in _paymentProducts) {
      final p = double.tryParse(item.priceCtrl.text) ?? 0.0;
      final q = double.tryParse(item.qtyCtrl.text) ?? 0.0;
      sum += p * q;
    }
    return sum;
  }

  double get _discount => double.tryParse(_discountCtrl.text) ?? 0.0;
  double get _shipping => double.tryParse(_shippingCtrl.text) ?? 0.0;
  double get _taxRate => double.tryParse(_taxRateCtrl.text) ?? 0.0;

  double get _taxAmount {
    final subAfterDisc = _subtotal - _discount;
    return (subAfterDisc * _taxRate) / 100.0;
  }

  double get _totalAmount {
    return _subtotal - _discount + _shipping + _taxAmount;
  }

  // Returns expiry time for a specific session type key (service/utility/marketing/authentication)
  // Supports: unix epoch 'expiration', ISO 'expiry'/'expiresAt', startedAt/createdAt + 24h, and
  // last incoming message + 24h as ultimate fallback.
  Map<String, String> _sessionCountdown(String type) {
    final sessionObj = _contactDetails?['session'];
    DateTime? expiry;

    if (sessionObj != null) {
      final typeData = sessionObj[type];
      if (typeData is Map) {
        // 1. Unix epoch expiration (e.g. WhatsApp API: typeData['expiration'] = 1722000000)
        final expirationRaw = typeData['expiration'];
        if (expirationRaw != null) {
          final expirationDouble = double.tryParse(expirationRaw.toString()) ?? 0.0;
          final expirationInt = expirationDouble.toInt();
          if (expirationInt > 0) {
            expiry = DateTime.fromMillisecondsSinceEpoch(expirationInt * 1000);
          }
        }
        // 2. ISO expiry field
        if (expiry == null) {
          final expiryRaw = typeData['expiry'] ?? typeData['expiresAt'] ?? typeData['expireAt'];
          if (expiryRaw != null) {
            expiry = DateTime.tryParse(expiryRaw.toString())?.toLocal();
          }
        }
        // 3. startedAt/createdAt + 24h
        if (expiry == null) {
          final startRaw = typeData['startedAt'] ?? typeData['createdAt'] ?? typeData['timestamp'] ?? typeData['updatedAt'];
          if (startRaw != null) {
            final start = DateTime.tryParse(startRaw.toString())?.toLocal();
            if (start != null) expiry = start.add(const Duration(hours: 24));
          }
        }
      } else if (typeData is String) {
        // Some backends store just the expiry ISO string directly
        expiry = DateTime.tryParse(typeData)?.toLocal();
        if (expiry != null && expiry.isBefore(DateTime.now())) {
          expiry = expiry.add(const Duration(hours: 24));
        }
      } else if (typeData is num) {
        // Unix epoch directly as number
        expiry = DateTime.fromMillisecondsSinceEpoch(typeData.toInt() * 1000);
      }
    }

    // Ultimate fallback: last incoming customer message + 24h
    if (expiry == null && _lastIncomingMessageAt != null) {
      expiry = _lastIncomingMessageAt!.toLocal().add(const Duration(hours: 24));
    }

    if (expiry == null) return {'hours': '00', 'mins': '00', 'secs': '00'};

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiryEpoch = expiry.millisecondsSinceEpoch ~/ 1000;
    final timeLeft = expiryEpoch - now;
    if (timeLeft <= 0) return {'hours': '00', 'mins': '00', 'secs': '00'};
    return {
      'hours': (timeLeft ~/ 3600).toString().padLeft(2, '0'),
      'mins': ((timeLeft % 3600) ~/ 60).toString().padLeft(2, '0'),
      'secs': (timeLeft % 60).toString().padLeft(2, '0'),
    };
  }

  List<String> get _currentGroupsList {
    final g1 = _contactDetails?['contact']?['groups'];
    final g2 = _contactDetails?['session']?['groups'];
    final rawGroups = (g1 is List) ? g1 : ((g2 is List) ? g2 : const []);
    return rawGroups
        .map((g) => g is Map ? (g['label'] ?? g['name'] ?? '').toString() : g.toString())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  List<String> get _currentTagsList {
    final t1 = _contactDetails?['contact']?['tags'];
    final t2 = _contactDetails?['session']?['tags'];
    final rawTags = (t1 is List) ? t1 : ((t2 is List) ? t2 : const []);
    return rawTags
        .map((t) => t is Map ? (t['label'] ?? t['name'] ?? '').toString() : t.toString())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _updateTags(List<String> newTags) async {
    final scope = AppScope.of(context);
    final contactObj = _contactDetails?['contact'] as Map?;
    final sessionObj = _contactDetails?['session'] as Map?;

    final contactId = (contactObj?['_id'] ?? '').toString();
    final sessionId = (sessionObj?['_id'] ?? '').toString();
    final idToSend = contactId.isNotEmpty ? contactId : sessionId;

    if (idToSend.isEmpty) {
      debugPrint('[Profile] Error: No contactId or sessionId found to update tags');
      return;
    }

    final reqBody = {
      'countryCode': contactObj?['countryCode'] ?? '',
      'phoneNumber': (contactObj?['contactNumber'] ?? sessionObj?['contactNumber'] ?? number).toString(),
      'contactName': (contactObj?['contactName'] ?? sessionObj?['profileName'] ?? name).toString(),
      'groups': _currentGroupsList,
      'tags': newTags,
    };

    setState(() => _loading = true);
    try {
      if (contactId.isNotEmpty) {
        await scope.contacts.updateContact(idToSend, {
          'id': idToSend,
          'contact': reqBody,
        });
      } else {
        await scope.contacts.updateContact(idToSend, {
          'id': idToSend,
          'session': reqBody,
        });
      }
      debugPrint('[Profile] Tags updated successfully via updateContact');
    } catch (e) {
      debugPrint('[Profile] Error updating tags: $e');
    }
    await _loadAll();
  }

  Future<void> _updateGroups(List<String> newGroups) async {
    final scope = AppScope.of(context);
    final contactObj = _contactDetails?['contact'] as Map?;
    final sessionObj = _contactDetails?['session'] as Map?;

    final contactId = (contactObj?['_id'] ?? '').toString();
    final sessionId = (sessionObj?['_id'] ?? '').toString();
    final idToSend = contactId.isNotEmpty ? contactId : sessionId;

    if (idToSend.isEmpty) {
      debugPrint('[Profile] Error: No contactId or sessionId found to update groups');
      return;
    }

    final reqBody = {
      'countryCode': contactObj?['countryCode'] ?? '',
      'phoneNumber': (contactObj?['contactNumber'] ?? sessionObj?['contactNumber'] ?? number).toString(),
      'contactName': (contactObj?['contactName'] ?? sessionObj?['profileName'] ?? name).toString(),
      'groups': newGroups,
      'tags': _currentTagsList,
    };

    setState(() => _loading = true);
    try {
      if (contactId.isNotEmpty) {
        await scope.contacts.updateContact(idToSend, {
          'id': idToSend,
          'contact': reqBody,
        });
      } else {
        await scope.contacts.updateContact(idToSend, {
          'id': idToSend,
          'session': reqBody,
        });
      }
      debugPrint('[Profile] Groups updated successfully via updateContact');
    } catch (e) {
      debugPrint('[Profile] Error updating groups: $e');
    }
    await _loadAll();
  }


  Future<void> _loadAll() async {
    if (number.isEmpty) return;
    setState(() => _loading = true);
    final scope = AppScope.of(context);
    final contactsService = scope.contacts;
    final chatService = scope.chat;
    final commerceService = scope.commerce;
    final agentsService = scope.agents;

    Map<String, dynamic>? details;
    List<Map<String, dynamic>> notes = [];
    List<Map<String, dynamic>> assigned = [];
    List<Map<String, dynamic>> catalogs = [];
    final Map<String, List<ProductDto>> catProducts = {};
    List<MessageDto> messages = [];
    List<Map<String, dynamic>> journey = [];

    // 0. Pre-fetch all agents (needed to resolve assigned agent IDs → objects)
    List<Map<String, dynamic>> allAgents = [];
    try {
      allAgents = await agentsService.fetchAgents();
      debugPrint('[Profile] Fetched ${allAgents.length} agents');
    } catch (e) {
      debugPrint('[Profile] Error loading agents list: $e');
    }

    // 1. Load contact details
    try {
      details = await contactsService.searchByNumber(number);
      debugPrint('[Profile] Contact details: contact=${details?["contact"] != null}, session=${details?["session"] != null}');
      if (details?['session'] != null) {
        final sess = details!['session'] as Map?;
        debugPrint('[Profile] Session keys: ${sess?.keys.toList()}');
        debugPrint('[Profile] Session.service: ${sess?["service"]}');
      }
    } catch (e) {
      debugPrint('[Profile] Error loading contact details: $e');
    }

    // 2. Load assigned agents AND notes together (single API call — matches web)
    //    Pass allAgents so IDs can be resolved to full agent objects
    try {
      final result = await chatService.fetchAssignedAgentsWithNotes(number, allAgents: allAgents);
      assigned = result.agents;
      notes = result.notes;
      debugPrint('[Profile] Assigned agents: ${assigned.length}, Notes: ${notes.length}');
    } catch (e) {
      debugPrint('[Profile] Error loading assigned agents/notes: $e');
    }

    // 3. Load catalogs and products (matches Web / LMS Commerce profile)
    try {
      final allCatalogs = await commerceService.fetchCatalogs();
      final connectedOnly = allCatalogs.where((c) {
        final isConnected = c['isConnected'];
        if (isConnected == null) return true; // Default to true if field omitted
        final str = isConnected.toString().toLowerCase().trim();
        return str == 'true' || str == '1';
      }).toList();
      catalogs = connectedOnly.isNotEmpty ? connectedOnly : allCatalogs;
      debugPrint('[Profile] Catalogs total=${allCatalogs.length} active=${catalogs.length}');
      
      for (final catalog in catalogs) {
        final mongoId = (catalog['_id'] ?? catalog['id'] ?? '').toString();
        final fbCatalogId = (catalog['catalogId'] ?? '').toString();
        final keyId = fbCatalogId.isNotEmpty ? fbCatalogId : mongoId;
        
        List<ProductDto> fetched = [];
        if (mongoId.isNotEmpty) {
          try {
            fetched = await commerceService.fetchProductsByCatalog(mongoId);
          } catch (err) {
            debugPrint('[Profile] Error fetching products by mongoId $mongoId: $err');
          }
        }
        if (fetched.isEmpty && fbCatalogId.isNotEmpty) {
          try {
            fetched = await commerceService.fetchProductsByCatalog(fbCatalogId);
          } catch (err) {
            debugPrint('[Profile] Error fetching products by fbCatalogId $fbCatalogId: $err');
          }
        }

        final products = fetched.map((p) => ProductDto(
          id: p.id,
          name: p.name,
          price: p.price,
          image: p.image,
          currency: p.currency,
          catalogId: keyId,
          productId: p.productId,
        )).toList();
        if (keyId.isNotEmpty) {
          catProducts[keyId] = products;
          _expandedCatalogs[keyId] = true; // Expand by default so products are visible
        }
        debugPrint('[Profile] Catalog $keyId has ${products.length} products');
      }

      // Fallback: If no products were found per catalog or catProducts is empty, fetch all products via GET /v1/commerce/getProducts
      if (catProducts.isEmpty || catProducts.values.every((list) => list.isEmpty)) {
        try {
          final allProds = await commerceService.fetchProducts();
          if (allProds.isNotEmpty) {
            if (catalogs.isEmpty) {
              final defaultCat = {'_id': 'default_cat', 'name': 'AskEva Commerce', 'productCount': allProds.length};
              catalogs = [defaultCat];
              catProducts['default_cat'] = allProds;
              _expandedCatalogs['default_cat'] = true;
            } else {
              for (final cat in catalogs) {
                final k = (cat['catalogId'] ?? cat['_id'] ?? cat['id'] ?? '').toString();
                if (k.isNotEmpty) {
                  catProducts[k] = allProds;
                  _expandedCatalogs[k] = true;
                }
              }
            }
          }
        } catch (err) {
          debugPrint('[Profile] Fallback all-products fetch error: $err');
        }
      }
    } catch (e) {
      debugPrint('[Profile] Error loading catalogs: $e');
    }

    // 4. Load messages (for status stats)
    try {
      messages = await chatService.fetchMessages(number, limit: 1000);
      debugPrint('[Profile] Messages loaded: ${messages.length}');
    } catch (e) {
      debugPrint('[Profile] Error loading messages: $e');
    }

    // Load local Mute status
    final pref = await SharedPreferences.getInstance();
    final mutedList = pref.getStringList('muted_numbers') ?? [];
    _isMuted = mutedList.contains(number);

    // 5. Load customer journey (filtered by number — matches React)
    try {
      journey = await chatService.fetchCustomerJourney(number);
      debugPrint('[Profile] Journey events: ${journey.length}');
    } catch (e) {
      debugPrint('[Profile] Error loading customer journey: $e');
    }

    if (mounted) {
      setState(() {
        _contactDetails = details;
        _notes = notes;
        _assignedAgents = assigned;
        _catalogs = catalogs;
        _catalogProducts = catProducts;
        _events = journey;
        _isMuted = _isMuted;
        
        // Re-calculate stats from messages
        systemNonInteractiveCount = 0;
        userCount = 0;
        firstUserMessageText = '—';
        activityStatus = 'No user activity';
        readableTimestamp = '—';
        _calculateMessageStats(messages);

        _loading = false;
      });
    }
  }

  void _calculateMessageStats(List<MessageDto> messages) {
    if (messages.isEmpty) return;

    DateTime? lastActiveTimestamp;
    DateTime? lastConversationTimestamp;

    // Loop backwards (from newest to oldest) to find latest timestamps
    for (int i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      final j = m.rawJson;
      final sentBy = (j['sentBy'] ?? '').toString().toLowerCase();

      if (lastConversationTimestamp == null && m.timestamp != null) {
        lastConversationTimestamp = m.timestamp;
      }

      if (sentBy == 'user' && lastActiveTimestamp == null && m.timestamp != null) {
        lastActiveTimestamp = m.timestamp;
      }
    }

    // Count messages
    for (final m in messages) {
      final j = m.rawJson;
      final sentBy = (j['sentBy'] ?? '').toString().toLowerCase();
      if (sentBy == 'system') {
        if (j['messageKey'] != null) {
          systemNonInteractiveCount++;
        } else {
          userCount++;
        }
      }
    }

    // First user message text (find first user message in chronological order)
    try {
      final firstUserMsg = messages.firstWhere((m) {
        final sentBy = (m.rawJson['sentBy'] ?? '').toString().toLowerCase();
        return sentBy == 'user';
      });
      firstUserMessageText = firstUserMsg.text.isNotEmpty ? firstUserMsg.text : '—';
    } catch (_) {}

    // Format readableTimestamp (Last Active Conversation)
    if (lastConversationTimestamp != null) {
      final date = lastConversationTimestamp.toLocal();
      final formattedDate = '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
      final hours = date.hour;
      final minutes = date.minute;
      final ampm = hours >= 12 ? 'PM' : 'AM';
      final formattedHours = hours % 12 == 0 ? 12 : hours % 12;
      final formattedMinutes = minutes.toString().padLeft(2, '0');
      readableTimestamp = '$formattedDate $formattedHours.$formattedMinutes$ampm';
    }

    // Format activityStatus
    if (lastActiveTimestamp != null) {
      _lastIncomingMessageAt = lastActiveTimestamp; // store for 24hr countdown
      final now = DateTime.now();
      final diff = now.difference(lastActiveTimestamp.toLocal());
      final diffInSeconds = diff.inSeconds;

      if (diffInSeconds < 60) {
        activityStatus = 'Active now';
      } else if (diffInSeconds < 3600) {
        final minutes = diff.inMinutes;
        activityStatus = ' $minutes ${minutes == 1 ? "min" : "mins"} ago';
      } else if (diffInSeconds < 86400) {
        final hours = diff.inHours;
        activityStatus = ' $hours ${hours == 1 ? "hr" : "hrs"} ago';
      } else if (diffInSeconds < 2592000) {
        final days = diff.inDays;
        activityStatus = ' $days ${days == 1 ? "day" : "days"} ago';
      } else if (diffInSeconds < 31536000) {
        final months = diffInSeconds ~/ 2592000;
        activityStatus = ' $months ${months == 1 ? "month" : "months"} ago';
      } else {
        final years = diffInSeconds ~/ 31536000;
        activityStatus = ' $years ${years == 1 ? "yr" : "yrs"} ago';
      }
    }
  }

  Future<void> _showAddAgentDialog() async {
    final scope = AppScope.of(context);
    final agentsService = scope.agents;
    final chatService = scope.chat;
    try {
      final agentsList = await agentsService.fetchAgents();
      // Get the IDs already assigned so we can skip them in the list
      final assignedIds = _assignedAgents.map((a) => (a['_id'] ?? a['id'] ?? '').toString()).toSet();
      final unassigned = agentsList.where((a) {
        final id = (a['_id'] ?? a['id'] ?? '').toString();
        return id.isNotEmpty && !assignedIds.contains(id);
      }).toList();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Assign Agent'),
          children: [
            if (unassigned.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('All agents are already assigned.'),
              )
            else
              ...unassigned.map((agent) {
                final name = (agent['username'] ?? agent['name'] ?? 'Agent').toString();
                final id = (agent['_id'] ?? '').toString();
                final email = (agent['email'] ?? '').toString();
                return SimpleDialogOption(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    setState(() => _loading = true);
                    // Add this agent to the existing assigned list (not replace)
                    final currentIds = _assignedAgents
                        .map((a) => (a['_id'] ?? a['id'] ?? '').toString())
                        .where((s) => s.isNotEmpty)
                        .toList();
                    await chatService.assignAgents(number, [...currentIds, id]);
                    await _loadAll();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppText.poppins(size: 14.5, weight: FontWeight.w700)),
                        if (email.isNotEmpty)
                          Text(email, style: AppText.poppins(size: 12, color: AppColors.ink3)),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      );
    } catch (e) {
      debugPrint("Error fetching agents: $e");
    }
  }

  Future<void> _showAddGroupDialog() async {
    final scope = AppScope.of(context);
    final contactsService = scope.contacts;
    final textCtrl = TextEditingController();
    
    try {
      final fetchedGroups = await contactsService.fetchGroups();
      final groupsList = _currentGroupsList;
      final groupNames = fetchedGroups
          .map((g) => (g['name'] ?? '').toString())
          .where((s) => s.isNotEmpty && !groupsList.contains(s))
          .toList();

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add to Groups'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textCtrl,
                decoration: const InputDecoration(
                  labelText: 'New Group Name',
                  hintText: 'Type to create new group...',
                ),
              ),
              if (groupNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Or select existing:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: groupNames.length,
                    itemBuilder: (c, idx) {
                      final gName = groupNames[idx];
                      return ListTile(
                        title: Text(gName),
                        dense: true,
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          await _updateGroups([...groupsList, gName]);
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final newName = textCtrl.text.trim();
                Navigator.of(ctx).pop();
                if (newName.isNotEmpty) {
                  await _updateGroups([...groupsList, newName]);
                }
              },
              child: const Text('Create & Add'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint("Error fetching groups: $e");
    }
  }

  Future<void> _sendPaymentNotification() async {
    for (final item in _paymentProducts) {
      if (item.nameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter product name for all items.')),
        );
        return;
      }
      final price = double.tryParse(item.priceCtrl.text) ?? -1.0;
      if (price < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid price.')),
        );
        return;
      }
    }

    final formattedProducts = _paymentProducts.map((p) {
      final name = p.nameCtrl.text.trim();
      final price = double.tryParse(p.priceCtrl.text) ?? 0.0;
      final quantity = int.tryParse(p.qtyCtrl.text) ?? 1;
      return {
        'name': name,
        'price': price,
        'quantity': quantity,
        'total': price * quantity,
      };
    }).toList();

    final payload = {
      'userNumber': number,
      'products': formattedProducts,
      'subtotal': _subtotal,
      'discount': _discount,
      'subtotalAfterDiscount': _subtotal - _discount,
      'shippingPrice': _shipping,
      'taxRate': _taxRate,
      'taxAmount': _taxAmount,
      'totalAmount': _totalAmount,
      'description': _descriptionCtrl.text.trim(),
    };

    setState(() => _loading = true);
    final scope = AppScope.of(context);
    final paymentsService = scope.payments;
    final chatService = scope.chat;
    try {
      await paymentsService.notifyPayment(payload);
      await chatService.setIntervene(number, true);
      
      _paymentProducts.clear();
      _paymentProducts.add(_PaymentProductItem());
      _paymentProducts[0].priceCtrl.addListener(_onPaymentFormChanged);
      _paymentProducts[0].qtyCtrl.addListener(_onPaymentFormChanged);
      _descriptionCtrl.clear();
      _discountCtrl.text = '0';
      _shippingCtrl.text = '0';
      _taxRateCtrl.text = '5';
      
      await _loadAll();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment Notification sent successfully!')),
        );
      }
    } catch (e) {
      debugPrint("Error sending payment link: $e");
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send payment link: $e')),
        );
      }
    }
  }

  bool _isExpanded(String title) => _expanded[title] ?? false;

  Widget _section(IconData icon, String title, {required Widget child, Widget? trailing}) {
    final isExpanded = _isExpanded(title);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expanded[title] = !isExpanded;
              });
            },
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.evaGreen50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: AppColors.evaGreenDeep),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: AppText.poppins(
                      size: 14.5,
                      weight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  trailing,
                  const SizedBox(width: 8),
                ],
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.ink3,
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 12),
            child,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = avatarColorFor(name);
    final tagsList = _currentTagsList;
    final groupsList = _currentGroupsList;

    return Material(
      color: Colors.transparent,
      child: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                child: Row(
                  children: [
                    Text('Profile Details', style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
                    const Spacer(),
                    InkWell(onTap: () => Navigator.of(context).pop(), child: const Icon(Icons.close_rounded, size: 22, color: AppColors.ink2)),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.line),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.evaGreen))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                InitialsAvatar(initials: _initials(name), color: color, size: 76, radius: 38),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: AppColors.evaGreen,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(name, style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.ink)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  number,
                                  style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink3),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: number));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Phone number copied!')),
                                    );
                                  },
                                  child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.ink4),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _pillBtn(Icons.call_outlined, 'Call', () async {
                              final telUrl = Uri.parse('tel:$number');
                              try {
                                final launched = await launchUrl(telUrl);
                                if (!launched && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Could not initiate phone call.')),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            }),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _pillBtn(
                              _isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                              _isMuted ? 'Unmute' : 'Mute',
                              () async {
                                final pref = await SharedPreferences.getInstance();
                                final mutedList = pref.getStringList('muted_numbers') ?? [];
                                if (_isMuted) {
                                  mutedList.remove(number);
                                  await pref.setStringList('muted_numbers', mutedList);
                                  setState(() => _isMuted = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Notifications unmuted for $name.')),
                                    );
                                  }
                                } else {
                                  mutedList.add(number);
                                  await pref.setStringList('muted_numbers', mutedList);
                                  setState(() => _isMuted = true);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Notifications muted for $name.')),
                                    );
                                  }
                                }
                              }
                            ),
                          ),
                        ],
                      ),
                      
                      // 1. Assigned Agent Section
                      _section(Icons.person_outline_rounded, 'Assigned Agent', child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Conversation owner', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3)),
                          const SizedBox(height: 8),
                          if (_assignedAgents.isEmpty) ...[
                            Text('No agents assigned yet.', style: AppText.poppins(size: 13, color: AppColors.ink4)),
                            const SizedBox(height: 8),
                          ],
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ..._assignedAgents.map((agent) {
                                final username = agent['username'] ?? agent['name'] ?? 'Agent';
                                final initials = username.substring(0, 1).toUpperCase();
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.evaGreen50,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: AppColors.evaGreen200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 18,
                                        height: 18,
                                        alignment: Alignment.center,
                                        decoration: const BoxDecoration(
                                          color: AppColors.evaGreen,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          initials,
                                          style: AppText.poppins(size: 10, weight: FontWeight.w800, color: Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        username,
                                        style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () async {
                                          final agentId = (agent['_id'] ?? agent['id'] ?? '').toString();
                                          setState(() => _loading = true);
                                          // Remove this specific agent — send remaining IDs
                                          final remainingIds = _assignedAgents
                                              .map((a) => (a['_id'] ?? a['id'] ?? '').toString())
                                              .where((id) => id.isNotEmpty && id != agentId)
                                              .toList();
                                          await AppScope.of(context).chat.assignAgents(number, remainingIds);
                                          await _loadAll();
                                        },
                                        child: const Icon(Icons.close_rounded, size: 13, color: AppColors.evaGreenDeep),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              InkWell(
                                onTap: _showAddAgentDialog,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: AppColors.line),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.add_rounded, size: 14, color: AppColors.ink2),
                                      const SizedBox(width: 4),
                                      Text('Add agent', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )),

                      // 2. Status Details Section
                      _section(Icons.show_chart_rounded, 'Status Details', child: Column(
                        children: [
                          _kv('User Active Status', activityStatus),
                          _kv('Last Conversation', readableTimestamp),
                          _kv('Template Messages', systemNonInteractiveCount.toString()),
                          _kv('Session Messages', userCount.toString()),
                           _kv('First User Message', firstUserMessageText),
                          _kv('Assigned Agent', '', trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_assignedAgents.isNotEmpty)
                                ..._assignedAgents.map((agent) => Padding(
                                  padding: const EdgeInsets.only(right: 6.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.evaGreen50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.evaGreen200),
                                    ),
                                    child: Text(
                                      (agent['username'] ?? agent['name'] ?? 'Agent').toString(),
                                      style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                                    ),
                                  ),
                                )),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.evaGreen, size: 20),
                                onPressed: _showAddAgentDialog,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          )),
                          _kv('Lead Status', '', trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFEEEAFE), borderRadius: BorderRadius.circular(999)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF7C5CFC), shape: BoxShape.circle)),
                                const SizedBox(width: 5),
                                Text(
                                  (_contactDetails?['contact']?['leadStatus'] ??
                                   _contactDetails?['contact']?['status'] ??
                                   'Customer').toString(),
                                  style: AppText.poppins(size: 11, weight: FontWeight.w700, color: const Color(0xFF7C5CFC)),
                                ),
                              ],
                            ),
                          )),
                          _kv('Groups', '', trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (groupsList.isNotEmpty)
                                ...groupsList.map((g) => Padding(
                                  padding: const EdgeInsets.only(right: 6.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface2,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.line),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          g,
                                          style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink2),
                                        ),
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: () async {
                                            final newGroups = groupsList.where((x) => x != g).toList();
                                            await _updateGroups(newGroups);
                                          },
                                          child: const Icon(Icons.close_rounded, size: 12, color: AppColors.ink3),
                                        ),
                                      ],
                                    ),
                                  ),
                                )),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.evaGreen, size: 20),
                                onPressed: _showAddGroupDialog,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          )),
                        ],
                      )),

                      // 3. Active Sessions Section — matches React/Web CountdownTimer
                      // Uses last incoming customer message timestamp + 24h (matches web logic)
                      _section(Icons.access_time_rounded, 'Active Sessions', child: Builder(
                        builder: (context) {
                          final sessionObj = _contactDetails?['session'] as Map?;
                          final sessionTypes = [
                            ('service', 'SERVICE WINDOW · UTILITY'),
                            ('utility', 'UTILITY'),
                            ('marketing', 'MARKETING'),
                            ('authentication', 'AUTHENTICATION'),
                          ];

                          // Build active sessions from explicit API session object
                          final activeSessions = <(String, Map<String, String>, String)>[];
                          for (final t in sessionTypes) {
                            final typeData = sessionObj?[t.$1];
                            if (typeData != null) {
                              final timeLeft = _sessionCountdown(t.$1);
                              final isActive = timeLeft['hours'] != '00' || timeLeft['mins'] != '00' || timeLeft['secs'] != '00';
                              if (isActive) {
                                activeSessions.add((t.$1, timeLeft, t.$2));
                              }
                            }
                          }

                          // Fallback: use last incoming customer message + 24h
                          // This is exactly how the web works (lastTs + 24h window)
                          if (activeSessions.isEmpty && _lastIncomingMessageAt != null) {
                            final expiry = _lastIncomingMessageAt!.toLocal().add(const Duration(hours: 24));
                            final remaining = expiry.difference(DateTime.now());
                            if (!remaining.isNegative) {
                              final timeLeft = _sessionCountdown('service');
                              activeSessions.add(('service', timeLeft, 'SERVICE WINDOW · UTILITY'));
                            }
                          }

                          if (activeSessions.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.ink4,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'No active sessions',
                                    style: AppText.poppins(size: 12, color: AppColors.ink4),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: activeSessions.map((s) {
                              final label = s.$3;
                              final timeLeft = s.$2;
                              final isActive = timeLeft['hours'] != '00' || timeLeft['mins'] != '00' || timeLeft['secs'] != '00';
                              final h = int.tryParse(timeLeft['hours']!) ?? 0;
                              final m = int.tryParse(timeLeft['mins']!) ?? 0;
                              // Amber = expiring within 30 minutes (matches web .amber class)
                              final isAmber = isActive && h == 0 && m < 30;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Label row — matches web .session-lbl
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? (isAmber ? const Color(0xFFB47608) : AppColors.evaGreen)
                                                : AppColors.ink4,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          label,
                                          style: AppText.poppins(
                                            size: 12,
                                            weight: FontWeight.w800,
                                            color: AppColors.ink3,
                                            letterSpacing: 0.04,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    // 3-column timer grid — matches web .timer-grid
                                    Row(
                                      children: [
                                        _countdown(timeLeft['hours']!, 'HOURS', amber: isAmber),
                                        const SizedBox(width: 10),
                                        _countdown(timeLeft['mins']!, 'MINS', amber: isAmber),
                                        const SizedBox(width: 10),
                                        _countdown(timeLeft['secs']!, 'SECS', amber: isAmber),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      )),

                      // 4. Payments Section
                      _section(Icons.payment_rounded, 'Payments', child: _paymentsForm()),

                      // 5. Catalogs Section
                      _section(Icons.storefront_outlined, 'Catalogs', child: Column(
                        children: [
                          if (_catalogs.isEmpty)
                            Text('No catalogs connected yet.', style: AppText.poppins(size: 13, color: AppColors.ink4)),
                          ..._catalogs.map((catalog) => _catalogSection(catalog)),
                        ],
                      )),

                      // 6. Customer Journey Section
                      _section(Icons.route_rounded, 'Customer Journey', child: _journey()),

                      // 7. Tags Section
                      _section(
                        Icons.label_outline_rounded,
                        'Tags',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: const BoxDecoration(color: AppColors.evaGreen, shape: BoxShape.circle),
                          child: Text(
                            '${tagsList.length}',
                            style: AppText.poppins(size: 10, weight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (tagsList.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text('No tags added yet.', style: AppText.poppins(size: 13, color: AppColors.ink4)),
                              ),
                            if (tagsList.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: tagsList.map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFBBF7D0)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(tag, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: const Color(0xFF15803D))),
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () async {
                                          final newTags = tagsList.where((t) => t != tag).toList();
                                          await _updateTags(newTags);
                                        },
                                        child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF15803D)),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _tagController,
                                    style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink),
                                    decoration: InputDecoration(
                                      hintText: 'Add a tag...',
                                      hintStyle: AppText.poppins(size: 13, color: AppColors.ink4),
                                      isDense: true,
                                      filled: true,
                                      fillColor: AppColors.surface2,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                InkWell(
                                  onTap: () async {
                                    final tag = _tagController.text.trim();
                                    if (tag.isNotEmpty) {
                                      final newTags = [...tagsList, tag];
                                      _tagController.clear();
                                      await _updateTags(newTags);
                                    }
                                  },
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: const BoxDecoration(
                                      color: AppColors.evaGreen,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 8. Notes Section
                      _section(
                        Icons.description_outlined,
                        'Notes',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_notes.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                                  child: Text(
                                    'No notes yet',
                                    style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink4).copyWith(fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ),
                            if (_notes.isNotEmpty)
                              ..._notes.map((noteObj) {
                                final noteText = (noteObj['note'] ?? noteObj['text'] ?? noteObj['content'] ?? noteObj['description'] ?? '').toString();
                                final meta = noteObj['metadata'] is Map ? noteObj['metadata'] as Map : const {};
                                final addedBy = (noteObj['username'] ?? noteObj['by'] ?? noteObj['addedBy'] ?? noteObj['agent'] ?? noteObj['agentName'] ?? noteObj['createdByName'] ?? noteObj['createdBy'] ?? noteObj['user'] ?? noteObj['userName'] ?? meta['username'] ?? meta['by'] ?? meta['agentName'] ?? '').toString().trim();
                                final dtRaw = noteObj['createdAt'] ?? noteObj['timestamp'] ?? noteObj['date'];
                                String timeStr = '';
                                if (dtRaw != null) {
                                  final dt = DateTime.tryParse(dtRaw.toString());
                                  if (dt != null) {
                                    final d = dt.toLocal();
                                    timeStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
                                  }
                                }
                                final subtitle = [
                                  if (addedBy.isNotEmpty && addedBy != 'null') 'Added by $addedBy',
                                  if (timeStr.isNotEmpty) timeStr,
                                ].join(' · ');

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface2,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(noteText, style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                                          if (subtitle.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(subtitle, style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3)),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () {
                                        final editController = TextEditingController(text: noteText);
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            title: Text('Edit Note', style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
                                            content: TextField(
                                              controller: editController,
                                              maxLines: 3,
                                              maxLength: 500,
                                              style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink),
                                              decoration: InputDecoration(
                                                hintText: 'Edit your note here...',
                                                hintStyle: AppText.poppins(size: 13, color: AppColors.ink4),
                                                filled: true,
                                                fillColor: AppColors.surface2,
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(ctx).pop(),
                                                child: Text('Cancel', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink3)),
                                              ),
                                              TextButton(
                                                onPressed: () async {
                                                  final newVal = editController.text.trim();
                                                  if (newVal.isEmpty) return;
                                                  final chatRepo = AppScope.of(context).chat;
                                                  Navigator.of(ctx).pop();
                                                  setState(() => _loading = true);
                                                  try {
                                                    await chatRepo.deleteNote(number, noteText);
                                                    await chatRepo.addNote(number, newVal);
                                                  } catch (e) {
                                                    debugPrint('Error editing note: $e');
                                                  } finally {
                                                    await _loadAll();
                                                  }
                                                },
                                                child: Text('Save', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      child: const Icon(Icons.edit_outlined, size: 18, color: AppColors.ink2),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () async {
                                        setState(() => _loading = true);
                                        await AppScope.of(context).chat.deleteNote(number, noteText);
                                        await _loadAll();
                                      },
                                      child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _noteController,
                                    maxLines: 1,
                                    maxLength: 500,
                                    style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink),
                                    decoration: InputDecoration(
                                      hintText: 'Type a note...',
                                      hintStyle: AppText.poppins(size: 13, color: AppColors.ink4),
                                      isDense: true,
                                      filled: true,
                                      fillColor: AppColors.surface2,
                                      counterText: '',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                InkWell(
                                  onTap: () async {
                                    final note = _noteController.text.trim();
                                    if (note.isNotEmpty) {
                                      setState(() => _loading = true);
                                      await AppScope.of(context).chat.addNote(number, note);
                                      _noteController.clear();
                                      await _loadAll();
                                    }
                                  },
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: const BoxDecoration(
                                      color: AppColors.evaGreen,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${_noteController.text.length}/500',
                                style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  ),
);
}

  Widget _pillBtn(IconData icon, String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.line)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 17, color: AppColors.ink2),
            const SizedBox(width: 8),
            Text(label, style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink)),
          ]),
        ),
      );

  Widget _kv(String k, String v, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(child: Text(k, style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3))),
            if (trailing != null) trailing else Text(v, style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink)),
          ],
        ),
      );

  // Countdown cell — matches web .timer-cell: equal width, centered, 30px number, unit below
  Widget _countdown(String value, String label, {bool amber = false}) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: amber ? const Color(0xFFFEF6E6) : AppColors.evaGreen50,
            border: Border.all(color: amber ? const Color(0xFFF8E3B0) : AppColors.evaGreen200),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: AppText.poppins(
                  size: 30,
                  weight: FontWeight.w800,
                  color: amber ? const Color(0xFFB47608) : AppColors.evaGreenDeep,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppText.poppins(
                  size: 11,
                  weight: FontWeight.w700,
                  color: AppColors.ink4,
                  letterSpacing: 0.05,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _paymentsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._paymentProducts.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          
          final price = double.tryParse(item.priceCtrl.text) ?? 0.0;
          final qty = double.tryParse(item.qtyCtrl.text) ?? 0.0;
          final itemTotal = price * qty;

          return Container(
            key: ValueKey(item),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Item #${index + 1}', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
                    const Spacer(),
                    if (_paymentProducts.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                        onPressed: () => _removePaymentProduct(index),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Product name', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3)),
                const SizedBox(height: 6),
                TextField(
                  controller: item.nameCtrl,
                  style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: 'Enter product name',
                    hintStyle: AppText.poppins(size: 13, color: AppColors.ink4),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.line)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.evaGreen)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Price (₹)', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: item.priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.line)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.evaGreen)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Qty', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: item.qtyCtrl,
                            keyboardType: TextInputType.number,
                            style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.line)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.evaGreen)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Item total', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3)),
                    const Spacer(),
                    Text('₹${itemTotal.toStringAsFixed(2)}', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
                  ],
                ),
              ],
            ),
          );
        }),
        Row(
          children: [
            InkWell(
              onTap: _addPaymentProduct,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.evaGreen50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.evaGreen200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 16, color: AppColors.evaGreenDeep),
                    const SizedBox(width: 6),
                    Text('Add Item', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Subtotal', style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
                Text('₹${_subtotal.toStringAsFixed(2)}', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Description (optional)', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)),
        const SizedBox(height: 6),
        TextField(
          controller: _descriptionCtrl,
          maxLines: 2,
          style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: 'Add some details...',
            hintStyle: AppText.poppins(size: 13, color: AppColors.ink4),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.evaGreen)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Discount (₹)', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _discountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.line)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.evaGreen)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Shipping (₹)', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _shippingCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.line)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.evaGreen)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Tax Rate (%)', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)),
        const SizedBox(height: 6),
        TextField(
          controller: _taxRateCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.evaGreen)),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC8E6C9)),
          ),
          child: Column(
            children: [
              _summaryRow('Subtotal', '₹${_subtotal.toStringAsFixed(2)}'),
              const SizedBox(height: 6),
              _summaryRow('Discount', '-₹${_discount.toStringAsFixed(2)}'),
              const SizedBox(height: 6),
              _summaryRow('Shipping', '₹${_shipping.toStringAsFixed(2)}'),
              const SizedBox(height: 6),
              _summaryRow('Tax', '₹${_taxAmount.toStringAsFixed(2)}'),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(color: Color(0xFFA5D6A7), height: 1, thickness: 1),
              ),
              Row(
                children: [
                  Text('Total', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: const Color(0xFF2E7D32))),
                  const Spacer(),
                  Text('₹${_totalAmount.toStringAsFixed(2)}', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: const Color(0xFF2E7D32))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _sendPaymentNotification,
            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            label: Text(
              'Send Payment Link',
              style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.evaGreen,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: AppText.poppins(size: 13, weight: FontWeight.w600, color: const Color(0xFF2E7D32))),
        const Spacer(),
        Text(value, style: AppText.poppins(size: 13, weight: FontWeight.w600, color: const Color(0xFF2E7D32))),
      ],
    );
  }

  Widget _catalogSection(Map<String, dynamic> catalog) {
    final mongoId = (catalog['_id'] ?? catalog['id'] ?? '').toString();
    final fbCatalogId = (catalog['catalogId'] ?? '').toString();
    final id = fbCatalogId.isNotEmpty ? fbCatalogId : mongoId;
    final name = (catalog['name'] ?? 'Catalog').toString();
    
    final isExpanded = _expandedCatalogs[id] ?? true;
    final products = _catalogProducts[id] ?? const [];
    final count = products.isNotEmpty ? products.length : (catalog['productCount'] ?? 0);

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _expandedCatalogs[id] = !isExpanded;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD98A3D),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
                      Text(
                        '$count products · synced recently',
                        style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.ink3,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No products in this catalog.',
                style: AppText.poppins(size: 12.5, color: AppColors.ink4),
              ),
            ),
          ...products.map((product) => Container(
            margin: const EdgeInsets.only(left: 16, right: 4, bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                if (product.image.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      product.image,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 40,
                        height: 40,
                        color: AppColors.surface2,
                        child: const Icon(Icons.image_not_supported_outlined, size: 18, color: AppColors.ink4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${product.price.toStringAsFixed(2)} ${product.currency}',
                        style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.send_rounded,
                    color: widget.sessionClosed ? AppColors.ink4 : AppColors.evaGreen,
                    size: 18,
                  ),
                  onPressed: () async {
                    // Guard: 24-hour session must be open to send catalog products via WhatsApp
                    if (widget.sessionClosed) {
                      await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Row(
                            children: [
                              const Icon(Icons.access_time_rounded, color: Color(0xFFFF8C00), size: 22),
                              const SizedBox(width: 10),
                              Text('Session Expired', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                            ],
                          ),
                          content: Text(
                            'The 24-hour WhatsApp conversation window is closed.\n\nPlease go back and send a Template message to re-open the session before sending catalog products.',
                            style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink2),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text('OK', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                            ),
                          ],
                        ),
                      );
                      return;
                    }
                    setState(() => _loading = true);
                    try {
                      await AppScope.of(context).commerce.sendCatalogProduct(
                        catalogId: id,
                        productIds: [product.productId.isNotEmpty ? product.productId : product.id],
                        userNumber: number,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 10),
                                const Text('Catalog product sent to chat!'),
                              ],
                            ),
                            backgroundColor: AppColors.evaGreen,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      final errStr = e.toString().replaceFirst('Exception: ', '');
                      final isSessionErr = errStr.toLowerCase().contains('session') ||
                          errStr.toLowerCase().contains('window') ||
                          errStr.toLowerCase().contains('24') ||
                          errStr.toLowerCase().contains('no session');
                      if (mounted) {
                        if (isSessionErr) {
                          await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, color: Color(0xFFFF8C00), size: 22),
                                  const SizedBox(width: 10),
                                  Text('Session Expired', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                                ],
                              ),
                              content: Text(
                                'The 24-hour WhatsApp conversation window is closed.\n\nPlease go back and send a Template message to re-open the session, then try sending the product again.',
                                style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink2),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: Text('OK', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                                ),
                              ],
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to send product: $errStr'),
                              backgroundColor: AppColors.danger,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    } finally {
                      if (mounted) setState(() => _loading = false);
                      await _loadAll();
                    }
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          )),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _journey() {
    if (_events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            const Icon(Icons.route_outlined, size: 18, color: AppColors.ink4),
            const SizedBox(width: 8),
            Text('No customer journey data available.', style: AppText.poppins(size: 13, color: AppColors.ink4)),
          ],
        ),
      );
    }

    String extractAgentName(Map<String, dynamic> e) {
      String getVal(dynamic m) {
        if (m is Map) {
          final v = (m['agentName'] ??
                  m['agent'] ??
                  m['by'] ??
                  m['username'] ??
                  m['userName'] ??
                  m['addedBy'] ??
                  m['createdByName'] ??
                  m['createdBy'] ??
                  m['user'] ??
                  m['name'] ??
                  '').toString().trim();
          if (v.isNotEmpty && v != 'null') return v;
        }
        return '';
      }

      final direct = getVal(e);
      if (direct.isNotEmpty) return direct;
      final meta = getVal(e['metadata']);
      if (meta.isNotEmpty) return meta;
      final details = getVal(e['details']);
      if (details.isNotEmpty) return details;
      final data = getVal(e['data']);
      if (data.isNotEmpty) return data;
      return '';
    }

    // Map action → (label, isActive) matching React ChatSideStatus.jsx logic
    String actionLabel(Map<String, dynamic> e) {
      final action = (e['action'] ?? e['event'] ?? e['type'] ?? '').toString().trim();
      final agentName = extractAgentName(e);
      final removedBy = (e['removedBy'] ?? '').toString();
      final actionLower = action.toLowerCase();

      switch (actionLower) {
        case 'agent_assigned':
          return 'Assigned to${agentName.isNotEmpty ? " $agentName" : ""}';
        case 'agent_removed':
          return 'Agent${agentName.isNotEmpty ? " $agentName" : ""} removed${removedBy.isNotEmpty ? " by $removedBy" : ""}';
        case 'agent_switched':
          return 'Switched to${agentName.isNotEmpty ? " $agentName" : ""}';
        case 'moved_to_admin':
          return 'Completed by${agentName.isNotEmpty ? " $agentName" : ""}';
        case 'user_blocked':
          return 'Blocked by${agentName.isNotEmpty ? " $agentName" : ""}';
        case 'user_unblocked':
          return 'Unblocked by${agentName.isNotEmpty ? " $agentName" : ""}';
        case 'user_unsubscribed':
          return 'Unsubscribed';
        case 'note_added':
        case 'note_created':
        case 'note added':
        case 'note':
          return 'Note added${agentName.isNotEmpty ? " by $agentName" : ""}';
        default:
          if (actionLower.contains('note')) {
            return 'Note added${agentName.isNotEmpty ? " by $agentName" : ""}';
          }
          final intervene = e['intervene'];
          if (intervene != null) {
            return intervene == true ? 'Intervene On' : 'Intervene Off';
          }
          return action.isNotEmpty ? action.replaceAll('_', ' ') : 'Event';
      }
    }

    bool isActiveAction(Map<String, dynamic> e) {
      final action = (e['action'] ?? e['event'] ?? e['type'] ?? '').toString();
      switch (action) {
        case 'agent_assigned':
        case 'agent_switched':
          return true;
        case 'agent_removed':
        case 'moved_to_admin':
        case 'user_blocked':
        case 'user_unsubscribed':
          return false;
        case 'user_unblocked':
          return true;
        default:
          final intervene = e['intervene'];
          return intervene == true;
      }
    }

    String formatTime(Map<String, dynamic> e) {
      final dt = DateTime.tryParse((e['createdAt'] ?? e['timestamp'] ?? '').toString());
      if (dt == null) return '';
      final d = dt.toLocal();
      final months = const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hours = d.hour;
      final minutes = d.minute.toString().padLeft(2, '0');
      final ampm = hours >= 12 ? 'PM' : 'AM';
      final formattedHours = hours % 12 == 0 ? 12 : hours % 12;
      return '${d.day.toString().padLeft(2, '0')} ${months[d.month]} ${d.year}, $formattedHours:$minutes $ampm';
    }

    return Column(
      children: _events.map((e) {
        final label = actionLabel(e);
        final active = isActiveAction(e);
        final when = formatTime(e);
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: active ? AppColors.evaGreen : AppColors.ink4, width: 2.5))),
                  Expanded(child: Container(width: 2, color: AppColors.line)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(11)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(width: 7, height: 7, decoration: BoxDecoration(color: active ? AppColors.evaGreen : AppColors.ink3, shape: BoxShape.circle)),
                        const SizedBox(width: 7),
                        Expanded(child: Text(label, style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink))),
                      ]),
                      if (when.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.schedule_rounded, size: 11, color: AppColors.ink4),
                          const SizedBox(width: 5),
                          Text(when, style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink4)),
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
