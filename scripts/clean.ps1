# Universal Video Studio - Clean (PowerShell)
$ErrorActionPreference = "SilentlyContinue"

$root = (Get-Item -Path "$PSScriptRoot\..").FullName
Write-Host ">>> Cleaning temporary build artifacts..." -ForegroundColor Cyan

Remove-Item -Recurse -Force "$root\core\rust\target"
Remove-Item -Recurse -Force "$root\apps\flutter_app\.dart_tool"
Remove-Item -Recurse -Force "$root\apps\flutter_app\build"
Remove-Item -Recurse -Force "$root\tests\output"
Remove-Item -Recurse -Force "$root\dist"

Write-Host ">>> Clean complete." -ForegroundColor Green
