import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/chat_service.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────
//  Quick Reply Page  (full-screen, mirrors the web modal)
// ─────────────────────────────────────────────────────────────
class QuickReplyPage extends StatefulWidget {
  final String contactNumber;

  const QuickReplyPage({super.key, required this.contactNumber});

  @override
  State<QuickReplyPage> createState() => _QuickReplyPageState();
}

class _QuickReplyPageState extends State<QuickReplyPage> {
  /// Show error as red banner at top.
  static void _showErrorAtTop(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: Colors.red.shade700,
        actions: [
          TextButton(
            onPressed: () => messenger.hideCurrentMaterialBanner(),
            child: const Text(
              'DISMISS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(seconds: 4), () {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    });
  }

  List<dynamic> _allReplies = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _activeFilter = 'All'; // All | TEXT | IMAGE | DOCUMENT | VIDEO

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchReplies();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchReplies() async {
    setState(() => _loading = true);
    try {
      final data = await ChatService.getQuickReplies();
      if (mounted) {
        setState(() {
          _allReplies = data;
          _applyFilter();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    _filtered = _allReplies.where((r) {
      final matchSearch = (r['title'] ?? '').toString().toLowerCase().contains(
        _search.toLowerCase(),
      );
      final matchType =
          _activeFilter == 'All' ||
          (r['type'] ?? '').toString().toUpperCase() == _activeFilter;
      return matchSearch && matchType;
    }).toList();
  }

  void _onSearchChanged(String val) {
    setState(() {
      _search = val;
      _applyFilter();
    });
  }

  void _onFilterTap(String filter) {
    setState(() {
      _activeFilter = filter;
      _applyFilter();
    });
  }

  // ── Send quick reply to the contact ──────────────────────────
  Future<void> _sendReply(Map<String, dynamic> reply) async {
    try {
      final type = (reply['type'] ?? 'TEXT').toString().toLowerCase();
      await ChatService.sendMessage(
        toNumber: widget.contactNumber,
        type: type,
        data: {
          'body': reply['content'],
          'link': reply['fileUrl'],
          'caption': reply['content'],
          'filename': reply['title'],
        },
      );
      if (mounted) {
        Navigator.pop(context, true); // pop with refresh signal
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Quick reply sent!')));
      }
    } catch (e) {
      if (mounted) {
        _showErrorAtTop(context, 'Failed to send: $e');
      }
    }
  }

  // ── Delete ────────────────────────────────────────────────────
  Future<void> _deleteReply(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quick Reply'),
        content: const Text(
          'Are you sure you want to delete this quick reply?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ChatService.deleteQuickReply(id);
      _fetchReplies();
    } catch (e) {
      if (mounted) {
        _showErrorAtTop(context, 'Failed to delete: $e');
      }
    }
  }

  // ── Open Add / Edit / Copy form ───────────────────────────────
  Future<void> _openForm({
    Map<String, dynamic>? editing,
    Map<String, dynamic>? copying,
  }) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuickReplyFormPage(editing: editing, copying: copying),
        fullscreenDialog: true,
      ),
    );
    if (result == true) _fetchReplies();
  }

  // ── Build a copy of the reply with a new title ────────────────
  Map<String, dynamic> _makeCopy(Map<String, dynamic> reply) {
    final baseTitle = (reply['title'] ?? '')
        .toString()
        .replaceAll(RegExp(r'\s*copy\d*$', caseSensitive: false), '')
        .trim();
    final existingTitles = _allReplies
        .map((r) => r['title'].toString())
        .toList();
    int copyNum = 0;
    for (final t in existingTitles) {
      final m = RegExp(
        r'^' + RegExp.escape(baseTitle) + r'\s*copy(\d*)$',
        caseSensitive: false,
      ).firstMatch(t);
      if (m != null) {
        final n = int.tryParse(m.group(1) ?? '') ?? 0;
        if (n >= copyNum) copyNum = n + 1;
      }
    }
    final newTitle = copyNum == 0
        ? '$baseTitle copy'
        : '$baseTitle copy$copyNum';
    return {...reply, 'title': newTitle};
  }

  // ─────────────────────────────────────────────────────────────
  //  UI
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Quick Actions',
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: cs.onSurface),
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────
          Container(
            color: cs.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Search by title',
                hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close, size: 20, color: cs.onSurfaceVariant),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _search = '';
                            _applyFilter();
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: cs.surfaceContainerHighest.withOpacity(0.6),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: cs.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: cs.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),

          // ── Type filter tabs ────────────────────────────────
          Container(
            color: cs.surface,
            child: _FilterTabs(active: _activeFilter, onTap: _onFilterTap),
          ),

          const SizedBox(height: 8),

          // ── Cards grid ──────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filtered.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _fetchReplies,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.72,
                          ),
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) => _ReplyCard(
                        reply: _filtered[i],
                        onSend: () => _sendReply(_filtered[i]),
                        onEdit: () => _openForm(editing: _filtered[i]),
                        onCopy: () =>
                            _openForm(copying: _makeCopy(_filtered[i])),
                        onDelete: () =>
                            _deleteReply(_filtered[i]['_id'].toString()),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildEmpty() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flash_on_rounded, size: 64, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            _search.isNotEmpty || _activeFilter != 'All'
                ? 'No quick replies match your filters'
                : 'No quick replies yet.\nTap the + button to create one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Filter Tabs
// ─────────────────────────────────────────────────────────────
class _FilterTabs extends StatelessWidget {
  final String active;
  final ValueChanged<String> onTap;

  const _FilterTabs({required this.active, required this.onTap});

  static const _filters = [
    {'key': 'All', 'label': 'All', 'icon': Icons.grid_view_rounded},
    {'key': 'TEXT', 'label': 'Text', 'icon': Icons.text_fields_rounded},
    {'key': 'IMAGE', 'label': 'Image', 'icon': Icons.image_rounded},
    {
      'key': 'DOCUMENT',
      'label': 'File',
      'icon': Icons.insert_drive_file_rounded,
    },
    {'key': 'VIDEO', 'label': 'Video', 'icon': Icons.videocam_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: _filters.map((f) {
          final isActive = active == f['key'];
          return GestureDetector(
            onTap: () => onTap(f['key'] as String),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive
                        ? AppColors.primaryLight
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    f['icon'] as IconData,
                    size: 14,
                    color: isActive ? AppColors.primaryLight : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    f['label'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isActive
                          ? AppColors.primary
                          : cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Reply Card
// ─────────────────────────────────────────────────────────────
class _ReplyCard extends StatelessWidget {
  final Map<String, dynamic> reply;
  final VoidCallback onSend;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  const _ReplyCard({
    required this.reply,
    required this.onSend,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
  });

  Color _badgeColor(String type) {
    switch (type.toUpperCase()) {
      case 'IMAGE':
        return Colors.blue;
      case 'VIDEO':
        return Colors.purple;
      case 'DOCUMENT':
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final type = (reply['type'] ?? 'TEXT').toString().toUpperCase();
    final fileUrl = reply['fileUrl']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    reply['title'] ?? 'No Title',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _badgeColor(type),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    type,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Media preview
          if ((type == 'IMAGE' || type == 'VIDEO') && fileUrl != null)
            SizedBox(
              height: 80,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: type == 'IMAGE'
                    ? Image.network(
                        fileUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.broken_image, color: cs.onSurfaceVariant),
                      )
                    : Container(
                        color: Colors.black.withOpacity(0.7),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
              ),
            ),

          // Document preview
          if (type == 'DOCUMENT' && fileUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: cs.outline),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.insert_drive_file,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        reply['filename'] ?? 'Document',
                        style: TextStyle(fontSize: 11, color: cs.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Content text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                reply['content'] ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.4,
                ),
                overflow: TextOverflow.fade,
              ),
            ),
          ),

          // Action buttons
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: cs.outline.withOpacity(0.5))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                _ActionBtn(
                  icon: Icons.copy_rounded,
                  onTap: onCopy,
                  tooltip: 'Copy',
                ),
                _ActionBtn(
                  icon: Icons.edit_rounded,
                  onTap: onEdit,
                  tooltip: 'Edit',
                ),
                _ActionBtn(
                  icon: Icons.delete_outline_rounded,
                  onTap: onDelete,
                  tooltip: 'Delete',
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onSend,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: cs.outline),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Quick Reply Form Page  (Add / Edit / Copy)
// ─────────────────────────────────────────────────────────────
class QuickReplyFormPage extends StatefulWidget {
  final Map<String, dynamic>? editing;
  final Map<String, dynamic>? copying;

  const QuickReplyFormPage({super.key, this.editing, this.copying});

  @override
  State<QuickReplyFormPage> createState() => _QuickReplyFormPageState();
}

class _QuickReplyFormPageState extends State<QuickReplyFormPage> {
  static void _showErrorAtTop(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: Colors.red.shade700,
        actions: [
          TextButton(
            onPressed: () => messenger.hideCurrentMaterialBanner(),
            child: const Text(
              'DISMISS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(seconds: 4), () {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    });
  }

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  String _selectedType = 'TEXT';
  String? _fileUrl;
  String? _fileName;
  bool _uploading = false;
  bool _saving = false;

  bool get _isEdit => widget.editing != null;
  bool get _isCopy => widget.copying != null;

  Map<String, dynamic>? get _source => widget.editing ?? widget.copying;

  @override
  void initState() {
    super.initState();
    if (_source != null) {
      _titleCtrl.text = _source!['title'] ?? '';
      _contentCtrl.text = _source!['content'] ?? '';
      _selectedType = (_source!['type'] ?? 'TEXT').toString().toUpperCase();
      _fileUrl = _source!['fileUrl'];
      _fileName = _source!['filename'] ?? _fileUrl?.split('-').last;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  String get _title {
    if (_isCopy) return 'Copy Quick Response';
    if (_isEdit) return 'Edit Quick Response';
    return 'Add a Quick Response';
  }

  String get _submitLabel {
    if (_isCopy) return 'Copy Quick Reply';
    if (_isEdit) return 'Update Quick Reply';
    return 'Save Quick Reply';
  }

  // ── File upload ───────────────────────────────────────────────
  Future<void> _pickAndUpload() async {
    FileType fileType;
    List<String>? allowedExtensions;

    switch (_selectedType) {
      case 'IMAGE':
        fileType = FileType.image;
        break;
      case 'VIDEO':
        fileType = FileType.video;
        break;
      case 'DOCUMENT':
        fileType = FileType.custom;
        allowedExtensions = [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt',
          'rtf',
          'zip',
        ];
        break;
      default:
        return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: fileType,
      allowedExtensions: allowedExtensions,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _uploading = true);
    try {
      final url = await ChatService.uploadFile(file.path!, 'chat');
      if (url != null) {
        setState(() {
          _fileUrl = url;
          _fileName = file.name;
        });
      } else {
        if (mounted) {
          _showErrorAtTop(context, 'File upload failed');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorAtTop(context, 'Upload error: $e');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Save ──────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType != 'TEXT' && _fileUrl == null) {
      _showErrorAtTop(
        context,
        'Please upload a ${_selectedType.toLowerCase()} file',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = {
        'title': _titleCtrl.text.trim(),
        'type': _selectedType,
        'content': _contentCtrl.text.trim(),
        'fileUrl': _fileUrl,
        'filename': _selectedType == 'DOCUMENT' ? _fileName : null,
      };

      if (_isEdit) {
        await ChatService.editQuickReply(
          widget.editing!['_id'].toString(),
          payload,
        );
      } else {
        await ChatService.createQuickReply(payload);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEdit
                  ? 'Quick reply updated!'
                  : (_isCopy ? 'Quick reply copied!' : 'Quick reply added!'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorAtTop(context, 'Failed to save: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _title,
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        iconTheme: IconThemeData(color: cs.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + Type row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildLabel(
                      context,
                      'Title *',
                      TextFormField(
                        controller: _titleCtrl,
                        readOnly: _isCopy,
                        maxLength: 50,
                        style: TextStyle(color: cs.onSurface),
                        decoration: _inputDeco(context, 'Enter the title'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Please enter a title';
                          if (v.length > 50) return 'Max 50 characters';
                          if (!RegExp(r'^[a-zA-Z0-9 ]*$').hasMatch(v))
                            return 'No special characters';
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLabel(
                      context,
                      'Quick Reply Type *',
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: _inputDeco(context, 'Select type'),
                        items: ['TEXT', 'IMAGE', 'VIDEO', 'DOCUMENT']
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                        onChanged: _isCopy
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedType = val;
                                    _fileUrl = null;
                                    _fileName = null;
                                  });
                                }
                              },
                        validator: (v) =>
                            v == null ? 'Please select a type' : null,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Content
              _buildLabel(
                context,
                'Content *',
                TextFormField(
                  controller: _contentCtrl,
                  readOnly: _isCopy,
                  maxLines: 5,
                  maxLength: 1000,
                  style: TextStyle(color: cs.onSurface),
                  decoration: _inputDeco(
                    context,
                    'Enter the content (e.g., message, URL, etc.)',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Please enter content';
                    if (v.length > 1000) return 'Max 1000 characters';
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 16),

              // File upload (non-text types)
              if (_selectedType != 'TEXT') ...[
                _buildLabel(context, 'Upload File *', _buildFileUpload()),
                const SizedBox(height: 16),
              ],

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _submitLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileUpload() {
    if (_uploading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Text(
              'Uploading...',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    if (_fileUrl != null) {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _fileName ?? _fileUrl!.split('-').last,
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!_isCopy)
            TextButton.icon(
              onPressed: () => setState(() {
                _fileUrl = null;
                _fileName = null;
              }),
              icon: const Icon(
                Icons.delete_outline,
                size: 16,
                color: Colors.red,
              ),
              label: const Text(
                'Remove',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.primary),
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.upload_file_rounded, size: 18),
      label: const Text('Upload File'),
      onPressed: _isCopy ? null : _pickAndUpload,
    );
  }

  Widget _buildLabel(BuildContext context, String label, Widget child) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _inputDeco(BuildContext context, String hint) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: cs.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: cs.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}
