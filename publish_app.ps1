$ErrorActionPreference = "Stop"

Write-Host "Publishing Android APK..."
Remove-Item "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\CONTABILE APP Bimbomixer\*" -Force -ErrorAction SilentlyContinue
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\CONTABILE APP Bimbomixer\BimboMixer_v1.8.7_update.apk" -Force
Write-Host "Android APK published!"

Write-Host "Publishing Windows App..."
Remove-Item "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\CONTABILE APP Bimbomixer\*" -Force -ErrorAction SilentlyContinue
Compress-Archive -Path build\windows\x64\runner\Release\* -DestinationPath "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\CONTABILE APP Bimbomixer\BimboMixer_v1.8.7_update.zip" -Force
Write-Host "Windows App published!"
