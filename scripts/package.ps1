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
    if ((Test-Path "$cand\universal_video_studio.exe") -or (Test-Path "$cand\uvs.exe") -or (Test-Path "$cand\Universal Video Studio.exe")) {
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
        if ((Test-Path "$cand\universal_video_studio.exe") -or (Test-Path "$cand\uvs.exe") -or (Test-Path "$cand\Universal Video Studio.exe")) {
            $winReleaseDir = $cand
            break
        }
    }
}

if (-not $winReleaseDir) {
    Write-Host "`n[FAIL / HARDWARE-REQUIRED] Flutter Windows Release executable was not found." -ForegroundColor Red
    Write-Host "Visual Studio C++ Desktop Development Workload is required to compile Windows desktop Flutter runners." -ForegroundColor Red
    Write-Host "This step compiles and packages automatically on GitHub Actions 'windows-latest' runner." -ForegroundColor Yellow
    Write-Host "Refusing to create a fake, incomplete archive." -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Found Flutter Windows Release directory: $winReleaseDir" -ForegroundColor Green

# 2. Stage complete package directory: UVS-Windows-x64-Portable
$portableDir = "$distDir\UVS-Windows-x64-Portable"
if (Test-Path $portableDir) { Remove-Item -Recurse -Force $portableDir }
New-Item -ItemType Directory -Force -Path $portableDir | Out-Null

Write-Host ">>> Staging canonical application files into $portableDir..." -ForegroundColor Cyan
Copy-Item -Recurse -Path "$winReleaseDir\*" -Destination $portableDir

# Canonicalize executable: ONE canonical user-facing executable "Universal Video Studio.exe"
$canonExe = "$portableDir\Universal Video Studio.exe"
if (Test-Path "$portableDir\universal_video_studio.exe") {
    Move-Item "$portableDir\universal_video_studio.exe" -Destination $canonExe -Force
} elseif (Test-Path "$portableDir\uvs.exe") {
    Move-Item "$portableDir\uvs.exe" -Destination $canonExe -Force
}
# Remove confusing duplicate binaries if any
if (Test-Path "$portableDir\uvs.exe") {
    Remove-Item -Force "$portableDir\uvs.exe"
}
if (Test-Path "$portableDir\universal_video_studio.exe") {
    Remove-Item -Force "$portableDir\universal_video_studio.exe"
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
    Copy-Item $rustDll -Destination $portableDir -Force
    Write-Host "[OK] Bundled uvs_core.dll into application root." -ForegroundColor Green
} else {
    Write-Host "[FAIL] uvs_core.dll could not be found or built!" -ForegroundColor Red
    exit 1
}

# Copy SBOM, README, LICENSE
if (Test-Path "$distDir\uvs_sbom.json") {
    Copy-Item "$distDir\uvs_sbom.json" -Destination $portableDir
}
if (Test-Path "$root\README.md") {
    Copy-Item "$root\README.md" -Destination $portableDir
}
if (Test-Path "$root\LICENSE") {
    Copy-Item "$root\LICENSE" -Destination $portableDir
}

# 3. Audit required components
if (-not (Test-Path $canonExe)) {
    Write-Host "[FATAL] Mandatory release executable (Universal Video Studio.exe) is missing!" -ForegroundColor Red
    Remove-Item -Recurse -Force $portableDir
    exit 1
}

$mandatoryFiles = @("flutter_windows.dll", "uvs_core.dll", "data")
foreach ($req in $mandatoryFiles) {
    if (-not (Test-Path "$portableDir\$req")) {
        Write-Host "[FATAL] Mandatory release component missing: $req" -ForegroundColor Red
        Remove-Item -Recurse -Force $portableDir
        exit 1
    }
}
Write-Host "[PASS] All mandatory runtime components verified." -ForegroundColor Green

# 4. Generate Manifest with File Sizes and SHA-256
Write-Host ">>> Generating MANIFEST.txt with SHA-256 checksums..." -ForegroundColor Cyan
$manifestLines = @(
    "# Universal Video Studio - Windows x64 Portable Release Package Manifest",
    "# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')",
    "#"
)
Get-ChildItem -Recurse -File $portableDir | ForEach-Object {
    $relPath = $_.FullName.Substring($portableDir.Length + 1)
    $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash.ToLower()
    $size = $_.Length
    $manifestLines += "$hash  $size bytes  $relPath"
}
$manifestLines | Out-File -FilePath "$portableDir\MANIFEST.txt" -Encoding utf8

# 5. Compress Archive for Release (UVS-Windows-x64-Portable.zip)
$winDist = "$distDir\UVS-Windows-x64-Portable.zip"
if (Test-Path $winDist) { Remove-Item -Force $winDist }
Write-Host ">>> Compressing package to $winDist..." -ForegroundColor Cyan
Compress-Archive -Path "$portableDir\*" -DestinationPath $winDist -Force

# Also provide universal_video_studio_windows_x64.zip alias for backwards compatibility
Copy-Item "$winDist" -Destination "$distDir\universal_video_studio_windows_x64.zip" -Force

# Retain $portableDir directory intact so GitHub Actions can upload the bundle directory directly without nested ZIPs!

# 6. Validate Archive Size
$zipSize = (Get-Item $winDist).Length
Write-Host "Created: $winDist ($([math]::Round($zipSize / 1MB, 2)) MB)" -ForegroundColor Green

if ($zipSize -lt 10000000) {
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
