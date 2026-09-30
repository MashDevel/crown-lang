param([Parameter(Mandatory = $true)][string]$Expected)

. (Join-Path $PSScriptRoot '../windows-support.ps1')

$cases = @(
    @('Win32NT', '9', 'x86_64-windows'),
    @('Win32NT', '12', 'arm64-windows')
)
foreach ($case in $cases) {
    if ((Get-CrownHost $case[0] $case[1]) -cne $case[2]) {
        throw 'Windows bootstrap selected the wrong host'
    }
}
foreach ($case in @(@('Win32NT', '0'), @('Win32NT', '5'), @('Unix', '9'), @('', ''))) {
    $rejected = $false
    try { $null = Get-CrownHost $case[0] $case[1] } catch { $rejected = $true }
    if (-not $rejected) { throw 'Windows bootstrap accepted an unsupported host' }
}

if ((Get-CrownNativeHost) -cne $Expected) {
    throw 'Windows bootstrap confused process emulation with the native architecture'
}
