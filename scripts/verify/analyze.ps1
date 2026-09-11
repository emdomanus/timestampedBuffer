. "$PSScriptRoot/prepare.ps1"
Push-Location $packageRoot
try {
    Invoke-Tool "luau-lsp" @("analyze", "--platform=standard", ".verify/src", "tests", "bench")
} finally { Pop-Location }
