
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// AskEva-styled date-range picker bottom sheet: Start/End pills, a month grid
/// with ‹ › navigation, and Clear / Apply. Returns the chosen [DateTimeRange]
/// (or null if cancelled/cleared). Days outside [firstDate]..[lastDate] are
/// disabled.
Future<DateTimeRange?> showAppDateRangePicker(
  BuildContext context, {
  DateTimeRange? initialRange,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DateRangeSheet(initialRange: initialRange, firstDate: firstDate, lastDate: lastDate),
  );
}

class _DateRangeSheet extends StatefulWidget {
  final DateTimeRange? initialRange;
  final DateTime firstDate, lastDate;
  const _DateRangeSheet({this.initialRange, required this.firstDate, required this.lastDate});
  @override
  State<_DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends State<_DateRangeSheet> {
  DateTime? _start, _end;
  late DateTime _month; // first day of the visible month

  @override
  void initState() {
    super.initState();
    _start = widget.initialRange?.start;
    _end = widget.initialRange?.end;
    final now = DateTime.now();
    DateTime refMonth = DateTime(now.year, now.month);
    if (_start != null) {
      refMonth = DateTime(_start!.year, _start!.month);
    }
    final firstMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    final lastMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
    if (refMonth.isBefore(firstMonth)) refMonth = firstMonth;
    if (refMonth.isAfter(lastMonth)) refMonth = lastMonth;

    _month = refMonth;
  }

  static DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);
  static bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  bool _disabled(DateTime day) => day.isBefore(_d(widget.firstDate)) || day.isAfter(_d(widget.lastDate));

  void _tapDay(DateTime day) {
    if (_disabled(day)) return;
    setState(() {
      if (_start == null || _end != null) {
        _start = day;
        _end = null;
      } else if (day.isBefore(_start!)) {
        _end = _start;
        _start = day;
      } else {
        _end = day;
      }
    });
  }

  bool _inRange(DateTime day) {
    if (_start == null || _end == null) return false;
    return !day.isBefore(_d(_start!)) && !day.isAfter(_d(_end!));
  }

  bool get _canPrev => _month.isAfter(DateTime(widget.firstDate.year, widget.firstDate.month));
  bool get _canNext => _month.isBefore(DateTime(widget.lastDate.year, widget.lastDate.month));

  String? _pill(DateTime? d) => d == null ? null : '${d.day} ${_monthAbbr[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final startActive = _start == null || _end != null;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.surface3,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 14, 6),
              child: Row(
                children: [
                  Expanded(child: Text('Select date range', style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink))),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.close_rounded, size: 17, color: AppColors.ink2)),
                  ),
                ],
              ),
            ),
            // Start / End pills
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
              child: Row(
                children: [
                  Expanded(child: _rangePill(_pill(_start) ?? 'Start date', active: startActive, set: _start != null)),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.ink3)),
                  Expanded(child: _rangePill(_pill(_end) ?? 'End date', active: !startActive, set: _end != null)),
                ],
              ),
            ),
            // Month navigation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _navBtn(Icons.chevron_left_rounded, _canPrev ? () => setState(() => _month = DateTime(_month.year, _month.month - 1)) : null),
                  Text('${_monthNames[_month.month - 1]} ${_month.year}', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                  _navBtn(Icons.chevron_right_rounded, _canNext ? () => setState(() => _month = DateTime(_month.year, _month.month + 1)) : null),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Weekday header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: const ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
                    .map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink4)))))
                    .toList(),
              ),
            ),
            const SizedBox(height: 4),
            // Day grid — scrollable so 6-row months don't overflow
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _grid(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.line),
            // Clear / Apply
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _start = null;
                        _end = null;
                      }),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.ink2, side: const BorderSide(color: AppColors.line), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                      child: Text('Clear', style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: AppColors.ink2)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: _start == null ? null : AppColors.evaGradient, color: _start == null ? AppColors.surface3 : null, borderRadius: BorderRadius.circular(13)),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(13),
                          onTap: _start == null ? null : () => Navigator.of(context).pop(DateTimeRange(start: _d(_start!), end: _d(_end ?? _start!))),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(child: Text('Apply', style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: _start == null ? AppColors.ink4 : Colors.white))),
                          ),
                        ),
                      ),
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

  Widget _rangePill(String text, {required bool active, required bool set}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.evaGreen50 : AppColors.surface2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: active ? AppColors.evaGreen : AppColors.line),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: set || active ? AppColors.evaGreenDeep : AppColors.ink3),
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 24, color: onTap == null ? AppColors.line : AppColors.ink3),
      ),
    );
  }

  Widget _grid() {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // Leading blanks so day 1 lands under its weekday (Sunday-first columns).
    final leading = DateTime(_month.year, _month.month, 1).weekday % 7; // Sun=0
    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      cells.add(_dayCell(DateTime(_month.year, _month.month, day)));
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.35,
      children: cells,
    );
  }

  Widget _dayCell(DateTime day) {
    final isEnd = _start != null && _same(day, _start!) || (_end != null && _same(day, _end!));
    final inRange = _inRange(day) && !isEnd;
    final disabled = _disabled(day);
    Color? bg;
    Color fg = AppColors.ink;
    if (disabled) {
      fg = AppColors.line;
    } else if (isEnd) {
      bg = AppColors.evaGreen;
      fg = Colors.white;
    } else if (inRange) {
      bg = AppColors.evaGreen50;
      fg = AppColors.evaGreenDeep;
    }
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: bg ?? Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: disabled ? null : () => _tapDay(day),
          child: Center(
            child: Text('${day.day}', style: AppText.poppins(size: 13, weight: isEnd ? FontWeight.w800 : FontWeight.w600, color: fg)),
          ),
        ),
      ),
    );
  }
}
