import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GlassDateRangePicker {
  static Future<DateTimeRange?> show(
    BuildContext context, {
    DateTimeRange? initialDateRange,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime normalizedFirst = DateUtils.dateOnly(firstDate ?? DateTime(2000));
    final DateTime normalizedLast = DateUtils.dateOnly(lastDate ?? DateTime(2100));
    final DateTime focusedMonth = DateTime(
      (initialDateRange?.start ?? now).year,
      (initialDateRange?.start ?? now).month,
      1,
    );

    return await showDialog<DateTimeRange>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) {
        return _GlassCalendarRangeDialog(
          focusedMonth: focusedMonth,
          initialRange: initialDateRange,
          firstDate: normalizedFirst,
          lastDate: normalizedLast,
        );
      },
    );
  }
}

class _GlassCalendarRangeDialog extends StatefulWidget {
  final DateTime focusedMonth;
  final DateTimeRange? initialRange;
  final DateTime firstDate;
  final DateTime lastDate;

  const _GlassCalendarRangeDialog({
    required this.focusedMonth,
    this.initialRange,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_GlassCalendarRangeDialog> createState() =>
      _GlassCalendarRangeDialogState();
}

class _GlassCalendarRangeDialogState extends State<_GlassCalendarRangeDialog> {
  late DateTime _focusedMonth;
  DateTime? _start;
  DateTime? _end;

  static const Color _bgDark = Color(0xFF161026);
  static const Color _cyan = Color(0xFF00E5FF);
  static const Color _magenta = Color(0xFFFF00FF);
  static const Color _cellBg = Color(0xFF1E1E24);
  static const Color _cellBorder = Color(0xFF322756);

  @override
  void initState() {
    super.initState();
    _focusedMonth = widget.focusedMonth;
    _start = widget.initialRange?.start != null
        ? DateUtils.dateOnly(widget.initialRange!.start)
        : null;
    _end = widget.initialRange?.end != null
        ? DateUtils.dateOnly(widget.initialRange!.end)
        : null;
  }

  int get _daysInMonth =>
      DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
  int get _firstWeekday =>
      DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday;

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isSelected(DateTime d) {
    if (_start != null && _end != null) {
      final sd = DateTime(_start!.year, _start!.month, _start!.day);
      final ed = DateTime(_end!.year, _end!.month, _end!.day);
      final cd = DateTime(d.year, d.month, d.day);
      return cd.compareTo(sd) >= 0 && cd.compareTo(ed) <= 0;
    }
    if (_start != null) {
      final sd = DateTime(_start!.year, _start!.month, _start!.day);
      final cd = DateTime(d.year, d.month, d.day);
      return cd == sd;
    }
    return false;
  }

  bool _isStartOrEnd(DateTime d) {
    final cd = DateTime(d.year, d.month, d.day);
    if (_start != null) {
      final sd = DateTime(_start!.year, _start!.month, _start!.day);
      if (cd == sd) return true;
    }
    if (_end != null) {
      final ed = DateTime(_end!.year, _end!.month, _end!.day);
      if (cd == ed) return true;
    }
    return false;
  }

  void _onDateTap(DateTime date) {
    if (date.isBefore(widget.firstDate) || date.isAfter(widget.lastDate)) {
      return;
    }

    setState(() {
      if (_start == null) {
        _start = date;
        _end = null;
      } else if (_end == null) {
        if (date.isBefore(_start!)) {
          _end = _start;
          _start = date;
        } else {
          _end = date;
        }
      } else {
        _start = date;
        _end = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<DateTime?> grid = [];
    final firstDayOffset = _firstWeekday - 1;

    for (int i = 0; i < firstDayOffset; i++) {
      grid.add(null);
    }
    for (int i = 1; i <= _daysInMonth; i++) {
      grid.add(DateTime(_focusedMonth.year, _focusedMonth.month, i));
    }
    while (grid.length % 7 != 0) {
      grid.add(null);
    }

    final double dialogW = MediaQuery.of(context).size.width * 0.85 > 350
        ? 350
        : MediaQuery.of(context).size.width * 0.85;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: dialogW,
        decoration: BoxDecoration(
          color: _bgDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: _magenta.withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: 5,
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white70),
                    onPressed: () => setState(() {
                      _focusedMonth = DateTime(
                        _focusedMonth.year,
                        _focusedMonth.month - 1,
                        1,
                      );
                    }),
                  ),
                  Text(
                    DateFormat('MMMM yyyy', 'it_IT').format(_focusedMonth),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white70),
                    onPressed: () => setState(() {
                      _focusedMonth = DateTime(
                        _focusedMonth.year,
                        _focusedMonth.month + 1,
                        1,
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['L', 'M', 'M', 'G', 'V', 'S', 'D']
                    .map(
                      (d) => SizedBox(
                        width: 36,
                        child: Center(
                          child: Text(
                            d,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: grid.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (_, i) {
                  final date = grid[i];
                  if (date == null) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  }

                  final isSel = _isSelected(date);
                  final isToday = _isToday(date);
                  final isStartEnd = _isStartOrEnd(date);
                  final glowColor = isSel ? _cyan : (isToday ? _magenta : null);

                  return GestureDetector(
                    onTap: () => _onDateTap(date),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSel ? _cyan.withValues(alpha: 0.15) : _cellBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: glowColor?.withValues(alpha: 0.8) ?? _cellBorder,
                          width: (isSel || isToday) ? 1.5 : 1.0,
                        ),
                        boxShadow: (isStartEnd || isToday) && glowColor != null
                            ? [
                                BoxShadow(
                                  color: glowColor.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            color: isStartEnd
                                ? _cyan
                                : (isSel
                                    ? Colors.white
                                    : (isToday ? _magenta : Colors.white)),
                            fontSize: 14,
                            fontWeight: (isSel || isToday)
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text(
                      'Annulla',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _cyan,
                      foregroundColor: _bgDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _start == null
                        ? null
                        : () => Navigator.pop(
                              context,
                              DateTimeRange(
                                start: _start!,
                                end: _end ?? _start!,
                              ),
                            ),
                    child: const Text(
                      'Conferma',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
