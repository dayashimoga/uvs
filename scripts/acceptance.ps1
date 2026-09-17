# Universal Video Studio - Acceptance (PowerShell)
$ErrorActionPreference = "Stop"

$root = (Get-Item -Path "$PSScriptRoot\..").FullName
python "$root\tests\acceptance_runner.py"
