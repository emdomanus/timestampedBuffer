. "$PSScriptRoot/prepare.ps1"
Push-Location $packageRoot
try {
    Invoke-Tool "lune" @("--version")
    Get-CimInstance Win32_Processor | Select-Object -First 1 -ExpandProperty Name
    [Environment]::OSVersion.VersionString
    Invoke-Tool "lune" @("run", "bench/timestampedBuffer.luau")
} finally { Pop-Location }
