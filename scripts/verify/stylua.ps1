. "$PSScriptRoot/tool.ps1"
Push-Location $packageRoot
try {
    Invoke-Tool "stylua" @("--check", "src", "tests", "bench")
} finally { Pop-Location }
