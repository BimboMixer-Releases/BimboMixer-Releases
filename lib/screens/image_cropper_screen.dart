import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:crop_image/crop_image.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageCropperScreen extends StatefulWidget {
  final File imageFile;

  const ImageCropperScreen({super.key, required this.imageFile});

  @override
  State<ImageCropperScreen> createState() => _ImageCropperScreenState();
}

class _ImageCropperScreenState extends State<ImageCropperScreen> {
  final CropController _controller = CropController();
  bool _isProcessing = false;

  Future<void> _processAndReturn() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Ottieni l'immagine ritagliata come ui.Image
      ui.Image bitmap = await _controller.croppedBitmap();
      
      // 2. Converti in byte (PNG base)
      final data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();

      // 3. Elabora con il pacchetto "image" (compressione, contrasto, nitidezza)
      img.Image? decodedImage = img.decodeImage(bytes);
      
      if (decodedImage != null) {
        // Ridimensionamento per evitare pesi eccessivi (max altezza/larghezza ~ 1600)
        if (decodedImage.width > 1600 || decodedImage.height > 1600) {
          decodedImage = img.copyResize(
            decodedImage, 
            width: decodedImage.width > decodedImage.height ? 1600 : null,
            height: decodedImage.height >= decodedImage.width ? 1600 : null,
          );
        }

        // Miglioramento Contrasto
        decodedImage = img.adjustColor(decodedImage, contrast: 1.3);

        // Miglioramento Nitidezza (Sharpen tramite matrice di convoluzione)
        // Una matrice standard per sharpening
        decodedImage = img.convolution(
          decodedImage,
          filter: [
             0, -1,  0,
            -1,  5, -1,
             0, -1,  0
          ],
          div: 1,
          offset: 0,
        );

        // Codifica con altissima compressione JPG (es. quality = 60)
        final compressedBytes = img.encodeJpg(decodedImage, quality: 60);

        // Salva su un file temporaneo
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/cropped_receipt_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(compressedBytes);

        if (mounted) {
          Navigator.of(context).pop(tempFile);
        }
      } else {
        throw Exception("Impossibile decodificare l'immagine ritagliata.");
      }
    } catch (e) {
      print("Errore durante l'elaborazione dell'immagine: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il ritaglio: $e')),
        );
        Navigator.of(context).pop(widget.imageFile); // Fallback: ritorna l'originale
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ritaglia e Ottimizza'),
        actions: [
          IconButton(
            icon: Icon(Icons.rotate_right),
            onPressed: _isProcessing ? null : () {
              _controller.rotateRight();
            },
          ),
          IconButton(
            icon: Icon(Icons.check),
            onPressed: _isProcessing ? null : _processAndReturn,
          ),
        ],
      ),
      body: Stack(
        children: [
          CropImage(
            controller: _controller,
            image: Image.file(widget.imageFile),
            paddingSize: 25.0,
            alwaysMove: true,
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Ottimizzazione in corso...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}


