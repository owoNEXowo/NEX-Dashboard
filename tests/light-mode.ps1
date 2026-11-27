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
    if ((Mix-NexColor '000000' 'FFFFFF' 0.25) -ne '404040') {throw 'Fractional RGB blending is broken'}
    if ((Mix-NexColor '000000' 'FFFFFF' 0.75) -ne 'BFBFBF') {throw 'Fractional RGB blending is broken'}
    function Luminance([string]$hex) {
        $v=foreach($i in @(0,2,4)) {
            $c=[Convert]::ToInt32($hex.Substring($i,2),16)/255.0
            if ($c -le 0.04045) {$c/12.92} else {[Math]::Pow(($c+0.055)/1.055,2.4)}
        }
        0.2126*$v[0]+0.7152*$v[1]+0.0722*$v[2]
    }
    $accents=@{};$backgrounds=@{}
    foreach ($theme in @(Get-NexThemeNames)) {
        $global:NexPublicSettings.LightMode=$false
        $dark=Get-NexPalette $theme
        $global:NexPublicSettings.LightMode=$true
        $light=Get-NexPalette $theme
        if ($light.Count -ne 6 -or $dark.Count -ne 6) {throw "Invalid palette: $theme"}
        foreach ($c in $light) {if ($c -notmatch '^[A-F0-9]{6}$') {throw "Invalid color: $c"}}
        foreach ($i in @(0,2,4)) {if ([Convert]::ToInt32($light[3].Substring($i,2),16) -lt 200) {throw "Background is not light: $theme"}}
        $accents[$light[0]]=$true;$backgrounds[$light[3]]=$true
        foreach ($index in @(0,1,4,5)) {
            $contrast=((Luminance $light[3])+0.05)/((Luminance $light[$index])+0.05)
            if ($contrast -lt 4.5) {throw "Unreadable light text: $theme / $index / $contrast"}
        }
        if ($light[3] -eq $dark[3]) {throw "No light variation: $theme"}
    }
    if ((Get-NexLightCanvas 'F5C2E7') -ne 'FFC9F0') {throw 'Sakura tint missing'}
    if ((Get-NexLightCanvas 'A6E3A1') -ne 'CDFFC9') {throw 'Mint tint missing'}
    if ($accents.Count -lt 12 -or $backgrounds.Count -lt 12) {throw 'Light themes collapsed into identical colors'}
    $defaults=Get-NexPreferences -DefaultsOnly
    if ($defaults.LightMode -or $defaults.Theme -ne 'Pink') {throw 'Factory preferences are not default'}
    Write-Host 'Light theme and default preference checks passed.'
} finally {
    $env:LOCALAPPDATA=$old
    if (Test-Path -LiteralPath $temp) {Remove-Item -LiteralPath $temp -Recurse -Force}
}
