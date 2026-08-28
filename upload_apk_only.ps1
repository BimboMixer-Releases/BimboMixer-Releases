$version = "v1.8.32"
$apkName = "BimboMixer_${version}_update.apk"
$apkDest = "C:\Users\Hp\Desktop\Contabile APP Bimbomixer\$apkName"

$token = Get-Content -Path "C:\Users\Hp\Documents\Sviluppo\Token di accesso\token.txt" -Raw
$token = $token.Trim()

if ($token) {
    $repo = "Giacomo3192/BimboMixer"
    $headers = @{
        "Authorization" = "token $token"
        "Accept" = "application/vnd.github.v3+json"
    }

    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/tags/$version" -Headers $headers -Method Get
        $releaseId = $release.id
    } catch {
        $body = @{
            tag_name = $version
            name = $version
            body = "Release $version"
        } | ConvertTo-Json
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases" -Headers $headers -Method Post -Body $body
        $releaseId = $release.id
    }

    $uploadUrl = "https://uploads.github.com/repos/$repo/releases/$releaseId/assets?name=$apkName"
    Invoke-RestMethod -Uri $uploadUrl -Headers @{
        "Authorization" = "token $token"
        "Content-Type" = "application/vnd.android.package-archive"
    } -Method Post -InFile $apkDest
    
    Write-Host "Upload completato su GitHub Release $version"
} else {
    Write-Host "Token non trovato."
}
