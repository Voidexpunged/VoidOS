param(
    [string]$ProjectPath = "C:\voidos",
    [int]$ImageSizeMB = 10
)

$bootPath   = Join-Path $ProjectPath "boot.bin"
$stage2Path = Join-Path $ProjectPath "stage2.bin"
$outPath    = Join-Path $ProjectPath "voidos.img"

Write-Host "Reading boot.bin..."
$boot = [System.IO.File]::ReadAllBytes($bootPath)

Write-Host "Reading stage2.bin..."
$stage2 = [System.IO.File]::ReadAllBytes($stage2Path)

$imgSize = $ImageSizeMB * 1MB
Write-Host "Allocating image buffer $imgSize bytes..."
$img = New-Object byte[] $imgSize

Write-Host "Writing boot sector (LBA 0)..."
[Array]::Copy($boot, 0, $img, 0, $boot.Length)

Write-Host "Writing stage2 at LBA 1..."
[Array]::Copy($stage2, 0, $img, 512, $stage2.Length)

Write-Host "Saving voidos.img..."
[System.IO.File]::WriteAllBytes($outPath, $img)

Write-Host "Done → $outPath"
Write-Host "Size:" (Get-Item $outPath).Length "bytes"
