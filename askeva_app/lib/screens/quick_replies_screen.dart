import 'package:flutter/material.dart';
import '../api/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/dashboard_sheets.dart' show appToast;
import '../widgets/common.dart';
import '../shell/app_nav.dart';

class QuickRepliesScreen extends StatefulWidget {
  const QuickRepliesScreen({super.key});

  @override
  State<QuickRepliesScreen> createState() => _QuickRepliesScreenState();
}

class _QuickRepliesScreenState extends State<QuickRepliesScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _quickReplies = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _snack(String msg, {bool err = false}) {
    appToast(context, msg);
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final repo = AppScope.of(context).ticketing;
      final data = await repo.fetchQuickReplies();
      if (mounted) {
        setState(() {
          _quickReplies = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Failed to load quick replies: $e', err: true);
      }
    }
  }

  Future<void> _deleteReply(Map<String, dynamic> reply) async {
    final id = reply['id'] ?? reply['_id'] ?? '';
    final title = reply['title'] ?? 'Quick Reply';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Quick Reply', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
        content: Text('Are you sure you want to delete "$title"?', style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink2)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink3))),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final repo = AppScope.of(context).ticketing;
      await repo.deleteQuickReply(id);
      _snack('Quick reply deleted successfully');
      _loadData();
    } catch (e) {
      _snack('Failed to delete quick reply: $e', err: true);
    }
  }

  void _showFormSheet([Map<String, dynamic>? reply]) {
    final titleCtrl = TextEditingController(text: reply?['title']?.toString() ?? '');
    final msgCtrl = TextEditingController(text: reply?['message']?.toString() ?? '');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text(
                reply == null ? 'Add New Quick Reply' : 'Edit Quick Reply',
                style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 16),

              // Title Input
              RichText(text: TextSpan(children: [
                TextSpan(text: 'Title', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                TextSpan(text: ' *', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.danger)),
              ])),
              const SizedBox(height: 6),
              Container(
                height: 40,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
                child: TextField(
                  controller: titleCtrl,
                  style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Enter quick reply title',
                    hintStyle: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink4),
                    prefixIcon: const Icon(Icons.local_offer_outlined, size: 16, color: AppColors.ink4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Message Input
              RichText(text: TextSpan(children: [
                TextSpan(text: 'Message', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                TextSpan(text: ' *', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.danger)),
              ])),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: msgCtrl,
                      maxLines: 4,
                      maxLength: 1000,
                      style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Enter quick reply message',
                        hintStyle: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink4),
                        contentPadding: EdgeInsets.zero,
                        counterText: '',
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => setSt(() {}),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${msgCtrl.text.length}/1000',
                      style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Actions Footer Row (Cancel & OK)
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink2,
                      side: const BorderSide(color: AppColors.line),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Cancel', style: AppText.poppins(size: 13.5, weight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: saving ? null : () async {
                        final title = titleCtrl.text.trim();
                        final msg = msgCtrl.text.trim();

                        if (title.isEmpty || msg.isEmpty) {
                          _snack('Title and Message are required', err: true);
                          return;
                        }

                        final payload = {
                          'title': title,
                          'message': msg,
                        };

                        setSt(() => saving = true);
                        try {
                          final repo = AppScope.of(context).ticketing;
                          if (reply == null) {
                            await repo.createQuickReply(payload);
                            _snack('Quick reply created successfully');
                          } else {
                            final id = reply['id'] ?? reply['_id'] ?? '';
                            await repo.updateQuickReply(id, payload);
                            _snack('Quick reply updated successfully');
                          }
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          _loadData();
                        } catch (e) {
                          _snack('Failed to save quick reply: $e', err: true);
                          setSt(() => saving = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.evaGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: saving
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('OK', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = AppNav.maybeOf(context);
    final totalReplies = _quickReplies.length;

    return Scaffold(
      backgroundColor: AppColors.surface2,
      body: GreenHeaderScaffold(
        title: 'Ticketing',
        onMenu: nav?.openDrawer,
        headerChild: GreenSegmented(
          items: const ['Dashboard', 'Tickets', 'Settings'],
          selected: 2, // Settings
          onChanged: (i) {
            if (i != 2) {
              Navigator.of(context).pop(i);
            }
          },
        ),
        sheet: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.evaGreen))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button row
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                            color: AppColors.evaGreen,
                            borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back_ios_new_rounded,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text('Back',
                                style: AppText.poppins(
                                    size: 13,
                                    weight: FontWeight.w700,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Screen Title
                    Text('Quick Reply Configuration',
                        style: AppText.poppins(
                            size: 20,
                            weight: FontWeight.w800,
                            color: AppColors.ink)),
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                        boxShadow: AppColors.shadowSm,
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Card Header Row with title and count badge
                        Row(children: [
                          Expanded(
                            child: Text('Quick Reply Configuration', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFE8F2FF), borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              '$totalReplies quick replies',
                              style: AppText.poppins(size: 11, weight: FontWeight.w700, color: const Color(0xFF1E3A8A)),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),

                        // Add Quick Reply green button
                        SizedBox(
                          height: 38,
                          child: ElevatedButton.icon(
                            onPressed: () => _showFormSheet(),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add Quick Reply'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.evaGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1, color: AppColors.line),
                        const SizedBox(height: 16),

                        // List of quick replies
                        if (totalReplies == 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: Text('No quick replies configured.', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink4))),
                          )
                        else
                          ..._quickReplies.map((reply) {
                            final title = reply['title']?.toString() ?? 'Quick Reply';
                            final messageStr = reply['message']?.toString() ?? '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Row(children: [
                                // Icon on left
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED), // light orange
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.access_time_rounded, color: Color(0xFFD97706), size: 18),
                                ),
                                const SizedBox(width: 12),

                                // Text in middle
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(title, style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
                                    const SizedBox(height: 3),
                                    Text(
                                      messageStr,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink4, height: 1.3),
                                    ),
                                  ]),
                                ),

                                // Actions
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.line),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => _showFormSheet(reply),
                                    icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.ink3),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFEE2E2)),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => _deleteReply(reply),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                                  ),
                                ),
                              ]),
                            );
                          }),
                      ]),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
