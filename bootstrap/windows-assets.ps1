. (Join-Path $PSScriptRoot 'windows-support.ps1')

function Get-CrownAssetSettings {
    param([string]$Root, [string]$Target)
    if ($Target -notin @('x86_64-windows', 'arm64-windows')) { throw 'unsupported bootstrap host' }
    $release = [IO.File]::ReadAllText((Join-Path $Root 'bootstrap/seed-release')).Trim()
    if ($release -cnotmatch '^[a-zA-Z0-9._-]+$') { throw 'invalid bootstrap release tag' }
    $repository = $env:CROWN_BOOTSTRAP_REPOSITORY
    if (-not $repository) { $repository = [IO.File]::ReadAllText((Join-Path $Root 'bootstrap/repository')).Trim() }
    if ($repository -cnotmatch '^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$') { throw 'invalid GitHub repository' }
    return @{
        Root = $Root; Target = $Target; Release = $release; Repository = $repository
        Lock = (Join-Path $Root "bootstrap/locks/$Target.json")
    }
}

function Assert-CrownAsset {
    param([hashtable]$Settings, [string]$Path, [string]$Field)
    $expected = Read-CrownDigest $Settings.Lock $Field
    if ((Get-CrownDigest $Path) -cne $expected) { throw "bootstrap checksum mismatch: $Path" }
}

function Get-CrownAsset {
    param([hashtable]$Settings, [string]$Name, [string]$Output)
    if ($env:CROWN_BOOTSTRAP_ASSETS) {
        [IO.File]::Copy((Join-Path $env:CROWN_BOOTSTRAP_ASSETS $Name), $Output)
    } elseif ($env:GH_TOKEN) {
        & gh release download $Settings.Release --repo $Settings.Repository --pattern $Name --output $Output
        if ($LASTEXITCODE -ne 0) { throw "bootstrap download failed: $Name" }
    } else {
        $url = "https://github.com/$($Settings.Repository)/releases/download/$($Settings.Release)/$Name"
        & curl.exe --fail --location --retry 3 --connect-timeout 20 --max-time 300 --proto '=https' --proto-redir '=https' --output $Output $url
        if ($LASTEXITCODE -ne 0) { throw "bootstrap download failed: $Name" }
    }
}

function Expand-CrownSeed {
    param([string]$Archive, [string]$Output)
    $inputFile = [IO.File]::OpenRead($Archive)
    $outputFile = $null
    $gzip = $null
    try {
        $outputFile = [IO.File]::Create($Output)
        $gzip = [IO.Compression.GZipStream]::new($inputFile, [IO.Compression.CompressionMode]::Decompress)
        $gzip.CopyTo($outputFile)
    } finally {
        if ($null -ne $gzip) { $gzip.Dispose() }
        if ($null -ne $outputFile) { $outputFile.Dispose() }
        $inputFile.Dispose()
    }
}

function Install-CrownAssetDirectory {
    param([string]$Source, [string]$Destination)
    $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $Destination))
    $lockPath = "$Destination.installing"
    $lock = [IO.File]::Open($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        [IO.Directory]::Move($Source, $Destination)
    } finally {
        $lock.Dispose()
        [IO.File]::Delete($lockPath)
    }
}

function Install-CrownSeed {
    param([hashtable]$Settings, [string]$Stage)
    $destination = Join-Path $Settings.Root "bootstrap/$($Settings.Target)"
    if (Test-Path -LiteralPath $destination) {
        Assert-CrownAsset $Settings (Join-Path $destination 'manifest.json') 'manifest_sha256'
        Assert-CrownAsset $Settings (Join-Path $destination 'compiler.s') 'assembly_sha256'
        return
    }
    $name = "crown-bootstrap-$($Settings.Target)"
    $archive = Join-Path $Stage "$name.s.gz"
    $seed = Join-Path $Stage 'seed'
    $null = [IO.Directory]::CreateDirectory($seed)
    Get-CrownAsset $Settings "$name.s.gz" $archive
    Assert-CrownAsset $Settings $archive 'archive_sha256'
    $manifest = Join-Path $seed 'manifest.json'
    Get-CrownAsset $Settings "$name.json" $manifest
    Assert-CrownAsset $Settings $manifest 'manifest_sha256'
    $assembly = Join-Path $seed 'compiler.s'
    Expand-CrownSeed $archive $assembly
    Assert-CrownAsset $Settings $assembly 'assembly_sha256'
    Install-CrownAssetDirectory $seed $destination
}

function Install-CrownBinary {
    param([hashtable]$Settings, [string]$Stage)
    $destination = Join-Path $Settings.Root "target/bootstrap-release/$($Settings.Release)/$($Settings.Target)"
    $compiler = Join-Path $destination 'crown.exe'
    if (Test-Path -LiteralPath $destination) {
        Assert-CrownAsset $Settings $compiler 'compiler_sha256'
        return $compiler
    }
    $name = "crown-$($Settings.Target)"
    $archive = Join-Path $Stage "$name.tar.gz"
    Get-CrownAsset $Settings "$name.tar.gz" $archive
    Assert-CrownAsset $Settings $archive 'compiler_archive_sha256'
    & tar.exe -xzf $archive -C $Stage "$name/crown.exe"
    if ($LASTEXITCODE -ne 0) { throw 'could not extract bootstrap compiler' }
    $directory = Join-Path $Stage $name
    Assert-CrownAsset $Settings (Join-Path $directory 'crown.exe') 'compiler_sha256'
    Install-CrownAssetDirectory $directory $destination
    return $compiler
}

function Get-CrownBootstrapAssets {
    param([string]$Root, [string]$Target)
    $settings = Get-CrownAssetSettings $Root $Target
    $stage = Join-Path $Root ('bootstrap/download-' + [IO.Path]::GetRandomFileName())
    $null = [IO.Directory]::CreateDirectory($stage)
    try {
        Install-CrownSeed $settings $stage
        return Install-CrownBinary $settings $stage
    } finally {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}
