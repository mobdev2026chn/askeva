import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../modules/lead_settings/profile_page.dart';
import '../modules/dashboard/dashboard_page.dart';
import '../theme/theme_provider.dart';
import '../modules/whatsapp_chat/whatsapp_chat_list_page.dart';
import '../splash_screen.dart';

class AppDrawer extends StatelessWidget {
  final String? email;
  final String? name; // Added name
  const AppDrawer({super.key, this.email, this.name});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeService = ThemeProvider.of(context);

    return Drawer(
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    radius: 26,
                    child: Text(
                      (name ?? email ?? 'U')[0].toUpperCase(),
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name ?? 'User',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                            fontSize: 18,
                          ),
                        ),
                        if (email != null && email!.isNotEmpty)
                          Text(
                            email!,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      themeService.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                    onPressed: () => themeService.toggle(),
                    tooltip: themeService.isDark ? 'Light theme' : 'Dark theme',
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              children: [
                ListTile(
                  leading: Icon(Icons.dashboard_rounded, color: cs.onSurfaceVariant),
                  title: Text(
                    'Dashboard',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => DashboardPage(email: email, name: name),
                      ),
                      (route) => false,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: const Color(0xFF25D366),
                  ),
                  title: Text(
                    'Chat',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WhatsAppChatListPage(
                          drawer: AppDrawer(email: email, name: name),
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.person_outline_rounded, color: cs.onSurfaceVariant),
                  title: Text(
                    'Profile',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    );
                  },
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: cs.onSurface),
            title: Text(
              'Logout',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            onTap: () async {
              // Close drawer first
              Navigator.of(context).pop();

              // Clear FCM token on backend before clearing local auth token
              await FCMService.clearToken();
              await AuthService.clearAuth();
              if (context.mounted) {
                // Reset everything and go back to Splash
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
