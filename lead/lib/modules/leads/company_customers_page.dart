import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/leads_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/drawer_menu_icon.dart';
import 'lead_details_page.dart';

class CompanyCustomersPage extends StatefulWidget {
  final String? companyId;
  final String? companyName;
  const CompanyCustomersPage({super.key, this.companyId, this.companyName});

  @override
  State<CompanyCustomersPage> createState() => _CompanyCustomersPageState();
}

class _CompanyCustomersPageState extends State<CompanyCustomersPage> {
  late Future<List<dynamic>> _future;
  List<dynamic> _allLeads = [];
  String _searchQuery = '';
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _fetchFilteredLeads();
    });
  }

  List<dynamic> get _filteredLeads {
    if (_searchQuery.trim().isEmpty) return _allLeads;
    final q = _searchQuery.trim().toLowerCase();
    return _allLeads.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final mobile = (item['mobile'] ?? '').toString().toLowerCase();
      final email = (item['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || mobile.contains(q) || email.contains(q);
    }).toList();
  }

  Future<List<dynamic>> _fetchFilteredLeads() async {
    final allLeads = await LeadsService.fetchAllLeads();

    if (widget.companyId == 'no_company_special_id') {
      return allLeads.where((item) {
        final rawCompany = item['company'];
        if (rawCompany == null) return true;
        if (rawCompany is String && rawCompany.trim().isEmpty) return true;
        if (rawCompany is Map &&
            (rawCompany['name'] == null ||
                rawCompany['name'].toString().trim().isEmpty))
          return true;
        return false;
      }).toList();
    } else {
      // Filter by company name
      final targetName = widget.companyName;
      if (targetName == null) return [];

      return allLeads.where((item) {
        final rawCompany = item['company'];
        String? cName;
        if (rawCompany is Map) {
          cName = rawCompany['name'];
        } else if (rawCompany != null) {
          cName = rawCompany.toString();
        }
        return cName == targetName;
      }).toList();
    }
  }

  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedIds.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _exportSelected() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one customer')),
      );
      return;
    }

    final url = LeadsService.getCustomerExportUrl(ids: _selectedIds.toList());
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      _exitSelectionMode();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch export URL: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: const DrawerMenuIcon(),
        title: Text('${widget.companyName ?? 'Company'} – Leads'),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportSelected,
              tooltip: 'Export Selected',
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitSelectionMode,
              tooltip: 'Cancel',
            ),
          ] else ...[
            IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: _enterSelectionMode,
              tooltip: 'Enable Selection for Export',
            ),
          ],
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              ),
            );
          }
          if (snap.hasError) {
            return RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error: ${snap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          final items = snap.data ?? [];
          _allLeads = items;
          final displayItems = _filteredLeads;

          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline_rounded, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                        const SizedBox(height: 16),
                        Text(
                          'No leads found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No leads in this group yet',
                          style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, mobile, email...',
                    prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).colorScheme.onSurface.withOpacity(0.8) : Colors.grey[600], size: 22),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.primary,
                  child: displayItems.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: 200,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.search_off_rounded, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No matching leads',
                                      style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: displayItems.length,
                          itemBuilder: (context, index) {
                            final it = displayItems[index] as Map<String, dynamic>;
                            final idRaw = it['id'] ?? it['_id'];
                            final id = idRaw?.toString();
                            final name = it['name']?.toString() ?? '—';
                            final mobile = it['mobile']?.toString() ?? '—';
                            final email = it['email']?.toString() ?? '—';
                            final status = it['status']?.toString() ?? '—';
                            final source = it['source']?.toString() ?? '—';
                            final sNo = index + 1;
                            final selected = id != null && _selectedIds.contains(id);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _LeadCard(
                                sNo: sNo,
                                name: name,
                                mobile: mobile,
                                email: email,
                                status: status,
                                source: source,
                                isSelectionMode: _selectionMode,
                                isSelected: selected,
                                onTap: () {
                                  if (_selectionMode) {
                                    if (id != null) _toggleSelection(id);
                                  } else {
                                    final detailsLeadId = LeadsService.leadIdFromLead(it);
                                    if (detailsLeadId != null && detailsLeadId.isNotEmpty) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => LeadDetailsPage(leadId: detailsLeadId),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  final int sNo;
  final String name;
  final String mobile;
  final String email;
  final String status;
  final String source;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;

  const _LeadCard({
    required this.sNo,
    required this.name,
    required this.mobile,
    required this.email,
    required this.status,
    required this.source,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;
    final initial = name.isNotEmpty && name != '—' ? name[0].toUpperCase() : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : borderColor,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 2),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap(),
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$sNo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(icon: Icons.phone_outlined, label: mobile),
                    if (email != '—') _InfoRow(icon: Icons.email_outlined, label: email),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (status != '—')
                          _ChipLabel(label: status, icon: Icons.flag_outlined),
                        if (source != '—')
                          _ChipLabel(label: source, icon: Icons.source_rounded),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white54 : Colors.grey.shade400,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isDark ? Colors.white70 : Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey[700]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final String label;
  final IconData icon;

  const _ChipLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
