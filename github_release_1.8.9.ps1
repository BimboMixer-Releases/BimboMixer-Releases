$ErrorActionPreference = "Stop"

$token = Get-Content -Path "C:\Users\Hp\.github_token.txt" -Raw
$token = $token.Trim()
$repo = "BimboMixer-Releases/BimboMixer-Releases"
$version = "1.8.9"
$tag = "v$version"
$releaseName = "Aggiornamento v$version"
$body = "Nuovo aggiornamento v$version con supporto per importazione XLSX/ODS multi-campo e calcolo divisioni preventivi. Nuova notifica sonora per aggiornamenti PC."

$headers = @{
    "Authorization" = "token $token"
    "Accept" = "application/vnd.github.v3+json"
}

# Creazione Release GitHub
Write-Host "Creating GitHub Release $tag..."
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
        request.AllowWriteStreamBuffering = false; // prevents OutOfMemory and hanging
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

$apkDest = "C:\Users\Hp\Desktop\Contabile APP Bimbomixer\BimboMixer_v$($version)_update.apk"
$uploadUri = "https://uploads.github.com/repos/$repo/releases/$releaseId/assets?name=BimboMixer_update.apk"
Write-Host "Uploading APK with C# HTTP stream..."
[Uploader]::UploadFile($uploadUri, $apkDest, $token, "application/vnd.android.package-archive")

$zipDest = "C:\Users\Hp\Desktop\Contabile APP Bimbomixer\BimboMixer_v$($version)_update.zip"
$uploadUriZip = "https://uploads.github.com/repos/$repo/releases/$releaseId/assets?name=BimboMixer_PC_Portable.zip"
Write-Host "Uploading ZIP with C# HTTP stream..."
[Uploader]::UploadFile($uploadUriZip, $zipDest, $token, "application/zip")

Write-Host "Tutto completato! L'aggiornamento è stato pubblicato con successo con streaming C#!"
