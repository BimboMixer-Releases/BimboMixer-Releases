$ErrorActionPreference = "Stop"

$token = Get-Content -Path "C:\Users\Hp\.github_token.txt" -Raw
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

$apkDestPath = "C:\Users\Hp\Desktop\CONTABILE APP\Aggiornamenti Apk Android\BimboMixer_v$($version)_update.apk"
$pcAssetPath = "C:\Users\Hp\Desktop\CONTABILE APP\Aggiornamenti App PC\BimboMixer_v$($version).exe"
$pcAssetName = "BimboMixer_v$($version).exe"
$pcContentType = "application/x-msdownload"

if (-not (Test-Path $apkDestPath)) { Write-Error "APK non trovato: $apkDestPath"; exit 1 }
if (-not (Test-Path $pcAssetPath)) { Write-Error "EXE non trovato: $pcAssetPath"; exit 1 }

# Icona già impostata tramite WinRAR -iicon durante la fase di export.

Write-Host "`nPubblicazione su GitHub Release $tag..." -ForegroundColor Yellow

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
    Write-Host "  Uploading $FileName..."
    $uploadUri = "https://uploads.github.com/repos/$repo/releases/$releaseId/assets?name=$FileName"
    $fileBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $FilePath))
    $result = Invoke-RestMethod -Uri $uploadUri -Method Post -Headers $headers -Body $fileBytes -ContentType $ContentType
    Write-Host "  ✅ $FileName caricato ($(($result.size / 1MB).ToString('F1')) MB)"
}

if ($existingRelease) {
    $existingRelease.assets | Where-Object { $_.name -match "\.msix$|\.exe$|\.zip$|\.apk$" } | ForEach-Object {
        Write-Host "  Rimozione asset esistente: $($_.name)"
        Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/assets/$($_.id)" -Method Delete -Headers $headers
    }
}

Upload-Asset -FilePath $apkDestPath -FileName "BimboMixer_v$($version)_update.apk" -ContentType "application/vnd.android.package-archive"
Upload-Asset -FilePath $pcAssetPath -FileName $pcAssetName -ContentType $pcContentType

Write-Host "`n✅ Tutto completato! Versione v$version pubblicata su GitHub." -ForegroundColor Green
