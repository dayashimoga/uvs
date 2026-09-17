# Universal Video Studio - Benchmark (PowerShell)
$ErrorActionPreference = "Stop"

$root = (Get-Item -Path "$PSScriptRoot\..").FullName
python "$root\tests\benchmarks.py"
