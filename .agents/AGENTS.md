# Project Guidelines

## Output Directory Rules (OBBLIGATORIO — rispettare sempre)

> **Aggiornamento 25/09/2026**: Le cartelle di output sono state spostate dal Desktop alla radice del progetto `contabile_app`. I percorsi Desktop precedenti sono obsoleti. Vedi sezione "Separazione obbligatoria dei progetti" a fine file.

- **Cartella APK Android**: `C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\Aggiornamenti App\Aggiornamenti Apk Android`
- **Cartella ZIP PC**: `C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\Aggiornamenti App\Aggiornamenti App PC`

- **Output Android APK**: Ogni volta che viene compilata una nuova APK Android, deve essere:
  1. Eliminato qualsiasi file APK preesistente nella cartella APK Android sopra indicata
  2. Copiata la nuova APK con nome `BimboMixer_vX.X_update.apk` (dove X.X è la versione corrente)

- **Output PC (Windows EXE/ZIP)**: L'app per PC deve **sempre** essere creata come versione Portable (zippando la cartella `Release`). Ogni volta che viene compilata una nuova build PC, deve essere:
  1. Eliminato qualsiasi file preesistente nella cartella ZIP PC sopra indicata
  2. Zippato il contenuto di `build\windows\x64\runner\Release`
  3. Copiato il file zip con nome `BimboMixer_vX.X_PC_Portable.zip`

- **Nessuna versione vecchia**: Non devono MAI coesistere più versioni nella stessa cartella. La cartella deve contenere sempre e solo l'ultimo aggiornamento.

## Build Script da usare (PowerShell)

Dopo ogni `flutter build apk --release`:
```powershell
$apkDir = "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\Aggiornamenti App\Aggiornamenti Apk Android"
Remove-Item "$apkDir\*" -Force -ErrorAction SilentlyContinue
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "$apkDir\BimboMixer_vX.X_update.apk" -Force
```

Dopo ogni `flutter build windows --release`:
```powershell
$pcDir = "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\Aggiornamenti App\Aggiornamenti App PC"
Remove-Item "$pcDir\*" -Force -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory('build\windows\x64\runner\Release', "$pcDir\BimboMixer_vX.X_PC_Portable.zip")
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

## Separazione obbligatoria dei progetti - indicazione utente 25 settembre 2026

Il progetto attivo Bimbomixer Contabilita e esclusivamente questa cartella contabile_app.
La cartella contabile_app_mixed_backup e stata archiviata in Sviluppo\Archivio progetti separati, fuori dal progetto attivo.
NON usarla mai per questo progetto: non leggere o importare codice da essa, non usarla come riferimento, dipendenza, workspace, base per fix o fonte per ripristinare file. Contiene anche un altro progetto, TaxFlow. Non mescolare i due progetti.
Le cartelle Aggiornamenti App e CONTABILE APP Bimbomixer sono ora dentro la radice di questo progetto. Non ricrearle sul Desktop. Questa indicazione dell'utente sostituisce i vecchi percorsi Desktop riportati sopra.

## Regola Versione
- **Nuova regola (Ottobre 2026)**: Il terzo numero della versione non deve mai superare il 99. Se si arriva a 1.x.99, l'aggiornamento successivo dovrà incrementare il numero centrale e azzerare l'ultimo a 1 (es. da 1.8.99 si passa a 1.9.1, NON a 1.8.100). Il build number dopo il + continua a salire progressivamente sempre.
