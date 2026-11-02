import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  final Dio _dio = Dio();

  static const String githubRepo = 'BimboMixer-Releases/BimboMixer-Releases';

  int _versionToInt(String version) {
    final String mainVersion = version.split('+').first.split('-').first;
    final String cleaned = mainVersion.replaceAll(RegExp(r'[^0-9.]'), '');
    final List<String> parts = cleaned.split('.');
    int val = 0;
    if (parts.isNotEmpty) val += (int.tryParse(parts[0]) ?? 0) * 1000000;
    if (parts.length > 1) val += (int.tryParse(parts[1]) ?? 0) * 1000;
    if (parts.length > 2) val += (int.tryParse(parts[2]) ?? 0);
    return val;
  }

  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      if (githubRepo.contains('TUO_USERNAME')) {
        debugPrint('Devi impostare il tuo username GitHub in update_service.dart');
        return null;
      }

      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final int currentVersionVal = _versionToInt(packageInfo.version);

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
        final String tagName = data['tag_name']?.toString() ?? '';
        final int latestVersionVal = _versionToInt(tagName);

        if (latestVersionVal > currentVersionVal) {
          String androidUrl = '';
          String windowsZipUrl = '';
          String windowsFallbackUrl = '';
          final String releaseNotes =
              data['body']?.toString() ?? 'Nuovo aggiornamento disponibile.';

          final List assets = (data['assets'] as List?) ?? [];
          for (final asset in assets) {
            final String name = asset['name']?.toString().toLowerCase() ?? '';
            final String downloadUrl =
                asset['browser_download_url']?.toString() ?? '';
            if (downloadUrl.isEmpty) continue;
            if (name.endsWith('.apk')) {
              androidUrl = downloadUrl;
            } else if (name.endsWith('.zip')) {
              windowsZipUrl = downloadUrl;
            } else if (name.endsWith('.exe') || name.endsWith('.msix')) {
              windowsFallbackUrl = downloadUrl;
            }
          }

          final String windowsUrl =
              windowsZipUrl.isNotEmpty ? windowsZipUrl : windowsFallbackUrl;

          if (androidUrl.isNotEmpty || windowsUrl.isNotEmpty) {
            return {
              'version': tagName,
              'versionName': tagName,
              'releaseNotes': releaseNotes,
              'androidUrl': androidUrl,
              'windowsUrl': windowsUrl,
            };
          }
        }
      }
    } catch (e) {
      debugPrint('Errore controllo aggiornamenti GitHub: $e');
    }
    return null;
  }

  Future<void> downloadAndInstallUpdate(
    String url,
    Function(double) onProgress,
  ) async {
    if (url.isEmpty) {
      throw Exception(
        'URL aggiornamento non disponibile per questa piattaforma.',
      );
    }

    try {
      if (Platform.isAndroid) {
        await _downloadAndInstallAndroid(url, onProgress);
      } else if (Platform.isWindows) {
        await _downloadAndInstallWindows(url, onProgress);
      } else {
        final uri = Uri.parse(url);
        final launched =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          throw Exception('Impossibile aprire il link di download nel browser.');
        }
      }
    } catch (e) {
      debugPrint('Errore durante il download o installazione: $e');
      rethrow;
    }
  }

  Future<void> _downloadAndInstallAndroid(
    String url,
    Function(double) onProgress,
  ) async {
    Directory? downloadsDir;
    if (Platform.isAndroid) {
      downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) {
        downloadsDir = await getExternalStorageDirectory();
      }
    } else {
      downloadsDir = await getDownloadsDirectory();
    }
    downloadsDir ??= await getApplicationDocumentsDirectory();

    String savePath = '${downloadsDir.path}/BimboMixer_update.apk';
    final file = File(savePath);
    try {
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {
      savePath =
          '${downloadsDir.path}/BimboMixer_update_${DateTime.now().millisecondsSinceEpoch}.apk';
    }

    try {
      await _dio.download(
        url,
        savePath,
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 2),
          headers: {
            'Accept': '*/*',
            'User-Agent': 'BimboMixer-App/1.0',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress(received / total);
          }
        },
      );
    } catch (e) {
      debugPrint('Errore Dio durante il download: $e');
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (_) {}
      throw Exception(
        'Server error o blocco download. Ti ho aperto il browser per scaricarlo manualmente!',
      );
    }

    final downloaded = File(savePath);
    if (!downloaded.existsSync() || downloaded.lengthSync() < 1024) {
      throw Exception('File scaricato non valido o troppo piccolo.');
    }

    final result = await OpenFilex.open(
      savePath,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      final fileUri = Uri.file(savePath);
      try {
        await launchUrl(fileUri);
      } catch (_) {
        throw Exception(
          'Impossibile avviare l\'installazione: ${result.message}\n'
          'Vai in Download e apri il file APK manualmente.',
        );
      }
    }
  }

  Future<void> _downloadAndInstallWindows(
    String url,
    Function(double) onProgress,
  ) async {
    Directory? downloadsDir = await getDownloadsDirectory();
    downloadsDir ??= await getApplicationDocumentsDirectory();

    String ext = url.split('?').first.split('.').last.toLowerCase();
    if (ext != 'zip' && ext != 'exe' && ext != 'msix') ext = 'zip';

    String savePath = '${downloadsDir.path}\\BimboMixer_update.$ext';
    final file = File(savePath);
    try {
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {
      savePath =
          '${downloadsDir.path}\\BimboMixer_update_${DateTime.now().millisecondsSinceEpoch}.$ext';
    }

    try {
      await _dio.download(
        url,
        savePath,
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 2),
          headers: {
            'Accept': '*/*',
            'User-Agent': 'BimboMixer-App/1.0',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress(received / total);
          }
        },
      );
    } catch (e) {
      debugPrint('Errore Dio durante il download su Windows: $e');
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (_) {}
      throw Exception(
        'Server error o blocco download. Ti ho aperto il browser per scaricarlo manualmente!',
      );
    }

    final downloaded = File(savePath);
    if (!downloaded.existsSync() || downloaded.lengthSync() < 1024) {
      throw Exception('File scaricato non valido o troppo piccolo.');
    }

    final result = await OpenFilex.open(savePath);
    if (result.type != ResultType.done) {
      final fileUri = Uri.file(savePath);
      try {
        await launchUrl(fileUri);
      } catch (_) {
        throw Exception(
          'Impossibile avviare il file: ${result.message}\n'
          'Vai in Download e apri il file manualmente.',
        );
      }
    }
  }
}
