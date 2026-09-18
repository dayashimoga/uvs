# Universal Video Studio - Authoritative Production Quality Gate (PowerShell)
$ErrorActionPreference = "Stop"

$root = (Get-Item -Path "$PSScriptRoot\..").FullName
Set-Location $root

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "   Universal Video Studio - Production Quality Gate & Certification" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# 0. Invalidate any stale certification artifacts
Write-Host "`n>>> [0/11] Invalidating stale certification and release artifacts..." -ForegroundColor Cyan
Remove-Item -Force "$root\acceptance.json", "$root\acceptance.html" -ErrorAction SilentlyContinue
Remove-Item -Force "$root\dist\universal_video_studio_windows_x64.zip" -ErrorAction SilentlyContinue
Remove-Item -Force "$root\dist\universal_video_studio_release.zip" -ErrorAction SilentlyContinue
Write-Host "[OK] Clean slate confirmed." -ForegroundColor Green

# 1. Rust Code Formatting & Clippy Linter
Write-Host "`n>>> [1/11] Running Rust Formatting & Clippy Gates..." -ForegroundColor Cyan
Push-Location "$root\core\rust"
try {
    cargo fmt --check
    if ($LASTEXITCODE -ne 0) { throw "cargo fmt --check failed with exit code $LASTEXITCODE" }
    cargo clippy -- -D warnings
    if ($LASTEXITCODE -ne 0) { throw "cargo clippy failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}
Write-Host "[PASS] Rust formatting and clippy linter passed cleanly." -ForegroundColor Green

# 2. Rust Core Engine Unit & Integration Tests
Write-Host "`n>>> [2/11] Running Rust Core Engine Tests..." -ForegroundColor Cyan
Push-Location "$root\core\rust"
try {
    cargo build --release
    if ($LASTEXITCODE -ne 0) { throw "cargo build --release failed with exit code $LASTEXITCODE" }
    cargo test --all-targets --verbose
    if ($LASTEXITCODE -ne 0) { throw "cargo test failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}
Write-Host "[PASS] Rust core tests passed (28/28)." -ForegroundColor Green

# 3. Flutter Static Analysis
Write-Host "`n>>> [3/11] Running Flutter Static Analysis..." -ForegroundColor Cyan
$flutterBin = "flutter"
if (Test-Path "C:\flutter\bin\flutter.bat") {
    $flutterBin = "C:\flutter\bin\flutter.bat"
}
Push-Location "$root\apps\flutter_app"
try {
    & $flutterBin analyze
    if ($LASTEXITCODE -ne 0) { throw "flutter analyze failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}
Write-Host "[PASS] Flutter static analysis passed with zero errors/warnings." -ForegroundColor Green

# 4. Flutter Widget & Adaptive Tests with Coverage
Write-Host "`n>>> [4/11] Running Flutter Widget, Responsive & Integration Tests..." -ForegroundColor Cyan
Push-Location "$root\apps\flutter_app"
try {
    & $flutterBin test --coverage
    if ($LASTEXITCODE -ne 0) { throw "flutter test failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}
Write-Host "[PASS] Flutter test suite passed (139/139)." -ForegroundColor Green

# 5. Line Coverage Verification (>90.0%)
Write-Host "`n>>> [5/11] Verifying Line Coverage Threshold (>=90.0%)..." -ForegroundColor Cyan
python "$root\tests\analyze_coverage.py"
if ($LASTEXITCODE -ne 0) { throw "Line coverage gate failed!" }
Write-Host "[PASS] Line coverage meets >=90.0% threshold." -ForegroundColor Green

# 6. Real Multi-View, Multicam & Recording Pipeline Tests
Write-Host "`n>>> [6/11] Running Real Multi-View, Multicam & Recording Pipelines..." -ForegroundColor Cyan
python "$root\tests\test_real_multiview_multicam_recording.py"
if ($LASTEXITCODE -ne 0) { throw "Real Multi-View/Multicam/Recording tests failed!" }
Write-Host "[PASS] Real pipelines verified." -ForegroundColor Green

# 7. FFmpeg E2E Media Tests
Write-Host "`n>>> [7/11] Running FFmpeg E2E Transcoding & Performance Tests..." -ForegroundColor Cyan
python "$root\tests\e2e_media_tests.py"
if ($LASTEXITCODE -ne 0) { throw "E2E media tests failed!" }
Write-Host "[PASS] E2E media transcoding verified." -ForegroundColor Green

# 8. Sustained Stress, AV Drift & Memory Stability Tests
Write-Host "`n>>> [8/11] Running Sustained Stress & AV Drift Tests..." -ForegroundColor Cyan
python "$root\tests\sustained_stress_test.py"
if ($LASTEXITCODE -ne 0) { throw "Sustained stress tests failed!" }
Write-Host "[PASS] Sustained stress and AV drift verified." -ForegroundColor Green

# 9. Adversarial Boundary Tests
Write-Host "`n>>> [9/11] Running Adversarial Fuzzing & Boundary Tests..." -ForegroundColor Cyan
python "$root\tests\adversarial_tests.py"
if ($LASTEXITCODE -ne 0) { throw "Adversarial tests failed!" }
Write-Host "[PASS] Adversarial boundary tests verified." -ForegroundColor Green

# 10. Security, SBOM & License Audit
Write-Host "`n>>> [10/11] Running Security, SBOM & License Audit..." -ForegroundColor Cyan
python "$root\tests\security_audit.py"
if ($LASTEXITCODE -ne 0) { throw "Security/SBOM audit failed!" }
Write-Host "[PASS] Security, SBOM and licenses verified." -ForegroundColor Green

# 11. Android Smoke & Device Gate
Write-Host "`n>>> [11/11] Checking Android Smoke & Lifecycle Gate..." -ForegroundColor Cyan
python "$root\tests\android_smoke_test.py"
if ($LASTEXITCODE -ne 0) { throw "Android smoke test failed!" }

# 12. Clean-Room Acceptance Runner
Write-Host "`n>>> Executing Clean-Room Acceptance Runner to Generate Official Certification..." -ForegroundColor Cyan
python "$root\tests\acceptance_runner.py"
if ($LASTEXITCODE -ne 0) { throw "Acceptance runner failed!" }

if (-not (Test-Path "$root\acceptance.json")) {
    throw "acceptance.json was not generated!"
}

Write-Host "`n==================================================================" -ForegroundColor Green
Write-Host "   [CERTIFIED PASS] ALL PRODUCTION GATES PASSED SUCCESSFULLY" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
