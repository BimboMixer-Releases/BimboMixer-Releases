Write-Host "Building Windows..."
flutter build windows --release
Write-Host "Building APK..."
flutter build apk --release
Write-Host "Exporting release locally..."
.\export_release.ps1
Write-Host "Publishing to GitHub..."
.\publish_current.ps1
Write-Host "All done!"
