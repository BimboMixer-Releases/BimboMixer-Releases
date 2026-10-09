import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Mostra un date picker in stile glassmorphism scuro (come da design reference).
/// Restituisce la data selezionata o null se annullato.
class GlassDatePicker {
  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final DateTime now = DateTime.now();
    DateTime focusedMonth = DateTime(
      (initialDate ?? now).year,
      (initialDate ?? now).month,
      1,
    );
    DateTime? selected = initialDate;

    return await showDialog<DateTime>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) {
        return _GlassCalendarDialog(
          focusedMonth: focusedMonth,
          selected: selected,
          firstDate: firstDate ?? DateTime(2000),
          lastDate: lastDate ?? DateTime(2100),
        );
      },
    );
  }
}

class _GlassCalendarDialog extends StatefulWidget {
  final DateTime focusedMonth;
  final DateTime? selected;
  final DateTime firstDate;
  final DateTime lastDate;

  const _GlassCalendarDialog({
    required this.focusedMonth,
    required this.selected,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_GlassCalendarDialog> createState() => _GlassCalendarDialogState();
}

class _GlassCalendarDialogState extends State<_GlassCalendarDialog> {
  late DateTime _focusedMonth;
  DateTime? _selected;

  static const Color _bgDark = Color(0xFF0F0C1B);
  static const Color _cyan = Color(0xFF00E5FF);
  static const Color _magenta = Color(0xFFC040FF);
  static const Color _cellBg = Color(0x0DFFFFFF); // 5% white
  static const Color _cellBorder = Color(0x1AFFFFFF); // 10% white

  @override
  void initState() {
    super.initState();
    _focusedMonth = widget.focusedMonth;
    _selected = widget.selected;
  }

  int get _daysInMonth =>
      DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);

  List<DateTime?> get _grid {
    final first = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startWeekday = first.weekday; // 1=Mon
    final grid = <DateTime?>[];
    for (int i = 1; i < startWeekday; i++) grid.add(null);
    for (int i = 1; i <= _daysInMonth; i++) {
      grid.add(DateTime(_focusedMonth.year, _focusedMonth.month, i));
    }
    while (grid.length % 7 != 0) grid.add(null);
    return grid;
  }

  bool _isSelected(DateTime? d) =>
      d != null &&
      _selected != null &&
      d.year == _selected!.year &&
      d.month == _selected!.month &&
      d.day == _selected!.day;

  bool _isToday(DateTime? d) {
    final now = DateTime.now();
    return d != null &&
        d.year == now.year &&
        d.month == now.month &&
        d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final grid = _grid;
    final screenW = MediaQuery.of(context).size.width;
    final dialogW = screenW > 440 ? 400.0 : screenW * 0.92;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Header: mese + anno + frecce ───────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white70),
                  onPressed: () => setState(() {
                    _focusedMonth = DateTime(
                        _focusedMonth.year, _focusedMonth.month - 1, 1);
                  }),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_focusedMonth),
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
                        _focusedMonth.year, _focusedMonth.month + 1, 1);
                  }),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ─── Giorni della settimana ──────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['L', 'M', 'M', 'G', 'V', 'S', 'D']
                  .map((d) => SizedBox(
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
                      ))
                  .toList(),
            ),

            const SizedBox(height: 8),

            // ─── Griglia giorni ──────────────────────────────────────────
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
                final glowColor = isSel ? _cyan : (isToday ? _magenta : null);

                return GestureDetector(
                  onTap: () {
                    if (date.isBefore(widget.firstDate) ||
                        date.isAfter(widget.lastDate)) return;
                    setState(() => _selected = date);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSel
                          ? _cyan.withValues(alpha: 0.15)
                          : _cellBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: glowColor?.withValues(alpha: 0.8) ??
                            _cellBorder,
                        width: (isSel || isToday) ? 1.5 : 1.0,
                      ),
                      boxShadow: (isSel || isToday) && glowColor != null
                          ? [
                              BoxShadow(
                                color: glowColor.withValues(alpha: 0.3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isSel
                              ? _cyan
                              : (isToday ? _magenta : Colors.white),
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

            // ─── Pulsanti Conferma / Annulla ─────────────────────────────
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
                        horizontal: 24, vertical: 12),
                  ),
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.pop(context, _selected),
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
    );
  }
}
