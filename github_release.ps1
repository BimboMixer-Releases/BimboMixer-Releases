[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "Stop"

$token = Get-Content -Path "C:\Users\Hp\Documents\Sviluppo\Token di accesso\token.txt" -Raw
$token = $token.Trim()
$repo = "BimboMixer-Releases/BimboMixer-Releases"

# Legge la versione automaticamente da pubspec.yaml
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

# â”€â”€ 1. Build Android APK â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Write-Host "`n[1/4] Build Android APK..." -ForegroundColor Yellow
flutter build apk --release
if ($LASTEXITCODE -ne 0) { Write-Error "Build APK fallita!"; exit 1 }

# â”€â”€ 2. Build Windows + MSIX â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Write-Host "`n[2/4] Build Windows + MSIX..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) { Write-Error "Build Windows fallita!"; exit 1 }

# dart run msix:create rimosso perche causa freeze

$msixExists = Test-Path "build\windows\x64\runner\Release\contabile_app.msix"
if (-not $msixExists) {
    Write-Host "  MSIX non generato, creo il portable ZIP come alternativa..." -ForegroundColor DarkYellow
}

# ————————————————————————————————————————————————————————————————————————————————
Write-Host "`n[3/4] Copia locale su Desktop..." -ForegroundColor Yellow

# Directory di esportazione finali (senza sottocartelle Android e PC, tutto nella stessa cartella Bimbomixer come richiesto)
$destDir = "C:\Users\Hp\Desktop\Contabile APP Bimbomixer"
if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }

# APK
$apkSrcPath = "build\app\outputs\flutter-apk\app-release.apk"
$apkDestPath = "$destDir\BimboMixer_v$($version)_update.apk"
Copy-Item $apkSrcPath $apkDestPath -Force
Write-Host "APK copiato: $apkDestPath"

# MSIX o Portable ZIP

$msixSrcPath = "build\windows\x64\runner\Release\contabile_app.msix"
$winReleasePath = "build\windows\x64\runner\Release"
$pcAssetPath = $null
$pcAssetName = $null
$pcContentType = $null

if (Test-Path $msixSrcPath) {
    $pcAssetPath = "$destDir\BimboMixer_v$($version)_update.msix"
    Copy-Item $msixSrcPath $pcAssetPath -Force
    Write-Host "MSIX copiato: $pcAssetPath"
    $pcAssetName = "BimboMixer_v$($version)_update.msix"
    $pcContentType = "application/msix"
} else {
    # Fallback: crea un portable ZIP
    $zipPath = "$destDir\BimboMixer_v$($version)_portable.zip"
    Write-Host "  Creo portable ZIP da $winReleasePath..." -ForegroundColor DarkCyan
    Compress-Archive -Path "$winReleasePath\*" -DestinationPath $zipPath -Force
    $pcAssetPath = $zipPath
    $pcAssetName = "BimboMixer_v$($version)_portable.zip"
    $pcContentType = "application/zip"
    Write-Host "Portable ZIP creato: $zipPath"
}

# â”€â”€ 4. Pubblica su GitHub â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Write-Host "`n[4/4] Pubblicazione su GitHub Release $tag..." -ForegroundColor Yellow

$headers = @{
    "Authorization" = "token $token"
    "Accept" = "application/vnd.github.v3+json"
}

# Controlla se il tag esiste giÃ 
$existingRelease = $null
try {
    $existingRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/tags/$tag" -Headers $headers -ErrorAction Stop
    Write-Host "Release $tag giÃ  esistente (ID: $($existingRelease.id)). Aggiunta asset..." -ForegroundColor DarkYellow
    $releaseId = $existingRelease.id
} catch {
    # Crea nuova release
    $releaseBody = @{
        tag_name   = $tag
        name       = $releaseName
        body       = $body
        draft      = $false
        prerelease = $false
    } | ConvertTo-Json

    $releaseResponse = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases" -Method Post -Headers $headers -Body $releaseBody -ContentType "application/json"
    $releaseId = $releaseResponse.id
    Write-Host "Release creata con ID: $releaseId"
}

# Funzione upload asset
function Upload-Asset {
    param(
        [string]$FilePath,
        [string]$FileName,
        [string]$ContentType
    )
    Write-Host "  Uploading $FileName..."
    $uploadUri = "https://uploads.github.com/repos/$repo/releases/$releaseId/assets?name=$FileName"
    $resolvedPath = Resolve-Path $FilePath
    curl.exe -s -X POST -H "Authorization: token $token" -H "Content-Type: $ContentType" --data-binary "@$resolvedPath" "$uploadUri" | Out-Null
    Write-Host "  $FileName caricato!" -ForegroundColor Green
}

# Rimuovi asset PC esistenti se in aggiornamento
if ($existingRelease) {
    $existingRelease.assets | Where-Object { $_.name -match "\.msix$|\.exe$|\.zip$|\.apk$" } | ForEach-Object {
        Write-Host "  Rimozione asset esistente: $($_.name)"
        Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/assets/$($_.id)" -Method Delete -Headers $headers
    }
}

Upload-Asset -FilePath $apkDestPath -FileName "BimboMixer_v$($version)_update.apk" -ContentType "application/vnd.android.package-archive"
Upload-Asset -FilePath $pcAssetPath -FileName $pcAssetName -ContentType $pcContentType

Write-Host "`nTutto completato! Versione v$version pubblicata su GitHub." -ForegroundColor Green
Write-Host "URL: https://github.com/$repo/releases/tag/$tag" -ForegroundColor Cyan



