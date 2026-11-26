$ErrorActionPreference='Stop'
$old=$env:LOCALAPPDATA
$temp=Join-Path $env:TEMP ('NexPreferencesTest-'+[guid]::NewGuid().ToString('N'))
try {
    $env:LOCALAPPDATA=$temp
    . (Join-Path $PSScriptRoot '../src/NexDashboard.ps1')
    $global:NexPublicSettings=Get-NexPreferences -DefaultsOnly
    if ($global:NexPublicSettings.LightMode) {throw 'Default light mode must be off'}
    $global:NexPublicSettings.Theme='Cherry Blossom'
    $global:NexPublicSettings.LightMode=$true
    Save-NexPreferences
    $global:NexPublicSettings=Get-NexPreferences
    if (-not $global:NexPublicSettings.LightMode -or $global:NexPublicSettings.Theme -ne 'Cherry Blossom') {throw 'Light mode did not persist'}
    $backup=Get-NexBackupPreferences ([pscustomobject]$global:NexPublicSettings)
    if (-not $backup.LightMode) {throw 'Light mode lost in backup'}
    $legacy=[pscustomobject]$global:NexPublicSettings.Clone()
    $legacy.PSObject.Properties.Remove('LightMode')
    if ((Get-NexBackupPreferences $legacy).LightMode) {throw 'Legacy backup default incorrect'}
    foreach ($theme in @(Get-NexThemeNames)) {
        $global:NexPublicSettings.LightMode=$false
        $dark=Get-NexPalette $theme
        $global:NexPublicSettings.LightMode=$true
        $light=Get-NexPalette $theme
        if ($light.Count -ne 6 -or $dark.Count -ne 6) {throw "Invalid palette: $theme"}
        foreach ($c in $light) {if ($c -notmatch '^[A-F0-9]{6}$') {throw "Invalid color: $c"}}
        foreach ($i in @(0,2,4)) {if ([Convert]::ToInt32($light[3].Substring($i,2),16) -lt 230) {throw "Background is not light: $theme"}}
        if ($light[3] -eq $dark[3]) {throw "No light variation: $theme"}
    }
    $defaults=Get-NexPreferences -DefaultsOnly
    if ($defaults.LightMode -or $defaults.Theme -ne 'Pink') {throw 'Factory preferences are not default'}
    Write-Host 'Light theme and default preference checks passed.'
} finally {
    $env:LOCALAPPDATA=$old
    if (Test-Path -LiteralPath $temp) {Remove-Item -LiteralPath $temp -Recurse -Force}
}
