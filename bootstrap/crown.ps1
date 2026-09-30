param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Forwarded = @())

. (Join-Path $PSScriptRoot 'windows-support.ps1')

function Start-CrownCheckout {
    param([string]$Root, [string]$Directory, [string]$Target, [string]$Compiler)
    $current = Join-Path $Directory 'current.exe'
    $status = Build-CrownCompiler $Root $Target $Compiler $current
    if ($status -ne 0) { return $status }
    $arguments = @($Forwarded)
    if ($arguments.Count -eq 0 -or $arguments[0] -ne 'bootstrap') {
        $arguments = @('_launch') + $arguments
    }
    return Invoke-Crown $current $arguments $Directory
}

function Start-CrownBootstrap {
    param([string]$Root, [string]$Target)
    $seed = Join-Path $Root "bootstrap/$Target/compiler.s"
    try {
        $digest = Read-CrownDigest (Join-Path $Root "bootstrap/$Target/manifest.json") 'assembly_sha256'
        if ((Get-CrownDigest $seed) -cne $digest) { throw 'checksum mismatch' }
    } catch {
        throw ('bootstrap assembly checksum mismatch or missing seed (' + $Target + '): ' + $_.Exception.Message)
    }
    $directory = if ($env:CROWN_BOOTSTRAP_DIR) { $env:CROWN_BOOTSTRAP_DIR } else { Join-Path $Root 'target/bootstrap' }
    $directory = [IO.Path]::GetFullPath($directory)
    $null = [IO.Directory]::CreateDirectory($directory)
    foreach ($compiler in @((Join-Path $directory 'crown.exe'), (Join-Path $Root 'target/bootstrap/crown.exe'))) {
        if (Test-CrownCompiler $compiler $digest) {
            return Start-CrownCheckout $Root $directory $Target $compiler
        }
    }
    $temporary = Join-Path $directory ([IO.Path]::GetRandomFileName())
    $null = [IO.Directory]::CreateDirectory($temporary)
    try {
        $compiler = Join-Path $temporary 'compiler.exe'
        Build-CrownSeed $seed $compiler
        $output = Join-Path $directory 'seed.exe'
        Move-Item -LiteralPath $compiler -Destination $output -Force
    } finally {
        Remove-Item -LiteralPath $temporary -Recurse -Force
    }
    return Start-CrownCheckout $Root $directory $Target $output
}

try {
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $env:CROWN_ROOT = $root
    $target = Get-CrownNativeHost
    exit (Start-CrownBootstrap $root $target)
} catch {
    [Console]::Error.WriteLine('error: ' + $_.Exception.Message)
    exit 1
}
