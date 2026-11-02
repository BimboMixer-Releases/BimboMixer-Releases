import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/app_theme_provider.dart';

class AppDrawer extends StatelessWidget {
  final int currentIndex;
  final Function(int) onItemSelected;
  final VoidCallback onLogout;
  final String role;

  const AppDrawer({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
    required this.onLogout,
    this.role = 'User',
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();
    final isAdmin = role.toLowerCase() == 'admin';

    return Drawer(
      backgroundColor: const Color(0xFF080812),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF080812),
              border: Border(
                right: BorderSide(
                  color: theme.currentColors.primary,
                  width: 1.0,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.currentColors.primary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFF2A2D34),
                    backgroundImage:
                        AssetImage('assets/images/logo_bimbomixer_neon.jpg'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        Colors.white,
                        Colors.white.withValues(alpha: 0.85),
                        Colors.white,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ).createShader(bounds),
                    child: Text(
                      'Bimbomixer Contabilità',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  0,
                  LucideIcons.home,
                  'Dashboard',
                  theme.primaryColor,
                ),
                _buildDrawerItem(
                  context,
                  1,
                  LucideIcons.arrowLeftRight,
                  'Movimenti',
                  theme.primaryColor,
                ),
                _buildDrawerItem(
                  context,
                  2,
                  LucideIcons.fileText,
                  'Fatture',
                  theme.primaryColor,
                ),
                _buildDrawerItem(
                  context,
                  12,
                  LucideIcons.pieChart,
                  'Bilancio Fisco',
                  theme.primaryColor,
                ),
                _buildDrawerItem(
                  context,
                  5,
                  LucideIcons.fileSignature,
                  'Preventivi',
                  theme.primaryColor,
                ),
                _buildDrawerItem(
                  context,
                  3,
                  LucideIcons.calendarDays,
                  'Scadenze',
                  theme.primaryColor,
                ),
                _buildDrawerItem(
                  context,
                  4,
                  LucideIcons.stickyNote,
                  'Note',
                  theme.primaryColor,
                ),
                _buildDrawerItem(
                  context,
                  6,
                  LucideIcons.users,
                  'Clienti/Fornitori',
                  theme.primaryColor,
                ),
                _buildDrawerItem(
                  context,
                  7,
                  LucideIcons.shoppingCart,
                  'Servizi Erogati',
                  theme.primaryColor,
                ),
                _buildDrawerItem(
                  context,
                  8,
                  LucideIcons.tags,
                  'Categorie',
                  theme.primaryColor,
                ),
                _buildDrawerItem(
                  context,
                  9,
                  Icons.bug_report_outlined,
                  'Segnalazioni',
                  theme.primaryColor,
                ),
                if (isAdmin)
                  _buildDrawerItem(
                    context,
                    10,
                    LucideIcons.settings,
                    'Impostazioni',
                    theme.primaryColor,
                  ),
                _buildDrawerItem(
                  context,
                  11,
                  Icons.grid_view_rounded,
                  'Altro',
                  theme.primaryColor,
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: Icon(Icons.logout, color: theme.currentColors.secondary),
            title: Text(
              'Esci',
              style: TextStyle(
                color: theme.currentColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: onLogout,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    int index,
    IconData icon,
    String title,
    Color primaryColor,
  ) {
    final bool isSelected = currentIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? primaryColor : Colors.white70),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? primaryColor : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: primaryColor.withValues(alpha: 0.1),
      onTap: () {
        onItemSelected(index);
        Navigator.pop(context);
      },
    );
  }
}
