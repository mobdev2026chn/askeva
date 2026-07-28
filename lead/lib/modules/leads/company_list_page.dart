import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/leads_service.dart';
import 'company_customers_page.dart';

class CompanyListPage extends StatefulWidget {
  const CompanyListPage({super.key});

  @override
  State<CompanyListPage> createState() => _CompanyListPageState();
}

class _CompanyListPageState extends State<CompanyListPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _fetchAndGroupCompanies();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchAndGroupCompanies() async {
    final all = await LeadsService.fetchAllLeads();
    var items = all;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      items = all.where((lead) {
        final name = (lead['name'] ?? '').toString().toLowerCase();
        final email = (lead['email'] ?? '').toString().toLowerCase();
        final fullMobile = (lead['fullMobile'] ?? '').toString().toLowerCase();
        final mobile = (lead['mobile'] ?? '').toString().toLowerCase();
        final company = lead['company'];
        final companyStr = company is String
            ? company.toLowerCase()
            : (company is Map ? (company['name'] ?? '').toString().toLowerCase() : '');
        return name.contains(q) || email.contains(q) || fullMobile.contains(q) || mobile.contains(q) || companyStr.contains(q);
      }).toList();
    }

    final Map<String, int> companyCounts = {};
    int noCompanyCount = 0;

    for (var item in items) {
      String? companyName;
      final rawCompany = item['company'];
      if (rawCompany is Map) {
        companyName = rawCompany['name'];
      } else if (rawCompany != null) {
        companyName = rawCompany.toString();
      }

      if (companyName != null &&
          companyName.trim().isNotEmpty &&
          companyName.toLowerCase() != 'null') {
        companyCounts[companyName] = (companyCounts[companyName] ?? 0) + 1;
      } else {
        noCompanyCount++;
      }
    }

    final List<Map<String, dynamic>> grouped = [];

    companyCounts.forEach((name, count) {
      grouped.add({'name': name, 'count': count, 'id': name});
    });

    if (noCompanyCount > 0) {
      grouped.add({
        'name': 'No Company',
        'count': noCompanyCount,
        'id': 'no_company_special_id',
      });
    }

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      grouped.removeWhere((item) {
        final name = (item['name'] as String).toLowerCase();
        return !name.contains(query);
      });
    }

    grouped.sort((a, b) {
      if (a['id'] == 'no_company_special_id') return 1;
      if (b['id'] == 'no_company_special_id') return -1;
      return (a['name'] as String).compareTo(b['name'] as String);
    });

    return grouped;
  }

  void _openViewLeads(String companyId, String companyName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompanyCustomersPage(
          companyId: companyId,
          companyName: companyName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceVariant = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _refresh();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search Companies',
              prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).colorScheme.onSurface.withOpacity(0.8) : Colors.grey[600], size: 22),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.cancel, color: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).colorScheme.onSurface.withOpacity(0.8) : Colors.grey[600], size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _refresh();
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.primary,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                if (snap.hasError) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline_rounded, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                                const SizedBox(height: 12),
                                Text(
                                  'Something went wrong',
                                  style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${snap.error}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.business_center_rounded, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                              const SizedBox(height: 16),
                              Text(
                                'No companies found',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Leads will appear here when assigned to a company',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final it = items[index];
                    final name = it['name'] as String;
                    final count = it['count'] ?? 0;
                    final id = it['id'] as String;
                    final isNoCompany = id == 'no_company_special_id';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CompanyCard(
                        companyName: name,
                        leadCount: count,
                        isNoCompany: isNoCompany,
                        onTap: () => _openViewLeads(id, name),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CompanyCard extends StatelessWidget {
  final String companyName;
  final int leadCount;
  final bool isNoCompany;
  final VoidCallback onTap;

  const _CompanyCard({
    required this.companyName,
    required this.leadCount,
    required this.isNoCompany,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

    final initial = companyName.isNotEmpty
        ? (isNoCompany ? '?' : companyName[0].toUpperCase())
        : '?';
    final iconBg = isNoCompany
        ? (isDark ? Colors.white54 : Colors.grey.shade400)
        : AppColors.primary;

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
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBg.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: iconBg,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companyName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 16,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          leadCount == 1 ? '1 lead' : '$leadCount leads',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Leads',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
