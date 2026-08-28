$ErrorActionPreference = "Stop"

$token = Get-Content -Path "C:\Users\Hp\.github_token.txt" -Raw
$token = $token.Trim()
$repo = "BimboMixer-Releases/BimboMixer-Releases"
$version = "1.8.7"
$releaseId = "366374819"

# Local paths
$apkDest = "C:\Users\Hp\Desktop\Contabile APP Bimbomixer\BimboMixer_v$($version)_update.apk"
$zipDest = "C:\Users\Hp\Desktop\Contabile APP Bimbomixer\BimboMixer_v$($version)_update.zip"

function Upload-Asset-Curl {
    param(
        [string]$FilePath,
        [string]$FileName,
        [string]$ContentType
    )
    Write-Host "Uploading $FileName using curl.exe..."
    $uploadUri = "https://uploads.github.com/repos/$repo/releases/$releaseId/assets?name=$FileName"
    
    # Costruisci l'argomento per curl
    $authHeader = "Authorization: token $token"
    $acceptHeader = "Accept: application/vnd.github.v3+json"
    $contentTypeHeader = "Content-Type: $ContentType"

    curl.exe -sL -X POST -H $authHeader -H $acceptHeader -H $contentTypeHeader --data-binary "@$FilePath" $uploadUri
    
    Write-Host "`n$FileName uploaded successfully!"
}

Upload-Asset-Curl -FilePath $apkDest -FileName "BimboMixer_update.apk" -ContentType "application/vnd.android.package-archive"
Upload-Asset-Curl -FilePath $zipDest -FileName "BimboMixer_PC_Portable.zip" -ContentType "application/zip"

Write-Host "Tutto completato! L'aggiornamento è stato pubblicato con curl.exe."
