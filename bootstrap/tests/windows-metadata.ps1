. (Join-Path $PSScriptRoot '../windows-support.ps1')

. (Join-Path $PSScriptRoot 'windows-assert.ps1')

$directory = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
$null = [IO.Directory]::CreateDirectory($directory)
try {
    $compiler = Join-Path $directory 'compiler.exe'
    $record = "$compiler.crown-build"
    $digest = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
    [IO.File]::WriteAllText($compiler, 'abc', [Text.UTF8Encoding]::new($false))
    if ((Get-CrownDigest $compiler) -cne $digest) { throw 'bootstrap SHA-256 mismatch' }
    Assert-Rejected { Get-CrownDigest (Join-Path $directory 'missing.exe') }
    $empty = Join-Path $directory 'empty.exe'
    [IO.File]::WriteAllBytes($empty, [byte[]]@())
    if ((Get-CrownDigest $empty) -cne 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855') {
        throw 'empty bootstrap SHA-256 mismatch'
    }
    $valid = @{ input = $digest; output = $digest; seed = $digest }
    [IO.File]::WriteAllText($record, ($valid | ConvertTo-Json -Compress))
    foreach ($field in @('input', 'output', 'seed')) {
        if ((Read-CrownDigest $record $field) -cne $digest) { throw 'valid digest metadata was changed' }
    }
    if (-not (Test-CrownCompiler $compiler $digest)) { throw 'valid bootstrap cache was rejected' }
    foreach ($invalid in @('{}', 'invalid json', '{"input":false}', '{"input":"short"}')) {
        [IO.File]::WriteAllText($record, $invalid)
        Assert-Rejected { Read-CrownDigest $record 'input' }
        if (Test-CrownCompiler $compiler $digest) { throw 'invalid cache was trusted' }
    }
    [IO.File]::WriteAllText($record, ($valid | ConvertTo-Json -Compress))
    [IO.File]::WriteAllText($compiler, 'changed')
    if (Test-CrownCompiler $compiler $digest) { throw 'corrupt cache was trusted' }
    Remove-Item -LiteralPath $record
    Assert-Rejected { Read-CrownDigest $record 'input' }
} finally {
    Remove-Item -LiteralPath $directory -Recurse -Force
}
