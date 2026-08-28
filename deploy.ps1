$targetDir = "C:\Users\Hp\Desktop\Aggiornamenti App"
$androidDir = "$targetDir\Android"
$pcDir = "$targetDir\PC"

New-Item -ItemType Directory -Force -Path $androidDir
New-Item -ItemType Directory -Force -Path $pcDir

# Copy APK
$apkSource = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apkSource) {
    Copy-Item -Path $apkSource -Destination "$androidDir\contabile_app.apk" -Force
    Write-Host "APK copiato con successo."
} else {
    Write-Host "APK non trovato."
}

# Copia i file Windows senza zippare
$windowsSource = "build\windows\x64\runner\Release"
if (Test-Path $windowsSource) {
    Copy-Item -Path "$windowsSource\*" -Destination $pcDir -Recurse -Force
    Write-Host "App PC copiata con successo come cartella indipendente."
} else {
    Write-Host "Build Windows non trovata."
}
