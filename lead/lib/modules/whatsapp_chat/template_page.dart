import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../theme/app_colors.dart';

/// Show banner at top **above** any open form (overlay-based).
void _showTemplateBannerAboveForm(BuildContext context, String message,
    {bool isError = false}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  void remove() {
    try {
      entry.remove();
    } catch (_) {}
  }
  entry = OverlayEntry(
    builder: (_) => Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: isError ? Colors.red.shade700 : AppColors.primary,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.check_circle,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                TextButton(
                  onPressed: remove,
                  child: const Text(
                    'DISMISS',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(
      Duration(seconds: isError ? 4 : 3), remove);
}

/// Show error as red banner at top (above form).
void _showTemplateErrorAtTop(BuildContext context, String message) {
  _showTemplateBannerAboveForm(context, message, isError: true);
}

/// Show success as green banner at top (above form).
void _showTemplateSuccessBanner(BuildContext context) {
  _showTemplateBannerAboveForm(context, 'Template sent successfully');
}

class TemplatePage extends StatefulWidget {
  final String contactNumber;
  final bool isIntervened;

  const TemplatePage({
    super.key,
    required this.contactNumber,
    this.isIntervened = true,
  });

  @override
  State<TemplatePage> createState() => _TemplatePageState();
}

class _TemplatePageState extends State<TemplatePage>
    with TickerProviderStateMixin {
  List<dynamic> _allTemplates = [];
  List<dynamic> _filteredTemplates = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Search
  final TextEditingController _searchController = TextEditingController();

  // Tabs (Categories)
  late TabController _tabController;
  final List<String> _categories = ['Marketing', 'Utility', 'Authentication'];

  // Filters (Types)
  final List<Map<String, dynamic>> _typeFilters = [
    {'label': 'All', 'icon': Icons.grid_view, 'value': 'all'},
    {'label': 'Text', 'icon': Icons.text_fields, 'value': 'text'},
    {'label': 'Image', 'icon': Icons.image, 'value': 'image'},
    {'label': 'File', 'icon': Icons.insert_drive_file, 'value': 'file'},
    {'label': 'Video', 'icon': Icons.videocam, 'value': 'video'},
    {'label': 'Carousel', 'icon': Icons.view_carousel, 'value': 'carousel'},
  ];
  String _selectedType = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _fetchTemplates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      _filterTemplates();
    }
  }

  Future<void> _fetchTemplates() async {
    try {
      final templates = await ChatService.getApprovedTemplates();
      if (mounted) {
        setState(() {
          _allTemplates = templates;
          _isLoading = false;
        });
        _filterTemplates();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _filterTemplates() {
    final searchQuery = _searchController.text.toLowerCase();
    final currentCategory = _categories[_tabController.index].toLowerCase();

    setState(() {
      _filteredTemplates = _allTemplates.where((template) {
        // 1. Filter by Category (Web uses 'type' for category)
        final category = (template['type'] ?? '').toString().toLowerCase();
        if (category != currentCategory) return false;

        // 2. Filter by Type
        if (_selectedType != 'all') {
          final headerType = (template['headerType'] ?? '')
              .toString()
              .toLowerCase();
          final subType = (template['subType'] ?? '').toString().toLowerCase();

          if (_selectedType == 'carousel') {
            // Web: template.headerType === "none" && template.subType === "carousel"
            if (headerType != 'none' || subType != 'carousel') return false;
          } else {
            // Web: template.headerType?.toLowerCase() === typeMap[activeTab]
            // typeMap: text: "text", image: "image", ...
            // We need to ensure text templates have headerType 'text'
            // If the backend returns 'none' for text templates, we might need to adjust,
            // but strictly following valid web code 'text' maps to 'text'.
            // However, just in case, let's treat 'none' as 'text' if not carousel, or strictly follow web.
            // Web code: text: "text"
            if (headerType != _selectedType) return false;
          }
        }

        // 3. Filter by Search
        final name = (template['name'] ?? '').toString().toLowerCase();
        final message = (template['message'] ?? '').toString().toLowerCase();
        if (searchQuery.isNotEmpty &&
            !name.contains(searchQuery) &&
            !message.contains(searchQuery)) {
          return false;
        }

        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          'Template and Quick Actions',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: AppColors.primary,
          tabs: _categories.map((c) => Tab(text: c)).toList(),
        ),
      ),
      body: Column(
        children: [
          // Search and Filters
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() => _filterTemplates()),
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search by template name',
                    hintStyle: TextStyle(color: cs.onSurfaceVariant),
                    prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close, size: 20, color: cs.onSurfaceVariant),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _filterTemplates());
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: cs.outline),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Type Filters (Horizontal List)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _typeFilters.map((type) {
                      final isSelected = _selectedType == type['value'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                type['icon'],
                                size: 16,
                                color: isSelected
                                    ? AppColors.primary
                                    : cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(type['label']),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedType = type['value'];
                            });
                            _filterTemplates();
                          },
                          backgroundColor: cs.surfaceContainerHighest,
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          checkmarkColor: AppColors.primary,
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : cs.outline,
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : cs.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Template Grid/List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage.isNotEmpty
                ? Center(child: Text('Error: $_errorMessage', style: TextStyle(color: cs.onSurface)))
                : _filteredTemplates.isEmpty
                ? Center(child: Text('No templates found', style: TextStyle(color: cs.onSurfaceVariant)))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, // 2 columns for mobile
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: _filteredTemplates.length,
                    itemBuilder: (context, index) {
                      return _buildTemplateCard(_filteredTemplates[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    final cs = Theme.of(context).colorScheme;
    final name = template['name'] ?? 'Unnamed';
    final message = template['message'] ?? '';
    final headerType = template['headerType'];

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Name + Type Badge)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (headerType ?? 'text').toString().toLowerCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: cs.outline.withOpacity(0.5)),

          // Body Preview
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                message,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Send Button
          InkWell(
            onTap: () => _handleTemplateSelection(template),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: cs.outline.withOpacity(0.5))),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Send Template',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Variable Handling Checks (Copied from WhatsAppChatPage logic)
  Future<void> _handleTemplateSelection(Map<String, dynamic> template) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => _TemplatePreviewDialog(
            template: template,
            scrollController: scrollController,
            onSend: (data) async {
              await _sendTemplateFinal(template, data);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _sendTemplateFinal(
    Map<String, dynamic> template,
    Map<String, dynamic> data,
  ) async {
    // Show loading
    setState(() => _isLoading = true);

    try {
      final method = widget.isIntervened ? 'intervene' : 'chat-send';
      final variables = data['variables'] as Map<String, String>;
      final fileUrl = data['file'] as String?;
      final carouselFiles = data['files'] as List<String?>?;

      final reqData = {
        'countryCode': '91',
        'contactNumber': widget.contactNumber,
        'method': 'single',
        ...variables,
        'campaignId': '$method-send',
        'header':
            [
              'image',
              'video',
              'file',
            ].contains(template['headerType']?.toString().toLowerCase())
            ? fileUrl
            : template['message'],
      };

      if (template['headerType'] == 'none' &&
          template['subType'] == 'carousel') {
        if (carouselFiles != null) {
          // Validate all cards have files
          if (carouselFiles.contains(null) || carouselFiles.isEmpty) {
            throw Exception("Please upload images for all carousel cards.");
          }
          reqData['cards'] = carouselFiles
              .map((url) => {'header': url})
              .toList();
        } else {
          throw Exception("Please upload images for all carousel cards.");
        }
      }

      await ChatService.sendTemplate(
        templateId: template['_id'],
        data: reqData,
        method: method,
      );

      if (mounted) {
        _showTemplateSuccessBanner(context);
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showTemplateErrorAtTop(
          context,
          'Failed to send template: ${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
  }
}

class _TemplatePreviewDialog extends StatefulWidget {
  final Map<String, dynamic> template;
  final ScrollController? scrollController;
  final Function(Map<String, dynamic>) onSend;

  const _TemplatePreviewDialog({
    required this.template,
    this.scrollController,
    required this.onSend,
  });

  @override
  State<_TemplatePreviewDialog> createState() => _TemplatePreviewDialogState();
}

class _TemplatePreviewDialogState extends State<_TemplatePreviewDialog> {
  late TextEditingController _previewController;
  final Map<String, TextEditingController> _variableControllers = {};
  String? _uploadedFileUrl;

  // Carousel State
  List<String?> _carouselFiles = [];
  int _currentCardIndex = 0;

  bool _isUploading = false;
  List<String> _variables = [];

  @override
  void initState() {
    super.initState();
    final message = (widget.template['message'] ?? '').toString();
    _previewController = TextEditingController(text: message);
    _variables = _uniqueVariables(message);

    for (var v in _variables) {
      _variableControllers[v] = TextEditingController();
      _variableControllers[v]!.addListener(_updatePreview);
    }

    // Initialize carousel files if needed
    if (_isCarousel()) {
      final cards = widget.template['cards'] as List<dynamic>? ?? [];
      _carouselFiles = List.filled(cards.length, null);
    }
  }

  bool _isCarousel() {
    return (widget.template['headerType'] == 'none' ||
            widget.template['headerType'] == null) &&
        widget.template['subType'] == 'carousel';
  }

  @override
  void dispose() {
    _previewController.dispose();
    for (var c in _variableControllers.values) c.dispose();
    super.dispose();
  }

  void _updatePreview() {
    String message = (widget.template['message'] ?? '').toString();
    for (var v in _variables) {
      final value = _variableControllers[v]!.text;
      message = message.replaceAll('{{$v}}', value.isEmpty ? '{{$v}}' : value);
    }
    _previewController.text = message;
  }

  List<String> _uniqueVariables(String text) {
    final regExp = RegExp(
      r'\{\{(\d+|[a-zA-Z]+)\}\}',
    ); // Updated regex to support named variables
    final matches = regExp.allMatches(text);
    return matches.map((m) => m.group(1)!).toSet().toList()..sort();
  }

  /// Validation matching web (askeva-react SelectTemplate.jsx / Leads SendTemplate).
  /// Returns null if valid, otherwise error message.
  String? _validateBeforeSend() {
    final headerType = (widget.template['headerType'] ?? '')
        .toString()
        .toLowerCase();
    final isMedia = ['image', 'video', 'file'].contains(headerType);
    final isCarousel = _isCarousel();
    final cards = widget.template['cards'] as List<dynamic>? ?? [];

    // 1. All variables must be filled (web: "Please fill in all the variable mappings!" / "Please fill: var1, var2")
    final emptyVars = _variables
        .where((v) => (_variableControllers[v]?.text ?? '').trim().isEmpty)
        .toList();
    if (emptyVars.isNotEmpty) {
      return 'Please fill: ${emptyVars.join(", ")}';
    }

    // 2. OTP / pincode must be numbers only (web: "${ele} must be Numbers")
    for (final v in _variables) {
      final lower = v.toString().toLowerCase();
      if (lower.contains('otp') || lower.contains('pincode')) {
        final val = _variableControllers[v]?.text ?? '';
        if (val.isNotEmpty && !RegExp(r'^\d+$').hasMatch(val)) {
          return '$v must be Numbers';
        }
      }
    }

    // 3. Image/Video/File templates require file upload (web: "Please upload ${headerType} file" / "Please select a ${type}")
    if (isMedia && (_uploadedFileUrl == null || _uploadedFileUrl!.isEmpty)) {
      return 'Please upload ${headerType} file';
    }

    // 4. Carousel requires all cards to have files (web: "Please select all carousel files")
    if (isCarousel && cards.isNotEmpty) {
      if (_carouselFiles.length != cards.length ||
          _carouselFiles.any((f) => f == null || f.isEmpty)) {
        return 'Please select all carousel files';
      }
    }

    return null;
  }

  Future<void> _pickAndUploadFile([int? carouselIndex]) async {
    setState(() => _isUploading = true);
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.single.path;
        if (path != null) {
          final url = await ChatService.uploadFile(path, 'chat');
          if (url != null) {
            setState(() {
              if (carouselIndex != null) {
                _carouselFiles[carouselIndex] = url;
                // Auto-advance to next card after upload; user can use arrows to go back
                if (carouselIndex < _carouselFiles.length - 1) {
                  _currentCardIndex = carouselIndex + 1;
                }
              } else {
                _uploadedFileUrl = url;
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showTemplateErrorAtTop(context, 'Upload failed: $e');
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Widget _buildFilePreview(String? url, String type) {
    if (url == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final isImage =
        type == 'image' ||
        url.toLowerCase().endsWith('.jpg') ||
        url.toLowerCase().endsWith('.png') ||
        url.toLowerCase().endsWith('.jpeg');

    if (isImage) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        height: 100,
        width: 100,
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: cs.onSurfaceVariant),
          ),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              url.split('/').last,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerType = (widget.template['headerType'] ?? '')
        .toString()
        .toLowerCase();
    final isMedia = ['image', 'video', 'file'].contains(headerType);
    final isCarousel = _isCarousel();
    final cards = widget.template['cards'] as List<dynamic>? ?? [];

    final scrollController = widget.scrollController ?? ScrollController();
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Preview or Edit Message',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: cs.brightness == Brightness.dark
                        ? cs.onSurfaceVariant
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // Preview Text Area
            TextField(
              controller: _previewController,
              readOnly: true,
              maxLines: null,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                labelText: 'Message Preview',
                labelStyle: TextStyle(color: cs.onSurfaceVariant),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: cs.outline),
                ),
                fillColor: cs.surfaceContainerHighest,
                filled: true,
              ),
            ),
            const SizedBox(height: 16),

            // Variable Inputs - label above + placeholder like variable name (screenshot)
            if (_variables.isNotEmpty) ...[
              Text(
                'Variables:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ..._variables.map(
                (v) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _variableControllers[v],
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          hintText: v.toString(),
                          hintStyle: TextStyle(color: cs.onSurfaceVariant),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: cs.outline),
                          ),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Media Upload (Single) - Required for image/video/file templates (same as web)
            if (isMedia) ...[
              Text(
                '${headerType[0].toUpperCase()}${headerType.substring(1)} Attachment (Required):',
                style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
              ),
              const SizedBox(height: 8),
              if (_uploadedFileUrl != null)
                _buildFilePreview(_uploadedFileUrl, headerType),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isUploading ? null : () => _pickAndUploadFile(),
                  icon: _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.upload_file),
                  label: Text(
                    _uploadedFileUrl != null
                        ? 'Change File'
                        : 'Upload ${headerType.toUpperCase()}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Carousel Uploads (Navigation View) - All cards required (same as web)
            if (isCarousel && cards.isNotEmpty) ...[
              Text(
                'Carousel Cards (Required - upload for all):',
                style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _currentCardIndex > 0
                              ? () => setState(() => _currentCardIndex--)
                              : null,
                          icon: Icon(Icons.arrow_back_ios, size: 16, color: cs.onSurface),
                        ),
                        Text(
                          "Card ${_currentCardIndex + 1} of ${cards.length}",
                          style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
                        ),
                        IconButton(
                          onPressed: _currentCardIndex < cards.length - 1
                              ? () => setState(() => _currentCardIndex++)
                              : null,
                          icon: Icon(Icons.arrow_forward_ios, size: 16, color: cs.onSurface),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    if (_carouselFiles[_currentCardIndex] != null)
                      Container(
                        width: double.infinity,
                        height: 140,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: cs.outline.withOpacity(0.5)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            _carouselFiles[_currentCardIndex]!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 140,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.broken_image,
                              color: cs.onSurfaceVariant,
                              size: 48,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isUploading
                            ? null
                            : () => _pickAndUploadFile(_currentCardIndex),
                        icon: const Icon(Icons.image, size: 16),
                        label: Text(
                          _carouselFiles[_currentCardIndex] != null
                              ? 'Change Image'
                              : 'Upload Image',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isUploading
                          ? null
                          : () {
                              final error = _validateBeforeSend();
                              if (error != null) {
                                _showTemplateErrorAtTop(context, error);
                                return;
                              }
                              final variables = {
                                for (var v in _variables)
                                  v: _variableControllers[v]!.text,
                              };
                              widget.onSend({
                                'variables': variables,
                                'file': _uploadedFileUrl,
                                'files': _carouselFiles.isNotEmpty
                                    ? _carouselFiles
                                    : null,
                              });
                              Navigator.pop(context);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Send'),
                    ),
                  ),
                ),
              ],
            ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
