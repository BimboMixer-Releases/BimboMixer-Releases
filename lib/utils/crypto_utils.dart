import 'package:encrypt/encrypt.dart' as encrypt;

class CryptoUtils {
  // Chiave statica a 32 byte per AES-256
  // (In un'app di produzione con backend andrebbe recuperata via API, 
  // ma per app serverless è il compromesso migliore per cifratura data-at-rest)
  static final _key = encrypt.Key.fromUtf8('B1mb0M1x3rS3cur3C0nt4b1l3K3y2026!');
  static final _iv = encrypt.IV.fromLength(16);
  static final _encrypter = encrypt.Encrypter(encrypt.AES(_key));

  /// Cifra una stringa (es. P.IVA, CF). Ritorna il Base64 cifrato.
  static String? encryptData(String? data) {
    if (data == null || data.isEmpty) return data;
    try {
      final encrypted = _encrypter.encrypt(data, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      return data;
    }
  }

  /// Decifra una stringa precedentemente cifrata.
  static String? decryptData(String? encryptedBase64) {
    if (encryptedBase64 == null || encryptedBase64.isEmpty) return encryptedBase64;
    try {
      // Se non è base64 valido o non è cifrato, restituisce eccezione
      final encrypted = encrypt.Encrypted.fromBase64(encryptedBase64);
      return _encrypter.decrypt(encrypted, iv: _iv);
    } catch (e) {
      // Se fallisce, significa che era un dato vecchio salvato in chiaro o corrotto
      return encryptedBase64;
    }
  }
}
