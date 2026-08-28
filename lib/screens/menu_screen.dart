import 'package:flutter/material.dart';
import 'customers_screen.dart';
import 'categories_screen.dart';
import 'services_screen.dart';
import 'users_screen.dart';
import 'settings_screen.dart';
import 'data_import_screen.dart';
import 'security_center_screen.dart';
import 'changelog_screen.dart';
import 'quotes_screen.dart';
import 'reports_screen.dart';
import 'package:provider/provider.dart';
import '../providers/app_theme_provider.dart';
import '../widgets/hover_glow_text.dart';

class MenuScreen extends StatelessWidget {
  final String role;
  
  const MenuScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              context.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer();
            },
          ),
        ),
        title: Text('Altro', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeader('Utenti e Clienti', theme),
            _buildMenuItem(context, theme, Icons.people, 'Clienti/Fornitori', const CustomersScreen()),
            if (role.toLowerCase() == 'admin')
              _buildMenuItem(context, theme, Icons.security, 'Gestione Utenti', const UsersScreen()),

            _buildSectionHeader('Inserimento Voci', theme),
            _buildMenuItem(context, theme, Icons.category, 'Categorie', const CategoriesScreen()),
            _buildMenuItem(context, theme, Icons.miscellaneous_services, 'Tipi Prestazione', const ServicesScreen()),

            if (role.toLowerCase() == 'admin') ...[
              _buildSectionHeader('Amministrazione', theme),
              _buildMenuItem(context, theme, Icons.admin_panel_settings, 'Security Center', const SecurityCenterScreen()),
              _buildMenuItem(context, theme, Icons.settings, 'Impostazioni', const SettingsScreen()),
              _buildMenuItem(context, theme, Icons.bug_report, 'Report Bug e Consigli', const ReportsScreen()),
            ],

            _buildSectionHeader('Informazioni', theme),
            _buildMenuItem(context, theme, Icons.info_outline, 'Versione & Changelog', const ChangelogScreen()),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, AppThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.primaryColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, AppThemeProvider theme, IconData icon, String title, Widget screen) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderColor),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
        leading: Icon(icon, color: theme.primaryColor),
        title: HoverGlowText(
          title, 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          glowColor: theme.primaryColor,
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.54), size: 16),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
        },
      )),
    );
  }
}


