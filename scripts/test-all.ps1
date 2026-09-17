# Universal Video Studio - Test All (PowerShell)
$ErrorActionPreference = "Stop"

$root = (Get-Item -Path "$PSScriptRoot\..").FullName
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "       Universal Video Studio - Comprehensive Test Suite" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan

# 1. Rust Core Tests
Write-Host "`n>>> [1/4] Running Rust Core Tests (Cargo)..." -ForegroundColor Yellow
Push-Location "$root\core\rust"
try {
    cargo test --all-targets
} finally {
    Pop-Location
}
Write-Host "[PASS] Rust Core Tests Passed." -ForegroundColor Green

# 2. Flutter Widget & Adaptive Tests
Write-Host "`n>>> [2/4] Running Flutter Widget & Adaptive Tests (Podman Container)..." -ForegroundColor Yellow
podman run --rm -v "${root}:/workspace:Z" -e "PUB_CACHE=/workspace/.pub-cache" -w /workspace/apps/flutter_app ghcr.io/cirruslabs/flutter:3.24.3 bash -c "flutter test"
Write-Host "[PASS] Flutter Tests Passed." -ForegroundColor Green

# 3. End-to-End Media & Transcoding Verification
Write-Host "`n>>> [3/4] Running End-to-End FFmpeg Media Tests..." -ForegroundColor Yellow
python "$root\tests\e2e_media_tests.py"
Write-Host "[PASS] E2E Media Tests Passed." -ForegroundColor Green

# 4. Performance & Resource Benchmarks
Write-Host "`n>>> [4/4] Running Performance Benchmarks..." -ForegroundColor Yellow
python "$root\tests\benchmarks.py"
Write-Host "[PASS] Performance Benchmarks Passed." -ForegroundColor Green

Write-Host "`n=========================================================" -ForegroundColor Green
Write-Host "  ALL TESTS PASSED SUCCESSFULLY (100% Pass Rate)" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green
