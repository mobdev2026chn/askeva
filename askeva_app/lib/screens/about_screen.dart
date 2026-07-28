import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/common.dart';
import '../widgets/settings_extra.dart'; // For SettingsSubScaffold

/// "About" — app version, Meta partnership, and Terms & Conditions summary.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _appVersion = 'v1.0.0+1';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${packageInfo.version}+${packageInfo.buildNumber}';
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSubScaffold(
      title: 'About',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row(Icons.shield_outlined, 'App Version', _appVersion, first: true),
                _row(Icons.chat_bubble_outline_rounded, 'Meta Partner', 'Official WhatsApp Business Solution Provider'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
            child: Text(
              'Terms & Conditions',
              style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3),
            ),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_rounded, size: 18, color: AppColors.evaGreenDeep),
                    const SizedBox(width: 8),
                    Text(
                      'Terms and conditions accepted',
                      style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _bullet('Important Billing Changes — Effective July 1, 2025'),
                _bullet('Pricing Update — Effective January 1, 2026'),
                _bullet('Messaging limits follow your Meta WhatsApp tier and policy.'),
                _bullet('Data is processed per our Privacy Policy & WhatsApp Business terms.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, {bool first = false}) {
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
                  label,
                  style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink4),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 9),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(color: AppColors.ink4, shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink2, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
