import 'package:flutter/material.dart';
import '../dashboard/dashboard_page.dart';
import 'widgets/import_leads_modal.dart';
import '../../theme/app_colors.dart';

/// Screen shown when import has duplicates. Shows duplicate rows (S.No, Phone, Email),
/// FAB to start import again, and bottom nav. Back goes to Leads.
class ImportIssuesScreen extends StatelessWidget {
  /// Duplicate rows: each map has 'sno', 'phone', 'email'
  final List<Map<String, String>> duplicates;
  final VoidCallback? onImportAgain;

  const ImportIssuesScreen({
    super.key,
    required this.duplicates,
    this.onImportAgain,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _goBackToLeads(context),
          tooltip: 'Back to Leads',
        ),
        title: const Text('Import issues'),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Your import has duplicates',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'No leads were imported. Remove or fix the duplicate phone numbers or emails below and try again.',
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(0.8),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(2),
                  },
                  border: TableBorder.all(color: Colors.grey.shade300),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade200),
                      children: [
                        _cell('S.No', bold: true),
                        _cell('Phone No', bold: true),
                        _cell('Email', bold: true),
                      ],
                    ),
                    ...duplicates.map((row) => TableRow(
                      children: [
                        _cell(row['sno'] ?? ''),
                        _cell(row['phone'] ?? '—'),
                        _cell(row['email'] ?? '—'),
                      ],
                    )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openImportModal(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.upload_file),
        label: const Text('Import'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: 1,
          onTap: (index) => _onNavTap(context, index),
          selectedItemColor: cs.primary,
          unselectedItemColor: cs.onSurfaceVariant,
          type: BottomNavigationBarType.fixed,
          backgroundColor: cs.surface,
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people_alt),
              label: 'Leads',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _goBackToLeads(BuildContext context) {
    Navigator.of(context).pop();
  }

  void _onNavTap(BuildContext context, int index) {
    if (index == 1) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DashboardPage(initialIndex: index),
      ),
    );
  }

  void _openImportModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ImportLeadsModal(
        onSuccess: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Leads imported and saved successfully')),
          );
          onImportAgain?.call();
        },
      ),
    );
  }
}
