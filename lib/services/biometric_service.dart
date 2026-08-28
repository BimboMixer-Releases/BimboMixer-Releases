import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'secure_storage_service.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication auth = LocalAuthentication();
  final SecureStorageService _secureStorage = SecureStorageService();

  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Autenticati per accedere'}) async {
    try {
      return await auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
        biometricOnly: false,
      );
    } on PlatformException {
      return false;
    }
  }

  Future<void> saveUserCredentials(String username, String password) async {
    await _secureStorage.write(key: 'biometric_user_$username', value: password);
    await _secureStorage.write(key: 'last_biometric_user', value: username);
  }

  Future<String?> getSavedPassword(String username) async {
    return await _secureStorage.read(key: 'biometric_user_$username');
  }
  
  Future<String?> getLastBiometricUser() async {
    return await _secureStorage.read(key: 'last_biometric_user');
  }

  Future<void> clearUserCredentials(String username) async {
    await _secureStorage.delete(key: 'biometric_user_$username');
  }
}
