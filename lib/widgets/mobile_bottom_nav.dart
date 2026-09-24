import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../utils/app_colors.dart';
import '../providers/app_theme_provider.dart';
import 'package:provider/provider.dart';

class MobileBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  const MobileBottomNav({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>().currentColors;
    
    // Map main index to bottom nav index (Home, Movimenti, Fatture, Scadenze, Altro)
    // 0: Dashboard
    // 1: Payments
    // 2: Invoices
    // 3: Deadlines
    // 6: Menu/Altro
    int bottomNavIndex = 0;
    switch (currentIndex) {
      case 0: bottomNavIndex = 0; break;
      case 1: bottomNavIndex = 1; break;
      case 2: bottomNavIndex = 2; break;
      case 3: bottomNavIndex = 3; break;
      default: bottomNavIndex = 4; break;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
        border: Border(
          top: BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, bottomNavIndex == 0, LucideIcons.layoutDashboard, 'Home', theme),
              _buildNavItem(1, bottomNavIndex == 1, LucideIcons.arrowRightLeft, 'Movimenti', theme),
              _buildNavItem(2, bottomNavIndex == 2, LucideIcons.fileText, 'Fatture', theme),
              _buildNavItem(3, bottomNavIndex == 3, LucideIcons.calendarDays, 'Scadenze', theme),
              _buildNavItem(11, bottomNavIndex == 4, LucideIcons.menu, 'Altro', theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int targetIndex, bool isSelected, IconData icon, String label, ThemeColors theme) {
    return GestureDetector(
      onTap: () => onItemSelected(targetIndex),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? theme.primary.withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? theme.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? theme.primary : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
