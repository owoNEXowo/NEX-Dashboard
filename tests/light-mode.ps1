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
    # Exercise native theme writes in an isolated settings file, preserving opacity.
    $fixture=Join-Path $temp 'terminal-test.json'
    $fixtureData=@{theme='dark';themes=@(@{name='User Theme';window=@{applicationTheme='dark'}});profiles=@{defaults=@{opacity=70;useAcrylic=$true};list=@(@{name='Test shell';commandline='powershell.exe';tabColor='#FFFFFF';opacity=60;useAcrylic=$false})}}
    [IO.File]::WriteAllText($fixture,($fixtureData | ConvertTo-Json -Depth 20))
    $global:NexPublicSettings.Theme='Mint';$global:NexPublicSettings.LightMode=$true
    $null=Sync-NexTerminalAppearance (Get-NexSharedPaletteChanges) (Get-NexSharedScheme) $fixture
    $obj=ParseConfig ([IO.File]::ReadAllText($fixture))
    $native=@($obj.themes | Where-Object name -eq 'NEX Window')[0]
    if ($obj.theme -ne 'NEX Window' -or $native.window.applicationTheme -ne 'light' -or $native.window.useMica) {throw 'Native light chrome not applied'}
    if ($native.tab.background -eq $native.tabRow.background) {throw 'No active tab distinction'}
    if ($obj.profiles.defaults.opacity -ne 70 -or -not $obj.profiles.defaults.useAcrylic -or $obj.profiles.list[0].opacity -ne 60 -or $obj.profiles.list[0].useAcrylic) {throw 'Theme changed opacity settings'}
    if ($obj.profiles.list[0].PSObject.Properties['tabColor'] -or $obj.profiles.list[0].commandline -ne 'powershell.exe' -or @($obj.themes | Where-Object name -eq 'User Theme').Count -ne 1) {throw 'Profile/theme preservation failure'}
    $null=Sync-NexTerminalAppearance @{opacity=50;useAcrylic=$false} $null $fixture
    $obj=ParseConfig ([IO.File]::ReadAllText($fixture))
    if ($obj.profiles.defaults.opacity -ne 50 -or $obj.profiles.defaults.useAcrylic -or $obj.theme -ne 'NEX Window') {throw 'Native transparency update failed'}
    $global:NexPublicSettings.LightMode=$false
    $null=Sync-NexTerminalAppearance (Get-NexSharedPaletteChanges) (Get-NexSharedScheme) $fixture
    $obj=ParseConfig ([IO.File]::ReadAllText($fixture))
    $native=@($obj.themes | Where-Object name -eq 'NEX Window')[0]
    if ($native.window.applicationTheme -ne 'dark' -or $obj.profiles.defaults.opacity -ne 50) {throw 'Native dark chrome not restored'}
    # Exercise SFC decoding without running a real system scan.
    $ast=(Get-Command Invoke-NexDiagnosticStep -CommandType Function).ScriptBlock.Ast
    $decoder=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'DecodeSfcOutput'},$true)
    if (-not $decoder) {throw 'SFC decoder missing'}
    . ([scriptblock]::Create($decoder.Extent.Text))
    $sample='Защита ресурсов Windows не обнаружила нарушений целостности.'
    $utf16=[Text.Encoding]::Unicode.GetBytes($sample)
    $bom=[byte[]](@(255,254)+$utf16)
    if ((DecodeSfcOutput $utf16) -cne $sample -or (DecodeSfcOutput $bom) -cne $sample) {throw 'SFC UTF16 decode failed'}
    if ((DecodeSfcOutput ([Text.Encoding]::UTF8.GetBytes($sample))) -cne $sample) {throw 'SFC UTF8 decode failed'}
    if ((Test-NexAdministrator) -isnot [bool]) {throw 'Privilege detection must return a Boolean'}
    # Handoff acknowledgement does not launch a terminal or elevate the test runner.
    $token=[guid]::NewGuid().ToString('N')
    $pending=Get-NexHandoffPath $token pending
    $ready=Get-NexHandoffPath $token ready
    Complete-NexHandoff $token
    if (Test-Path -LiteralPath $ready) {throw 'Handoff acknowledged without a pending request'}
    [IO.File]::WriteAllText($pending,'wrong')
    Complete-NexHandoff $token
    if (Test-Path -LiteralPath $ready) {throw 'Incorrect token was accepted'}
    [IO.File]::WriteAllText($pending,$token)
    Complete-NexHandoff $token
    if ([IO.File]::ReadAllText($ready) -cne $token) {throw 'Handoff acknowledgement missing'}
    Complete-NexHandoff $token
    if ([IO.File]::ReadAllText($ready) -cne $token) {throw 'Duplicate acknowledgement changed result'}
    $rejected=$false
    try {Get-NexHandoffPath '../invalid' ready} catch {$rejected=$true}
    if (-not $rejected) {throw 'Invalid handoff path accepted'}
    $defaults=Get-NexPreferences -DefaultsOnly
    if ($defaults.LightMode -or $defaults.Theme -ne 'Pink') {throw 'Factory preferences are not default'}
    Write-Host 'Light theme and default preference checks passed.'
} finally {
    $env:LOCALAPPDATA=$old
    if (Test-Path -LiteralPath $temp) {Remove-Item -LiteralPath $temp -Recurse -Force}
}
