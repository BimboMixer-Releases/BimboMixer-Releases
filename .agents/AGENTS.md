# Project Guidelines

## Output Directory Rules (OBBLIGATORIO — rispettare sempre)

- **Cartella Principale**: Tutti gli aggiornamenti devono essere salvati in `C:\Users\Hp\Desktop\Aggiornamenti App`.

- **Output Android APK**: Ogni volta che viene compilata una nuova APK Android, deve essere:
  1. Eliminato qualsiasi file APK preesistente in `C:\Users\Hp\Desktop\Aggiornamenti App\Aggiornamenti Apk Android`
  2. Copiata la nuova APK in `C:\Users\Hp\Desktop\Aggiornamenti App\Aggiornamenti Apk Android` con nome `BimboMixer_vX.X_update.apk` (dove X.X è la versione corrente) prima di inviare l'aggiornamento alle piattaforme.

- **Output PC (Windows EXE/ZIP)**: L'app per PC deve **sempre** essere creata come versione Portable (zippando la cartella `Release`). Ogni volta che viene compilata una nuova build PC, deve essere:
  1. Eliminato qualsiasi file preesistente in `C:\Users\Hp\Desktop\Aggiornamenti App\Aggiornamenti App PC`
  2. Zippato il contenuto di `build\windows\x64\runner\Release`
  3. Copiato il file zip in `C:\Users\Hp\Desktop\Aggiornamenti App\Aggiornamenti App PC` con nome `BimboMixer_vX.X_PC_Portable.zip` prima di inviare l'aggiornamento alle piattaforme.

- **Nessuna versione vecchia**: Non devono MAI coesistere più versioni nella stessa cartella. La cartella deve contenere sempre e solo l'ultimo aggiornamento.

## Build Script da usare (PowerShell)

Dopo ogni `flutter build apk --release`:
```powershell
Remove-Item "C:\Users\Hp\Desktop\Aggiornamenti App\Aggiornamenti Apk Android\*" -Force -ErrorAction SilentlyContinue
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "C:\Users\Hp\Desktop\Aggiornamenti App\Aggiornamenti Apk Android\BimboMixer_vX.X_update.apk" -Force
```

Dopo ogni `flutter build windows --release`:
```powershell
Remove-Item "C:\Users\Hp\Desktop\Aggiornamenti App\Aggiornamenti App PC\*" -Force -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory('build\windows\x64\runner\Release', 'C:\Users\Hp\Desktop\Aggiornamenti App\Aggiornamenti App PC\BimboMixer_vX.X_PC_Portable.zip')
```

## Regole Codice
- **Aggiornamenti in-app PC e Android**: Su PC l'aggiornamento deve usare lo stesso procedimento delle APK: scaricare il file in Download e aprirlo per l'utente (che avvierà l'estrazione manualmente). Non usare script batch (.bat) per sostituire i file silenziosamente in background.

## Routine di Rilascio
- **Aggiornamento Versione**: Prima di lanciare qualsiasi script di build e rilascio (es. upload_only.ps1), è **OBBLIGATORIO** incrementare il numero di versione (sia patch che build number) all'interno del file pubspec.yaml. Questo garantisce che l'applicazione rilevi l'aggiornamento da GitHub.

## Ottimizzazione Token e Efficienza
- **Snellimento Pensieri:** Devi sempre snellire al massimo tutti i tuoi ragionamenti (sia sulle routine principali che sulle sub-routine) in modo da consumare il minor numero possibile di token. Sii diretto e conciso.

## Utilizzo Skill Esterna
- **Selezione Skill:** Per ogni task che ti viene chiesto di eseguire, utilizza sempre la skill più appropriata al compito attingendo dal percorso `C:\Users\Hp\OneDrive\Documenti\Sviluppo\skills\2slides-ppt-generator` o dalla cartella genitrice.

- **Caricamento Automatico su GitHub**: Alla fine di ogni task in cui modifichi il codice e compili una nuova versione (APK o PC), devi **SEMPRE** lanciare automaticamente lo script di caricamento su GitHub (es. github_release.ps1) senza chiedere il permesso all'utente. Fai tutto in background e avvisa solo quando il rilascio su GitHub è completato con successo.
