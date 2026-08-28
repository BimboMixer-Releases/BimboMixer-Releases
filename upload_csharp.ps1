$ErrorActionPreference = "Stop"

$token = Get-Content -Path "C:\Users\Hp\.github_token.txt" -Raw
$token = $token.Trim()
$releaseId = "366374819"
$version = "1.8.7"

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
            byte[] buffer = new byte[81920]; // 80KB chunks
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
$uploadUri = "https://uploads.github.com/repos/BimboMixer-Releases/BimboMixer-Releases/releases/$releaseId/assets?name=BimboMixer_update.apk"
Write-Host "Uploading APK with C# HTTP stream..."
[Uploader]::UploadFile($uploadUri, $apkDest, $token, "application/vnd.android.package-archive")

$zipDest = "C:\Users\Hp\Desktop\Contabile APP Bimbomixer\BimboMixer_v$($version)_update.zip"
$uploadUriZip = "https://uploads.github.com/repos/BimboMixer-Releases/BimboMixer-Releases/releases/$releaseId/assets?name=BimboMixer_PC_Portable.zip"
Write-Host "Uploading ZIP with C# HTTP stream..."
[Uploader]::UploadFile($uploadUriZip, $zipDest, $token, "application/zip")

Write-Host "Tutto completato! L'aggiornamento è stato pubblicato con successo con streaming C#!"
