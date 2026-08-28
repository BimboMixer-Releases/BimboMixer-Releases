import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/update_service.dart';

class ClientUpdateScreen extends StatefulWidget {
  final Map<String, dynamic> updateData;
  const ClientUpdateScreen({super.key, required this.updateData});

  @override
  State<ClientUpdateScreen> createState() => _ClientUpdateScreenState();
}

class _ClientUpdateScreenState extends State<ClientUpdateScreen> {
  final UpdateService _updateService = UpdateService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = "Pronto per il download";

  @override
  void initState() {
    super.initState();
    _playSound();
  }

  Future<void> _playSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/blimp.wav'));
    } catch (e) {
      print("Errore riproduzione suono: $e");
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _statusMessage = "Download in corso...";
    });

    try {
      String url = Theme.of(context).platform == TargetPlatform.windows
          ? widget.updateData['windowsUrl']
          : widget.updateData['androidUrl'];

      await _updateService.downloadAndInstallUpdate(url, (progress) {
        setState(() {
          _progress = progress;
        });
      });
      
      setState(() {
        _statusMessage = "Download completato! Installazione in corso...";
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _statusMessage = "Errore durante il download.";
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Errore: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Aggiornamento Software"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.system_update_alt, size: 80, color: Colors.blueAccent),
              SizedBox(height: 24),
              Text(
                "Nuova versione trovata: ${widget.updateData['versionName']}",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                "Clicca il pulsante qui sotto per scaricare e installare automaticamente l'aggiornamento.",
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 48),
              
              if (_isDownloading) ...[
                LinearProgressIndicator(value: _progress),
                SizedBox(height: 16),
                Text("${(_progress * 100).toStringAsFixed(1)}%"),
                SizedBox(height: 8),
                Text(_statusMessage, style: TextStyle(color: Colors.grey)),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _startDownload,
                  icon: Icon(Icons.download),
                  label: Text("Scarica e Installa"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


