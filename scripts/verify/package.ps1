. "$PSScriptRoot/tool.ps1"
Push-Location $packageRoot
try {
    $null = New-Item -ItemType Directory -Force -Path ".verify"
    Invoke-Tool "rojo" @("sourcemap", "default.project.json", "--output", ".verify/sourcemap.json")
    function Test-UniqueChildren($Node) {
        $names = @{}
        foreach ($child in $Node.children) {
            if ($names.ContainsKey($child.name)) { throw "Duplicate Rojo child: $($child.name)" }
            $names[$child.name] = $true
            Test-UniqueChildren $child
        }
    }
    Test-UniqueChildren (Get-Content -Raw .verify/sourcemap.json | ConvertFrom-Json)
    Invoke-Tool "rojo" @("build", "default.project.json", "--output", ".verify/timestampedBuffer.rbxm")
    Invoke-Tool "pesde" @("install")
    # Pesde can report a workspace-root failure with exit 0. Require a fresh archive.
    if (Test-Path -LiteralPath "package.tar.gz") { Remove-Item -LiteralPath "package.tar.gz" }
    Invoke-Tool "pesde" @("publish", "--dry-run", "--yes")
    if (-not (Test-Path -LiteralPath "package.tar.gz")) { throw "Pesde did not produce an archive" }
    $archiveFiles = @(& tar -tzf package.tar.gz)
    if ($LASTEXITCODE -ne 0) { throw "Unable to inspect package archive" }
    $expected = @("pesde.toml", "README.md") + @(
        Get-ChildItem -LiteralPath "src" -File -Recurse | ForEach-Object {
            [IO.Path]::GetRelativePath($packageRoot, $_.FullName).Replace('\', '/')
        }
    )
    $difference = @(Compare-Object ($expected | Sort-Object) ($archiveFiles | Sort-Object))
    if ($difference.Count -ne 0) { $difference; throw "Packaged files do not match source/README" }
    $archiveFiles | Set-Content .verify/package-files.txt
    Write-Output "Verified $($archiveFiles.Count) packaged files and unique Rojo sibling names. No publication performed."
} finally { Pop-Location }
