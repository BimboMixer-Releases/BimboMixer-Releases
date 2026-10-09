$ErrorActionPreference = "Stop"
$version = "v1.8.51"
$notes = "Nuova versione con fix per il loop degli aggiornamenti (causato da un precedente errore di compilazione su GitHub) e schermata di login aggiornata."

# 1. Commit changes
git add pubspec.yaml lib/
git commit -m "chore: bump version to $version and fix compile errors"
git push origin main

# 2. Tag release
git tag $version
git push origin $version

# 3. Create Release on GitHub
gh release create $version --title "BimboMixer Contabile App $version" --notes $notes

# 4. Build APK
flutter build apk --release

# 5. Build Windows ZIP
flutter build windows --release
$buildDir = "build\windows\x64\runner\Release"
$zipName = "contabile_app_windows_$version.zip"
Compress-Archive -Path "$buildDir\*" -DestinationPath $zipName -Force

# 6. Upload Assets
gh release upload $version build\app\outputs\flutter-apk\app-release.apk
gh release upload $version $zipName

Write-Host "Release $version completed successfully!" -ForegroundColor Green
