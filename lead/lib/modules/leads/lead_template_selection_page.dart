import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/leads_service.dart';
import '../../theme/app_colors.dart';

/// WhatsApp-style template selection screen for Lead Send Template.
/// Pushed from Lead Details Send Template tab; pops with selected template on tap.
class LeadTemplateSelectionPage extends StatefulWidget {
  const LeadTemplateSelectionPage({super.key});

  @override
  State<LeadTemplateSelectionPage> createState() =>
      _LeadTemplateSelectionPageState();
}

class _LeadTemplateSelectionPageState extends State<LeadTemplateSelectionPage>
    with TickerProviderStateMixin {
  List<dynamic> _allTemplates = [];
  List<dynamic> _filteredTemplates = [];
  bool _isLoading = true;
  String _errorMessage = '';

  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;
  static const List<String> _categories = [
    'Marketing',
    'Utility',
    'Authentication',
  ];

  static const List<Map<String, dynamic>> _typeFilters = [
    {'label': 'All', 'icon': Icons.grid_view, 'value': 'all'},
    {'label': 'Text', 'icon': Icons.text_fields, 'value': 'text'},
    {'label': 'Image', 'icon': Icons.image, 'value': 'image'},
    {'label': 'File', 'icon': Icons.insert_drive_file, 'value': 'file'},
    {'label': 'Video', 'icon': Icons.videocam, 'value': 'video'},
  ];
  String _selectedType = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(_onTabOrFilterChanged);
    _fetchTemplates();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabOrFilterChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabOrFilterChanged() {
    if (_tabController.indexIsChanging) return;
    _filterTemplates();
  }

  Future<void> _fetchTemplates() async {
    if (kDebugMode) debugPrint('[LeadTemplateSelection] FETCH templates START');
    try {
      final templates = await LeadsService.getApprovedTemplates();
      if (kDebugMode) debugPrint('[LeadTemplateSelection] FETCH templates OK count=${templates.length}');
      if (mounted) {
        setState(() {
          _allTemplates = templates;
          _isLoading = false;
        });
        _filterTemplates();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[LeadTemplateSelection] FETCH templates ERROR $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _filterTemplates() {
    final searchQuery = _searchController.text.trim().toLowerCase();
    final currentCategory = _categories[_tabController.index].toLowerCase();

    setState(() {
      _filteredTemplates = _allTemplates.where((t) {
        final template = t as Map<String, dynamic>;
        final category =
            (template['type'] ?? '').toString().toLowerCase();
        if (category != currentCategory) return false;

        if (_selectedType != 'all') {
          final headerType =
              (template['headerType'] ?? '').toString().toLowerCase();
          final subType =
              (template['subType'] ?? '').toString().toLowerCase();
          if (_selectedType == 'carousel') {
            if (headerType != 'none' || subType != 'carousel') return false;
          } else {
            if (headerType != _selectedType) return false;
          }
        }

        if (searchQuery.isNotEmpty) {
          final name = (template['name'] ?? '').toString().toLowerCase();
          final message = (template['message'] ?? '').toString().toLowerCase();
          if (!name.contains(searchQuery) && !message.contains(searchQuery)) {
            return false;
          }
        }
        return true;
      }).toList();
    });
  }

  void _onSelectTemplate(Map<String, dynamic> template) {
    Navigator.of(context).pop(template);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          'Select Template',
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: cs.onSurfaceVariant,
          indicatorColor: AppColors.primary,
          tabs: _categories.map((c) => Tab(text: c)).toList(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _filterTemplates(),
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search Template',
                    hintStyle: TextStyle(color: cs.onSurfaceVariant),
                    prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                                Icons.close, size: 20, color: cs.onSurfaceVariant),
                            onPressed: () {
                              _searchController.clear();
                              _filterTemplates();
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
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _typeFilters.map((type) {
                      final isSelected = _selectedType == type['value'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                type['icon'] as IconData,
                                size: 16,
                                color: isSelected
                                    ? AppColors.primary
                                    : cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(type['label'] as String),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedType = type['value'] as String;
                              _filterTemplates();
                            });
                          },
                          backgroundColor: cs.surfaceContainerHighest,
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          checkmarkColor: AppColors.primary,
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : cs.outline,
                          ),
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.primary : cs.onSurface,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: cs.error),
                              const SizedBox(height: 12),
                              Text(
                                'Could not load templates',
                                style: TextStyle(fontSize: 16, color: cs.onSurface),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _errorMessage.replaceFirst('Exception: ', ''),
                                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _errorMessage = '';
                                    _isLoading = true;
                                  });
                                  _fetchTemplates();
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filteredTemplates.isEmpty
                        ? Center(
                            child: Text(
                              'No templates found',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.82,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _filteredTemplates.length,
                            itemBuilder: (context, index) {
                              return _buildTemplateCard(
                                _filteredTemplates[index]
                                    as Map<String, dynamic>,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    final cs = Theme.of(context).colorScheme;
    final name = template['name']?.toString() ?? 'Unnamed';
    final message = template['message']?.toString() ?? '';

    return InkWell(
      onTap: () => _onSelectTemplate(template),
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'T',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  message.isEmpty ? '—' : message,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: cs.outline.withOpacity(0.5)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Select',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
