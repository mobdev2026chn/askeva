import 'package:flutter/material.dart';
import '../api/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/dashboard_sheets.dart' show appToast;
import '../widgets/common.dart';
import '../shell/app_nav.dart';

class BusinessHoursScreen extends StatefulWidget {
  const BusinessHoursScreen({super.key});

  @override
  State<BusinessHoursScreen> createState() => _BusinessHoursScreenState();
}

class _BusinessHoursScreenState extends State<BusinessHoursScreen> {
  bool _loading = false;
  bool _saving = false;
  String _timezone = 'America/New_York';

  // State structure for each day
  final Map<String, Map<String, dynamic>> _days = {
    'monday': {'enabled': true, 'start': '09:00', 'end': '18:00', 'breaks': []},
    'tuesday': {'enabled': true, 'start': '09:00', 'end': '18:00', 'breaks': []},
    'wednesday': {'enabled': true, 'start': '09:00', 'end': '18:00', 'breaks': []},
    'thursday': {'enabled': true, 'start': '09:00', 'end': '18:00', 'breaks': []},
    'friday': {'enabled': true, 'start': '09:00', 'end': '18:00', 'breaks': []},
    'saturday': {'enabled': false, 'start': '10:00', 'end': '16:00', 'breaks': []},
    'sunday': {'enabled': false, 'start': '10:00', 'end': '16:00', 'breaks': []},
  };

  final List<String> _timezones = [
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'Europe/London',
    'Europe/Paris',
    'Asia/Tokyo',
    'Australia/Sydney',
  ];

  final Map<String, String> _dayLabels = {
    'monday': 'Monday',
    'tuesday': 'Tuesday',
    'wednesday': 'Wednesday',
    'thursday': 'Thursday',
    'friday': 'Friday',
    'saturday': 'Saturday',
    'sunday': 'Sunday',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final repo = AppScope.of(context).ticketing;
      final settings = await repo.fetchTicketSettings();

      if (mounted) {
        setState(() {
          if (settings.containsKey('timezone')) {
            _timezone = settings['timezone'].toString();
          }

          // Parse businessHours from settings if exists
          final bh = settings['businessHours'] ?? settings['workingHours'];
          if (bh is Map) {
            bh.forEach((key, val) {
              final dayKey = key.toString().toLowerCase();
              // handle both mon/monday
              final targetDayKey = _days.keys.firstWhere(
                (d) => d == dayKey || d.startsWith(dayKey),
                orElse: () => '',
              );

              if (targetDayKey.isNotEmpty && val is Map) {
                _days[targetDayKey] = {
                  'enabled': val['enabled'] ?? val['open'] ?? false,
                  'start': val['start']?.toString() ?? '09:00',
                  'end': val['end']?.toString() ?? '18:00',
                  'breaks': val['breaks'] is List ? val['breaks'] : [],
                };
              }
            });
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Failed to load settings: $e', err: true);
      }
    }
  }

  void _snack(String m, {bool err = false}) {
    appToast(context, m);
  }

  String _calculateWorkingHours(String day) {
    final d = _days[day]!;
    if (d['enabled'] != true) return 'Closed';
    try {
      final startParts = d['start'].toString().split(':');
      final endParts = d['end'].toString().split(':');
      final sMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final eMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

      int breakMin = 0;
      final brks = d['breaks'] as List;
      for (final b in brks) {
        if (b is Map) {
          final bsParts = b['start'].toString().split(':');
          final beParts = b['end'].toString().split(':');
          final bsMin = int.parse(bsParts[0]) * 60 + int.parse(bsParts[1]);
          final beMin = int.parse(beParts[0]) * 60 + int.parse(beParts[1]);
          if (beMin > bsMin) breakMin += (beMin - bsMin);
        }
      }

      final totalMin = (eMin - sMin) - breakMin;
      if (totalMin <= 0) return 'Closed';
      final h = totalMin ~/ 60;
      final m = totalMin % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    } catch (_) {
      return 'Closed';
    }
  }

  TimeOfDay _parseTime(String tStr) {
    try {
      final parts = tStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $period';
  }

  String _formatTimeOfDay24(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime(String day, String field) async {
    final d = _days[day]!;
    final curr = _parseTime(d[field].toString());
    final picked = await showTimePicker(
      context: context,
      initialTime: curr,
      builder: (ctx, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.evaGreen,
            onPrimary: Colors.white,
            onSurface: AppColors.ink,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        d[field] = _formatTimeOfDay24(picked);
      });
    }
  }

  void _showTimezoneSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Timezone', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 16),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: _timezones.map((tz) {
                final selected = _timezone == tz;
                return GestureDetector(
                  onTap: () {
                    setState(() => _timezone = tz);
                    Navigator.of(ctx).pop();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.evaGreen50 : AppColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? AppColors.evaGreen : AppColors.line, width: 1.2),
                    ),
                    child: Text(tz, style: AppText.poppins(size: 14, weight: selected ? FontWeight.w700 : FontWeight.w600, color: selected ? AppColors.evaGreenDeep : AppColors.ink)),
                  ),
                );
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }

  void _showBreaksModal(String day) {
    final d = _days[day]!;
    final dayLabel = _dayLabels[day]!;

    // Create a copy of the breaks list
    final List draft = List.from(d['breaks']?.map((x) => Map<String, dynamic>.from(x)) ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(children: [
                GestureDetector(onTap: () => Navigator.of(ctx).pop(), child: const Icon(Icons.close_rounded, size: 22, color: AppColors.ink)),
                Expanded(
                  child: Center(
                    child: Column(children: [
                      Text('Configure Breaks', style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
                      Text(dayLabel, style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
                    ]),
                  ),
                ),
                const SizedBox(width: 22),
              ]),
            ),
            const Divider(height: 1, color: AppColors.line),
            // Body
            Expanded(
              child: draft.isEmpty
                  ? Center(child: Text('No breaks added yet.', style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink4)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: draft.length,
                      itemBuilder: (ctx, i) {
                        final b = draft[i];
                        final startT = _parseTime(b['start'].toString());
                        final endT = _parseTime(b['end'].toString());

                        Future<void> pickBreakTime(String field) async {
                          final current = _parseTime(b[field].toString());
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: current,
                            builder: (ctx, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(primary: AppColors.evaGreen),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setSt(() {
                              b[field] = _formatTimeOfDay24(picked);
                            });
                          }
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                          child: Row(children: [
                            const Icon(Icons.schedule_rounded, size: 16, color: AppColors.ink4),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Row(children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => pickBreakTime('start'),
                                    child: Text(_formatTimeOfDay(startT), style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                                  ),
                                ),
                                Text('to', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => pickBreakTime('end'),
                                    child: Text(_formatTimeOfDay(endT), style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                                  ),
                                ),
                              ]),
                            ),
                            IconButton(
                              onPressed: () => setSt(() => draft.removeAt(i)),
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                            ),
                          ]),
                        );
                      },
                    ),
            ),
            // Footer
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(ctx).padding.bottom),
              child: Column(children: [
                OutlinedButton.icon(
                  onPressed: () => setSt(() => draft.add({'start': '13:00', 'end': '14:00'})),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Break'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.evaGreenDeep,
                    side: const BorderSide(color: AppColors.evaGreen200),
                    minimumSize: const Size.fromHeight(45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      d['breaks'] = draft;
                    });
                    Navigator.of(ctx).pop();
                    _snack('Breaks saved');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.evaGreen,
                    minimumSize: const Size.fromHeight(45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Save breaks', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
                ),
              ]),
            ),
          ]),
        );
      }),
    );
  }
  Future<void> _saveAll() async {
    final repo = AppScope.of(context).ticketing;
    setState(() => _saving = true);
    try {
      final payload = {
        'timezone': _timezone,
        'businessHours': _days,
      };

      await repo.updateTicketSettings(payload);
      if (!mounted) return;
      _snack('Business hours saved successfully');
      Navigator.of(context).pop();
    } catch (e) {
      _snack('Failed to save business hours: $e', err: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final nav = AppNav.maybeOf(context);

    return Scaffold(
      backgroundColor: AppColors.surface2,
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _saveAll,
              backgroundColor: AppColors.evaGreen,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined, color: Colors.white),
              label: Text('Save All', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
            ),
      body: GreenHeaderScaffold(
        title: 'Ticketing',
        onMenu: nav?.openDrawer,
        headerChild: GreenSegmented(
          items: const ['Dashboard', 'Tickets', 'Settings'],
          selected: 2, // Settings
          onChanged: (i) {
            if (i != 2) {
              Navigator.of(context).pop(i);
            }
          },
        ),
        sheet: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.evaGreen))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button row
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                            color: AppColors.evaGreen,
                            borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back_ios_new_rounded,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text('Back',
                                style: AppText.poppins(
                                    size: 13,
                                    weight: FontWeight.w700,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Screen Title
                    Text('Business Hours',
                        style: AppText.poppins(
                            size: 20,
                            weight: FontWeight.w800,
                            color: AppColors.ink)),
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                        boxShadow: AppColors.shadowSm,
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Working Hours', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                          GestureDetector(
                            onTap: _showTimezoneSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.line)),
                              child: Row(children: [
                                Text(_timezone, style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink2)),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.ink3),
                              ]),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        ..._days.keys.map((dayKey) {
                          final dayVal = _days[dayKey]!;
                          final isOpen = dayVal['enabled'] == true;
                          final hoursStr = _calculateWorkingHours(dayKey);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Text(_dayLabels[dayKey]!, style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
                                Text(hoursStr, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: isOpen ? AppColors.evaGreenDeep : AppColors.ink3)),
                              ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                SizedBox(
                                  height: 24,
                                  child: Switch(
                                    value: isOpen,
                                    onChanged: (v) => setState(() => dayVal['enabled'] = v),
                                    activeThumbColor: Colors.white,
                                    activeTrackColor: AppColors.evaGreen,
                                    inactiveThumbColor: Colors.white,
                                    inactiveTrackColor: AppColors.line,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isOpen ? 'Open' : 'Closed',
                                  style: AppText.poppins(
                                      size: 12.5,
                                      weight: FontWeight.w700,
                                      color: isOpen ? AppColors.evaGreenDeep : AppColors.ink3),
                                ),
                              ]),
                              if (isOpen) ...[
                                const SizedBox(height: 12),
                                Text('Start Time', style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3)),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () => _pickTime(dayKey, 'start'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.line)),
                                    child: Row(children: [
                                      const Icon(Icons.schedule_rounded, size: 15, color: AppColors.ink4),
                                      const SizedBox(width: 8),
                                      Text(_formatTimeOfDay(_parseTime(dayVal['start'])), style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                                      const Spacer(),
                                      const Icon(Icons.schedule_rounded, size: 15, color: AppColors.ink4),
                                    ]),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text('End Time', style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3)),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () => _pickTime(dayKey, 'end'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.line)),
                                    child: Row(children: [
                                      const Icon(Icons.schedule_rounded, size: 15, color: AppColors.ink4),
                                      const SizedBox(width: 8),
                                      Text(_formatTimeOfDay(_parseTime(dayVal['end'])), style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                                      const Spacer(),
                                      const Icon(Icons.schedule_rounded, size: 15, color: AppColors.ink4),
                                    ]),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(children: [
                                  Text('Breaks: ', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3)),
                                  Text(
                                    dayVal['breaks'].length > 0 ? '${dayVal['breaks'].length} configured' : 'No breaks configured',
                                    style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink2),
                                  ),
                                ]),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _showBreaksModal(dayKey),
                                  icon: const Icon(Icons.edit_outlined, size: 15),
                                  label: const Text('Configure Breaks'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.ink2,
                                    side: const BorderSide(color: AppColors.line),
                                    minimumSize: const Size.fromHeight(36),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ]),
                          );
                        }),
                      ]),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

}
