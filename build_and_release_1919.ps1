Wait-Process -Name dart -ErrorAction SilentlyContinue

echo "Building APK..."
flutter build apk --release

echo "Building Windows..."
flutter build windows --release

echo "Packaging APK..."
$apkDir = "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\Aggiornamenti App\Aggiornamenti Apk Android"
Remove-Item "$apkDir\*" -Force -ErrorAction SilentlyContinue
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "$apkDir\BimboMixer_v1.9.19_update.apk" -Force

echo "Packaging PC..."
$pcDir = "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\Aggiornamenti App\Aggiornamenti App PC"
Remove-Item "$pcDir\*" -Force -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory('build\windows\x64\runner\Release', "$pcDir\BimboMixer_v1.9.19_PC_Portable.zip")

echo "Running GitHub Release..."
powershell -ExecutionPolicy Bypass -File .\github_release.ps1
echo "All done!"
