import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../widgets/glass_container.dart';
import '../services/biometric_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  static String _normalizeRole(dynamic rawRole) {
    final str = rawRole?.toString().trim().toLowerCase() ?? '';
    return str == 'admin' ? 'Admin' : 'User';
  }

  bool _isCurrentLoggedUser(Map<String, dynamic> user) {
    final current = _dbHelper.currentUser?.trim().toLowerCase();
    if (current == null || current.isEmpty) return false;
    final uname = user['username']?.toString().trim().toLowerCase() ?? '';
    return uname == current;
  }

  int get _adminCount =>
      _users.where((u) => _normalizeRole(u['role']) == 'Admin').length;

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final users = await _dbHelper.getUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore caricamento utenti: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showUserDialog({Map<String, dynamic>? user}) async {
    final isOnlyAdmin =
        user != null &&
        _normalizeRole(user['role']) == 'Admin' &&
        _adminCount <= 1;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _UserFormDialog(
        user: user,
        isOnlyAdmin: isOnlyAdmin,
        dbHelper: _dbHelper,
      ),
    );

    if (saved == true && mounted) {
      _loadUsers();
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final id = user['id']?.toString() ?? '';
    if (id.isEmpty) return;

    if (_isCurrentLoggedUser(user)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Non puoi eliminare l\'utente attualmente connesso.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_normalizeRole(user['role']) == 'Admin' && _adminCount <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossibile eliminare l\'ultimo amministratore rimasto.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Conferma Eliminazione',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sei sicuro di voler eliminare l\'utente "${user['username']}"?',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(
                      'ANNULLA',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('ELIMINA'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        await _dbHelper.deleteUser(id);
        final uname = user['username']?.toString();
        if (uname != null && uname.isNotEmpty) {
          await BiometricService().clearUserCredentials(uname);
        }
        if (!mounted) return;
        _loadUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Utente eliminato.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore eliminazione: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _setupBiometrics(Map<String, dynamic> user) async {
    final bioService = BiometricService();
    final available = await bioService.isBiometricAvailable();
    if (!mounted) return;

    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometria non disponibile sul dispositivo.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final username = user['username']?.toString().trim() ?? '';
    if (username.isEmpty) return;

    final String? verifiedPassword = await showDialog<String>(
      context: context,
      builder: (_) => _BiometricSetupDialog(
        username: username,
        dbHelper: _dbHelper,
      ),
    );

    if (!mounted || verifiedPassword == null || verifiedPassword.isEmpty) {
      return;
    }

    final authenticated = await bioService.authenticate(
      reason: 'Autorizza il salvataggio della password',
    );
    if (!mounted) return;

    if (authenticated) {
      await bioService.saveUserCredentials(username, verifiedPassword);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometria impostata con successo.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Autenticazione biometrica fallita.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Gestione Utenti',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final normalizedRole = _normalizeRole(user['role']);
                final isSelf = _isCurrentLoggedUser(user);
                final isLastAdmin =
                    normalizedRole == 'Admin' && _adminCount <= 1;
                final canDelete =
                    user['username']?.toString().toLowerCase() != 'admin' &&
                    !isSelf &&
                    !isLastAdmin;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: GlassContainer(
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        title: Text(
                          user['username']?.toString() ?? 'Utente',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Ruolo: $normalizedRole${isSelf ? ' (Tu)' : ''}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.fingerprint,
                                color: Colors.greenAccent,
                              ),
                              tooltip: 'Imposta Biometria / Viso',
                              onPressed: () => _setupBiometrics(user),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blueAccent,
                              ),
                              onPressed: () => _showUserDialog(user: user),
                            ),
                            if (canDelete)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _deleteUser(user),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  final Map<String, dynamic>? user;
  final bool isOnlyAdmin;
  final DatabaseHelper dbHelper;

  const _UserFormDialog({
    required this.user,
    required this.isOnlyAdmin,
    required this.dbHelper,
  });

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late String _role;
  bool _isSaving = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.user?['username']?.toString() ?? '',
    );
    _passwordController = TextEditingController();
    _emailController = TextEditingController(
      text: widget.user?['email']?.toString() ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.user?['phone']?.toString() ?? '',
    );
    _role = _UsersScreenState._normalizeRole(widget.user?['role']);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<String?> _syncNewUserWithFirebaseAuth({
    required String username,
    required String email,
    required String password,
  }) async {
    final sanitizedUser =
        username.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final primaryAuthEmail = sanitizedUser.isNotEmpty
        ? '$sanitizedUser@bimbomixer.local'
        : email;
    if (primaryAuthEmail.isEmpty) return null;

    FirebaseApp? secondaryApp;
    String? infoMessage;
    try {
      try {
        secondaryApp = Firebase.app('SecondaryUserCreationApp');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'SecondaryUserCreationApp',
          options: Firebase.app().options,
        );
      }
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      try {
        await secondaryAuth.createUserWithEmailAndPassword(
          email: primaryAuthEmail,
          password: password,
        );
        await secondaryAuth.signOut();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          infoMessage =
              'Account già registrato su Firebase Auth; profilo sincronizzato nel database.';
        } else if (e.code == 'weak-password') {
          throw Exception(
            'La password deve contenere almeno 6 caratteri.',
          );
        } else {
          throw Exception('Errore Firebase Auth (${e.code}).');
        }
      }

      if (email.isNotEmpty &&
          email.contains('@') &&
          email.toLowerCase() != primaryAuthEmail.toLowerCase()) {
        try {
          await secondaryAuth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          await secondaryAuth.signOut();
        } on FirebaseAuthException catch (e) {
          if (e.code != 'email-already-in-use') {
            debugPrint('Info sincronizzazione email secondaria Auth: ${e.code}');
          }
        }
      }
    } finally {
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (_) {}
      }
    }
    return infoMessage;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (username.isEmpty) {
      setState(() => _errorMessage = 'Inserisci uno username valido.');
      return;
    }
    if (widget.user == null && password.isEmpty) {
      setState(() => _errorMessage = 'Inserisci una password per il nuovo utente.');
      return;
    }
    if (password.isNotEmpty && password.length < 6) {
      setState(
        () => _errorMessage = 'La password deve avere almeno 6 caratteri.',
      );
      return;
    }
    if (widget.isOnlyAdmin && _role != 'Admin') {
      setState(
        () => _errorMessage =
            'Non puoi rimuovere il ruolo Admin all\'unico amministratore rimasto.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });

    try {
      String? authNotice;
      if (widget.user == null) {
        final existingUsers = await widget.dbHelper.getUsers();
        final duplicate = existingUsers.any(
          (u) =>
              (u['username']?.toString().trim().toLowerCase() ?? '') ==
              username.toLowerCase(),
        );
        if (duplicate) {
          if (!mounted) return;
          setState(() {
            _isSaving = false;
            _errorMessage = 'Esiste già un utente con questo username.';
          });
          return;
        }

        authNotice = await _syncNewUserWithFirebaseAuth(
          username: username,
          email: email,
          password: password,
        );

        await widget.dbHelper.insertUser({
          'username': username,
          'password_hash': password,
          'role': _role,
          'email': email.isNotEmpty ? email : null,
          'phone': phone.isNotEmpty ? phone : null,
        });
      } else {
        final Map<String, dynamic> updatedUser = {
          'id': widget.user!['id'],
          'username': username,
          'role': _role,
          'email': email.isNotEmpty ? email : null,
          'phone': phone.isNotEmpty ? phone : null,
          'password_hash': password.isNotEmpty
              ? password
              : widget.user!['password_hash'],
        };
        await widget.dbHelper.updateUser(updatedUser);
      }

      if (!mounted) return;
      if (authNotice != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authNotice)),
        );
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.user == null;
    return AlertDialog(
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      content: GlassContainer(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isNew ? 'Nuovo Utente' : 'Modifica Utente',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: isNew
                      ? 'Password (min. 6 caratteri)'
                      : 'Password (lascia vuoto per non modificare)',
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email (per recupero e sincronizzazione)',
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Cellulare (per recupero password)',
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _role,
                dropdownColor: Colors.blueGrey[900],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Ruolo',
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                items: const ['Admin', 'User'].map((String r) {
                  return DropdownMenuItem<String>(value: r, child: Text(r));
                }).toList(),
                onChanged: widget.isOnlyAdmin
                    ? null
                    : (String? newValue) {
                        if (newValue != null) {
                          setState(() => _role = newValue);
                        }
                      },
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.pop(context, false),
                    child: Text(
                      'ANNULLA',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('SALVA'),
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

class _BiometricSetupDialog extends StatefulWidget {
  final String username;
  final DatabaseHelper dbHelper;

  const _BiometricSetupDialog({
    required this.username,
    required this.dbHelper,
  });

  @override
  State<_BiometricSetupDialog> createState() => _BiometricSetupDialogState();
}

class _BiometricSetupDialogState extends State<_BiometricSetupDialog> {
  final TextEditingController _pwdController = TextEditingController();
  bool _obscure = true;
  bool _isVerifying = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _pwdController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndContinue() async {
    if (_isVerifying) return;
    final pwd = _pwdController.text;
    if (pwd.isEmpty) {
      setState(() => _errorMessage = 'Inserisci la password.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = '';
    });

    try {
      final verified = await widget.dbHelper.verifyCredentials(
        widget.username,
        pwd,
      );
      if (!mounted) return;

      if (verified == null) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Password non corretta per "${widget.username}".';
        });
        return;
      }

      Navigator.pop(context, pwd);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Errore di verifica: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      content: GlassContainer(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Imposta Biometria per ${widget.username}',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Inserisci la password dell\'utente per verificarla e salvarla nel portachiavi sicuro del dispositivo.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pwdController,
                obscureText: _obscure,
                onSubmitted: (_) => _verifyAndContinue(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isVerifying
                        ? null
                        : () => Navigator.pop(context),
                    child: Text(
                      'ANNULLA',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyAndContinue,
                    child: _isVerifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('VERIFICA E SALVA'),
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

