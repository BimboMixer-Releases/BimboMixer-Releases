import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:contabile_app/database/database_helper.dart';
import 'package:contabile_app/screens/main_screen.dart';
import 'package:contabile_app/widgets/glass_container.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:contabile_app/services/update_service.dart';
import 'package:contabile_app/widgets/update_dialog.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/secure_storage_service.dart';
import '../services/biometric_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final SecureStorageService _secureStorage = SecureStorageService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';
  String? _lastBiometricUser;
  bool _isBiometricSupported = false;
  bool _rememberMe = false;

  // Rate limiting
  static const int _maxLoginAttempts = 3;
  static const int _lockoutMinutes = 5;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
    _checkBiometrics();
    _loadSavedCredentials();
  }

  String _getDeviceType() {
    if (kIsWeb) return 'Computer / Web';
    return (Platform.isAndroid || Platform.isIOS) ? 'Cellulare' : 'Computer';
  }

  Future<void> _loadSavedCredentials() async {
    final savedUser = await _secureStorage.read(key: 'saved_username');
    if (!mounted) return;
    if (savedUser != null && savedUser.isNotEmpty) {
      setState(() {
        _usernameController.text = savedUser;
        _rememberMe = true;
      });
    }
  }

  Future<void> _checkBiometrics() async {
    final bioService = BiometricService();
    final supported = await bioService.isBiometricAvailable();
    if (!mounted) return;
    setState(() {
      _isBiometricSupported = supported;
    });
    if (supported) {
      final user = await bioService.getLastBiometricUser();
      if (!mounted) return;
      if (user != null && user.isNotEmpty) {
        setState(() {
          _lastBiometricUser = user;
          if (_usernameController.text.trim().isEmpty) {
            _usernameController.text = user;
          }
        });
      }
    }
  }

  Future<void> _loginWithBiometrics() async {
    final bioService = BiometricService();
    var user = _usernameController.text.trim();
    if (user.isEmpty) {
      if (_lastBiometricUser != null && _lastBiometricUser!.isNotEmpty) {
        user = _lastBiometricUser!;
        setState(() {
          _usernameController.text = user;
        });
      } else {
        setState(() {
          _errorMessage = 'Inserisci il tuo username per usare la biometria.';
        });
        return;
      }
    }

    final authenticated = await bioService.authenticate(
      reason: 'Autenticati per effettuare l\'accesso',
    );
    if (!mounted) return;

    if (authenticated) {
      final password = await bioService.getSavedPassword(user);
      if (!mounted) return;
      if (password != null && password.isNotEmpty) {
        _passwordController.text = password;
        await _login();
      } else {
        setState(() {
          _errorMessage =
              'Biometria non configurata per "$user". Abilitala dalla Gestione Utenti.';
        });
      }
    }
  }

  Future<void> _checkForUpdates() async {
    final updateService = UpdateService();
    final updateData = await updateService.checkForUpdate();
    if (!mounted || updateData == null) return;
    try {
      await _audioPlayer.play(AssetSource('audio/notification.mp3'));
    } catch (_) {
      // Errore riproduzione suono non critico
    }
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          UpdateDialog(updateData: updateData, updateService: updateService),
    );
  }

  Future<void> _login() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Inserisci username e password';
      });
      return;
    }

    // Rate limiting: controlla tentativi recenti
    try {
      final recentAttempts = await _dbHelper.getRecentFailedAttempts(
        username,
        minutes: _lockoutMinutes,
      );
      if (!mounted) return;
      if (recentAttempts >= _maxLoginAttempts) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Troppi tentativi falliti. Riprova tra $_lockoutMinutes minuti.';
        });
        return;
      }
    } catch (_) {
      // Se il rate limiting fallisce prima dell'auth, non bloccare il login
    }

    final String sanitizedUser =
        username.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final String authEmail = '$sanitizedUser@bimbomixer.local';

    try {
      // 1. Authenticate with Firebase Auth
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

      // 2. Verifica credenziali in Firestore con password hashata
      final verifiedUser =
          await _dbHelper.verifyCredentials(username, password);
      if (!mounted) return;

      setState(() => _isLoading = false);

      if (verifiedUser != null) {
        final rawRole = verifiedUser['role']?.toString() ?? 'User';
        final role = rawRole.toLowerCase() == 'admin' ? 'Admin' : 'User';
        _dbHelper.currentUser = username;

        // Salva solo username (mai la password) per "Ricordami"
        if (_rememberMe) {
          await _secureStorage.write(key: 'saved_username', value: username);
        } else {
          await _secureStorage.delete(key: 'saved_username');
        }

        // Pulisci vecchi tentativi di login
        _dbHelper.cleanOldLoginAttempts();

        if (!mounted) return;
        try {
          await _dbHelper.logAccess(
            username,
            role,
            _getDeviceType(),
            eventType: 'login_success',
          );
        } catch (_) {
          // Non bloccare il login se il logging fallisce
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Benvenuto $username!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MainScreen(role: role, username: username),
          ),
        );
      } else {
        await FirebaseAuth.instance.signOut();

        // Registra tentativo fallito
        try {
          final attempts = await _dbHelper.recordFailedLogin(username);
          await _dbHelper.logAccess(
            username,
            'unknown',
            _getDeviceType(),
            eventType: 'login_failed',
          );
          if (!mounted) return;
          final remaining = _maxLoginAttempts - attempts;
          setState(() {
            if (remaining > 0) {
              _errorMessage =
                  'Credenziali non valide. Tentativi rimasti: $remaining';
            } else {
              _errorMessage =
                  'Account temporaneamente bloccato. Riprova tra $_lockoutMinutes minuti.';
            }
          });
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Credenziali non valide.';
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      int? attempts;
      if (e.code != 'network-request-failed') {
        try {
          attempts = await _dbHelper.recordFailedLogin(username);
          await _dbHelper.logAccess(
            username,
            'unknown',
            _getDeviceType(),
            eventType: 'login_failed',
          );
        } catch (_) {
          // Non bloccare la gestione errore se Firestore rifiuta scritture non autenticate
        }
      }
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (e.code == 'user-not-found' ||
            e.code == 'invalid-credential' ||
            e.code == 'wrong-password') {
          if (attempts != null && attempts >= _maxLoginAttempts) {
            _errorMessage =
                'Account temporaneamente bloccato. Riprova tra $_lockoutMinutes minuti.';
          } else {
            _errorMessage =
                'Credenziali di autenticazione non valide o account inesistente.';
          }
        } else if (e.code == 'network-request-failed') {
          _errorMessage = 'Errore di rete. Verifica la connessione.';
        } else {
          _errorMessage = 'Errore di autenticazione (${e.code}).';
        }
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (e.code == 'permission-denied') {
          _errorMessage = 'Permessi insufficienti per accedere al database.';
        } else {
          _errorMessage = 'Errore database (${e.code}).';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Errore imprevisto. Riprova.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0A10), // Sfondo scuro neon
      body: Stack(
        children: [
          // Sfondo con leggeri gradienti per dare l'effetto neon
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF885CF6).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFEC4899).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // LOGO NEON
                      Center(
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF885CF6).withValues(alpha: 0.6),
                                blurRadius: 40,
                                spreadRadius: -10,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/images/logo_bimbomixer_neon.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // BENTORNATO
                      const Text(
                        'Bentornato!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Accedi al tuo account per\ngestire la tua attività in modo semplice.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // NOME UTENTE
                      TextField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Nome utente',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: Colors.white70,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF4A3B69),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF4A3B69),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF885CF6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // PASSWORD
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onSubmitted: (_) {
                          if (!_isLoading) _login();
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: Colors.white70,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white70,
                            ),
                            tooltip: _obscurePassword
                                ? 'Mostra password'
                                : 'Nascondi password',
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF4A3B69),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF4A3B69),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF885CF6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // RICORDA E PASSWORD DIMENTICATA
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Theme(
                                data: Theme.of(context).copyWith(
                                  unselectedWidgetColor: Colors.white54,
                                ),
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (val) {
                                    setState(() {
                                      _rememberMe = val ?? false;
                                    });
                                  },
                                  activeColor: const Color(0xFF885CF6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              Text(
                                'Ricorda',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Flexible(
                            child: TextButton(
                              onPressed: _showRecoveryWizard,
                              child: const Text(
                                'Password dimenticata?',
                                style: TextStyle(
                                  color: Color(0xFFEC4899),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // PULSANTE ACCEDI
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEC4899), Color(0xFF885CF6)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF885CF6).withValues(
                                alpha: 0.5,
                              ),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Accedi',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ACCESSO IMPRONTA
                      if (_isBiometricSupported)
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _loginWithBiometrics,
                          icon: const Icon(
                            Icons.fingerprint,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "Accesso con l'impronta",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Color(0xFF4A3B69)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),

                      const SizedBox(height: 40),

                      // ICONS ROW
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.lock_outline,
                                  color: Color(0xFFEC4899),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Sicuro',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'I tuoi dati protetti',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.cloud_queue,
                                  color: Color(0xFFEC4899),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Sincronizzato',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'su tutti i dispositivi',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.bar_chart,
                                  color: Color(0xFFEC4899),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Smart',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Gestisci in mobilità',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRecoveryWizard() {
    showDialog(
      context: context,
      builder: (_) => const _RecoveryWizardDialog(),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}

class _RecoveryWizardDialog extends StatefulWidget {
  const _RecoveryWizardDialog();

  @override
  State<_RecoveryWizardDialog> createState() => _RecoveryWizardDialogState();
}

class _RecoveryWizardDialogState extends State<_RecoveryWizardDialog> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  bool _isRecovering = false;
  String _errorMsg = '';
  String _successMsg = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _recover() async {
    if (_isRecovering) return;
    setState(() {
      _errorMsg = '';
      _successMsg = '';
    });
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (email.isEmpty || phone.isEmpty) {
      setState(() => _errorMsg = 'Compila entrambi i campi.');
      return;
    }

    setState(() => _isRecovering = true);
    try {
      final dbHelper = DatabaseHelper();
      final users = await dbHelper.getUsers();
      if (!mounted) return;

      final matchingUsers = users
          .where(
            (u) =>
                (u['email']?.toString().trim().toLowerCase() ?? '') ==
                    email.toLowerCase() &&
                (u['phone']?.toString().trim() ?? '') == phone,
          )
          .toList();

      if (matchingUsers.isNotEmpty) {
        final data = matchingUsers.first;
        setState(() {
          _successMsg =
              'Account trovato!\nUsername: ${data["username"]}\n\nPer resettare la password, contatta un amministratore.';
        });
      } else {
        setState(
          () => _errorMsg = 'Nessun account trovato con questi dati.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMsg = 'Errore di connessione.');
    } finally {
      if (mounted) {
        setState(() => _isRecovering = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      content: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Recupero Credenziali',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Inserisci Email e Cellulare associati al tuo account per recuperare il tuo username.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Cellulare',
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMsg.isNotEmpty)
                Text(
                  _errorMsg,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              if (_successMsg.isNotEmpty)
                Text(
                  _successMsg,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isRecovering
                        ? null
                        : () => Navigator.pop(context),
                    child: Text(
                      'CHIUDI',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isRecovering ? null : _recover,
                    child: _isRecovering
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('RECUPERA'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
