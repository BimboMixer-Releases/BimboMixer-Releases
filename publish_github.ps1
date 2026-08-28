$token = Get-Content "C:\Users\Hp\Documents\Sviluppo\Token di accesso\token.txt" -Raw
$token = $token.Trim()
$repo = "BimboMixer-Releases/BimboMixer-Releases"
$version = "1.8.24"

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
        "body" = "Risolti errori di caricamento e versione."
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
Write-Host "Uploading APK..."

# Upload APK
$apkPath = "C:\Users\Hp\Documents\Sviluppo\contabile\contabile_app\build\app\outputs\flutter-apk\app-release.apk"
$apkName = "contabile_app.apk"
$apkUploadUrl = $uploadUrl + "?name=" + $apkName

$uploadHeaders = @{
    "Authorization" = "token $token"
    "Content-Type" = "application/vnd.android.package-archive"
}

try {
    Invoke-RestMethod -Uri $apkUploadUrl -Method Post -Headers $uploadHeaders -InFile $apkPath
    Write-Host "APK uploaded successfully."
} catch {
    Write-Host "Failed to upload APK. Error:"
    Write-Host $_.Exception.Message
}
