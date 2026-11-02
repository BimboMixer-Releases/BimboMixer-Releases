import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Utility per hashing sicuro delle password.
/// Usa SHA-256 con salt casuale per impedire attacchi rainbow table.
class PasswordHasher {
  static const int _saltLength = 32;
  static final RegExp _hashedPattern = RegExp(r'^[^$]+\$[a-fA-F0-9]{64}$');

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
    if (isHashed(storedHash)) {
      final sepIdx = storedHash.lastIndexOf('\$');
      final salt = storedHash.substring(0, sepIdx);
      final hash = storedHash.substring(sepIdx + 1);
      return _hash(password, salt) == hash.toLowerCase();
    } else {
      return password == storedHash;
    }
  }

  /// Controlla se una password è già nel formato hash (`salt$64hex`).
  static bool isHashed(String passwordHash) {
    return _hashedPattern.hasMatch(passwordHash);
  }
}
