$ErrorActionPreference = "Stop"

$token = Get-Content -Path "C:\Users\Hp\Documents\Sviluppo\Token di accesso\token.txt" -Raw
$token = $token.Trim()
$repo = "BimboMixer-Releases/BimboMixer-Releases"

$pubspecContent = Get-Content "pubspec.yaml" -Raw
if ($pubspecContent -match "version:\s*([\d.]+)\+") {
    $version = $Matches[1]
} else {
    Write-Error "Impossibile leggere la versione da pubspec.yaml"
    exit 1
}

$tag = "v$version"
$releaseName = "Aggiornamento v$version"
$body = "Nuovo aggiornamento v$version della Contabile App."

Write-Host "=== Rilascio versione $version ===" -ForegroundColor Cyan

# Step 1: Crea release via curl
Write-Host "
[1/2] Creazione Release $tag su GitHub..." -ForegroundColor Yellow
$releaseData = @{
    tag_name = $tag
    name = $releaseName
    body = $body
    draft = $false
    prerelease = $false
} | ConvertTo-Json

$releaseResponse = curl.exe -s -X POST -H "Authorization: token $token" -H "Accept: application/vnd.github.v3+json" -d $releaseData "https://api.github.com/repos/$repo/releases" | ConvertFrom-Json
if ($releaseResponse.id -eq $null) {
    # Prova a recuperare la release esistente
    $existingRelease = curl.exe -s -H "Authorization: token $token" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/$repo/releases/tags/$tag" | ConvertFrom-Json
    if ($existingRelease.id -eq $null) {
        Write-Error "Errore durante la creazione della release."
        exit 1
    }
    $releaseId = $existingRelease.id
} else {
    $releaseId = $releaseResponse.id
}

Write-Host "Release ID: $releaseId" -ForegroundColor Green

# Step 2: Upload assets via curl
$apkPath = "C:\Users\Hp\Desktop\Contabile APP Bimbomixer\BimboMixer_v${version}_update.apk"
$zipPath = "C:\Users\Hp\Desktop\Contabile APP Bimbomixer\BimboMixer_v${version}_portable.zip"

if (Test-Path $apkPath) {
    Write-Host "Uploading APK..."
    $apkName = Split-Path $apkPath -Leaf
    curl.exe -s -X POST -H "Authorization: token $token" -H "Content-Type: application/vnd.android.package-archive" --data-binary "@$apkPath" "https://uploads.github.com/repos/$repo/releases/$releaseId/assets?name=$apkName" | Out-Null
    Write-Host "APK caricato con successo!" -ForegroundColor Green
}

if (Test-Path $zipPath) {
    Write-Host "Uploading ZIP..."
    $zipName = Split-Path $zipPath -Leaf
    curl.exe -s -X POST -H "Authorization: token $token" -H "Content-Type: application/zip" --data-binary "@$zipPath" "https://uploads.github.com/repos/$repo/releases/$releaseId/assets?name=$zipName" | Out-Null
    Write-Host "ZIP caricato con successo!" -ForegroundColor Green
}

Write-Host "
Release completata con successo!" -ForegroundColor Green
