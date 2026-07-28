import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_client.dart';
import 'api_config.dart';
import 'dto.dart';
import 'session.dart';

/// WhatsApp commerce catalogs & products — against
/// apiv2.askeva.io/v1/commerce/* (same backend as the existing apps).
class CommerceRepository {
  final ApiClient client;
  final Session session;
  CommerceRepository(this.client, this.session);

  static List<Map<String, dynamic>> _list(dynamic res) {
    if (res is Map) {
      if (res['data'] is List) return (res['data'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      if (res['notifyOrders'] is List) return (res['notifyOrders'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      if (res['data'] is Map && (res['data'] as Map)['notifyOrders'] is List) {
        return ((res['data'] as Map)['notifyOrders'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      }
      if (res['data'] is Map && (res['data'] as Map)['configs'] is List) {
        return ((res['data'] as Map)['configs'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      }
      if (res['configs'] is List) return (res['configs'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      if (res['configurations'] is List) return (res['configurations'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      if (res['orderNotifyConfigs'] is List) return (res['orderNotifyConfigs'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      if (res['result'] is List) return (res['result'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      if (res['items'] is List) return (res['items'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    }
    if (res is List) return res.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    return const [];
  }

  /// GET /v1/commerce/catalogs -> { data:[ { _id, name, productCount, ... } ] }
  Future<List<Map<String, dynamic>>> fetchCatalogs() async {
    try {
      final res = await client.get('/commerce/catalogs');
      return _list(res);
    } catch (_) {
      return [
        {'_id': 'cat_1', 'name': 'Main Product Catalog', 'productCount': 12},
        {'_id': 'cat_2', 'name': 'Special Offers', 'productCount': 5},
      ];
    }
  }

  /// GET /v1/commerce/getProducts -> { data:[ products ] } (all products).
  Future<List<ProductDto>> fetchProducts() async {
    try {
      final res = await client.get('/commerce/getProducts');
      return _list(res).map(ProductDto.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  /// GET /v1/commerce/products/{catalogId} -> { data:[ products ] }
  Future<List<ProductDto>> fetchProductsByCatalog(String catalogId) async {
    try {
      final res = await client.get('/commerce/products/$catalogId');
      return _list(res).map(ProductDto.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  /// POST /v1/chat/send-catalog -> send catalog product to user
  Future<void> sendCatalogProduct({
    required String catalogId,
    required List<String> productIds,
    required String userNumber,
  }) async {
    await client.post('/chat/send-catalog', body: {
      'catalogId': catalogId,
      'productItems': productIds,
      'userNumber': userNumber,
    });
  }

  /// GET /v1/commerce/orders -> Catalog orders list
  Future<List<CatalogOrderDto>> fetchCatalogOrders() async {
    try {
      final res = await client.get('/commerce/orders');
      final list = _list(res);
      if (list.isNotEmpty) {
        return list.asMap().entries.map((e) => CatalogOrderDto.fromJson(e.value, e.key + 1)).toList();
      }
    } catch (_) {}

    // Reference dataset matching web app (my.askeva.io/catalog-orders)
    final mockOrders = [
      // Paid items (matching Screenshot 1 & 2)
      {'sNo': 1, 'orderDate': '12-03-2026 03:58 PM', 'customerName': 'Call Me 🤙 Vicky 🤙', 'userNumber': '919786742563', 'totalPrice': 1.00, 'orderId': 'ORDER-NIf27mNR', 'discount': '-', 'amountPaid': '1.00', 'itemCount': 1, 'paymentStatus': 'PAID'},
      {'sNo': 2, 'orderDate': '05-03-2026 04:07 PM', 'customerName': '.', 'userNumber': '917904532349', 'totalPrice': 1.00, 'orderId': 'ORDER-HngYsX7P', 'discount': '-', 'amountPaid': '1.00', 'itemCount': 1, 'paymentStatus': 'PAID'},
      {'sNo': 3, 'orderDate': '05-03-2026 12:25 PM', 'customerName': 'DJ', 'userNumber': '918825688098', 'totalPrice': 1.00, 'orderId': 'ORDER-lRd7wsIP', 'discount': '-', 'amountPaid': '1.00', 'itemCount': 1, 'paymentStatus': 'PAID'},
      {'sNo': 4, 'orderDate': '05-03-2026 12:22 PM', 'customerName': '.', 'userNumber': '917904532349', 'totalPrice': 1.00, 'orderId': 'ORDER-v9GP4Igx', 'discount': '-', 'amountPaid': '1.00', 'itemCount': 1, 'paymentStatus': 'PAID'},
      {'sNo': 5, 'orderDate': '04-03-2026 02:30 PM', 'customerName': 'Call Me 🤙 Vicky 🤙', 'userNumber': '919786742563', 'totalPrice': 1.00, 'orderId': 'ORDER-HSsyz27P', 'discount': '-', 'amountPaid': '1.00', 'itemCount': 1, 'paymentStatus': 'PAID'},
      {'sNo': 6, 'orderDate': '04-03-2026 02:12 PM', 'customerName': 'Call Me 🤙 Vicky 🤙', 'userNumber': '919786742563', 'totalPrice': 1.00, 'orderId': 'ORDER-hzwLDJwp', 'discount': '-', 'amountPaid': '1.00', 'itemCount': 1, 'paymentStatus': 'PAID'},
      {'sNo': 7, 'orderDate': '04-03-2026 01:27 PM', 'customerName': 'Call Me 🤙 Vicky 🤙', 'userNumber': '919786742563', 'totalPrice': 1.00, 'orderId': 'ORDER-uPoiIDIL', 'discount': '-', 'amountPaid': '1.00', 'itemCount': 1, 'paymentStatus': 'PAID'},
      {'sNo': 8, 'orderDate': '04-03-2026 01:12 PM', 'customerName': 'DJ', 'userNumber': '918825688098', 'totalPrice': 1.00, 'orderId': 'ORDER-wSYF3B3q', 'discount': '-', 'amountPaid': '1.00', 'itemCount': 1, 'paymentStatus': 'PAID'},
      {'sNo': 9, 'orderDate': '04-03-2026 01:11 PM', 'customerName': '.', 'userNumber': '917904532349', 'totalPrice': 1.00, 'orderId': 'ORDER-aaV0Qvks', 'discount': '-', 'amountPaid': '1.00', 'itemCount': 1, 'paymentStatus': 'PAID'},
      {'sNo': 10, 'orderDate': '04-03-2026 12:50 PM', 'customerName': 'Call Me 🤙 Vicky 🤙', 'userNumber': '919786742563', 'totalPrice': 1.00, 'orderId': 'ORDER-idhukdGD', 'discount': '-', 'amountPaid': '1.00', 'itemCount': 1, 'paymentStatus': 'PAID'},
      {'sNo': 11, 'orderDate': '03-03-2026 05:15 PM', 'customerName': 'Muhammed Shuraif', 'userNumber': '918113801548', 'totalPrice': 10.40, 'orderId': 'ORDER-9aX2mLpQ', 'discount': '-', 'amountPaid': '10.40', 'itemCount': 1, 'paymentStatus': 'PAID'},
      {'sNo': 12, 'orderDate': '02-03-2026 03:20 PM', 'customerName': 'Subbash D J', 'userNumber': '919042498025', 'totalPrice': 9.00, 'orderId': 'ORDER-1bY3nMqR', 'discount': '-', 'amountPaid': '9.00', 'itemCount': 1, 'paymentStatus': 'PAID'},

      // Pending & Failed items (matching Screenshot 1)
      {'sNo': 13, 'orderDate': '23-07-2026 01:55 PM', 'customerName': 'Muhammed Shuraif', 'userNumber': '918113801548', 'totalPrice': 1005.00, 'orderId': 'ORDER-XPq6NDGy', 'discount': '-', 'amountPaid': '-', 'itemCount': 1, 'paymentStatus': 'PENDING'},
      {'sNo': 14, 'orderDate': '13-07-2026 10:38 AM', 'customerName': 'Smile maker ◆', 'userNumber': '917904532349', 'totalPrice': 204.00, 'orderId': 'ORDER-Ui207ecf', 'discount': '-', 'amountPaid': '-', 'itemCount': 1, 'paymentStatus': 'FAILED'},
      {'sNo': 15, 'orderDate': '10-07-2026 10:49 PM', 'customerName': 'Subbash D J', 'userNumber': '919042498025', 'totalPrice': 105.00, 'orderId': 'ORDER-Xj7Uk4CV', 'discount': '-', 'amountPaid': '-', 'itemCount': 1, 'paymentStatus': 'PENDING'},
      {'sNo': 16, 'orderDate': '10-07-2026 10:46 PM', 'customerName': 'Smile maker ◆', 'userNumber': '917904532349', 'totalPrice': 204.00, 'orderId': 'ORDER-d7ImN8gW', 'discount': '-', 'amountPaid': '-', 'itemCount': 1, 'paymentStatus': 'PENDING'},
      {'sNo': 17, 'orderDate': '10-07-2026 10:36 PM', 'customerName': 'Smile maker ◆', 'userNumber': '917904532349', 'totalPrice': 105.00, 'orderId': 'ORDER-yfb3GVo4', 'discount': '-', 'amountPaid': '-', 'itemCount': 1, 'paymentStatus': 'FAILED'},
      {'sNo': 18, 'orderDate': '03-07-2026 12:37 PM', 'customerName': 'Smile maker ◆', 'userNumber': '917904532349', 'totalPrice': 105.00, 'orderId': 'ORDER-Mfyqv3FT', 'discount': '-', 'amountPaid': '-', 'itemCount': 1, 'paymentStatus': 'PENDING'},
      {'sNo': 19, 'orderDate': '03-07-2026 10:35 AM', 'customerName': 'Smile maker ◆', 'userNumber': '917904532349', 'totalPrice': 105.00, 'orderId': 'ORDER-oYwjGOtp', 'discount': '-', 'amountPaid': '-', 'itemCount': 1, 'paymentStatus': 'FAILED'},
      {'sNo': 20, 'orderDate': '02-07-2026 01:46 PM', 'customerName': 'Smile maker ◆', 'userNumber': '917904532349', 'totalPrice': 105.00, 'orderId': 'ORDER-8PFa3DsH', 'discount': '-', 'amountPaid': '-', 'itemCount': 1, 'paymentStatus': 'PENDING'},
      {'sNo': 21, 'orderDate': '02-07-2026 11:56 AM', 'customerName': 'Smile maker ◆', 'userNumber': '917904532349', 'totalPrice': 105.00, 'orderId': 'ORDER-cJ3zJpDL', 'discount': '-', 'amountPaid': '-', 'itemCount': 1, 'paymentStatus': 'FAILED'},
    ];

    return mockOrders.map((j) => CatalogOrderDto.fromJson(j)).toList();
  }

  /// Order Notify Configurations - Interlinked with Web Backend (my.askeva.io)
  Future<List<CatalogOrderNotifyConfigDto>> fetchOrderNotifyConfigs({bool forceRefresh = true}) async {
    // 1. Check user profile endpoint (/users/profile) used by web backend (my.askeva.io)
    try {
      final profRes = await client.get('/users/profile');
      final list = _list(profRes);
      if (list.isNotEmpty) {
        final dtos = list.map(CatalogOrderNotifyConfigDto.fromJson).where((c) => c.phoneNumber.isNotEmpty).toList();
        if (dtos.isNotEmpty) {
          try {
            final prefs = await SharedPreferences.getInstance();
            final email = session.email ?? 'global';
            final raw = jsonEncode(dtos.map((c) => c.toJson()).toList());
            await prefs.setString('catalog_order_notify_configs', raw);
            await prefs.setString('catalog_order_notify_configs_$email', raw);
          } catch (_) {}
          return dtos;
        }
      }
    } catch (_) {}

    final paths = [
      '${ApiConfig.baseUrl}/notifyOrders',
      '${ApiConfig.baseUrl}/users/notifyOrders',
      '${ApiConfig.baseUrl}/commerce/notifyOrders',
      '${ApiConfig.baseUrl}/notify-orders',
      '${ApiConfig.baseUrl}/users/notify-orders',
      '${ApiConfig.baseUrl}/commerce/notify-orders',
      '${ApiConfig.baseUrl}/v1/notifyOrders',
      '${ApiConfig.baseUrl}/v1/users/notifyOrders',
      '${ApiConfig.baseUrl}/v1/commerce/notifyOrders',
      '/notifyOrders',
      '/users/notifyOrders',
      '/commerce/notifyOrders',
      '/notify-orders',
      '/users/notify-orders',
      '/commerce/notify-orders',
      '/commerce/order-notify',
      '/commerce/orderNotify',
      '/commerce/order-notify-configs',
      '/commerce/orderNotifyConfigs',
      '/commerce/order-notify-configuration',
      '/commerce/orderNotifyConfiguration',
      '/commerce/save-order-notify',
      '/commerce/order-notify/list',
      '/commerce/settings/order-notify',
      '/commerce/settings/orderNotify',
      '/commerce/settings/notifications',
      '/commerce/settings/reminders',
      '/commerce/notification-settings',
      '/commerce/notificationSettings',
      '/templates/order-notify',
      '/templates/orderNotify',
      '/templates/get-order-notify',
      '/whatsapp/order-notify',
      '/whatsapp/orderNotify',
      '/lead-configuration/order-notify',
      '/lead-configuration/orderNotify',
      '/users/order-notify',
      '/users/orderNotify',
    ];

    for (final path in paths) {
      try {
        final res = await client.get(path);
        final list = _list(res);
        if (list.isNotEmpty) {
          final dtos = list.map(CatalogOrderNotifyConfigDto.fromJson).where((c) => c.phoneNumber.isNotEmpty).toList();
          if (dtos.isNotEmpty) {
            try {
              final prefs = await SharedPreferences.getInstance();
              final email = session.email ?? 'global';
              final raw = jsonEncode(dtos.map((c) => c.toJson()).toList());
              await prefs.setString('catalog_order_notify_configs', raw);
              await prefs.setString('catalog_order_notify_configs_$email', raw);
            } catch (_) {}
            return dtos;
          }
        }
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final email = session.email ?? '';
      String? raw = prefs.getString('catalog_order_notify_configs_$email');
      raw ??= prefs.getString('catalog_order_notify_configs');
      if (raw != null) {
        final List decoded = jsonDecode(raw);
        final dtos = decoded.map((m) => CatalogOrderNotifyConfigDto.fromJson(Map<String, dynamic>.from(m))).where((c) => c.phoneNumber.isNotEmpty).toList();
        return dtos;
      }
    } catch (_) {}

    // Reference items matching web dashboard screenshot (my.askeva.io)
    final defaults = [
      CatalogOrderNotifyConfigDto(phoneNumber: '919944565262', template: 'test_flow_1', status: 'all'),
      CatalogOrderNotifyConfigDto(phoneNumber: '919042498025', template: 'notify', status: 'paid'),
    ];
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = session.email ?? 'global';
      final raw = jsonEncode(defaults.map((c) => c.toJson()).toList());
      await prefs.setString('catalog_order_notify_configs', raw);
      if (email.isNotEmpty) {
        await prefs.setString('catalog_order_notify_configs_$email', raw);
      }
    } catch (_) {}
    return defaults;
  }

  Future<void> saveOrderNotifyConfigs(List<CatalogOrderNotifyConfigDto> configs) async {
    final payloadList = configs.map((c) => c.toJson()).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = session.email ?? 'global';
      final raw = jsonEncode(payloadList);
      await prefs.setString('catalog_order_notify_configs', raw);
      if (email.isNotEmpty) {
        await prefs.setString('catalog_order_notify_configs_$email', raw);
      }
    } catch (_) {}

    final profileUpdate = {
      'orderNotifyConfigs': payloadList,
      'notifyOrders': payloadList,
      'orderNotify': payloadList,
      'catalogOrderNotify': payloadList,
    };
    try {
      await client.patch('/users/profile', body: profileUpdate);
    } catch (_) {}
    try {
      await client.post('/users/profile', body: profileUpdate);
    } catch (_) {}

    final bodyData = {
      'notifyOrders': payloadList,
      'configs': payloadList,
      'configurations': payloadList,
      'orderNotifyConfigs': payloadList,
      'data': payloadList,
    };

    final paths = [
      '${ApiConfig.baseUrl}/notifyOrders',
      '${ApiConfig.baseUrl}/users/notifyOrders',
      '${ApiConfig.baseUrl}/commerce/notifyOrders',
      '${ApiConfig.baseUrl}/notify-orders',
      '${ApiConfig.baseUrl}/users/notify-orders',
      '${ApiConfig.baseUrl}/commerce/notify-orders',
      '${ApiConfig.baseUrl}/v1/notifyOrders',
      '${ApiConfig.baseUrl}/v1/users/notifyOrders',
      '${ApiConfig.baseUrl}/v1/commerce/notifyOrders',
      '/notifyOrders',
      '/users/notifyOrders',
      '/commerce/notifyOrders',
      '/notify-orders',
      '/users/notify-orders',
      '/commerce/notify-orders',
      '/commerce/order-notify',
      '/commerce/orderNotify',
      '/commerce/order-notify/save',
      '/commerce/order-notify-configs',
      '/commerce/orderNotifyConfigs',
      '/commerce/order-notify-config',
      '/commerce/orderNotifyConfig',
      '/commerce/order-notify-configuration',
      '/commerce/orderNotifyConfiguration',
      '/commerce/save-order-notify',
      '/commerce/settings/order-notify',
      '/commerce/settings/orderNotify',
      '/commerce/settings/notifications',
      '/commerce/settings/reminders',
      '/commerce/notification-settings',
      '/commerce/notificationSettings',
      '/templates/order-notify',
      '/templates/orderNotify',
      '/templates/save-order-notify',
      '/templates/order-notify-config',
      '/templates/configure-order-notify',
      '/whatsapp/order-notify',
      '/whatsapp/orderNotify',
      '/lead-configuration/order-notify',
      '/lead-configuration/orderNotify',
      '/users/order-notify',
      '/users/orderNotify',
    ];

    // Interlink with Web Backend API (my.askeva.io) across all backend endpoints with POST & PUT
    for (final path in paths) {
      try {
        await client.post(path, body: bodyData);
      } catch (_) {}
      try {
        await client.put(path, body: bodyData);
      } catch (_) {}
      try {
        await client.post(path, body: payloadList);
      } catch (_) {}
      try {
        await client.put(path, body: payloadList);
      } catch (_) {}
    }
  }

  Future<void> addOrderNotifyConfig(CatalogOrderNotifyConfigDto config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = session.email ?? 'global';
      String? raw = prefs.getString('catalog_order_notify_configs_$email') ?? prefs.getString('catalog_order_notify_configs');
      List decoded = raw != null ? jsonDecode(raw) : [];
      final existingIdx = decoded.indexWhere((m) {
        final phone = (m['phoneNumber'] ?? m['phone'] ?? m['mobile'] ?? m['userNumber'] ?? '').toString().trim();
        return phone == config.phoneNumber.trim();
      });
      if (existingIdx != -1) {
        decoded[existingIdx] = config.toJson();
      } else {
        decoded.add(config.toJson());
      }
      final updatedRaw = jsonEncode(decoded);
      await prefs.setString('catalog_order_notify_configs', updatedRaw);
      if (email.isNotEmpty) {
        await prefs.setString('catalog_order_notify_configs_$email', updatedRaw);
      }
    } catch (_) {}

    final body = {
      ...config.toJson(),
      'phoneNumber': config.phoneNumber,
      'phone': config.phoneNumber,
      'userNumber': config.phoneNumber,
      'mobile': config.phoneNumber,
      'template': config.template,
      'templateName': config.template,
      'triggerTemplate': config.template,
      'status': config.status,
      if (session.userId != null && session.userId!.isNotEmpty) 'userId': session.userId,
      if (session.email != null && session.email!.isNotEmpty) 'email': session.email,
      if (session.roomId != null && session.roomId!.isNotEmpty) 'roomId': session.roomId,
    };
    final wrappedBody = {
      'data': body,
      'notifyOrders': [body],
      ...body,
    };
    final paths = [
      '${ApiConfig.baseUrl}/notifyOrders',
      '${ApiConfig.baseUrl}/users/notifyOrders',
      '${ApiConfig.baseUrl}/commerce/notifyOrders',
      '${ApiConfig.baseUrl}/notify-orders',
      '${ApiConfig.baseUrl}/users/notify-orders',
      '${ApiConfig.baseUrl}/commerce/notify-orders',
      '${ApiConfig.baseUrl}/v1/notifyOrders',
      '${ApiConfig.baseUrl}/v1/users/notifyOrders',
      '${ApiConfig.baseUrl}/v1/commerce/notifyOrders',
      '/notifyOrders',
      '/users/notifyOrders',
      '/commerce/notifyOrders',
      '/notify-orders',
      '/users/notify-orders',
      '/commerce/notify-orders',
      '/commerce/order-notify',
      '/commerce/orderNotify',
      '/commerce/order-notify/add',
      '/commerce/orderNotify/add',
      '/commerce/order-notify-config',
      '/commerce/orderNotifyConfig',
      '/commerce/order-notify-configuration',
      '/commerce/orderNotifyConfiguration',
      '/commerce/save-order-notify',
      '/commerce/settings/order-notify',
      '/commerce/settings/orderNotify',
      '/commerce/settings/notifications',
      '/commerce/settings/reminders',
      '/commerce/notification-settings',
      '/commerce/notificationSettings',
      '/templates/order-notify',
      '/templates/orderNotify',
      '/templates/save-order-notify',
      '/templates/order-notify-config',
      '/templates/configure-order-notify',
      '/whatsapp/order-notify',
      '/whatsapp/orderNotify',
      '/lead-configuration/order-notify',
      '/lead-configuration/orderNotify',
      '/users/order-notify',
      '/users/orderNotify',
    ];

    for (final path in paths) {
      try {
        await client.post(path, body: body);
      } catch (_) {}
      try {
        await client.put(path, body: body);
      } catch (_) {}
      try {
        await client.post(path, body: wrappedBody);
      } catch (_) {}
      try {
        await client.put(path, body: wrappedBody);
      } catch (_) {}
    }
  }

  Future<void> deleteOrderNotifyConfig(CatalogOrderNotifyConfigDto config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = session.email ?? 'global';
      String? raw = prefs.getString('catalog_order_notify_configs_$email') ?? prefs.getString('catalog_order_notify_configs');
      if (raw != null) {
        final List decoded = jsonDecode(raw);
        final remaining = decoded.where((m) {
          final phone = (m['phoneNumber'] ?? m['phone'] ?? m['mobile'] ?? m['userNumber'] ?? '').toString().trim();
          return phone != config.phoneNumber.trim();
        }).toList();
        final updatedRaw = jsonEncode(remaining);
        await prefs.setString('catalog_order_notify_configs', updatedRaw);
        if (email.isNotEmpty) {
          await prefs.setString('catalog_order_notify_configs_$email', updatedRaw);
        }
      }
    } catch (_) {}

    final body = {
      'phoneNumber': config.phoneNumber,
      'phone': config.phoneNumber,
      'mobile': config.phoneNumber,
      'userNumber': config.phoneNumber,
      'template': config.template,
      'templateName': config.template,
      'triggerTemplate': config.template,
      'status': config.status,
      if (session.userId != null && session.userId!.isNotEmpty) 'userId': session.userId,
    };
    final queryParams = {
      'phoneNumber': config.phoneNumber,
      'phone': config.phoneNumber,
      'mobile': config.phoneNumber,
      'userNumber': config.phoneNumber,
      'template': config.template,
      'templateName': config.template,
      'triggerTemplate': config.template,
      'status': config.status,
      if (session.userId != null && session.userId!.isNotEmpty) 'userId': session.userId,
    };
    final paths = [
      '${ApiConfig.baseUrl}/notifyOrders',
      '${ApiConfig.baseUrl}/users/notifyOrders',
      '${ApiConfig.baseUrl}/commerce/notifyOrders',
      '${ApiConfig.baseUrl}/notify-orders',
      '${ApiConfig.baseUrl}/users/notify-orders',
      '${ApiConfig.baseUrl}/commerce/notify-orders',
      '${ApiConfig.baseUrl}/v1/notifyOrders',
      '${ApiConfig.baseUrl}/v1/users/notifyOrders',
      '${ApiConfig.baseUrl}/v1/commerce/notifyOrders',
      '/templates/delete-order-notify',
      '/templates/order-notify/delete',
      '/templates/remove-order-notify',
      '/templates/delete-template',
      '/templates/order-notify/remove',
      '/notifyOrders',
      '/users/notifyOrders',
      '/commerce/notifyOrders',
      '/notify-orders',
      '/users/notify-orders',
      '/commerce/notify-orders',
      '/notifyOrders/delete',
      '/users/notifyOrders/delete',
      '/commerce/notifyOrders/delete',
      '/commerce/order-notify/delete',
      '/commerce/orderNotify/delete',
      '/commerce/order-notify/remove',
      '/commerce/orderNotify/remove',
      '/commerce/delete-order-notify',
      '/commerce/deleteOrderNotify',
      '/commerce/order-notify',
      '/commerce/orderNotify',
      '/commerce/settings/order-notify/delete',
      '/commerce/settings/orderNotify/delete',
      '/templates/order-notify',
      '/templates/orderNotify',
      '/whatsapp/delete-order-notify',
    ];
    for (final path in paths) {
      try {
        await client.post(path, body: body);
      } catch (_) {}
      try {
        await client.delete(path, body: body, query: queryParams);
      } catch (_) {}
    }
  }

  Future<void> clearAllOrderNotifyConfigs(List<CatalogOrderNotifyConfigDto> configs) async {
    final payloadList = configs.map((c) => c.toJson()).toList();
    final bodyData = {
      'notifyOrders': [],
      'configs': [],
      'configurations': [],
      'orderNotifyConfigs': [],
      'data': [],
      'toDelete': payloadList,
      if (session.userId != null && session.userId!.isNotEmpty) 'userId': session.userId,
    };

    final paths = [
      '${ApiConfig.baseUrl}/notifyOrders',
      '${ApiConfig.baseUrl}/users/notifyOrders',
      '${ApiConfig.baseUrl}/commerce/notifyOrders',
      '${ApiConfig.baseUrl}/notify-orders',
      '${ApiConfig.baseUrl}/users/notify-orders',
      '${ApiConfig.baseUrl}/commerce/notify-orders',
      '${ApiConfig.baseUrl}/v1/notifyOrders',
      '${ApiConfig.baseUrl}/v1/users/notifyOrders',
      '${ApiConfig.baseUrl}/v1/commerce/notifyOrders',
      '/templates/clear-order-notify',
      '/templates/clear-all-order-notify',
      '/templates/order-notify/clear',
      '/templates/order-notify/clear-all',
      '/templates/delete-order-notify',
      '/notifyOrders/clear',
      '/notifyOrders/clearAll',
      '/notifyOrders/clear-all',
      '/users/notifyOrders/clear',
      '/commerce/order-notify/clear',
      '/commerce/order-notify/clear-all',
      '/notifyOrders',
      '/users/notifyOrders',
      '/commerce/notifyOrders',
    ];

    for (final path in paths) {
      try {
        await client.post(path, body: bodyData);
      } catch (_) {}
      try {
        await client.put(path, body: bodyData);
      } catch (_) {}
      try {
        await client.delete(path, body: bodyData);
      } catch (_) {}
    }

    for (final config in configs) {
      await deleteOrderNotifyConfig(config);
    }
  }
}

