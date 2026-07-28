import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// Full-screen template selection matching web ComposeModals:
/// Search, Marketing/Utility/Authentication tabs, Text/Image/File/Video filters, grid of cards.
class TemplateSelectionModal extends StatefulWidget {
  final List<dynamic> templates;
  final void Function(Map<String, dynamic> template) onSelect;
  final void Function() onClose;

  const TemplateSelectionModal({
    super.key,
    required this.templates,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<TemplateSelectionModal> createState() => _TemplateSelectionModalState();
}

class _TemplateSelectionModalState extends State<TemplateSelectionModal> {
  String _searchQuery = '';
  String _category = 'all'; // all, marketing, utility, authentication
  String _contentFilter = 'all'; // all, text, image, file, video

  List<dynamic> get _filteredTemplates {
    var list = widget.templates;
    if (list.isEmpty) return [];

    // Category filter (template.type: MARKETING, UTILITY, AUTHENTICATION)
    if (_category.isNotEmpty && _category != 'all') {
      list = list.where((t) {
        final type = (t['type'] as String?)?.toLowerCase();
        return type == _category.toLowerCase();
      }).toList();
    }

    // Content type filter (template.headerType)
    if (_contentFilter != 'all') {
      list = list.where((t) {
        final ht = (t['headerType'] as String?)?.toLowerCase();
        if (_contentFilter == 'text') return ht == 'text' || ht == null || ht.isEmpty;
        return ht == _contentFilter;
      }).toList();
    }

    // Search by name
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((t) {
        final name = (t['name'] as String?)?.toLowerCase() ?? '';
        final msg = (t['message'] as String?)?.toLowerCase() ?? '';
        return name.contains(q) || msg.contains(q);
      }).toList();
    }

    return list;
  }

  IconData _iconForTemplate(Map<String, dynamic> t) {
    final ht = (t['headerType'] as String?)?.toLowerCase();
    if (ht == 'image') return Icons.image;
    if (ht == 'video') return Icons.videocam;
    if (ht == 'file' || ht == 'document') return Icons.insert_drive_file;
    return Icons.text_fields; // text or default
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTemplates;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Select Template'),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search Template',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category tabs (Marketing, Utility, Authentication)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _tabChip('All', 'all'),
                const SizedBox(width: 8),
                _tabChip('Marketing', 'marketing'),
                const SizedBox(width: 8),
                _tabChip('Utility', 'utility'),
                const SizedBox(width: 8),
                _tabChip('Authentication', 'authentication'),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content type filters (All, Text, Image, File, Video)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip('All', 'all', Icons.grid_view),
                const SizedBox(width: 8),
                _filterChip('Text', 'text', Icons.text_fields),
                const SizedBox(width: 8),
                _filterChip('Image', 'image', Icons.image),
                const SizedBox(width: 8),
                _filterChip('File', 'file', Icons.insert_drive_file),
                const SizedBox(width: 8),
                _filterChip('Video', 'video', Icons.videocam),
              ],
            ),
          ),
          const Divider(height: 1),
          // Grid of template cards
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No template available',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final t = filtered[index] as Map<String, dynamic>;
                      final name = (t['name'] ?? 'Template').toString();
                      final message = (t['message'] ?? '').toString();
                      final preview = message.length > 80 ? '${message.substring(0, 80)}...' : message;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => widget.onSelect(t),
                          borderRadius: BorderRadius.circular(12),
                          child: Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _iconForTemplate(t),
                                        size: 32,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Expanded(
                                    child: Text(
                                      preview,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(String label, String value) {
    final selected = _category == value;
    return FilterChip(
      label: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      selected: selected,
      onSelected: (_) => setState(() => _category = value),
      selectedColor: AppColors.primary.withOpacity(0.3),
      checkmarkColor: AppColors.primary,
    );
  }

  Widget _filterChip(String label, String value, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    final selected = _contentFilter == value;
    return FilterChip(
      avatar: Icon(icon, size: 18, color: selected ? AppColors.primary : cs.onSurfaceVariant),
      label: Text(label, style: TextStyle(color: cs.onSurface)),
      selected: selected,
      onSelected: (_) => setState(() => _contentFilter = value),
      selectedColor: AppColors.primary.withOpacity(0.3),
      checkmarkColor: AppColors.primary,
    );
  }
}
