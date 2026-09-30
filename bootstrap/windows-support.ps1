Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CrownHost {
    param([string]$System, [string]$Architecture)
    if ($System -ne 'Win32NT') {
        throw 'Crown requires a 64-bit ARM or x86 Windows host'
    }
    switch ($Architecture) {
        '9' { return 'x86_64-windows' }
        '12' { return 'arm64-windows' }
        default { throw 'Crown requires a 64-bit ARM or x86 Windows host' }
    }
}

function Get-CrownNativeHost {
    $system = [Environment]::OSVersion.Platform.ToString()
    $architecture = Get-CimInstance -ClassName Win32_Processor | Select-Object -ExpandProperty Architecture -Unique
    return Get-CrownHost $system ([string]$architecture)
}

function Get-CrownDigest {
    param([string]$Path)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    $stream = $null
    try {
        $stream = [IO.File]::OpenRead($Path)
        $bytes = $algorithm.ComputeHash($stream)
        return [BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant()
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
        $algorithm.Dispose()
    }
}

function Read-CrownDigest {
    param([string]$Path, [string]$Field)
    $record = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    $property = $record.PSObject.Properties[$Field]
    if ($null -eq $property -or $property.Value -isnot [string] -or $property.Value -cnotmatch '^[a-f0-9]{64}$') {
        throw ('invalid bootstrap digest metadata: ' + $Field)
    }
    return $property.Value
}

function Test-CrownCompiler {
    param([string]$Compiler, [string]$SeedDigest)
    try {
        $record = "$Compiler.crown-build"
        $null = Read-CrownDigest $record 'input'
        $output = Read-CrownDigest $record 'output'
        $seed = Read-CrownDigest $record 'seed'
        return $seed -ceq $SeedDigest -and (Get-CrownDigest $Compiler) -ceq $output
    } catch {
        return $false
    }
}

function Invoke-Crown {
    param([string]$Compiler, [string[]]$Arguments, [string]$Directory)
    $response = Join-Path $Directory ([IO.Path]::GetRandomFileName() + '.json')
    $process = $null
    try {
        $json = ConvertTo-Json -InputObject @($Arguments) -Compress
        [IO.File]::WriteAllText($response, $json, [Text.UTF8Encoding]::new($false))
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = $Compiler
        $start.Arguments = '_arguments "' + $response + '"'
        $start.UseShellExecute = $false
        $process = [Diagnostics.Process]::Start($start)
        $process.WaitForExit()
        return $process.ExitCode
    } finally {
        if ($null -ne $process) {
            if (-not $process.HasExited) { $process.Kill() }
            $process.Dispose()
        }
        if (Test-Path -LiteralPath $response) { Remove-Item -LiteralPath $response }
    }
}

function Build-CrownCompiler {
    param([string]$Root, [string]$Target, [string]$Compiler, [string]$Output)
    $directory = Split-Path -Parent ([IO.Path]::GetFullPath($Output))
    $null = [IO.Directory]::CreateDirectory($directory)
    $arguments = @('build', (Join-Path $Root 'components/compiler'), '--target', $Target, '-o', $Output)
    return Invoke-Crown $Compiler $arguments $directory
}

function Get-CrownLinkFlags {
    param([string]$Seed)
    $path = Join-Path (Split-Path -Parent $Seed) 'manifest.json'
    $record = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $property = $record.PSObject.Properties['link_arguments']
    if ($null -eq $property -or $property.Value -isnot [array] -or $property.Value.Count -eq 0) {
        throw 'invalid bootstrap link arguments'
    }
    foreach ($argument in $property.Value) {
        if ($argument -isnot [string] -or -not $argument.StartsWith('-') -or $argument.Contains([char]0)) {
            throw 'invalid bootstrap link argument'
        }
    }
    return $property.Value
}

function Build-CrownSeed {
    param([string]$Seed, [string]$Output)
    $driver = if ($env:CC) { $env:CC } else { 'clang' }
    $flags = Get-CrownLinkFlags $Seed
    & $driver $Seed @flags '-o' $Output
    if ($LASTEXITCODE -ne 0) { throw 'could not assemble Crown bootstrap seed' }
}
