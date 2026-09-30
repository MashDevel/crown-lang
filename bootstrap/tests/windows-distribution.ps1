param([Parameter(Mandatory = $true)][string]$Assets)

. (Join-Path $PSScriptRoot '../windows-assets.ps1')
$directory = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
$previousAssets = $env:CROWN_BOOTSTRAP_ASSETS
try {
    $target = Get-CrownNativeHost
    $assetsPath = [IO.Path]::GetFullPath($Assets)
    $null = [IO.Directory]::CreateDirectory((Join-Path $directory 'bootstrap/locks'))
    [IO.File]::Copy((Join-Path $assetsPath "crown-bootstrap-$target.lock.json"), (Join-Path $directory "bootstrap/locks/$target.json"))
    [IO.File]::Copy((Join-Path $PSScriptRoot '../repository'), (Join-Path $directory 'bootstrap/repository'))
    [IO.File]::WriteAllText((Join-Path $directory 'bootstrap/seed-release'), 'packaged-fixture')
    $env:CROWN_BOOTSTRAP_ASSETS = $assetsPath
    $compiler = Get-CrownBootstrapAssets $directory $target
    & $compiler --version
    if ($LASTEXITCODE -ne 0) { throw 'downloaded compiler failed to execute' }
    $env:CROWN_BOOTSTRAP_ASSETS = Join-Path $directory 'unavailable'
    if ((Get-CrownBootstrapAssets $directory $target) -cne $compiler) { throw 'download cache was not reused' }
} finally {
    $env:CROWN_BOOTSTRAP_ASSETS = $previousAssets
    if (Test-Path -LiteralPath $directory) { Remove-Item -LiteralPath $directory -Recurse -Force }
}
