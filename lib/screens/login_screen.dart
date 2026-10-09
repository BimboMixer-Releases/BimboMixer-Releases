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
  static const int _maxLoginAttempts = 3;
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
      // 1. Authenticate with Firebase Auth
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

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
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
          _errorMessage = 'Credenziali di autenticazione non valide o account inesistente.';
        } else if (e.code == 'network-request-failed') {
          _errorMessage = 'Errore di rete. Verifica la connessione.';
        } else {
          _errorMessage = 'Errore di autenticazione (${e.code}).';
        }
      });
    } on FirebaseException catch (e) {
      setState(() {
        _isLoading = false;
        if (e.code == 'permission-denied') {
          _errorMessage = 'Permessi insufficienti per accedere al database.';
        } else {
          _errorMessage = 'Errore database (${e.code}).';
        }
      });
    } catch (e) {
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
                        'Accedi al tuo account per\ngestire la tua attivitÃ  in modo semplice.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // NOME UTENTE
                      TextField(
                        controller: _usernameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Nome utente',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: Colors.transparent,
                          prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF4A3B69)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF4A3B69)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF885CF6)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // PASSWORD
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: Colors.transparent,
                          prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                          suffixIcon: const Icon(Icons.visibility_off, color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF4A3B69)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF4A3B69)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF885CF6)),
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
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                              Text(
                                'Ricorda',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
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
                            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
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
                              color: const Color(0xFF885CF6).withValues(alpha: 0.5),
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
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                          icon: const Icon(Icons.fingerprint, color: Colors.white),
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
                      
                      const SizedBox(height: 32),
                      
                      // REGISTRATI
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            // TODO: Add register logic if exists
                          },
                          child: RichText(
                            text: const TextSpan(
                              text: 'Non hai un account? ',
                              style: TextStyle(color: Colors.white54, fontSize: 14),
                              children: [
                                TextSpan(
                                  text: 'Registrati',
                                  style: TextStyle(
                                    color: Color(0xFFEC4899),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
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
                                const Icon(Icons.lock_outline, color: Color(0xFFEC4899)),
                                const SizedBox(height: 8),
                                const Text('Sicuro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('I tuoi dati protetti', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(Icons.cloud_queue, color: Color(0xFFEC4899)),
                                const SizedBox(height: 8),
                                const Text('Sincronizzato', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('su tutti i dispositivi', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(Icons.bar_chart, color: Color(0xFFEC4899)),
                                const SizedBox(height: 8),
                                const Text('Smart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('Gestisci in mobilitÃ ', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
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
                  Text('Inserisci Email e Cellulare associati al tuo account per recuperare il tuo username.', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                  SizedBox(height: 16),
                  TextField(
                    controller: emailCtrl,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: phoneCtrl,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: 'Cellulare', labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                  ),
                  SizedBox(height: 16),
                  if (errorMsg.isNotEmpty) Text(errorMsg, style: TextStyle(color: Colors.redAccent)),
                  if (successMsg.isNotEmpty) Text(successMsg, style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('CHIUDI', style: TextStyle(color: Colors.white.withValues(alpha: 0.7)))),
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





