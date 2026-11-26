$ErrorActionPreference='Stop'
$WarningPreference='Stop'
. (Join-Path $PSScriptRoot '../src/NexDashboard.ps1')
$snapshot=@{
    OS=[pscustomobject]@{Caption='Microsoft Windows 11 Pro';BuildNumber='26300';TotalVisibleMemorySize=33554432;FreePhysicalMemory=16777216;LastBootUpTime=(Get-Date).AddDays(-1)}
    CPU=[pscustomobject]@{Name='AMD Ryzen 9 9950X3D 16-Core Processor'}
    GPU=@('NVIDIA GeForce RTX 5080')
    Disks=@([pscustomobject]@{DeviceID='C:';Size=1TB;FreeSpace=512GB})
    CV=[pscustomobject]@{UBR=10075;DisplayVersion='26H2'}
}
$global:NexPublicSettings.CustomLogo=''
foreach ($language in @('en','ru','de')) {
    $global:NexPublicSettings.Language=$language
    foreach ($preset in @('Cards','Neon Frame','Studio','Tree Layout','Color Labels','Minimal','Compact')) {
        $global:NexPublicSettings.FetchPreset=$preset
        foreach ($width in @(24,28,40,58,79,80,100,112,160)) {
            $lines=@(Show-NexPublicFetch -Width $width -AsLines -NoAnimation -Snapshot $snapshot)
            if (-not $lines.Count) {throw "No output: $language / $preset / $width"}
            foreach ($line in $lines) {
                $plain=$line -replace '\x1b\[[0-9;]*m',''
                if ((Get-NexLogoWidth $plain) -ge $width) {throw "Line too wide: $language / $preset / $width / $plain"}
                if ($preset -eq 'Cards' -and $width -ge 28 -and $plain -match '[╭│╰]' -and $plain -notmatch '[╮│╯]$') {throw "Incomplete card border: $width / $plain"}
            }
        }
    }
}
Write-Host 'Responsive fetch width tests passed.'
