import 'dart:io';
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
      backgroundColor: const Color(0xFF1A1D24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF3A3F4B),
                  const Color(0xFF2A2D34),
                  const Color(0xFF4A4F5A),
                  const Color(0xFF2A2D34),
                  const Color(0xFF3A3F4B),
                ],
                stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF2A2D34),
                    child: theme.hasValidLogo
                        ? ClipOval(
                            child: Image.file(
                              File(theme.logoImagePath!),
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(Icons.account_balance_wallet, size: 30, color: theme.primaryColor),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        Colors.white,
                        Colors.white.withOpacity(0.85),
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
                            color: Colors.black.withOpacity(0.5),
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
