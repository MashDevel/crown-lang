param([Parameter(Mandatory = $true)][string]$Compiler)

. (Join-Path $PSScriptRoot '../windows-support.ps1')
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$directory = Join-Path $root 'target/windows/launcher arguments'
$null = [IO.Directory]::CreateDirectory($directory)
$program = Join-Path $directory 'arguments.exe'
$source = Join-Path $root 'components/toolchain/tests/fixtures/launcher_arguments.cwn'
& $Compiler build $source --toolchain-library toolchain -o $program
if ($LASTEXITCODE -ne 0) { throw 'launcher fixture failed to build' }
$arguments = @('', ('hello ' + [char]::ConvertFromUtf32(128512) + '!'), 'spaces "quotes"', 'tail\', ('x' * 70000))
if ((Invoke-Crown $program $arguments $directory) -ne 37) {
    throw 'launcher failed to preserve native arguments or exit status'
}
$failed = $false
try { $null = Invoke-Crown (Join-Path $directory 'missing.exe') @() $directory } catch { $failed = $true }
if (-not $failed) { throw 'launcher accepted a missing compiler' }
if (@(Get-ChildItem -LiteralPath $directory -Filter '*.json').Count -ne 0) {
    throw 'launcher leaked a response file'
}
