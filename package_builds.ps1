$version = "1.9.31"
$apkDir = "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\Aggiornamenti App\Aggiornamenti Apk Android"
$pcDir = "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\Aggiornamenti App\Aggiornamenti App PC"

Write-Host "Packaging APK..."
if (!(Test-Path $apkDir)) { New-Item -ItemType Directory -Force -Path $apkDir | Out-Null }
Remove-Item "$apkDir\*" -Force -ErrorAction SilentlyContinue
if (Test-Path "build\app\outputs\flutter-apk\app-release.apk") {
    Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "$apkDir\BimboMixer_v${version}_update.apk" -Force
} else {
    Write-Host "APK non trovata!"
}

Write-Host "Packaging PC ZIP..."
if (!(Test-Path $pcDir)) { New-Item -ItemType Directory -Force -Path $pcDir | Out-Null }
Remove-Item "$pcDir\*" -Force -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path "build\windows\x64\runner\Release") {
    [System.IO.Compression.ZipFile]::CreateFromDirectory("build\windows\x64\runner\Release", "$pcDir\BimboMixer_v${version}_PC_Portable.zip")
} else {
    Write-Host "Release PC non trovata!"
}

Write-Host "Running github upload..."
if (Test-Path "upload_only.ps1") {
    .\upload_only.ps1
} elseif (Test-Path "github_release.ps1") {
    .\github_release.ps1
} else {
    Write-Host "Script di caricamento GitHub non trovato."
}
