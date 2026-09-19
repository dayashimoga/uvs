# Universal Video Studio - Canonical Windows Packaging & Release Verifier
$ErrorActionPreference = "Stop"

$root = (Get-Item -Path "$PSScriptRoot\..").FullName
$distDir = "$root\dist"
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "   Universal Video Studio - Windows Canonical Packaging Pipeline" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# 1. Locate Flutter Windows Release output
$winBuildCandidates = @(
    "$root\apps\flutter_app\build\windows\x64\runner\Release",
    "$root\apps\flutter_app\build\windows\runner\Release"
)

$winReleaseDir = $null
foreach ($cand in $winBuildCandidates) {
    if ((Test-Path "$cand\universal_video_studio.exe") -or (Test-Path "$cand\uvs.exe")) {
        $winReleaseDir = $cand
        break
    }
}

if (-not $winReleaseDir) {
    Write-Host ">>> Flutter Windows release output not found. Attempting build..." -ForegroundColor Yellow
    $flutterBin = "flutter"
    if (Test-Path "C:\flutter\bin\flutter.bat") {
        $flutterBin = "C:\flutter\bin\flutter.bat"
    }

    Push-Location "$root\apps\flutter_app"
    try {
        & $flutterBin build windows --release
    } catch {
        Write-Host "[WARN] 'flutter build windows --release' encountered an error." -ForegroundColor Yellow
    } finally {
        Pop-Location
    }

    foreach ($cand in $winBuildCandidates) {
        if ((Test-Path "$cand\universal_video_studio.exe") -or (Test-Path "$cand\uvs.exe")) {
            $winReleaseDir = $cand
            break
        }
    }
}

if (-not $winReleaseDir) {
    Write-Host "`n[FAIL / HARDWARE-REQUIRED] Flutter Windows Release executable (universal_video_studio.exe or uvs.exe) was not found." -ForegroundColor Red
    Write-Host "Visual Studio C++ Desktop Development Workload is required to compile Windows desktop Flutter runners." -ForegroundColor Red
    Write-Host "This step compiles and packages automatically on GitHub Actions 'windows-latest' runner." -ForegroundColor Yellow
    Write-Host "Refusing to create a fake, incomplete 841 KB ZIP." -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Found Flutter Windows Release directory: $winReleaseDir" -ForegroundColor Green

# 2. Stage complete package
$tempWin = "$distDir\win_pkg_staging"
if (Test-Path $tempWin) { Remove-Item -Recurse -Force $tempWin }
New-Item -ItemType Directory -Force -Path $tempWin | Out-Null

Write-Host ">>> Staging canonical application files..." -ForegroundColor Cyan
# Copy all Flutter release files
Copy-Item -Recurse -Path "$winReleaseDir\*" -Destination $tempWin

# Ensure both binary aliases exist in the package
if ((Test-Path "$tempWin\universal_video_studio.exe") -and (-not (Test-Path "$tempWin\uvs.exe"))) {
    Copy-Item "$tempWin\universal_video_studio.exe" -Destination "$tempWin\uvs.exe" -Force
} elseif ((Test-Path "$tempWin\uvs.exe") -and (-not (Test-Path "$tempWin\universal_video_studio.exe"))) {
    Copy-Item "$tempWin\uvs.exe" -Destination "$tempWin\universal_video_studio.exe" -Force
}

# Copy Rust native engine
$rustDll = "$root\core\rust\target\release\uvs_core.dll"
if (-not (Test-Path $rustDll)) {
    Write-Host ">>> Compiling Rust core release DLL..." -ForegroundColor Cyan
    Push-Location "$root\core\rust"
    cargo build --release
    Pop-Location
}
if (Test-Path $rustDll) {
    Copy-Item $rustDll -Destination $tempWin -Force
    Write-Host "[OK] Bundled uvs_core.dll into application root." -ForegroundColor Green
} else {
    Write-Host "[FAIL] uvs_core.dll could not be found or built!" -ForegroundColor Red
    exit 1
}

# Copy SBOM, README, LICENSE
if (Test-Path "$distDir\uvs_sbom.json") {
    Copy-Item "$distDir\uvs_sbom.json" -Destination $tempWin
}
if (Test-Path "$root\README.md") {
    Copy-Item "$root\README.md" -Destination $tempWin
}
if (Test-Path "$root\LICENSE") {
    Copy-Item "$root\LICENSE" -Destination $tempWin
}

# 3. Audit required components
if ((-not (Test-Path "$tempWin\uvs.exe")) -and (-not (Test-Path "$tempWin\universal_video_studio.exe"))) {
    Write-Host "[FATAL] Mandatory release executable (universal_video_studio.exe / uvs.exe) is missing!" -ForegroundColor Red
    Remove-Item -Recurse -Force $tempWin
    exit 1
}

$mandatoryFiles = @("flutter_windows.dll", "uvs_core.dll", "data")
foreach ($req in $mandatoryFiles) {
    if (-not (Test-Path "$tempWin\$req")) {
        Write-Host "[FATAL] Mandatory release component missing: $req" -ForegroundColor Red
        Remove-Item -Recurse -Force $tempWin
        exit 1
    }
}
Write-Host "[PASS] All mandatory runtime components verified." -ForegroundColor Green

# 4. Generate Manifest with File Sizes and SHA-256
Write-Host ">>> Generating MANIFEST.txt with SHA-256 checksums..." -ForegroundColor Cyan
$manifestLines = @(
    "# Universal Video Studio - Windows x64 Release Package Manifest",
    "# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')",
    "#"
)
Get-ChildItem -Recurse -File $tempWin | ForEach-Object {
    $relPath = $_.FullName.Substring($tempWin.Length + 1)
    $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash.ToLower()
    $size = $_.Length
    $manifestLines += "$hash  $size bytes  $relPath"
}
$manifestLines | Out-File -FilePath "$tempWin\MANIFEST.txt" -Encoding utf8

# 5. Compress Archive
$winDist = "$distDir\universal_video_studio_windows_x64.zip"
if (Test-Path $winDist) { Remove-Item -Force $winDist }
Write-Host ">>> Compressing package to $winDist..." -ForegroundColor Cyan
Compress-Archive -Path "$tempWin\*" -DestinationPath $winDist -Force
Remove-Item -Recurse -Force $tempWin

# 6. Validate Archive Size
$zipSize = (Get-Item $winDist).Length
Write-Host "Created: $winDist ($([math]::Round($zipSize / 1MB, 2)) MB)" -ForegroundColor Green

if ($zipSize -lt 10000000) { # Less than 10 MB is suspicious (fake archives were ~841 KB)
    Write-Host "[FATAL] Archive size is suspicious ($zipSize bytes < 10 MB). Packaging rejected!" -ForegroundColor Red
    exit 1
}

# 7. Update SHA256SUMS
$distHash = (Get-FileHash -Path $winDist -Algorithm SHA256).Hash.ToLower()
Write-Host "Archive SHA-256: $distHash" -ForegroundColor Gray

# Regenerate master SHA256SUMS for all dist items
$hashLines = @()
Get-ChildItem -Path $distDir -File | Where-Object { $_.Name -notlike "SHA256SUMS*" } | ForEach-Object {
    $fHash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash.ToLower()
    $hashLines += "$fHash  $($_.Name)"
}
$hashLines | Out-File -FilePath "$distDir\SHA256SUMS" -Encoding utf8

Write-Host "`n[CERTIFIED PASS] Windows Release Package Built & Verified Successfully." -ForegroundColor Green
