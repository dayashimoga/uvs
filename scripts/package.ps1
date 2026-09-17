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
Copy-Item "$root\core\rust\target\release\uvs_core.dll" -Destination $tempWin -ErrorAction SilentlyContinue
Copy-Item "$root\dist\uvs_sbom.json" -Destination $tempWin -ErrorAction SilentlyContinue
Copy-Item "$root\README.md" -Destination $tempWin
Compress-Archive -Path "$tempWin\*" -DestinationPath $winDist -Force
Remove-Item -Recurse -Force $tempWin

# Copy Android artifacts if available
$apkSrc = "$root\apps\flutter_app\build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apkSrc) {
    Copy-Item $apkSrc -Destination "$distDir\app-release.apk" -Force
}

$aabSrc = "$root\apps\flutter_app\build\app\outputs\bundle\release\app-release.aab"
if (Test-Path $aabSrc) {
    Copy-Item $aabSrc -Destination "$distDir\app-release.aab" -Force
}

# Compute SHA256 for all release packages in dist
$hashLines = @()
$releaseFiles = @("universal_video_studio_windows_x64.zip", "app-release.apk", "app-release.aab", "uvs_sbom.json")
foreach ($f in $releaseFiles) {
    $filePath = "$distDir\$f"
    if (Test-Path $filePath) {
        $fileHash = (Get-FileHash -Path $filePath -Algorithm SHA256).Hash.ToLower()
        $hashLines += "$fileHash  $f"
        Write-Host "  Artifact: $f (SHA256: $fileHash)" -ForegroundColor Gray
    }
}
$hashLines | Out-File -FilePath "$distDir\SHA256SUMS" -Encoding utf8

Write-Host "[SUCCESS] Packaged distribution artifacts and generated SHA256SUMS" -ForegroundColor Green


