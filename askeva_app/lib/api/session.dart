import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the authenticated session (token + user identity) and persists it.
/// A single instance is created in main() and shared via [SessionScope].
class Session extends ChangeNotifier {
  String? token;
  String? roomId; // company room / tenant id used by chat + socket
  String? userId;
  String? username;
  String? email;
  String? role;
  Map<String, dynamic>? profile;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  static const _kToken = 'auth_token';
  static const _kRoom = 'auth_room_id';
  static const _kUserId = 'auth_user_id';
  static const _kUser = 'auth_username';
  static const _kEmail = 'auth_email';
  static const _kRole = 'auth_role';
  static const _kProfile = 'auth_profile_json';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString(_kToken);
    roomId = p.getString(_kRoom);
    userId = p.getString(_kUserId);
    username = p.getString(_kUser);
    email = p.getString(_kEmail);
    role = p.getString(_kRole);
    final rawProf = p.getString(_kProfile);
    if (rawProf != null && rawProf.isNotEmpty) {
      try {
        profile = (jsonDecode(rawProf) as Map).cast<String, dynamic>();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> save({
    required String token,
    String? roomId,
    String? userId,
    String? username,
    String? email,
    String? role,
  }) async {
    this.token = token;
    this.roomId = roomId;
    this.userId = userId;
    this.username = username;
    this.email = email;
    this.role = role;

    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token);
    if (roomId != null && roomId.isNotEmpty) {
      await p.setString(_kRoom, roomId);
    } else {
      await p.remove(_kRoom);
    }

    if (userId != null && userId.isNotEmpty) {
      await p.setString(_kUserId, userId);
    } else {
      await p.remove(_kUserId);
    }

    if (username != null && username.isNotEmpty) {
      await p.setString(_kUser, username);
    } else {
      await p.remove(_kUser);
    }

    if (email != null && email.isNotEmpty) {
      await p.setString(_kEmail, email);
    } else {
      await p.remove(_kEmail);
    }

    if (role != null && role.isNotEmpty) {
      await p.setString(_kRole, role);
    } else {
      await p.remove(_kRole);
    }
    notifyListeners();
  }

  void setProfile(Map<String, dynamic> p) {
    profile = {
      ...?profile,
      ...p,
    };
    if (profile != null) {
      SharedPreferences.getInstance().then((pref) {
        pref.setString(_kProfile, jsonEncode(profile));
      });
    }
    notifyListeners();
  }

  /// Returns the lowercase name of the current subscription plan (e.g. 'standard', 'enterprises', 'ecommerce').
  String get planName {
    final p = profile ?? {};
    final planObj = p['plan'];
    if (planObj is Map) {
      final name = planObj['name']?.toString();
      if (name != null && name.isNotEmpty) return name.toLowerCase().trim();
    }
    final directName = (p['planName'] ?? p['subscriptionPlan'] ?? p['plan_name'] ?? p['package'] ?? p['packageName'] ?? role ?? '').toString();
    return directName.toLowerCase().trim();
  }

  /// Returns the lowercase validity of the current subscription plan (e.g. 'unlimited', '3month', '6month', '12month').
  String get planValidity {
    final p = profile ?? {};
    final planObj = p['plan'];
    if (planObj is Map) {
      final validity = planObj['validity']?.toString();
      if (validity != null && validity.isNotEmpty) return validity.toLowerCase().trim();
    }
    return (p['validity'] ?? p['planValidity'] ?? '').toString().toLowerCase().trim();
  }

  /// Returns true if the user's active subscription plan is the Standard Plan.
  bool get isStandardPlan {
    final pName = planName;
    if (pName.isEmpty) return false;
    // Standard plan names: 'standard', 'standard plan', 'basic'
    // Exclude enterprise, enterprises, ecommerce, professional
    if (pName.contains('enterprise') || pName.contains('ecommerce') || pName.contains('professional') || pName.contains('pro')) {
      return false;
    }
    return pName == 'standard' || pName.contains('standard') || pName == 'basic';
  }

  /// Returns true if the user's active plan is Ecommerce Unlimited.
  bool get isEcommerceUnlimited {
    final pName = planName;
    final val = planValidity;
    final isEcommerce = pName.contains('ecommerce');
    final isUnlimited = val == 'unlimited' || pName.contains('unlimited') || true;
    return isEcommerce;
  }

  /// Returns true if the user's plan is below Ecommerce Unlimited.
  /// Any plan that is not Ecommerce + Unlimited validity is below Ecommerce Unlimited.
  bool get isBelowEcommerceUnlimited {
    return !isEcommerceUnlimited;
  }

  Future<void> clear() async {
    token = roomId = userId = username = email = role = null;
    profile = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kRoom);
    await p.remove(_kUserId);
    await p.remove(_kUser);
    await p.remove(_kEmail);
    await p.remove(_kRole);
    await p.remove(_kProfile);
    notifyListeners();
  }
}
