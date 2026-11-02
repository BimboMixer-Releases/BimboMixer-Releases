import 'dart:io';
import 'package:contabile_app/services/update_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateDialog extends StatefulWidget {
  final Map<String, dynamic> updateData;
  final UpdateService updateService;

  const UpdateDialog({
    super.key,
    required this.updateData,
    required this.updateService,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  bool _downloadCompleted = false;
  double _progress = 0.0;
  String _status = '';
  bool _hasError = false;
  String _downloadUrl = '';

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _downloadUrl = widget.updateData['windowsUrl']?.toString() ?? '';
    } else if (Platform.isAndroid) {
      _downloadUrl = widget.updateData['androidUrl']?.toString() ?? '';
    } else {
      _downloadUrl = widget.updateData['windowsUrl']?.toString() ??
          widget.updateData['androidUrl']?.toString() ??
          '';
    }
  }

  Future<void> _startUpdate() async {
    if (_downloadUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _status =
            'Nessun file di aggiornamento disponibile per questa piattaforma.\n'
            'Contatta l\'amministratore.';
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadCompleted = false;
      _hasError = false;
      _status = 'Avvio download...';
      _progress = 0.0;
    });

    try {
      await widget.updateService.downloadAndInstallUpdate(
        _downloadUrl,
        (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _status =
                  'Download: ${(progress * 100).toStringAsFixed(0)}% completato';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadCompleted = true;
          _progress = 1.0;
          _status = Platform.isWindows
              ? 'Download completato! Il file ZIP è stato aperto nella cartella Download.'
              : 'Download completato! Segui la schermata di installazione.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _hasError = true;
          _status = 'Errore: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  Future<void> _openInBrowser() async {
    if (_downloadUrl.isEmpty) return;
    final uri = Uri.parse(_downloadUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching url: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final versionName = widget.updateData['versionName']?.toString() ??
        widget.updateData['version']?.toString() ??
        'Nuova versione';
    final notes = widget.updateData['releaseNotes']?.toString() ??
        widget.updateData['notes']?.toString() ??
        '';

    final isWindows = Platform.isWindows;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.system_update, color: Colors.blueAccent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aggiornamento Disponibile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Versione $versionName',
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Novità:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notes,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              if (isWindows && !_hasError) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blueAccent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.laptop_windows,
                            color: Colors.blueAccent,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Aggiornamento PC',
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        '1. Clicca "Scarica Ora"\n'
                        '2. Il file ZIP verrà scaricato in Download\n'
                        '3. Aprilo per estrarre e usare la nuova versione',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_isDownloading) ...[
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.blueAccent,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _progress > 0
                      ? '${(_progress * 100).toStringAsFixed(0)}%'
                      : 'Connessione...',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ] else if (_downloadCompleted) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.greenAccent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.greenAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _status,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_hasError) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.redAccent,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Errore aggiornamento',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _status,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  isWindows
                      ? 'Vuoi scaricare la nuova versione per PC?'
                      : 'Vuoi scaricare e installare l\'aggiornamento?',
                  style: const TextStyle(color: Colors.white70),
                ),
                if (_downloadUrl.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'File non ancora disponibile per questa piattaforma.',
                      style:
                          TextStyle(color: Colors.orangeAccent, fontSize: 12),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!_isDownloading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _downloadCompleted ? 'Chiudi' : 'Più Tardi',
              style: const TextStyle(color: Colors.white54),
            ),
          ),
        if (_hasError && _downloadUrl.isNotEmpty)
          TextButton.icon(
            onPressed: _openInBrowser,
            icon: const Icon(
              Icons.open_in_browser,
              size: 16,
              color: Colors.blueAccent,
            ),
            label: const Text(
              'Scarica dal Browser',
              style: TextStyle(color: Colors.blueAccent),
            ),
          ),
        if (!_isDownloading && !_hasError && !_downloadCompleted)
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: Text(isWindows ? 'Scarica Ora' : 'Aggiorna Ora'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _downloadUrl.isNotEmpty ? _startUpdate : null,
          ),
        if (_hasError)
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Riprova'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _startUpdate,
          ),
      ],
    );
  }
}
