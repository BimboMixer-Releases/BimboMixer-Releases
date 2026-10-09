$ErrorActionPreference = 'Stop'

$token = Get-Content -Path 'C:\Users\Hp\Documents\Sviluppo\Token di accesso\token.txt' -Raw
$token = $token.Trim()
$repo = 'BimboMixer-Releases/BimboMixer-Releases'

$pubspecContent = Get-Content 'pubspec.yaml' -Raw
if ($pubspecContent -match 'version:\s*([\d.]+)\+') {
    $version = $Matches[1]
} else {
    Write-Error 'Impossibile leggere la versione da pubspec.yaml'
    exit 1
}

$tag = "v$version"
$releaseName = "Aggiornamento v$version"
$body = "Nuovo aggiornamento v$version della Contabile App."

Write-Host "=== Rilascio versione $version ===" -ForegroundColor Cyan

# Step 1: Crea release via Invoke-RestMethod
Write-Host "
[1/2] Creazione Release $tag su GitHub..." -ForegroundColor Yellow
$releaseData = @{
    tag_name = $tag
    name = $releaseName
    body = $body
    draft = $false
    prerelease = $false
} | ConvertTo-Json

$headers = @{
    'Authorization' = "token $token"
    'Accept' = 'application/vnd.github.v3+json'
}

try {
    $releaseResponse = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases" -Method Post -Headers $headers -Body $releaseData -ContentType 'application/json'
    $releaseId = $releaseResponse.id
} catch {
    # Prova a recuperare la release esistente
    try {
        $existingRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/tags/$tag" -Method Get -Headers $headers
        $releaseId = $existingRelease.id
    } catch {
        Write-Error 'Errore durante la creazione della release.'
        exit 1
    }
}

Write-Host "Release ID: $releaseId" -ForegroundColor Green

# Step 2: Upload assets via Invoke-RestMethod
$apkPath = "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\Aggiornamenti App\Aggiornamenti Apk Android\BimboMixer_v$($version)_update.apk"
$zipPath = "C:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\Aggiornamenti App\Aggiornamenti App PC\BimboMixer_v$($version)_PC_Portable.zip"

if (Test-Path $apkPath) {
    Write-Host "Uploading APK..."
    $apkName = Split-Path $apkPath -Leaf
    $uploadUri = "https://uploads.github.com/repos/$repo/releases/$releaseId/assets?name=$apkName"
    Invoke-RestMethod -Uri $uploadUri -Method Post -Headers $headers -InFile $apkPath -ContentType 'application/vnd.android.package-archive' | Out-Null
    Write-Host "APK caricato con successo!" -ForegroundColor Green
} else {
    Write-Host "APK non trovato: $apkPath" -ForegroundColor Red
}

if (Test-Path $zipPath) {
    Write-Host "Uploading ZIP..."
    $zipName = Split-Path $zipPath -Leaf
    $uploadUri = "https://uploads.github.com/repos/$repo/releases/$releaseId/assets?name=$zipName"
    Invoke-RestMethod -Uri $uploadUri -Method Post -Headers $headers -InFile $zipPath -ContentType 'application/zip' | Out-Null
    Write-Host "ZIP caricato con successo!" -ForegroundColor Green
} else {
    Write-Host "ZIP non trovato: $zipPath" -ForegroundColor Red
}

Write-Host "
Release completata con successo!" -ForegroundColor Green
