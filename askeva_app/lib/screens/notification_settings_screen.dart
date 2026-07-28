import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/app_scope.dart';
import '../api/local_notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/common.dart';
import '../widgets/dashboard_sheets.dart';
import '../widgets/settings_extra.dart'; // For SettingsSubScaffold

/// Shared helper to dispatch notification alerts respecting user settings.
Future<void> dispatchNotificationAlert(
  BuildContext context, {
  required String title,
  required String message,
  IconData? icon,
  bool isError = false,
  bool isSuccess = false,
}) async {
  final email = AppScope.of(context).session.email ?? 'global';
  final prefs = await SharedPreferences.getInstance();
  final pushEnabled = prefs.getBool('push_notifications_enabled_$email') ?? true;

  // If push notifications are disabled, DO NOT show push alert!
  if (!pushEnabled) return;

  final soundMode = prefs.getString('notification_sound_mode_$email') ?? 'sound';
  final inAppSounds = prefs.getBool('in_app_sounds_enabled_$email') ?? true;

  // 1. Show notification in System Mobile Notification Bar!
  await LocalNotificationService.showNotification(
    title: title,
    body: message,
    email: email,
  );

  // 2. Play in-app audio/vibrate feedback if inAppSounds is enabled
  if (soundMode == 'sound' && inAppSounds) {
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.lightImpact();
    } catch (_) {}
  } else if (soundMode == 'vibrate') {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  } else if (soundMode == 'silent') {
    // Silent mode — no sound or vibration
  }

  if (context.mounted) {
    appToast(
      context,
      '$title: $message',
      icon: icon,
      isError: isError,
      isSuccess: isSuccess,
    );
  }
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> with WidgetsBindingObserver {
  bool _pushEnabled = true;
  bool _soundsEnabled = true;
  bool _catalogNotifyEnabled = true;
  String _soundMode = 'sound'; // 'sound', 'vibrate', 'silent'
  bool _loading = true;
  bool _permissionBlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _checkPermissionStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionStatus();
    }
  }

  Future<void> _checkPermissionStatus() async {
    try {
      final status = await Permission.notification.status;
      if (mounted) {
        setState(() {
          _permissionBlocked = status.isDenied || status.isPermanentlyDenied || status.isRestricted;
        });
      }
    } catch (_) {}
  }

  Future<void> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      if (mounted) {
        setState(() {
          _permissionBlocked = status.isDenied || status.isPermanentlyDenied || status.isRestricted;
        });
      }
      if (status.isPermanentlyDenied || status.isDenied) {
        await openAppSettings();
      }
    } catch (_) {
      await openAppSettings();
    }
  }

  Future<void> _loadSettings() async {
    final email = AppScope.of(context).session.email ?? 'global';
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushEnabled = prefs.getBool('push_notifications_enabled_$email') ?? true;
      _soundsEnabled = prefs.getBool('in_app_sounds_enabled_$email') ?? true;
      _catalogNotifyEnabled = prefs.getBool('catalog_notifications_enabled_$email') ?? true;
      _soundMode = prefs.getString('notification_sound_mode_$email') ?? 'sound';
      _loading = false;
    });
  }

  Future<void> _savePushSetting(bool val) async {
    setState(() => _pushEnabled = val);
    final email = AppScope.of(context).session.email ?? 'global';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications_enabled_$email', val);

    try {
      final scope = AppScope.of(context);
      await scope.client.post('/users/notification-settings', body: {
        'pushEnabled': val,
        'catalogNotifyEnabled': _catalogNotifyEnabled,
        'soundsEnabled': _soundsEnabled,
        'soundMode': _soundMode,
      });
    } catch (_) {}

    if (val && _permissionBlocked) {
      await _requestNotificationPermission();
    }
  }

  Future<void> _saveCatalogNotifySetting(bool val) async {
    setState(() => _catalogNotifyEnabled = val);
    final email = AppScope.of(context).session.email ?? 'global';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('catalog_notifications_enabled_$email', val);

    try {
      final scope = AppScope.of(context);
      await scope.client.post('/users/notification-settings', body: {
        'pushEnabled': _pushEnabled,
        'catalogNotifyEnabled': val,
        'soundsEnabled': _soundsEnabled,
        'soundMode': _soundMode,
      });
    } catch (_) {}
  }

  Future<void> _saveSoundsSetting(bool val) async {
    setState(() => _soundsEnabled = val);
    final email = AppScope.of(context).session.email ?? 'global';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('in_app_sounds_enabled_$email', val);

    try {
      final scope = AppScope.of(context);
      await scope.client.post('/users/notification-settings', body: {
        'pushEnabled': _pushEnabled,
        'catalogNotifyEnabled': _catalogNotifyEnabled,
        'soundsEnabled': val,
        'soundMode': _soundMode,
      });
    } catch (_) {}
  }

  Future<void> _saveSoundMode(String mode) async {
    setState(() => _soundMode = mode);
    final email = AppScope.of(context).session.email ?? 'global';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notification_sound_mode_$email', mode);

    try {
      final scope = AppScope.of(context);
      await scope.client.post('/users/notification-settings', body: {
        'pushEnabled': _pushEnabled,
        'catalogNotifyEnabled': _catalogNotifyEnabled,
        'soundsEnabled': _soundsEnabled,
        'soundMode': mode,
      });
    } catch (_) {}

    // Provide immediate feedback on selection
    if (mode == 'sound') {
      try {
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.lightImpact();
      } catch (_) {}
    } else if (mode == 'vibrate') {
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}
    }
  }

  Widget _permissionWarningCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE0B2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_off_rounded, size: 18, color: Color(0xFFE65100)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notification Permission Blocked',
                      style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: const Color(0xFFE65100)),
                    ),
                    Text(
                      'Notifications are disabled in your phone settings.',
                      style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: const Color(0xFFBF360C)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await openAppSettings();
                _checkPermissionStatus();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: const Icon(Icons.settings_outlined, size: 16, color: Colors.white),
              label: Text(
                'Unblock in Phone Settings',
                style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSubScaffold(
      title: 'Notifications',
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.evaGreen))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
              children: [
                if (_permissionBlocked) _permissionWarningCard(),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _row(
                        icon: Icons.notifications_none_rounded,
                        title: 'Push notifications',
                        subtitle: 'New messages & leads',
                        value: _pushEnabled,
                        onChanged: _savePushSetting,
                        first: true,
                      ),
                      _row(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Catalog order alerts',
                        subtitle: 'Push alerts for catalog orders & payments',
                        value: _catalogNotifyEnabled,
                        onChanged: _saveCatalogNotifySetting,
                      ),
                      _row(
                        icon: Icons.volume_up_outlined,
                        title: 'In-app sounds',
                        subtitle: 'Play a chime on new chat',
                        value: _soundsEnabled,
                        onChanged: _saveSoundsSetting,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'NOTIFICATION ALERT MODE',
                  style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink4),
                ),
                const SizedBox(height: 10),
                AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _soundModeTile(
                        mode: 'sound',
                        title: 'Sound',
                        subtitle: 'Play alert sound and chime',
                        icon: Icons.notifications_active_outlined,
                      ),
                      const Divider(height: 1, color: AppColors.line),
                      _soundModeTile(
                        mode: 'vibrate',
                        title: 'Vibrate',
                        subtitle: 'Vibrate device without alert sound',
                        icon: Icons.vibration_rounded,
                      ),
                      const Divider(height: 1, color: AppColors.line),
                      _soundModeTile(
                        mode: 'silent',
                        title: 'Silent',
                        subtitle: 'Silent banner alert without sound or vibration',
                        icon: Icons.notifications_off_outlined,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _soundModeTile({
    required String mode,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _soundMode == mode;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onTap: () => _saveSoundMode(mode),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.evaGreen50 : AppColors.surface2,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? AppColors.evaGreenDeep : AppColors.ink3,
        ),
      ),
      title: Text(
        title,
        style: AppText.poppins(
          size: 14,
          weight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? AppColors.ink : AppColors.ink2,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppText.poppins(size: 11.5, color: AppColors.ink4),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.evaGreen)
          : const Icon(Icons.radio_button_unchecked_rounded, size: 20, color: AppColors.ink4),
    );
  }

  Widget _row({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool first = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: first ? null : const Border(top: BorderSide(color: AppColors.surface3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          TintIcon(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink4),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: AppColors.evaGreen,
            inactiveTrackColor: AppColors.surface3,
          ),
        ],
      ),
    );
  }
}
