$ErrorActionPreference = "Stop"
$version = "1.8.12"
$tag = "v$version"
$releaseName = "Aggiornamento v$version"
$body = "Nuovo aggiornamento v$version con UI per Inserimento/Modifica Fatture con più campi."

$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
$windowsBuildDir = "build\windows\x64\runner\Release"
$zipPath = "build\windows\x64\runner\BimboMixer_PC_Portable.zip"

$desktopDir = "C:\Users\Hp\Desktop\Aggiornamenti App"
$apkDestDir = "$desktopDir\Aggiornamenti Apk Android"
$zipDestDir = "$desktopDir\Aggiornamenti App PC"
New-Item -ItemType Directory -Force -Path $apkDestDir | Out-Null
New-Item -ItemType Directory -Force -Path $zipDestDir | Out-Null

$apkDest = "$apkDestDir\BimboMixer_v$($version)_update.apk"
$zipDest = "$zipDestDir\BimboMixer_v$($version)_update.zip"

Write-Host "1. Compilando Android APK..."
flutter build apk --release

Write-Host "2. Compilando Windows Portable App..."
flutter build windows --release

Write-Host "3. Creando MSIX Installer per Windows..."
flutter pub run msix:create
$msixPath = "build\windows\x64\runner\Release\contabile_app.msix"

Write-Host "4. Copiando i file nelle cartelle Desktop..."
Copy-Item -Path $apkPath -Destination $apkDest -Force
Copy-Item -Path $msixPath -Destination $zipDest -Force
Write-Host "Copia completata: $apkDest e $zipDest"

Write-Host "5. Uploading su GitHub Releases..."
$token = (Get-Content -Path "C:\Users\Hp\.github_token.txt" -Raw).Trim()
$repo = "BimboMixer-Releases/BimboMixer-Releases"
$headers = @{
    "Authorization" = "token $token"
    "Accept" = "application/vnd.github.v3+json"
}

$releaseBody = @{
    tag_name = $tag
    name = $releaseName
    body = $body
    draft = $false
    prerelease = $false
} | ConvertTo-Json

$releaseResponse = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases" -Method Post -Headers $headers -Body $releaseBody -ContentType "application/json"
$releaseId = $releaseResponse.id
Write-Host "Created release with ID: $releaseId"

Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.IO;
using System.Net;

public class Uploader {
    public static void UploadFile(string url, string filePath, string token, string contentType) {
        HttpWebRequest request = (HttpWebRequest)WebRequest.Create(url);
        request.Method = "POST";
        request.Headers.Add("Authorization", "token " + token);
        request.Accept = "application/vnd.github.v3+json";
        request.ContentType = contentType;
        request.UserAgent = "PowerShell-Agent";
        request.AllowWriteStreamBuffering = false;
        request.Timeout = System.Threading.Timeout.Infinite;
        
        FileInfo fi = new FileInfo(filePath);
        request.ContentLength = fi.Length;
        
        using (FileStream fileStream = fi.OpenRead())
        using (Stream requestStream = request.GetRequestStream()) {
            byte[] buffer = new byte[81920];
            int bytesRead;
            while ((bytesRead = fileStream.Read(buffer, 0, buffer.Length)) > 0) {
                requestStream.Write(buffer, 0, bytesRead);
            }
        }
        
        using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
        using (StreamReader reader = new StreamReader(response.GetResponseStream())) {
            Console.WriteLine("Success! Response: " + reader.ReadToEnd());
        }
    }
}
"@

$uploadUri = "https://uploads.github.com/repos/$repo/releases/$releaseId/assets?name=BimboMixer_update.apk"
Write-Host "Uploading APK..."
[Uploader]::UploadFile($uploadUri, $apkDest, $token, "application/vnd.android.package-archive")

$uploadUriZip = "https://uploads.github.com/repos/$repo/releases/$releaseId/assets?name=BimboMixer_PC_Installer.msix"
Write-Host "Uploading MSIX..."
[Uploader]::UploadFile($uploadUriZip, $zipDest, $token, "application/msix")

Write-Host "Processo terminato con successo!"
