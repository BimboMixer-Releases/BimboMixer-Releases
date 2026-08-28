$oldDir = 'C:\Users\Hp\Desktop\Nuove apk'
$newDir = 'C:\Users\Hp\Desktop\CONTABILE APP'

if (-not (Test-Path $newDir)) {
    New-Item -ItemType Directory -Force -Path $newDir | Out-Null
    Write-Host "Creata nuova cartella: $newDir"
}

if (Test-Path $oldDir) {
    # Move subfolders
    Get-ChildItem -Path $oldDir | Move-Item -Destination $newDir -Force
    # Remove old dir
    Remove-Item $oldDir -Force -Recurse
    Write-Host "Migrazione completata da $oldDir a $newDir"
} else {
    Write-Host "Vecchia cartella non trovata ($oldDir)"
}

# Clean old versions
$files = Get-ChildItem -Path $newDir -Recurse -File
if ($files) {
    $groupedFiles = $files | Group-Object { $_.DirectoryName, $_.Extension }
    foreach ($group in $groupedFiles) {
        if ($group.Group.Count -gt 1) {
            $sorted = $group.Group | Sort-Object LastWriteTime -Descending
            # Keep newest, remove the rest
            for ($i = 1; $i -lt $sorted.Count; $i++) {
                Remove-Item $sorted[$i].FullName -Force
                Write-Host "Rimosso file vecchio: $($sorted[$i].FullName)"
            }
        }
    }
}
Write-Host "Pulizia completata."
