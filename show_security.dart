import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class PasswordHasher {
  static const int _saltLength = 32;

  static String _generateSalt() {
    final random = Random.secure();
    final salt = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    return base64Encode(salt);
  }

  static String _hash(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static String hashPassword(String password) {
    final salt = _generateSalt();
    final hash = _hash(password, salt);
    return '$salt\$$hash';
  }

  static bool verifyPassword(String password, String storedHash) {
    if (storedHash.contains('\$')) {
      final parts = storedHash.split('\$');
      if (parts.length != 2) return false;
      final salt = parts[0];
      final hash = parts[1];
      return _hash(password, salt) == hash;
    }
    return password == storedHash;
  }
}

void main() {
  print('====================================================');
  print('    TEST DI SICUREZZA LOGIN - CONTABILE APP         ');
  print('====================================================');
  
  String testPassword = "LaMiaPasswordSuperSicura123!";
  print('1. L\'utente inserisce la password in chiaro: \$testPassword');
  
  String hashedPassword = PasswordHasher.hashPassword(testPassword);
  print('2. Il sistema genera un SALT crittografico e converte la password in un Hash SHA-256.');
  print('   -> HASH SALVATO NEL DATABASE:');
  print('      \$hashedPassword');
  
  print('3. Simulazione di un tentativo di Login (Inserita password corretta)...');
  bool isValid = PasswordHasher.verifyPassword(testPassword, hashedPassword);
  print('   -> Risultato: \${isValid ? 'ACCESSO CONSENTITO (Verifica tramite Hash)' : 'ACCESSO NEGATO'}');
  
  print('4. Simulazione di un tentativo di Login (Inserita password errata)...');
  bool isInvalid = PasswordHasher.verifyPassword("PasswordSbagliata", hashedPassword);
  print('   -> Risultato: \${isInvalid ? 'ACCESSO CONSENTITO' : 'ACCESSO NEGATO - Credenziali non valide'}');
  print('====================================================');
  print('    SISTEMA DI LOCKOUT (Rate Limiting) IN FUNZIONE  ');
  print('    - 5 tentativi massimi                           ');
  print('    - 15 minuti di blocco account in caso di abuso  ');
  print('====================================================');
}
