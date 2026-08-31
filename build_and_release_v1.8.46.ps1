$version = "1.8.46"
$desktop = "$env:USERPROFILE\Desktop\CONTABILE APP Bimbomixer"
$apkName = "Contabile_Bimbomixer_v$version.apk"
$zipName = "Contabile_Bimbomixer_Windows_v$version.zip"

Write-Host "Building Windows..."
flutter build windows
Write-Host "Compressing Windows Build..."
Compress-Archive -Path build\windows\x64\runner\Release\* -DestinationPath "$desktop\$zipName" -Force

Write-Host "Building APK..."
flutter build apk --release
Write-Host "Copying APK..."
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" -Destination "$desktop\$apkName" -Force

$token = Get-Content "C:\Users\Hp\Documents\Sviluppo\Token di accesso\token.txt" -Raw
$token = $token.Trim()
$repo = "BimboMixer-Releases/BimboMixer-Releases"

$headers = @{
    "Authorization" = "token $token"
    "Accept" = "application/vnd.github.v3+json"
}

Write-Host "Publishing release v$version on $repo..."

# Check if release exists
$releaseResponse = $null
try {
    $releaseResponse = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/tags/v$version" -Method Get -Headers $headers
    Write-Host "Release v$version already exists."
} catch {
    Write-Host "Release v$version does not exist. Creating..."
}

if ($null -eq $releaseResponse) {
    # Create Release
    $body = @{
        "tag_name" = "v$version"
        "name" = "Release v$version"
        "body" = "Fase 4: Migrazione finale a design opaco per tutti i contenitori (rimosso effetto Glass), fix simbolo euro globale, aggiornamento schermata Scadenze Programmate (status badge, date range, toggle rapido) e fix calcoli patrimonio netto per data_from."
    } | ConvertTo-Json

    try {
        $releaseResponse = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases" -Method Post -Headers $headers -Body $body -ContentType "application/json"
        Write-Host "Release created successfully."
    } catch {
        Write-Host "Failed to create release. Error:"
        Write-Host $_.Exception.Message
        exit 1
    }
}

$uploadUrl = $releaseResponse.upload_url.Split('{')[0]

# Upload APK
$apkUploadUrl = $uploadUrl + "?name=" + $apkName
$uploadHeadersApk = @{
    "Authorization" = "token $token"
    "Content-Type" = "application/vnd.android.package-archive"
}

Write-Host "Uploading APK..."
try {
    Invoke-RestMethod -Uri $apkUploadUrl -Method Post -Headers $uploadHeadersApk -InFile "$desktop\$apkName"
    Write-Host "APK uploaded successfully."
} catch {
    Write-Host "Failed to upload APK. Error:"
    Write-Host $_.Exception.Message
}

# Upload ZIP
$zipUploadUrl = $uploadUrl + "?name=" + $zipName
$uploadHeadersZip = @{
    "Authorization" = "token $token"
    "Content-Type" = "application/zip"
}

Write-Host "Uploading ZIP..."
try {
    Invoke-RestMethod -Uri $zipUploadUrl -Method Post -Headers $uploadHeadersZip -InFile "$desktop\$zipName"
    Write-Host "ZIP uploaded successfully."
} catch {
    Write-Host "Failed to upload ZIP. Error:"
    Write-Host $_.Exception.Message
}
