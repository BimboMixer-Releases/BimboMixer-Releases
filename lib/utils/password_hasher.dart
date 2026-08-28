import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Utility per hashing sicuro delle password.
/// Usa SHA-256 con salt casuale per impedire attacchi rainbow table.
class PasswordHasher {
  static const int _saltLength = 32;

  /// Genera un salt casuale di [_saltLength] byte, codificato in base64.
  static String _generateSalt() {
    final random = Random.secure();
    final salt = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    return base64Encode(salt);
  }

  /// Calcola l'hash SHA-256 di [password] con il [salt] dato.
  static String _hash(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Crea un hash completo (salt + hash) da salvare nel database.
  /// Formato: `salt$hash`
  static String hashPassword(String password) {
    final salt = _generateSalt();
    final hash = _hash(password, salt);
    return '$salt\$$hash';
  }

  /// Verifica se [password] corrisponde a [storedHash].
  /// Supporta sia il nuovo formato (salt$hash) che le password in chiaro legacy.
  static bool verifyPassword(String password, String storedHash) {
    if (storedHash.contains('\$')) {
      // Nuovo formato: salt$hash
      final parts = storedHash.split('\$');
      if (parts.length != 2) return false;
      final salt = parts[0];
      final hash = parts[1];
      return _hash(password, salt) == hash;
    } else {
      // Password legacy in chiaro — confronto diretto per migrazione
      return password == storedHash;
    }
  }

  /// Controlla se una password è già nel formato hash (contiene il separatore $).
  static bool isHashed(String passwordHash) {
    return passwordHash.contains('\$') && passwordHash.length > 70;
  }
}
