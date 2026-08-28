import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';

class AdminUpdateScreen extends StatelessWidget {
  const AdminUpdateScreen({super.key});

  Future<void> _openGitHub() async {
    if (UpdateService.githubRepo.contains('TUO_USERNAME')) {
      return;
    }
    final url = Uri.parse('https://github.com/${UpdateService.githubRepo}/releases/new');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isPlaceholder = UpdateService.githubRepo.contains('TUO_USERNAME');
    
    return Scaffold(
      backgroundColor: const Color(0xFF14141A),
      appBar: AppBar(
        title: Text('Pubblica Aggiornamento', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.cloud_upload_rounded, size: 80, color: Colors.blueAccent),
              SizedBox(height: 24),
              Text(
                'Distribuzione con GitHub Releases',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 24),
              if (isPlaceholder)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 40),
                      SizedBox(height: 12),
                      Text(
                        'Devi prima configurare il tuo username GitHub!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. Crea un account su GitHub.com\n'
                        '2. Crea un repository pubblico chiamato "BimboMixer-Releases"\n'
                        '3. Apri il file "lib/services/update_service.dart"\n'
                        '4. Modifica "TUO_USERNAME" con il tuo vero nome utente',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Istruzioni per la pubblicazione:',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      SizedBox(height: 16),
                      _buildStep(1, 'Genera i file di aggiornamento', 'Il programma ha generato un file .zip e un .apk sulla Scrivania.'),
                      SizedBox(height: 12),
                      _buildStep(2, 'Apri GitHub', 'Clicca il pulsante qui sotto per aprire la pagina delle Release del tuo repository.'),
                      SizedBox(height: 12),
                      _buildStep(3, 'Crea una nuova Release', 'Clicca su "Draft a new release". Inserisci come "Tag" la versione esatta che hai nel file pubspec.yaml (es. "v1.7.0").'),
                      SizedBox(height: 12),
                      _buildStep(4, 'Carica i file', 'Trascina i file .zip e .apk nel riquadro in basso e premi "Publish release".'),
                    ],
                  ),
                ),
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: isPlaceholder ? null : _openGitHub,
                icon: Icon(Icons.open_in_browser),
                label: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Apri Pagina GitHub', style: TextStyle(fontSize: 18)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade800,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(int number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.blueAccent,
            shape: BoxShape.circle,
          ),
          child: Text('$number', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(description, style: TextStyle(color: Colors.white.withOpacity(0.7))),
            ],
          ),
        ),
      ],
    );
  }
}



