#Requires -Version 5.1
<#
.SYNOPSIS
    WinCleaner: safe temp file and cache cleaner for Windows 10/11.

.DESCRIPTION
    Removes only temporary files and caches. Never touches documents, downloads,
    passwords, cookies, browser history or settings. Never accesses the network.

    By default it scans first, shows how much space each area uses and asks before
    deleting anything.

.PARAMETER Scan
    Scan only, delete nothing. (Turkish alias: -Tara)

.PARAMETER Yes
    Clean without asking. (Turkish alias: -Evet)

.PARAMETER Quiet
    No console output except errors. Used by the weekly scheduled task.

.PARAMETER Advanced
    Also include advanced areas such as the Windows component store (slow).

.PARAMETER Language
    tr or en. Defaults to the Windows display language.

.PARAMETER InstallSchedule
    Adds a weekly cleanup task for the current user. Day and time come from
    settings (default Sunday 12:00) and can be changed in the window.

.PARAMETER RemoveSchedule
    Removes the weekly cleanup task.

.EXAMPLE
    .\WinCleaner.ps1 -Scan
#>
[CmdletBinding()]
param(
    [Alias('Tara')][switch]$Scan,
    [Alias('Evet')][switch]$Yes,
    [switch]$Quiet,
    [switch]$Advanced,
    [ValidateSet('', 'tr', 'en')][string]$Language = '',
    [switch]$InstallSchedule,
    [switch]$RemoveSchedule
)

$ErrorActionPreference = 'Continue'
Import-Module (Join-Path $PSScriptRoot 'WinCleaner.Core.psm1') -Force

# Settings and log live in %LOCALAPPDATA%\WinCleaner, shared with the window and the weekly run
$SettingsPath = Join-Path (Get-WcDataPath) 'settings.json'
$LogPath = Join-Path (Get-WcDataPath) 'WinCleaner.log'
$Settings = Get-WcSettings -Path $SettingsPath
if (-not $Language) { $Language = $Settings.Language }
Set-WcLanguage $Language
if ($Settings.Advanced) { $Advanced = $true }

function Show([string]$Text, [string]$Color = '') {
    if ($Quiet) { return }
    if ($Color) { Write-Host $Text -ForegroundColor $Color } else { Write-Host $Text }
}

function Add-LogLine([string]$Text) {
    try { Add-Content -LiteralPath $LogPath -Value $Text -Encoding UTF8 } catch { $null = $_ }
}

# ---------------------------------------------------------------------------
# Weekly schedule
# ---------------------------------------------------------------------------
if ($InstallSchedule -or $RemoveSchedule) {
    if (-not (Test-WcAdmin)) { Write-Warning (Get-WcText 'ScheduleNeedsAdmin'); return }
    if ($InstallSchedule) {
        Register-WcSchedule -SourceFolder $PSScriptRoot -Day $Settings.ScheduleDay -Time $Settings.ScheduleTime
        Show ((Get-WcText 'ScheduleAdded') -f (Get-WcDayName $Settings.ScheduleDay), $Settings.ScheduleTime) 'Green'
    } elseif (Get-WcSchedule) {
        Unregister-WcSchedule
        Show (Get-WcText 'ScheduleRemoved') 'Green'
    } else {
        Show (Get-WcText 'ScheduleNone')
    }
    return
}

# ---------------------------------------------------------------------------
# Scan
# ---------------------------------------------------------------------------
Show ''
Show ('=== {0} ===' -f (Get-WcText 'Title')) 'Cyan'
if (-not (Test-WcAdmin)) {
    Show (Get-WcText 'NotAdmin') 'Yellow'
    Show (Get-WcText 'UseBat') 'Yellow'
}
Show (Get-WcText 'Scanning')
Show ''

$Results = @()
$No = 0
foreach ($t in Get-WcTarget -Advanced:$Advanced) {
    $No++
    $status = Get-WcStatus -Target $t -DisabledIds $Settings.DisabledAreas
    $size = if ($status -in 'NeedsAdmin', 'Disabled') { [long]0 } else { Measure-WcTarget $t }
    $Results += [pscustomobject]@{
        No = $No; Area = Get-WcTargetName $t; Size = Format-WcSize $size
        Status = Get-WcText $status; Ready = ($status -eq 'Ready'); Bytes = $size; Target = $t
    }
}

if (-not $Quiet) {
    $Results | Format-Table @(
        @{ L = (Get-WcText 'ColNo'); E = { $_.No } }
        @{ L = (Get-WcText 'ColArea'); E = { $_.Area } }
        @{ L = (Get-WcText 'ColSize'); E = { $_.Size }; A = 'Right' }
        @{ L = (Get-WcText 'ColStatus'); E = { $_.Status } }
    ) -AutoSize | Out-Host
}

# Areas with an unknown size (-1) are cleaned too, they just do not count in the total
$ToClean = @($Results | Where-Object { $_.Ready -and $_.Bytes -ne 0 })
$Total = [long](($ToClean | Where-Object { $_.Bytes -gt 0 } | Measure-Object -Property Bytes -Sum).Sum)
Show ((Get-WcText 'Total') -f (Format-WcSize $Total)) 'Green'
Show (Get-WcText 'TotalNote')
Show ''

if ($Scan) { Show (Get-WcText 'ScanOnly'); return }
if ($ToClean.Count -eq 0) { Show (Get-WcText 'Nothing'); return }
if (-not $Yes -and -not $Quiet) {
    $answer = Read-Host (Get-WcText 'Confirm')
    if ($answer -notmatch (Get-WcText 'YesPattern')) { Show (Get-WcText 'Cancelled'); return }
}

# ---------------------------------------------------------------------------
# Clean
# ---------------------------------------------------------------------------
Show ''
$Freed = [long]0
$Skipped = 0
Add-LogLine ('--- {0} ---' -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))
foreach ($r in $ToClean) {
    if (-not $Quiet) { Write-Host ((Get-WcText 'Cleaning') -f $r.Area) -NoNewline }
    $result = Clear-WcTarget $r.Target
    $Freed += $result.Freed
    $Skipped += $result.Skipped
    Show (' {0}' -f (Format-WcSize $result.Freed)) 'Green'
    Add-LogLine ('{0}: {1}' -f $r.Target.Id, (Format-WcSize $result.Freed))
}

Show ''
Show ((Get-WcText 'Freed') -f (Format-WcSize $Freed)) 'Cyan'
if ($Skipped -gt 0) { Show ((Get-WcText 'Skipped') -f $Skipped) }
Add-LogLine ('Total: {0}, skipped files: {1}' -f (Format-WcSize $Freed), $Skipped)
