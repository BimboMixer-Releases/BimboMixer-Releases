import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  final Dio _dio = Dio();

  // INSERISCI QUI IL TUO NOME UTENTE GITHUB
  // Es: 'MarioRossi/BimboMixer-Releases'
  static const String githubRepo = 'BimboMixer-Releases/BimboMixer-Releases';

  int _versionToInt(String version) {
    String cleaned = version.replaceAll(RegExp(r'[^0-9.]'), '');
    List<String> parts = cleaned.split('.');
    int val = 0;
    if (parts.isNotEmpty) val += (int.tryParse(parts[0]) ?? 0) * 10000;
    if (parts.length > 1) val += (int.tryParse(parts[1]) ?? 0) * 100;
    if (parts.length > 2) val += (int.tryParse(parts[2]) ?? 0);
    return val;
  }

  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      if (githubRepo.contains('TUO_USERNAME')) {
        print("Devi impostare il tuo username GitHub in update_service.dart");
        return null;
      }

      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      int currentVersionVal = _versionToInt(packageInfo.version);

      final response = await _dio.get(
        'https://api.github.com/repos/$githubRepo/releases/latest',
        options: Options(
          headers: {
            'Accept': 'application/vnd.github.v3+json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        String tagName = data['tag_name'] ?? '';
        int latestVersionVal = _versionToInt(tagName);

        if (latestVersionVal > currentVersionVal) {
          // Trova gli URL degli asset
          String androidUrl = '';
          String windowsUrl = '';
          String releaseNotes = data['body'] ?? 'Nuovo aggiornamento disponibile.';

          List assets = data['assets'] ?? [];
          for (var asset in assets) {
            String name = asset['name'].toString().toLowerCase();
            String downloadUrl = asset['browser_download_url'];
            if (name.endsWith('.apk')) {
              androidUrl = downloadUrl;
            } else if (name.endsWith('.exe') || name.endsWith('.msix') || name.endsWith('.zip')) {
              windowsUrl = downloadUrl;
            }
          }

          if (androidUrl.isNotEmpty || windowsUrl.isNotEmpty) {
            return {
              'version': tagName,
              'releaseNotes': releaseNotes,
              'androidUrl': androidUrl,
              'windowsUrl': windowsUrl,
            };
          }
        }
      }
    } catch (e) {
      print("Errore controllo aggiornamenti GitHub: $e");
    }
    return null;
  }

  Future<void> downloadAndInstallUpdate(
      String url, Function(double) onProgress) async {
    if (url.isEmpty) {
      throw Exception('URL aggiornamento non disponibile per questa piattaforma.');
    }

    try {
      if (Platform.isAndroid) {
        await _downloadAndInstallAndroid(url, onProgress);
      } else if (Platform.isWindows) {
        await _downloadAndInstallWindows(url, onProgress);
      } else {
        // Fallback: apri nel browser
        final uri = Uri.parse(url);
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          throw Exception('Impossibile aprire il link di download nel browser.');
        }
      }
    } catch (e) {
      print("Errore durante il download o installazione: $e");
      rethrow;
    }
  }

  // ─── Android: scarica APK e avvia installazione ────────────────────────────

  Future<void> _downloadAndInstallAndroid(
      String url, Function(double) onProgress) async {
    // Save in app-specific external directory to avoid Android scoped storage issues
    Directory? downloadsDir = await getExternalStorageDirectory();
    downloadsDir ??= await getApplicationDocumentsDirectory();

    final savePath = '${downloadsDir.path}/BimboMixer_update.apk';

    // Rimuovi versione precedente se esiste
    final file = File(savePath);
    if (file.existsSync()) file.deleteSync();

    // Download con Dio
    await _dio.download(
      url,
      savePath,
      options: Options(
        receiveTimeout: const Duration(minutes: 10),
        sendTimeout: const Duration(minutes: 2),
        headers: {'Accept': '*/*'},
      ),
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress(received / total);
        }
      },
    );

    // Verifica che il file esista e abbia dimensione ragionevole
    final downloaded = File(savePath);
    if (!downloaded.existsSync() || downloaded.lengthSync() < 1024) {
      throw Exception('File scaricato non valido o troppo piccolo.');
    }

    // Apri l'APK per installazione
    final result = await OpenFilex.open(savePath, type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done) {
      // Fallback: prova con url_launcher
      final fileUri = Uri.file(savePath);
      try {
        await launchUrl(fileUri);
      } catch (e) {
        throw Exception(
            'Impossibile avviare l\'installazione: ${result.message}\n'
            'Vai in Download e apri BimboMixer_update.apk manualmente.');
      }
    }
  }

  // ─── Windows: scarica ZIP/EXE e aggiorna ──────────────────────────────────

  Future<void> _downloadAndInstallWindows(
      String url, Function(double) onProgress) async {
    Directory? downloadsDir = await getDownloadsDirectory();
    downloadsDir ??= await getApplicationDocumentsDirectory();
    
    String ext = url.split('?').first.split('.').last.toLowerCase();
    if (ext != 'zip' && ext != 'exe' && ext != 'msix') ext = 'zip';
    
    final savePath = '${downloadsDir.path}\\BimboMixer_update.$ext';

    final file = File(savePath);
    if (file.existsSync()) file.deleteSync();

    await _dio.download(
      url,
      savePath,
      options: Options(
        receiveTimeout: const Duration(minutes: 10),
        sendTimeout: const Duration(minutes: 2),
      ),
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress(received / total);
        }
      },
    );

    final downloaded = File(savePath);
    if (!downloaded.existsSync() || downloaded.lengthSync() < 1024) {
      throw Exception('File scaricato non valido o troppo piccolo.');
    }

    final result = await OpenFilex.open(savePath);
    if (result.type != ResultType.done) {
      final fileUri = Uri.file(savePath);
      try {
        await launchUrl(fileUri);
      } catch (e) {
        throw Exception(
            'Impossibile avviare il file: ${result.message}\n'
            'Vai in Download e apri BimboMixer_update.$ext manualmente.');
      }
    }
  }
}
