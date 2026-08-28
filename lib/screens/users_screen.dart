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

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await _dbHelper.getUsers();
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  void _showUserDialog({Map<String, dynamic>? user}) {
    final TextEditingController usernameController = TextEditingController(text: user?['username']);
    final TextEditingController passwordController = TextEditingController(); // For security, don't show old hash
    final TextEditingController emailController = TextEditingController(text: user?['email']);
    final TextEditingController phoneController = TextEditingController(text: user?['phone']);
    String role = user?['role'] ?? 'User';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              content: GlassContainer(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user == null ? 'Nuovo Utente' : 'Modifica Utente',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: usernameController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Username',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.7))),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: user == null ? 'Password' : 'Password (lascia vuoto per non modificare)',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.7))),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Email (per recupero password)',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.7))),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Cellulare (per recupero password)',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.7))),
                        ),
                      ),
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: role,
                        dropdownColor: Colors.blueGrey[900],
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Ruolo',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.7))),
                        ),
                        items: ['Admin', 'User'].map((String r) {
                          return DropdownMenuItem<String>(
                            value: r,
                            child: Text(r),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setDialogState(() {
                            role = newValue!;
                          });
                        },
                      ),
                      SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text('ANNULLA', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final username = usernameController.text.trim();
                              final password = passwordController.text;
                              final email = emailController.text.trim();
                              final phone = phoneController.text.trim();

                              if (username.isEmpty) return;
                              if (user == null && password.isEmpty) return; // Password obbligatoria solo in creazione

                              if (user == null) {
                                await _dbHelper.insertUser({
                                  'username': username,
                                  'password_hash': password, // Ideally hash this
                                  'role': role,
                                  'email': email.isNotEmpty ? email : null,
                                  'phone': phone.isNotEmpty ? phone : null,
                                });
                              } else {
                                final Map<String, dynamic> updatedUser = {
                                  'id': user['id'],
                                  'username': username,
                                  'role': role,
                                  'email': email.isNotEmpty ? email : null,
                                  'phone': phone.isNotEmpty ? phone : null,
                                  'password_hash': password.isNotEmpty ? password : user['password_hash'],
                                };
                                await _dbHelper.updateUser(updatedUser);
                              }

                              if (dialogContext.mounted) Navigator.pop(dialogContext);
                              _loadUsers();
                            },
                            child: Text('SALVA'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  void _deleteUser(String id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Conferma Eliminazione', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Text('Sei sicuro di voler eliminare questo utente?', style: TextStyle(color: Colors.white.withOpacity(0.7))),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('ANNULLA', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('ELIMINA'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        await _dbHelper.deleteUser(id);
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Utente eliminato.'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore eliminazione: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  void _setupBiometrics(Map<String, dynamic> user) async {
    final bioService = BiometricService();
    if (!await bioService.isBiometricAvailable()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometria non disponibile sul dispositivo.'), backgroundColor: Colors.orange));
      return;
    }
    
    final TextEditingController pwdController = TextEditingController();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Imposta Biometria per ${user['username']}', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Text('Inserisci la password dell\'utente per poterla salvare nel portachiavi sicuro del dispositivo.', style: TextStyle(color: Colors.white.withOpacity(0.7))),
              SizedBox(height: 16),
              TextField(
                controller: pwdController,
                obscureText: true,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.7))),
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('ANNULLA', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('SALVA'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );

    if (confirm == true && pwdController.text.isNotEmpty) {
      if (await bioService.authenticate(reason: 'Autorizza il salvataggio della password')) {
        await bioService.saveUserCredentials(user['username'], pwdController.text);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometria impostata con successo.'), backgroundColor: Colors.green));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Autenticazione biometrica fallita.'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Background handled by main layout
      appBar: AppBar(
        title: Text('Gestione Utenti', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: GlassContainer(
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                      title: Text(user['username']?.toString() ?? 'Utente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text('Ruolo: ${user['role']?.toString() ?? 'User'}', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.fingerprint, color: Colors.greenAccent),
                            tooltip: 'Imposta Biometria / Viso',
                            onPressed: () => _setupBiometrics(user),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.blueAccent),
                            onPressed: () => _showUserDialog(user: user),
                          ),
                          // Prevent deleting the main admin to avoid lockouts
                          if (user['username'] != 'admin')
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _deleteUser(user['id']),
                            ),
                        ],
                      ),
                    )),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(),
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.add),
      ),
    );
  }
}


