. "$PSScriptRoot/tool.ps1"

# Only rewrite script-relative require expressions in a generated test copy.
# Luau bodies and canonical contracts remain identical to shipped source.
$sourceRoot = Join-Path $packageRoot "src"
$generatedRoot = Join-Path $packageRoot ".verify/src"
$resolvedGeneratedRoot = [IO.Path]::GetFullPath($generatedRoot)
if (-not $resolvedGeneratedRoot.StartsWith($packageRoot + [IO.Path]::DirectorySeparatorChar)) {
    throw "Generated runtime must remain inside this package"
}
if (Test-Path -LiteralPath $resolvedGeneratedRoot) {
    Remove-Item -LiteralPath $resolvedGeneratedRoot -Recurse -Force
}
foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -Recurse -Filter *.luau) {
    $relative = [IO.Path]::GetRelativePath($sourceRoot, $file.FullName)
    $destination = Join-Path $generatedRoot $relative
    # Lune and luau-lsp disagree on init-relative string imports. Name the copy
    # package.luau so both resolve from the same directory.
    if ($file.Name -eq "init.luau") { $destination = Join-Path (Split-Path $destination) "package.luau" }
    $null = New-Item -ItemType Directory -Force -Path (Split-Path $destination)
    $source = [IO.File]::ReadAllText($file.FullName)
    $transformed = [regex]::Replace($source, 'require\(\s*(script(?:\.[A-Za-z_][A-Za-z0-9_]*)+)\s*\)', {
        param($match)
        $node = if ($file.Name -eq "init.luau") { $file.DirectoryName } else {
            Join-Path $file.DirectoryName $file.BaseName
        }
        foreach ($token in $match.Groups[1].Value.Split('.') | Select-Object -Skip 1) {
            $node = if ($token -eq "Parent") { Split-Path $node } else { Join-Path $node $token }
        }
        $target = if (Test-Path -LiteralPath "$node.luau") { "$node.luau" } else { Join-Path $node "init.luau" }
        if (-not (Test-Path -LiteralPath $target)) { throw "Unresolved require: $($match.Value) in $relative" }
        $import = [IO.Path]::GetRelativePath($file.DirectoryName, $target).Replace('\', '/')
        $import = $import -replace '(^|/)init\.luau$', '${1}package.luau'
        return 'require("./' + $import.Substring(0, $import.Length - 5) + '")'
    })
    [IO.File]::WriteAllText($destination, $transformed)
}
