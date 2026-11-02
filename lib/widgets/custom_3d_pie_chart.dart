import 'dart:math' as math;
import 'package:contabile_app/utils/currency_utils.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ModernPieChartPanel extends StatelessWidget {
  final List<MapEntry<String, double>> sortedCats;
  final Map<String, Color> categoryColors;
  final List<Color> palette;
  final Map<String, String> categoryNames;
  final bool isFullScreen;
  final Widget? titleDropdown;

  const ModernPieChartPanel({
    super.key,
    required this.sortedCats,
    required this.categoryColors,
    required this.palette,
    required this.categoryNames,
    this.isFullScreen = false,
    this.titleDropdown,
  });

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, double>> groupedCats = [];
    double othersTotal = 0;

    for (int i = 0; i < sortedCats.length; i++) {
      if (i < 3) {
        groupedCats.add(sortedCats[i]);
      } else {
        othersTotal += sortedCats[i].value;
      }
    }
    if (othersTotal > 0) {
      groupedCats.add(MapEntry('altre_categorie', othersTotal));
    }

    final total = groupedCats.fold<double>(0, (s, e) => s + e.value);
    final currencyFmt = NumberFormat.currency(locale: 'it_IT', symbol: '€');

    final Widget contentWidget = LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth > 600;

        final Widget header = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                    ),
                    child: const Icon(
                      LucideIcons.pieChart,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DefaultTextStyle(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                          child: titleDropdown ??
                              const Text(
                                'RIPARTIZIONE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                        ),
                        Text(
                          'Tocca una sezione per i dettagli',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        if (!isFullScreen) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              header,
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildChart(
                        groupedCats,
                        total,
                        currencyFmt,
                        small: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        child: _buildListLegend(
                          groupedCats,
                          total,
                          currencyFmt,
                          small: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        } else {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: 32),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: _buildChart(
                          groupedCats,
                          total,
                          currencyFmt,
                          small: false,
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 1,
                        child: _buildListLegend(
                          groupedCats,
                          total,
                          currencyFmt,
                          small: false,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      SizedBox(
                        height: 250,
                        child: _buildChart(
                          groupedCats,
                          total,
                          currencyFmt,
                          small: false,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildListLegend(
                        groupedCats,
                        total,
                        currencyFmt,
                        small: false,
                      ),
                    ],
                  ),
                const SizedBox(height: 32),
                if (groupedCats.isNotEmpty)
                  _buildBottomSquares(groupedCats, total, currencyFmt),
              ],
            ),
          );
        }
      },
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F111A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding:
          isFullScreen ? const EdgeInsets.all(24) : const EdgeInsets.all(12),
      child: contentWidget,
    );
  }

  Color _getColor(String key, int index) {
    if (key == 'altre_categorie') return const Color(0xFF94A3B8);
    if (categoryColors.containsKey(key)) return categoryColors[key]!;
    if (palette.isEmpty) return const Color(0xFF3B82F6);
    return palette[index % palette.length];
  }

  IconData _getIcon(String key) {
    if (key == 'altre_categorie') return LucideIcons.layoutGrid;
    if (key.toLowerCase().contains('materiale') ||
        key.toLowerCase().contains('acquist')) {
      return LucideIcons.shoppingCart;
    }
    if (key.toLowerCase().contains('manodopera') ||
        key.toLowerCase().contains('servizi')) {
      return LucideIcons.hardHat;
    }
    return LucideIcons.moreHorizontal;
  }

  String _getName(String key) {
    if (key == 'altre_categorie') return 'Altre Categorie';
    return categoryNames[key] ?? key;
  }

  Widget _buildChart(
    List<MapEntry<String, double>> cats,
    double total,
    NumberFormat fmt, {
    bool small = false,
  }) {
    if (cats.isEmpty) {
      return const Center(
        child: Text('Nessun dato', style: TextStyle(color: Colors.white54)),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: small ? 110 : 200,
          height: small ? 110 : 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
        ),
        PieChart(
          PieChartData(
            sectionsSpace: 4,
            centerSpaceRadius: small ? 35 : 60,
            sections: cats.asMap().entries.map((e) {
              final i = e.key;
              final entry = e.value;
              final color = _getColor(entry.key, i);
              return PieChartSectionData(
                color: color,
                value: entry.value,
                showTitle: false,
                radius: small ? 25 : 40,
              );
            }).toList(),
          ),
        ),
        IgnorePointer(
          child: Container(
            width: small ? 130 : 220,
            height: small ? 130 : 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.5),
                radius: 1.0,
                colors: [
                  Colors.white.withValues(alpha: 0.4),
                  Colors.white.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.6),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        SizedBox(
          width: small ? 68 : 112,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Totale',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: small ? 10 : 14,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${CurrencyUtils.formatNumber(total)} €',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: small ? 14 : 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '100%',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: small ? 9 : 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListLegend(
    List<MapEntry<String, double>> cats,
    double total,
    NumberFormat fmt, {
    bool small = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: cats.asMap().entries.map((e) {
        final i = e.key;
        final entry = e.value;
        final color = _getColor(entry.key, i);
        final pct = total > 0 ? (entry.value / total * 100) : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: small
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.05),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.15),
                color.withValues(alpha: 0.02),
              ],
            ),
          ),
          child: Row(
            children: [
              Icon(_getIcon(entry.key), color: color, size: small ? 16 : 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getName(entry.key),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: small ? 10 : 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '${CurrencyUtils.formatNumber(entry.value)} €',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: small ? 10 : 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: color,
                            fontSize: small ? 10 : 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomSquares(
    List<MapEntry<String, double>> cats,
    double total,
    NumberFormat fmt,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: cats.asMap().entries.map((e) {
            final i = e.key;
            final entry = e.value;
            final color = _getColor(entry.key, i);
            final pct = total > 0 ? (entry.value / total * 100) : 0.0;

            final rawWidth =
                (constraints.maxWidth - (cats.length - 1) * 12) / cats.length;
            final width = math.max(0.0, rawWidth);

            return Container(
              width: width,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.3),
                    color.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getIcon(entry.key), color: color, size: 28),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${CurrencyUtils.formatNumber(entry.value)} €',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
