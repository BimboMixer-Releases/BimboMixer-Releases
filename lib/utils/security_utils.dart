import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../services/biometric_service.dart';
import '../widgets/glass_container.dart';

class SecurityUtils {
  static Future<bool> requireAdminAuth(BuildContext context) async {
    final dbHelper = DatabaseHelper();
    final isCurrentAdmin = await dbHelper.isCurrentUserAdmin();

    if (isCurrentAdmin) {
      final bioService = BiometricService();
      final isBioAvailable = await bioService.isBiometricAvailable();
      if (isBioAvailable) {
        final success = await bioService.authenticate(
          reason: 'Autenticati per abilitare le modifiche',
        );
        if (success) {
          return true;
        }
      }
    }

    if (!context.mounted) return false;
    return await _showAdminPasswordDialog(context);
  }

  static Future<bool> _showAdminPasswordDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AdminPasswordDialog(),
    );
    return result ?? false;
  }
}

class _AdminPasswordDialog extends StatefulWidget {
  const _AdminPasswordDialog();

  @override
  State<_AdminPasswordDialog> createState() => _AdminPasswordDialogState();
}

class _AdminPasswordDialogState extends State<_AdminPasswordDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isObscure = true;
  bool _isVerifying = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_isVerifying) return;
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Inserisci la password');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = '';
    });

    try {
      final isValidAdmin = await DatabaseHelper().verifyAdminPassword(password);
      if (!mounted) return;
      if (isValidAdmin) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Password errata o utente non amministratore';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Errore verifica credenziali: $e';
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
              const Icon(Icons.security, color: Colors.blueAccent, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Accesso Amministratore',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Inserisci la password di un amministratore per modificare questo elemento.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _passwordController,
                obscureText: _isObscure,
                onSubmitted: (_) => _verify(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password Admin',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blueAccent),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscure ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white54,
                    ),
                    onPressed: () => setState(() => _isObscure = !_isObscure),
                  ),
                ),
              ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isVerifying ? null : () => Navigator.pop(context, false),
                    child: const Text(
                      'ANNULLA',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isVerifying ? null : _verify,
                    child: _isVerifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('SBLOCCA'),
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
