#Requires -Version 5.1
<#
    WinCleaner core module.

    Holds the list of cleaning areas and the scan / clean logic.
    Used by both the console script (WinCleaner.ps1) and the windowed UI.

    This module never accesses the network. CI fails if a network command is added.
#>

Set-StrictMode -Version 2.0

$script:IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
$script:Lang = 'en'
$script:SkippedFiles = 0
$script:TaskName = 'WinCleaner Weekly'

# ---------------------------------------------------------------------------
# Texts
# ---------------------------------------------------------------------------
$script:Texts = @{
    tr = @{
        Title            = 'WinCleaner'
        NotAdmin         = 'Uyarı: Yönetici olarak çalışmıyor. Bazı alanlar atlanacak.'
        UseBat           = 'Tümünü temizlemek için WinCleaner.bat dosyasını kullanın.'
        Scanning         = 'Taranıyor, biraz sürebilir...'
        ColNo            = 'No'
        ColArea          = 'Alan'
        ColSize          = 'Boyut'
        ColStatus        = 'Durum'
        Total            = 'Temizlenebilecek toplam alan: {0}'
        TotalNote        = '(Gerçek kazanç biraz daha az olabilir, kullanımdaki dosyalar atlanır.)'
        ScanOnly         = 'Sadece tarama yapıldı, hiçbir şey silinmedi.'
        Nothing          = 'Temizlenecek bir şey yok.'
        Confirm          = 'Bu alanlar temizlensin mi? (E/H)'
        YesPattern       = '^\s*[EeYy]'
        Cancelled        = 'İptal edildi, hiçbir şey silinmedi.'
        Cleaning         = 'Temizleniyor: {0}...'
        Freed            = 'Toplam açılan alan: {0}'
        Skipped          = 'Kullanımda olduğu için atlanan dosya sayısı: {0}'
        Ready            = 'Hazır'
        NeedsAdmin       = 'Yönetici gerekli'
        AppRunning       = 'Program açık, kapatın'
        Disabled         = 'Ayarlarda kapalı'
        Unknown          = 'bilinmiyor'
        Advanced         = 'Gelişmiş'
        ScheduleAdded    = 'Haftalık temizlik eklendi: her {0} {1} (bilgisayar kapalıysa ilk açılışta). Pencere kapalıyken de çalışır.'
        ScheduleRemoved  = 'Haftalık temizlik kaldırıldı.'
        ScheduleNone     = 'Haftalık temizlik zaten kurulu değil.'
        ScheduleNeedsAdmin = 'Haftalık temizliği kurmak için yönetici olarak çalıştırın.'
    }
    en = @{
        Title            = 'WinCleaner'
        NotAdmin         = 'Warning: not running as administrator. Some areas will be skipped.'
        UseBat           = 'Use WinCleaner.bat to clean everything.'
        Scanning         = 'Scanning, this may take a moment...'
        ColNo            = 'No'
        ColArea          = 'Area'
        ColSize          = 'Size'
        ColStatus        = 'Status'
        Total            = 'Total space that can be freed: {0}'
        TotalNote        = '(Actual result may be slightly lower, files in use are skipped.)'
        ScanOnly         = 'Scan only, nothing was deleted.'
        Nothing          = 'Nothing to clean.'
        Confirm          = 'Clean these areas? (Y/N)'
        YesPattern       = '^\s*[Yy]'
        Cancelled        = 'Cancelled, nothing was deleted.'
        Cleaning         = 'Cleaning: {0}...'
        Freed            = 'Total space freed: {0}'
        Skipped          = 'Files skipped because they are in use: {0}'
        Ready            = 'Ready'
        NeedsAdmin       = 'Needs administrator'
        AppRunning       = 'App is running, close it'
        Disabled         = 'Disabled in settings'
        Unknown          = 'unknown'
        Advanced         = 'Advanced'
        ScheduleAdded    = 'Weekly cleanup added: every {0} at {1} (or at next start if the PC was off). It runs without opening WinCleaner.'
        ScheduleRemoved  = 'Weekly cleanup removed.'
        ScheduleNone     = 'Weekly cleanup is not installed.'
        ScheduleNeedsAdmin = 'Run as administrator to install the weekly cleanup.'
    }
}

# ---------------------------------------------------------------------------
# Cleaning areas
#   Id        : stable identifier, used in settings.json
#   Paths     : folder -> its CONTENTS are removed (folder stays); file -> file is removed
#   Admin     : needs administrator rights
#   MinAge    : files changed within this many hours are kept
#   Process   : area is skipped while one of these processes runs
#   Services  : stopped during cleaning and started again afterwards
#   Special   : RecycleBin | DeliveryOptimization | ComponentStore
#   Advanced  : only included when -Advanced is used
# ---------------------------------------------------------------------------
function Get-WcTargetList {
    $L = $env:LOCALAPPDATA
    $R = $env:APPDATA
    $W = $env:SystemRoot
    $PD = $env:ProgramData
    $SD = $env:SystemDrive

    function Chromium([string]$Root) {
        @("$Root\*\Cache", "$Root\*\Code Cache", "$Root\*\GPUCache")
    }

    @(
        @{ Id = 'UserTemp'; Tr = 'Kullanıcı Temp klasörü'; En = 'User Temp folder'
           Paths = @($env:TEMP); MinAge = 24 }
        @{ Id = 'WindowsTemp'; Tr = 'Windows Temp klasörü'; En = 'Windows Temp folder'
           Paths = @("$W\Temp"); Admin = $true; MinAge = 24 }
        @{ Id = 'WindowsUpdate'; Tr = 'Windows Update indirme önbelleği'; En = 'Windows Update download cache'
           Paths = @("$W\SoftwareDistribution\Download"); Admin = $true; Services = @('wuauserv', 'bits') }
        @{ Id = 'DeliveryOptimization'; Tr = 'Teslim İyileştirme önbelleği'; En = 'Delivery Optimization cache'
           Paths = @("$W\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache")
           Admin = $true; Special = 'DeliveryOptimization'; Services = @('DoSvc') }
        @{ Id = 'Thumbnails'; Tr = 'Küçük resim ve simge önbelleği'; En = 'Thumbnail and icon cache'
           Paths = @("$L\Microsoft\Windows\Explorer\thumbcache_*.db", "$L\Microsoft\Windows\Explorer\iconcache_*.db") }
        @{ Id = 'DirectX'; Tr = 'DirectX gölgelendirici önbelleği'; En = 'DirectX shader cache'
           Paths = @("$L\D3DSCache") }
        @{ Id = 'GpuShader'; Tr = 'Ekran kartı gölgelendirici önbelleği'; En = 'GPU shader cache'
           Paths = @("$L\NVIDIA\DXCache", "$L\NVIDIA\GLCache", "$L\AMD\DxCache", "$L\AMD\DxcCache", "$L\AMD\GLCache") }
        @{ Id = 'GpuInstaller'; Tr = 'Ekran kartı sürücü kurulum artıkları'; En = 'GPU driver installer leftovers'
           Paths = @("$SD\NVIDIA", "$SD\AMD", "$PD\NVIDIA Corporation\Downloader"); Admin = $true }
        @{ Id = 'Edge'; Tr = 'Microsoft Edge önbelleği'; En = 'Microsoft Edge cache'
           Paths = (Chromium "$L\Microsoft\Edge\User Data"); Process = @('msedge') }
        @{ Id = 'Chrome'; Tr = 'Google Chrome önbelleği'; En = 'Google Chrome cache'
           Paths = (Chromium "$L\Google\Chrome\User Data"); Process = @('chrome') }
        @{ Id = 'Brave'; Tr = 'Brave önbelleği'; En = 'Brave cache'
           Paths = (Chromium "$L\BraveSoftware\Brave-Browser\User Data"); Process = @('brave') }
        @{ Id = 'Vivaldi'; Tr = 'Vivaldi önbelleği'; En = 'Vivaldi cache'
           Paths = (Chromium "$L\Vivaldi\User Data"); Process = @('vivaldi') }
        @{ Id = 'Opera'; Tr = 'Opera önbelleği'; En = 'Opera cache'
           Paths = @("$L\Opera Software\Opera Stable\Cache", "$L\Opera Software\Opera Stable\Default\Cache",
                     "$L\Opera Software\Opera GX Stable\Cache", "$L\Opera Software\Opera GX Stable\Default\Cache")
           Process = @('opera') }
        @{ Id = 'Firefox'; Tr = 'Mozilla Firefox önbelleği'; En = 'Mozilla Firefox cache'
           Paths = @("$L\Mozilla\Firefox\Profiles\*\cache2"); Process = @('firefox') }
        @{ Id = 'Discord'; Tr = 'Discord önbelleği'; En = 'Discord cache'
           Paths = @("$R\discord\Cache", "$R\discord\Code Cache", "$R\discord\GPUCache"); Process = @('Discord') }
        @{ Id = 'Teams'; Tr = 'Microsoft Teams önbelleği'; En = 'Microsoft Teams cache'
           Paths = @("$R\Microsoft\Teams\Cache", "$R\Microsoft\Teams\Code Cache", "$R\Microsoft\Teams\GPUCache",
                     "$L\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\EBWebView\*\Cache",
                     "$L\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\EBWebView\*\Code Cache")
           Process = @('ms-teams', 'Teams') }
        @{ Id = 'CrashDumps'; Tr = 'Uygulama çökme dökümleri'; En = 'App crash dumps'
           Paths = @("$L\CrashDumps") }
        @{ Id = 'ErrorReports'; Tr = 'Sistem hata dökümleri ve raporları'; En = 'System crash dumps and error reports'
           Paths = @("$PD\Microsoft\Windows\WER\ReportArchive", "$PD\Microsoft\Windows\WER\ReportQueue",
                     "$W\Minidump", "$W\MEMORY.DMP"); Admin = $true }
        @{ Id = 'WindowsLogs'; Tr = 'Eski Windows günlük dosyaları'; En = 'Old Windows log files'
           Paths = @("$W\Logs\CBS", "$W\Logs\DISM", "$W\Logs\MoSetup", "$W\Logs\WindowsUpdate")
           Admin = $true; MinAge = 168 }
        @{ Id = 'RecycleBin'; Tr = 'Geri Dönüşüm Kutusu'; En = 'Recycle Bin'
           Special = 'RecycleBin' }
        @{ Id = 'ComponentStore'; Tr = 'Windows bileşen deposu (DISM, uzun sürer)'; En = 'Windows component store (DISM, slow)'
           Special = 'ComponentStore'; Admin = $true; Advanced = $true }
    ) | ForEach-Object {
        $t = $_
        foreach ($k in 'Paths', 'Process', 'Services') { if (-not $t.ContainsKey($k)) { $t[$k] = @() } }
        foreach ($k in 'Admin', 'Advanced') { if (-not $t.ContainsKey($k)) { $t[$k] = $false } }
        if (-not $t.ContainsKey('MinAge')) { $t.MinAge = 0 }
        if (-not $t.ContainsKey('Special')) { $t.Special = '' }
        [pscustomobject]$t
    }
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Set-WcLanguage([string]$Language) {
    if (-not $Language) { $Language = if ((Get-UICulture).TwoLetterISOLanguageName -eq 'tr') { 'tr' } else { 'en' } }
    $script:Lang = if ($Language -eq 'tr') { 'tr' } else { 'en' }
}

function Get-WcLanguage { $script:Lang }

function Get-WcText([string]$Key) { $script:Texts[$script:Lang][$Key] }

function Get-WcDayName([string]$Day) {
    $culture = if ($script:Lang -eq 'tr') { 'tr-TR' } else { 'en-US' }
    ([Globalization.CultureInfo]::GetCultureInfo($culture)).DateTimeFormat.GetDayName([DayOfWeek]$Day)
}

<#
.SYNOPSIS
    Folder for settings, log and the scheduled copy: %LOCALAPPDATA%\WinCleaner
#>
function Get-WcDataPath {
    $path = Join-Path $env:LOCALAPPDATA 'WinCleaner'
    if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
    $path
}

function Get-WcTargetName($Target) { if ($script:Lang -eq 'tr') { $Target.Tr } else { $Target.En } }

function Test-WcAdmin { $script:IsAdmin }

function Format-WcSize([long]$Bytes) {
    if ($Bytes -lt 0) { return (Get-WcText 'Unknown') }
    if ($Bytes -ge 1GB) { '{0:N2} GB' -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { '{0:N1} MB' -f ($Bytes / 1MB) }
    else { '{0:N0} KB' -f ($Bytes / 1KB) }
}

function Get-BlockedPath {
    @("$env:SystemDrive\", $env:SystemRoot, $env:USERPROFILE, $env:LOCALAPPDATA, $env:APPDATA, $env:ProgramData,
      $env:ProgramFiles, ${env:ProgramFiles(x86)}, "$env:SystemRoot\System32") |
        Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\').ToLowerInvariant() }
}

function Test-ReparsePoint([IO.FileSystemInfo]$Item) {
    ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
}

function Get-TargetItem($Paths) {
    $blocked = Get-BlockedPath
    foreach ($p in $Paths) {
        if (-not $p) { continue }
        foreach ($item in @(Get-Item -Path $p -Force -ErrorAction SilentlyContinue)) {
            if ($blocked -contains $item.FullName.TrimEnd('\').ToLowerInvariant()) { continue }
            $item
        }
    }
}

# A folder target is emptied (the folder itself stays); a file target is removed.
function Get-TargetChild([IO.FileSystemInfo]$Item) {
    if ($Item -is [IO.DirectoryInfo] -and -not (Test-ReparsePoint $Item)) {
        try { $Item.GetFileSystemInfos() } catch { @() }
    } else { $Item }
}

function Get-TreeSize([IO.FileSystemInfo]$Item, [datetime]$Cutoff) {
    if (Test-ReparsePoint $Item) { return [long]0 }
    if ($Item -is [IO.FileInfo]) {
        if ($Item.LastWriteTime -lt $Cutoff) { return [long]$Item.Length } else { return [long]0 }
    }
    $total = [long]0
    try { $children = $Item.GetFileSystemInfos() } catch { return [long]0 }
    foreach ($c in $children) { $total += Get-TreeSize $c $Cutoff }
    return $total
}

function Remove-Tree([IO.FileSystemInfo]$Item, [datetime]$Cutoff) {
    if (Test-ReparsePoint $Item) {
        # Remove only the link itself, never its target
        try {
            if ($Item -is [IO.DirectoryInfo]) { [IO.Directory]::Delete($Item.FullName, $false) } else { $Item.Delete() }
        } catch { $null = $_ }
        return [long]0
    }
    if ($Item -is [IO.FileInfo]) {
        if ($Item.LastWriteTime -ge $Cutoff) { return [long]0 }
        $size = [long]$Item.Length
        try {
            if ($Item.IsReadOnly) { $Item.IsReadOnly = $false }
            $Item.Delete()
            return $size
        } catch {
            $script:SkippedFiles++
            return [long]0
        }
    }
    $total = [long]0
    try { $children = $Item.GetFileSystemInfos() } catch { return [long]0 }
    foreach ($c in $children) { $total += Remove-Tree $c $Cutoff }
    try { if ($Item.GetFileSystemInfos().Count -eq 0) { $Item.Delete() } } catch { $null = $_ }
    return $total
}

function Get-RecycleBinSize {
    try {
        $shell = New-Object -ComObject Shell.Application
        $total = [long]0
        foreach ($i in $shell.NameSpace(10).Items()) { $total += [long]$i.Size }
        return $total
    } catch { return [long]0 }
}

# ---------------------------------------------------------------------------
# Public functions
# ---------------------------------------------------------------------------

<#
.SYNOPSIS
    Returns the cleaning areas. Advanced areas only with -Advanced.
#>
function Get-WcTarget {
    param([switch]$Advanced)
    Get-WcTargetList | Where-Object { $Advanced -or -not $_.Advanced }
}

<#
.SYNOPSIS
    Returns Ready, NeedsAdmin, AppRunning or Disabled for an area.
#>
function Get-WcStatus {
    param($Target, [string[]]$DisabledIds = @())
    if ($DisabledIds -contains $Target.Id) { return 'Disabled' }
    if ($Target.Admin -and -not $script:IsAdmin) { return 'NeedsAdmin' }
    if ($Target.Process.Count -gt 0 -and (Get-Process -Name $Target.Process -ErrorAction SilentlyContinue)) {
        return 'AppRunning'
    }
    return 'Ready'
}

<#
.SYNOPSIS
    Returns the bytes an area would free. -1 when it cannot be measured in advance.
#>
function Measure-WcTarget {
    param($Target)
    switch ($Target.Special) {
        'RecycleBin' { return Get-RecycleBinSize }
        'ComponentStore' { return [long]-1 }
    }
    $cutoff = (Get-Date).AddHours(-[double]$Target.MinAge)
    $total = [long]0
    foreach ($item in Get-TargetItem $Target.Paths) {
        foreach ($c in Get-TargetChild $item) { $total += Get-TreeSize $c $cutoff }
    }
    return $total
}

<#
.SYNOPSIS
    Cleans one area. Returns an object with Freed (bytes) and Skipped (files in use).
#>
function Clear-WcTarget {
    param($Target)
    $script:SkippedFiles = 0

    if ($Target.Special -eq 'RecycleBin') {
        $before = Get-RecycleBinSize
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        return [pscustomobject]@{ Freed = [long][Math]::Max(0, $before - (Get-RecycleBinSize)); Skipped = 0 }
    }
    if ($Target.Special -eq 'ComponentStore') {
        $drive = Get-PSDrive -Name $env:SystemDrive.TrimEnd(':') -ErrorAction SilentlyContinue
        $freeBefore = if ($drive) { [long]$drive.Free } else { [long]0 }
        & "$env:SystemRoot\System32\Dism.exe" /Online /Cleanup-Image /StartComponentCleanup /Quiet | Out-Null
        $drive = Get-PSDrive -Name $env:SystemDrive.TrimEnd(':') -ErrorAction SilentlyContinue
        $freeAfter = if ($drive) { [long]$drive.Free } else { [long]0 }
        return [pscustomobject]@{ Freed = [long][Math]::Max(0, $freeAfter - $freeBefore); Skipped = 0 }
    }

    # Delivery Optimization: Windows' own command first. It finishes in the
    # background, so leftovers are removed below with the service stopped.
    $extra = [long]0
    if ($Target.Special -eq 'DeliveryOptimization' -and
        (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue)) {
        $before = Measure-WcTarget $Target
        Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue *> $null
        $extra = [long][Math]::Max(0, $before - (Measure-WcTarget $Target))
    }

    $stopped = @()
    foreach ($s in $Target.Services) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq 'Running') {
            Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
            $stopped += $s
        }
    }
    try {
        $cutoff = (Get-Date).AddHours(-[double]$Target.MinAge)
        $total = [long]0
        foreach ($item in Get-TargetItem $Target.Paths) {
            foreach ($c in Get-TargetChild $item) { $total += Remove-Tree $c $cutoff }
        }
        return [pscustomobject]@{ Freed = [long]($total + $extra); Skipped = $script:SkippedFiles }
    } finally {
        foreach ($s in $stopped) { Start-Service -Name $s -ErrorAction SilentlyContinue }
    }
}

<#
.SYNOPSIS
    Reads settings.json next to the scripts. Returns defaults when missing or invalid.
#>
function Get-WcSettings {
    param([string]$Path)
    $settings = [pscustomobject]@{
        Language = ''; DisabledAreas = @(); Advanced = $false; ScheduleDay = 'Sunday'; ScheduleTime = '12:00'
    }
    if ($Path -and (Test-Path -LiteralPath $Path)) {
        try {
            $json = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in 'Language', 'DisabledAreas', 'Advanced', 'ScheduleDay', 'ScheduleTime') {
                if ($json.PSObject.Properties.Name -contains $p) { $settings.$p = $json.$p }
            }
            $settings.DisabledAreas = @($settings.DisabledAreas)
        } catch { $null = $_ }
    }
    if ([Enum]::GetNames([DayOfWeek]) -notcontains $settings.ScheduleDay) { $settings.ScheduleDay = 'Sunday' }
    if ($settings.ScheduleTime -notmatch '^([01]\d|2[0-3]):[0-5]\d$') { $settings.ScheduleTime = '12:00' }
    $settings
}

function Save-WcSettings {
    param([string]$Path, $Settings)
    $Settings | ConvertTo-Json | Set-Content -LiteralPath $Path -Encoding UTF8
}

<#
.SYNOPSIS
    Installs or removes the weekly scheduled cleanup for the current user.
#>
function Get-WcSchedule {
    [bool](Get-ScheduledTask -TaskName $script:TaskName -ErrorAction SilentlyContinue)
}

function Register-WcSchedule {
    param(
        # Folder that holds WinCleaner.ps1 and this module
        [Parameter(Mandatory)][string]$SourceFolder,
        [ValidateSet('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')]
        [string]$Day = 'Sunday',
        [ValidatePattern('^([01]\d|2[0-3]):[0-5]\d$')][string]$Time = '12:00'
    )
    # Copy the scripts to a fixed place, so the weekly run keeps working
    # even if the downloaded folder is moved or deleted.
    $target = Join-Path (Get-WcDataPath) 'app'
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    foreach ($file in 'WinCleaner.ps1', 'WinCleaner.Core.psm1') {
        Copy-Item -LiteralPath (Join-Path $SourceFolder $file) -Destination $target -Force
    }
    $scriptPath = Join-Path $target 'WinCleaner.ps1'

    $arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Yes -Quiet' -f $scriptPath
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $Day -At $Time
    $principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) `
        -LogonType Interactive -RunLevel Highest
    $taskSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit (New-TimeSpan -Hours 2)
    Register-ScheduledTask -TaskName $script:TaskName -Action $action -Trigger $trigger -Principal $principal `
        -Settings $taskSettings -Description 'WinCleaner weekly temp and cache cleanup' -Force | Out-Null
}

function Unregister-WcSchedule {
    Unregister-ScheduledTask -TaskName $script:TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path (Get-WcDataPath) 'app') -Recurse -Force -ErrorAction SilentlyContinue
}

Export-ModuleMember -Function Set-WcLanguage, Get-WcLanguage, Get-WcDayName, Get-WcDataPath, Get-WcText, Get-WcTargetName, Test-WcAdmin, Format-WcSize,
    Get-WcTarget, Get-WcStatus, Measure-WcTarget, Clear-WcTarget, Get-WcSettings, Save-WcSettings,
    Get-WcSchedule, Register-WcSchedule, Unregister-WcSchedule
