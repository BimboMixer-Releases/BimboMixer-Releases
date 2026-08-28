import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/app_theme_provider.dart';
import 'dashboard_screen.dart';
import 'payments_screen.dart';
import 'invoices_screen.dart';
import 'deadlines_selection_screen.dart';
import 'menu_screen.dart';
import 'notes_screen.dart';
import 'quotes_screen.dart';
import 'login_screen.dart';
import '../widgets/app_drawer.dart';
import '../services/secure_storage_service.dart';

class MainScreen extends StatefulWidget {
  final String role;
  final String username;
  
  const MainScreen({super.key, required this.role, this.username = ''});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  DateTime? _lastActivity;

  // Timeout sessione: 30 minuti di inattività
  static const int _sessionTimeoutMinutes = 30;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastActivity = DateTime.now();
    _screens = [
      DashboardScreen(role: widget.role),
      const PaymentsScreen(),
      const InvoicesScreen(),
      const DeadlinesSelectionScreen(),
      const NotesScreen(),
      const QuotesScreen(),
      MenuScreen(role: widget.role),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSessionTimeout();
    } else if (state == AppLifecycleState.paused) {
      _lastActivity = DateTime.now();
    }
  }

  void _checkSessionTimeout() {
    if (_lastActivity != null) {
      final elapsed = DateTime.now().difference(_lastActivity!);
      if (elapsed.inMinutes >= _sessionTimeoutMinutes) {
        _logout(reason: 'Sessione scaduta per inattività.');
      }
    }
    _lastActivity = DateTime.now();
  }

  Future<void> _logout({String? reason}) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      // Non bloccare il logout
    }
    
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      if (reason != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(reason), backgroundColor: Colors.orange),
        );
      }
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disconnessione'),
        content: Text('Sei sicuro di voler uscire dall\'app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ANNULLA'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: Text('ESCI', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reset activity timer on any interaction
    _lastActivity = DateTime.now();
    final theme = context.watch<AppThemeProvider>();

    return Scaffold(
      backgroundColor: theme.hasValidBackground ? Colors.transparent : const Color(0xFF121212),
      body: Container(
        decoration: theme.hasValidBackground
            ? BoxDecoration(
                image: DecorationImage(
                  image: FileImage(File(theme.backgroundImagePath!)),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.8), // Sfondo molto scuro per non dare fastidio
                    BlendMode.darken,
                  ),
                ),
              )
            : null,
        child: _screens[_currentIndex],
      ),
      drawer: AppDrawer(
        currentIndex: _currentIndex,
        onItemSelected: (index) {
          setState(() => _currentIndex = index);
        },
        onLogout: _showLogoutConfirmation,
      ),
    );
  }
}
