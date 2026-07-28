import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import 'lead_file_reader_stub.dart'
    if (dart.library.io) 'lead_file_reader_io.dart' as file_reader;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../services/leads_service.dart';

class ImportLeadsModal extends StatefulWidget {
  final VoidCallback onSuccess;
  final void Function(List<Map<String, String>> duplicates)? onDuplicates;

  const ImportLeadsModal({
    super.key,
    required this.onSuccess,
    this.onDuplicates,
  });

  @override
  State<ImportLeadsModal> createState() => _ImportLeadsModalState();
}

/// System field keys for mapping.
const String _sysCountry = 'countryCode';
const String _sysMobile = 'mobile';
const String _sysName = 'name';

class _ImportLeadsModalState extends State<ImportLeadsModal> {
  int _currentStep = 0;
  PlatformFile? _selectedFile;
  bool _isImporting = false;
  String? _importError;
  Map<String, dynamic>? _importResult;
  bool _sendAlert = false;

  /// Raw CSV: headers from first row, data rows (no header).
  List<String>? _csvHeaders;
  List<List<String>>? _csvRawRows;
  /// Map CSV column index -> system field key (_sysCountry, _sysMobile, _sysName).
  Map<int, String> _columnMapping = {};
  /// Loading raw CSV after file pick.
  bool _loadingCsv = false;

  /// After import: not-imported rows with reason (duplicate in file, duplicate in DB, etc.).
  List<Map<String, String>> _notImportedWithReason = [];
  /// After import: failed rows from API (sno, phone, email, name?, reason).
  List<Map<String, String>> _failedWithReason = [];
  /// Server-side skipped count (when backend skipped some).
  int _serverSkippedCount = 0;

  final List<String> _steps = [
    'Upload File',
    'Map Fields',
    'Preview & Handle Duplicates',
    'Import',
  ];

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result != null) {
        final file = result.files.single;
        if (!file.name.toLowerCase().endsWith('.csv')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a CSV file (.csv)')),
          );
          return;
        }
        setState(() {
          _selectedFile = file;
          _csvHeaders = null;
          _csvRawRows = null;
          _columnMapping = {};
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
    }
  }

  /// Parse CSV to headers + raw rows (no interpretation).
  static Future<({List<String> headers, List<List<String>> rows})> _parseCsvRaw(PlatformFile file) async {
    String raw;
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      raw = utf8.decode(file.bytes!, allowMalformed: true);
    } else if (file.path != null && file.path!.trim().isNotEmpty) {
      raw = await file_reader.readFileFromPath(file.path!);
      if (raw.isEmpty) throw Exception('File is empty.');
    } else {
      throw Exception('No file data.');
    }
    if (raw.startsWith('\uFEFF')) {
      raw = raw.substring(1);
    }
    final lines = raw.split(RegExp(r'\r\n|\r|\n')).where((s) => s.trim().isNotEmpty).toList();
    if (lines.isEmpty) throw Exception('CSV has no lines.');
    final headers = _parseCsvLine(lines.first);
    final rows = <List<String>>[];
    for (int i = 1; i < lines.length; i++) {
      final cols = _parseCsvLine(lines[i]);
      if (cols.isNotEmpty) rows.add(cols);
    }
    return (headers: headers, rows: rows);
  }

  /// Load raw CSV and auto-detect mapping from header names.
  Future<void> _loadRawCsv() async {
    if (_selectedFile == null) return;
    setState(() {
      _loadingCsv = true;
      _importError = null;
    });
    try {
      final parsed = await _parseCsvRaw(_selectedFile!);
      final mapping = <int, String>{};
      for (int i = 0; i < parsed.headers.length; i++) {
        final h = parsed.headers[i].toLowerCase().trim();
        if (h == 'country_code') mapping[i] = _sysCountry;
        else if (h == 'mobile_number' || h == 'mobile') mapping[i] = _sysMobile;
        else if (h == 'contact_name' || h == 'name') mapping[i] = _sysName;
      }
      if (mounted) {
        setState(() {
          _csvHeaders = parsed.headers;
          _csvRawRows = parsed.rows;
          _columnMapping = mapping;
          _loadingCsv = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingCsv = false;
          _importError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  /// Normalize phone to digits only; if 10 digits assume India (+91).
  static String _normalizePhone(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 10 && !digits.startsWith('0')) return '91$digits';
    if (digits.length >= 10) return digits;
    return digits;
  }

  static String _normalizeEmail(String? value) {
    return (value ?? '').trim().toLowerCase();
  }

  /// Build lead maps from raw rows using current column mapping.
  List<Map<String, dynamic>> _getMappedLeads() {
    final rows = _csvRawRows ?? [];
    final list = <Map<String, dynamic>>[];
    for (final cols in rows) {
      String countryCode = '91';
      String mobile = '';
      String name = '';
      _columnMapping.forEach((colIdx, sysKey) {
        if (colIdx >= cols.length) return;
        final v = cols[colIdx].trim();
        if (sysKey == _sysCountry) {
          final digits = v.replaceAll(RegExp(r'[^\d]'), '');
          countryCode = digits.isEmpty ? '91' : digits;
        } else if (sysKey == _sysMobile) {
          mobile = v.replaceAll(RegExp(r'[^\d]'), '');
          if (mobile.length > 10 && mobile.startsWith('91')) {
            countryCode = '91';
            mobile = mobile.substring(2);
          }
        } else if (sysKey == _sysName) {
          name = v;
        }
      });
      if (name.isEmpty) name = 'Lead';
      final fullMobile = countryCode.isNotEmpty && mobile.isNotEmpty ? '$countryCode$mobile' : null;
      list.add({
        'name': name,
        'company': '',
        'email': null,
        'status': 'New Lead',
        'source': 'Website',
        'mobile': mobile.isEmpty ? null : mobile,
        'countryCode': countryCode,
        'fullMobile': fullMobile,
      });
    }
    return list;
  }

  /// Preview rows for display: list of {countryCode, mobile, name}.
  List<Map<String, String>> _getPreviewRows() {
    final rows = _csvRawRows ?? [];
    final preview = <Map<String, String>>[];
    for (final cols in rows) {
      String countryCode = '91';
      String mobile = '';
      String name = '';
      _columnMapping.forEach((colIdx, sysKey) {
        if (colIdx >= cols.length) return;
        final v = cols[colIdx].trim();
        if (sysKey == _sysCountry) {
          countryCode = v.replaceAll(RegExp(r'[^\d]'), '').isEmpty ? '91' : v.replaceAll(RegExp(r'[^\d]'), '');
        } else if (sysKey == _sysMobile) {
          mobile = v.replaceAll(RegExp(r'[^\d]'), '');
        } else if (sysKey == _sysName) {
          name = v;
        }
      });
      preview.add({'countryCode': countryCode, 'mobile': mobile, 'name': name.isEmpty ? '—' : name});
    }
    return preview;
  }

  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;
    final hasComma = line.contains(',');
    final hasSemicolon = line.contains(';');
    final delimiter = (hasSemicolon && !hasComma) ? ';' : ',';
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == delimiter && !inQuotes) {
        result.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(c);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  Future<void> _doImport() async {
    final parsed = _getMappedLeads();
    if (kDebugMode) {
      print('[ImportLeadsModal._doImport] parsed count: ${parsed.length}, _columnMapping: $_columnMapping, _csvRawRows length: ${_csvRawRows?.length ?? 0}');
    }
    if (parsed.isEmpty) {
      if (kDebugMode) print('[ImportLeadsModal._doImport] no rows to import, returning');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid rows to import'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() {
      _isImporting = true;
      _importError = null;
      _importResult = null;
    });

    try {
      List<dynamic> existing = [];
      try {
        existing = await LeadsService.getExistingLeadsForDuplicateCheck();
      } catch (_) {
        existing = [];
      }
      if (kDebugMode) print('[ImportLeadsModal._doImport] existing leads for duplicate check: ${existing.length}');
      final existingPhones = <String>{};
      final existingEmails = <String>{};
      for (final e in existing) {
        final fm = e['fullMobile']?.toString().trim();
        if (fm != null && fm.isNotEmpty) existingPhones.add(fm.replaceAll(RegExp(r'[^\d]'), ''));
        final em = _normalizeEmail(e['email']?.toString());
        if (em.isNotEmpty) existingEmails.add(em);
      }

      // Within-file: import first occurrence only; 2nd duplicate in file → not imported with reason.
      // Already in DB → not imported with reason.
      final seenPhones = <String>{};
      final seenEmails = <String>{};
      final toImport = <Map<String, dynamic>>[];
      _notImportedWithReason = [];
      _failedWithReason = [];
      _serverSkippedCount = 0;

      for (int i = 0; i < parsed.length; i++) {
        final row = parsed[i];
        final fullMobile = row['fullMobile']?.toString() ?? _normalizePhone(row['mobile']?.toString());
        final email = _normalizeEmail(row['email']?.toString());
        final phoneKey = fullMobile.replaceAll(RegExp(r'[^\d]'), '');
        final name = (row['name'] ?? '').toString().trim();
        final phoneDisplay = fullMobile.isNotEmpty ? fullMobile : (row['mobile']?.toString() ?? '—');
        final emailDisplay = row['email']?.toString().trim() ?? '—';

        String? notImportedReason;
        final phoneInDb = phoneKey.isNotEmpty && existingPhones.contains(phoneKey);
        final phoneInFile = phoneKey.isNotEmpty && seenPhones.contains(phoneKey);
        final emailInDb = email.isNotEmpty && existingEmails.contains(email);
        final emailInFile = email.isNotEmpty && seenEmails.contains(email);
        if (phoneInDb || emailInDb) {
          notImportedReason = 'Duplicate - already exists in leads';
        } else if (phoneInFile || emailInFile) {
          notImportedReason = 'Duplicate in file - first occurrence imported';
        }

        if (notImportedReason != null) {
          _notImportedWithReason.add({
            'sno': '${i + 1}',
            'phone': phoneDisplay,
            'email': emailDisplay,
            'name': name.isEmpty ? '—' : name,
            'reason': notImportedReason,
          });
        } else {
          toImport.add(row);
          if (phoneKey.isNotEmpty) seenPhones.add(phoneKey);
          if (email.isNotEmpty) seenEmails.add(email);
        }
      }

      // Build payload to match backend bulkCreateLeads: name, company?, email?, status?, source?, countryCode, mobile?
      final leadsForApi = toImport.map((r) {
        final name = (r['name'] ?? '').toString().trim();
        final countryCode = (r['countryCode'] ?? '91').toString().trim();
        final mobile = r['mobile']?.toString().trim();
        final map = <String, dynamic>{
          'name': name.isEmpty ? 'Lead' : name,
          'company': (r['company'] ?? '').toString().trim(),
          'status': (r['status'] ?? 'New Lead').toString().trim(),
          'source': (r['source'] ?? 'Website').toString().trim(),
          'countryCode': countryCode.isEmpty ? '91' : countryCode,
        };
        final emailVal = r['email']?.toString().trim();
        if (emailVal != null && emailVal.isNotEmpty) map['email'] = emailVal;
        if (mobile != null && mobile.isNotEmpty) map['mobile'] = mobile;
        return map;
      }).toList();

      if (kDebugMode) {
        print('[ImportLeadsModal._doImport] leadsForApi count: ${leadsForApi.length}, sendAlert: $_sendAlert');
        if (leadsForApi.isNotEmpty) {
          print('[ImportLeadsModal._doImport] first lead for API: ${leadsForApi.first}');
        }
      }

      final res = await LeadsService.bulkCreateLeads(
        leadsForApi,
        duplicateAction: 'skip',
        sendAlert: _sendAlert,
      );

      if (kDebugMode) print('[ImportLeadsModal._doImport] bulkCreateLeads success, moving to step 3');

      final data = res['data'] as Map<String, dynamic>?;
      _serverSkippedCount = (data?['skipped'] ?? 0) as int;
      final errors = data?['errors'] as List<dynamic>? ?? [];
      _failedWithReason = [];
      for (final e in errors) {
        final err = e as Map<String, dynamic>? ?? {};
        final idx = (err['index'] ?? 0) as int;
        final errMsg = (err['error'] ?? 'Unknown error').toString();
        final leadData = err['data'] as Map<String, dynamic>? ?? {};
        _failedWithReason.add({
          'sno': '${idx + 1}',
          'phone': (leadData['mobile'] ?? leadData['fullMobile'] ?? '—').toString(),
          'email': (leadData['email'] ?? '—').toString(),
          'name': (leadData['name'] ?? '—').toString(),
          'reason': errMsg,
        });
      }

      if (mounted) {
        setState(() {
          _isImporting = false;
          _importResult = res;
          _currentStep = 3;
        });
        widget.onSuccess();
        final successCount = (data?['success'] ?? 0) as int;
        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$successCount lead(s) imported and saved.')),
          );
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('[ImportLeadsModal._doImport] error: $e');
        print('[ImportLeadsModal._doImport] stackTrace: $st');
      }
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _isImporting = false;
          _importError = msg;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $msg'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _nextStep() async {
    if (_currentStep == 0) {
      if (_selectedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a file first')),
        );
        return;
      }
      await _loadRawCsv();
      if (!mounted) return;
      if (_importError != null) return;
      setState(() => _currentStep = 1);
      return;
    }
    if (_currentStep == 1) {
      final mapped = _columnMapping.values.toSet();
      if (!mapped.contains(_sysMobile) || !mapped.contains(_sysName)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please map Mobile and Name (required fields).')),
        );
        return;
      }
      setState(() => _currentStep = 2);
      return;
    }
    if (_currentStep == 2) {
      // Preview step: Import is handled by the "Import N Contacts" button, not Next
      return;
    }
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      Navigator.pop(context);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  static const List<String> _csvFormatHeaders = [
    'Country_Code',
    'Mobile_number',
    'Contact_Name',
  ];

  void _showExcelFormatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.table_chart, color: Colors.green),
            SizedBox(width: 8),
            Text('CSV import format'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Use these column headers in the first row of your CSV.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1),
                  },
                  border: TableBorder.symmetric(
                    inside: BorderSide(color: Colors.grey.shade300),
                  ),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade200),
                      children: _csvFormatHeaders
                          .map((h) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Text(h, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Container(
            width: 600,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildStepper(),
                const SizedBox(height: 24),
                Expanded(child: SingleChildScrollView(child: _buildStepContent())),
                const SizedBox(height: 24),
                _buildActions(),
              ],
            ),
          ),
          if (_isImporting)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(height: 16),
                          Text('Importing leads...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Import Leads',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: _showExcelFormatDialog,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Sample CSV',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepper() {
    return Row(
      children: List.generate(_steps.length, (index) {
        final isActive = index == _currentStep;
        final isCompleted = index < _currentStep;
        return Expanded(
          child: Row(
            children: [
              Container(
                // Circle
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive || isCompleted
                      ? Colors.green
                      : Colors.grey.shade200,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isActive || isCompleted ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _steps[index],
                  style: TextStyle(
                    color: isActive ? Colors.black : Colors.grey,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (index < _steps.length - 1)
                Container(
                  width: 20,
                  height: 1,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildUploadStep();
      case 1:
        return _buildMapStep();
      case 2:
        return _buildPreviewStep();
      case 3:
        return _buildImportResultStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildUploadStep() {
    if (_loadingCsv) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Reading CSV...'),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.description_outlined, size: 48, color: Colors.green),
        const SizedBox(height: 16),
        const Text(
          'Import Leads',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Upload a CSV file to import your contacts as leads',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Format: CSV (Excel)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _showExcelFormatDialog,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.table_chart_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'View Excel format',
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_selectedFile != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green),
              borderRadius: BorderRadius.circular(8),
              color: Colors.green.withAlpha(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.file_present, color: Colors.green),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _selectedFile!.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() => _selectedFile = null),
                ),
              ],
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('Select File'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
      ],
    );
  }

  static const List<MapEntry<String, String>> _mapToFieldOptions = [
    MapEntry('', "— Don't map"),
    MapEntry(_sysCountry, 'Country'),
    MapEntry(_sysMobile, 'Mobile *'),
    MapEntry(_sysName, 'Name *'),
  ];

  Widget _buildMapStep() {
    if (_loadingCsv) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Reading CSV...'),
            ],
          ),
        ),
      );
    }
    final headers = _csvHeaders ?? [];
    final sampleRow = (_csvRawRows != null && _csvRawRows!.isNotEmpty) ? _csvRawRows!.first : <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Map Fields',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Map your CSV columns to system fields. Required fields must be mapped.',
          style: TextStyle(fontSize: 13, color: Colors.black87),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(1.8),
            },
            border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey.shade300)),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade200),
                children: [
                  _tableCell('CSV Column', bold: true),
                  _tableCell('Sample Data', bold: true),
                  _tableCell('Map to Field', bold: true),
                ],
              ),
              ...List.generate(headers.length, (i) {
                final sample = i < sampleRow.length ? sampleRow[i] : '';
                final current = _columnMapping[i];
                return TableRow(
                  children: [
                    _tableCell(headers[i]),
                    _tableCell(sample.isEmpty ? '—' : sample),
                    TableCell(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: DropdownButton<String>(
                          value: current ?? '',
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: _mapToFieldOptions
                              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              if (v == null || v.isEmpty) {
                                _columnMapping.remove(i);
                              } else {
                                _columnMapping[i] = v;
                              }
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tableCell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildPreviewStep() {
    final preview = _getPreviewRows();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Preview Data',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Review the mapped data before importing.',
          style: TextStyle(fontSize: 13, color: Colors.black87),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey.shade300)),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade200),
                      children: [
                        _tableCell('Country Code', bold: true),
                        _tableCell('Mobile', bold: true),
                        _tableCell('Name', bold: true),
                      ],
                    ),
                    ...preview.take(20).map((r) => TableRow(
                      children: [
                        _tableCell(r['countryCode'] ?? ''),
                        _tableCell(r['mobile'] ?? ''),
                        _tableCell(r['name'] ?? ''),
                      ],
                    )),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (preview.length > 20)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '... and ${preview.length - 20} more rows',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        const SizedBox(height: 20),
        CheckboxListTile(
          value: _sendAlert,
          onChanged: (v) => setState(() => _sendAlert = v ?? false),
          title: const Text('Send new lead alert message for imported contacts'),
          subtitle: const Text(
            'This will trigger notifications for each successfully imported lead.',
            style: TextStyle(fontSize: 12),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (_importError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _importError!,
                    style: TextStyle(fontSize: 13, color: Colors.red.shade900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImportResultStep() {
    if (_importError != null) {
      return Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(_importError!),
        ],
      );
    }
    final data = _importResult?['data'] as Map<String, dynamic>? ?? _importResult;
    final imported = (data?['success'] ?? _importResult?['imported']) ?? 0;
    final failedCount = (data?['failed'] ?? _importResult?['failed']) ?? 0;
    final hasNotImported = _notImportedWithReason.isNotEmpty;
    final hasFailed = _failedWithReason.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 12),
          Text('Imported: $imported lead(s)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if (_serverSkippedCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Skipped by server (duplicates): $_serverSkippedCount', style: TextStyle(fontSize: 13, color: Colors.orange.shade700)),
            ),
          if (hasNotImported) ...[
            const SizedBox(height: 20),
            Text('Not imported (${_notImportedWithReason.length})', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.orange.shade800)),
            const SizedBox(height: 8),
            Text('Duplicates in file: 2nd occurrence skipped. Already in leads: skipped.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            _buildReasonTable(_notImportedWithReason),
          ],
          if (hasFailed) ...[
            const SizedBox(height: 16),
            Text('Failed ($failedCount)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red.shade700)),
            const SizedBox(height: 8),
            _buildReasonTable(_failedWithReason),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildReasonTable(List<Map<String, String>> rows) {
    if (rows.isEmpty) return const SizedBox();
    final showRows = rows.take(50).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
              columns: const [
                DataColumn(label: Text('S.No', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Reason', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
              rows: showRows.map((r) => DataRow(
                cells: [
                  DataCell(Text(r['sno'] ?? '—')),
                  DataCell(Text((r['phone'] ?? '—').toString())),
                  DataCell(Text((r['email'] ?? '—').toString())),
                  DataCell(Text((r['name'] ?? '—').toString())),
                  DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 200), child: Text((r['reason'] ?? '—').toString(), maxLines: 2, overflow: TextOverflow.ellipsis))),
                ],
              )).toList(),
            ),
          ),
        ),
        if (rows.length > 50)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('... and ${rows.length - 50} more', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
      ],
    );
  }

  Widget _buildActions() {
    if (_currentStep == 3) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      );
    }

    if (_currentStep == 2) {
      final count = _getMappedLeads().length;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(onPressed: _prevStep, child: const Text('Back')),
          ElevatedButton(
            onPressed: _isImporting ? null : _doImport,
            child: Text('Import $count Contact${count == 1 ? '' : 's'}'),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          OutlinedButton(onPressed: _prevStep, child: const Text('Back'))
        else
          const SizedBox(),
        ElevatedButton(
          onPressed: _loadingCsv ? null : _nextStep,
          child: Text(_currentStep == 0 ? 'Next' : 'Preview Data'),
        ),
      ],
    );
  }
}
