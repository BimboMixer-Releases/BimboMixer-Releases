$token = Get-Content "C:\Users\Hp\Documents\Sviluppo\Token di accesso\token.txt" -Raw
$token = $token.Trim()
$repo = "BimboMixer-Releases/BimboMixer-Releases"
$version = "1.8.45"

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
        "body" = "Fase 3: Rimossa password nei preventivi, aggiunto simbolo euro, fix colori dropdown e aggiunto logo."
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
$apkPath = "C:\Users\Hp\Desktop\CONTABILE APP Bimbomixer\Contabile_Bimbomixer_v1.8.45.apk"
$apkName = "Contabile_Bimbomixer_v1.8.45.apk"
$apkUploadUrl = $uploadUrl + "?name=" + $apkName

$uploadHeadersApk = @{
    "Authorization" = "token $token"
    "Content-Type" = "application/vnd.android.package-archive"
}

Write-Host "Uploading APK..."
try {
    Invoke-RestMethod -Uri $apkUploadUrl -Method Post -Headers $uploadHeadersApk -InFile $apkPath
    Write-Host "APK uploaded successfully."
} catch {
    Write-Host "Failed to upload APK. Error:"
    Write-Host $_.Exception.Message
}

# Upload ZIP
$zipPath = "C:\Users\Hp\Desktop\CONTABILE APP Bimbomixer\Contabile_Bimbomixer_Windows_v1.8.45.zip"
$zipName = "Contabile_Bimbomixer_Windows_v1.8.45.zip"
$zipUploadUrl = $uploadUrl + "?name=" + $zipName

$uploadHeadersZip = @{
    "Authorization" = "token $token"
    "Content-Type" = "application/zip"
}

Write-Host "Uploading ZIP..."
try {
    Invoke-RestMethod -Uri $zipUploadUrl -Method Post -Headers $uploadHeadersZip -InFile $zipPath
    Write-Host "ZIP uploaded successfully."
} catch {
    Write-Host "Failed to upload ZIP. Error:"
    Write-Host $_.Exception.Message
}
