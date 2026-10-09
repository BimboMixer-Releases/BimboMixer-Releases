$ErrorActionPreference = 'Stop'

$pubspecContent = Get-Content 'pubspec.yaml' -Raw
if ($pubspecContent -match 'version:\s*([\d.]+)\+') {
    $version = $Matches[1]
} else {
    Write-Error 'Impossibile leggere la versione da pubspec.yaml'
    exit 1
}

Write-Host "Building APK for version $version..."
flutter build apk --release
Write-Host "Building Windows for version $version..."
flutter build windows --release

Write-Host "Copying files..."
Remove-Item "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\Aggiornamenti App\Aggiornamenti Apk Android\*" -Force -ErrorAction SilentlyContinue
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\Aggiornamenti App\Aggiornamenti Apk Android\BimboMixer_v$($version)_update.apk" -Force

Remove-Item "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\Aggiornamenti App\Aggiornamenti App PC\*" -Force -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory('build\windows\x64\runner\Release', "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\Aggiornamenti App\Aggiornamenti App PC\BimboMixer_v$($version)_PC_Portable.zip")

Write-Host "Running GitHub Release..."
.\upload_only.ps1

