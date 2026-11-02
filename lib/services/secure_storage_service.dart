import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Servizio di storage sicuro cross-platform.
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  Map<String, String>? _cache;
  Future<void> _ioQueue = Future<void>.value();

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _ioQueue = _ioQueue.whenComplete(() async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<List<int>> _getKey() async {
    final dir = await getApplicationSupportDirectory();
    final seed = 'BM_SEC_${dir.path}_v2';
    return sha256.convert(utf8.encode(seed)).bytes;
  }

  Future<File> _getFile() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}.secure_store');
  }

  Future<Map<String, String>> _loadStore() async {
    if (_cache != null) return _cache!;

    try {
      final file = await _getFile();
      if (await file.exists()) {
        final encrypted = await file.readAsBytes();
        final key = await _getKey();
        final decrypted = _xorCrypt(encrypted, key);
        final json = utf8.decode(decrypted);
        final map = jsonDecode(json) as Map<String, dynamic>;
        _cache = map.map((k, v) => MapEntry(k, v.toString()));
        return _cache!;
      }
    } catch (_) {
      // Se il file è corrotto, ricomincia da zero
    }
    _cache = {};
    return _cache!;
  }

  Future<void> _saveStore(Map<String, String> store) async {
    final json = jsonEncode(store);
    final key = await _getKey();
    final encrypted = _xorCrypt(utf8.encode(json), key);
    final file = await _getFile();
    await file.writeAsBytes(encrypted, flush: true);
    _cache = store;
  }

  List<int> _xorCrypt(List<int> data, List<int> key) {
    final result = List<int>.filled(data.length, 0);
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ key[i % key.length];
    }
    return result;
  }

  /// Scrive un valore sicuro.
  Future<void> write({required String key, required String value}) {
    return _synchronized(() async {
      final store = await _loadStore();
      store[key] = value;
      await _saveStore(store);
    });
  }

  /// Legge un valore sicuro.
  Future<String?> read({required String key}) {
    return _synchronized(() async {
      final store = await _loadStore();
      return store[key];
    });
  }

  /// Elimina un valore.
  Future<void> delete({required String key}) {
    return _synchronized(() async {
      final store = await _loadStore();
      store.remove(key);
      await _saveStore(store);
    });
  }

  /// Elimina tutto lo storage sicuro.
  Future<void> deleteAll() {
    return _synchronized(() async {
      _cache = {};
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    });
  }
}
