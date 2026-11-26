$ErrorActionPreference='Stop'
$root=Join-Path ([IO.Path]::GetTempPath()) ('nex-consent-test-'+[guid]::NewGuid().ToString('N'))
$old=$env:LOCALAPPDATA
try {
    $env:LOCALAPPDATA=$root
    . (Join-Path $PSScriptRoot '../src/NexDashboard.ps1')
    $a='A'*64;$b='B'*64
    if (Test-NexOoklaConsent $a) {throw 'Unexpected initial acceptance'}
    Save-NexOoklaConsent $a
    if (-not (Test-NexOoklaConsent $a)) {throw 'Acceptance not saved'}
    if (Test-NexOoklaConsent $b) {throw 'Changed executable should require acceptance'}
    if (Test-NexOoklaConsent '') {throw 'Invalid hash accepted'}
    . (Join-Path $PSScriptRoot '../src/NexDashboard.ps1')
    if (-not (Test-NexOoklaConsent $a)) {throw 'Acceptance did not survive reload'}
    $file=Get-NexOoklaConsentPath
    $data=[IO.File]::ReadAllText($file) | ConvertFrom-Json
    $data.TermsRevision='old'
    [IO.File]::WriteAllText($file,($data | ConvertTo-Json))
    if (Test-NexOoklaConsent $a) {throw 'Old terms accepted'}
    Save-NexOoklaConsent $a
    Remove-Item -LiteralPath $file
    if (Test-NexOoklaConsent $a) {throw 'Reset did not revoke stored consent'}
    Write-Host 'Ookla consent persistence tests passed.'
} finally {
    $env:LOCALAPPDATA=$old
    if (Test-Path -LiteralPath $root) {Remove-Item -LiteralPath $root -Recurse -Force}
}
