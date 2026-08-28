import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_theme_provider.dart';
import 'deadlines_screen.dart';
import 'scheduled_payments_screen.dart';
import 'memo_events_screen.dart';

class DeadlinesSelectionScreen extends StatelessWidget {
  const DeadlinesSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    
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
        title: Text('Gestione Scadenze', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _buildSelectionCard(
                context: context,
                title: 'Pagamento Tasse',
                icon: Icons.account_balance,
                description: 'Visualizza e gestisci le scadenze fiscali',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DeadlinesScreen()),
                  );
                },
                theme: theme,
                isDesktop: isDesktop,
              ),
              _buildSelectionCard(
                context: context,
                title: 'Pagamenti Programmati',
                icon: Icons.schedule,
                description: 'Scadenziario dei pagamenti in dare o in avere',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScheduledPaymentsScreen()),
                  );
                },
                theme: theme,
                isDesktop: isDesktop,
              ),
              _buildSelectionCard(
                context: context,
                title: 'Memo pagamenti eventi',
                icon: Icons.note_alt,
                description: 'Pre-compila e traccia i memo per pagamenti e fatture',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MemoEventsScreen()),
                  );
                },
                theme: theme,
                isDesktop: isDesktop,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String description,
    required VoidCallback onTap,
    required AppThemeProvider theme,
    required bool isDesktop,
  }) {
    return Card(
      elevation: 4,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: isDesktop ? 300 : MediaQuery.of(context).size.width * 0.8,
          height: 200,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: Colors.blueAccent),
              SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.54),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



