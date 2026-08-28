$ErrorActionPreference = "Stop"

$token = Get-Content -Path "C:\Users\Hp\.github_token.txt" -Raw
$token = $token.Trim()
$repo = "BimboMixer-Releases/BimboMixer-Releases"
$version = "1.8.7"
$releaseId = "366374819"

# Local paths
$apkDest = "C:\Users\Hp\Desktop\Contabile APP Bimbomixer\BimboMixer_v$($version)_update.apk"
$zipDest = "C:\Users\Hp\Desktop\Contabile APP Bimbomixer\BimboMixer_v$($version)_update.zip"

function Upload-Asset {
    param(
        [string]$FilePath,
        [string]$FileName,
        [string]$ContentType
    )
    Write-Host "Uploading $FileName using Invoke-RestMethod -InFile..."
    $uploadUri = "https://uploads.github.com/repos/$repo/releases/$releaseId/assets?name=$FileName"
    
    $headers = @{
        "Authorization" = "token $token"
        "Accept" = "application/vnd.github.v3+json"
    }

    Invoke-RestMethod -Uri $uploadUri -Method Post -Headers $headers -ContentType $ContentType -InFile $FilePath
    
    Write-Host "`n$FileName uploaded successfully!"
}

Upload-Asset -FilePath $apkDest -FileName "BimboMixer_update.apk" -ContentType "application/vnd.android.package-archive"
Upload-Asset -FilePath $zipDest -FileName "BimboMixer_PC_Portable.zip" -ContentType "application/zip"

Write-Host "Tutto completato! L'aggiornamento è stato pubblicato con successo."
