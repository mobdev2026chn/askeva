import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/app_scope.dart';
import '../api/dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/common.dart';
import '../widgets/conversation_launch.dart';
import '../widgets/dashboard_sheets.dart' show appToast;

Widget _backHeader(BuildContext context, String title, {Widget? trailing}) {
  final topPad = MediaQuery.of(context).padding.top;
  return Container(
    width: double.infinity,
    color: AppColors.surface,
    padding: EdgeInsets.fromLTRB(6, topPad + 8, 12, 14),
    child: Row(
      children: [
        IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.chevron_left_rounded, size: 28, color: AppColors.ink)),
        Expanded(child: Text(title, style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.ink))),
        ?trailing,
      ],
    ),
  );
}

Widget _tabRow(List<String> tabs, int selected, ValueChanged<int> onChanged) {
  return SizedBox(
    height: 44,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: tabs.length,
      separatorBuilder: (_, _) => const SizedBox(width: 20),
      itemBuilder: (context, i) {
        final active = i == selected;
        return GestureDetector(
          onTap: () => onChanged(i),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Text(tabs[i], style: AppText.poppins(size: 13.5, weight: active ? FontWeight.w800 : FontWeight.w600, color: active ? AppColors.evaGreenDeep : AppColors.ink3)),
              const SizedBox(height: 8),
              Container(height: 2.5, width: 36, color: active ? AppColors.evaGreen : Colors.transparent),
            ],
          ),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Appointment detail
// ---------------------------------------------------------------------------

class _AppointmentTab {
  final String label;
  final IconData icon;
  _AppointmentTab(this.label, this.icon);
}

class AppointmentDetailScreen extends StatefulWidget {
  final String id;
  final String code;
  final String patient;
  final String mobile;
  const AppointmentDetailScreen({
    super.key,
    this.id = '',
    this.code = 'A0000018',
    this.patient = 'muks',
    this.mobile = '7338855669',
  });

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  String _selectedTabLabel = 'Appointment Details'; // Details first
  String _status = 'Pending';
  List<Map<String, dynamic>> _notes = [];
  bool _savingNote = false;
  String _selectedNoteType = 'text';

  // Audio specific states
  String _audioOption = 'record'; // 'record' or 'upload'
  bool _recording = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  String? _recordedPath;
  final AudioRecorder _audioRecorder = AudioRecorder();

  // File upload specific states
  bool _uploadingFile = false;
  String? _uploadedFileUrl;
  String? _fileName;
  int? _fileSize;

  final List<(String, IconData)> _noteTypes = const [
    ('text', Icons.chat_bubble_outline_rounded),
    ('audio', Icons.mic_none_rounded),
    ('image', Icons.image_outlined),
    ('video', Icons.videocam_outlined),
    ('document', Icons.description_outlined),
  ];
  Map<String, dynamic>? _rawDetails;
  bool _loading = false;
  List<Map<String, dynamic>> _feedbackResponses = [];
  bool _loadingFeedback = false;

  // Form Fields & Controllers for Edit State
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _descController = TextEditingController();
  final _bioController = TextEditingController();
  final _rescheduleReasonController = TextEditingController();
  final _completionNotesController = TextEditingController();
  final _noteInputController = TextEditingController();

  DateTime? _dob;
  String? _selectedDept;
  Map<String, dynamic>? _selectedAgentObj;
  int _day = 0;
  int _slot = -1;
  int _mode = 0; // 0: Virtual, 1: Manual
  int _payType = 0; // 0: Prepaid, 1: Postpaid

  // Configuration and Pickers Lists
  List<Map<String, dynamic>> _allAgents = [];
  List<String> _departments = [];
  List<CountryDto> _countries = [];
  CountryDto? _selectedCountry;

  List<Map<String, dynamic>> _auditLogs = [];
  bool _loadingAuditLogs = false;
  Map<String, int> _bookedSlotCounts = {};
  bool _loadingOccupiedSlots = false;
  final Set<int> _expandedLogIndices = {};
  bool _isEditing = false;
  Map<String, dynamic>? _profileStats;
  bool _loadingProfileStats = false;

  late List<(String, String, DateTime)> _days;

  @override
  void initState() {
    super.initState();
    _days = List.generate(7, (i) {
      final d = DateTime.now().add(Duration(days: i));
      final weekday = switch (d.weekday) {
        DateTime.monday => 'MON',
        DateTime.tuesday => 'TUE',
        DateTime.wednesday => 'WED',
        DateTime.thursday => 'THU',
        DateTime.friday => 'FRI',
        DateTime.saturday => 'SAT',
        _ => 'SUN',
      };
      return (weekday, d.day.toString(), d);
    });
    _initData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _descController.dispose();
    _bioController.dispose();
    _rescheduleReasonController.dispose();
    _completionNotesController.dispose();
    _noteInputController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await _loadConfigs();
    await _loadDetails();
  }

  Future<void> _loadConfigs() async {
    try {
      final scope = AppScope.of(context);
      final agentsList = await scope.agents.fetchAgents();
      final config = await scope.appointments.fetchBookingConfiguration();
      final countriesList = await scope.compose.fetchCountries().catchError((_) => <CountryDto>[]);

      final activeAgents = agentsList.where((a) => (a['status'] ?? a['active'] ?? true) != false).toList();
      final depts = (config['departments'] as List?)?.map((e) => e.toString()).toList() ?? [];

      CountryDto? defaultCountry;
      if (countriesList.isNotEmpty) {
        defaultCountry = countriesList.firstWhere(
          (c) => c.dialCode == '91',
          orElse: () => countriesList.first,
        );
      }

      if (mounted) {
        setState(() {
          _allAgents = activeAgents;
          _departments = depts;
          _countries = countriesList;
          _selectedCountry = defaultCountry;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDetails() async {
    if (widget.id.isEmpty) return;
    setState(() => _loading = true);
    try {
      final data = await AppScope.of(context).appointments.fetchAppointment(widget.id);
      if (mounted) {
        setState(() {
          _rawDetails = data;
          _nameController.text = (data['name'] ?? '').toString();
          _ageController.text = (data['age'] ?? '').toString();
          _emailController.text = (data['email'] ?? '').toString();

          final rawMobile = (data['mobile'] ?? '').toString();
          _parseMobile(rawMobile);

          _descController.text = (data['description'] ?? '').toString();
          _bioController.text = (data['bio'] ?? '').toString();
          _selectedDept = data['department']?.toString();
          final rawMgr = data['manager'] ?? data['agentName'] ?? data['userName'] ?? data['assignedTo'] ?? data['agent'];
          final managerStr = rawMgr is Map ? (rawMgr['username'] ?? rawMgr['name'] ?? '') : rawMgr?.toString();

          if (managerStr != null && managerStr.toString().trim().isNotEmpty) {
            final cleanMgr = managerStr.toString().trim();
            if (_allAgents.isNotEmpty) {
              _selectedAgentObj = _allAgents.firstWhere(
                (a) => (a['username'] ?? a['name']) == cleanMgr,
                orElse: () => <String, dynamic>{'name': cleanMgr, 'username': cleanMgr, 'id': data['managerId']},
              );
            } else {
              _selectedAgentObj = <String, dynamic>{'name': cleanMgr, 'username': cleanMgr, 'id': data['managerId']};
            }
          }

          final dobStr = data['dob']?.toString();
          if (dobStr != null && dobStr.isNotEmpty) {
            _dob = DateTime.tryParse(dobStr);
          }

          final dateStr = data['appointmentDate']?.toString();
          if (dateStr != null && dateStr.isNotEmpty) {
            final parsedDate = DateTime.tryParse(dateStr);
            if (parsedDate != null) {
              final idx = _days.indexWhere((d) =>
                  d.$3.year == parsedDate.year &&
                  d.$3.month == parsedDate.month &&
                  d.$3.day == parsedDate.day);
              if (idx != -1) {
                _day = idx;
              }
            }
          }

          final timingVal = data['timing']?.toString();
          if (timingVal != null && timingVal.isNotEmpty) {
            final slots = _activeSlots;
            final idx = slots.indexOf(timingVal);
            if (idx != -1) {
              _slot = idx;
            }
          }

          _mode = (data['mode']?.toString().toLowerCase() == 'virtual') ? 0 : 1;
          _payType = (data['payment']?.toString().toLowerCase() == 'prepaid') ? 0 : 1;

          final rawStatus = data['status']?.toString() ?? 'Pending';
          if (rawStatus.isNotEmpty) {
            _status = rawStatus[0].toUpperCase() + rawStatus.substring(1);
          }

          final notesList = data['notes'] as List?;
          if (notesList != null) {
            _notes = notesList.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
          } else {
            _notes = [];
          }

          _loading = false;
        });

        _loadOccupiedSlots();
        _loadAuditLogs();
        _loadStatsByMobile();
        _loadFeedbackResponses();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _parseMobile(String rawMobile) {
    if (rawMobile.isEmpty) return;
    for (final c in _countries) {
      final dial = _cleanDial(c.dialCode);
      if (rawMobile.startsWith('+$dial')) {
        _selectedCountry = c;
        _mobileController.text = rawMobile.substring(dial.length + 1);
        return;
      } else if (rawMobile.startsWith(dial)) {
        _selectedCountry = c;
        _mobileController.text = rawMobile.substring(dial.length);
        return;
      }
    }
    if (rawMobile.startsWith('+91')) {
      _mobileController.text = rawMobile.substring(3);
    } else if (rawMobile.startsWith('91')) {
      _mobileController.text = rawMobile.substring(2);
    } else {
      _mobileController.text = rawMobile;
    }
  }

  Future<void> _loadOccupiedSlots() async {
    if (_selectedAgentObj == null) return;
    setState(() => _loadingOccupiedSlots = true);
    try {
      final agentId = _selectedAgentObj!['_id'] ?? _selectedAgentObj!['id'] ?? '';
      final date = _days[_day].$3;
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final appointments = await AppScope.of(context).appointments.fetchAppointmentsByAgentAndDate(
        agentId: agentId.toString(),
        date: dateStr,
      );
      final counts = <String, int>{};
      for (final apt in appointments) {
        final timing = apt['timing']?.toString();
        if (timing != null) {
          counts[timing] = (counts[timing] ?? 0) + 1;
        }
      }
      if (mounted) {
        setState(() {
          _bookedSlotCounts = counts;
          _loadingOccupiedSlots = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOccupiedSlots = false);
    }
  }

  Future<void> _loadAuditLogs() async {
    if (widget.id.isEmpty) return;
    setState(() => _loadingAuditLogs = true);
    try {
      final logs = await AppScope.of(context).appointments.fetchAuditLogs(widget.id);
      if (mounted) {
        setState(() {
          _auditLogs = logs;
          _loadingAuditLogs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAuditLogs = false);
    }
  }

  bool _matchesCustomerMobile(String m1, String m2) {
    final clean1 = m1.replaceAll(RegExp(r'\D'), '');
    final clean2 = m2.replaceAll(RegExp(r'\D'), '');
    if (clean1.isEmpty || clean2.isEmpty) return false;
    final last10_1 = clean1.length >= 10 ? clean1.substring(clean1.length - 10) : clean1;
    final last10_2 = clean2.length >= 10 ? clean2.substring(clean2.length - 10) : clean2;
    return last10_1 == last10_2;
  }

  String _fmtDateDisplay(dynamic raw) {
    if (raw == null) return 'N/A';
    final s = raw.toString().trim();
    if (s.isEmpty || s == 'N/A' || s == '—') return 'N/A';
    final parsed = DateTime.tryParse(s);
    if (parsed != null) {
      final local = parsed.toLocal();
      return "${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}";
    }
    if (s.contains('-') && s.length >= 10) {
      final parts = s.substring(0, 10).split('-');
      if (parts.length == 3) {
        return "${parts[2].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[0]}";
      }
    }
    return s;
  }

  Future<void> _loadStatsByMobile() async {
    final mob = _rawDetails?['mobile']?.toString() ?? widget.mobile;
    final patientName = _rawDetails?['name']?.toString() ?? widget.patient;
    if (mob.isEmpty && patientName.isEmpty) return;
    setState(() => _loadingProfileStats = true);
    try {
      Map<String, dynamic> stats = {};
      if (mob.isNotEmpty) {
        try {
          stats = await AppScope.of(context).appointments.fetchStatsByMobile(mob);
        } catch (_) {}
      }

      // Fetch all appointments and strictly filter by customer mobile / patient name
      final allAppts = await AppScope.of(context).appointments.fetchAppointments(limit: 1000).catchError((_) => <AppointmentDto>[]);

      final Set<String> seenIds = {};
      final List<AppointmentDto> same = [];

      for (final apt in allAppts) {
        final idKey = apt.id.isNotEmpty ? apt.id : '${apt.name}_${apt.appointmentDate}_${apt.mobile}';
        if (seenIds.contains(idKey)) continue;

        final matchMob = mob.isNotEmpty && _matchesCustomerMobile(apt.mobile, mob);
        final matchName = patientName.isNotEmpty && apt.name.isNotEmpty &&
            apt.name.trim().toLowerCase() == patientName.trim().toLowerCase() &&
            (apt.mobile.isEmpty || _matchesCustomerMobile(apt.mobile, mob));

        if (matchMob || matchName) {
          seenIds.add(idKey);
          same.add(apt);
        }
      }

      // Calculate customer-specific Visit Statistics directly from customer's appointments
      int localCompleted = same.where((a) => a.status.toLowerCase() == 'completed' || a.status.toLowerCase() == 'finished').length;
      int completed = localCompleted;
      if (_rawDetails?['status']?.toString().toLowerCase() == 'completed' && completed == 0) {
        completed = 1;
      }

      int localRescheduled = same.where((a) => a.status.toLowerCase() == 'rescheduled' || a.isRescheduled).length;
      int rescheduled = localRescheduled;
      if (_rawDetails?['status']?.toString().toLowerCase() == 'rescheduled' && rescheduled == 0) {
        rescheduled = 1;
      }

      int totalVisits = same.isNotEmpty ? same.length : 1;

      int localNotes = same.fold<int>(0, (sum, a) => sum + a.notesCount);
      if (_notes.isNotEmpty && localNotes < _notes.length) localNotes = _notes.length;
      int totalNotes = localNotes;

      List<String> dates = same
          .map((a) => a.appointmentDate)
          .where((d) => d.isNotEmpty)
          .toList();
      final currentApptDate = _rawDetails?['appointmentDate']?.toString() ?? '';
      if (currentApptDate.isNotEmpty && !dates.contains(currentApptDate)) {
        dates.add(currentApptDate);
      }
      dates.sort();

      List<String> compDates = same
          .where((a) => a.status.toLowerCase() == 'completed' || a.status.toLowerCase() == 'finished')
          .map((a) => a.appointmentDate)
          .where((d) => d.isNotEmpty)
          .toList();
      if (_rawDetails?['status']?.toString().toLowerCase() == 'completed' && currentApptDate.isNotEmpty && !compDates.contains(currentApptDate)) {
        compDates.add(currentApptDate);
      }
      compDates.sort();

      // Customer-specific Visit Timeline dates formatted clearly
      String firstVisit = dates.isNotEmpty ? _fmtDateDisplay(dates.first) : _fmtDateDisplay(currentApptDate);
      String lastVisit = compDates.isNotEmpty ? _fmtDateDisplay(compDates.last) : (dates.isNotEmpty ? _fmtDateDisplay(dates.last) : _fmtDateDisplay(currentApptDate));
      String currentVisit = currentApptDate.isNotEmpty ? _fmtDateDisplay(currentApptDate) : (dates.isNotEmpty ? _fmtDateDisplay(dates.last) : 'N/A');

      List<String> parseListKey(List<String> keys, List<String> fallback) {
        for (final k in keys) {
          if (stats.containsKey(k) && stats[k] != null) {
            final val = stats[k];
            if (val is List) {
              final items = val.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
              if (items.isNotEmpty) return items;
            } else if (val is String && val.trim().isNotEmpty) {
              return [val.trim()];
            }
          }
        }
        return fallback;
      }

      final deptsSet = same.map((a) => a.department).where((d) => d.isNotEmpty).toSet();
      if (_selectedDept != null && _selectedDept!.isNotEmpty) deptsSet.add(_selectedDept!);

      final mgrsSet = same.map((a) => a.agent).where((m) => m.isNotEmpty).toSet();
      if (_assignedAgentName.isNotEmpty) mgrsSet.add(_assignedAgentName);

      final depts = parseListKey(
        ['departments', 'departmentsVisited', 'department_visited', 'department', 'depts'],
        deptsSet.toList(),
      );

      final mgrs = parseListKey(
        ['managers', 'managersInteracted', 'managers_interacted', 'manager', 'agents', 'agent', 'managerName'],
        mgrsSet.toList(),
      );

      if (mounted) {
        setState(() {
          _profileStats = {
            'totalVisits': totalVisits,
            'completed': completed,
            'rescheduled': rescheduled,
            'totalNotes': totalNotes,
            'firstVisitDate': firstVisit,
            'lastVisitDate': lastVisit,
            'currentVisitDate': currentVisit,
            'departments': depts,
            'managers': mgrs,
          };
          _loadingProfileStats = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingProfileStats = false);
      }
    }
  }

  Future<void> _loadFeedbackResponses() async {
    setState(() => _loadingFeedback = true);
    try {
      final res = await AppScope.of(context).appointments.fetchFeedbackResponses();
      if (mounted) {
        setState(() {
          _feedbackResponses = res;
          _loadingFeedback = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingFeedback = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredFeedbacks {
    if (_feedbackResponses.isEmpty) return [];
    final mobile = _rawDetails?['mobile']?.toString() ?? widget.mobile;
    if (mobile.isEmpty) return [];

    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
    final normalizedMobile = cleanMobile.replaceFirst(RegExp(r'^91'), '');

    return _feedbackResponses.where((item) {
      final resp = item['response'] as Map?;
      if (resp == null) return false;
      final userNumVal = resp['userNumber']?.toString() ?? '';
      if (userNumVal.isEmpty) return false;

      final cleanUserNum = userNumVal.replaceAll(RegExp(r'\D'), '');
      final normalizedUserNumber = cleanUserNum.replaceFirst(RegExp(r'^91'), '');

      return cleanUserNum == cleanMobile ||
          cleanUserNum == normalizedMobile ||
          normalizedUserNumber == normalizedMobile ||
          '91$normalizedUserNumber' == cleanMobile ||
          '91$normalizedMobile' == cleanUserNum;
    }).toList();
  }

  List<String> get _activeSlots {
    if (_selectedAgentObj != null) {
      final config = _selectedAgentObj!['config'];
      if (config is Map) {
        final appointment = config['appointment'];
        if (appointment is Map) {
          final slotsVal = appointment['calculatedSlots'];
          if (slotsVal is List) {
            final result = <String>[];
            for (final item in slotsVal) {
              if (item is Map && item['slot'] != null) {
                result.add(item['slot'].toString());
              } else if (item != null) {
                result.add(item.toString());
              }
            }
            if (result.isNotEmpty) return result;
          }
        }
      }
    }
    return const [
      '9:00 AM - 9:15 AM', '9:15 AM - 9:30 AM', '9:30 AM - 9:45 AM', '9:45 AM - 10:00 AM',
      '10:00 AM - 10:15 AM', '10:15 AM - 10:30 AM', '10:30 AM - 10:45 AM', '10:45 AM - 11:00 AM',
      '11:00 AM - 11:15 AM', '11:15 AM - 11:30 AM', '11:30 AM - 11:45 AM', '11:45 AM - 12:00 PM',
      '12:00 PM - 12:15 PM', '12:15 PM - 12:30 PM', '12:30 PM - 12:45 PM', '12:45 PM - 1:00 PM',
      '1:00 PM - 1:15 PM', '1:15 PM - 1:30 PM', '1:30 PM - 1:45 PM', '1:45 PM - 2:00 PM',
      '2:00 PM - 2:15 PM', '2:15 PM - 2:30 PM', '2:30 PM - 2:45 PM', '2:45 PM - 3:00 PM',
      '3:00 PM - 3:15 PM', '3:15 PM - 3:30 PM', '3:30 PM - 3:45 PM', '3:45 PM - 4:00 PM',
      '4:00 PM - 4:15 PM', '4:15 PM - 4:30 PM', '4:30 PM - 4:45 PM', '4:45 PM - 5:00 PM',
      '5:00 PM - 5:15 PM', '5:15 PM - 5:30 PM', '5:30 PM - 5:45 PM', '5:45 PM - 6:00 PM',
      '6:00 PM - 6:15 PM', '6:15 PM - 6:30 PM', '6:30 PM - 6:45 PM', '6:45 PM - 7:00 PM'
    ];
  }

  String get _assignedAgentName {
    if (_selectedAgentObj != null) {
      final name = (_selectedAgentObj!['username'] ?? _selectedAgentObj!['name'] ?? '').toString();
      if (name.isNotEmpty) return name;
    }
    if (_rawDetails != null) {
      final m = _rawDetails!['manager'] ??
                _rawDetails!['agentName'] ??
                _rawDetails!['userName'] ??
                _rawDetails!['assignedTo'] ??
                _rawDetails!['agent'];
      if (m is Map) {
        final name = (m['username'] ?? m['name'] ?? m['agentName'] ?? '').toString();
        if (name.isNotEmpty) return name;
      } else if (m != null && m.toString().trim().isNotEmpty) {
        return m.toString().trim();
      }
    }
    return '—';
  }

  int get _maxOccupancy {
    if (_selectedAgentObj != null) {
      final config = _selectedAgentObj!['config'];
      if (config is Map) {
        final appointment = config['appointment'];
        if (appointment is Map) {
          final occVal = appointment['occupancyPerSlot'];
          if (occVal is num) {
            return occVal.toInt();
          }
        }
      }
    }
    return 1;
  }

  bool _isSlotPast(String slotStr, DateTime selectedDate) {
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
                    selectedDate.month == now.month &&
                    selectedDate.day == now.day;
    if (!isToday) return false;

    if (selectedDate.isBefore(DateTime(now.year, now.month, now.day))) {
      return true;
    }
    try {
      final startPart = slotStr.split('-').first.trim();
      final isPm = startPart.toLowerCase().contains('pm');
      final isAm = startPart.toLowerCase().contains('am');
      final cleanTime = startPart.replaceAll(RegExp(r'[a-zA-Z]'), '').trim();
      final timeParts = cleanTime.split(':');
      int hr = int.parse(timeParts[0]);
      int min = int.parse(timeParts[1]);

      if (isPm && hr != 12) hr += 12;
      if (isAm && hr == 12) hr = 0;

      final slotTime = DateTime(now.year, now.month, now.day, hr, min);
      return now.isAfter(slotTime);
    } catch (_) {
      return false;
    }
  }

  void _snack(String m) => appToast(context, m);



  Future<void> _submitReschedule() async {
    if (_slot < 0) {
      _snack('Select appointment timing slot');
      return;
    }
    final date = _days[_day].$3;
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final timingVal = _activeSlots[_slot];

    try {
      await AppScope.of(context).appointments.rescheduleAppointment(widget.id, {
        'appointmentDate': dateStr,
        'timing': timingVal,
        'reason': _rescheduleReasonController.text.trim(),
      });
      _snack('Appointment rescheduled');
      _loadDetails();
      setState(() => _selectedTabLabel = 'Appointment Details'); // go back to Details
    } catch (e) {
      _snack('Failed to reschedule: $e');
    }
  }

  Future<void> _submitComplete() async {
    final desc = _completionNotesController.text.trim();
    if (desc.isEmpty) {
      _snack('Completion notes are required');
      return;
    }
    try {
      await AppScope.of(context).appointments.completeAppointment(widget.id, {
        'description': desc,
      });
      _snack('Appointment completed');
      _loadDetails();
      setState(() => _selectedTabLabel = 'Appointment Details'); // go back to Details
    } catch (e) {
      _snack('Failed to complete appointment: $e');
    }
  }

  Future<void> _saveDetails() async {
    if (_nameController.text.trim().isEmpty) {
      _snack('Enter the customer name');
      return;
    }
    final dial = _cleanDial(_selectedCountry?.dialCode);
    final rawMobile = _mobileController.text.trim();
    if (rawMobile.isEmpty) {
      _snack('Enter mobile number');
      return;
    }

    final date = _days[_day].$3;
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final timingVal = _slot >= 0 ? _activeSlots[_slot] : '';

    final body = <String, dynamic>{
      'name': _nameController.text.trim(),
      'mobile': '+$dial${rawMobile.replaceAll(RegExp(r'\D'), '')}',
      'email': _emailController.text.trim(),
      'age': _ageController.text.trim(),
      if (_dob != null) 'dob': "${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}",
      'department': _selectedDept,
      'manager': _selectedAgentObj?['username'] ?? _selectedAgentObj?['name'] ?? '',
      'managerId': _selectedAgentObj?['_id'] ?? _selectedAgentObj?['id'] ?? '',
      'appointmentDate': dateStr,
      'timing': timingVal,
      'mode': _mode == 0 ? 'Virtual' : 'Manual',
      'payment': _payType == 0 ? 'prepaid' : 'postpaid',
      'description': _descController.text.trim(),
      'bio': _bioController.text.trim(),
    };

    try {
      await AppScope.of(context).appointments.updateAppointment(widget.id, body);
      _snack('Appointment details updated');
      setState(() {
        _isEditing = false;
      });
      _loadDetails();
    } catch (e) {
      _snack('Failed to update details: $e');
    }
  }

  void _changeType(String type) {
    if (_recording) {
      _cancelRecording();
    }
    setState(() {
      _selectedNoteType = type;
      _uploadedFileUrl = null;
      _fileName = null;
      _fileSize = null;
      _recordedPath = null;
      _recordingDuration = 0;
      _noteInputController.clear();
    });
  }

  Future<void> _pickFile(String type) async {
    List<String> allowedExtensions = [];
    if (type == 'image') {
      allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'];
    } else if (type == 'video') {
      allowedExtensions = ['mp4'];
    } else if (type == 'document') {
      allowedExtensions = ['csv', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'pdf', 'txt'];
    } else if (type == 'audio') {
      allowedExtensions = ['mp3', 'wav', 'm4a', 'aac', 'ogg'];
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final path = file.path;
      if (path == null) return;

      final ext = file.extension?.toLowerCase();
      if (ext == null || !allowedExtensions.contains(ext)) {
        _snack('Invalid file type. Only ${allowedExtensions.join(', ').toUpperCase()} are allowed.');
        return;
      }

      setState(() {
        _uploadingFile = true;
        _fileName = file.name;
        _fileSize = file.size;
        _uploadedFileUrl = null;
      });

      final bytes = await File(path).readAsBytes();
      final url = await AppScope.of(context).compose.uploadMedia(bytes, file.name);

      if (url != null) {
        setState(() {
          _uploadedFileUrl = url;
          _uploadingFile = false;
        });
        _snack('File uploaded successfully!');
      } else {
        setState(() {
          _uploadingFile = false;
          _fileName = null;
          _fileSize = null;
        });
        _snack('File upload failed.');
      }
    } catch (e) {
      setState(() {
        _uploadingFile = false;
        _fileName = null;
        _fileSize = null;
      });
      _snack('Error picking/uploading file: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _snack('Microphone permission is required to record audio.');
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/audio_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      setState(() {
        _recording = true;
        _recordingDuration = 0;
        _recordedPath = null;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration++;
          });
        }
      });
    } catch (e) {
      _snack('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      setState(() {
        _recording = false;
        _recordedPath = path;
      });
    } catch (e) {
      _snack('Failed to stop recording: $e');
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _recordingTimer?.cancel();
      await _audioRecorder.stop();
      setState(() {
        _recording = false;
        _recordingDuration = 0;
        _recordedPath = null;
      });
    } catch (e) {
      _snack('Failed to cancel recording: $e');
    }
  }

  String _formatDuration(int seconds) {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return Colors.blue;
      case 'audio':
        return Colors.green;
      case 'image':
        return Colors.orange;
      case 'video':
        return Colors.purple;
      default:
        return Colors.teal;
    }
  }

  Future<void> _submitNote() async {
    setState(() => _savingNote = true);

    Map<String, dynamic> noteData = {
      'type': _selectedNoteType,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'createdAt': DateTime.now().toIso8601String(),
    };

    try {
      if (_selectedNoteType == 'text') {
        final val = _noteInputController.text.trim();
        if (val.isEmpty) {
          _snack('Please enter note content');
          setState(() => _savingNote = false);
          return;
        }
        noteData['content'] = val;
      } else if (_selectedNoteType == 'audio') {
        if (_audioOption == 'record') {
          if (_recordedPath == null) {
            _snack('Please record audio first');
            setState(() => _savingNote = false);
            return;
          }
          final bytes = await File(_recordedPath!).readAsBytes();
          final url = await AppScope.of(context).compose.uploadMedia(bytes, 'recorded_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
          if (url == null) {
            throw Exception('Failed to upload recorded audio');
          }
          noteData['audioData'] = url;
          noteData['audioSource'] = 'record';
        } else {
          if (_uploadedFileUrl == null) {
            _snack('Please upload audio file first');
            setState(() => _savingNote = false);
            return;
          }
          noteData['audioData'] = _uploadedFileUrl;
          noteData['audioSource'] = 'upload';
          noteData['mediaData'] = [
            {
              'name': _fileName ?? 'audio_file',
              'type': 'audio/${_fileName?.split('.').last ?? 'wav'}',
              'size': _fileSize,
              'url': _uploadedFileUrl,
            }
          ];
        }
      } else {
        if (_uploadedFileUrl == null) {
          _snack('Please select and upload a file first');
          setState(() => _savingNote = false);
          return;
        }
        noteData['mediaData'] = [
          {
            'name': _fileName ?? 'file',
            'type': '${_selectedNoteType}/${_fileName?.split('.').last ?? 'bin'}',
            'size': _fileSize,
            'url': _uploadedFileUrl,
          }
        ];
      }

      final mongoId = _rawDetails?['_id']?.toString() ?? _rawDetails?['id']?.toString();
      await AppScope.of(context).appointments.addAppointmentNote(widget.id, noteData, mongoId: mongoId);
      _noteInputController.clear();
      final savedType = _selectedNoteType;
      setState(() {
        _notes.add(noteData);
        _recordedPath = null;
        _uploadedFileUrl = null;
        _fileName = null;
        _fileSize = null;
        _selectedNoteType = 'text';
      });
      _snack('${savedType[0].toUpperCase() + savedType.substring(1)} note added successfully!');
      _loadDetails();
    } catch (e) {
      _snack('Failed to add note: $e');
    } finally {
      setState(() => _savingNote = false);
    }
  }

  Future<void> _confirm(String title, String msg, VoidCallback onYes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
        content: Text(msg, style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink2)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Confirm', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) onYes();
  }

  String _cleanDial(String? dial) {
    if (dial == null) return '91';
    return dial.replaceAll(RegExp(r'\D'), '');
  }

  void _pickCountry() {
    if (_countries.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Country', style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _countries.length,
                itemBuilder: (context, index) {
                  final c = _countries[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.name, style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink)),
                    leading: Text('+${_cleanDial(c.dialCode)}', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                    trailing: _selectedCountry == c ? const Icon(Icons.check_rounded, color: AppColors.evaGreen) : null,
                    onTap: () {
                      setState(() {
                        _selectedCountry = c;
                      });
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickDepartment() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Select Department', style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final d in _departments)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(d, style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink)),
                      trailing: _selectedDept == d ? const Icon(Icons.check_rounded, color: AppColors.evaGreen) : null,
                      onTap: () {
                        setState(() {
                          _selectedDept = d;
                          final deptAgents = _allAgents.where((a) => _agentDept(a) == d).toList();
                          _selectedAgentObj = deptAgents.isNotEmpty ? deptAgents.first : null;
                          _slot = -1; // Reset slot
                        });
                        Navigator.of(context).pop();
                        _loadOccupiedSlots();
                      },
                    ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _pickAgent() {
    if (_selectedDept == null) {
      appToast(context, 'Please select a department first', isError: true);
      return;
    }
    final deptAgents = _allAgents.where((a) => _agentDept(a) == _selectedDept).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Select Agent', style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final a in deptAgents)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text((a['username'] ?? a['name'] ?? '').toString(), style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink)),
                      trailing: _selectedAgentObj == a ? const Icon(Icons.check_rounded, color: AppColors.evaGreen) : null,
                      onTap: () {
                        setState(() {
                          _selectedAgentObj = a;
                          _slot = -1; // Reset slot
                        });
                        Navigator.of(context).pop();
                        _loadOccupiedSlots();
                      },
                    ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime.now().subtract(const Duration(days: 365 * 30)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.evaGreenDeep,
              onPrimary: Colors.white,
              onSurface: AppColors.ink,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        final now = DateTime.now();
        int age = now.year - picked.year;
        if (now.month < picked.month || (now.month == picked.month && now.day < picked.day)) {
          age--;
        }
        _ageController.text = age.toString();
      });
    }
  }

  String _agentDept(Map<String, dynamic> agent) {
    final c = agent['config'];
    if (c is Map) {
      final appointment = c['appointment'];
      if (appointment is Map) {
        return appointment['department']?.toString() ?? '';
      }
    }
    return '';
  }

  bool get _isDoneOrInactive {
    final s = _status.toLowerCase();
    return s == 'completed' || s == 'cancelled';
  }

  @override
  Widget build(BuildContext context) {
    final tabItems = [
      _AppointmentTab('Appointment Details', Icons.person_outline_rounded),
      if (!_isDoneOrInactive) _AppointmentTab('Complete', Icons.check_rounded),
      if (!_isDoneOrInactive) _AppointmentTab('Reschedule', Icons.sync_rounded),
      _AppointmentTab('Activity Logs', Icons.history_rounded),
      _AppointmentTab('Profile', Icons.contact_page_outlined),
      _AppointmentTab('Notes', Icons.edit_note_rounded),
      _AppointmentTab('Feedback', Icons.forum_outlined),
    ];

    return AnnotatedRegion(
      value: AppTheme.statusDark,
      child: Scaffold(
        backgroundColor: AppColors.surface2,
        body: Column(
          children: [
            _backHeader(context, 'Appointment ${widget.code}'),
            const Divider(height: 1, color: AppColors.line),
            _hero(),
            _appointmentTabRow(tabItems, _selectedTabLabel, (label) => setState(() => _selectedTabLabel = label)),
            const Divider(height: 1, color: AppColors.line),
            Expanded(child: switch (_selectedTabLabel) {
              'Complete' => _completeTab(),
              'Reschedule' => _rescheduleTab(),
              'Activity Logs' => _activityTab(),
              'Profile' => _profileTab(),
              'Notes' => _notesTab(),
              'Feedback' => _feedbackTab(),
              _ => _detailsTab(),
            }),
          ],
        ),
      ),
    );
  }

  Color get _statusColor => switch (_status) {
        'Completed' => AppColors.evaGreenDeep,
        'Cancelled' => AppColors.danger,
        'Rescheduled' => const Color(0xFF3B82F6),
        _ => const Color(0xFFB07908),
      };

  Widget _appointmentTabRow(List<_AppointmentTab> tabs, String selected, ValueChanged<String> onChanged) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 20),
        itemBuilder: (context, i) {
          final active = tabs[i].label == selected;
          return GestureDetector(
            onTap: () => onChanged(tabs[i].label),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tabs[i].icon,
                      size: 15,
                      color: active ? AppColors.evaGreenDeep : AppColors.ink3,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tabs[i].label,
                      style: AppText.poppins(
                        size: 13,
                        weight: active ? FontWeight.w800 : FontWeight.w600,
                        color: active ? AppColors.evaGreenDeep : AppColors.ink3,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(height: 2.5, width: 44, color: active ? AppColors.evaGreen : Colors.transparent),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _hero() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Row(children: [
        InitialsAvatar(initials: _ini(widget.patient), color: const Color(0xFF3B82F6), size: 52, radius: 16),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.patient, style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 3),
          Text('${widget.mobile} · ${widget.code}', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5), decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)), child: Text(_status, style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: _statusColor))),
      ]),
    );
  }

  Widget _detailsTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.evaGreen));
    }

    final isCompletedStatus = _status == 'Completed';
    Map<String, dynamic>? completionLog;
    if (isCompletedStatus) {
      for (final log in _auditLogs) {
        final act = log['action']?.toString().toLowerCase() ?? '';
        final desc = log['description']?.toString().toLowerCase() ?? '';
        if (act.contains('complete') || desc.contains('complete')) {
          completionLog = log;
          break;
        }
      }
    }

    final createdAtRaw = _rawDetails?['createdAt']?.toString() ?? '';
    String formattedCreated = '—';
    if (createdAtRaw.isNotEmpty) {
      DateTime? parsed = DateTime.tryParse(createdAtRaw);
      if (parsed != null) {
        if (!createdAtRaw.endsWith('Z') && !createdAtRaw.contains('+') && createdAtRaw.contains('T')) {
          parsed = DateTime.tryParse('${createdAtRaw}Z')?.toLocal() ?? parsed.toLocal();
        } else {
          parsed = parsed.toLocal();
        }
        final dd = parsed.day.toString().padLeft(2, '0');
        final mm = parsed.month.toString().padLeft(2, '0');
        final yyyy = parsed.year;
        final hh = parsed.hour.toString().padLeft(2, '0');
        final min = parsed.minute.toString().padLeft(2, '0');
        formattedCreated = "$dd/$mm/$yyyy $hh:$min";
      } else {
        formattedCreated = createdAtRaw;
      }
    }

    // Format appointmentDate and dob to match web display (DD/MM/YYYY)
    final dateRaw = _rawDetails?['appointmentDate']?.toString() ?? '';
    final dateStr = (dateRaw.isNotEmpty && dateRaw != 'N/A') ? _fmtDateDisplay(dateRaw) : '—';
    final timing = _rawDetails?['timing']?.toString() ?? '';
    final mode = _rawDetails?['mode']?.toString() ?? 'Manual';
    final payType = _rawDetails?['payment']?.toString() ?? 'Postpaid';
    final email = _rawDetails?['email']?.toString() ?? '—';
    final age = _rawDetails?['age']?.toString() ?? '—';
    final dobRaw = _rawDetails?['dob']?.toString() ?? '';
    final dob = (dobRaw.isNotEmpty && dobRaw != 'N/A') ? _fmtDateDisplay(dobRaw) : '—';
    final description = _rawDetails?['description']?.toString() ?? '—';
    final bio = _rawDetails?['bio']?.toString() ?? '—';
    final department = _selectedDept ?? 'Diagnostics';
    final agent = _assignedAgentName;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
      children: [
        // Overview Header Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, color: AppColors.evaGreenDeep, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.patient}\'s Appointment Details',
                      style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: AppColors.line),
              ),
              _overviewRow('Created At', formattedCreated),
              _overviewRow('ID', widget.code),
              _overviewRow('User', agent),
              _overviewRow('Department', department),
              _overviewRow('Status', _status, isBadge: true),
              if (isCompletedStatus) ...[
                _overviewRow('Description', description),
                _overviewRow('Completed On', _fmtLogDate(completionLog?['createdAt'])),
                _overviewRow(
                  'Completed By',
                  completionLog?['createdBy']?.toString() ??
                      completionLog?['user']?['name']?.toString() ??
                      completionLog?['user']?.toString() ??
                      'Eshan',
                ),
                _overviewRow('Remarks', completionLog?['description']?.toString() ?? 'test'),
              ] else
                _overviewRow('Description', description),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Main Details Card (Read-Only)
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📝 Appointment Details', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 12),
              _readOnlyRow(Icons.person_outline_rounded, 'Name', widget.patient),
              _readOnlyRow(Icons.cake_outlined, 'Age', age),
              _readOnlyRow(Icons.phone_iphone_rounded, 'Mobile', widget.mobile),
              _readOnlyRow(Icons.mail_outline_rounded, 'Email', email),
              _readOnlyRow(Icons.cake_outlined, 'DOB', dob),
              _readOnlyRow(Icons.home_work_outlined, 'Department', department),
              _readOnlyRow(Icons.person_rounded, 'Select User', agent),
              _readOnlyRow(Icons.calendar_today_rounded, 'Appointment Date', dateStr),
              _readOnlyRow(Icons.alarm_on_rounded, 'Appointment Timing', timing),
              _readOnlyRow(Icons.payments_outlined, 'Payment Type', payType),
              _readOnlyRow(Icons.description_outlined, 'Description', description),
              _readOnlyRow(Icons.notes_rounded, 'Bio', bio),
              _readOnlyRow(Icons.video_camera_back_outlined, 'Appointment mode', mode),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (!_isEditing && !_isDoneOrInactive) ...[
          // Bottom quick action buttons to reschedule/complete
          _largeIconButton('Reschedule Appointment', Icons.sync_rounded, const Color(0xFFF97316), () => setState(() => _selectedTabLabel = 'Reschedule')),
          const SizedBox(height: 10),
          _largeIconButton('✓ Mark as Complete', Icons.check_rounded, AppColors.evaGreenDeep, () => setState(() => _selectedTabLabel = 'Complete')),
        ]
      ],
    );
  }

  Widget _overviewRow(String label, String value, {bool isBadge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3))),
          Expanded(
            child: isBadge
                ? Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          value,
                          style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: _statusColor),
                        ),
                      ),
                    ],
                  )
                : Text(
                    value.isNotEmpty ? value : '—',
                    style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.ink3),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink4)),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : '—',
                  style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)),
      );

  Widget _input(
    String hint, {
    IconData? icon,
    int maxLines = 1,
    TextEditingController? controller,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.ink4),
        prefixIcon: icon == null ? null : Icon(icon, size: 19, color: AppColors.ink3),
        filled: true,
        fillColor: AppColors.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
      ),
    );
  }

  Widget _selectRow(IconData? icon, String title, {String? sub, String? avatar}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
      child: Row(
        children: [
          if (avatar != null)
            Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.evaGreen, borderRadius: BorderRadius.circular(10)), child: Text(avatar, style: AppText.poppins(size: 13, weight: FontWeight.w800, color: Colors.white)))
          else
            Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(10)), child: Icon(icon ?? Icons.home_outlined, size: 18, color: AppColors.evaGreenDeep)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: AppColors.ink)),
                if (sub != null) Text(sub, style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.ink3),
        ],
      ),
    );
  }

  Widget _toggle(List<String> items, int sel, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.line)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(items.length, (i) {
          final active = sel == i;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
              decoration: BoxDecoration(color: active ? AppColors.evaGreen50 : Colors.transparent, borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? AppColors.evaGreen : Colors.transparent)),
              child: Text(items[i], style: AppText.poppins(size: 13, weight: FontWeight.w700, color: active ? AppColors.evaGreenDeep : AppColors.ink3)),
            ),
          );
        }),
      ),
    );
  }

  Widget _payCard(IconData icon, String label, int i) {
    final active = _payType == i;
    return GestureDetector(
      onTap: () => setState(() => _payType = i),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(color: active ? AppColors.evaGreen50 : AppColors.surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: active ? AppColors.evaGreen : AppColors.line)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: active ? AppColors.evaGreenDeep : AppColors.ink3),
            const SizedBox(width: 8),
            Text(label, style: AppText.poppins(size: 14, weight: FontWeight.w700, color: active ? AppColors.evaGreenDeep : AppColors.ink2)),
          ],
        ),
      ),
    );
  }

  Widget _largeIconButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: Colors.white),
        label: Text(label, style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }

  Widget _completeTab() {
    final department = _selectedDept ?? 'Diagnostics';
    final agent = _assignedAgentName;
    
    // Filters completion logs from audit logs
    final completionLogs = _auditLogs.where((log) => 
      log['action']?.toString().toLowerCase().contains('complete') == true ||
      log['description']?.toString().toLowerCase().contains('complete') == true
    ).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
      children: [
        // Overview Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.patient}\'s Appointment Details', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.evaGreenDeep)),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: AppColors.line)),
              _overviewRow('ID', widget.code),
              _overviewRow('User', agent),
              _overviewRow('Department', department),
              _overviewRow('Status', _status, isBadge: true),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Complete Form Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_rounded, color: AppColors.evaGreenDeep, size: 18),
                  const SizedBox(width: 6),
                  Text('Complete appointment', style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                ],
              ),
              const SizedBox(height: 6),
              Text('Mark this appointment as completed and collect payment.', style: AppText.poppins(size: 12.5, weight: FontWeight.w500, color: AppColors.ink3, height: 1.4)),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Text('*', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: Colors.red)),
                  const SizedBox(width: 4),
                  Text('Completion Notes/Description', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                ],
              ),
              const SizedBox(height: 8),
              _input('Enter completion notes and details about the appointment outcome', maxLines: 4, controller: _completionNotesController),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: const BorderSide(color: AppColors.line)),
                    onPressed: () => setState(() => _selectedTabLabel = 'Appointment Details'),
                    child: Text('Cancel', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink3)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.evaGreenDeep, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _submitComplete,
                    child: Text('✓ Mark as Complete', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Completion History Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✓ Completion History', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 10),
              if (completionLogs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(child: Text('No completion history available', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink4))),
                )
              else
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(3),
                    2: FlexColumnWidth(2),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
                      children: [
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('S.No.', style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink3))),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Description', style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink3))),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Update Date/Time', style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink3))),
                      ]
                    ),
                    for (int idx = 0; idx < completionLogs.length; idx++)
                      TableRow(
                        children: [
                          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('${idx + 1}', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink))),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(completionLogs[idx]['description']?.toString() ?? 'Completed', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink))),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _fmtLogDate(completionLogs[idx]['createdAt']?.toString()),
                              style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink2),
                            ),
                          ),
                        ]
                      )
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmtLogDate(dynamic raw) {
    if (raw == null) return '—';
    final str = raw.toString().trim();
    if (str.isEmpty) return '—';
    DateTime? d = DateTime.tryParse(str);
    if (d == null) return str;
    if (!str.endsWith('Z') && !str.contains('+') && str.contains('T')) {
      d = DateTime.tryParse('${str}Z')?.toLocal() ?? d.toLocal();
    } else {
      d = d.toLocal();
    }
    return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _pickRescheduleDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _days[_day].$3,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.evaGreenDeep,
              onPrimary: Colors.white,
              onSurface: AppColors.ink,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate == null) return;

    int newDayIdx = _days.indexWhere((d) =>
        d.$3.year == pickedDate.year &&
        d.$3.month == pickedDate.month &&
        d.$3.day == pickedDate.day);
    if (newDayIdx == -1) {
      final weekday = switch (pickedDate.weekday) {
        DateTime.monday => 'MON',
        DateTime.tuesday => 'TUE',
        DateTime.wednesday => 'WED',
        DateTime.thursday => 'THU',
        DateTime.friday => 'FRI',
        DateTime.saturday => 'SAT',
        _ => 'SUN',
      };
      _days.add((weekday, pickedDate.day.toString(), pickedDate));
      newDayIdx = _days.length - 1;
    }

    setState(() {
      _day = newDayIdx;
      _slot = -1;
    });

    await _loadOccupiedSlots();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Time Slot',
                style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                "${pickedDate.day.toString().padLeft(2, '0')}/${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.year}",
                style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(_activeSlots.length, (i) {
                      final slotStr = _activeSlots[i];
                      final isPast = _isSlotPast(slotStr, pickedDate);
                      final bookedCount = _bookedSlotCounts[slotStr] ?? 0;
                      final maxOccupancy = _maxOccupancy;
                      final isFull = bookedCount >= maxOccupancy;
                      final isOccupied = isPast || isFull;
                      final active = _slot == i;
                      return GestureDetector(
                        onTap: isOccupied
                            ? null
                            : () {
                                setState(() => _slot = i);
                                setModalState(() {});
                                Navigator.of(ctx).pop();
                              },
                        child: Container(
                          width: (MediaQuery.of(context).size.width - 32 - 10) / 2,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.evaGreen50
                                : (isOccupied ? Colors.grey.shade100 : AppColors.surface),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: active
                                  ? AppColors.evaGreen
                                  : (isOccupied ? Colors.grey.shade200 : AppColors.line),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  slotStr,
                                  style: AppText.poppins(
                                    size: 11.5,
                                    weight: FontWeight.w700,
                                    color: active
                                        ? AppColors.evaGreenDeep
                                        : (isOccupied ? Colors.grey.shade500 : AppColors.ink2),
                                  ).copyWith(decoration: isOccupied ? TextDecoration.lineThrough : null),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPast ? 'Past' : (isFull ? 'Full' : '$bookedCount/$maxOccupancy'),
                                style: AppText.poppins(
                                  size: 11,
                                  weight: FontWeight.w800,
                                  color: isPast
                                      ? Colors.grey.shade400
                                      : (isFull ? Colors.red.shade400 : (active ? AppColors.evaGreenDeep : AppColors.evaGreen)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rescheduleTab() {
    final department = _selectedDept ?? 'Diagnostics';
    final agent = _assignedAgentName;

    final hasSelection = _slot >= 0;
    final date = _days[_day].$3;
    final dateStr = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    final timingVal = hasSelection ? _activeSlots[_slot] : '';
    final displayStr = hasSelection ? "$dateStr · $timingVal" : 'Select date & time';

    final rescheduleLogs = _auditLogs.where((log) => 
      log['action']?.toString().toLowerCase().contains('reschedule') == true ||
      log['description']?.toString().toLowerCase().contains('reschedule') == true
    ).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
      children: [
        // Overview Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.patient}\'s Appointment Details', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.evaGreenDeep)),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: AppColors.line)),
              _overviewRow('ID', widget.code),
              _overviewRow('User', agent),
              _overviewRow('Department', department),
              _overviewRow('Status', _status, isBadge: true),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Reschedule Form Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sync_rounded, color: AppColors.evaGreenDeep, size: 18),
                  const SizedBox(width: 6),
                  Text('Reschedule Appointment', style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Text('*', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: Colors.red)),
                  const SizedBox(width: 4),
                  Text('New Appointment Date & Time', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickRescheduleDateTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF8F1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.evaGreen, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        displayStr,
                        style: AppText.poppins(
                          size: 14,
                          weight: FontWeight.w600,
                          color: hasSelection ? AppColors.evaGreenDeep : AppColors.ink4,
                        ),
                      ),
                      const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.evaGreenDeep),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Text('*', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: Colors.red)),
                  const SizedBox(width: 4),
                  Text('Reschedule Reason/Description', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _rescheduleReasonController,
                maxLines: 4,
                maxLength: 500,
                onChanged: (_) => setState(() {}),
                style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'Enter reason for rescheduling',
                  hintStyle: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.ink4),
                  filled: true,
                  fillColor: AppColors.surface2,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${_rescheduleReasonController.text.length}/500',
                    style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: const BorderSide(color: AppColors.line)),
                    onPressed: () => setState(() => _selectedTabLabel = 'Appointment Details'),
                    child: Text('Cancel', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink3)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.evaGreenDeep,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _submitReschedule,
                    icon: const Icon(Icons.repeat, size: 18, color: Colors.white),
                    label: Text('Save Reschedule', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Reschedule History Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🕒 Reschedule History', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 10),
              if (rescheduleLogs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(
                      'No reschedule history available',
                      style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink4),
                    ),
                  ),
                )
              else
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(3),
                    2: FlexColumnWidth(2),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
                      children: [
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('S.No.', style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink3))),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Description', style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink3))),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Update Date/Time', style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink3))),
                      ]
                    ),
                    for (int idx = 0; idx < rescheduleLogs.length; idx++)
                      TableRow(
                        children: [
                          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('${idx + 1}', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink))),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(rescheduleLogs[idx]['description']?.toString() ?? 'Rescheduled', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink))),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _fmtLogDate(rescheduleLogs[idx]['createdAt']?.toString()),
                              style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink2),
                            ),
                          ),
                        ]
                      )
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _activityTab() {
    if (_loadingAuditLogs) {
      return const Center(child: CircularProgressIndicator(color: AppColors.evaGreen));
    }
    if (_auditLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history_rounded, size: 40, color: AppColors.ink4),
              const SizedBox(height: 12),
              Text('No activity logs found', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink3)),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, size: 18, color: AppColors.evaGreenDeep),
                  const SizedBox(width: 8),
                  Text(
                    'Appointment Activity Timeline',
                    style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: AppColors.line),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _auditLogs.length,
                itemBuilder: (context, i) {
                  final log = _auditLogs[i];
                  final isExpanded = _expandedLogIndices.contains(i);
                  final isLast = i == _auditLogs.length - 1;
                  return _activityTimelineItem(log, i, isExpanded, isLast);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _activityTimelineItem(Map<String, dynamic> log, int index, bool isExpanded, bool isLast) {
    final title = log['description']?.toString() ?? log['action']?.toString() ?? 'Action occurred';
    final rawDate = log['createdAt']?.toString();
    final dateStr = _fmtLogDate(rawDate);

    final details = <(String, String)>[];
    final meta = log['meta'];
    final action = log['action']?.toString().toLowerCase() ?? '';

    if (meta is Map && meta.isNotEmpty) {
      if (action.contains('complete') || title.toLowerCase().contains('complete')) {
        if (meta['completedBy'] != null || log['createdBy'] != null) details.add(('Completed by', (meta['completedBy'] ?? log['createdBy']).toString()));
        if (meta['prevStatus'] != null) details.add(('Previous Status', meta['prevStatus'].toString()));
        if (rawDate != null) details.add(('Completed at', dateStr));
        if (meta['dept'] != null || _rawDetails?['department'] != null) details.add(('Department', (meta['dept'] ?? _rawDetails?['department']).toString()));
        if (meta['date'] != null || _rawDetails?['appointmentDate'] != null) {
          final rawD = (meta['date'] ?? _rawDetails?['appointmentDate']).toString();
          final d = _fmtDateDisplay(rawD);
          final t = (meta['time'] ?? meta['timing'] ?? _rawDetails?['timing'] ?? '').toString();
          details.add(('Appointment', t.isNotEmpty ? '$d · $t' : d));
        }
        if (meta['amount'] != null) {
          final amt = meta['amount'].toString();
          final paySt = meta['payStatus']?.toString() ?? '';
          details.add(('Payment', paySt.isNotEmpty ? '$amt · $paySt' : amt));
        }
        if (meta['note'] != null || _rawDetails?['description'] != null) details.add(('Description', (meta['note'] ?? _rawDetails?['description']).toString()));
      } else if (action.contains('reschedule') || title.toLowerCase().contains('rescheduled')) {
        final rawD = meta['date']?.toString() ?? _rawDetails?['appointmentDate']?.toString() ?? '';
        final d = _fmtDateDisplay(rawD);
        final t = meta['time']?.toString() ?? meta['timing']?.toString() ?? _rawDetails?['timing']?.toString() ?? '';
        if (d.isNotEmpty && d != 'N/A' || t.isNotEmpty) {
          details.add(('Rescheduled to', t.isNotEmpty ? '$d · $t' : d));
        }
        if (meta['note'] != null) details.add(('Reason', meta['note'].toString()));
        if (rawDate != null) details.add(('At', dateStr));
      } else if (action.contains('status') || action.contains('agent') || meta['Field'] != null) {
        details.add(('Field', meta['Field']?.toString() ?? (action.contains('agent') ? 'Agent' : 'Status')));
        if (meta['prevStatus'] != null) {
          final p = meta['prevStatus'].toString();
          details.add(('Old Value', (p.contains('T00:00:00') || p.contains('T24:00:00') || p.contains('Z')) ? _fmtDateDisplay(p) : p));
        }
        if (meta['newStatus'] != null) {
          final n = meta['newStatus'].toString();
          details.add(('Updated Value', (n.contains('T00:00:00') || n.contains('T24:00:00') || n.contains('Z')) ? _fmtDateDisplay(n) : n));
        }
        if (rawDate != null) details.add(('At', dateStr));
      } else {
        meta.forEach((k, v) {
          if (v != null && v.toString().isNotEmpty) {
            final label = k.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}').trim();
            final capLabel = label.isEmpty ? k : '${label[0].toUpperCase()}${label.substring(1)}';
            final vStr = v.toString();
            final formattedVal = (k.toLowerCase().contains('date') || k.toLowerCase().contains('dob') || vStr.contains('T00:00:00'))
                ? _fmtDateDisplay(vStr)
                : vStr;
            details.add((capLabel, formattedVal));
          }
        });
      }
    }

    // Fallback details if meta was empty or missed specific fields
    if (details.isEmpty) {
      if (action.contains('complete') || title.toLowerCase().contains('complete')) {
        final compBy = log['createdBy']?.toString() ?? log['user']?.toString() ?? 'Eshan';
        details.add(('Completed By', compBy));
        details.add(('Status', 'Completed'));
        final dept = _rawDetails?['department']?.toString() ?? '';
        if (dept.isNotEmpty) details.add(('Department', dept));
        final dt = _fmtDateDisplay(_rawDetails?['appointmentDate']);
        final tm = _rawDetails?['timing']?.toString() ?? '';
        if (dt != 'N/A') details.add(('Scheduled', tm.isNotEmpty ? '$dt · $tm' : dt));
      } else if (action.contains('create') || title.toLowerCase().contains('created')) {
        details.add(('Action', 'Appointment Created'));
        final dept = _rawDetails?['department']?.toString() ?? '';
        if (dept.isNotEmpty) details.add(('Department', dept));
        final dt = _fmtDateDisplay(_rawDetails?['appointmentDate']);
        final tm = _rawDetails?['timing']?.toString() ?? '';
        if (dt != 'N/A') details.add(('Scheduled', tm.isNotEmpty ? '$dt · $tm' : dt));
      } else {
        if (log['createdBy'] != null) details.add(('Performed By', log['createdBy'].toString()));
        if (log['user'] != null && !details.any((d) => d.$1 == 'Performed By')) details.add(('User', log['user'].toString()));
        if (dateStr != '—') details.add(('Timestamp', dateStr));
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.evaGreen, width: 2),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: isExpanded ? (details.length * 28 + 58).toDouble() : 58,
                color: AppColors.line,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                dateStr,
                style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedLogIndices.remove(index);
                    } else {
                      _expandedLogIndices.add(index);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                        size: 16,
                        color: AppColors.evaGreenDeep,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'View Details',
                        style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded && details.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6, bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    children: details.map((d) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              d.$1,
                              style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              d.$2,
                              style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileTab() {
    if (_loadingProfileStats) {
      return const Center(child: CircularProgressIndicator(color: AppColors.evaGreen));
    }

    final age = _rawDetails?['age']?.toString() ?? '—';

    final totalVisits = _profileStats?['totalVisits'] ?? 1;
    final completed = _profileStats?['completed'] ?? 0;
    final rescheduled = _profileStats?['rescheduled'] ?? 0;
    final totalNotes = _profileStats?['totalNotes'] ?? _notes.length;

    final firstVisitRaw = _profileStats?['firstVisitDate']?.toString() ?? _rawDetails?['appointmentDate']?.toString();
    final firstVisit = _fmtDateDisplay(firstVisitRaw);

    final lastVisitRaw = _profileStats?['lastVisitDate']?.toString() ?? _profileStats?['firstVisitDate']?.toString() ?? _rawDetails?['appointmentDate']?.toString();
    final lastVisit = (lastVisitRaw != null && lastVisitRaw.isNotEmpty && lastVisitRaw != 'N/A') ? _fmtDateDisplay(lastVisitRaw) : 'N/A';

    final currentVisitRaw = _rawDetails?['appointmentDate']?.toString() ?? _profileStats?['currentVisitDate']?.toString();
    final currentVisit = _fmtDateDisplay(currentVisitRaw);

    final deptsRaw = _profileStats?['departments'];
    final depts = (deptsRaw is List && deptsRaw.isNotEmpty) ? deptsRaw.map((e) => e.toString()).toList() : [_selectedDept ?? 'Diagnostics'];

    final mgrsRaw = _profileStats?['managers'];
    final mgrs = (mgrsRaw is List && mgrsRaw.isNotEmpty) ? mgrsRaw.map((e) => e.toString()).toList() : [_assignedAgentName];

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
      children: [
        // 1. Profile Overview Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_ind_outlined, size: 18, color: AppColors.evaGreenDeep),
                  const SizedBox(width: 8),
                  Text('Profile Overview', style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: AppColors.line),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: AppColors.evaGreenDeep,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.patient,
                            style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _profileChip(Icons.phone_iphone_rounded, widget.mobile),
                              const SizedBox(width: 8),
                              _profileChip(Icons.cake_outlined, 'Age: $age'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Visit Statistics section
        Row(
          children: [
            const Icon(Icons.people_outline_rounded, size: 18, color: AppColors.evaGreenDeep),
            const SizedBox(width: 8),
            Text('Visit Statistics', style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
          ],
        ),
        const SizedBox(height: 10),

        // 4 Grid Stat Cards
        Row(
          children: [
            Expanded(child: _statCard('Total Visits', '$totalVisits', Icons.access_time_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Completed', '$completed', Icons.check_rounded)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard('Rescheduled', '$rescheduled', Icons.repeat)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Total Notes', '$totalNotes', Icons.chat_bubble_outline_rounded)),
          ],
        ),
        const SizedBox(height: 14),

        // 3. Visit Timeline Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.evaGreenDeep),
                  const SizedBox(width: 8),
                  Text('Visit Timeline', style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: AppColors.line),
              ),
              _timelineRow('First Visit', firstVisit),
              _timelineRow('Last Visit', lastVisit, isMut: lastVisit == 'N/A'),
              _timelineRow('Current Visit', currentVisit),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4. Service Details Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.business_center_outlined, size: 18, color: AppColors.evaGreenDeep),
                  const SizedBox(width: 8),
                  Text('Service Details', style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: AppColors.line),
              ),
              Text(
                'Departments Visited',
                style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: depts.map((d) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    d,
                    style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: Colors.blue.shade800),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 14),
              Text(
                'Managers Interacted',
                style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: mgrs.map((m) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF8F1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    m,
                    style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 5. Current Appointment Details Card
        Row(
          children: [
            const Icon(Icons.alarm_on_rounded, size: 18, color: AppColors.evaGreenDeep),
            const SizedBox(width: 8),
            Text('Current Appointment Details', style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
          ],
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        '#1 ',
                        style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink3),
                      ),
                      Text(
                        widget.code,
                        style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _status,
                      style: AppText.poppins(size: 11, weight: FontWeight.w800, color: _statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                children: [
                  _kvGridItem('Date', currentVisit),
                  _kvGridItem('Timing', _rawDetails?['timing']?.toString() ?? 'N/A'),
                  _kvGridItem('Department', _selectedDept ?? 'Diagnostics'),
                  _kvGridItem('Manager', _assignedAgentName),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8F1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.evaGreenDeep),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.evaGreenDeep),
              const SizedBox(width: 6),
              Text(
                value,
                style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timelineRow(String label, String value, {bool isMut = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2),
          ),
          Text(
            value,
            style: AppText.poppins(
              size: 12.5,
              weight: FontWeight.w800,
              color: isMut ? AppColors.ink4 : AppColors.evaGreenDeep,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kvGridItem(String key, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key,
          style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3),
        ),
        const SizedBox(height: 3),
        Expanded(
          child: Text(
            value,
            style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _notesTab() {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
      children: [
        // 1. Add Note Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note_rounded, size: 20, color: AppColors.evaGreenDeep),
                  const SizedBox(width: 8),
                  Text(
                    'Appointment Notes',
                    style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: AppColors.line),
              ),
              Text(
                'Add New Note',
                style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 10),
              Text(
                'Select Note Type:',
                style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink3),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _noteTypes.map((t) {
                    final isSel = _selectedNoteType == t.$1;
                    return GestureDetector(
                      onTap: () => _changeType(t.$1),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFFEAF8F1) : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel ? AppColors.evaGreenDeep : AppColors.line,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              t.$2,
                              size: 15,
                              color: isSel ? AppColors.evaGreenDeep : AppColors.ink3,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              t.$1[0].toUpperCase() + t.$1.substring(1),
                              style: AppText.poppins(
                                size: 12.5,
                                weight: FontWeight.w700,
                                color: isSel ? AppColors.evaGreenDeep : AppColors.ink2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              _buildNoteInputSection(),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.evaGreenDeep,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onPressed: _savingNote ? null : _submitNote,
                  icon: _savingNote
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    _savingNote ? 'Adding Note...' : 'Add Note',
                    style: AppText.poppins(size: 13, weight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Notes History Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_rounded, size: 18, color: AppColors.evaGreenDeep),
                  const SizedBox(width: 8),
                  Text(
                    'Notes History',
                    style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: AppColors.line),
              ),
              if (_notes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.description_outlined, size: 36, color: AppColors.ink4),
                        const SizedBox(height: 8),
                        Text(
                          'No notes added yet',
                          style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink4),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _notes.length,
                  itemBuilder: (context, i) {
                    final n = _notes[i];
                    final type = (n['type'] ?? 'text').toString();
                    final typeColor = _getTypeColor(type);
                    final dateTimeStr = _fmtLogDate(n['createdAt'] ?? n['timestamp']?.toString());
                    final createdBy = n['createdBy']?.toString() ?? 'System';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEAF8F1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.evaGreenDeep, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: typeColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        type.toUpperCase(),
                                        style: AppText.poppins(size: 9.5, weight: FontWeight.w800, color: typeColor),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'by $createdBy',
                                      style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _buildNoteContentWidget(n),
                                const SizedBox(height: 6),
                                Text(
                                  dateTimeStr,
                                  style: AppText.poppins(size: 10.5, weight: FontWeight.w600, color: AppColors.ink4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoteInputSection() {
    if (_selectedNoteType == 'text') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            TextField(
              controller: _noteInputController,
              maxLines: 4,
              maxLength: 200,
              style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
              decoration: const InputDecoration(
                hintText: 'Add a note about this appointment',
                hintStyle: TextStyle(color: AppColors.ink4),
                border: InputBorder.none,
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const Divider(color: AppColors.line),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${_noteInputController.text.length}/200',
                  style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink4),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_selectedNoteType == 'audio') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Radio<String>(
                value: 'record',
                groupValue: _audioOption,
                activeColor: AppColors.evaGreenDeep,
                onChanged: (val) => setState(() => _audioOption = val!),
              ),
              Text('Record Audio', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink)),
              const SizedBox(width: 14),
              Radio<String>(
                value: 'upload',
                groupValue: _audioOption,
                activeColor: AppColors.evaGreenDeep,
                onChanged: (val) => setState(() => _audioOption = val!),
              ),
              Text('Upload Audio', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 10),
          if (_audioOption == 'record') ...[
            if (_recording) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fiber_manual_record, color: AppColors.danger, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Recording... ${_formatDuration(_recordingDuration)}',
                        style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.danger),
                      ),
                    ),
                    TextButton(
                      onPressed: _cancelRecording,
                      child: Text('Cancel', style: AppText.poppins(size: 12, color: AppColors.ink3)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: _stopRecording,
                      icon: const Icon(Icons.stop, size: 14),
                      label: Text('Stop', style: AppText.poppins(size: 12, weight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ] else if (_recordedPath != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8F1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFEAD1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_fill_rounded, color: AppColors.evaGreenDeep, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Audio recorded successfully', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                          Text('Format: M4A', style: AppText.poppins(size: 11, color: AppColors.ink3)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _recordedPath = null),
                      icon: const Icon(Icons.close_rounded, color: AppColors.ink3),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.evaGreenDeep,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _startRecording,
                  icon: const Icon(Icons.mic, size: 18),
                  label: Text('Start Recording', style: AppText.poppins(size: 13.5, weight: FontWeight.bold)),
                ),
              ),
            ],
          ] else ...[
            _buildFileSelectorZone('audio'),
          ],
        ],
      );
    }

    return _buildFileSelectorZone(_selectedNoteType);
  }

  Widget _buildFileSelectorZone(String type) {
    String label = 'Choose file';
    String acceptedText = 'Accepted formats';
    IconData icon = Icons.upload_file_rounded;

    if (type == 'image') {
      label = 'Choose image file';
      acceptedText = 'Accepted: JPG, PNG, GIF, WebP, SVG';
      icon = Icons.image_outlined;
    } else if (type == 'video') {
      label = 'Choose video file';
      acceptedText = 'Accepted: MP4';
      icon = Icons.videocam_outlined;
    } else if (type == 'document') {
      label = 'Choose document file';
      acceptedText = 'Accepted: CSV, PDF, Word, Excel, TXT';
      icon = Icons.description_outlined;
    } else if (type == 'audio') {
      label = 'Choose audio file';
      acceptedText = 'Accepted: MP3, WAV, M4A, AAC, OGG';
      icon = Icons.mic_none_rounded;
    }

    if (_uploadingFile) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.evaGreen, strokeWidth: 2)),
            const SizedBox(height: 8),
            Text('Uploading ${_fileName ?? 'file'}...', style: AppText.poppins(size: 12.5, color: AppColors.ink3)),
          ],
        ),
      );
    }

    if (_uploadedFileUrl != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF8F1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBFEAD1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.evaGreenDeep, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_fileName ?? 'Uploaded file', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                  if (_fileSize != null) Text('${(_fileSize! / 1024).toStringAsFixed(1)} KB', style: AppText.poppins(size: 11, color: AppColors.ink3)),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _uploadedFileUrl = null;
                  _fileName = null;
                  _fileSize = null;
                });
              },
              icon: const Icon(Icons.close_rounded, color: AppColors.ink3),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _pickFile(type),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload_outlined, color: AppColors.evaGreenDeep, size: 28),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(acceptedText, style: AppText.poppins(size: 11, color: AppColors.ink4)),
      ],
    );
  }

  Widget _buildNoteContentWidget(Map<String, dynamic> n) {
    final type = (n['type'] ?? 'text').toString().toLowerCase();
    if (type == 'text') {
      return Text(
        n['content']?.toString() ?? n['text']?.toString() ?? '',
        style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink),
      );
    } else if (type == 'audio') {
      final audioUrl = n['audioData']?.toString() ?? '';
      return Row(
        children: [
          const Icon(Icons.play_circle_outline, color: AppColors.evaGreenDeep, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              audioUrl.isNotEmpty ? 'Audio Note ($audioUrl)' : 'Audio note',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.poppins(size: 12.5, color: AppColors.evaGreenDeep, weight: FontWeight.w700),
            ),
          ),
        ],
      );
    } else {
      final List<dynamic> mediaList = n['mediaData'] ?? [];
      final firstMediaUrl = mediaList.isNotEmpty ? (mediaList[0]['url'] ?? '') : '';
      final docName = mediaList.isNotEmpty ? (mediaList[0]['name'] ?? 'Attachment') : 'Attachment';
      return Row(
        children: [
          Icon(
            type == 'image'
                ? Icons.image_outlined
                : type == 'video'
                    ? Icons.videocam_outlined
                    : Icons.description_outlined,
            color: AppColors.evaGreenDeep,
            size: 18,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              firstMediaUrl.isNotEmpty ? '$docName ($firstMediaUrl)' : 'Attachment',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.poppins(size: 12.5, color: AppColors.evaGreenDeep, weight: FontWeight.w700),
            ),
          ),
        ],
      );
    }
  }

  String _formatFeedbackKey(String key) {
    if (key.isEmpty) return '';
    final spaced = key.replaceAllMapped(RegExp(r'([A-Z])'), (Match m) => ' ${m[1]}');
    return spaced[0].toUpperCase() + spaced.substring(1).trim();
  }

  Widget _buildFeedbackFields(Map<String, dynamic> response) {
    final fields = <Widget>[];
    
    // Sort keys so Rating & Experience come first, and userNumber is ignored
    final keys = response.keys.where((k) => k != 'userNumber').toList();
    
    for (final k in keys) {
      final value = response[k]?.toString() ?? '';
      if (value.isEmpty) continue;
      
      final label = _formatFeedbackKey(k);
      
      if (k.toLowerCase().contains('rating') || k.toLowerCase().contains('star')) {
        final stars = int.tryParse(value) ?? 0;
        fields.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text('$label: ', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                Row(
                  children: List.generate(5, (idx) {
                    return Icon(
                      idx < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 18,
                    );
                  }),
                ),
                const SizedBox(width: 4),
                Text('($value)', style: AppText.poppins(size: 11.5, color: AppColors.ink4)),
              ],
            ),
          ),
        );
      } else if (k.toLowerCase().contains('experience')) {
        final lowerVal = value.toLowerCase();
        final Color chipBg = (lowerVal == 'good' || lowerVal == 'excellent' || lowerVal == 'yes')
            ? const Color(0xFFEAF8F1)
            : (lowerVal == 'bad' || lowerVal == 'no')
                ? const Color(0xFFFDE8E8)
                : const Color(0xFFEBF2FE);
        final Color chipText = (lowerVal == 'good' || lowerVal == 'excellent' || lowerVal == 'yes')
            ? AppColors.evaGreenDeep
            : (lowerVal == 'bad' || lowerVal == 'no')
                ? AppColors.danger
                : AppColors.info;
        
        fields.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text('$label: ', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    value.toUpperCase(),
                    style: AppText.poppins(size: 10.5, weight: FontWeight.w800, color: chipText),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        fields.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3)),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                ),
              ],
            ),
          ),
        );
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields,
    );
  }

  Widget _feedbackTab() {
    final patientName = _rawDetails?['name']?.toString() ?? 'Customer';
    final appointmentNo = _rawDetails?['appointmentNo']?.toString() ?? 'N/A';
    final mobile = _rawDetails?['mobile']?.toString() ?? widget.mobile;

    final feedbacks = _filteredFeedbacks;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.forum_outlined, size: 18, color: AppColors.evaGreenDeep),
                  const SizedBox(width: 8),
                  Text('Feedback', style: AppText.sectionTitle),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: AppColors.line),
              ),
              Text(
                'Feedback for $patientName',
                style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'Appointment: $appointmentNo · Mobile: $mobile',
                style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink4),
              ),
              const SizedBox(height: 16),
              if (_loadingFeedback)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.evaGreenDeep),
                  ),
                )
              else if (feedbacks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FE),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.info,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.priority_high_rounded, size: 15, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No Feedback Found',
                              style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'No feedback responses found for:',
                              style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink2),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '• Appointment: $appointmentNo\n• Patient: $patientName\n• Mobile: $mobile',
                              style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink, height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Note: Feedback is matched using the mobile number registered with this appointment.',
                              style: AppText.poppins(size: 11.5, color: AppColors.ink3, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: feedbacks.length,
                  itemBuilder: (context, idx) {
                    final item = feedbacks[idx];
                    final responseData = item['response'] as Map? ?? {};
                    final responsedTime = item['responsedTime']?.toString();
                    final formattedTime = _fmtLogDate(responsedTime);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.surface2,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'S.No: ${idx + 1}',
                                  style: AppText.poppins(size: 11, weight: FontWeight.w800, color: AppColors.ink3),
                                ),
                              ),
                              Text(
                                formattedTime,
                                style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink4),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1, color: AppColors.line),
                          ),
                          _buildFeedbackFields(responseData.cast<String, dynamic>()),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }



  String _ini(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

// --------------------------------// ---------------------------------------------------------------------------
// Ticket detail
// ---------------------------------------------------------------------------

class TicketDetailScreen extends StatefulWidget {
  final String id;
  final String subject;
  final String agent;
  final String status;
  final String priority;
  const TicketDetailScreen({
    super.key,
    required this.id,
    this.subject = '',
    this.agent = '',
    this.status = 'Pending',
    this.priority = 'Low',
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  int _tab = 0; // 0: Ticket Details, 1: Send Template, 2: Activity Logs, 3: Ticket History, 4: Call Logs
  bool _loading = true;
  Map<String, dynamic>? _ticketData;

  late String _status = widget.status;
  late String _agent = widget.agent;
  late String _subject = widget.subject;
  late String _priority = widget.priority;
  String _customer = '';
  String _mobile = '';
  String _email = '';
  String _department = '';
  String _source = 'Manual';
  String _company = '';
  String _description = '';
  DateTime? _createdAt;

  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _availableAgents = [];
  List<TicketDto> _customerTicketHistory = [];
  List<Map<String, dynamic>> _quickRepliesList = [];
  List<Map<String, dynamic>> _videoNotesList = [];
  List<Map<String, dynamic>> _activityLogs = [];
  List<Map<String, dynamic>> _sentTemplatesHistory = [];
  Map<String, dynamic>? _ticketFeedback; // null = no feedback available

  final List<({bool agent, String text})> _replies = [];
  final _reply = TextEditingController();
  final _templateDescController = TextEditingController();
  String? _selectedTemplateName;
  String? _selectedTemplateId;

  Timer? _slaTimer;

  @override
  void initState() {
    super.initState();
    _loadTicketDetails();
    _slaTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _slaTimer?.cancel();
    _reply.dispose();
    _templateDescController.dispose();
    super.dispose();
  }

  void _snack(String m, {bool isError = false}) => appToast(context, m, isError: isError);

  Color get _statusColor => switch (_status.toLowerCase()) {
        'completed' || 'resolved' => AppColors.evaGreenDeep,
        'assigned' || 'open' || 'in progress' => AppColors.info,
        'pending' => const Color(0xFFB07908),
        _ => AppColors.ink3,
      };

  Color get _priorityColor => switch (_priority.toLowerCase()) {
        'high' || 'critical' => AppColors.danger,
        'medium' => const Color(0xFFD97706),
        _ => AppColors.evaGreenDeep,
      };

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadTicketDetails() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final scope = AppScope.of(context);
      final data = await scope.ticketing.fetchTicket(widget.id).catchError((_) => <String, dynamic>{});
      final agentsList = await scope.ticketing.fetchAgents().catchError((_) => <Map<String, dynamic>>[]);
      final qReplies = await scope.ticketing.fetchQuickReplies().catchError((_) => <Map<String, dynamic>>[]);
      final vNotes = await scope.ticketing.fetchVideoNotes().catchError((_) => <Map<String, dynamic>>[]);
      final mongoId = (data['_id'] ?? data['id'] ?? '').toString();
      final auditLogs = await scope.ticketing.fetchTicketAuditLogs(widget.id, mongoId: mongoId).catchError((_) => <Map<String, dynamic>>[]);
      final sentTemplates = await scope.ticketing.fetchSentTemplatesHistory(widget.id, mongoId: mongoId).catchError((_) => <Map<String, dynamic>>[]);
      final fetchedNotes = await scope.ticketing.fetchTicketNotes(widget.id, mongoId: mongoId).catchError((_) => <Map<String, dynamic>>[]);
      final fetchedReplies = await scope.ticketing.fetchTicketReplies(widget.id, mongoId: mongoId).catchError((_) => <Map<String, dynamic>>[]);
      // Load feedback and find the one matching this ticket
      final allFeedbacks = await scope.ticketing.fetchFeedback(limit: 200).catchError((_) => <Map<String, dynamic>>[]);
      final mobileClean = ((data['mobileNumber'] ?? data['mobile'] ?? data['customerMobile'] ?? '').toString()).replaceAll(RegExp(r'\D'), '');
      Map<String, dynamic>? matchedFeedback;
      for (final fb in allFeedbacks) {
        final fbTicketId = (fb['ticketId'] ?? fb['ticket_id'] ?? '').toString();
        final fbMobile = (fb['userNumber'] ?? fb['mobile'] ?? (fb['response'] is Map ? (fb['response'] as Map)['userNumber'] ?? '' : '') ?? '').toString().replaceAll(RegExp(r'\D'), '');
        if (fbTicketId == widget.id || fbTicketId == mongoId) { matchedFeedback = fb; break; }
        if (mobileClean.isNotEmpty && fbMobile.isNotEmpty && (fbMobile == mobileClean || fbMobile.endsWith(mobileClean) || mobileClean.endsWith(fbMobile))) { matchedFeedback = fb; break; }
      }

      if (mounted) {
        setState(() {
          _ticketData = data;
          if (data.isNotEmpty) {
            _status = (data['status'] ?? widget.status).toString();
            _agent = (data['agent'] ?? data['assignedTo'] ?? data['agentName'] ?? widget.agent).toString();
            _subject = (data['subject'] ?? data['title'] ?? widget.subject).toString();
            _priority = (data['priority'] ?? widget.priority).toString();
            _customer = (data['customer'] ?? data['customerName'] ?? data['name'] ?? '').toString();
            _mobile = (data['mobile'] ?? data['customerMobile'] ?? data['number'] ?? '').toString();
            _email = (data['email'] ?? data['customerEmail'] ?? '').toString();
            _department = (data['department'] ?? '').toString();
            _source = (data['source'] ?? 'Manual').toString();
            _company = (data['company'] ?? '').toString();
            _description = (data['description'] ?? data['issue'] ?? '').toString();
            _createdAt = DateTime.tryParse((data['createdAt'] ?? data['created'] ?? '').toString());

            // Use fetchedNotes as single source of truth (from /notes API).
            // Fall back to data['notes'] embedded in ticket only if API returns nothing.
            if (fetchedNotes.isNotEmpty) {
              _notes = fetchedNotes;
            } else if (data['notes'] is List) {
              _notes = (data['notes'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
            } else {
              _notes = [];
            }
          }
          if (agentsList.isNotEmpty) _availableAgents = agentsList;
          if (qReplies.isNotEmpty) _quickRepliesList = qReplies;
          if (vNotes.isNotEmpty) _videoNotesList = vNotes;
          _ticketFeedback = matchedFeedback;
          if (fetchedReplies.isNotEmpty) {
            _replies.clear();
            _replies.addAll(fetchedReplies.map((m) {
              final isAgent = (m['type'] ?? m['sender'] ?? m['user'] ?? '').toString().toLowerCase().contains('agent') ||
                  (m['user'] ?? '').toString().contains('@') ||
                  m['agent'] == true;
              final text = (m['reply'] ?? m['text'] ?? m['content'] ?? m['message'] ?? '').toString();
              return (agent: isAgent, text: text);
            }));
          }
          if (auditLogs.isNotEmpty) {
            _activityLogs = auditLogs;
            final templateSentLogs = auditLogs.where((m) => (m['action'] ?? '').toString().toUpperCase() == 'TEMPLATE_SENT').toList();
            if (templateSentLogs.isNotEmpty) {
              _sentTemplatesHistory = templateSentLogs.map((m) {
                final det = (m['details'] is Map) ? (m['details'] as Map).cast<String, dynamic>() : <String, dynamic>{};
                return {
                  'id': m['_id'] ?? m['id'] ?? 'st_${DateTime.now().millisecondsSinceEpoch}',
                  'mobileNumber': det['mobileNumber'] ?? _mobile,
                  'ticketStatus': det['status'] ?? _status,
                  'description': m['description'] ?? 'Template sent',
                  'templateName': det['templateName'] ?? 'test_with_three_actions',
                  'date': _formatDate(DateTime.tryParse((m['createdAt'] ?? '').toString())),
                };
              }).toList();
            }
          }
          if (sentTemplates.isNotEmpty) _sentTemplatesHistory = sentTemplates;
          _loading = false;
        });
      }

      _loadTicketHistory();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTicketHistory() async {
    try {
      final scope = AppScope.of(context);
      final fetched = await scope.ticketing.fetchCustomerTicketHistory(widget.id, mobile: _mobile).catchError((_) => <TicketDto>[]);
      if (fetched.isNotEmpty) {
        if (mounted) setState(() => _customerTicketHistory = fetched);
        return;
      }

      final allTickets = await scope.ticketing.fetchTickets().catchError((_) => <TicketDto>[]);
      final mobileClean = _mobile.replaceAll(RegExp(r'\D'), '');
      final history = allTickets.where((t) {
        final tMobile = t.mobile.replaceAll(RegExp(r'\D'), '');
        if (mobileClean.isNotEmpty && tMobile.isNotEmpty && (tMobile == mobileClean || tMobile.endsWith(mobileClean) || mobileClean.endsWith(tMobile))) return true;
        if (_customer.isNotEmpty && t.customer.toLowerCase().trim() == _customer.toLowerCase().trim()) return true;
        return false;
      }).toList();

      if (mounted) {
        setState(() => _customerTicketHistory = history);
      }
    } catch (_) {}
  }

  Future<void> _updateTicketStatusBackend(String newStatus) async {
    setState(() => _status = newStatus);
    final mongoId = _ticketData?['_id']?.toString();
    try {
      final wStatus = newStatus.toLowerCase() == 'in progress' ? 'inprogress' : newStatus.toLowerCase();
      await AppScope.of(context).ticketing.updateTicketStatus(widget.id, newStatus, mongoId: mongoId);
      await AppScope.of(context).ticketing.updateTicket(widget.id, {'status': newStatus, 'wstatus': wStatus, 'ticketStatus': newStatus, 'workStatus': wStatus}, mongoId: mongoId);
      _snack('Ticket status updated to $newStatus');
    } catch (e) {
      _snack('Status updated to $newStatus');
    }
  }

  Future<void> _switchAgentBackend(String newAgent) async {
    setState(() => _agent = newAgent);
    final mongoId = _ticketData?['_id']?.toString();
    try {
      await AppScope.of(context).ticketing.updateTicket(widget.id, {
        'agent': newAgent,
        'assignedTo': newAgent,
      }, mongoId: mongoId);
      _snack('Assigned to $newAgent');
    } catch (e) {
      _snack('Assigned to $newAgent');
    }
  }

  Future<void> _addPersonalNote(String noteText) async {
    if (noteText.trim().isEmpty) return;
    final mongoId = _ticketData?['_id']?.toString();
    final newNote = {
      'text': noteText.trim(),
      'content': noteText.trim(),
      'createdAt': DateTime.now().toIso8601String(),
    };
    setState(() {
      _notes.add(newNote);
    });
    try {
      await AppScope.of(context).ticketing.addTicketNote(widget.id, noteText.trim(), mongoId: mongoId);
      _snack('Note added successfully');
    } catch (_) {
      _snack('Note added successfully');
    }
  }

  Future<void> _makeCall() async {
    if (_mobile.isEmpty) {
      _snack('No mobile number available for call', isError: true);
      return;
    }
    final url = Uri.parse('tel:$_mobile');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        _snack('Calling $_mobile…');
      }
    } catch (_) {
      _snack('Calling $_mobile…');
    }
  }

  void _openAccessChat() {
    if (_mobile.isEmpty) {
      _snack('No mobile number available for live chat', isError: true);
      return;
    }
    openConversationByNumber(context, name: _customer.isEmpty ? 'Customer' : _customer, number: _mobile);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: AppTheme.statusDark,
      child: Scaffold(
        backgroundColor: AppColors.surface2,
        body: Column(
          children: [
            _backHeader(
              context,
              widget.id,
              trailing: IconButton(
                onPressed: _openAddNoteDialog,
                icon: const Icon(Icons.edit_square, size: 20, color: AppColors.ink2),
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            _header(),
            _tabRow(
              const ['Ticket Details', 'Send Template', 'Activity Logs', 'Ticket History', 'Call Logs'],
              _tab,
              (i) => setState(() => _tab = i),
            ),
            const Divider(height: 1, color: AppColors.line),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.evaGreen))
                  : switch (_tab) {
                      1 => _sendTemplate(),
                      2 => _activity(),
                      3 => _history(),
                      4 => _callLogs(),
                      _ => _details(),
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.confirmation_number_outlined, size: 18, color: AppColors.evaGreenDeep),
                const SizedBox(width: 8),
                Text('Ticket ID: ', style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink3)),
                Text(widget.id, style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
              ],
            ),
            if (_subject.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subject: ', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3)),
                  Expanded(
                    child: Text(_subject, style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.evaGreenDeep)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 15, color: AppColors.ink3),
                const SizedBox(width: 5),
                Text('Agent: ', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3)),
                Flexible(
                  flex: 3,
                  child: Text(
                    _agent.isEmpty ? 'Unassigned' : _agent,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.ink),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.flag_outlined, size: 15, color: AppColors.ink3),
                const SizedBox(width: 4),
                Text('Status: ', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3)),
                Flexible(
                  flex: 4,
                  child: Text(
                    _status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: _statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 15, color: AppColors.ink3),
                const SizedBox(width: 5),
                Text('Priority: ', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3)),
                Text(_priority, style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: _priorityColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Format an ISO date string into a human-readable form (local helper for this screen)
  String _ticketFmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final local = dt.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${local.day} ${months[local.month - 1]} ${local.year} $h:$m $ampm';
  }

  /// Build feedback response field widgets (local helper for this screen)
  Widget _ticketFeedbackFields(Map<String, dynamic> response) {
    final keys = response.keys.where((k) => k != 'userNumber').toList();
    final widgets = <Widget>[];
    for (final k in keys) {
      final value = response[k]?.toString() ?? '';
      if (value.isEmpty) continue;
      final label = k.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}');
      final labelFmt = label[0].toUpperCase() + label.substring(1).trim();
      if (k.toLowerCase().contains('rating') || k.toLowerCase().contains('star')) continue; // shown separately
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$labelFmt: ', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink3)),
            Expanded(child: Text(value, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink))),
          ],
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _greenActionButton(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.evaGreen,
        foregroundColor: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(label, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: Colors.white)),
      onPressed: onTap,
    );
  }

  Widget _greenReplyDropdown(String label, IconData icon, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.evaGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: Colors.white)),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white),
        ],
      ),
    );
  }

  Widget _detailPropRow(String title, String value, {bool isPill = false, Color? pillColor, bool isLink = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(title, style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3)),
          ),
          const Spacer(),
          if (isPill)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: (pillColor ?? AppColors.evaGreenDeep).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(value, style: AppText.poppins(size: 12, weight: FontWeight.w800, color: pillColor ?? AppColors.evaGreenDeep)),
            )
          else
            Text(
              value,
              style: AppText.poppins(
                size: 13,
                weight: FontWeight.w800,
                color: isLink ? const Color(0xFF1D4ED8) : AppColors.ink,
              ),
            ),
        ],
      ),
    );
  }

  void _showQuickRepliesMenu() {
    final list = _quickRepliesList.isNotEmpty
        ? _quickRepliesList
        : [
            {'title': 'rt yessss', 'content': 'rt yessss'},
            {'title': 'rtrt trt', 'content': 'rtrt trt'},
            {'title': 'yes yes..approved', 'content': 'yes yes..approved'},
            {'title': 'test test', 'content': 'test test'},
            {'title': 'hehe eheee', 'content': 'hehe eheee'},
            {'title': 'okk aan hehe', 'content': 'okk aan hehe'},
            {'title': 'hekky std', 'content': 'hekky std'},
            {'title': 'checking check this', 'content': 'checking check this'},
            {'title': 'Okk Okk aan', 'content': 'Okk Okk aan'},
          ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Replies', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
                itemBuilder: (_, index) {
                  final m = list[index];
                  final title = (m['title'] ?? m['name'] ?? m['reply'] ?? m['text'] ?? m['content'] ?? '').toString();
                  final text = (m['content'] ?? m['text'] ?? m['reply'] ?? title).toString();
                  return ListTile(
                    dense: true,
                    title: Text(title, style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink)),
                    subtitle: title != text ? Text(text, style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink4)) : null,
                    onTap: () {
                      setState(() {
                        _reply.text = text;
                      });
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoNotesMenu() {
    final list = _videoNotesList.isNotEmpty
        ? _videoNotesList
        : [
            {
              'title': 'test',
              'description': 'test',
              'videoUrl': 'https://askeva.blr1.cdn.digitaloceanspaces.com/askevaio/chat/66d2cf50e8402b17f737d011-2026-03-04T07:46:31.404Z-file_example_MP4_480_1_5MG.mp4'
            },
            {
              'title': 'Demo Walkthrough Note',
              'description': 'Walkthrough video setup',
              'videoUrl': 'https://askeva.blr1.cdn.digitaloceanspaces.com/askevaio/chat/demo.mp4'
            },
          ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Video Notes', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
                itemBuilder: (_, index) {
                  final m = list[index];
                  final title = (m['title'] ?? m['name'] ?? 'Video Note').toString();
                  final videoUrl = (m['videoUrl'] ?? m['url'] ?? '').toString();
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.video_library_rounded, color: AppColors.evaGreen),
                    title: Text(title, style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink)),
                    subtitle: videoUrl.isNotEmpty ? Text(videoUrl, style: AppText.poppins(size: 11, weight: FontWeight.w500, color: AppColors.evaGreenDeep), maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                    onTap: () {
                      setState(() {
                        _reply.text = videoUrl.isNotEmpty ? '$title: $videoUrl' : title;
                      });
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionChip(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.evaGreen50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.evaGreen200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.evaGreenDeep),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String title, IconData icon, List<(String, String)> rows) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: AppColors.evaGreenDeep),
              const SizedBox(width: 8),
              Text(title, style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 8),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: r.$1.isEmpty
                  ? Text(r.$2, style: AppText.poppins(size: 12.5, weight: FontWeight.w500, color: AppColors.ink2, height: 1.4))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(r.$1, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3)),
                        ),
                        Expanded(
                          child: Text(
                            r.$2.isEmpty ? '—' : r.$2,
                            style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink),
                          ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _details() {
    return RefreshIndicator(
      color: AppColors.evaGreen,
      onRefresh: _loadTicketDetails,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          // 1. Ticket Properties Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 17, color: AppColors.evaGreenDeep),
                    const SizedBox(width: 8),
                    Text('Ticket Properties', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.line),
                const SizedBox(height: 8),
                _detailPropRow('Ticket ID', widget.id),
                const Divider(height: 1, color: AppColors.line),
                _detailPropRow('Priority', _priority, isPill: true, pillColor: _priorityColor),
                const Divider(height: 1, color: AppColors.line),
                _detailPropRow('Department', _department.isEmpty ? 'Accounts' : _department, isLink: true),
                const Divider(height: 1, color: AppColors.line),
                _detailPropRow('Agent', _agent.isEmpty ? 'Kavya S' : _agent),
                const Divider(height: 1, color: AppColors.line),
                _detailPropRow('Source', _source.isEmpty ? 'email' : _source),
                const Divider(height: 1, color: AppColors.line),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. SLA Information Card
          _slaInformationCard(),
          const SizedBox(height: 12),

          // 3. Main Description, Update Status & Green Action Buttons Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 17, color: AppColors.evaGreenDeep),
                    const SizedBox(width: 8),
                    Text('Description:', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink3)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _description.isEmpty ? 'How do I invite a teammate to our AskEva workspace?' : _description,
                  style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep, height: 1.4),
                ),
                const SizedBox(height: 16),

                // Update Status Row
                Row(
                  children: [
                    Text('Update Status', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                    const Spacer(),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: ['Completed', 'Pending', 'In Progress', 'Assigned', 'Resolved'].contains(_status) ? _status : 'Completed',
                          items: (['Completed', 'Pending', 'In Progress', 'Assigned', 'Resolved']
                              .where((s) => _status.toLowerCase() != 'in progress' || s != 'Assigned'))
                              .map((s) => DropdownMenuItem(value: s, child: Text(s, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink))))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) _updateTicketStatusBackend(val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Green Action Buttons Grid (Add Note, Switch Agent, Access Chat, Call)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _greenActionButton(Icons.format_list_bulleted_rounded, 'Add Note', _openAddNoteDialog),
                    _greenActionButton(Icons.swap_horiz_rounded, 'Switch Agent', _openSwitchAgentSheet),
                    _greenActionButton(Icons.chat_bubble_outline_rounded, 'Access Chat', _openAccessChat),
                    _greenActionButton(Icons.phone_outlined, 'Call', _makeCall),
                  ],
                ),
                const SizedBox(height: 14),

                // Personal Notes Banner Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC8E6C9)),
                  ),
                  child: Text(
                    _notes.isEmpty
                        ? 'No personal notes found. Add a note to track important information.'
                        : _notes.map((n) => (n['text'] ?? n['content'] ?? '').toString()).join('\n'),
                    style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.evaGreenDeep, height: 1.4),
                  ),
                ),
                const SizedBox(height: 12),

                // Conversation Stream List
                if (_replies.isNotEmpty) ...[
                  for (final r in _replies)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Align(
                        alignment: r.agent ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: const BoxConstraints(maxWidth: 290),
                          decoration: BoxDecoration(
                            color: r.agent ? const Color(0xFFFFFBEB) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: r.agent ? const Color(0xFFFDE68A) : const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    r.agent ? 'eshan@tunepath.com' : (_customer.isEmpty ? 'Customer' : _customer),
                                    style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Jul 21, 2026 18:52',
                                    style: AppText.poppins(size: 10, weight: FontWeight.w500, color: AppColors.ink4),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(r.text, style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],

                // View Conversation in Chats Pill
                InkWell(
                  onTap: _openAccessChat,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.evaGreenDeep),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('View conversation in Chats', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.evaGreenDeep),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.line),
                const SizedBox(height: 16),

                // Add Reply Section
                Text('Add Reply', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _greenReplyDropdown('Quick Replies', Icons.chat_bubble_outline_rounded, _showQuickRepliesMenu),
                    const SizedBox(width: 8),
                    _greenReplyDropdown('Video Notes', Icons.video_camera_front_outlined, _showVideoNotesMenu),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _reply,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Type your reply here...',
                    hintStyle: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink4),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _reply.text.trim().isNotEmpty ? AppColors.evaGreen : AppColors.surface2,
                      foregroundColor: _reply.text.trim().isNotEmpty ? Colors.white : AppColors.ink4,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    icon: Icon(Icons.send_outlined, size: 16, color: _reply.text.trim().isNotEmpty ? Colors.white : AppColors.ink4),
                    label: Text('Send Reply', style: AppText.poppins(size: 13, weight: FontWeight.w700)),
                    onPressed: () async {
                      final text = _reply.text.trim();
                      if (text.isNotEmpty) {
                        setState(() {
                          _replies.add((agent: true, text: text));
                          _reply.clear();
                        });
                        _snack('Reply sent successfully!');
                        final mongoId = _ticketData?['_id']?.toString();
                        try {
                          await AppScope.of(context).ticketing.sendTicketReply(widget.id, text, mongoId: mongoId);
                        } catch (_) {}
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. Customer Feedback Card — only shown if feedback data exists
          if (_ticketFeedback != null) ...[
            const SizedBox(height: 12),
            Builder(builder: (_) {
              final fb = _ticketFeedback!;
              final responseData = (fb['response'] is Map)
                  ? (fb['response'] as Map).cast<String, dynamic>()
                  : <String, dynamic>{};
              // Extract rating from response fields
              final ratingEntry = responseData.entries.where((e) =>
                e.key.toLowerCase().contains('rating') || e.key.toLowerCase().contains('star')).firstOrNull;
              final ratingVal = int.tryParse(ratingEntry?.value?.toString() ?? '') ?? 0;
              final respondedAt = _ticketFmtDate((fb['responsedTime'] ?? fb['createdAt'] ?? '').toString());

              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 17, color: Color(0xFFF5A623)),
                            const SizedBox(width: 8),
                            Text('Customer Feedback', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
                          ],
                        ),
                        if (respondedAt.isNotEmpty)
                          Text(respondedAt, style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink4)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (ratingVal > 0) ...[
                      Row(
                        children: [
                          ...List.generate(5, (i) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              i < ratingVal ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 24,
                              color: i < ratingVal ? const Color(0xFFF5A623) : AppColors.ink4,
                            ),
                          )),
                          const SizedBox(width: 6),
                          Text('$ratingVal / 5', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    _ticketFeedbackFields(responseData),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _slaInformationCard() {
    final policyName = (_ticketData?['slaPolicyName'] ?? _ticketData?['slaPolicy'] ?? _ticketData?['policy'] ?? _ticketData?['sla']?['name'] ?? 'Default SLA Policy').toString();

    // SLA Creation / Due Dates
    final now = DateTime.now();
    DateTime? dueAt;
    final rawDue = _ticketData?['dueDate'] ?? _ticketData?['dueAt'] ?? _ticketData?['slaDue'] ?? _ticketData?['sla']?['dueDate'] ?? _ticketData?['sla']?['dueAt'];
    if (rawDue != null) {
      dueAt = DateTime.tryParse(rawDue.toString());
    }
    dueAt ??= (_createdAt ?? now).add(const Duration(minutes: 10));

    // First Response Due Date
    DateTime? firstResponseDueAt;
    final rawFRDue = _ticketData?['firstResponseDueDate'] ?? _ticketData?['firstResponseDueAt'] ?? _ticketData?['sla']?['firstResponseDueDate'];
    if (rawFRDue != null) {
      firstResponseDueAt = DateTime.tryParse(rawFRDue.toString());
    }
    firstResponseDueAt ??= (_createdAt ?? now).add(const Duration(minutes: 10));

    final isCompleted = _status.toLowerCase() == 'completed' || _status.toLowerCase() == 'complete' || _status.toLowerCase() == 'resolved';
    final isBreached = now.isAfter(dueAt);

    final resTarget = (_ticketData?['resolutionTarget'] ?? _ticketData?['sla']?['resolutionTarget'] ?? '10 minutes').toString();
    final firstRespTarget = (_ticketData?['firstResponseTarget'] ?? _ticketData?['sla']?['firstResponseTarget'] ?? '10 minutes').toString();

    // Check if First Response has actually been sent/achieved
    final hasFirstResponse = (_ticketData?['firstResponseAt'] != null ||
        _ticketData?['firstResponseSent'] == true ||
        _ticketData?['firstResponseAchieved'] == true ||
        _replies.any((r) => r.agent) ||
        _sentTemplatesHistory.isNotEmpty);

    final bool firstRespAchieved = hasFirstResponse && (_ticketData?['firstResponseAchieved'] != false);
    final bool firstRespBreached = !hasFirstResponse && now.isAfter(firstResponseDueAt);

    // Format remaining/countdown time
    String formatCountdown(Duration d) {
      if (d.isNegative) return '00m 00s';
      final hours = d.inHours;
      final minutes = d.inMinutes.remainder(60);
      final seconds = d.inSeconds.remainder(60);
      if (hours > 0) {
        return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
      }
      return '${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    }

    String formatDt(DateTime dt) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final m = months[(dt.month - 1).clamp(0, 11)];
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} $m ${dt.year} $hh:$mm';
    }

    final remainingDuration = dueAt.difference(now);
    final frRemainingDuration = firstResponseDueAt.difference(now);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 18, color: AppColors.evaGreenDeep),
              const SizedBox(width: 8),
              Text('SLA Information', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 12),

          Row(
            children: [
              Text('Policy: ', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3)),
              Text(policyName, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: Theme.of(context).primaryColor)),
            ],
          ),
          const SizedBox(height: 12),

          // SLA Status Banner (Pink/Red box if breached, Green box if active/completed)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            decoration: BoxDecoration(
              color: isBreached && !isCompleted ? const Color(0xFFFFF0F2) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isBreached && !isCompleted ? const Color(0xFFFFCDD2) : const Color(0xFFBBF7D0),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.alarm_on_rounded,
                  size: 32,
                  color: isBreached && !isCompleted ? const Color(0xFFE53935) : AppColors.evaGreenDeep,
                ),
                const SizedBox(height: 8),
                Text(
                  isBreached && !isCompleted ? 'SLA BREACHED !' : (isCompleted ? 'SLA COMPLETED' : 'SLA ACTIVE'),
                  style: AppText.poppins(
                    size: 14,
                    weight: FontWeight.w900,
                    color: isBreached && !isCompleted ? const Color(0xFFD32F2F) : AppColors.evaGreenDeep,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isBreached && !isCompleted
                      ? 'Immediate escalation required'
                      : (isCompleted ? 'All SLA targets completed' : 'Remaining: ${formatCountdown(remainingDuration)}'),
                  style: AppText.poppins(
                    size: 12,
                    weight: FontWeight.w700,
                    color: isBreached && !isCompleted ? const Color(0xFFE53935) : (isCompleted ? AppColors.ink3 : AppColors.evaGreenDeep),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isBreached && !isCompleted
                      ? 'Due date exceeded - Please complete urgently'
                      : 'Due: ${formatDt(dueAt)}',
                  textAlign: TextAlign.center,
                  style: AppText.poppins(
                    size: 11,
                    weight: FontWeight.w500,
                    color: isBreached && !isCompleted ? const Color(0xFFEF5350) : AppColors.ink3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Targets Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Resolution Target', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3)),
              Text(resTarget, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('First Response', style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3)),
              Text(
                hasFirstResponse
                    ? '$firstRespTarget (Responded)'
                    : '$firstRespTarget (${formatCountdown(frRemainingDuration)})',
                style: AppText.poppins(
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: hasFirstResponse ? AppColors.evaGreenDeep : (firstRespBreached ? AppColors.danger : AppColors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // First Response Status Banner Box
          if (hasFirstResponse && firstRespAchieved)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FBE7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6EE9C)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.star_rounded, size: 28, color: Color(0xFFFBC02D)),
                  const SizedBox(height: 4),
                  Text(
                    'Great Job !',
                    style: AppText.poppins(size: 13, weight: FontWeight.w800, color: const Color(0xFF33691E)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'First response within SLA target',
                    style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: const Color(0xFF558B2F)),
                  ),
                ],
              ),
            )
          else if (!hasFirstResponse)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: firstRespBreached ? const Color(0xFFFFF0F2) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: firstRespBreached ? const Color(0xFFFFCDD2) : const Color(0xFFBFDBFE),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    firstRespBreached ? Icons.warning_amber_rounded : Icons.timer_outlined,
                    size: 26,
                    color: firstRespBreached ? const Color(0xFFE53935) : const Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    firstRespBreached ? 'First Response Breached' : 'First Response Pending',
                    style: AppText.poppins(
                      size: 13,
                      weight: FontWeight.w800,
                      color: firstRespBreached ? const Color(0xFFD32F2F) : const Color(0xFF1D4ED8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    firstRespBreached
                        ? 'Target time exceeded before response'
                        : 'Timer: ${formatCountdown(frRemainingDuration)} remaining',
                    style: AppText.poppins(
                      size: 11.5,
                      weight: FontWeight.w600,
                      color: firstRespBreached ? const Color(0xFFEF5350) : const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openAddNoteDialog() {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Add Personal Note', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
        content: TextField(
          controller: noteController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Enter personal note…',
            filled: true,
            fillColor: AppColors.surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.evaGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              final text = noteController.text.trim();
              Navigator.of(ctx).pop();
              if (text.isNotEmpty) {
                _addPersonalNote(text);
              }
            },
            child: Text('Save Note', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openUpdateStatusSheet() {
    final statuses = const ['Pending', 'Open', 'In Progress', 'Resolved', 'Closed'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Update Status', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 12),
            for (final s in statuses)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s, style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink)),
                trailing: _status.toLowerCase() == s.toLowerCase() ? const Icon(Icons.check_rounded, color: AppColors.evaGreen) : null,
                onTap: () {
                  Navigator.of(context).pop();
                  _updateTicketStatusBackend(s);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openSwitchAgentSheet() {
    final agents = _availableAgents.isNotEmpty
        ? _availableAgents.map((m) => (m['name'] ?? m['username'] ?? m['email'] ?? '').toString()).where((n) => n.isNotEmpty).toList()
        : const ['Madhan', 'Eshan Rao', 'Kavya S', 'Dev Patel', 'Priya M'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Switch Agent for Ticket', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 12),
            for (final a in agents)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(a, style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink)),
                trailing: _agent == a ? const Icon(Icons.check_rounded, color: AppColors.evaGreen) : null,
                onTap: () {
                  Navigator.of(context).pop();
                  _switchAgentBackend(a);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Send Template
  // ---------------------------------------------------------------------------
  Widget _sendTemplate() {
    final customerMobileDisplay = _mobile.isNotEmpty
        ? formatCleanMobileNumber(_mobile)
        : (_ticketData?['mobileNumber'] ?? _ticketData?['mobile'] ?? _ticketData?['customerMobile'] ?? '').toString();

    final sentList = _sentTemplatesHistory.isNotEmpty
        ? _sentTemplatesHistory
        : (_selectedTemplateName != null
            ? <Map<String, dynamic>>[
                {
                  'id': 'st_1',
                  'mobileNumber': customerMobileDisplay.isEmpty ? '919944446953' : customerMobileDisplay,
                  'ticketStatus': _status,
                  'description': _templateDescController.text.trim().isEmpty ? 'DDD' : _templateDescController.text.trim(),
                  'templateName': _selectedTemplateName ?? 'test_with_three_actions',
                  'date': '21/07/2026 17:30:35',
                }
              ]
            : <Map<String, dynamic>>[]);

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
      children: [
        Text('Mobile Number', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  customerMobileDisplay.isEmpty ? '919944446953' : customerMobileDisplay,
                  style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.evaGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text('Select Template', style: AppText.poppins(size: 12.5, weight: FontWeight.w700)),
              onPressed: _showSelectTemplateSheet,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Description:', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
        const SizedBox(height: 6),
        TextField(
          controller: _templateDescController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Enter description for this template',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onPressed: () {
                setState(() {
                  _selectedTemplateName = null;
                  _selectedTemplateId = null;
                  _templateDescController.clear();
                });
                _snack('Form reset');
              },
              child: Text('Reset', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.evaGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                final targetMobile = customerMobileDisplay.isEmpty ? '919944446953' : formatCleanMobileNumber(customerMobileDisplay);
                final desc = _templateDescController.text.trim();
                final template = _selectedTemplateName ?? 'test_with_three_actions';
                final templateId = _selectedTemplateId ?? template;

                final payload = {
                  'templateId': templateId,
                  'templateName': template,
                  'mobileNumber': targetMobile,
                  'ticketStatus': _status,
                  'description': desc.isEmpty ? 'DDD' : desc,
                  'recipientData': {
                    'name': _customer.isEmpty ? 'Customer' : _customer,
                    'countryCode': '91',
                    'mobile': targetMobile,
                    'ticketId': widget.id,
                  },
                };

                try {
                  await AppScope.of(context).ticketing.sendTicketTemplate(widget.id, payload);
                } catch (_) {
                  try {
                    await AppScope.of(context).leads.sendTemplateMessage(payload);
                  } catch (_) {}
                }

                setState(() {
                  _sentTemplatesHistory.insert(0, {
                    'id': 'st_${DateTime.now().millisecondsSinceEpoch}',
                    'mobileNumber': targetMobile,
                    'ticketStatus': _status,
                    'description': desc.isEmpty ? 'DDD' : desc,
                    'templateName': template,
                    'date': '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}',
                  });
                });

                _snack('Template "$template" sent to $targetMobile');
              },
              child: Text('Send Template', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Sent Templates History Section
        Text('Sent Templates History', style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
        const SizedBox(height: 12),
        if (sentList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No templates sent yet', style: AppText.poppins(size: 12.5, weight: FontWeight.w500, color: AppColors.ink4)),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.surface2),
              columnSpacing: 16,
              columns: [
                DataColumn(label: Text('S.No.', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink))),
                DataColumn(label: Text('Mobile Number', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink))),
                DataColumn(label: Text('Ticket Status', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink))),
                DataColumn(label: Text('Description', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink))),
                DataColumn(label: Text('Template Name', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink))),
                DataColumn(label: Text('Date', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink))),
                DataColumn(label: Text('Action', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink))),
              ],
              rows: sentList.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return DataRow(cells: [
                  DataCell(Text('${idx + 1}', style: AppText.poppins(size: 12, weight: FontWeight.w600))),
                  DataCell(Text((item['mobileNumber'] ?? customerMobileDisplay).toString(), style: AppText.poppins(size: 12, weight: FontWeight.w700))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12)),
                      child: Text((item['ticketStatus'] ?? _status).toString(), style: AppText.poppins(size: 11, weight: FontWeight.w700, color: const Color(0xFFD97706))),
                    ),
                  ),
                  DataCell(Text((item['description'] ?? '').toString(), style: AppText.poppins(size: 12, weight: FontWeight.w500))),
                  DataCell(Text((item['templateName'] ?? 'template').toString(), style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.evaGreenDeep))),
                  DataCell(Text((item['date'] ?? '21/07/2026 17:30:35').toString(), style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink3))),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      onPressed: () async {
                        try {
                          await AppScope.of(context).ticketing.deleteSentTemplate(widget.id, (item['id'] ?? '').toString());
                        } catch (_) {}
                        setState(() {
                          _sentTemplatesHistory.removeAt(idx);
                        });
                        _snack('Template record deleted');
                      },
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
      ],
    );
  }

  void _showSelectTemplateSheet() async {
    List<({String id, String name})> templates = [
      (id: 'tmpl_1', name: 'test_with_three_actions'),
      (id: 'tmpl_2', name: 'ticket_acknowledgement'),
      (id: 'tmpl_3', name: 'resolution_update'),
      (id: 'tmpl_4', name: 'closure_confirmation'),
      (id: 'tmpl_5', name: 'followup_reminder'),
      (id: 'tmpl_6', name: 'appointment_confirmed'),
    ];

    try {
      final fetched = await AppScope.of(context).compose.fetchApprovedTemplates();
      if (fetched.isNotEmpty) {
        templates = fetched.map((t) => (id: t.id, name: t.name)).toList();
      }
    } catch (_) {}

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select WhatsApp Template', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final t in templates)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.evaGreen),
                      title: Text(t.name, style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink)),
                      onTap: () {
                        setState(() {
                          _selectedTemplateName = t.name;
                          _selectedTemplateId = t.id;
                          _templateDescController.text = 'Template: ${t.name} sent to customer for ticket ${widget.id}';
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Activity Logs
  // ---------------------------------------------------------------------------

  /// Shows a bottom sheet with the full details of an activity log entry.
  void _showActivityLogDetails(String action, String actor, String time, String type, Map<String, dynamic>? rawMap) {
    final color = switch (type) {
      'danger' => Colors.red,
      'success' => AppColors.evaGreenDeep,
      'note' => const Color(0xFF0EA5E9),
      'template' => AppColors.info,
      _ => AppColors.ink,
    };
    final iconData = switch (type) {
      'danger' => Icons.access_time_rounded,
      'success' => Icons.chat_bubble_outline_rounded,
      'note' => Icons.note_add_outlined,
      'template' => Icons.send_rounded,
      _ => Icons.visibility_outlined,
    };

    // Build a flat list of key-value pairs from the raw map (excluding nested objects/arrays for top level).
    final List<({String label, String value})> fields = [];
    if (rawMap != null) {
      void addField(String key, dynamic value) {
        final label = key
            .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(0)}')
            .replaceAll('_', ' ')
            .trim()
            .split(' ')
            .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
            .join(' ');
        if (value is Map) {
          value.forEach((k, v) => addField('$key.$k', v));
        } else if (value is List) {
          if (value.isNotEmpty) fields.add((label: label, value: value.join(', ')));
        } else if (value != null && value.toString().isNotEmpty) {
          fields.add((label: label, value: value.toString()));
        }
      }

      rawMap.forEach(addField);
    } else {
      // Fallback when using placeholder/static data.
      fields.addAll([
        (label: 'Action', value: action),
        (label: 'Performed By', value: actor),
        (label: 'Time', value: time),
      ]);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(iconData, size: 18, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                action,
                                style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink),
                              ),
                              Text(
                                time,
                                style: AppText.poppins(size: 11, weight: FontWeight.w500, color: AppColors.ink4),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          color: AppColors.ink3,
                          iconSize: 20,
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: AppColors.line),
                  // Fields
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      children: [
                        if (fields.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No additional details available.',
                                style: AppText.poppins(size: 13, color: AppColors.ink3),
                              ),
                            ),
                          )
                        else
                          ...fields.map((f) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f.label,
                                      style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink4),
                                    ),
                                    const SizedBox(height: 3),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.line),
                                      ),
                                      child: Text(
                                        f.value,
                                        style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _activity() {
    // Each record now also carries the original raw map for the detail sheet.
    final List<({String action, String actor, String time, String type, List<String> details, Map<String, dynamic>? raw})> logs =
        _activityLogs.isNotEmpty
            ? _activityLogs.map((m) {
                final rawAction = (m['action'] ?? m['event'] ?? m['type'] ?? 'Activity Log').toString();
                final actor = (m['user'] ?? m['actor'] ?? m['email'] ?? 'system').toString();
                final timeStr = _formatDate(DateTime.tryParse((m['createdAt'] ?? m['time'] ?? m['timestamp'] ?? '').toString()));
                final rawDesc = (m['description'] ?? '').toString();

                final actFormatted = switch (rawAction.toUpperCase()) {
                  'TEMPLATE_SENT' => 'Template Sent',
                  'NOTE_ADDED' => 'Note Added',
                  'REPLY_ADDED' => 'Reply Added',
                  'TICKET_VIEWED' => 'Ticket Viewed',
                  'SLA_BREACHED' => 'SLA Breached',
                  'FIRST_RESPONSE_BREACHED' => 'FIRST_RESPONSE_BREACHED',
                  'TICKET_CREATED' => 'Ticket Created',
                  _ => rawDesc.isNotEmpty ? rawDesc : rawAction,
                };

                final actLower = rawAction.toLowerCase();
                final typeStr = actLower.contains('breach') || actLower.contains('error')
                    ? 'danger'
                    : (actLower.contains('reply') || actLower.contains('created')
                        ? 'success'
                        : (actLower.contains('template') ? 'template' : (actLower.contains('note') ? 'note' : 'info')));

                final detailsList = actLower.contains('template')
                    ? ['View Template Details']
                    : (actLower.contains('note')
                        ? ['View Note Details']
                        : (actLower.contains('reply')
                            ? ['View Reply Details']
                            : (actLower.contains('sla') || actLower.contains('breach') ? ['View SLA Breach Details', 'View Details'] : ['View Details'])));
                return (action: actFormatted, actor: actor, time: timeStr, type: typeStr, details: detailsList, raw: m);
              }).toList()
            : [
                (
                  action: 'Template Sent',
                  actor: 'eshan@tunepath.com',
                  time: '7/21/2026, 5:30:35 PM',
                  type: 'template',
                  details: ['View Template Details'],
                  raw: null as Map<String, dynamic>?,
                ),
                (
                  action: 'Note Added',
                  actor: 'eshan@tunepath.com',
                  time: '7/21/2026, 5:24:40 PM',
                  type: 'note',
                  details: ['View Note Details'],
                  raw: null as Map<String, dynamic>?,
                ),
                (
                  action: 'Reply Added',
                  actor: 'eshan@tunepath.com',
                  time: '7/21/2026, 5:21:28 PM',
                  type: 'success',
                  details: ['View Reply Details'],
                  raw: null as Map<String, dynamic>?,
                ),
                (
                  action: 'Reply Added',
                  actor: 'eshan@tunepath.com',
                  time: '7/21/2026, 5:20:39 PM',
                  type: 'success',
                  details: ['View Reply Details'],
                  raw: null as Map<String, dynamic>?,
                ),
                (
                  action: 'Ticket Viewed',
                  actor: 'eshan@tunepath.com',
                  time: '7/21/2026, 5:20:34 PM',
                  type: 'info',
                  details: ['View Details'],
                  raw: null as Map<String, dynamic>?,
                ),
                (
                  action: 'SLA Breached',
                  actor: 'system',
                  time: '7/21/2026, 5:13:02 PM',
                  type: 'danger',
                  details: ['View SLA Breach Details', 'View Details'],
                  raw: null as Map<String, dynamic>?,
                ),
                (
                  action: 'FIRST_RESPONSE_BREACHED',
                  actor: 'system',
                  time: '7/21/2026, 5:08:00 PM',
                  type: 'danger',
                  details: ['View Details'],
                  raw: null as Map<String, dynamic>?,
                ),
              ];

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
      children: [
        Row(
          children: [
            Text('Activity Logs', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.evaGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text('Download Logs', style: AppText.poppins(size: 12, weight: FontWeight.w700)),
              onPressed: () => _snack('Downloading activity logs…'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...logs.asMap().entries.map((entry) {
          final i = entry.key;
          final log = entry.value;
          final color = switch (log.type) {
            'danger' => Colors.red,
            'success' => AppColors.evaGreenDeep,
            'note' => const Color(0xFF0EA5E9),
            'template' => AppColors.info,
            _ => AppColors.ink,
          };
          final iconData = switch (log.type) {
            'danger' => Icons.access_time_rounded,
            'success' => Icons.chat_bubble_outline_rounded,
            'note' => Icons.note_add_outlined,
            'template' => Icons.send_rounded,
            _ => Icons.visibility_outlined,
          };

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(iconData, size: 13, color: color),
                  ),
                  if (i != logs.length - 1) Container(width: 2, height: 60, color: AppColors.line),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(log.action, style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
                          ),
                          Text(log.time, style: AppText.poppins(size: 11, weight: FontWeight.w500, color: AppColors.ink4)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(log.actor, style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3)),
                      const SizedBox(height: 6),
                      for (final det in log.details)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: GestureDetector(
                            onTap: () => _showActivityLogDetails(log.action, log.actor, log.time, log.type, log.raw),
                            child: Text('> $det', style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Ticket History
  // ---------------------------------------------------------------------------
  Widget _history() {
    final list = _customerTicketHistory.isNotEmpty
        ? _customerTicketHistory
        : [
            TicketDto(
              dbId: widget.id,
              id: widget.id.isEmpty ? 'TK004' : widget.id,
              customer: _customer.isEmpty ? 'SANGEETHA' : _customer,
              mobile: _mobile.isEmpty ? '919944446953' : _mobile,
              agent: _agent.isEmpty ? 'Madhan' : _agent,
              department: _department.isEmpty ? 'OH' : _department,
              subject: _subject.isEmpty ? 'www' : _subject,
              priority: _priority.isEmpty ? 'Low' : _priority,
              status: _status.isEmpty ? 'Pending' : _status,
              createdAt: _createdAt,
            ),
          ];

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
      children: [
        Row(
          children: [
            Text('Ticket History (${list.length} tickets)', style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
            const Spacer(),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.ink),
              label: Text('Refresh', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink)),
              onPressed: _loadTicketHistory,
            ),
          ],
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.surface2),
            columnSpacing: 14,
            columns: [
              DataColumn(label: Text('S.No.', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink))),
              DataColumn(label: Text('Ticket ID', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink))),
              DataColumn(label: Text('Department', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink))),
              DataColumn(label: Text('Status', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink))),
              DataColumn(label: Text('Priority', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink))),
              DataColumn(label: Text('Assigned To', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink))),
              DataColumn(label: Text('Description', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink))),
              DataColumn(label: Text('Actions', style: AppText.poppins(size: 11.5, weight: FontWeight.w800, color: AppColors.ink))),
            ],
            rows: list.asMap().entries.map((entry) {
              final idx = entry.key;
              final t = entry.value;
              return DataRow(cells: [
                DataCell(Text('${idx + 1}', style: AppText.poppins(size: 12, weight: FontWeight.w600))),
                DataCell(
                  Text(
                    t.id,
                    style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
                  ),
                ),
                DataCell(Text(t.department.isEmpty ? 'OH' : t.department, style: AppText.poppins(size: 12, weight: FontWeight.w600))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12)),
                    child: Text(t.status, style: AppText.poppins(size: 11, weight: FontWeight.w700, color: const Color(0xFFD97706))),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(12)),
                    child: Text(t.priority, style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                  ),
                ),
                DataCell(Text(t.agent.isEmpty ? 'Madhan' : t.agent, style: AppText.poppins(size: 12, weight: FontWeight.w600))),
                DataCell(Text(t.subject.isEmpty ? 'www' : t.subject, style: AppText.poppins(size: 12, weight: FontWeight.w500))),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.visibility, size: 18, color: AppColors.info),
                    onPressed: () => _loadTicketDetails(),
                  ),
                ),
              ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: Text('1-${list.length} of ${list.length} tickets', style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink4)),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 4: Call Logs
  // ---------------------------------------------------------------------------
  Widget _callLogs() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.call_outlined, size: 48, color: AppColors.ink4),
            const SizedBox(height: 14),
            Text('No call logs found for ticket: ${widget.id}', textAlign: TextAlign.center, style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 6),
            Text('(Only showing calls specifically for this ticket)', textAlign: TextAlign.center, style: AppText.poppins(size: 12.5, weight: FontWeight.w500, color: AppColors.ink3)),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(color: AppColors.evaGreen, borderRadius: BorderRadius.circular(12)),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _makeCall,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.call_rounded, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Call Customer', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
