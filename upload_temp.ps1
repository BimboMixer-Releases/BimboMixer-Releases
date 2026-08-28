$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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

Write-Host "=== Rilascio versione $version (SOLO UPLOAD) ===" -ForegroundColor Cyan

# ── 3. Copia locale ──────────────────────────────────────────────────────────
Write-Host "`n[3/4] Copia locale su Desktop..." -ForegroundColor Yellow

# APK
$apkSrcPath = "build\app\outputs\flutter-apk\app-release.apk"
$apkDestDir = "C:\Users\Hp\Desktop\Contabile APP Bimbomixer"
$apkDestPath = "$apkDestDir\BimboMixer_v$($version)_update.apk"
Remove-Item "$apkDestDir\*" -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $apkDestDir | Out-Null
Copy-Item $apkSrcPath $apkDestPath -Force
Write-Host "APK copiato: $apkDestPath"

# Portable ZIP
$pcDestDir = "C:\Users\Hp\Desktop\Contabile APP Bimbomixer"
Remove-Item "$pcDestDir\*" -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $pcDestDir | Out-Null

$winReleasePath = "build\windows\x64\runner\Release"

$zipPath = "$pcDestDir\BimboMixer_v$($version)_portable.zip"
Write-Host "  Creo portable ZIP da $winReleasePath..." -ForegroundColor DarkCyan

$pcAssetPath = $zipPath
$pcAssetName = "BimboMixer_v$($version)_portable.zip"
$pcContentType = "application/zip"
Write-Host "Portable ZIP creato: $zipPath"

# ── 4. Pubblica su GitHub ─────────────────────────────────────────────────────
Write-Host "`n[4/4] Pubblicazione su GitHub Release $tag..." -ForegroundColor Yellow

$headers = @{
    "Authorization" = "token $token"
    "Accept" = "application/vnd.github.v3+json"
}

$existingRelease = $null
try {
    $existingRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/tags/$tag" -Headers $headers -ErrorAction Stop
    Write-Host "Release $tag già esistente (ID: $($existingRelease.id)). Aggiunta asset..." -ForegroundColor DarkYellow
    $releaseId = $existingRelease.id
} catch {
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

function Upload-Asset {
    param(
        [string]$FilePath,
        [string]$FileName,
        [string]$ContentType
    )
    Write-Host "  Uploading $FileName via curl..."
    $uploadUri = "https://uploads.github.com/repos/$repo/releases/$releaseId/assets?name=$FileName"
    $fullPath = Resolve-Path $FilePath
    $curlOutput = curl.exe -s -X POST -H "Authorization: token $token" -H "Accept: application/vnd.github.v3+json" -H "Content-Type: $ContentType" --data-binary "@$fullPath" $uploadUri
    Write-Host "  ✅ $FileName caricato"
}

if ($existingRelease) {
    $existingRelease.assets | Where-Object { $_.name -match "\.msix$|\.exe$|\.zip$|\.apk$" } | ForEach-Object {
        Write-Host "  Rimozione asset esistente: $($_.name)"
        Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/assets/$($_.id)" -Method Delete -Headers $headers
    }
}

Upload-Asset -FilePath $apkDestPath -FileName "BimboMixer_v$($version)_update.apk" -ContentType "application/vnd.android.package-archive"


Write-Host "`n✅ Tutto completato! Versione v$version pubblicata su GitHub." -ForegroundColor Green
