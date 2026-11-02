import 'package:contabile_app/providers/app_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

class AppSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onLogout;
  final String role;

  const AppSidebar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
    required this.onLogout,
    this.role = 'User',
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>().currentColors;
    final isAdmin = role.toLowerCase() == 'admin';

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF080812),
        border: Border(
          right: BorderSide(
            color: theme.primary,
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.only(top: 40, bottom: 24, left: 16, right: 16),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/logo.jpg'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildNavItem(context, 0, LucideIcons.home, 'Dashboard'),
                _buildNavItem(
                    context, 1, LucideIcons.arrowLeftRight, 'Movimenti'),
                _buildNavItem(context, 2, LucideIcons.fileText, 'Fatture'),
                _buildNavItem(
                    context, 12, LucideIcons.pieChart, 'Bilancio Fisco'),
                _buildNavItem(
                    context, 5, LucideIcons.fileSignature, 'Preventivi'),
                _buildNavItem(
                    context, 3, LucideIcons.calendarDays, 'Scadenze'),
                _buildNavItem(context, 4, LucideIcons.stickyNote, 'Note'),
                _buildNavItem(
                    context, 6, LucideIcons.users, 'Clienti/Fornitori'),
                _buildNavItem(
                    context, 7, LucideIcons.shoppingCart, 'Servizi Erogati'),
                _buildNavItem(context, 8, LucideIcons.tags, 'Categorie'),
                _buildNavItem(
                    context, 9, Icons.bug_report_outlined, 'Segnalazioni'),
                if (isAdmin)
                  _buildNavItem(
                      context, 10, LucideIcons.settings, 'Impostazioni'),
                _buildNavItem(context, 11, Icons.grid_view_rounded, 'Altro'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: onLogout,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).canvasColor,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: theme.secondary.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: theme.secondary.withValues(alpha: 0.15),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.logOut, color: theme.secondary, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Esci',
                      style: TextStyle(
                        color: theme.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData icon,
    String title,
  ) {
    final isSelected = currentIndex == index;
    final theme = context.watch<AppThemeProvider>().currentColors;

    final activeGradient = LinearGradient(
      colors: [theme.primary, const Color(0xFF0033FF)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onItemSelected(index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: isSelected ? activeGradient : null,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border(left: BorderSide(color: theme.primary, width: 3))
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(-2, 0),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : theme.primary,
                size: 20,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFFA9A9B8),
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
