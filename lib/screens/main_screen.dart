import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_colors.dart';
import 'customers_screen.dart';
import 'services_screen.dart';
import 'categories_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'dashboard_screen.dart';
import 'payments_screen.dart';
import 'invoices_screen.dart';
import 'deadlines_selection_screen.dart';
import 'menu_screen.dart';
import 'bilancio_fisco_screen.dart';
import 'notes_screen.dart';
import 'quotes_screen.dart';
import 'login_screen.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/app_drawer.dart';

class MainScreen extends StatefulWidget {
  final String role;
  final String username;

  const MainScreen({super.key, required this.role, this.username = ''});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final List<int> _sectionHistory = [];
  final _shellKey = GlobalKey<ScaffoldState>();
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
      const CustomersScreen(),
      const ServicesScreen(),
      const CategoriesScreen(),
      const ReportsScreen(),
      const SettingsScreen(),
      MenuScreen(role: widget.role),
      const BilancioFiscoScreen(),
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
        backgroundColor: AppColors.panelBackground,
        title: const Text(
          'Disconnessione',
          style: TextStyle(color: AppColors.textMain),
        ),
        content: const Text(
          'Sei sicuro di voler uscire dall\'app?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'ANNULLA',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expenseRed,
            ),
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: const Text(
              'ESCI',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectSection(int index) {
    if (index == _currentIndex) return;
    setState(() {
      if (index == 0) {
        _sectionHistory.clear();
      } else {
        _sectionHistory.add(_currentIndex);
      }
      _currentIndex = index;
    });
  }

  void _goBack() {
    if (_shellKey.currentState?.isDrawerOpen ?? false) {
      _shellKey.currentState?.closeDrawer();
      return;
    }
    if (_sectionHistory.isEmpty) return;
    setState(() => _currentIndex = _sectionHistory.removeLast());
  }

  Widget _sectionBody() => Column(
    children: [
      if (_sectionHistory.isNotEmpty)
        SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Torna alla sezione precedente',
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _goBack,
            ),
          ),
        ),
      Expanded(child: _screens[_currentIndex]),
    ],
  );

  @override
  Widget build(BuildContext context) {
    _lastActivity = DateTime.now();

    return PopScope(
      canPop: _sectionHistory.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        if (isDesktop) {
          // DESKTOP LAYOUT (Sidebar)
          return Scaffold(
            key: _shellKey,
            backgroundColor: const Color(0xFF080614), // Dark deep neon base
            body: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.5, -0.8),
                  radius: 1.5,
                  colors: [
                    Color(0xFF2A114A), // Neon purple glow top
                    Color(0xFF080614), // Deep dark
                  ],
                ),
              ),
              child: Row(
                children: [
                  AppSidebar(
                    currentIndex: _currentIndex,
                    onItemSelected: _selectSection,
                    onLogout: _showLogoutConfirmation,
                  ),
                  Expanded(child: _sectionBody()),
                ],
              ),
            ),
          );
        } else {
          // MOBILE LAYOUT (Bottom Navigation)
          return Scaffold(
            key: _shellKey,
            backgroundColor: const Color(0xFF080614),
            body: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -1.0),
                  radius: 1.5,
                  colors: [Color(0xFF2A114A), Color(0xFF080614)],
                ),
              ),
              child: _sectionBody(),
            ),
            drawer: AppDrawer(
              currentIndex: _currentIndex,
              onItemSelected: _selectSection,
              onLogout: _showLogoutConfirmation,
            ),
          );
        }
      },
      ),
    );
  }
}
