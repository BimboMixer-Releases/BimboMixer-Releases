$pubspecContent = Get-Content "pubspec.yaml" -Raw
if ($pubspecContent -match "version:\s*([\d.]+)\+") {
    $version = $Matches[1]
} else {
    Write-Error "Impossibile leggere la versione da pubspec.yaml"
    exit 1
}
$winReleasePath = 'build\windows\x64\runner\Release'
$pcDestDir = 'C:\Users\Hp\Desktop\CONTABILE APP\Aggiornamenti App PC'
$apkDestDir = 'C:\Users\Hp\Desktop\CONTABILE APP\Aggiornamenti Apk Android'
$winrar = "C:\Program Files\WinRAR\WinRAR.exe"
$iconPath = (Resolve-Path "windows\runner\resources\app_icon.ico").Path

# Crea cartelle
if (-not (Test-Path $pcDestDir)) { New-Item -ItemType Directory -Force -Path $pcDestDir | Out-Null }
if (-not (Test-Path $apkDestDir)) { New-Item -ItemType Directory -Force -Path $apkDestDir | Out-Null }

# Pulisce versioni vecchie nelle cartelle
Remove-Item "$apkDestDir\*" -Force -ErrorAction SilentlyContinue
Remove-Item "$pcDestDir\*" -Force -ErrorAction SilentlyContinue

# Copia APK
$apkSrc = 'build\app\outputs\flutter-apk\app-release.apk'
if (Test-Path $apkSrc) {
    $apkDest = "$apkDestDir\BimboMixer_v${version}_update.apk"
    Copy-Item $apkSrc $apkDest -Force
    Write-Host "APK copiato: $apkDest"
} else {
    Write-Host "Attenzione: file APK non trovato in $apkSrc. Assicurati di aver eseguito 'flutter build apk'."
}

# Crea file eseguibile Auto-estraente (SFX) per PC con ICONA
if (Test-Path "$winReleasePath\contabile_app.exe") {
    $exeDest = "$pcDestDir\BimboMixer_v${version}.exe"
    
    # Crea il file di configurazione SFX temporaneo
    $sfxConfig = @"
Setup=contabile_app.exe
TempMode
Silent=1
Overwrite=1
"@
    Set-Content -Path "sfx_config.txt" -Value $sfxConfig -Encoding UTF8

    if (Test-Path $winrar) {
        Write-Host "Creazione eseguibile SFX con WinRAR in corso..."
        # Utilizzo Start-Process per WinRAR (GUI) per supportare l'opzione -iicon ed attendo la fine del processo
        Start-Process -FilePath $winrar -ArgumentList "a -r -sfx -s -m5 -ep1 -iicon`"$iconPath`" -z`"sfx_config.txt`" `"$exeDest`" `"$winReleasePath\*`"" -Wait
        Remove-Item "sfx_config.txt" -Force
        
        if (Test-Path $exeDest) {
            Write-Host "File eseguibile creato con successo con icona: $exeDest"
        } else {
            Write-Host "Errore durante la creazione dell'eseguibile. Controlla che WinRAR abbia completato senza errori."
        }
    } else {
        Write-Host "Errore: WinRAR non trovato in $winrar. Impossibile creare l'eseguibile SFX."
    }
} else {
    Write-Host "Attenzione: Eseguibile Windows non trovato in $winReleasePath. Assicurati di aver eseguito 'flutter build windows'."
}

Write-Host 'Esportazione completata in CONTABILE APP!'
