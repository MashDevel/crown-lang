. (Join-Path $PSScriptRoot 'windows-assets.ps1')
try {
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    Get-CrownBootstrapAssets $root (Get-CrownNativeHost)
} catch {
    [Console]::Error.WriteLine('error: ' + $_.Exception.Message)
    exit 1
}
