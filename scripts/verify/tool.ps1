# Dot-sourced by package checks. Always use the project's Rokit shims.
$ErrorActionPreference = "Stop"
$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../.."))
$rokitBin = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".rokit/bin"
$env:PATH = "$rokitBin;$env:PATH"

function Invoke-Tool([string]$Name, [string[]]$ToolArgs) {
    $binary = Join-Path $rokitBin "$Name.exe"
    if (-not (Test-Path -LiteralPath $binary)) { throw "Run rokit install: missing $binary" }
    & $binary @ToolArgs
    if ($LASTEXITCODE -ne 0) { throw "$Name exited $LASTEXITCODE" }
}
