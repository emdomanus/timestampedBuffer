. "$PSScriptRoot/prepare.ps1"
Push-Location $packageRoot
try {
    Invoke-Tool "lune" @("run", "tests/lune/timestampedBuffer.spec.luau")
} finally { Pop-Location }
