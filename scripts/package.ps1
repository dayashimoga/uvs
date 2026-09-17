# Universal Video Studio - Package (PowerShell)
$ErrorActionPreference = "Stop"

$root = (Get-Item -Path "$PSScriptRoot\..").FullName
$distDir = "$root\dist"
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

Write-Host ">>> Packaging Universal Video Studio Distributables..." -ForegroundColor Cyan

# Package Windows Distributable
$winDist = "$distDir\universal_video_studio_windows_x64.zip"
$tempWin = "$distDir\win_pkg"
New-Item -ItemType Directory -Force -Path $tempWin | Out-Null
Copy-Item "$root\core\rust\target\release\*.dll" -Destination $tempWin -ErrorAction SilentlyContinue
Copy-Item "$root\core\rust\target\release\*.lib" -Destination $tempWin -ErrorAction SilentlyContinue
Copy-Item "$root\README.md" -Destination $tempWin
Compress-Archive -Path "$tempWin\*" -DestinationPath $winDist -Force
Remove-Item -Recurse -Force $tempWin

# Compute SHA256
$hash = (Get-FileHash -Path $winDist -Algorithm SHA256).Hash
"$hash  universal_video_studio_windows_x64.zip" | Out-File -FilePath "$distDir\SHA256SUMS" -Encoding utf8

Write-Host "[SUCCESS] Created package: $winDist (SHA256: $hash)" -ForegroundColor Green
