import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/app_scope.dart';
import '../api/dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'dashboard_sheets.dart' show appToast;

Future<void> showNewAppointmentSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _NewAppointmentSheet(),
  );
}

class _NewAppointmentSheet extends StatefulWidget {
  const _NewAppointmentSheet();
  @override
  State<_NewAppointmentSheet> createState() => _NewAppointmentSheetState();
}

class _NewAppointmentSheetState extends State<_NewAppointmentSheet> {
  int _day = 0;
  int _slot = -1;
  int _mode = 0; // Virtual / Manual
  int _payType = 0; // Prepaid / Postpaid
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _age = TextEditingController();
  final _desc = TextEditingController();
  final _bio = TextEditingController();

  // Overlay for name suggestions (floats over form like web app dropdown)
  final _nameLayerLink = LayerLink();
  final _nameFocus = FocusNode();
  OverlayEntry? _nameOverlay;

  DateTime? _dob;
  List<Map<String, dynamic>> _allAgents = [];
  List<String> _departments = [];
  String? _selectedDept;
  Map<String, dynamic>? _selectedAgentObj;
  late final List<(String, String, DateTime)> _days;
  bool _loading = true;

  // New fields for country code select and occupied slots
  List<CountryDto> _countries = [];
  CountryDto? _selectedCountry;
  bool _loadingOccupiedSlots = false;

  // New fields for patient suggestions
  List<Map<String, dynamic>> _nameSuggestions = [];
  List<Map<String, dynamic>> _numberSuggestions = [];
  Map<String, int> _bookedSlotCounts = {};
  List<Map<String, dynamic>> _bookingFields = [];

  @override
  void initState() {
    super.initState();
    _initDays();
    _loadData();
  }

  void _initDays() {
    final today = DateTime.now();
    _days = List.generate(7, (i) {
      final day = today.add(Duration(days: i));
      final label = i == 0
          ? 'TODAY'
          : i == 1
              ? 'TMRW'
              : _weekDayLabel(day.weekday);
      return (label, day.day.toString(), day);
    });
  }

  String _weekDayLabel(int weekday) {
    switch (weekday) {
      case 1: return 'MON';
      case 2: return 'TUE';
      case 3: return 'WED';
      case 4: return 'THU';
      case 5: return 'FRI';
      case 6: return 'SAT';
      default: return 'SUN';
    }
  }

  Future<void> _loadData() async {
    try {
      final scope = AppScope.of(context);
      // Fetch only agents configured for the Appointment module (matches web app)
      final list = await scope.agents.fetchModuleAgents('appointment');
      final countriesList = await scope.compose.fetchCountries();

      try {
        final config = await scope.appointments.fetchBookingConfiguration();
        final data = config['data'] ?? config;
        final rawFields = data['bookingFields'];
        if (rawFields is List) {
          _bookingFields = rawFields.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
        }
      } catch (_) {}

      final activeAgents = list.where((m) {
        final statusVal = m['status'] ?? m['active'];
        if (statusVal == null) return true;
        final sStr = statusVal.toString().toLowerCase().trim();
        return sStr != 'false' && sStr != '0' && sStr != 'inactive' && sStr != 'disabled';
      }).toList();

      final Set<String> deptsSet = {};
      for (final m in activeAgents) {
        final d = _agentDept(m);
        if (d.isNotEmpty) deptsSet.add(d);
      }

      try {
        final config = await scope.appointments.fetchBookingConfiguration();
        final data = config['data'] ?? config;
        final confDepts = data['departments'] ?? data['departmentList'];
        if (confDepts is List) {
          for (final cd in confDepts) {
            if (cd != null && cd.toString().trim().isNotEmpty) {
              final dStr = cd.toString().trim();
              if (dStr.toLowerCase() != 'superadmin' && dStr.toLowerCase() != 'superagent' && dStr.toLowerCase() != 'agent' && dStr.toLowerCase() != 'admin') {
                deptsSet.add(dStr);
              }
            }
          }
        }
      } catch (_) {}

      final depts = deptsSet.toList();
      if (depts.isEmpty) depts.add('Test');

      CountryDto? defaultCountry;
      if (countriesList.isNotEmpty) {
        // Find India as default or first
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
          final deptAgents = _selectedDept != null
              ? _allAgents.where((a) => _agentMatchesDepartment(a, _selectedDept!)).toList()
              : _allAgents;
          _selectedAgentObj = deptAgents.isNotEmpty ? deptAgents.first : (_allAgents.isNotEmpty ? _allAgents.first : null);
          _loading = false;
        });

        // Load occupied slots for initial selection
        _loadOccupiedSlots();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
      final parts = slotStr.split(' - ');
      final startTimeStr = parts.first.trim();
      
      int hour = 0;
      int minute = 0;

      if (startTimeStr.toUpperCase().contains('AM') || startTimeStr.toUpperCase().contains('PM')) {
        final cleanTime = startTimeStr.replaceAll(RegExp(r'[a-zA-Z\s]'), '');
        final isPm = startTimeStr.toUpperCase().contains('PM');
        final timeParts = cleanTime.split(':');
        hour = int.parse(timeParts.first);
        if (isPm && hour < 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
        minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
      } else {
        final timeParts = startTimeStr.split(':');
        hour = int.parse(timeParts.first);
        minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
      }

      final slotTime = DateTime(now.year, now.month, now.day, hour, minute);
      return now.isAfter(slotTime);
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadOccupiedSlots() async {
    if (_selectedAgentObj == null) return;
    final agentId = (_selectedAgentObj!['_id'] ?? _selectedAgentObj!['id'] ?? '').toString();
    if (agentId.isEmpty) return;

    final date = _days[_day].$3;
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    setState(() {
      _loadingOccupiedSlots = true;
    });

    try {
      final appointments = await AppScope.of(context).appointments.fetchAppointmentsByAgentAndDate(
        agentId: agentId,
        date: dateStr,
      );

      final counts = <String, int>{};
      for (final apt in appointments) {
        final timing = apt['timing']?.toString();
        if (timing != null && timing.isNotEmpty) {
          counts[timing] = (counts[timing] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _bookedSlotCounts = counts;
          _loadingOccupiedSlots = false;
          
          if (_slot >= 0) {
            final activeSlots = _activeSlots;
            if (_slot < activeSlots.length) {
              final slotStr = activeSlots[_slot];
              final isPast = _isSlotPast(slotStr, date);
              final isFull = (counts[slotStr] ?? 0) >= _maxOccupancy;
              if (isPast || isFull) {
                _slot = -1;
              }
            } else {
              _slot = -1;
            }
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingOccupiedSlots = false;
        });
      }
    }
  }

  bool _agentMatchesDepartment(Map<String, dynamic> agent, String targetDept) {
    if (targetDept.trim().isEmpty) return true;
    final target = targetDept.trim().toLowerCase();

    final config = agent['config'];
    if (config is Map) {
      final appointment = config['appointment'];
      if (appointment is Map) {
        final d = appointment['department'];
        final ds = appointment['departments'];
        if (d is String && (d.toLowerCase().trim() == target || d.toLowerCase().contains(target))) return true;
        if (ds is List && ds.any((item) => item.toString().toLowerCase().trim() == target || item.toString().toLowerCase().contains(target))) return true;
      }
      final dsConfig = config['departments'];
      if (dsConfig is List && dsConfig.any((item) => item.toString().toLowerCase().trim() == target || item.toString().toLowerCase().contains(target))) return true;
    }

    final rawDept = agent['department'] ?? agent['departments'] ?? agent['department_field'] ?? agent['dept'] ?? agent['department_name'];
    if (rawDept is List) {
      return rawDept.any((d) => d.toString().trim().toLowerCase() == target || d.toString().trim().toLowerCase().contains(target));
    }
    if (rawDept != null) {
      final dStr = rawDept.toString().trim().toLowerCase();
      if (dStr.isNotEmpty && (dStr == target || dStr.contains(target))) return true;
    }

    return false;
  }

  String _agentDept(Map<String, dynamic> agent) {
    final config = agent['config'];
    if (config is Map) {
      final appointment = config['appointment'];
      if (appointment is Map && appointment['department'] != null && appointment['department'].toString().trim().isNotEmpty) {
        return appointment['department'].toString().trim();
      }
    }
    final direct = agent['department'] ?? agent['department_name'] ?? agent['dept'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      final dStr = direct.toString().trim();
      if (dStr.toLowerCase() != 'superadmin' && dStr.toLowerCase() != 'superagent' && dStr.toLowerCase() != 'agent' && dStr.toLowerCase() != 'admin') {
        return dStr;
      }
    }
    return '';
  }

  @override
  void dispose() {
    _removeNameOverlay();
    _nameFocus.dispose();
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    _age.dispose();
    _desc.dispose();
    _bio.dispose();
    super.dispose();
  }

  // ── Overlay helpers ────────────────────────────────────────────────────────

  void _removeNameOverlay() {
    _nameOverlay?.remove();
    _nameOverlay = null;
  }

  void _showNameOverlay() {
    _removeNameOverlay();
    if (_nameSuggestions.isEmpty) return;

    final overlay = Overlay.of(context);
    _nameOverlay = OverlayEntry(
      builder: (_) => Positioned(
        width: MediaQuery.of(context).size.width - 36, // 18 padding each side
        child: CompositedTransformFollower(
          link: _nameLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 54),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _nameSuggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
                    itemBuilder: (context, i) {
                      final item = _nameSuggestions[i];
                      final name = (item['name'] ?? item['patientName'] ?? item['customerName'] ?? '').toString();
                      final number = (item['fullMobile'] ?? item['mobileNumber'] ?? item['mobile'] ?? item['phone'] ?? '').toString();
                      return InkWell(
                        onTap: () {
                          _selectCustomer(item);
                          _removeNameOverlay();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.evaGreen50,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  _ini(name.isNotEmpty ? name : '?'),
                                  style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      name,
                                      style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (number.isNotEmpty)
                                      Text(
                                        number,
                                        style: AppText.poppins(size: 11, weight: FontWeight.w500, color: AppColors.ink3),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.north_west_rounded, size: 14, color: AppColors.ink4),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_nameOverlay!);
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
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
        _age.text = age.toString();
      });
    }
  }

  void _pickDepartment() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: EdgeInsets.fromLTRB(18, 18, 18, 28 + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Select Department', style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final d in _departments)
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(d, style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink)),
                        trailing: _selectedDept == d ? const Icon(Icons.check_rounded, color: AppColors.evaGreen) : null,
                        onTap: () {
                          setState(() {
                            _selectedDept = d;
                            final deptAgents = _allAgents.where((a) => _agentMatchesDepartment(a, d)).toList();
                            _selectedAgentObj = deptAgents.isNotEmpty ? deptAgents.first : null;
                            _slot = -1; // Reset slot
                          });
                          Navigator.of(context).pop();
                          _loadOccupiedSlots();
                        },
                      ),
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
    final deptAgents = _selectedDept != null
        ? _allAgents.where((a) => _agentMatchesDepartment(a, _selectedDept!)).toList()
        : _allAgents;
    final agentsToDisplay = deptAgents;
    if (agentsToDisplay.isEmpty) {
      appToast(context, 'No agents configured for $_selectedDept department', isError: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: EdgeInsets.fromLTRB(18, 18, 18, 28 + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Select Agent', style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final a in agentsToDisplay)
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text((a['username'] ?? a['name'] ?? a['displayName'] ?? 'Agent').toString(), style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink)),
                        subtitle: a['role'] != null ? Text(a['role'].toString(), style: AppText.poppins(size: 11, color: AppColors.ink3)) : null,
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
                    ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  String _cleanDial(String? dial) {
    if (dial == null) return '91';
    return dial.replaceAll(RegExp(r'\D'), '');
  }

  void _pickCountry() {
    if (_countries.isEmpty) return;
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: EdgeInsets.fromLTRB(18, 18, 18, 28 + MediaQuery.of(ctx).padding.bottom),
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
                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
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
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchNameSuggestions([String query = '']) async {
    final q = query.trim().toLowerCase();
    List<Map<String, dynamic>> results = [];

    // 1. Fetch suggestions from backend API
    try {
      final apiResults = await AppScope.of(context).appointments.fetchCustomerSuggestions(
        type: 'name',
        value: query.trim(),
      );
      if (apiResults.isNotEmpty) {
        results.addAll(apiResults);
      }
    } catch (_) {}

    // 2. Also search local appointments dataset for existing customers
    try {
      final localAppts = await AppScope.of(context).appointments.fetchAppointments().catchError((_) => <AppointmentDto>[]);
      final Set<String> seen = results.map((r) => (r['name'] ?? r['patientName'] ?? '').toString().toLowerCase().trim()).toSet();
      for (final apt in localAppts) {
        if (apt.name.isEmpty) continue;
        final nLower = apt.name.trim().toLowerCase();
        final mLower = apt.mobile.trim().toLowerCase();
        if (q.isNotEmpty && !nLower.contains(q) && !mLower.contains(q)) continue;
        if (seen.contains(nLower)) continue;
        seen.add(nLower);
        results.add({
          'name': apt.name,
          'mobile': apt.mobile,
          'fullMobile': apt.mobile,
          'email': apt.rawJson['email'] ?? '',
          'age': apt.rawJson['age'] ?? '',
          'dob': apt.rawJson['dob'] ?? '',
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _nameSuggestions = results.take(10).toList());
      if (_nameFocus.hasFocus && _nameSuggestions.isNotEmpty) {
        _showNameOverlay();
      } else {
        _removeNameOverlay();
      }
    }
  }

  void _onNameChanged(String val) {
    _fetchNameSuggestions(val);
  }

  Future<void> _onMobileChanged(String val) async {
    if (val.trim().length < 2) {
      setState(() {
        _numberSuggestions = [];
      });
      return;
    }
    try {
      final suggestions = await AppScope.of(context).appointments.fetchCustomerSuggestions(
        type: 'number',
        value: val,
      );
      if (mounted) {
        setState(() {
          _numberSuggestions = suggestions;
        });
      }
    } catch (_) {}
  }

  void _selectCustomer(Map<String, dynamic> customer) {
    _removeNameOverlay();
    setState(() {
      _name.text = (customer['name'] ?? '').toString();
      _email.text = (customer['email'] ?? '').toString();
      final ageVal = customer['age'];
      if (ageVal != null) {
        _age.text = ageVal.toString();
      }
      final dobVal = customer['dob'];
      if (dobVal != null && dobVal.toString().isNotEmpty) {
        try {
          _dob = DateTime.tryParse(dobVal.toString());
        } catch (_) {}
      }

      final rawMobile = (customer['fullMobile'] ?? customer['mobileNumber'] ?? '').toString();
      var mobileStr = rawMobile.startsWith('+') ? rawMobile.substring(1) : rawMobile;
      mobileStr = mobileStr.replaceAll(RegExp(r'\D'), '');

      CountryDto? matchedCountry;
      for (final c in _countries) {
        final cleanDial = _cleanDial(c.dialCode);
        if (mobileStr.startsWith(cleanDial)) {
          matchedCountry = c;
          mobileStr = mobileStr.substring(cleanDial.length);
          break;
        }
      }

      if (matchedCountry != null) {
        _selectedCountry = matchedCountry;
      }
      _mobile.text = mobileStr;

      _nameSuggestions = [];
      _numberSuggestions = [];
    });
    // Dismiss keyboard after selection
    _nameFocus.unfocus();
  }

  Widget _suggestionList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
        itemBuilder: (context, i) {
          final item = items[i];
          final name = (item['name'] ?? '').toString();
          final number = (item['fullMobile'] ?? item['mobileNumber'] ?? '').toString();
          final company = (item['company'] ?? '').toString();
          return InkWell(
            onTap: () => _selectCustomer(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink)),
                        const SizedBox(height: 2),
                        Text(number, style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
                      ],
                    ),
                  ),
                  if (company.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.evaGreen50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.business_rounded, size: 12, color: AppColors.evaGreenDeep),
                          const SizedBox(width: 4),
                          Text(
                            company,
                            style: AppText.poppins(size: 10.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _validateMobile(String number, String dialCode) {
    final cleanDial = _cleanDial(dialCode);
    final clean = number.replaceAll(RegExp(r'\D'), '');
    switch (cleanDial) {
      case '91':
        return clean.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(clean);
      case '1':
        return clean.length == 10;
      case '44':
        return clean.length == 10;
      case '61':
        return clean.length == 9;
      case '971':
        return clean.length == 9;
      case '966':
        return clean.length == 9;
      case '65':
        return clean.length == 8;
      case '60':
        return clean.length == 9 || clean.length == 10;
      default:
        return clean.length >= 7 && clean.length <= 15;
    }
  }

  String _mobileValidationErrorMessage(String dialCode) {
    final cleanDial = _cleanDial(dialCode);
    switch (cleanDial) {
      case '91':
        return 'For India (+91), enter a valid 10-digit number starting with 6-9';
      case '1':
        return 'For US/Canada (+1), enter a valid 10-digit number';
      case '44':
        return 'For UK (+44), enter a valid 10-digit number';
      case '61':
        return 'For Australia (+61), enter a valid 9-digit number';
      case '971':
        return 'For UAE (+971), enter a valid 9-digit number';
      case '966':
        return 'For Saudi Arabia (+966), enter a valid 9-digit number';
      case '65':
        return 'For Singapore (+65), enter a valid 8-digit number';
      case '60':
        return 'For Malaysia (+60), enter a valid 9 or 10-digit number';
      default:
        return 'Enter a valid mobile number (7-15 digits)';
    }
  }

  void _create() {
    void err(String m) => appToast(context, m, isError: true);
    if (_name.text.trim().isEmpty) return err('Enter the customer name');

    final dial = _cleanDial(_selectedCountry?.dialCode);
    final rawMobile = _mobile.text.trim();
    if (!_validateMobile(rawMobile, dial)) {
      return err(_mobileValidationErrorMessage(dial));
    }

    if (_slot < 0) return err('Select an appointment time');
    if (_selectedDept == null) return err('Select a department');
    if (_selectedAgentObj == null) return err('Select an agent');

    // Validate mandatory fields configured in booking form settings (Age, DOB, Description, Email, etc.)
    for (final f in _bookingFields) {
      final isMandatory = f['mandatory'] == true || f['isMandatory'] == true || f['required'] == true;
      if (!isMandatory) continue;

      final label = (f['fieldLabel'] ?? f['name'] ?? f['label'] ?? f['fieldKey'] ?? '').toString();
      final normKey = (f['fieldKey'] ?? f['key'] ?? f['name'] ?? f['fieldLabel'] ?? '').toString().toLowerCase();

      if (normKey.contains('age') || normKey == 'age') {
        if (_age.text.trim().isEmpty) {
          return err('Please enter $label');
        }
      } else if (normKey.contains('dob') || normKey.contains('birth') || normKey == 'dob') {
        if (_dob == null) {
          return err('Please select $label');
        }
      } else if (normKey.contains('desc') || normKey == 'description') {
        if (_desc.text.trim().isEmpty) {
          return err('Please enter $label');
        }
      } else if (normKey.contains('email') || normKey == 'email') {
        if (_email.text.trim().isEmpty) {
          return err('Please enter $label');
        }
      } else if (normKey.contains('bio') || normKey == 'bio') {
        if (_bio.text.trim().isEmpty) {
          return err('Please enter $label');
        }
      }
    }

    final date = _days[_day].$3;
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final now = DateTime.now();
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'mobile': '$dial${rawMobile.replaceAll(RegExp(r'\D'), '')}',
      if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
      if (_age.text.trim().isNotEmpty) 'age': _age.text.trim(),
      if (_dob != null) 'dob': "${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}",
      'department': _selectedDept,
      'manager': _selectedAgentObj!['username'] ?? _selectedAgentObj!['name'] ?? '',
      'managerId': _selectedAgentObj!['_id'] ?? _selectedAgentObj!['id'] ?? '',
      if (_selectedAgentObj!['mobilenumber'] != null) 'agentNumber': _selectedAgentObj!['mobilenumber'].toString(),
      'appointmentDate': dateStr,
      'timing': _activeSlots[_slot],
      'mode': _mode == 0 ? 'Virtual' : 'Manual',
      'status': 'current',
      'payment': _payType == 0 ? 'prepaid' : 'postpaid',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
      if (_bio.text.trim().isNotEmpty) 'bio': _bio.text.trim(),
    };

    AppScope.of(context).appointments.createAppointment(body).catchError((_) {/* surfaced optimistically */});
    Navigator.of(context).pop();
    appToast(context, 'Appointment created for ${_name.text.trim()} at ${_activeSlots[_slot]}', isSuccess: true);
  }



  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: const Center(child: CircularProgressIndicator(color: AppColors.evaGreen)),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 10),
            child: Row(
              children: [
                InkWell(onTap: () => Navigator.of(context).pop(), child: const Icon(Icons.close_rounded, size: 22, color: AppColors.ink2)),
                const SizedBox(width: 14),
                Text('New appointment', style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              children: [
                _label('Name', mandatory: true),
                // The name field uses a floating overlay dropdown (like web app)
                CompositedTransformTarget(
                  link: _nameLayerLink,
                  child: _inputWithFocus(
                    'Search existing customer or enter name',
                    icon: Icons.person_outline_rounded,
                    controller: _name,
                    focusNode: _nameFocus,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
                    onChanged: _onNameChanged,
                    onFocusGained: () => _fetchNameSuggestions(_name.text),
                    onFocusLost: _removeNameOverlay,
                  ),
                ),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Age'), _input('Age', controller: _age, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly])])),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Date of Birth', mandatory: true),
                        GestureDetector(
                          onTap: _pickDob,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                            child: Row(children: [
                              const Icon(Icons.cake_outlined, size: 19, color: AppColors.ink3),
                              const SizedBox(width: 10),
                              Text(
                                _dob == null
                                    ? 'Select'
                                    : "${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}",
                                style: AppText.poppins(size: 14, weight: FontWeight.w600, color: _dob == null ? AppColors.ink4 : AppColors.ink),
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
                _label('Mobile Number', mandatory: true),
                Row(children: [
                  GestureDetector(
                    onTap: _pickCountry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                      child: Row(children: [
                        Text(
                          _selectedCountry != null ? '+${_cleanDial(_selectedCountry!.dialCode)}' : '+91',
                          style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.ink3),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _input(
                      'Enter mobile number',
                      controller: _mobile,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: _onMobileChanged,
                    ),
                  ),
                ]),
                _suggestionList(_numberSuggestions),
                _label('Email Address'),
                _input('Enter email address', icon: Icons.mail_outline_rounded, controller: _email),
                _label('Department', mandatory: true),
                GestureDetector(
                  onTap: _pickDepartment,
                  child: _selectRow(Icons.home_outlined, _selectedDept ?? 'Select Department'),
                ),
                _label('Select User', mandatory: true),
                GestureDetector(
                  onTap: _pickAgent,
                  child: _selectRow(
                    null,
                    _selectedAgentObj?['username'] ?? _selectedAgentObj?['name'] ?? 'Select User',
                    sub: _selectedAgentObj?['role']?.toString(),
                    avatar: _selectedAgentObj != null
                        ? _ini((_selectedAgentObj!['username'] ?? _selectedAgentObj!['name'] ?? '?').toString())
                        : null,
                  ),
                ),
                _label('Appointment Date', mandatory: true),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _days.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final active = _day == i;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _day = i);
                          _loadOccupiedSlots();
                        },
                        child: Container(
                          width: 56,
                          decoration: BoxDecoration(color: active ? AppColors.evaGreen : AppColors.surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: active ? AppColors.evaGreen : AppColors.line)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_days[i].$1, style: AppText.poppins(size: 9.5, weight: FontWeight.w700, color: active ? Colors.white : AppColors.ink4)),
                              const SizedBox(height: 4),
                              Text(_days[i].$2, style: AppText.poppins(size: 18, weight: FontWeight.w800, color: active ? Colors.white : AppColors.ink)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _label('Appointment Timing', mandatory: true),
                if (_loadingOccupiedSlots)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator(color: AppColors.evaGreen)),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: List.generate(_activeSlots.length, (i) {
                      final slotStr = _activeSlots[i];
                      final isPast = _isSlotPast(slotStr, _days[_day].$3);
                      final bookedCount = _bookedSlotCounts[slotStr] ?? 0;
                      final maxOccupancy = _maxOccupancy;
                      final isFull = bookedCount >= maxOccupancy;
                      final isOccupied = isPast || isFull;
                      final active = _slot == i;
                      return GestureDetector(
                        onTap: isOccupied
                            ? null
                            : () => setState(() => _slot = i),
                        child: Container(
                          width: (MediaQuery.of(context).size.width - 36 - 12) / 2,
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
                                  ).copyWith(
                                    decoration: isOccupied ? TextDecoration.lineThrough : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPast
                                    ? 'Past'
                                    : (isFull ? 'Full' : '$bookedCount/$maxOccupancy'),
                                style: AppText.poppins(
                                  size: 11,
                                  weight: FontWeight.w800,
                                  color: isPast
                                      ? Colors.grey.shade400
                                      : (isFull
                                          ? Colors.red.shade400
                                          : (active ? AppColors.evaGreenDeep : AppColors.evaGreen)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                _label('Description'),
                _input('Enter description', maxLines: 3, controller: _desc),
                _label('Bio'),
                _input('Enter bio', icon: Icons.notes_rounded, controller: _bio),
                _label('Appointment mode'),
                _toggle(['Virtual', 'Manual'], _mode, (i) => setState(() => _mode = i)),
                _label('Payment Type', mandatory: true),
                Row(children: [
                  Expanded(child: _payCard(Icons.credit_card_rounded, 'Prepaid', 0)),
                  const SizedBox(width: 12),
                  Expanded(child: _payCard(Icons.schedule_rounded, 'Postpaid', 1)),
                ]),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.of(context).padding.bottom + 14),
            child: SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.evaGradient, borderRadius: BorderRadius.circular(14)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _create,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.check_rounded, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Create Appointment', style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: Colors.white)),
                      ]),
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

  bool _isMandatory(String keyOrName) {
    final search = keyOrName.trim().toLowerCase();
    if (search.contains('dob') || search.contains('birth') || search.contains('date of birth')) {
      return true;
    }
    final f = _bookingFields.firstWhere(
      (m) => (m['fieldKey'] ?? m['key'] ?? m['name'] ?? m['fieldLabel'] ?? m['fieldName'] ?? '').toString().trim().toLowerCase().contains(search) ||
             search.contains((m['fieldKey'] ?? m['key'] ?? m['name'] ?? m['fieldLabel'] ?? m['fieldName'] ?? '').toString().trim().toLowerCase()),
      orElse: () => const {},
    );
    if (f.isNotEmpty) {
      return f['mandatory'] == true || f['isMandatory'] == true || f['required'] == true;
    }
    return false;
  }

  Widget _label(String t, {bool? mandatory}) {
    final isReq = mandatory ?? _isMandatory(t);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: RichText(
        text: TextSpan(
          children: [
            if (isReq)
              const TextSpan(text: '* ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
            TextSpan(
              text: t,
              style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(
    String hint, {
    IconData? icon,
    int maxLines = 1,
    TextEditingController? controller,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
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

  /// Name-field variant that accepts a FocusNode and focus callbacks
  /// so we can show/hide the overlay dropdown.
  Widget _inputWithFocus(
    String hint, {
    IconData? icon,
    TextEditingController? controller,
    FocusNode? focusNode,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    VoidCallback? onFocusGained,
    VoidCallback? onFocusLost,
  }) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          onFocusGained?.call();
        } else {
          // Small delay so tapping a suggestion registers before overlay hides.
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) onFocusLost?.call();
          });
        }
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
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
            Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: AppColors.evaGreenDeep)),
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
}

String _ini(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
}

