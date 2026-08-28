$version = '1.8.19'
$winReleasePath = 'build\windows\x64\runner\Release'
$pcDestDir = 'C:\Users\Hp\Desktop\Contabile APP Bimbomixer'
$apkDestDir = 'C:\Users\Hp\Desktop\Contabile APP Bimbomixer'

# Crea cartelle
New-Item -ItemType Directory -Force -Path $pcDestDir | Out-Null
New-Item -ItemType Directory -Force -Path $apkDestDir | Out-Null

# Copia APK
$apkSrc = 'build\app\outputs\flutter-apk\app-release.apk'
$apkDest = "$apkDestDir\BimboMixer_v${version}_update.apk"
Remove-Item "$apkDestDir\*" -Force -ErrorAction SilentlyContinue
Copy-Item $apkSrc $apkDest -Force
Write-Host "APK copiato: $apkDest" -ForegroundColor Green

# Crea portable ZIP
$zipDest = "$pcDestDir\BimboMixer_v${version}_portable.zip"
Remove-Item "$pcDestDir\*" -Force -ErrorAction SilentlyContinue
Write-Host "Creazione ZIP..." -ForegroundColor Cyan
Compress-Archive -Path "$winReleasePath\*" -DestinationPath $zipDest -Force
Write-Host "ZIP creato: $zipDest" -ForegroundColor Green

# Pubblica su GitHub
$token = (Get-Content -Path "C:\Users\Hp\.github_token.txt" -Raw).Trim()
$repo = "BimboMixer-Releases/BimboMixer-Releases"
$tag = "v$version"
$headers = @{
    "Authorization" = "token $token"
    "Accept" = "application/vnd.github.v3+json"
}

# Controlla se la release esiste
$existingRelease = $null
try {
    $existingRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/tags/$tag" -Headers $headers -ErrorAction Stop
    Write-Host "Release $tag esistente (ID: $($existingRelease.id))" -ForegroundColor DarkYellow
    $releaseId = $existingRelease.id
} catch {
    $releaseBody = @{
        tag_name   = $tag
        name       = "Aggiornamento v$version"
        body       = "Nuovo aggiornamento v$version della Contabile App."
        draft      = $false
        prerelease = $false
    } | ConvertTo-Json
    $resp = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases" -Method Post -Headers $headers -Body $releaseBody -ContentType "application/json"
    $releaseId = $resp.id
    Write-Host "Release creata: ID $releaseId" -ForegroundColor Green
}

# Rimuovi asset esistenti
if ($existingRelease) {
    $existingRelease.assets | ForEach-Object {
        Write-Host "  Rimozione: $($_.name)"
        Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/assets/$($_.id)" -Method Delete -Headers $headers | Out-Null
    }
}

# Upload APK
function Upload-Asset {
    param([string]$FilePath, [string]$FileName, [string]$ContentType)
    Write-Host "  Upload $FileName..."
    $uri = "https://uploads.github.com/repos/$repo/releases/$releaseId/assets?name=$FileName"
    $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $FilePath))
    $r = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $bytes -ContentType $ContentType
    Write-Host "  OK: $FileName ($([math]::Round($r.size/1MB,1)) MB)" -ForegroundColor Green
}

Upload-Asset -FilePath $apkDest -FileName "BimboMixer_v${version}_update.apk" -ContentType "application/vnd.android.package-archive"
Upload-Asset -FilePath $zipDest -FileName "BimboMixer_v${version}_portable.zip" -ContentType "application/zip"

Write-Host "`nTutto completato! v$version pubblicata su GitHub." -ForegroundColor Cyan
Write-Host "URL: https://github.com/$repo/releases/tag/$tag" -ForegroundColor Cyan
