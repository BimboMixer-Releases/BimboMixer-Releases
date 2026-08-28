import 'package:flutter/material.dart';
import '../services/biometric_service.dart';
import '../database/database_helper.dart';
import '../widgets/glass_container.dart';

class SecurityUtils {
  static Future<bool> requireAdminAuth(BuildContext context) async {
    final bioService = BiometricService();
    final isBioAvailable = await bioService.isBiometricAvailable();

    if (isBioAvailable) {
      final success = await bioService.authenticate(reason: 'Autenticati per abilitare le modifiche');
      if (success) {
        return true;
      }
    }

    // Fallback: Richiedi password Amministratore
    return await _showAdminPasswordDialog(context);
  }

  static Future<bool> _showAdminPasswordDialog(BuildContext context) async {
    final TextEditingController passwordController = TextEditingController();
    bool isObscure = true;
    String errorMessage = '';

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              content: GlassContainer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.security, color: Colors.blueAccent, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Accesso Amministratore',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Inserisci la password di un amministratore per modificare questo elemento.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: passwordController,
                      obscureText: isObscure,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password Admin',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                        suffixIcon: IconButton(
                          icon: Icon(isObscure ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
                          onPressed: () {
                            setState(() {
                              isObscure = !isObscure;
                            });
                          },
                        ),
                      ),
                    ),
                    if (errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          errorMessage,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('ANNULLA', style: TextStyle(color: Colors.white70)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final password = passwordController.text;
                            if (password.isEmpty) {
                              setState(() => errorMessage = 'Inserisci la password');
                              return;
                            }

                            final dbHelper = DatabaseHelper();
                            final isValidAdmin = await dbHelper.verifyAdminPassword(password);

                            if (isValidAdmin) {
                              Navigator.pop(dialogContext, true);
                            } else {
                              setState(() => errorMessage = 'Password errata o utente non amministratore');
                            }
                          },
                          child: const Text('SBLOCCA'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ) ?? false;
  }
}

