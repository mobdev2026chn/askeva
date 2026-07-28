import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/common.dart';

/// Company profile detail (`.cp-*`). Centered avatar header with info cards.
class CompanyProfileScreen extends StatelessWidget {
  final Company company;
  const CompanyProfileScreen({super.key, required this.company});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.surface2,
      body: Column(
        children: [
          // Green centered header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(18, topPad + 8, 18, 56),
            decoration: const BoxDecoration(gradient: AppColors.evaGradient),
            child: Column(
              children: [
                SizedBox(
                  height: 46,
                  child: Row(
                    children: [
                      GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()),
                      Expanded(
                        child: Text('Company', textAlign: TextAlign.center, style: AppText.screenTitle.copyWith(color: Colors.white)),
                      ),
                      const GlassIconButton(icon: Icons.more_horiz_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Color(0xFFEEF5EC)]),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 28, offset: const Offset(0, 12))],
                  ),
                  child: Container(
                    width: 78,
                    height: 78,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: company.color, shape: BoxShape.circle),
                    child: Text(company.shortName, style: AppText.poppins(size: 22, weight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(company.name, style: AppText.poppins(size: 23, weight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4)),
                const SizedBox(height: 3),
                Text(company.email, style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
                const SizedBox(height: 13),
                Wrap(
                  spacing: 8,
                  children: [
                    _chip(Icons.people_alt_rounded, '${company.leadCount} leads'),
                    _chip(Icons.verified_rounded, 'Verified'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -36),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 30),
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const TintIcon(icon: Icons.info_outline_rounded),
                              const SizedBox(width: 11),
                              Text('ABOUT', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink4, letterSpacing: 0.9)),
                            ],
                          ),
                          const SizedBox(height: 11),
                          Text(
                            '${company.name} is an active organisation on AskEva with ${company.leadCount} associated leads. Conversations are handled by the Sales team and synced in real-time.',
                            style: AppText.poppins(size: 14.5, weight: FontWeight.w500, color: AppColors.ink2, height: 1.55),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 13),
                    AppCard(
                      child: Column(
                        children: [
                          _infoRow(Icons.phone_rounded, 'PHONE', '+91 90011 22890', first: true),
                          _infoRow(Icons.mail_outline_rounded, 'EMAIL', company.email),
                          _infoRow(Icons.language_rounded, 'WEBSITE', 'www.${company.shortName.toLowerCase()}.com', link: true),
                          _infoRow(Icons.location_on_outlined, 'ADDRESS', 'Koregaon Park, Pune, MH 411001'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: AppText.poppins(size: 12, weight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String k, String v, {bool first = false, bool link = false}) {
    return Container(
      decoration: BoxDecoration(
        border: first ? null : const Border(top: BorderSide(color: AppColors.surface3)),
      ),
      padding: EdgeInsets.only(top: first ? 0 : 13, bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TintIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k, style: AppText.poppins(size: 11, weight: FontWeight.w800, color: AppColors.ink4, letterSpacing: 0.7)),
                const SizedBox(height: 4),
                Text(v,
                    style: AppText.poppins(
                        size: 14.5, weight: link ? FontWeight.w700 : FontWeight.w600, color: link ? AppColors.evaGreenDeep : AppColors.ink, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
