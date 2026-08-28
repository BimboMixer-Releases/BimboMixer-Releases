import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../screens/image_cropper_screen.dart';

class AttachmentService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Future<File?> _processPickedFile(BuildContext? context, File? file) async {
    if (file == null || context == null) return file;
    
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
      return null; // L'utente ha annullato il ritaglio
    }
    return file; // Restituisce PDF o altri file non immagine così com'è
  }

  /// Pick an image from the camera (Android/iOS)
  Future<File?> pickImageFromCamera(BuildContext context) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Su desktop la fotocamera non è supportata da image_picker, facciamo fallback al FilePicker
      return pickFile(context);
    }
    
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 100);
      if (image != null) {
        return _processPickedFile(context, File(image.path));
      }
    } catch (e) {
      print('Errore fotocamera: $e');
    }
    return null;
  }

  /// Pick an image from the gallery (Android/iOS)
  Future<File?> pickImageFromGallery(BuildContext context) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (image != null) {
      return _processPickedFile(context, File(image.path));
    }
    return null;
  }

  /// Pick a file (PDF, image, etc.) from the file system (Windows/Android/iOS)
  Future<File?> pickFile(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result != null && result.files.single.path != null) {
      return _processPickedFile(context, File(result.files.single.path!));
    }
    return null;
  }

  /// Uploads a file to Firebase Storage and returns its download URL
  Future<String?> uploadAttachment(File file, String folder) async {
    try {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
      
      // Rimuovi spazi dal nome file
      fileName = fileName.replaceAll(' ', '_');

      Reference ref = _storage.ref().child('$folder/$fileName');
      
      final bytes = await file.readAsBytes();
      UploadTask uploadTask = ref.putData(bytes);
      
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Errore durante l\'upload dell\'allegato: $e');
      throw Exception('Caricamento fallito (Controlla le regole di Firebase Storage o la connessione): $e');
    }
  }

  /// Scarica un allegato e lo salva in locale
  Future<void> downloadAttachment(BuildContext context, String url) async {
    try {
      final dio = Dio();
      String? dirPath;
      if (Platform.isWindows) {
        final dir = await getDownloadsDirectory();
        dirPath = dir?.path;
      } else if (Platform.isAndroid || Platform.isIOS) {
        // Su Android, possiamo usare getExternalStorageDirectory() o getDownloadsDirectory()
        final dir = await getDownloadsDirectory();
        dirPath = dir?.path;
      }
      
      if (dirPath == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossibile trovare la cartella di download.')));
        }
        return;
      }
      
      final uri = Uri.parse(url);
      String fileName = uri.pathSegments.last;
      if (url.contains('firebasestorage')) {
        fileName = uri.pathSegments.last.split('%2F').last;
        fileName = fileName.split('?').first;
      }
      
      // Aggiungi timestamp per evitare sovrascritture
      final ext = p.extension(fileName);
      final nameWithoutExt = p.basenameWithoutExtension(fileName);
      fileName = '${nameWithoutExt}_${DateTime.now().millisecondsSinceEpoch}$ext';
      
      final savePath = p.join(dirPath, fileName);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download in corso...')));
      }
      
      await dio.download(url, savePath);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File salvato in Download:\n$fileName'), duration: const Duration(seconds: 4)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore durante il download: $e')));
      }
    }
  }
}
