import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<bool> promptForPasswordFallback(BuildContext context) async {
  final TextEditingController _pwdCtrl = TextEditingController();
  bool obscure = true;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('Autenticazione richiesta', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Impronta digitale non disponibile o fallita. Inserisci la tua password per continuare.', 
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: _pwdCtrl,
              obscureText: obscure,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: const TextStyle(color: Colors.white54),
                enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
                  onPressed: () => setState(() => obscure = !obscure),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Conferma', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );

  if (result == true) {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        final cred = EmailAuthProvider.credential(email: user.email!, password: _pwdCtrl.text);
        await user.reauthenticateWithCredential(cred);
        return true;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password errata.'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }
  return false;
}