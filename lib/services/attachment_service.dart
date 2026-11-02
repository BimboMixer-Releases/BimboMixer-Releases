import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../screens/image_cropper_screen.dart';

class AttachmentService {
  FirebaseStorage get _storage => FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Future<File?> _processPickedFile(BuildContext? context, File? file) async {
    if (file == null || context == null || !context.mounted) return file;

    final ext = p.extension(file.path).toLowerCase();
    if (ext == '.jpg' || ext == '.jpeg' || ext == '.png') {
      final processedFile = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ImageCropperScreen(imageFile: file),
        ),
      );
      if (processedFile != null && processedFile is File) {
        return processedFile;
      }
      return null;
    }
    return file;
  }

  /// Pick an image from the camera (Android/iOS)
  Future<File?> pickImageFromCamera(BuildContext context) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return pickFile(context);
    }

    try {
      final XFile? image =
          await _picker.pickImage(source: ImageSource.camera, imageQuality: 100);
      if (image != null) {
        if (!context.mounted) return File(image.path);
        return _processPickedFile(context, File(image.path));
      }
    } catch (e) {
      debugPrint('Errore fotocamera: $e');
    }
    return null;
  }

  /// Pick an image from the gallery (Android/iOS)
  Future<File?> pickImageFromGallery(BuildContext context) async {
    try {
      final XFile? image =
          await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
      if (image != null) {
        if (!context.mounted) return File(image.path);
        return _processPickedFile(context, File(image.path));
      }
    } catch (e) {
      debugPrint('Errore galleria: $e');
    }
    return null;
  }

  /// Pick a file (PDF, image, etc.) from the file system (Windows/Android/iOS)
  Future<File?> pickFile(BuildContext context) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result != null && result.files.single.path != null) {
      final picked = File(result.files.single.path!);
      if (!context.mounted) return picked;
      return _processPickedFile(context, picked);
    }
    return null;
  }

  /// Uploads a file to Firebase Storage and returns its download URL
  Future<String?> uploadAttachment(File file, String folder) async {
    try {
      String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
      fileName = fileName.replaceAll(' ', '_');

      final Reference ref = _storage.ref().child('$folder/$fileName');
      final bytes = await file.readAsBytes();
      final UploadTask uploadTask = ref.putData(bytes);
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Errore durante l\'upload dell\'allegato: $e');
      throw Exception(
        'Caricamento fallito (Controlla le regole di Firebase Storage o la connessione): $e',
      );
    }
  }

  /// Deletes a file from Firebase Storage given its download URL
  Future<void> deleteAttachment(String url) async {
    if (url.isEmpty || !url.contains('firebasestorage')) return;
    try {
      final Reference ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('Errore durante l\'eliminazione dell\'allegato: $e');
    }
  }

  /// Estrae il nome pulito del file da un URL (anche Firebase Storage con %2F) o percorso locale.
  static String extractCleanFileName(String urlOrPath) {
    if (urlOrPath.isEmpty) return 'allegato';
    try {
      if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
        final uri = Uri.parse(urlOrPath);
        if (uri.pathSegments.isNotEmpty) {
          final decoded = Uri.decodeFull(uri.pathSegments.last);
          final base = decoded
              .split('/')
              .last
              .split('\\')
              .last
              .split('?')
              .first
              .trim();
          if (base.isNotEmpty) return base;
        }
      }
      return p.basename(urlOrPath.split('?').first);
    } catch (_) {
      return 'allegato';
    }
  }

  /// Scarica un allegato e lo salva in locale
  Future<void> downloadAttachment(BuildContext context, String url) async {
    try {
      final dio = Dio();
      Directory? dir;
      if (Platform.isAndroid) {
        final pubDownload = Directory('/storage/emulated/0/Download');
        if (pubDownload.existsSync()) {
          dir = pubDownload;
        } else {
          dir = await getDownloadsDirectory() ?? await getExternalStorageDirectory();
        }
      } else {
        dir = await getDownloadsDirectory();
      }
      dir ??= await getApplicationDocumentsDirectory();

      String fileName = extractCleanFileName(url);
      fileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

      final ext = p.extension(fileName);
      final nameWithoutExt = p.basenameWithoutExtension(fileName);
      fileName = '${nameWithoutExt}_${DateTime.now().millisecondsSinceEpoch}$ext';

      final savePath = p.join(dir.path, fileName);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download in corso...')),
        );
      }

      await dio.download(url, savePath);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File salvato in Download:\n$fileName'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il download: $e')),
        );
      }
    }
  }
}
