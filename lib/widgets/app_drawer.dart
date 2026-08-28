import 'package:flutter/material.dart';
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
      backgroundColor: const Color(0xFF1E1E24),
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: theme.primaryColor),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.account_balance_wallet, size: 30, color: theme.primaryColor),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'BimboMixer\nContabilità',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
            leading: Icon(Icons.logout, color: Colors.redAccent),
            title: Text('Esci', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: onLogout,
          ),
          SizedBox(height: 16),
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
      selectedTileColor: primaryColor.withOpacity(0.1),
      onTap: () {
        onItemSelected(index);
        Navigator.pop(context); // Chiudi il drawer
      },
    );
  }
}
