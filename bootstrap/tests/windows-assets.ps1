. (Join-Path $PSScriptRoot '../windows-assets.ps1')
. (Join-Path $PSScriptRoot 'windows-assert.ps1')

function Write-SeedArchive {
    param([string]$Source, [string]$Destination)
    $outputFile = [IO.File]::Create($Destination)
    $gzip = [IO.Compression.GZipStream]::new($outputFile, [IO.Compression.CompressionMode]::Compress)
    try {
        $bytes = [IO.File]::ReadAllBytes($Source)
        $gzip.Write($bytes, 0, $bytes.Length)
    } finally {
        $gzip.Dispose()
        $outputFile.Dispose()
    }
}

function New-AssetFixture {
    param([string]$Directory, [string]$Target)
    $root = Join-Path $Directory $Target
    $assets = Join-Path $root 'assets'
    $null = [IO.Directory]::CreateDirectory((Join-Path $root 'bootstrap/locks'))
    $null = [IO.Directory]::CreateDirectory($assets)
    [IO.File]::WriteAllText((Join-Path $root 'bootstrap/seed-release'), 'fixture-release')
    [IO.File]::WriteAllText((Join-Path $root 'bootstrap/repository'), 'fixture/repository')
    $assembly = Join-Path $root 'compiler.s'
    [IO.File]::WriteAllText($assembly, 'fixture assembly')
    $archive = Join-Path $assets "crown-bootstrap-$Target.s.gz"
    Write-SeedArchive $assembly $archive
    $manifest = Join-Path $assets "crown-bootstrap-$Target.json"
    [IO.File]::WriteAllText($manifest, ('{"assembly_sha256":"' + (Get-CrownDigest $assembly) + '"}'))
    $package = Join-Path $root "crown-$Target"
    $null = [IO.Directory]::CreateDirectory($package)
    $compiler = Join-Path $package 'crown.exe'
    [IO.File]::WriteAllText($compiler, 'fixture executable')
    $distribution = Join-Path $assets "crown-$Target.tar.gz"
    & tar.exe -czf $distribution -C $root "crown-$Target"
    if ($LASTEXITCODE -ne 0) { throw 'asset fixture archive failed' }
    $record = @{
        archive_sha256 = Get-CrownDigest $archive
        manifest_sha256 = Get-CrownDigest $manifest
        assembly_sha256 = Get-CrownDigest $assembly
        compiler_sha256 = Get-CrownDigest $compiler
        compiler_archive_sha256 = Get-CrownDigest $distribution
    }
    [IO.File]::WriteAllText((Join-Path $root "bootstrap/locks/$Target.json"), ($record | ConvertTo-Json -Compress))
    return $root
}

function Test-AssetInstallation {
    param([string]$Root, [string]$Target)
    $env:CROWN_BOOTSTRAP_ASSETS = Join-Path $Root 'assets'
    $settings = Get-CrownAssetSettings $Root $Target
    $binary = Get-CrownBootstrapAssets $Root $Target
    Assert-CrownAsset $settings $binary 'compiler_sha256'
    $env:CROWN_BOOTSTRAP_ASSETS = Join-Path $Root 'unavailable'
    if ((Get-CrownBootstrapAssets $Root $Target) -cne $binary) { throw 'cache path changed' }
    [IO.File]::AppendAllText($binary, 'corrupt')
    Assert-Rejected { Get-CrownBootstrapAssets $Root $Target }
    Remove-Item -LiteralPath (Split-Path -Parent $binary) -Recurse -Force
    $env:CROWN_BOOTSTRAP_ASSETS = Join-Path $Root 'assets'
    $lock = (Split-Path -Parent $binary) + '.installing'
    [IO.File]::WriteAllText($lock, 'busy')
    Assert-Rejected { Get-CrownBootstrapAssets $Root $Target }
    if (Test-Path -LiteralPath $binary) { throw 'busy destination was installed' }
    Remove-Item -LiteralPath $lock
    $null = Get-CrownBootstrapAssets $Root $Target
    [IO.File]::AppendAllText((Join-Path $Root "bootstrap/$Target/compiler.s"), 'corrupt')
    Assert-Rejected { Get-CrownBootstrapAssets $Root $Target }
}

function Test-AssetFailures {
    param([string]$Root, [string]$Target)
    $env:CROWN_BOOTSTRAP_ASSETS = Join-Path $Root 'assets'
    $archive = Join-Path $env:CROWN_BOOTSTRAP_ASSETS "crown-bootstrap-$Target.s.gz"
    [IO.File]::AppendAllText($archive, 'corrupt')
    Assert-Rejected { Get-CrownBootstrapAssets $Root $Target }
    if (Test-Path -LiteralPath (Join-Path $Root "bootstrap/$Target")) { throw 'corrupt seed was installed' }
    Assert-Rejected { Get-CrownAssetSettings $Root 'unsupported' }
    [IO.File]::WriteAllText((Join-Path $Root 'bootstrap/seed-release'), '../invalid')
    Assert-Rejected { Get-CrownAssetSettings $Root $Target }
    [IO.File]::WriteAllText((Join-Path $Root 'bootstrap/seed-release'), 'valid')
    [IO.File]::WriteAllText((Join-Path $Root 'bootstrap/repository'), 'owner/repo/extra')
    Assert-Rejected { Get-CrownAssetSettings $Root $Target }
    if (@(Get-ChildItem -LiteralPath (Join-Path $Root 'bootstrap') -Filter 'download-*').Count -ne 0) {
        throw 'failed download left staging files'
    }
}

$directory = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
$previousAssets = $env:CROWN_BOOTSTRAP_ASSETS
$previousRepository = $env:CROWN_BOOTSTRAP_REPOSITORY
try {
    $env:CROWN_BOOTSTRAP_REPOSITORY = $null
    foreach ($target in @('x86_64-windows', 'arm64-windows')) {
        $root = New-AssetFixture (Join-Path $directory 'normal') $target
        Test-AssetInstallation $root $target
        $root = New-AssetFixture (Join-Path $directory 'failure') $target
        Test-AssetFailures $root $target
    }
} finally {
    $env:CROWN_BOOTSTRAP_ASSETS = $previousAssets
    $env:CROWN_BOOTSTRAP_REPOSITORY = $previousRepository
    if (Test-Path -LiteralPath $directory) { Remove-Item -LiteralPath $directory -Recurse -Force }
}
