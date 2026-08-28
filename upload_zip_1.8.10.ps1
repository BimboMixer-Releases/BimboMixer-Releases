$ErrorActionPreference = "Stop"
$token = Get-Content -Path "C:\Users\Hp\.github_token.txt" -Raw
$token = $token.Trim()
$releaseId = "366509804"
$version = "1.8.10"
$repo = "BimboMixer-Releases/BimboMixer-Releases"

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

$zipDest = "C:\Users\Hp\Desktop\Contabile APP Bimbomixer\BimboMixer_v$($version)_update.zip"
$uploadUriZip = "https://uploads.github.com/repos/$repo/releases/$releaseId/assets?name=BimboMixer_PC_Portable.zip"
Write-Host "Uploading ZIP with C# HTTP stream..."
[Uploader]::UploadFile($uploadUriZip, $zipDest, $token, "application/zip")
