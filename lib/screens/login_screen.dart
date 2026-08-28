import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:contabile_app/database/database_helper.dart';

import 'package:contabile_app/screens/main_screen.dart';
import 'package:contabile_app/widgets/gradient_scaffold.dart';
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
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  String? _lastBiometricUser;
  bool _isBiometricSupported = false;
  bool _rememberMe = false;
  final SecureStorageService _secureStorage = SecureStorageService();

  // Rate limiting
  static const int _maxLoginAttempts = 5;
  static const int _lockoutMinutes = 5;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
    _checkBiometrics();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final savedUser = await _secureStorage.read(key: 'saved_username');
    if (savedUser != null) {
      setState(() {
        _usernameController.text = savedUser;
        _rememberMe = true;
      });
    }
  }

  Future<void> _checkBiometrics() async {
    final bioService = BiometricService();
    final supported = await bioService.isBiometricAvailable();
    setState(() {
      _isBiometricSupported = supported;
    });
    if (supported) {
      final user = await bioService.getLastBiometricUser();
      if (user != null) {
        setState(() {
          _lastBiometricUser = user;
          _usernameController.text = user;
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
    
    if (await bioService.authenticate(reason: 'Autenticati per effettuare l\'accesso')) {
      final password = await bioService.getSavedPassword(user);
      if (password != null) {
        _passwordController.text = password;
        _login();
      } else {
        setState(() {
          _errorMessage = 'Biometria non configurata per "$user". Abilitala dalla Gestione Utenti.';
        });
      }
    }
  }

  Future<void> _checkForUpdates() async {
    final updateService = UpdateService();
    final updateData = await updateService.checkForUpdate();
    if (updateData != null && mounted) {
      try {
        final player = AudioPlayer();
        await player.play(AssetSource('audio/notification.mp3'));
      } catch (e) {
        // Errore riproduzione suono non critico
      }
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => UpdateDialog(updateData: updateData, updateService: updateService),
      );
    }
  }

  Future<void> _login() async {
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

    final dbHelper = DatabaseHelper();

    // Rate limiting: controlla tentativi recenti
    try {
      final recentAttempts = await dbHelper.getRecentFailedAttempts(username, minutes: _lockoutMinutes);
      if (recentAttempts >= _maxLoginAttempts) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Troppi tentativi falliti. Riprova tra $_lockoutMinutes minuti.';
        });
        return;
      }
    } catch (e) {
      // Se il rate limiting fallisce, non bloccare il login
    }

    final String sanitizedUser = username.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final String authEmail = '$sanitizedUser@bimbomixer.local';

    try {
      // 1. Authenticate with Firebase Auth (only sign in, no auto-create)
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: authEmail, password: password);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          // L'utente potrebbe non esistere in Firebase Auth ma solo in Firestore
          // Non creiamo automaticamente account Firebase Auth per sicurezza
        }
      } catch (e) {
        // Auth Firebase non bloccante - i dati li verifichiamo su Firestore
      }

      // 2. Verifica credenziali in Firestore con password hashata
      var usersList = await dbHelper.getUsers();
      // Usa verifyCredentials per confronto sicuro con hash
      final verifiedUser = await dbHelper.verifyCredentials(username, password);

      setState(() => _isLoading = false);

      if (verifiedUser != null) {
        final role = verifiedUser['role'] ?? 'User';
        
        // Salva solo username (mai la password) per "Ricordami"
        if (_rememberMe) {
          await _secureStorage.write(key: 'saved_username', value: username);
        } else {
          await _secureStorage.delete(key: 'saved_username');
        }

        // Pulisci vecchi tentativi di login
        dbHelper.cleanOldLoginAttempts();

        if (mounted) {
          try {
            String deviceType = 'Sconosciuto';
            if (kIsWeb) {
              deviceType = 'Computer / Web';
            } else {
              deviceType = (Platform.isAndroid || Platform.isIOS) ? 'Cellulare' : 'Computer';
            }
            await dbHelper.logAccess(username, role, deviceType, eventType: 'login_success');
          } catch (e) {
            // Non bloccare il login se il logging fallisce
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Benvenuto $username!")),
          );
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainScreen(role: role, username: username)));
        }
      } else {
        await FirebaseAuth.instance.signOut();

        // Registra tentativo fallito
        try {
          final attempts = await dbHelper.recordFailedLogin(username);
          String deviceType = 'Sconosciuto';
          if (!kIsWeb) {
            deviceType = (Platform.isAndroid || Platform.isIOS) ? 'Cellulare' : 'Computer';
          }
          await dbHelper.logAccess(username, 'unknown', deviceType, eventType: 'login_failed');
          
          final remaining = _maxLoginAttempts - attempts;
          if (remaining > 0) {
            setState(() {
              _errorMessage = 'Credenziali non valide. Tentativi rimasti: $remaining';
            });
          } else {
            setState(() {
              _errorMessage = 'Account temporaneamente bloccato. Riprova tra $_lockoutMinutes minuti.';
            });
          }
        } catch (e) {
          setState(() {
            _errorMessage = 'Credenziali non valide.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Errore di connessione. Riprova.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: Text('Accesso Contabilità', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: GlassContainer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.account_balance,
                    size: 80,
                    color: Colors.white,
                  ),
                  SizedBox(height: 32),
                  TextField(
                    controller: _usernameController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.54))),
                      prefixIcon: Icon(Icons.person, color: Colors.white.withOpacity(0.7)),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.54))),
                      prefixIcon: Icon(Icons.lock, color: Colors.white.withOpacity(0.7)),
                    ),
                  ),
                  SizedBox(height: 8),
                  Theme(
                    data: Theme.of(context).copyWith(unselectedWidgetColor: Colors.white.withOpacity(0.7)),
                    child: CheckboxListTile(
                      title: Text('Ricordami', style: TextStyle(color: Colors.white)),
                      value: _rememberMe,
                      onChanged: (val) {
                        setState(() {
                          _rememberMe = val ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.blueAccent,
                    ),
                  ),
                  SizedBox(height: 8),

                  TextButton(
                    onPressed: _showRecoveryWizard,
                    child: Text('Recupera dati di accesso', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(height: 24),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Row(
                    children: [
                      if (_isBiometricSupported) ...[
                        Expanded(
                          flex: 1,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _loginWithBiometrics,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.greenAccent.withValues(alpha: 0.8),
                              foregroundColor: Colors.black87,
                            ),
                            child: Icon(Icons.fingerprint),
                          ),
                        ),
                        SizedBox(width: 8),
                      ],
                      Expanded(
                        flex: 3,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blueAccent.withValues(alpha: 0.8),
                            foregroundColor: Colors.white,
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  'ACCEDI',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
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
    );
  }

  void _showRecoveryWizard() {
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String errorMsg = '';
    String successMsg = '';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: GlassContainer(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Recupero Credenziali', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Text('Inserisci Email e Cellulare associati al tuo account per recuperare il tuo username.', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                  SizedBox(height: 16),
                  TextField(
                    controller: emailCtrl,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: Colors.white.withOpacity(0.7))),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: phoneCtrl,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: 'Cellulare', labelStyle: TextStyle(color: Colors.white.withOpacity(0.7))),
                  ),
                  SizedBox(height: 16),
                  if (errorMsg.isNotEmpty) Text(errorMsg, style: TextStyle(color: Colors.redAccent)),
                  if (successMsg.isNotEmpty) Text(successMsg, style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('CHIUDI', style: TextStyle(color: Colors.white.withOpacity(0.7)))),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          setDialogState(() { errorMsg = ''; successMsg = ''; });
                          final email = emailCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();
                          if (email.isEmpty || phone.isEmpty) {
                            setDialogState(() => errorMsg = 'Compila entrambi i campi.');
                            return;
                          }
                          try {
                            final dbHelper = DatabaseHelper();
                            final users = await dbHelper.getUsers();
                            
                            // Cerca utente per email e telefono
                            final matchingUsers = users.where((u) =>
                              u['email'] == email && u['phone'] == phone
                            ).toList();
                            
                            if (matchingUsers.isNotEmpty) {
                              final data = matchingUsers.first;
                              // Mostra SOLO lo username, MAI la password
                              setDialogState(() {
                                successMsg = 'Account trovato!\nUsername: ${data["username"]}\n\nPer resettare la password, contatta un amministratore.';
                              });
                            } else {
                              setDialogState(() => errorMsg = 'Nessun account trovato con questi dati.');
                            }
                          } catch (e) {
                            setDialogState(() => errorMsg = 'Errore di connessione.');
                          }
                        },
                        child: Text('RECUPERA'),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}



