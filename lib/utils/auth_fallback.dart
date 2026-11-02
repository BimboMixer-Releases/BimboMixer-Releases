import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';

Future<bool> promptForPasswordFallback(BuildContext context) async {
  final String? enteredPassword = await showDialog<String>(
    context: context,
    builder: (_) => const _PasswordFallbackDialog(),
  );

  if (enteredPassword == null || enteredPassword.isEmpty) {
    return false;
  }

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: enteredPassword,
      );
      await user.reauthenticateWithCredential(cred);
      return true;
    }

    final activeUsername = DatabaseHelper().currentUser;
    if (activeUsername != null && activeUsername.isNotEmpty) {
      final verified =
          await DatabaseHelper().verifyCredentials(activeUsername, enteredPassword);
      if (verified != null) return true;
    }

    if (await DatabaseHelper().verifyAdminPassword(enteredPassword)) {
      return true;
    }
  } catch (_) {}

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password errata.'),
        backgroundColor: Colors.red,
      ),
    );
  }
  return false;
}

class _PasswordFallbackDialog extends StatefulWidget {
  const _PasswordFallbackDialog();

  @override
  State<_PasswordFallbackDialog> createState() => _PasswordFallbackDialogState();
}

class _PasswordFallbackDialogState extends State<_PasswordFallbackDialog> {
  final TextEditingController pwdCtrl = TextEditingController();
  bool obscure = true;

  @override
  void dispose() {
    pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      title: const Text(
        'Autenticazione richiesta',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Impronta digitale non disponibile o fallita. Inserisci la tua password per continuare.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: pwdCtrl,
            obscureText: obscure,
            onSubmitted: (v) => Navigator.pop(context, v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: const TextStyle(color: Colors.white54),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blueAccent),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white54,
                ),
                onPressed: () => setState(() => obscure = !obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Annulla', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          onPressed: () => Navigator.pop(context, pwdCtrl.text),
          child: const Text('Conferma', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}