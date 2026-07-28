import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/app_scope.dart';
import '../api/dto.dart';
import '../shell/app_nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/common.dart';
import '../widgets/dashboard_sheets.dart' show showAppSheet, appToast;
import '../widgets/leads_extra.dart' show sheetScaffold, formSelect;

/// Schedule timezones (label, IANA zone). The backend stores the IANA zone in
/// `scheduleData.timeZone`; the label is just for display. India first to match
/// the web default.
const _timezones = <(String, String)>[
  ('(GMT+5:30) India Standard Time', 'Asia/Kolkata'),
  ('(GMT+4:00) Gulf Standard Time', 'Asia/Dubai'),
  ('(GMT+8:00) Singapore Time', 'Asia/Singapore'),
  ('(GMT+0:00) Coordinated Universal Time', 'UTC'),
  ('(GMT+0:00) Greenwich Mean Time', 'Europe/London'),
  ('(GMT+1:00) Central European Time', 'Europe/Paris'),
  ('(GMT+5:00) Pakistan Standard Time', 'Asia/Karachi'),
  ('(GMT+6:00) Bangladesh Standard Time', 'Asia/Dhaka'),
  ('(GMT+7:00) Indochina Time', 'Asia/Bangkok'),
  ('(GMT+9:00) Japan Standard Time', 'Asia/Tokyo'),
  ('(GMT+10:00) Australian Eastern Time', 'Australia/Sydney'),
  ('(GMT+3:00) East Africa Time', 'Africa/Nairobi'),
  ('(GMT+2:00) South Africa Standard Time', 'Africa/Johannesburg'),
  ('(GMT-5:00) Eastern Time (US & Canada)', 'America/New_York'),
  ('(GMT-6:00) Central Time (US & Canada)', 'America/Chicago'),
  ('(GMT-7:00) Mountain Time (US & Canada)', 'America/Denver'),
  ('(GMT-8:00) Pacific Time (US & Canada)', 'America/Los_Angeles'),
];

/// Compose Message (`Single MSG / Group / CSV`) wired to the live broadcast
/// API — mirrors my.askeva.io's Compose page (askeva-react Compose/index.jsx).
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});
  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  int _tab = 0; // 0 Single, 1 Group, 2 CSV
  final _mobile = TextEditingController();
  final _campaign = TextEditingController(text: 'CAMP-${DateTime.now().millisecondsSinceEpoch % 100000}');

  // Reference data loaded from the backend.
  bool _loading = true;
  List<CountryDto> _countries = const [];
  List<TemplateDto> _templates = const [];
  List<String> _groupOptions = const [];
  List<String> _attributes = const [];

  // Selection state.
  String? _cc; // selected dial code, e.g. "91"
  TemplateDto? _template;
  final Map<String, String> _vars = {}; // template variable -> value / attribute / column
  final List<String> _groups = []; // selected contact-group names

  // Header media (image/video/file templates).
  String? _mediaUrl;
  String? _mediaName;
  bool _uploadingMedia = false;

  // CSV tab.
  String? _csvUrl;
  String? _csvName;
  List<String> _csvCols = const [];
  String? _csvCcCol;
  String? _csvMobileCol;
  bool _uploadingCsv = false;

  bool _sending = false;

  // Schedule ("Send Now" by default).
  bool _scheduled = false;
  DateTime? _scheduleAt;
  String _tzZone = 'Asia/Kolkata';
  String _tzLabel = _timezones.first.$1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _loadAll();
  }

  @override
  void dispose() {
    _mobile.dispose();
    _campaign.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final repo = AppScope.of(context).compose;
    // Best-effort: a single failing endpoint shouldn't blank the whole screen.
    final countries = await repo.fetchCountries().catchError((_) => <CountryDto>[]);
    final templates = await repo.fetchApprovedTemplates().catchError((_) => <TemplateDto>[]);
    final groups = await repo.fetchContactGroups().catchError((_) => <String>[]);
    final attrs = await repo.fetchUserAttributes().catchError((_) => <String>[]);
    if (!mounted) return;
    setState(() {
      _countries = countries;
      _templates = templates;
      _groupOptions = groups;
      _attributes = attrs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nav = AppNav.of(context);
    return GreenHeaderScaffold(
      title: 'Compose Message',
      onMenu: nav.openDrawer,
      headerChild: GreenSegmented(items: const ['Single MSG', 'Group', 'CSV'], selected: _tab, onChanged: (i) => setState(() => _tab = i)),
      sheet: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.evaGreen))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
              children: [switch (_tab) { 0 => _single(), 1 => _group(), _ => _csv() }],
            ),
    );
  }

  // ---------------- tabs ----------------
  Widget _single() {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Country Code'), _ccPicker()])),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Mobile Number'), _input(_mobile, 'Enter the Mobile Number', keyboard: TextInputType.phone, maxLength: _getMaxLengthForCountryCode(_cc), formatters: [FilteringTextInputFormatter.digitsOnly])])),
        ]),
        const SizedBox(height: 16),
        _templatePicker(),
        _variableInputs(),
        _mediaUpload(),
        const SizedBox(height: 16),
        _label('Campaign Name'),
        _campaignField(),
        const SizedBox(height: 16),
        _actions(),
      ]),
    );
  }

  Widget _group() {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('Select from Contact Groups:'),
        _groupPicker(),
        const SizedBox(height: 16),
        _templatePicker(),
        _variableInputs(),
        _mediaUpload(),
        const SizedBox(height: 16),
        _label('Campaign Name'),
        _campaignField(),
        const SizedBox(height: 16),
        _actions(),
      ]),
    );
  }

  Widget _csv() {
    return Column(children: [
      AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.evaGreen200)),
            child: Text('Upload CSV only, Max file size : 32 MB', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
          ),
          const SizedBox(height: 16),
          _label('Choose File'),
          GestureDetector(
            onTap: _uploadingCsv ? null : _pickCsv,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.evaGreen200)),
              child: Center(
                child: _uploadingCsv
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.evaGreenDeep))
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_csvUrl != null ? Icons.description_rounded : Icons.file_upload_outlined, size: 18, color: AppColors.evaGreenDeep),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _csvName ?? 'Upload',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          if (_csvCols.isNotEmpty) ...[
            const SizedBox(height: 16),
            _label('Country Code Column:'),
            formSelect<String>(value: _csvCcCol, placeholder: 'Select column', options: [for (final c in _csvCols) (c, c)], onChanged: (v) => setState(() => _csvCcCol = v)),
            const SizedBox(height: 16),
            _label('Mobile Number Column:'),
            formSelect<String>(value: _csvMobileCol, placeholder: 'Select column', options: [for (final c in _csvCols) (c, c)], onChanged: (v) => setState(() => _csvMobileCol = v)),
          ] else if (_csvUrl != null)
            Padding(padding: const EdgeInsets.only(top: 10), child: Text('No columns detected in this CSV.', style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink4)))
          else
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('Upload a CSV to map the country-code and mobile columns.', style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink4))),
        ]),
      ),
      const SizedBox(height: 16),
      AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _templatePicker(),
          _variableInputs(),
          _mediaUpload(),
          const SizedBox(height: 16),
          _label('Campaign Name'),
          _campaignField(),
          const SizedBox(height: 16),
          _actions(),
        ]),
      ),
    ]);
  }

  // ---------------- pickers ----------------
  Widget _ccPicker() => GestureDetector(
        onTap: _pickCountry,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.line)),
          child: Row(children: [Expanded(child: Text(_ccLabel(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 14.5, weight: FontWeight.w600, color: _cc == null ? AppColors.ink4 : AppColors.ink))), const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.ink3)]),
        ),
      );

  String _ccLabel() {
    if (_cc == null) return 'Select';
    final c = _countries.where((c) => c.dialCode == _cc);
    return c.isEmpty ? '+$_cc' : c.first.label;
  }

  void _pickCountry() {
    if (_countries.isEmpty) return appToast(context, 'Country list unavailable');
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
              child: TextField(controller: search, autofocus: true, onChanged: (_) => setSt(() {}), decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'Search country or code', filled: true, fillColor: AppColors.surface2, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final c in list)
                    ListTile(
                      title: Text(c.name, style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink)),
                      trailing: Text('+${c.dialCode}', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                      onTap: () {
                        setState(() {
                          _cc = c.dialCode;
                          final maxLen = _getMaxLengthForCountryCode(_cc);
                          if (maxLen != null && _mobile.text.length > maxLen) {
                            _mobile.text = _mobile.text.substring(0, maxLen);
                          }
                        });
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

  Widget _groupPicker() {
    final hint = _groups.isEmpty ? 'Please select' : _groups.join(', ');
    return GestureDetector(
      onTap: _pickGroups,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.line)),
        child: Row(children: [Expanded(child: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 14.5, weight: FontWeight.w600, color: _groups.isEmpty ? AppColors.ink4 : AppColors.ink))), const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.ink3)]),
      ),
    );
  }

  void _pickGroups() {
    if (_groupOptions.isEmpty) return appToast(context, 'No contact groups found');
    final searchCtrl = TextEditingController();
    showAppSheet(context, StatefulBuilder(builder: (ctx, setSt) {
      final q = searchCtrl.text.toLowerCase().trim();
      final filteredGroups = q.isEmpty
          ? _groupOptions
          : _groupOptions.where((g) => g.toLowerCase().contains(q)).toList();

      return sheetScaffold(
        ctx,
        title: 'Contact Groups',
        icon: Icons.groups_rounded,
        body: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.55,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (_) => setSt(() {}),
                  style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.ink3),
                    hintText: 'Search contact group...',
                    hintStyle: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink4),
                    filled: true,
                    fillColor: AppColors.surface2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.6),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: filteredGroups.isEmpty
                    ? Center(
                        child: Text(
                          'No groups found',
                          style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink4),
                        ),
                      )
                    : ListView(
                        children: [
                          for (final g in filteredGroups)
                            CheckboxListTile(
                              value: _groups.contains(g),
                              activeColor: AppColors.evaGreen,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(g, style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink)),
                              onChanged: (v) {
                                setState(() => v == true ? _groups.add(g) : _groups.remove(g));
                                setSt(() {});
                              },
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        footer: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.evaGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Done (${_groups.length})',
                style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ),
      );
    }));
  }

  Widget _templatePicker() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Message Content'),
      GestureDetector(
        onTap: _pickTemplate,
        child: _template == null
            ? DottedDropzone(
                height: 120,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.cloud_upload_outlined, size: 30, color: AppColors.evaGreenDeep),
                  const SizedBox(height: 8),
                  Text('Click here to select template', style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink4, height: 1).copyWith(fontStyle: FontStyle.italic)),
                ]),
              )
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.evaGreen200)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(999)), child: Text(_template!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)))),
                    const Spacer(),
                    const Icon(Icons.edit_outlined, size: 16, color: AppColors.ink3),
                  ]),
                  const SizedBox(height: 8),
                  Text(_template!.message.isEmpty ? '[${_template!.headerType} template]' : _template!.message, style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink2, height: 1.4)),
                ]),
              ),
      ),
    ]);
  }

  void _pickTemplate() {
    if (_templates.isEmpty) return appToast(context, 'No approved templates available');
    final search = TextEditingController();
    int activeTab = 0; // 0=Marketing, 1=Utility, 2=Authentication
    const tabs = ['Marketing', 'Utility', 'Authentication'];

    // Helper: normalise API category string for comparison
    String normCat(String c) => c.trim().toLowerCase();

    showAppSheet(context, StatefulBuilder(builder: (ctx, setSt) {
      final q = search.text.toLowerCase();

      // Count per tab (for badges)
      int count(int tabIdx) {
        return _templates.where((t) {
          final cat = normCat(t.category);
          if (tabIdx == 0) return cat == 'marketing' || (cat != 'utility' && cat != 'authentication');
          if (tabIdx == 1) return cat == 'utility';
          return cat == 'authentication';
        }).length;
      }

      final list = _templates.where((t) {
        final cat = normCat(t.category);
        final bool matchCat;
        if (activeTab == 0) {
          // Marketing tab: show MARKETING + any unrecognised/empty category
          matchCat = cat == 'marketing' || (cat != 'utility' && cat != 'authentication');
        } else if (activeTab == 1) {
          matchCat = cat == 'utility';
        } else {
          matchCat = cat == 'authentication';
        }
        final matchQ = q.isEmpty || t.name.toLowerCase().contains(q) || t.message.toLowerCase().contains(q);
        return matchCat && matchQ;
      }).toList();

      return Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // drag handle
          Container(margin: const EdgeInsets.only(top: 10, bottom: 8), width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(99))),

          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 0),
            child: Row(children: [
              Text('Select template', style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.ink)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(99)),
                  child: const Icon(Icons.close_rounded, size: 18, color: AppColors.ink3),
                ),
              ),
            ]),
          ),

          // Category tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              for (int i = 0; i < tabs.length; i++) ...[
                GestureDetector(
                  onTap: () => setSt(() => activeTab = i),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        tabs[i],
                        style: AppText.poppins(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: activeTab == i ? AppColors.evaGreenDeep : AppColors.ink3,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: activeTab == i ? AppColors.evaGreenDeep : AppColors.surface3,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${count(i)}',
                          style: AppText.poppins(
                            size: 10,
                            weight: FontWeight.w800,
                            color: activeTab == i ? Colors.white : AppColors.ink3,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 5),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 3,
                      width: activeTab == i ? tabs[i].length * 8.0 : 0,
                      decoration: BoxDecoration(
                        color: AppColors.evaGreenDeep,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ]),
                ),
                if (i < tabs.length - 1) const SizedBox(width: 16),
              ],
            ]),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.line),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: TextField(
                controller: search,
                onChanged: (_) => setSt(() {}),
                style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.ink3),
                  hintText: 'Search templates...',
                  hintStyle: AppText.poppins(size: 13.5, weight: FontWeight.w400, color: AppColors.ink4),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),

          // Template list
          SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.52,
            child: list.isEmpty
                ? Center(child: Text('No templates found', style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink4)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final t = list[i];
                      final ht = t.headerType.toLowerCase();
                      final IconData typeIcon = ht == 'image'
                          ? Icons.image_outlined
                          : ht == 'video'
                              ? Icons.videocam_outlined
                              : ht == 'file' || ht == 'document'
                                  ? Icons.insert_drive_file_outlined
                                  : Icons.title_rounded;
                      final typeLabel = ht == 'image'
                          ? 'Image'
                          : ht == 'video'
                              ? 'Video'
                              : ht == 'file' || ht == 'document'
                                  ? 'File'
                                  : 'Text';

                      return GestureDetector(
                        onTap: () {
                          _selectTemplate(t);
                          Navigator.of(ctx).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.line),
                            boxShadow: AppColors.shadowXs,
                          ),
                          child: Row(children: [
                            // Type icon box
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.evaGreen50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(typeIcon, size: 22, color: AppColors.evaGreenDeep),
                            ),
                            const SizedBox(width: 12),

                            // Name + preview + tag
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(
                                  t.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink),
                                ),
                                if (t.message.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    t.message,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.poppins(size: 12, weight: FontWeight.w400, color: AppColors.ink3),
                                  ),
                                ],
                                const SizedBox(height: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.evaGreen50,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    typeLabel,
                                    style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(width: 10),

                            // Green arrow button
                            Container(
                              width: 36, height: 36,
                              decoration: const BoxDecoration(
                                color: AppColors.evaGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      );
    }));
  }

  void _selectTemplate(TemplateDto t) {
    setState(() {
      _template = t;
      _vars
        ..clear()
        ..addEntries(t.variables.map((v) => MapEntry(v, '')));
      _mediaUrl = null;
      _mediaName = null;
    });
  }

  /// Per-variable inputs: free text for single sends; attribute / column
  /// mapping for group / CSV sends.
  Widget _variableInputs() {
    final t = _template;
    if (t == null || t.variables.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      _label(_tab == 0 ? 'Template Variables' : 'Map Variables'),
      for (final v in t.variables) ...[
        Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(v, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3))),
        if (_tab == 0)
          TextField(
            onChanged: (val) => _vars[v] = val,
            style: AppText.poppins(size: 14.5, weight: FontWeight.w600, color: AppColors.ink),
            decoration: _fieldDecoration('Enter value for $v'),
          )
        else
          GestureDetector(
            onTap: (_tab == 2 && _csvCols.isEmpty)
                ? () => appToast(context, 'Please upload a CSV file first to populate columns')
                : null,
            child: formSelect<String>(
              value: _vars[v]?.isEmpty ?? true ? null : _vars[v],
              placeholder: _tab == 1 ? 'Select attribute' : 'Select column',
              options: [for (final o in (_tab == 1 ? _attributes : _csvCols)) (o, o)],
              onChanged: (val) => setState(() => _vars[v] = val),
            ),
          ),
        const SizedBox(height: 10),
      ],
    ]);
  }

  Widget _mediaUpload() {
    final t = _template;
    if (t == null || !t.needsMedia) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      _label('Header ${t.headerType[0].toUpperCase()}${t.headerType.substring(1)}'),
      GestureDetector(
        onTap: _uploadingMedia ? null : _pickMedia,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(13), border: Border.all(color: _mediaUrl != null ? AppColors.evaGreen200 : AppColors.line)),
          child: Center(
            child: _uploadingMedia
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.evaGreenDeep))
                : Row(mainAxisSize: MainAxisSize.min, children: [Icon(_mediaUrl != null ? Icons.check_circle_rounded : Icons.attach_file_rounded, size: 18, color: AppColors.evaGreenDeep), const SizedBox(width: 8), Flexible(child: Text(_mediaName ?? 'Upload ${t.headerType}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.evaGreenDeep)))]),
          ),
        ),
      ),
    ]);
  }

  // ---------------- uploads ----------------
  Future<void> _pickMedia() async {
    final t = _template;
    if (t == null) return;
    final ext = switch (t.headerType.toLowerCase()) {
      'image' => ['jpg', 'jpeg', 'png'],
      'video' => ['mp4', 'mov', 'mpeg'],
      _ => ['pdf', 'doc', 'docx'],
    };
    final repo = AppScope.of(context).compose;
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ext, withData: true);
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
    final f = res.files.first;
    setState(() => _uploadingMedia = true);
    try {
      final url = await repo.uploadMedia(f.bytes!, f.name);
      if (url == null || url.isEmpty) throw Exception('Upload failed');
      if (mounted) setState(() { _mediaUrl = url; _mediaName = f.name; });
    } catch (e) {
      if (mounted) appToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  List<String> _parseCsvHeadersLocally(Uint8List bytes) {
    try {
      final text = utf8.decode(bytes);
      final lines = text.split(RegExp(r'\r?\n'));
      String firstLine = '';
      for (final l in lines) {
        if (l.trim().isNotEmpty) {
          firstLine = l.trim();
          break;
        }
      }
      if (firstLine.isEmpty) return [];
      return firstLine
          .split(RegExp(r'[,;]'))
          .map((c) {
            var s = c.trim();
            if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
              s = s.substring(1, s.length - 1).trim();
            }
            return s;
          })
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  String? _autoDetectCol(List<String> cols, List<String> keywords) {
    for (final col in cols) {
      final lower = col.toLowerCase();
      for (final kw in keywords) {
        if (lower.contains(kw)) return col;
      }
    }
    return cols.isNotEmpty ? cols.first : null;
  }

  Future<void> _pickCsv() async {
    final repo = AppScope.of(context).compose;

    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      allowMultiple: false,
      withData: true,
    );

    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;

    final ext = (f.extension ?? f.name.split('.').last).toLowerCase().trim();
    if (ext != 'csv') {
      if (mounted) appToast(context, 'Please select a .csv file');
      return;
    }

    Uint8List? bytes = f.bytes;
    if (bytes == null) {
      final path = f.path;
      if (path == null) {
        if (mounted) appToast(context, 'Could not read file. Try again.');
        return;
      }
      try {
        bytes = await File(path).readAsBytes();
      } catch (_) {
        if (mounted) appToast(context, 'Could not read file. Try again.');
        return;
      }
    }

    final fileName = f.name.endsWith('.csv') ? f.name : '${f.name}.csv';

    // Parse headers locally first for instant, guaranteed offline fallback
    final localCols = _parseCsvHeadersLocally(bytes);

    setState(() {
      _uploadingCsv = true;
      _csvUrl = null;
      _csvCols = localCols;
      _csvName = '$fileName · ${localCols.length} columns';
      _csvCcCol = _autoDetectCol(localCols, ['country', 'cc', 'dial', 'code']);
      _csvMobileCol = _autoDetectCol(localCols, ['mobile', 'phone', 'number', 'contact']);
    });

    try {
      final url = await repo.uploadCsv(bytes, fileName);
      if (url == null || url.isEmpty) throw Exception('Upload failed — server returned no URL');
      
      List<String> cols = const [];
      try {
        cols = await repo.fetchCsvHeaders(url);
      } catch (_) {}

      final finalCols = cols.isNotEmpty ? cols : localCols;
      if (mounted) {
        setState(() {
          _csvUrl = url;
          _csvCols = finalCols;
          _csvName = '$fileName · ${finalCols.length} columns';
          _csvCcCol ??= _autoDetectCol(finalCols, ['country', 'cc', 'dial', 'code']);
          _csvMobileCol ??= _autoDetectCol(finalCols, ['mobile', 'phone', 'number', 'contact']);
        });
      }
    } catch (e) {
      if (mounted) {
        if (_csvCols.isEmpty) {
          setState(() { _csvUrl = null; _csvName = null; });
          appToast(context, e.toString().replaceFirst('Exception: ', ''));
        }
      }
    } finally {
      if (mounted) setState(() => _uploadingCsv = false);
    }
  }

  bool _validatePhoneNumber(String cc, String number) {
    final digits = number.trim();
    if (digits.isEmpty) {
      appToast(context, 'Enter a mobile number');
      return false;
    }

    if (cc == '91') {
      if (digits.length != 10) {
        appToast(context, 'India mobile number must be exactly 10 digits');
        return false;
      }
      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
        appToast(context, 'India mobile number must start with 6, 7, 8, or 9');
        return false;
      }
    } else if (cc == '1') {
      if (digits.length != 10) {
        appToast(context, 'US/Canada mobile number must be exactly 10 digits');
        return false;
      }
    } else if (cc == '44') {
      if (digits.length != 10) {
        appToast(context, 'UK mobile number must be exactly 10 digits (excluding leading 0)');
        return false;
      }
    } else if (cc == '971') {
      if (digits.length != 9) {
        appToast(context, 'UAE mobile number must be exactly 9 digits (excluding leading 0)');
        return false;
      }
    } else if (cc == '966') {
      if (digits.length != 9) {
        appToast(context, 'Saudi Arabia mobile number must be exactly 9 digits');
        return false;
      }
    } else if (cc == '974') {
      if (digits.length != 8) {
        appToast(context, 'Qatar mobile number must be exactly 8 digits');
        return false;
      }
    } else if (cc == '968') {
      if (digits.length != 8) {
        appToast(context, 'Oman mobile number must be exactly 8 digits');
        return false;
      }
    } else if (cc == '973') {
      if (digits.length != 8) {
        appToast(context, 'Bahrain mobile number must be exactly 8 digits');
        return false;
      }
    } else if (cc == '65') {
      if (digits.length != 8) {
        appToast(context, 'Singapore mobile number must be exactly 8 digits');
        return false;
      }
    } else if (cc == '60') {
      if (digits.length < 9 || digits.length > 10) {
        appToast(context, 'Malaysia mobile number must be 9 or 10 digits');
        return false;
      }
    } else if (cc == '61') {
      if (digits.length != 9) {
        appToast(context, 'Australia mobile number must be exactly 9 digits (excluding leading 0)');
        return false;
      }
    } else {
      if (digits.length < 7 || digits.length > 15) {
        appToast(context, 'Mobile number must be between 7 and 15 digits');
        return false;
      }
    }
    return true;
  }

  // ---------------- send ----------------
  Future<void> _send() async {
    final t = _template;
    if (t == null) return appToast(context, 'Select a template');
    if (t.isCarousel) return appToast(context, 'Carousel templates aren\'t supported here yet');
    final campaign = _campaign.text.trim();
    if (campaign.isEmpty) return appToast(context, 'Enter a campaign name');
    if (t.needsMedia && (_mediaUrl == null || _mediaUrl!.isEmpty)) return appToast(context, 'Upload the ${t.headerType} header first');
    if (_scheduled) {
      if (_scheduleAt == null) return appToast(context, 'Pick a schedule date & time');
      if (!_scheduleAt!.isAfter(DateTime.now().subtract(const Duration(minutes: 1)))) {
        return appToast(context, 'Select a future date & time');
      }
    }

    final header = t.needsMedia ? _mediaUrl! : t.message;
    final String method;
    final Map<String, dynamic> body;
    final Map<String, dynamic> attributesMap;

    if (_tab == 0) {
      method = 'single';
      if (_cc == null) return appToast(context, 'Select a country code');
      final mobile = _mobile.text.trim();
      if (!_validatePhoneNumber(_cc!, mobile)) return;
      for (final v in t.variables) {
        if ((_vars[v] ?? '').trim().isEmpty) return appToast(context, '$v is required');
      }
      attributesMap = Map<String, dynamic>.from(_vars);
      body = {
        'countryCode': _cc,
        'contactNumber': '$_cc$mobile',
        'method': 'single',
        ..._vars,
        'campaignId': campaign,
        'campaignName': campaign,
        'scheduleData': _scheduleData(),
        'scheduled': _scheduled,
        'isScheduled': _scheduled,
        'schedule': _scheduled,
        'trigger': _scheduled,
        'scheduledAt': _scheduleAt?.toIso8601String(),
        'header': header,
        'cards': const [],
      };
    } else if (_tab == 1) {
      method = 'group';
      if (_groups.isEmpty) return appToast(context, 'Select at least one contact group');
      for (final v in t.variables) {
        if ((_vars[v] ?? '').isEmpty) return appToast(context, 'Map an attribute for $v');
      }
      attributesMap = Map<String, dynamic>.from(_vars);
      body = {
        'method': 'group',
        'groups': _groups,
        'attributesMap': attributesMap,
        'header': header,
        'campaignId': campaign,
        'campaignName': campaign,
        'scheduleData': _scheduleData(),
        'scheduled': _scheduled,
        'isScheduled': _scheduled,
        'schedule': _scheduled,
        'trigger': _scheduled,
        'scheduledAt': _scheduleAt?.toIso8601String(),
        'cards': const [],
        'retrigger': {'flag': false, 'type': '', 'prevCampaignId': ''},
      };
    } else {
      method = 'csv';
      if (_csvUrl == null) return appToast(context, 'Upload a CSV file');
      if (_csvCcCol == null) return appToast(context, 'Select the country-code column');
      if (_csvMobileCol == null) return appToast(context, 'Select the mobile-number column');
      for (final v in t.variables) {
        if ((_vars[v] ?? '').isEmpty) return appToast(context, 'Map a column for $v');
      }
      attributesMap = {
        ..._vars,
        'countryCode': _csvCcCol,
        'phoneNumber': _csvMobileCol,
        'mobileNumber': _csvMobileCol,
        'contactNumber': _csvMobileCol,
      };
      body = {
        'method': 'csv',
        'groups': const [],
        'attributesMap': attributesMap,
        'filename': _csvUrl,
        'header': header,
        'campaignId': campaign,
        'campaignName': campaign,
        'scheduleData': _scheduleData(),
        'scheduled': _scheduled,
        'isScheduled': _scheduled,
        'schedule': _scheduled,
        'trigger': _scheduled,
        'scheduledAt': _scheduleAt?.toIso8601String(),
        'cards': const [],
        'retrigger': {'flag': false, 'type': '', 'prevCampaignId': ''},
      };
    }

    setState(() => _sending = true);
    try {
      final repo = AppScope.of(context).compose;
      // Duplicate-campaign guard (mirrors the web flow before broadcasting).
      await repo.checkCampaign(
        campaignId: campaign,
        templateId: t.id,
        filename: _csvUrl,
        method: method,
        attributesMap: attributesMap,
        groups: _tab == 1 ? _groups : const [],
        trigger: _scheduled,
      );
      await repo.sendBroadcast(t.id, body);
      if (!mounted) return;
      appToast(context, _scheduled ? 'Message scheduled successfully' : 'Campaign sent — processing in Meta\'s queue. Report updates in a few minutes.', isSuccess: true);
      _clear(silent: true);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) appToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<bool> _confirmScheduleDialog({
    required String campaignName,
    required String method,
    required DateTime scheduleAt,
    required String tzLabel,
  }) async {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${scheduleAt.day} ${months[scheduleAt.month - 1]} ${scheduleAt.year}';
    final h = scheduleAt.hour % 12 == 0 ? 12 : scheduleAt.hour % 12;
    final m = scheduleAt.minute.toString().padLeft(2, '0');
    final timeStr = '$h:$m ${scheduleAt.hour < 12 ? 'AM' : 'PM'}';
    final recipientStr = method == 'single'
        ? 'Single recipient ($_cc ${_mobile.text.trim()})'
        : method == 'group'
            ? 'Group broadcast (${_groups.join(', ')})'
            : 'CSV file contacts (${_csvName ?? 'uploaded file'})';

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.evaGreen50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.schedule_send_rounded, size: 26, color: AppColors.evaGreenDeep),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Confirm Schedule', style: AppText.poppins(size: 17, weight: FontWeight.w700, color: AppColors.ink)),
                          Text('Review schedule details before publishing', style: AppText.poppins(size: 11.5, color: AppColors.ink3)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAF7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _confirmRow(Icons.campaign_outlined, 'Campaign', campaignName),
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                      _confirmRow(Icons.event_outlined, 'Scheduled Date', '$dateStr at $timeStr'),
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                      _confirmRow(Icons.public_outlined, 'Time Zone', tzLabel),
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                      _confirmRow(Icons.people_alt_outlined, 'Recipients', recipientStr),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            side: const BorderSide(color: AppColors.line),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Cancel', style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink3)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            backgroundColor: AppColors.evaGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Confirm & Schedule', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.white)),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  Widget _confirmRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.evaGreenDeep),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.poppins(size: 11, weight: FontWeight.w500, color: AppColors.ink4)),
              const SizedBox(height: 2),
              Text(value, style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
            ],
          ),
        ),
      ],
    );
  }

  /// `scheduleData` payload: populated only when scheduling, matching the web's
  /// `{ timeZone: <IANA>, dateAndTime: "YYYY-MM-DDTHH:MM" }` (empty for Send Now).
  Map<String, String> _scheduleData() {
    if (!_scheduled || _scheduleAt == null) return const {'timeZone': '', 'dateAndTime': ''};
    final d = _scheduleAt!;
    String two(int n) => n.toString().padLeft(2, '0');
    final dt = '${d.year}-${two(d.month)}-${two(d.day)}T${two(d.hour)}:${two(d.minute)}:00';
    return {'timeZone': _tzZone, 'dateAndTime': dt};
  }

  bool _validateFormForSchedule() {
    final t = _template;
    if (t == null) {
      appToast(context, 'Select a template before scheduling', isError: true);
      return false;
    }
    if (t.isCarousel) {
      appToast(context, 'Carousel templates aren\'t supported here yet', isError: true);
      return false;
    }
    final campaign = _campaign.text.trim();
    if (campaign.isEmpty) {
      appToast(context, 'Enter a campaign name', isError: true);
      return false;
    }
    if (t.needsMedia && (_mediaUrl == null || _mediaUrl!.isEmpty)) {
      appToast(context, 'Upload the ${t.headerType} header first', isError: true);
      return false;
    }

    if (_tab == 0) {
      if (_cc == null) {
        appToast(context, 'Select a country code', isError: true);
        return false;
      }
      final mobile = _mobile.text.trim();
      if (!_validatePhoneNumber(_cc!, mobile)) return false;
      for (final v in t.variables) {
        if ((_vars[v] ?? '').trim().isEmpty) {
          appToast(context, '$v is required', isError: true);
          return false;
        }
      }
    } else if (_tab == 1) {
      if (_groups.isEmpty) {
        appToast(context, 'Select at least one contact group', isError: true);
        return false;
      }
      for (final v in t.variables) {
        if ((_vars[v] ?? '').isEmpty) {
          appToast(context, 'Map an attribute for $v', isError: true);
          return false;
        }
      }
    } else {
      if (_csvUrl == null) {
        appToast(context, 'Upload a CSV file', isError: true);
        return false;
      }
      if (_csvCcCol == null) {
        appToast(context, 'Select the country-code column', isError: true);
        return false;
      }
      if (_csvMobileCol == null) {
        appToast(context, 'Select the mobile-number column', isError: true);
        return false;
      }
      for (final v in t.variables) {
        if ((_vars[v] ?? '').isEmpty) {
          appToast(context, 'Map a column for $v', isError: true);
          return false;
        }
      }
    }
    return true;
  }

  void _openScheduleSheet() {
    final now = DateTime.now();
    var date = _scheduleAt ?? now;
    var time = _scheduleAt != null
        ? TimeOfDay(hour: _scheduleAt!.hour, minute: _scheduleAt!.minute)
        : TimeOfDay.now();
    var zone = _tzZone;
    var zoneLabel = _tzLabel;
    showAppSheet(context, StatefulBuilder(builder: (ctx, setSt) {
      DateTime combined() => DateTime(date.year, date.month, date.day, time.hour, time.minute);
      return sheetScaffold(
        ctx,
        title: 'Schedule message',
        icon: Icons.schedule_rounded,
        body: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.62,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CalendarDatePicker(
                initialDate: date,
                firstDate: DateTime(now.year, now.month, now.day - 1),
                lastDate: now.add(const Duration(days: 365)),
                onDateChanged: (d) => setSt(() => date = d),
              ),
              const SizedBox(height: 4),
              _schedTile(Icons.access_time_rounded, 'Time', time.format(ctx), () async {
                final picked = await showTimePicker(context: ctx, initialTime: time);
                if (picked != null) setSt(() => time = picked);
              }),
              const SizedBox(height: 10),
              _schedTile(Icons.public_rounded, 'Time zone', zoneLabel, () {
                _pickTimezone(ctx, (label, z) => setSt(() { zoneLabel = label; zone = z; }));
              }),
              const SizedBox(height: 8),
            ]),
          ),
        ),
        footer: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: AppColors.ink3)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.evaGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    final when = combined();
                    if (!when.isAfter(DateTime.now().subtract(const Duration(minutes: 1)))) {
                      appToast(ctx, 'Select a future date & time', isError: true);
                      return;
                    }
                    if (!_validateFormForSchedule()) return;
                    final confirmed = await _confirmScheduleDialog(
                      campaignName: _campaign.text.trim(),
                      method: _tab == 0 ? 'single' : (_tab == 1 ? 'group' : 'csv'),
                      scheduleAt: when,
                      tzLabel: zoneLabel,
                    );
                    if (confirmed == true) {
                      setState(() {
                        _scheduled = true;
                        _scheduleAt = when;
                        _tzZone = zone;
                        _tzLabel = zoneLabel;
                      });
                      if (mounted) Navigator.of(ctx).pop();
                      _send();
                    }
                  },
                  child: Text('Set', style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ]),
        ),
      );
    }));
  }

  Widget _schedTile(IconData icon, String label, String value, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.line)),
          child: Row(children: [
            Icon(icon, size: 19, color: AppColors.evaGreenDeep),
            const SizedBox(width: 12),
            Text(label, style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink3)),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.ink4),
          ]),
        ),
      );

  void _pickTimezone(BuildContext sheetCtx, void Function(String label, String zone) onPick) {
    final search = TextEditingController();
    showAppSheet(sheetCtx, StatefulBuilder(builder: (ctx, setSt) {
      final q = search.text.toLowerCase();
      final list = _timezones.where((t) => t.$1.toLowerCase().contains(q) || t.$2.toLowerCase().contains(q)).toList();
      return sheetScaffold(
        ctx,
        title: 'Time zone',
        icon: Icons.public_rounded,
        body: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.5,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(controller: search, autofocus: true, onChanged: (_) => setSt(() {}), decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'Search', filled: true, fillColor: AppColors.surface2, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final t in list)
                    ListTile(
                      title: Text(t.$1, style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink)),
                      onTap: () {
                        onPick(t.$1, t.$2);
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

  void _clear({bool silent = false}) {
    setState(() {
      _scheduled = false;
      _scheduleAt = null;
      _tzZone = 'Asia/Kolkata';
      _tzLabel = _timezones.first.$1;
      _mobile.clear();
      _cc = null;
      _template = null;
      _vars.clear();
      _groups.clear();
      _mediaUrl = null;
      _mediaName = null;
      _csvUrl = null;
      _csvName = null;
      _csvCols = const [];
      _csvCcCol = null;
      _csvMobileCol = null;
      _campaign.text = 'CAMP-${DateTime.now().millisecondsSinceEpoch % 100000}';
    });
    if (!silent) appToast(context, 'Cleared');
  }

  // ---------------- shared ----------------
  Widget _label(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink)));

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.ink4),
        filled: true,
        fillColor: AppColors.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
      );

  Widget _campaignField() => TextField(
        controller: _campaign,
        maxLength: 50,
        style: AppText.poppins(size: 14.5, weight: FontWeight.w600, color: AppColors.ink),
        decoration: _fieldDecoration('Enter the campaign name').copyWith(counterText: ''),
      );

  int? _getMaxLengthForCountryCode(String? cc) {
    if (cc == null) return null;
    switch (cc) {
      case '91': // India
      case '1':  // US / Canada
      case '44': // UK
        return 10;
      case '971': // UAE
      case '966': // Saudi Arabia
      case '61':  // Australia
        return 9;
      case '974': // Qatar
      case '968': // Oman
      case '973': // Bahrain
      case '65':  // Singapore
        return 8;
      case '60':  // Malaysia
        return 10;
      default:
        return 15;
    }
  }

  Widget _input(TextEditingController c, String hint, {TextInputType? keyboard, List<TextInputFormatter>? formatters, int? maxLength}) => TextField(
        controller: c,
        keyboardType: keyboard,
        inputFormatters: formatters,
        maxLength: maxLength,
        style: AppText.poppins(size: 14.5, weight: FontWeight.w600, color: AppColors.ink),
        decoration: _fieldDecoration(hint).copyWith(counterText: ''),
      );

  Widget _actions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_scheduled && _scheduleAt != null) ...[
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.evaGreen200)),
          child: Row(children: [
            const Icon(Icons.schedule_rounded, size: 16, color: AppColors.evaGreenDeep),
            const SizedBox(width: 8),
            Expanded(child: Text('Scheduled for ${_fmtSchedule(_scheduleAt!)} · $_tzLabel', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.evaGreenDeep))),
            GestureDetector(onTap: () => setState(() { _scheduled = false; _scheduleAt = null; }), child: const Icon(Icons.close_rounded, size: 16, color: AppColors.evaGreenDeep)),
          ]),
        ),
      ],
      Row(children: [
        Expanded(
          child: Material(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _sending ? null : _clear,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text('Clear', textAlign: TextAlign.center, style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: Colors.white))),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(color: AppColors.evaGreen, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                    onTap: _sending ? null : _send,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _sending
                          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)))
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_scheduled ? Icons.schedule_send_rounded : Icons.send_rounded, size: 17, color: Colors.white), const SizedBox(width: 8), Flexible(child: Text(_scheduled ? 'Schedule' : 'Send Now', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: Colors.white)))]),
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 26, color: Colors.white.withValues(alpha: 0.3)),
              PopupMenuButton<String>(
                enabled: !_sending,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 22),
                color: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'now') {
                    setState(() { _scheduled = false; _scheduleAt = null; });
                  } else {
                    _openScheduleSheet();
                  }
                },
                itemBuilder: (_) => [
                  _sendOption('now', Icons.send_rounded, 'Send Now'),
                  _sendOption('schedule', Icons.schedule_rounded, 'Schedule for later'),
                ],
              ),
            ]),
          ),
        ),
      ]),
    ]);
  }

  PopupMenuItem<String> _sendOption(String v, IconData icon, String label) => PopupMenuItem(
        value: v,
        child: Row(children: [Icon(icon, size: 18, color: AppColors.evaGreenDeep), const SizedBox(width: 12), Text(label, style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink))]),
      );

  String _fmtSchedule(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]}, $h:${two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
  }
}
