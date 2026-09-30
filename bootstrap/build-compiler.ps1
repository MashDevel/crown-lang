param(
    [Parameter(Mandatory = $true)][string]$Compiler,
    [Parameter(Mandatory = $true)][string]$Output
)

. (Join-Path $PSScriptRoot 'windows-support.ps1')
try {
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $env:CROWN_ROOT = $root
    $target = Get-CrownNativeHost
    exit (Build-CrownCompiler $root $target ([IO.Path]::GetFullPath($Compiler)) ([IO.Path]::GetFullPath($Output)))
} catch {
    [Console]::Error.WriteLine('error: ' + $_.Exception.Message)
    exit 1
}
