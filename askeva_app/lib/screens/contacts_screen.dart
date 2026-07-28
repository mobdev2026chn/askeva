import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/app_scope.dart';
import '../api/dto.dart';
import '../shell/app_nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import '../widgets/conversation_launch.dart';
import '../widgets/dashboard_sheets.dart' show showAppSheet, appToast;
import '../widgets/leads_extra.dart' show sheetScaffold, formLabel, formInput, formSelect, primaryButton;
import '../widgets/date_range_sheet.dart';



class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  Future<ContactsPage>? _contactsFuture;
  Future<UiContactsPage>? _uiContactsFuture;
  Future<List<UnsubscribedContactDto>>? _unsubFuture;
  int _tab = 0; // 0 Contacts, 1 UI-Contacts, 2 Opt-out

  // Shared interactive state.
  String _query = '';
  String _filter = 'All';
  String? _selectedSubFilter;
  bool _selectMode = false;
  final Set<String> _selected = {};
  final Map<String, String> _groupIds = {};
  final List<String> _groups = ['Test', 'test', 'test5', 'utility', 'vk', 'mukhil'];
  final Map<String, int> _groupCounts = {};
  List<String> _customAttributeKeys = [];

  bool _groupsLoaded = false;

  // UI-Contacts date filter state
  DateTime? _uiStartDate;
  DateTime? _uiEndDate;

  // Phone-number → contact name cache (populated when Contacts tab loads)
  final Map<String, String> _numberToName = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tab == 0 && _contactsFuture == null) _reloadContacts();
    if (_tab == 1 && _uiContactsFuture == null) _reloadUi();
    if (_tab == 2 && _unsubFuture == null) _reloadUnsub();

    if (!_groupsLoaded) {
      _groupsLoaded = true;
      AppScope.of(context).contacts.fetchGroups().then((g) {
        final names = <String>[];
        final ids = <String, String>{};
        final counts = <String, int>{};
        for (final m in g) {
          final name = (m['name'] ?? m['groupName'] ?? '').toString().trim();
          final id = (m['_id'] ?? m['id'] ?? '').toString();
          final count = (m['totalContacts'] ?? m['count'] ?? 0) as num;
          if (name.isNotEmpty) {
            names.add(name);
            if (id.isNotEmpty) ids[name] = id;
            counts[name] = count.toInt();
          }
        }
        if (mounted) {
          setState(() {
            _groups..clear()..addAll(names);
            _groupIds..clear()..addAll(ids);
            _groupCounts..clear()..addAll(counts);
          });
        }
      }).catchError((_) {});

      AppScope.of(context).agents.fetchUserAttributes().then((attrs) {
        final keys = attrs.map((e) => e['key'].toString()).toList();
        if (mounted) {
          setState(() {
            _customAttributeKeys = keys;
          });
        }
      }).catchError((_) {});
    }
  }

  void _reloadContacts() {
    final future = AppScope.of(context).contacts.fetchContacts(limit: 100);
    future.then((page) {
      if (!mounted) return;
      final lookup = <String, String>{};
      for (final c in page.contacts) {
        if (c.contactName.isNotEmpty && c.contactNumber.isNotEmpty) {
          lookup[c.contactNumber] = c.contactName;
          if (c.contactNumber.length > 10) {
            lookup[c.contactNumber.substring(c.contactNumber.length - 10)] = c.contactName;
          }
        }
      }
      setState(() {
        _numberToName
          ..clear()
          ..addAll(lookup);
      });
    }).catchError((_) {});
    setState(() {
      _contactsFuture = future;
    });
  }

  void _reloadUi({DateTime? startDate, DateTime? endDate}) {
    setState(() {
      _uiContactsFuture = AppScope.of(context).contacts.fetchUiContacts(
        limit: 200,
        search: _query.isNotEmpty ? _query : null,
        startDate: startDate ?? _uiStartDate,
        endDate: endDate ?? _uiEndDate,
      );
    });
  }

  void _reloadUnsub() {
    setState(() {
      _unsubFuture = AppScope.of(context).contacts.fetchUnsubscribedContacts();
    });
  }

  void _setTab(int i) {
    setState(() {
      _tab = i;
      _query = ''; // Reset query on tab swap
      if (i == 0 && _contactsFuture == null) _reloadContacts();
      if (i == 1 && _uiContactsFuture == null) _reloadUi();
      if (i == 2 && _unsubFuture == null) _reloadUnsub();
    });
  }

  @override
  Widget build(BuildContext context) {
    final nav = AppNav.of(context);
    return GreenHeaderScaffold(
      title: 'Contacts',
      onMenu: nav.openDrawer,
      sheet: Column(
        children: [
          AppTabBar(tabs: const ['Contacts', 'UI-Contacts', 'Opt-out'], selected: _tab, onChanged: _setTab),
          const Divider(height: 1, color: AppColors.line),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.evaGreen,
              onRefresh: () async {
                if (_tab == 0) _reloadContacts();
                if (_tab == 1) _reloadUi();
                if (_tab == 2) _reloadUnsub();
              },
              child: _buildTabContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        return AsyncView<ContactsPage>(
          future: _contactsFuture,
          onRetry: _reloadContacts,
          builder: _contactsTab,
        );
      case 1:
        return AsyncView<UiContactsPage>(
          future: _uiContactsFuture,
          onRetry: _reloadUi,
          builder: _uiContactsTab,
        );
      case 2:
      default:
        return AsyncView<List<UnsubscribedContactDto>>(
          future: _unsubFuture,
          onRetry: _reloadUnsub,
          builder: _optOutTab,
        );
    }
  }

  // ---------------- Contacts tab ----------------
  Widget _contactsTab(ContactsPage page) {
    final all = page.contacts;
    final q = _query.toLowerCase();
    final filtered = all.where((c) {
      final name = c.contactName.toLowerCase();
      final number = c.contactNumber.toLowerCase();

      String company = '';
      c.customAttributes.forEach((k, v) {
        final keyLower = k.toLowerCase();
        if (keyLower == 'company' || keyLower == 'businessname' || keyLower == 'business_name') {
          if (v != null) company = v.toString().toLowerCase();
        }
      });

      if (_filter == 'Groups') {
        if (c.groups.isEmpty) return false;
        if (_selectedSubFilter != null && !c.groups.contains(_selectedSubFilter)) return false;
        if (q.isNotEmpty && !c.groups.any((g) => g.toLowerCase().contains(q)) && !name.contains(q) && !number.contains(q)) return false;
        return true;
      }

      if (_filter == 'Tags') {
        if (c.tags.isEmpty) return false;
        if (_selectedSubFilter != null && !c.tags.contains(_selectedSubFilter)) return false;
        if (q.isNotEmpty && !c.tags.any((t) => t.toLowerCase().contains(q)) && !name.contains(q) && !number.contains(q)) return false;
        return true;
      }

      if (_filter == 'Number') {
        if (q.isNotEmpty && !number.contains(q)) return false;
        return true;
      }

      // Default: 'All'
      if (q.isEmpty) return true;
      if (name.contains(q)) return true;
      if (number.contains(q)) return true;
      if (c.groups.any((g) => g.toLowerCase().contains(q))) return true;
      if (c.tags.any((t) => t.toLowerCase().contains(q))) return true;
      if (company.isNotEmpty && company.contains(q)) return true;
      return false;
    }).toList();

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(16, 14, 16, _selectMode ? 92 : 24),
          children: [
            Row(children: [
              _filterDropdown(),
              const SizedBox(width: 10),
              Expanded(child: _searchField('Search...')),
            ]),
            if (_filter == 'Groups' && _groups.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _selectedSubFilter = null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _selectedSubFilter == null ? AppColors.evaGreen50 : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _selectedSubFilter == null ? AppColors.evaGreen : AppColors.line),
                        ),
                        child: Text('All Groups', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: _selectedSubFilter == null ? AppColors.evaGreenDeep : AppColors.ink3)),
                      ),
                    ),
                    for (final g in _groups) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _selectedSubFilter = g),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedSubFilter == g ? AppColors.evaGreen50 : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _selectedSubFilter == g ? AppColors.evaGreen : AppColors.line),
                          ),
                          child: Text(g, style: AppText.poppins(size: 12, weight: FontWeight.w700, color: _selectedSubFilter == g ? AppColors.evaGreenDeep : AppColors.ink3)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_filter == 'Tags') ...[
              Builder(
                builder: (context) {
                  final allTags = all.expand((c) => c.tags).toSet().toList();
                  return Column(
                    children: [
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 34,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _selectedSubFilter = null),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _selectedSubFilter == null ? AppColors.evaGreen50 : AppColors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _selectedSubFilter == null ? AppColors.evaGreen : AppColors.line),
                                ),
                                child: Text('All Tagged', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: _selectedSubFilter == null ? AppColors.evaGreenDeep : AppColors.ink3)),
                              ),
                            ),
                            for (final t in allTags) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(() => _selectedSubFilter = t),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _selectedSubFilter == t ? AppColors.evaGreen50 : AppColors.surface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: _selectedSubFilter == t ? AppColors.evaGreen : AppColors.line),
                                  ),
                                  child: Text('#$t', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: _selectedSubFilter == t ? AppColors.evaGreenDeep : AppColors.ink3)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _filledBtn(Icons.add_rounded, 'Add Contact', _addContact),
                const SizedBox(width: 10),
                _outlineBtn(Icons.group_outlined, 'Manage Groups', _manageGroups),
                const SizedBox(width: 10),
                _outlineBtn(Icons.download_rounded, 'Import', () => showContactImportWizard(context, groups: _groups, customAttributeKeys: _customAttributeKeys, onDone: () { _reloadContacts(); _snack('Contacts imported successfully'); })),
                const SizedBox(width: 10),
                _outlineBtn(Icons.file_upload_outlined, 'Export', () => _exportBulk(filtered)),
                const SizedBox(width: 10),
                _outlineBtn(Icons.description_outlined, 'Sample CSV', _downloadSampleCsv),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Text('${filtered.length} contacts', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
              const Spacer(),
              _selectPill(filtered),
            ]),
            const SizedBox(height: 12),
            for (final c in filtered) _apiCard(c),
          ],
        ),
        if (_selectMode) Positioned(left: 0, right: 0, bottom: 0, child: _bulkBar(filtered)),
      ],
    );
  }

  Widget _apiCard(ContactDto c) {
    final display = c.contactName.isEmpty ? c.contactNumber : c.contactName;
    final id = c.id;
    final selected = _selected.contains(id);

    // Extract company name if present in custom attributes
    String? company;
    c.customAttributes.forEach((k, v) {
      final keyLower = k.toLowerCase();
      if (keyLower == 'company' || keyLower == 'businessname' || keyLower == 'business_name') {
        if (v != null && v.toString().trim().isNotEmpty) {
          company = v.toString().trim();
        }
      }
    });

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: _selectMode 
            ? () => setState(() => selected ? _selected.remove(id) : _selected.add(id)) 
            : () => _editContact(c),
        onLongPress: _selectMode ? null : () => _showContactActions(c),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_selectMode) ...[Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 22, color: selected ? AppColors.evaGreen : AppColors.ink4), const SizedBox(width: 10)],
          InitialsAvatar(initials: _initials(display), color: AppColors.evaGreen, size: 46, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(display, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
              if (c.contactNumber.isNotEmpty) ...[const SizedBox(height: 3), Text(c.contactNumber, style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3))],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final g in c.groups) _Tag(g),
                  for (final t in c.tags) _Tag(t, hash: true),
                ],
              ),
              if (company != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Company: $company',
                  style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3),
                ),
              ],
            ]),
          ),
          if (!_selectMode) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showContactActions(c),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.evaGreen,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  void _showContactActions(ContactDto c) {
    final name = c.contactName.isEmpty ? c.contactNumber : c.contactName;
    showAppSheet(
      context,
      sheetScaffold(
        context,
        title: name,
        icon: Icons.person_rounded,
        body: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.ink2),
                title: Text('Edit', style: AppText.poppins(size: 14.5, weight: FontWeight.w700)),
                onTap: () {
                  Navigator.of(context).pop();
                  _editContact(c);
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_with_rounded, color: AppColors.ink2),
                title: Text('Move', style: AppText.poppins(size: 14.5, weight: FontWeight.w700)),
                onTap: () {
                  Navigator.of(context).pop();
                  _moveToGroup(c);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: AppColors.ink2),
                title: Text('Copy', style: AppText.poppins(size: 14.5, weight: FontWeight.w700)),
                onTap: () {
                  Navigator.of(context).pop();
                  _copyToGroup(c);
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_outlined, color: AppColors.ink2),
                title: Text('Export', style: AppText.poppins(size: 14.5, weight: FontWeight.w700)),
                onTap: () {
                  Navigator.of(context).pop();
                  _exportContactSingle(c);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                title: Text('Delete', style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: AppColors.danger)),
                onTap: () {
                  Navigator.of(context).pop();
                  _deleteContactConfirm(c);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportContactSingle(ContactDto c) async {
    final name = c.contactName.isEmpty ? c.contactNumber : c.contactName;
    _snack('Exporting contact $name...');
    try {
      final response = await AppScope.of(context).contacts.exportOneContact(c.id);
      final cleaned = Map<String, dynamic>.from(response);
      cleaned.remove('_id');
      cleaned.remove('countryCode');
      cleaned.remove('CA');
      cleaned.remove('phoneNumber');

      final keys = cleaned.keys.toList();
      final headers = keys.join(',');
      final values = keys.map((k) {
        final v = cleaned[k];
        if (v is List) return '"${v.join(' | ')}"';
        return '"${v.toString().replaceAll('"', '""')}"';
      }).join(',');
      final csvString = '$headers\n$values';

      final bytes = Uint8List.fromList(utf8.encode(csvString));
      final path = await FilePicker.platform.saveFile(
        fileName: '${cleaned['contactName'] ?? 'contact'}_export.csv',
        bytes: bytes,
      );
      if (path != null && mounted) {
        _snack('Exported successfully to $path');
      }
    } catch (e) {
      if (mounted) _snack('Failed to export: $e');
    }
  }

  Future<void> _exportBulk(List<ContactDto> contacts) async {
    if (contacts.isEmpty) {
      _snack('No contacts to export');
      return;
    }
    _snack('Preparing export for ${contacts.length} contacts...');
    try {
      final allKeys = <String>{};
      for (final c in contacts) {
        allKeys.addAll(c.customAttributes.keys);
      }
      final keysList = ['contactName', 'contactNumber', 'groups', 'tags', ...allKeys];
      final csvRows = <String>[];
      csvRows.add(keysList.join(','));
      for (final c in contacts) {
        final row = keysList.map((k) {
          dynamic val;
          if (k == 'contactName') val = c.contactName;
          else if (k == 'contactNumber') val = c.contactNumber;
          else if (k == 'groups') val = c.groups.join(' | ');
          else if (k == 'tags') val = c.tags.join(' | ');
          else val = c.customAttributes[k];
          return '"${(val ?? '').toString().replaceAll('"', '""')}"';
        }).join(',');
        csvRows.add(row);
      }
      final csvString = csvRows.join('\n');
      final bytes = Uint8List.fromList(utf8.encode(csvString));
      final path = await FilePicker.platform.saveFile(
        fileName: 'contacts_export.csv',
        bytes: bytes,
      );
      if (path != null && mounted) {
        _snack('Exported successfully to $path');
      }
    } catch (e) {
      if (mounted) _snack('Export failed: $e');
    }
  }

  void _downloadSampleCsv() async {
    const url = 'https://askeva.blr1.cdn.digitaloceanspaces.com/Samplecontact.csv';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _snack('Could not launch download URL');
    }
  }

  Future<void> _copyToGroup(ContactDto c) async {
    final g = await _showGroupSelectSheet(
      title: 'Add to group',
      actionLabel: 'Add',
      selectedCount: 1,
    );
    if (g != null && mounted) {
      final name = c.contactName.isEmpty ? c.contactNumber : c.contactName;
      _snack('Adding contact to $g...');
      final repo = AppScope.of(context).contacts;
      repo.copyContact(
        contactId: c.id,
        currentGroups: c.groups,
        targetGroup: g,
      ).then((_) {
        if (mounted) _snack('$name added to $g successfully');
        if (mounted) _reloadContacts();
      }).catchError((e) {
        if (mounted) _snack(e.toString());
      });
    }
  }

  void _deleteContactConfirm(ContactDto c) {
    final name = c.contactName.isEmpty ? c.contactNumber : c.contactName;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete contact?', style: AppText.poppins(size: 16.5, weight: FontWeight.w800, color: AppColors.ink)),
        content: Text('“$name” will be permanently removed.', style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink3)),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppColors.surface2,
                    foregroundColor: AppColors.ink,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Cancel', style: AppText.poppins(size: 13.5, weight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _snack('Deleting contact...');
                    AppScope.of(context).contacts.deleteContact(c.id).then((_) {
                      if (mounted) {
                        _snack('$name deleted successfully');
                        _reloadContacts();
                      }
                    }).catchError((e) {
                      if (mounted) _snack('Failed to delete: $e');
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Delete', style: AppText.poppins(size: 13.5, weight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  void _bulkDeleteConfirm(List<ContactDto> contactsList) {
    final selectedContacts = contactsList.where((c) => _selected.contains(c.id)).toList();
    final count = selectedContacts.isNotEmpty ? selectedContacts.length : _selected.length;
    if (count == 0) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete $count contacts?', style: AppText.poppins(size: 16.5, weight: FontWeight.w800, color: AppColors.ink)),
        content: Text('$count selected contact${count > 1 ? 's' : ''} will be permanently removed.', style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink3)),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppColors.surface2,
                    foregroundColor: AppColors.ink,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Cancel', style: AppText.poppins(size: 13.5, weight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    _snack('Deleting $count contacts...');
                    final repo = AppScope.of(context).contacts;
                    final idsToDelete = _selected.toList();
                    int deletedCount = 0;
                    for (final id in idsToDelete) {
                      try {
                        await repo.deleteContact(id);
                        deletedCount++;
                      } catch (e) {
                        debugPrint('[Contacts] Error deleting contact $id: $e');
                      }
                    }
                    if (mounted) {
                      setState(() {
                        _selectMode = false;
                        _selected.clear();
                      });
                      _snack('$deletedCount contacts deleted successfully');
                      _reloadContacts();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Delete', style: AppText.poppins(size: 13.5, weight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _exportBulkSelected(List<ContactDto> contactsList) {
    final selectedContacts = contactsList.where((c) => _selected.contains(c.id)).toList();
    if (selectedContacts.isNotEmpty) {
      _exportBulk(selectedContacts);
    } else {
      _snack('No contacts selected');
    }
  }

  Widget _bulkBar([List<ContactDto> contactsList = const []]) {
    final enabled = _selected.isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              '${_selected.length} selected',
              style: AppText.poppins(size: 12, weight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Material(
                color: enabled ? AppColors.evaGreen : AppColors.evaGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: enabled ? _showAddToGroupSheet : null,
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.group_add_outlined, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Add to Group',
                          style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _iconRoundBtn(
              icon: Icons.publish_rounded,
              color: Colors.white,
              bg: const Color(0xFF3A3A40),
              size: 34,
              onTap: enabled ? () => _exportBulkSelected(contactsList) : null,
            ),
            const SizedBox(width: 6),
            _iconRoundBtn(
              icon: Icons.delete_outline_rounded,
              color: Colors.white,
              bg: enabled ? const Color(0xFFEF5350) : const Color(0xFFEF5350).withValues(alpha: 0.3),
              size: 34,
              onTap: enabled ? () => _bulkDeleteConfirm(contactsList) : null,
            ),
            const SizedBox(width: 6),
            _iconRoundBtn(
              icon: Icons.close_rounded,
              color: Colors.white,
              bg: const Color(0xFF3A3A40),
              size: 34,
              onTap: () {
                setState(() {
                  _selectMode = false;
                  _selected.clear();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconRoundBtn({
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback? onTap,
    double size = 34,
  }) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  // ---------------- UI-Contacts tab ----------------
  Widget _uiContactsTab(UiContactsPage page) {
    final q = _query.toLowerCase();
    final contacts = page.contacts.where((c) {
      final display = c.profileName.isNotEmpty ? c.profileName : c.contactNumber;
      if (q.isEmpty) return true;
      if (display.toLowerCase().contains(q)) return true;
      if (c.contactNumber.contains(q)) return true;
      if (c.lastMessage.toLowerCase().contains(q)) return true;
      if (c.tags.any((t) => t.toLowerCase().contains(q))) return true;
      return false;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _searchField('Search tag / name / number'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => _pickUiDateRange(),
            child: _dateRangePill(),
          )),
          const SizedBox(width: 10),
          _filledBtn(Icons.file_upload_outlined, 'Export', () => _snack('Exported ${contacts.length} contacts')),
        ]),
        const SizedBox(height: 14),
        Text.rich(TextSpan(style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3), children: [
          TextSpan(text: '${page.total}      ', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink)),
          const TextSpan(text: 'contacts · user-initiated      '),
          TextSpan(text: '· auto-synced to Leads', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
        ])),
        const SizedBox(height: 12),
        for (var i = 0; i < contacts.length; i++) ...[
          Builder(
            builder: (context) {
              final c = contacts[i];
              final display = c.profileName.isNotEmpty ? c.profileName : (c.contactNumber.isNotEmpty ? c.contactNumber : 'Unknown');
              final sno = i + 1;
              final formattedTime = c.lastMessageTime != null ? _stamp(c.lastMessageTime) : (c.rawTimeStr.isNotEmpty ? c.rawTimeStr : 'N/A');

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => openConversationByNumber(context, name: display, number: c.contactNumber),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: S.No badge + Avatar + Name + Mobile Number
                      Row(
                        children: [
                          // Simple minimal S.No.
                          Text(
                            '#$sno',
                            style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink4),
                          ),
                          const SizedBox(width: 8),
                          InitialsAvatar(initials: _initials(display), color: AppColors.evaGreen, size: 38, radius: 19),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  display,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink),
                                ),
                                if (c.contactNumber.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_outlined, size: 12, color: AppColors.evaGreenDeep),
                                      const SizedBox(width: 4),
                                      Text(
                                        c.contactNumber,
                                        style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.ink4),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.line),
                      const SizedBox(height: 10),

                      // Last Message Time Column
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 13, color: AppColors.ink3),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Last Message Time:',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: Text(
                              formattedTime.isNotEmpty ? formattedTime : 'N/A',
                              style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Last Message Column
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: AppColors.ink3),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Last Message:',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: Text(
                              c.lastMessage.isNotEmpty ? c.lastMessage : '—',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Tags Column
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Row(
                              children: [
                                const Icon(Icons.local_offer_outlined, size: 13, color: AppColors.ink3),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Tags:',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ...c.tags.map((t) => GestureDetector(
                                  onTap: () => _deleteUiTag(c, t),
                                  child: _Tag(t, hash: true),
                                )),
                                GestureDetector(onTap: () => _addUiTag(c), child: _addTagChip()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Future<void> _pickUiDateRange() async {
    final now = DateTime.now();
    final range = await showAppDateRangePicker(
      context,
      initialRange: (_uiStartDate != null && _uiEndDate != null)
          ? DateTimeRange(start: _uiStartDate!, end: _uiEndDate!)
          : null,
      firstDate: DateTime(2023),
      lastDate: now,
    );
    if (range != null && mounted) {
      setState(() {
        _uiStartDate = range.start;
        _uiEndDate = range.end;
      });
      _reloadUi(startDate: range.start, endDate: range.end);
    }
  }

  // ---------------- Opt-out tab ----------------
  int _optSub = 0;
  // Bulk-unblock state (Blocked sub-tab)
  bool _blockSelectMode = false;
  final Set<String> _blockSelected = {};
  Widget _optOutTab(List<UnsubscribedContactDto> allUnsubscribed) {
    final list = _optSub == 0
        ? allUnsubscribed.where((c) => c.unsubscribed && !c.isBlocked).toList()
        : allUnsubscribed.where((c) => c.isBlocked).toList();
    final isBlocked = _optSub == 1;

    return Column(
      children: [
        // ── Sub-tab row ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            _subTab('Unsubscribed', 0),
            const SizedBox(width: 22),
            _subTab('Blocked', 1),
            const Spacer(),
            if (isBlocked)
              _outlineBtn(Icons.upload_file_outlined, 'Upload CSV', _uploadBlockedCsv),
          ]),
        ),

        // ── Bulk Unblock button (only in Blocked sub-tab) ────────────
        if (isBlocked)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: _blockSelected.isEmpty
                    ? null
                    : _doBulkUnblock,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _blockSelected.isEmpty
                        ? AppColors.surface
                        : AppColors.evaGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _blockSelected.isEmpty
                          ? AppColors.line
                          : AppColors.evaGreen,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    'Bulk Unblock (${_blockSelected.length})',
                    style: AppText.poppins(
                      size: 13,
                      weight: FontWeight.w700,
                      color: _blockSelected.isEmpty
                          ? AppColors.ink2
                          : AppColors.evaGreenDeep,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // ── Count + Select-all / Cancel row ─────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Text(
              '${list.length} ${isBlocked ? 'blocked' : 'unsubscribed'}',
              style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2),
            ),
            if (isBlocked && _blockSelectMode) ...[
              const SizedBox(width: 8),
              Text(
                '${_blockSelected.length} selected',
                style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.evaGreenDeep),
              ),
            ],
            const Spacer(),
            if (isBlocked && list.isNotEmpty) ...[
              if (_blockSelectMode) ...[
                // Select all / Deselect all
                GestureDetector(
                  onTap: () => setState(() {
                    if (_blockSelected.length == list.length) {
                      _blockSelected.clear();
                    } else {
                      _blockSelected
                        ..clear()
                        ..addAll(list.map((c) => c.contactNumber));
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.evaGreen, width: 1.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _blockSelected.length == list.length && list.isNotEmpty
                          ? 'Deselect all'
                          : 'Select all',
                      style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.evaGreenDeep),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Cancel
                GestureDetector(
                  onTap: () => setState(() {
                    _blockSelectMode = false;
                    _blockSelected.clear();
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.line, width: 1.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.close, size: 14, color: AppColors.ink2),
                      const SizedBox(width: 4),
                      Text('Cancel', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink2)),
                    ]),
                  ),
                ),
              ] else ...[
                // Select
                GestureDetector(
                  onTap: () => setState(() {
                    _blockSelectMode = true;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.line, width: 1.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_rounded, size: 14, color: AppColors.ink2),
                      const SizedBox(width: 4),
                      Text('Select', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink2)),
                    ]),
                  ),
                ),
              ],
            ],
          ]),
        ),

        // ── List ─────────────────────────────────────────────────────
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.forum_outlined, size: 44, color: AppColors.ink4),
                    const SizedBox(height: 14),
                    Text(isBlocked ? 'No blocked contacts' : 'No unsubscribed contacts',
                        style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Text(
                        isBlocked
                            ? 'Contacts you block appear here and cannot message you.'
                            : 'Contacts who opt out of messages appear here and are skipped by Compose.',
                        textAlign: TextAlign.center,
                        style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink3, height: 1.5),
                      ),
                    ),
                  ]),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    for (final c in list) _unsubCard(c, list),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _unsubCard(UnsubscribedContactDto c, [List<UnsubscribedContactDto>? list]) {
    final hasName = c.profileName.isNotEmpty;
    // Prefer backend profileName → fallback to contacts-list name → fallback to number
    final resolvedName = hasName
        ? c.profileName
        : (_numberToName[c.contactNumber] ??
           (c.contactNumber.length > 10
               ? _numberToName[c.contactNumber.substring(c.contactNumber.length - 10)]
               : null) ??
           c.contactNumber);
    final hasResolvedName = resolvedName != c.contactNumber;
    final avatarLabel = hasResolvedName
        ? _initials(resolvedName)
        : (c.contactNumber.length >= 2 ? c.contactNumber.substring(0, 2) : c.contactNumber);

    final isBlocked = _optSub == 1;
    final isSelected = _blockSelected.contains(c.contactNumber);

    return GestureDetector(
      onTap: isBlocked
          ? () => setState(() {
                _blockSelectMode = true;
                if (isSelected) {
                  _blockSelected.remove(c.contactNumber);
                } else {
                  _blockSelected.add(c.contactNumber);
                }
              })
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.evaGreen.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.evaGreen : AppColors.line,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          // Checkbox (only in Blocked sub-tab when select mode is active)
          if (isBlocked && _blockSelectMode) ...[
            GestureDetector(
              onTap: () => setState(() {
                _blockSelectMode = true;
                if (isSelected) {
                  _blockSelected.remove(c.contactNumber);
                } else {
                  _blockSelected.add(c.contactNumber);
                }
              }),
              child: Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.evaGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? AppColors.evaGreen : AppColors.ink4,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          ],
          InitialsAvatar(initials: avatarLabel, color: avatarColorFor(resolvedName), size: 44, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resolvedName,
                  style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasResolvedName && c.contactNumber.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(c.contactNumber, style: AppText.poppins(size: 11.5, color: AppColors.ink3)),
                  ),
                if (c.lastMessageTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(_stamp(c.lastMessageTime), style: AppText.poppins(size: 11, weight: FontWeight.w500, color: AppColors.ink4)),
                  ),
              ],
            ),
          ),
          if (isBlocked)
            TextButton(
              onPressed: () => _unblock(c.contactNumber),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.evaGreen.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: AppColors.evaGreen, width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Unblock', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
            ),
        ]),
      ),
    );
  }

  Widget _subTab(String label, int i) {
    final active = _optSub == i;
    return GestureDetector(
      onTap: () => setState(() {
        _optSub = i;
        _blockSelected.clear();
        _blockSelectMode = false;
      }),
      behavior: HitTestBehavior.opaque,
      child: Column(children: [
        Text(label, style: AppText.poppins(size: 14, weight: active ? FontWeight.w800 : FontWeight.w600, color: active ? AppColors.evaGreenDeep : AppColors.ink3)),
        const SizedBox(height: 6),
        Container(height: 2.5, width: 28, color: active ? AppColors.evaGreen : Colors.transparent),
      ]),
    );
  }

  // ---------------- actions ----------------
  void _snack(String m) => appToast(context, m);

  void _addContact() {
    showAppSheet(
      context,
      _ContactForm(
        groups: _groups,
        customAttributeKeys: _customAttributeKeys,
        onSave: (data) {
          final reqBody = <String, dynamic>{
            'countryCode': data['countryCode'],
            'phoneNumber': data['mobile'],
            'contactNumber': '${data['countryCode']}${data['mobile']}',
            'contactName': data['name'],
            'groups': data['groups'],
            'tags': data['tags'],
            ...Map<String, dynamic>.from(data['customAttributes'] ?? const {}),
          };
          AppScope.of(context).contacts.createContact(reqBody).then((_) {
            _reloadContacts();
            _snack('Contact created successfully');
          }).catchError((e) {
            _snack('Failed to create contact: $e');
          });
        },
      ),
    );
  }

  void _editContact(ContactDto c) {
    showAppSheet(
      context,
      _ContactForm(
        groups: _groups,
        customAttributeKeys: _customAttributeKeys,
        existing: c,
        onSave: (data) {
          final reqBody = <String, dynamic>{
            'countryCode': data['countryCode'],
            'phoneNumber': data['mobile'],
            'contactNumber': '${data['countryCode']}${data['mobile']}',
            'contactName': data['name'],
            'groups': data['groups'],
            'tags': data['tags'],
            ...Map<String, dynamic>.from(data['customAttributes'] ?? const {}),
          };
          AppScope.of(context).contacts.updateContact(c.id, {
            'contact': reqBody,
          }).then((_) {
            _reloadContacts();
            _snack('Contact updated successfully');
          }).catchError((e) {
            _snack('Failed to update contact: $e');
          });
        },
      ),
    );
  }

  void _manageGroups() {
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSheet) {
          final q = searchCtrl.text.toLowerCase().trim();
          final filteredGroups = _groups.where((g) => g.toLowerCase().contains(q)).toList();
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: EdgeInsets.fromLTRB(20, 20, 20, 28 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.group_outlined, size: 22, color: AppColors.ink),
                    const SizedBox(width: 8),
                    Text('Manage Groups', style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.ink)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.ink4),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchCtrl,
                        onChanged: (_) => setStateSheet(() {}),
                        style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
                        decoration: InputDecoration(
                          hintText: 'Search group...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.ink4),
                          suffixIcon: searchCtrl.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    searchCtrl.clear();
                                    setStateSheet(() {});
                                  },
                                  child: const Icon(Icons.clear_rounded, size: 16, color: AppColors.ink4),
                                )
                              : null,
                          filled: true,
                          fillColor: AppColors.surface2,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () async {
                        final contactsRepo = AppScope.of(context).contacts;
                        final name = await _prompt('Group name');
                        if (name == null || name.trim().isEmpty) return;
                        final g = name.trim();
                        if (!mounted) return;
                        setState(() {
                          _groups.add(g);
                          _groupCounts[g] = 0;
                        });
                        setStateSheet(() {});
                        contactsRepo.createGroup(g).then((_) {
                          contactsRepo.fetchGroups().then((groupsList) {
                            for (final m in groupsList) {
                              final gn = (m['name'] ?? m['groupName'] ?? '').toString();
                              final gi = (m['_id'] ?? m['id'] ?? '').toString();
                              if (gn == g && gi.isNotEmpty) {
                                if (mounted) _groupIds[g] = gi;
                              }
                            }
                          }).catchError((_) {});
                        }).catchError((_) {});
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.evaGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                      label: Text('New', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                  child: filteredGroups.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('No groups found', style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink4)),
                          ),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final g in filteredGroups) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            g,
                                            style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${_groupCounts[g] ?? 0} ${(_groupCounts[g] ?? 0) == 1 ? 'contact' : 'contacts'}',
                                            style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.ink3),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _iconActionBtn(Icons.edit_outlined, AppColors.ink2, () async {
                                      final oldName = g;
                                      final id = _groupIds[oldName];
                                      final repoRef = AppScope.of(context).contacts;
                                      final name = await _prompt('Rename group', initialText: oldName);
                                      if (name == null || name.trim().isEmpty || name.trim() == oldName) return;
                                      final newName = name.trim();
                                      if (!mounted) return;
                                      final idx = _groups.indexOf(oldName);
                                      setState(() {
                                        if (idx != -1) _groups[idx] = newName;
                                        final count = _groupCounts.remove(oldName) ?? 0;
                                        _groupCounts[newName] = count;
                                        if (id != null) {
                                          _groupIds.remove(oldName);
                                          _groupIds[newName] = id;
                                        }
                                      });
                                      setStateSheet(() {});
                                      if (id != null) {
                                        repoRef.client.patch('/contacts/groups/$id', body: {'name': newName}).catchError((_) {});
                                      }
                                    }),
                                    const SizedBox(width: 8),
                                    _iconActionBtn(Icons.delete_outline_rounded, AppColors.danger, () {
                                      final id = _groupIds[g];
                                      setState(() {
                                        _groups.remove(g);
                                        _groupCounts.remove(g);
                                        _groupIds.remove(g);
                                      });
                                      setStateSheet(() {});
                                      if (id != null) {
                                        AppScope.of(context).contacts.deleteGroup(id).catchError((_) {});
                                      }
                                    }),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: AppColors.line),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _iconActionBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.line),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      );

  Future<String?> _showGroupSelectSheet({
    required String title,
    required String actionLabel,
    required int selectedCount,
  }) async {
    String? localSelectedGroup;
    final List<String> localGroups = List<String>.from(_groups);
    final searchCtrl = TextEditingController();

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final q = searchCtrl.text.toLowerCase().trim();
          final filteredGroups = localGroups.where((g) => g.toLowerCase().contains(q)).toList();

          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.evaGreen50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.people_alt_outlined, color: AppColors.evaGreenDeep, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
                          Text(
                            '$selectedCount contact${selectedCount > 1 ? 's' : ''} selected',
                            style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.ink3),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface2,
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Search Bar + New Group Button
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchCtrl,
                        onChanged: (_) => setSt(() {}),
                        style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
                        decoration: InputDecoration(
                          hintText: 'Search group name...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.ink4),
                          suffixIcon: searchCtrl.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    searchCtrl.clear();
                                    setSt(() {});
                                  },
                                  child: const Icon(Icons.clear_rounded, size: 16, color: AppColors.ink4),
                                )
                              : null,
                          filled: true,
                          fillColor: AppColors.surface2,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () async {
                        final repo = AppScope.of(context).contacts;
                        final name = await _prompt('New group name');
                        if (name != null && name.trim().isNotEmpty) {
                          final trimmed = name.trim();
                          setSt(() {
                            if (!localGroups.contains(trimmed)) {
                              localGroups.add(trimmed);
                            }
                            localSelectedGroup = trimmed;
                          });
                          if (mounted) {
                            setState(() {
                              _groups.add(trimmed);
                              _groupCounts[trimmed] = 0;
                            });
                          }
                          repo.createGroup(trimmed).catchError((_) {});
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.evaGreen50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.evaGreen200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_rounded, size: 16, color: AppColors.evaGreenDeep),
                            const SizedBox(width: 4),
                            Text('New', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Searchable Dropdown List
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.4),
                  child: filteredGroups.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('No groups found', style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink4)),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: filteredGroups.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final g = filteredGroups[i];
                            final isSelected = localSelectedGroup == g;
                            final count = _groupCounts[g] ?? 0;
                            return GestureDetector(
                              onTap: () => setSt(() => localSelectedGroup = g),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.evaGreen50 : AppColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? AppColors.evaGreen : AppColors.line,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected ? Icons.folder_rounded : Icons.folder_outlined,
                                      size: 20,
                                      color: isSelected ? AppColors.evaGreenDeep : AppColors.ink3,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            g,
                                            style: AppText.poppins(
                                              size: 14,
                                              weight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                              color: isSelected ? AppColors.evaGreenDeep : AppColors.ink,
                                            ),
                                          ),
                                          Text(
                                            '$count contact${count == 1 ? '' : 's'}',
                                            style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink4),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                      size: 20,
                                      color: isSelected ? AppColors.evaGreen : AppColors.ink4,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.surface2,
                          side: const BorderSide(color: AppColors.line),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Cancel', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink2)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: localSelectedGroup == null ? null : () => Navigator.of(ctx).pop(localSelectedGroup),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.evaGreen,
                          disabledBackgroundColor: AppColors.evaGreen.withValues(alpha: 0.4),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(actionLabel, style: AppText.poppins(size: 14, weight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddToGroupSheet() {
    _showGroupSelectSheet(
      title: 'Add to group',
      actionLabel: 'Add',
      selectedCount: _selected.length,
    ).then((g) {
      if (g != null && mounted) {
        final selectedIds = _selected.toList();
        setState(() {
          _groupCounts[g] = (_groupCounts[g] ?? 0) + selectedIds.length;
          _selectMode = false;
          _selected.clear();
        });
        _snack('Adding contacts to $g...');
        AppScope.of(context).contacts.addToGroup(
          contactIds: selectedIds,
          groupName: g,
        ).then((_) {
          if (mounted) _snack('Added contacts to $g successfully');
          if (mounted) _reloadContacts();
        }).catchError((e) {
          if (mounted) _snack(e.toString());
        });
      }
    });
  }

  Future<void> _moveToGroup(ContactDto c) async {
    final g = await _showGroupSelectSheet(
      title: 'Move to group',
      actionLabel: 'Move',
      selectedCount: 1,
    );
    if (g != null && mounted) {
      final name = c.contactName.isEmpty ? c.contactNumber : c.contactName;
      _snack('Moving contact to $g...');
      final repo = AppScope.of(context).contacts;
      repo.addToGroup(
        contactIds: [c.id],
        groupName: g,
      ).then((_) {
        if (mounted) _snack('$name moved to $g successfully');
        if (mounted) _reloadContacts();
      }).catchError((e) {
        if (mounted) _snack(e.toString());
      });
    }
  }

  Future<void> _addUiTag(UiContactDto c) async {
    final t = await _prompt('Add tag');
    if (t == null || t.trim().isEmpty) return;
    if (!mounted) return;
    try {
      await AppScope.of(context).contacts.addUiTag(c.contactNumber, t.trim());
      if (!mounted) return;
      _snack('Tag #${t.trim()} added successfully');
      _reloadUi();
    } catch (e) {
      if (mounted) _snack(e.toString());
    }
  }

  Future<void> _deleteUiTag(UiContactDto c, String tag) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete tag'),
        content: Text('Are you sure you want to remove tag "#$tag" from ${c.profileName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    try {
      await AppScope.of(context).contacts.deleteUiTag(c.contactNumber, tag);
      if (!mounted) return;
      _snack('Tag #$tag removed successfully');
      _reloadUi();
    } catch (e) {
      if (mounted) _snack(e.toString());
    }
  }

  Future<void> _unblock(String number) async {
    try {
      await AppScope.of(context).chat.blockUser(number, block: false);
      setState(() {
        _blockSelected.remove(number);
        if (_blockSelected.isEmpty) _blockSelectMode = false;
      });
      _snack('User unblocked successfully');
      _reloadUnsub();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _doBulkUnblock() async {
    if (_blockSelected.isEmpty) return;
    final numbers = _blockSelected.toList();
    int success = 0;
    for (final number in numbers) {
      try {
        await AppScope.of(context).chat.blockUser(number, block: false);
        success++;
      } catch (_) {}
    }
    setState(() {
      _blockSelected.clear();
      _blockSelectMode = false;
    });
    _snack('$success contact${success == 1 ? '' : 's'} unblocked successfully');
    _reloadUnsub();
  }

  Future<void> _uploadBlockedCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) { _snack('Could not read file'); return; }

    // Parse CSV: skip header row, extract columns [countryCode, mobile]
    final csvText = String.fromCharCodes(bytes);
    final lines = csvText.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) { _snack('CSV file is empty or has no data rows'); return; }

    final contacts = <Map<String, String>>[];
    for (final line in lines.skip(1)) {
      final cols = line.split(',');
      final countryCode = (cols.isNotEmpty ? cols[0].trim() : '').replaceAll('"', '');
      final mobile = (cols.length > 1 ? cols[1].trim() : '').replaceAll('"', '');
      if (mobile.isNotEmpty) {
        contacts.add({'countryCode': countryCode.isEmpty ? '91' : countryCode, 'mobile': mobile});
      }
    }

    if (contacts.isEmpty) { _snack('No valid contacts found in CSV'); return; }

    _snack('Blocking ${contacts.length} contacts...');
    try {
      if (!mounted) return;
      await AppScope.of(context).chat.bulkBlock(contacts);
      if (!mounted) return;
      _snack('${contacts.length} contacts blocked successfully');
      _reloadUnsub();
    } catch (e) {
      if (!mounted) return;
      _snack('Bulk block failed: $e');
    }
  }

  Future<String?> _prompt(String title, {String? initialText}) {
    final c = TextEditingController(text: initialText);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.of(ctx).pop(c.text), child: const Text('Save'))],
      ),
    );
  }

  // ---------------- shared widgets ----------------
  Widget _filterDropdown() => PopupMenuButton<String>(
        onSelected: (v) => setState(() {
          _filter = v;
          _selectedSubFilter = null;
        }),
        position: PopupMenuPosition.under,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'All', child: Text('All')),
          PopupMenuItem(value: 'Groups', child: Text('Groups')),
          PopupMenuItem(value: 'Tags', child: Text('Tags')),
          PopupMenuItem(value: 'Number', child: Text('Number')),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Text(_filter, style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink)), const SizedBox(width: 4), const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.ink3)]),
        ),
      );

  Widget _searchField(String hint) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.line)),
        child: Row(children: [
          const Icon(Icons.search_rounded, size: 18, color: AppColors.ink4),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
              decoration: InputDecoration(isDense: true, border: InputBorder.none, hintText: hint, hintStyle: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink4)),
            ),
          ),
        ]),
      );

  Widget _filledBtn(IconData icon, String label, VoidCallback onTap) => Material(
        color: AppColors.evaGreen,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(borderRadius: BorderRadius.circular(24), onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 17, color: Colors.white), const SizedBox(width: 7), Text(label, style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: Colors.white))]))),
      );

  Widget _outlineBtn(IconData icon, String label, VoidCallback onTap) => Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(borderRadius: BorderRadius.circular(24), onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.line)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 17, color: AppColors.ink2), const SizedBox(width: 7), Text(label, style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink))]))),
      );

  Widget _selectPill(List<ContactDto> filtered) {
    if (_selectMode) {
      final allSelected = _selected.length == filtered.length;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                if (allSelected) {
                  _selected.clear();
                } else {
                  _selected.clear();
                  _selected.addAll(filtered.map((e) => e.id));
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.line)),
              child: Text(allSelected ? 'Deselect all' : 'Select all', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() { _selectMode = false; _selected.clear(); }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.line)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.close_rounded, size: 15, color: AppColors.ink3),
                const SizedBox(width: 5),
                Text('Cancel', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
              ]),
            ),
          ),
        ],
      );
    } else {
      return GestureDetector(
        onTap: () => setState(() => _selectMode = true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_rounded, size: 15, color: AppColors.ink3),
            const SizedBox(width: 5),
            Text('Select', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
          ]),
        ),
      );
    }
  }

  Widget _dateRangePill() {
    final hasFilter = _uiStartDate != null && _uiEndDate != null;
    String label;
    if (hasFilter) {
      String fmt(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
      label = '${fmt(_uiStartDate!)} → ${fmt(_uiEndDate!)}';
    } else {
      label = 'Start date → End date';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.evaGreen50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.evaGreen200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.evaGreenDeep),
            ),
          ),
          if (hasFilter) ...[
            GestureDetector(
              onTap: () {
                setState(() { _uiStartDate = null; _uiEndDate = null; });
                _reloadUi();
              },
              child: const Icon(Icons.close_rounded, size: 14, color: AppColors.evaGreenDeep),
            ),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.evaGreenDeep),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add / Edit contact form
// ---------------------------------------------------------------------------

class _ContactForm extends StatefulWidget {
  final List<String> groups;
  final List<String> customAttributeKeys;
  final ContactDto? existing;
  final void Function(Map<String, dynamic> data) onSave;
  const _ContactForm({
    required this.groups,
    required this.customAttributeKeys,
    this.existing,
    required this.onSave,
  });

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  late final _name = TextEditingController(text: widget.existing?.contactName ?? '');
  late final _mobile = TextEditingController(text: widget.existing?.contactNumber ?? '');
  
  List<CountryDto> _countries = [];
  bool _initializedCC = false;
  String _countryCode = '91';

  late final List<String> _formGroups = List<String>.from(widget.groups);
  late final Set<String> _selectedGroups = Set<String>.from(
    widget.existing?.groups.isNotEmpty == true
        ? widget.existing!.groups
        : (widget.groups.isNotEmpty ? [widget.groups.first] : <String>[]),
  );

  late final List<String> _allTags = {
    'premium', 'Vbc', 'test', 'vip',
    ...?widget.existing?.tags,
  }.toList();
  late final Set<String> _selectedTags = Set<String>.from(widget.existing?.tags ?? []);

  final Map<String, TextEditingController> _attrControllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize custom attributes controllers from the backend schema ONLY
    for (final k in widget.customAttributeKeys) {
      dynamic val;
      if (widget.existing != null) {
        val = widget.existing!.customAttributes[k] ?? widget.existing!.customAttributes[k.toLowerCase()];
      }
      _attrControllers[k] = TextEditingController(text: val?.toString() ?? '');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_countries.isEmpty) {
      AppScope.of(context).compose.fetchCountries().then((c) {
        if (mounted) {
          setState(() => _countries = c);
          _initCountryAndMobile();
        }
      }).catchError((_) {});
    } else {
      _initCountryAndMobile();
    }
  }

  void _initCountryAndMobile() {
    if (_initializedCC || _countries.isEmpty) return;
    _initializedCC = true;
    String mobile = widget.existing?.contactNumber ?? '';
    for (final c in _countries) {
      if (mobile.startsWith(c.dialCode) && mobile.length > c.dialCode.length) {
        setState(() {
          _countryCode = c.dialCode;
          _mobile.text = mobile.substring(c.dialCode.length);
        });
        break;
      }
    }
  }

  final _groupFilterController = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _groupFilterController.dispose();
    for (final c in _attrControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<String?> _promptDialog(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: const Text('Add')),
        ],
      ),
    );
  }

  Future<void> _addNewGroup() async {
    final name = await _promptDialog('New Group', 'Enter group name');
    if (name != null && name.trim().isNotEmpty) {
      final trimmed = name.trim();
      setState(() {
        if (!_formGroups.contains(trimmed)) {
          _formGroups.add(trimmed);
        }
        _selectedGroups.add(trimmed);
      });
    }
  }

  Future<void> _addNewTag() async {
    final name = await _promptDialog('New Tag', 'Enter tag name');
    if (name != null && name.trim().isNotEmpty) {
      final trimmed = name.trim();
      setState(() {
        if (!_allTags.contains(trimmed)) {
          _allTags.add(trimmed);
        }
        _selectedTags.add(trimmed);
      });
    }
  }

  Widget _groupDropdownPicker() {
    final selectedList = _selectedGroups.toList();
    final label = selectedList.isEmpty
        ? 'Select group(s)...'
        : (selectedList.length == 1 ? selectedList.first : '${selectedList.first} (+${selectedList.length - 1} more)');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _showGroupDropdownSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selectedList.isNotEmpty ? AppColors.evaGreen : AppColors.line),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.people_alt_outlined,
                  size: 18,
                  color: selectedList.isNotEmpty ? AppColors.evaGreenDeep : AppColors.ink4,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(
                      size: 13.5,
                      weight: selectedList.isNotEmpty ? FontWeight.w700 : FontWeight.w500,
                      color: selectedList.isNotEmpty ? AppColors.ink : AppColors.ink4,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.ink3),
              ],
            ),
          ),
        ),
        if (selectedList.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final g in selectedList)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.evaGreen50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.evaGreen200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(g, style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() => _selectedGroups.remove(g)),
                        child: const Icon(Icons.close_rounded, size: 14, color: AppColors.evaGreenDeep),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _showGroupDropdownSheet() {
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final q = searchCtrl.text.toLowerCase().trim();
          final filtered = _formGroups.where((g) => g.toLowerCase().contains(q)).toList();
          final viewInsets = MediaQuery.of(ctx).viewInsets.bottom;
          final maxListHeight = ((MediaQuery.of(ctx).size.height - viewInsets - 180) * 0.4).clamp(100.0, 260.0);

          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: EdgeInsets.fromLTRB(20, 20, 20, viewInsets + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Select Groups', style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchCtrl,
                    onChanged: (_) => setSt(() {}),
                    style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: 'Search groups...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.ink4),
                      filled: true,
                      fillColor: AppColors.surface2,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxListHeight),
                    child: filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text('No matching groups', style: AppText.poppins(size: 13, color: AppColors.ink4)),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 4),
                            itemBuilder: (ctx, i) {
                              final g = filtered[i];
                              final isSel = _selectedGroups.contains(g);
                              return Material(
                                color: isSel ? AppColors.evaGreen50 : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  leading: Icon(
                                    isSel ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                    color: isSel ? AppColors.evaGreen : AppColors.ink4,
                                    size: 22,
                                  ),
                                  title: Text(
                                    g,
                                    style: AppText.poppins(
                                      size: 14,
                                      weight: isSel ? FontWeight.w800 : FontWeight.w600,
                                      color: isSel ? AppColors.evaGreenDeep : AppColors.ink,
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      if (_selectedGroups.contains(g)) {
                                        _selectedGroups.remove(g);
                                      } else {
                                        _selectedGroups.add(g);
                                      }
                                    });
                                    setSt(() {});
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _addNewGroup();
                          setSt(() {});
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.evaGreen),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.evaGreenDeep),
                        label: Text('New Group', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.evaGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text('Done', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _ccPicker() {
    return GestureDetector(
      onTap: _pickCountry,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _ccLabel(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }

  String _ccLabel() {
    if (_countryCode.isEmpty) return 'Select';
    final c = _countries.where((c) => c.dialCode == _countryCode);
    return c.isEmpty ? '+$_countryCode' : '+$_countryCode ${c.first.name}';
  }

  void _pickCountry() {
    if (_countries.isEmpty) return;
    final search = TextEditingController();
    showAppSheet(context, StatefulBuilder(builder: (ctx, setSt) {
      final q = search.text.toLowerCase();
      final list = _countries.where((c) => c.name.toLowerCase().contains(q) || c.dialCode.contains(q)).toList();
      return sheetScaffold(
        ctx,
        title: 'Country Code',
        icon: Icons.public_rounded,
        body: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.5,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: search,
                autofocus: true,
                onChanged: (_) => setSt(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Search country or code',
                  filled: true,
                  fillColor: AppColors.surface2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final c in list)
                    ListTile(
                      title: Text(c.name, style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink)),
                      trailing: Text('+${c.dialCode}', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                      onTap: () {
                        setState(() => _countryCode = c.dialCode);
                        Navigator.of(ctx).pop();
                      },
                    ),
                ],
              ),
            ),
          ]),
        ),
      );
    }));
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      appToast(context, 'Enter the contact name');
      return;
    }
    if (_mobile.text.trim().isEmpty) {
      appToast(context, 'Enter the mobile number');
      return;
    }
    if (_selectedGroups.isEmpty) {
      appToast(context, 'Please select at least one group');
      return;
    }

    final customAttrs = <String, dynamic>{};
    for (final entry in _attrControllers.entries) {
      customAttrs[entry.key] = entry.value.text.trim();
    }

    widget.onSave({
      'name': _name.text.trim(),
      'countryCode': _countryCode,
      'mobile': _mobile.text.trim(),
      'groups': _selectedGroups.toList(),
      'tags': _selectedTags.toList(),
      'customAttributes': customAttrs,
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return sheetScaffold(
      context,
      title: widget.existing != null ? 'Edit Contact' : 'Add Contact',
      icon: Icons.person_add_alt_1_rounded,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            formLabel('Group * (select one or more)'),
            _groupDropdownPicker(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      formLabel('Country Code *'),
                      _ccPicker(),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      formLabel('Mobile Number *'),
                      formInput(_mobile, hint: '91XXXXXXXXXX', keyboard: TextInputType.phone, formatters: [FilteringTextInputFormatter.digitsOnly]),
                    ],
                  ),
                ),
              ],
            ),
            formLabel('Contact Name *'),
            formInput(_name, hint: 'Contact name'),
            const SizedBox(height: 12),
            formLabel('Tags'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _allTags)
                  GestureDetector(
                    onTap: () => setState(() {
                      if (_selectedTags.contains(t)) {
                        _selectedTags.remove(t);
                      } else {
                        _selectedTags.add(t);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _selectedTags.contains(t) ? AppColors.evaGreen : AppColors.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _selectedTags.contains(t) ? AppColors.evaGreen : AppColors.ink4,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(t, style: AppText.poppins(size: 13, weight: FontWeight.w700, color: _selectedTags.contains(t) ? AppColors.evaGreenDeep : AppColors.ink3)),
                        ],
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: _addNewTag,
                  child: CustomPaint(
                    painter: _DottedBorderPainter(color: AppColors.ink4, radius: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, size: 14, color: AppColors.ink3),
                          const SizedBox(width: 4),
                          Text('New tag', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_attrControllers.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Custom Attributes',
                style: AppText.poppins(size: 15, weight: FontWeight.w700, color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              for (final entry in _attrControllers.entries) ...[
                formLabel(entry.key),
                formInput(entry.value, hint: 'Enter ${entry.key}'),
              ],
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.surface2,
                      side: const BorderSide(color: AppColors.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Cancel', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink2)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.evaGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Save changes', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DottedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    // Draw dashed path
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double distance = 0.0;
    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        canvas.drawPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// shared bits
// ---------------------------------------------------------------------------

class _Tag extends StatelessWidget {
  final String text;
  final bool hash;
  final VoidCallback? onDelete;
  const _Tag(this.text, {this.hash = false, this.onDelete});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: hash ? AppColors.surface2 : AppColors.evaGreen50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: hash ? AppColors.line : AppColors.evaGreen200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(hash ? '#$text' : text, style: AppText.poppins(size: 11, weight: FontWeight.w700, color: hash ? AppColors.ink3 : AppColors.evaGreenDeep)),
          if (onDelete != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.close_rounded, size: 10, color: hash ? AppColors.ink3 : AppColors.evaGreenDeep),
            ),
          ],
        ],
      ),
    );
  }
}

Widget _addTagChip() => CustomPaint(
      painter: _DottedBorderPainter(color: AppColors.evaGreen, radius: 999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('+ Add Tag', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
          ],
        ),
      ),
    );

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
}

String _stamp(DateTime? d) {
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

void showContactImportWizard(
  BuildContext context, {
  required List<String> groups,
  required List<String> customAttributeKeys,
  VoidCallback? onDone,
}) {
  showAppSheet(
    context,
    _ContactImportWizard(
      groups: groups,
      customAttributeKeys: customAttributeKeys,
      onDone: onDone,
    ),
  );
}

class _ContactImportWizard extends StatefulWidget {
  final List<String> groups;
  final List<String> customAttributeKeys;
  final VoidCallback? onDone;

  const _ContactImportWizard({
    required this.groups,
    required this.customAttributeKeys,
    this.onDone,
  });

  @override
  State<_ContactImportWizard> createState() => _ContactImportWizardState();
}

class _ContactImportWizardState extends State<_ContactImportWizard> {
  late final List<String> _availableGroups = List<String>.from(widget.groups);
  final Set<String> _selectedGroups = {};

  bool _fileChosen = false;
  String _fileName = '';
  List<List<String>> _parsedRows = [];
  List<String> _headers = [];

  String? _nameCol;
  String? _ccCol;
  String? _mobileCol;
  final Map<String, String?> _customAttrMapping = {};

  bool _importing = false;
  int _step = 0; // 0: Upload & Group, 1: Column Mapping, 2: Done

  Future<void> _pickCsvFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final file = res.files.first;

      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) {
        if (mounted) appToast(context, 'Could not read file');
        return;
      }

      final content = utf8.decode(bytes, allowMalformed: true).replaceAll('\uFEFF', '');
      final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
      final List<List<String>> rows = lines.map((l) {
        return l.split(RegExp(r'[,;]')).map((c) {
          var s = c.trim();
          if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
            s = s.substring(1, s.length - 1).trim();
          }
          return s;
        }).toList();
      }).toList();

      if (rows.isEmpty || rows.first.isEmpty) {
        if (mounted) appToast(context, 'No columns found in CSV');
        return;
      }

      final List<String> headers = rows.first;
      if (mounted) {
        setState(() {
          _parsedRows = rows;
          _headers = headers;
          _fileName = file.name;
          _fileChosen = true;
          _autoMapColumns(headers);
        });
      }
    } catch (e) {
      if (mounted) appToast(context, 'Failed to read CSV: $e');
    }
  }

  void _autoMapColumns(List<String> headers) {
    String? findCol(List<String> keywords) {
      for (final h in headers) {
        final lower = h.toLowerCase();
        for (final kw in keywords) {
          if (lower.contains(kw)) return h;
        }
      }
      return null;
    }

    _nameCol = findCol(['name', 'full name', 'contact name', 'person']);
    _ccCol = findCol(['country', 'cc', 'dial', 'code']);
    _mobileCol = findCol(['mobile', 'phone', 'number', 'contact']);

    for (final attr in widget.customAttributeKeys) {
      final match = findCol([attr.toLowerCase()]);
      if (match != null) _customAttrMapping[attr] = match;
    }
  }

  void _proceedToMapping() {
    if (_selectedGroups.isEmpty) {
      appToast(context, 'Group is required. Please select at least one group.', isError: true);
      return;
    }
    if (!_fileChosen) {
      appToast(context, 'Choose a CSV file first', isError: true);
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _performImport() async {
    if (_nameCol == null || _nameCol!.isEmpty) {
      appToast(context, 'Please select the Contact Name column', isError: true);
      return;
    }
    if (_mobileCol == null || _mobileCol!.isEmpty) {
      appToast(context, 'Please select the Mobile Number column', isError: true);
      return;
    }

    final nameIdx = _headers.indexOf(_nameCol!);
    final mobileIdx = _headers.indexOf(_mobileCol!);
    final ccIdx = _ccCol != null ? _headers.indexOf(_ccCol!) : -1;

    final attrIndices = <String, int>{};
    _customAttrMapping.forEach((attrKey, colName) {
      if (colName != null && colName.isNotEmpty) {
        final idx = _headers.indexOf(colName);
        if (idx != -1) attrIndices[attrKey] = idx;
      }
    });

    final contactsList = <Map<String, dynamic>>[];
    for (var i = 1; i < _parsedRows.length; i++) {
      final row = _parsedRows[i];
      if (row.length <= nameIdx || row.length <= mobileIdx) continue;

      final name = row[nameIdx].trim();
      final mobileRaw = row[mobileIdx].replaceAll(RegExp(r'\D'), '').trim();
      if (name.isEmpty && mobileRaw.isEmpty) continue;

      String cc = '91';
      if (ccIdx != -1 && ccIdx < row.length) {
        final rawCc = row[ccIdx].replaceAll(RegExp(r'\D'), '').trim();
        if (rawCc.isNotEmpty) cc = rawCc;
      }

      final customAttrs = <String, dynamic>{};
      attrIndices.forEach((attrKey, idx) {
        if (idx < row.length) customAttrs[attrKey] = row[idx].trim();
      });

      contactsList.add({
        'countryCode': cc,
        'phoneNumber': mobileRaw,
        'contactNumber': '$cc$mobileRaw',
        'contactName': name,
        'groups': _selectedGroups.toList(),
        ...customAttrs,
      });
    }

    if (contactsList.isEmpty) {
      appToast(context, 'No valid contact rows found in CSV', isError: true);
      return;
    }

    setState(() => _importing = true);
    try {
      final repo = AppScope.of(context).contacts;
      await repo.importContacts(
        contacts: contactsList,
        groups: _selectedGroups.toList(),
      );
      if (!mounted) return;
      setState(() {
        _importing = false;
        _step = 2;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        appToast(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return sheetScaffold(
      context,
      title: 'Import Contact',
      icon: Icons.upload_file_rounded,
      body: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _step == 0
              ? _buildStep0Upload()
              : _step == 1
                  ? _buildStep1Mapping()
                  : _buildStep2Done(),
        ),
      ),
      footer: _step == 0
          ? primaryButton(context, 'Next: Map Columns', _proceedToMapping, icon: Icons.arrow_forward_rounded)
          : _step == 1
              ? primaryButton(context, _importing ? 'Importing...' : 'Import to Contacts', _importing ? () {} : _performImport, icon: Icons.check_circle_rounded)
              : primaryButton(context, 'Done', () {
                  Navigator.of(context).pop();
                  widget.onDone?.call();
                }, icon: Icons.check_rounded),
    );
  }

  Widget _buildStep0Upload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        formLabel('Group * (select at least one group)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in _availableGroups)
              GestureDetector(
                onTap: () => setState(() {
                  if (_selectedGroups.contains(g)) {
                    _selectedGroups.remove(g);
                  } else {
                    _selectedGroups.add(g);
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedGroups.contains(g) ? AppColors.evaGreen50 : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _selectedGroups.contains(g) ? AppColors.evaGreen : AppColors.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _selectedGroups.contains(g) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 16,
                        color: _selectedGroups.contains(g) ? AppColors.evaGreen : AppColors.ink4,
                      ),
                      const SizedBox(width: 6),
                      Text(g, style: AppText.poppins(size: 13, weight: FontWeight.w700, color: _selectedGroups.contains(g) ? AppColors.evaGreenDeep : AppColors.ink3)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        formLabel('Choose CSV File *'),
        GestureDetector(
          onTap: _pickCsvFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.evaGreen50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.evaGreen200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_fileChosen ? Icons.description_rounded : Icons.file_upload_outlined, size: 20, color: AppColors.evaGreenDeep),
                const SizedBox(width: 8),
                Text(
                  _fileChosen ? '$_fileName (${_parsedRows.length - 1} rows)' : 'Upload CSV File',
                  style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep1Mapping() {
    final colOptions = [('', "Don't map"), for (final h in _headers) (h, h)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Map CSV columns to Contact fields. Required fields (*) must be mapped.',
          style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3),
        ),
        const SizedBox(height: 16),
        formLabel('Contact Name *'),
        formSelect<String>(
          value: _nameCol,
          placeholder: 'Select column',
          options: colOptions,
          onChanged: (v) => setState(() => _nameCol = v),
        ),
        const SizedBox(height: 12),
        formLabel('Country Code *'),
        formSelect<String>(
          value: _ccCol,
          placeholder: 'Select column (default +91)',
          options: colOptions,
          onChanged: (v) => setState(() => _ccCol = v),
        ),
        const SizedBox(height: 12),
        formLabel('Mobile Number *'),
        formSelect<String>(
          value: _mobileCol,
          placeholder: 'Select column',
          options: colOptions,
          onChanged: (v) => setState(() => _mobileCol = v),
        ),
        if (widget.customAttributeKeys.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Custom Attributes', style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 10),
          for (final attr in widget.customAttributeKeys) ...[
            formLabel(attr),
            formSelect<String>(
              value: _customAttrMapping[attr],
              placeholder: 'Select column',
              options: colOptions,
              onChanged: (v) => setState(() => _customAttrMapping[attr] = v),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _buildStep2Done() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.evaGreen, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 36, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text('Contacts Imported Successfully!', style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 8),
            Text('Imported into ${_selectedGroups.join(', ')}', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3)),
          ],
        ),
      ),
    );
  }
}
