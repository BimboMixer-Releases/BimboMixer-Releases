$ErrorActionPreference = "Stop"
$Version = "1.8.52"

Write-Host "Building Android APK..."
flutter build apk --release

Write-Host "Copying APK..."
Remove-Item "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\Aggiornamenti App\Aggiornamenti Apk Android\*" -Force -ErrorAction SilentlyContinue
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\Aggiornamenti App\Aggiornamenti Apk Android\BimboMixer_v$Version`_update.apk" -Force

Write-Host "Building Windows Desktop..."
flutter build windows --release

Write-Host "Zipping Windows Desktop..."
Remove-Item "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\Aggiornamenti App\Aggiornamenti App PC\*" -Force -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory('build\windows\x64\runner\Release', "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\Aggiornamenti App\Aggiornamenti App PC\BimboMixer_v$Version`_PC_Portable.zip")

Write-Host "Running github_release.ps1..."
.\github_release.ps1

Write-Host "All done."
