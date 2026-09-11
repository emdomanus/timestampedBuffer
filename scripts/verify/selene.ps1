. "$PSScriptRoot/tool.ps1"
Push-Location $packageRoot
try {
    Invoke-Tool "selene" @("src", "tests", "bench")
} finally { Pop-Location }
