import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/app_theme_provider.dart';
import 'package:provider/provider.dart';

class AppDrawer extends StatelessWidget {
  final int currentIndex;
  final Function(int) onItemSelected;
  final VoidCallback onLogout;

  const AppDrawer({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();

    return Drawer(
      backgroundColor: const Color(0xFF080812), // Stesso colore di app_sidebar
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
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF2A2D34),
                    child: Icon(LucideIcons.wallet, size: 30, color: theme.primaryColor),
                  ),
                ),
                SizedBox(width: 16),
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
                _buildDrawerItem(context, 0, Icons.dashboard, 'Dashboard', theme.primaryColor),
                _buildDrawerItem(context, 1, Icons.swap_horiz, 'Movimenti', theme.primaryColor),
                _buildDrawerItem(context, 2, Icons.receipt, 'Fatture', theme.primaryColor),
                _buildDrawerItem(context, 3, Icons.calendar_today, 'Scadenze', theme.primaryColor),
                _buildDrawerItem(context, 4, Icons.note, 'Note', theme.primaryColor),
                _buildDrawerItem(context, 5, Icons.description, 'Preventivi', theme.primaryColor),
                _buildDrawerItem(context, 6, Icons.menu, 'Altro', theme.primaryColor),
              ],
            ),
          ),
          Divider(color: Colors.white24),
          ListTile(
            leading: Icon(Icons.logout, color: theme.currentColors.secondary),
            title: Text('Esci', style: TextStyle(color: theme.currentColors.secondary, fontWeight: FontWeight.bold)),
            onTap: onLogout,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, int index, IconData icon, String title, Color primaryColor) {
    bool isSelected = currentIndex == index;
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
        Navigator.pop(context); // Chiudi il drawer
      },
    );
  }
}
