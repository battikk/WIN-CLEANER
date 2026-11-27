#Requires -Version 5.1
<#
.SYNOPSIS
    WinCleaner windowed interface.

.DESCRIPTION
    Same cleaning areas and safety rules as WinCleaner.ps1, in a window.
    Scanning and cleaning run in the background so the window stays responsive.
    Never accesses the network.

.PARAMETER SelfTest
    Builds the window and runs a scan without showing it, then exits.
    Used by CI. Deletes nothing.
#>
[CmdletBinding()]
param(
    [switch]$SelfTest,
    # With -SelfTest: also save a picture of the window to this folder
    [string]$ScreenshotFolder = ''
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$ModulePath = Join-Path $PSScriptRoot 'src\WinCleaner.Core.psm1'
$ConsoleScript = Join-Path $PSScriptRoot 'WinCleaner.ps1'
$SettingsPath = Join-Path $PSScriptRoot 'settings.json'
$LogPath = Join-Path $PSScriptRoot 'WinCleaner.log'
Import-Module $ModulePath -Force

$Settings = Get-WcSettings -Path $SettingsPath
Set-WcLanguage $Settings.Language

# ---------------------------------------------------------------------------
# Window texts (area names and statuses come from the core module)
# ---------------------------------------------------------------------------
$UiTexts = @{
    tr = @{
        Subtitle     = 'Geçici dosyaları ve önbellekleri güvenle temizler. İnternete bağlanmaz.'
        NotAdmin     = 'Yönetici olarak çalışmıyor, bazı alanlar atlanacak. Tümü için WinCleaner.bat ile açın.'
        Scan         = 'Tara'
        Clean        = 'Temizle'
        Weekly       = 'Haftalık otomatik temizlik (Pazar 12:00)'
        ShowAdvanced = 'Gelişmiş alanları göster'
        Start        = 'Başlamak için Tara düğmesine bas.'
        StartDetail  = 'Tarama hiçbir şeyi silmez.'
        Scanning     = 'Taranıyor: {0}'
        Cleaning     = 'Temizleniyor: {0}'
        Found        = '{0} temizlenebilir'
        FoundDetail  = 'Temizlemek istemediğin alanların işaretini kaldır.'
        Freed        = '{0} yer açıldı'
        Skipped      = '{0} dosya kullanımda olduğu için atlandı.'
        Done         = 'Tamamlandı.'
        ConfirmTitle = 'Temizliği onayla'
        ConfirmBody  = '{0} alan temizlenecek. Geri Dönüşüm Kutusu seçiliyse içindekiler geri alınamaz. Devam edilsin mi?'
        Error        = 'Hata: {0}'
        AdminNeeded  = 'Bunun için WinCleaner.bat ile yönetici olarak açın.'
        NotScanned   = '–'
    }
    en = @{
        Subtitle     = 'Safely removes temporary files and caches. Never connects to the internet.'
        NotAdmin     = 'Not running as administrator, some areas will be skipped. Open with WinCleaner.bat for all.'
        Scan         = 'Scan'
        Clean        = 'Clean'
        Weekly       = 'Weekly automatic cleanup (Sunday 12:00)'
        ShowAdvanced = 'Show advanced areas'
        Start        = 'Press Scan to start.'
        StartDetail  = 'Scanning never deletes anything.'
        Scanning     = 'Scanning: {0}'
        Cleaning     = 'Cleaning: {0}'
        Found        = '{0} can be freed'
        FoundDetail  = 'Untick any area you want to keep.'
        Freed        = '{0} freed'
        Skipped      = '{0} files were skipped because they are in use.'
        Done         = 'Done.'
        ConfirmTitle = 'Confirm cleanup'
        ConfirmBody  = '{0} areas will be cleaned. If Recycle Bin is selected, its contents cannot be restored. Continue?'
        Error        = 'Error: {0}'
        AdminNeeded  = 'Open with WinCleaner.bat as administrator for this.'
        NotScanned   = '–'
    }
}
function T([string]$Key) { $UiTexts[(Get-WcLanguage)][$Key] }

# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------
[xml]$Xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WinCleaner" Width="700" Height="740" MinWidth="560" MinHeight="520"
        WindowStartupLocation="CenterScreen" FontFamily="Segoe UI" FontSize="13"
        Background="{DynamicResource Bg}" Foreground="{DynamicResource Fg}">
  <Window.Resources>
    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="Background" Value="{DynamicResource Accent}"/>
      <Setter Property="Padding" Value="24,9"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Chrome" Background="{TemplateBinding Background}" CornerRadius="6"
                    BorderBrush="{DynamicResource Line}" BorderThickness="1" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Chrome" Property="Opacity" Value="0.85"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="Chrome" Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="BtnSecondary" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="{DynamicResource Card}"/>
      <Setter Property="Foreground" Value="{DynamicResource Fg}"/>
    </Style>
  </Window.Resources>
  <Grid Margin="22">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <DockPanel Grid.Row="0" Margin="0,0,0,16">
      <ComboBox x:Name="LangBox" DockPanel.Dock="Right" Width="110" VerticalAlignment="Top">
        <ComboBoxItem Tag="tr">Türkçe</ComboBoxItem>
        <ComboBoxItem Tag="en">English</ComboBoxItem>
      </ComboBox>
      <StackPanel>
        <TextBlock Text="WinCleaner" FontSize="26" FontWeight="Bold"/>
        <TextBlock x:Name="Subtitle" Foreground="{DynamicResource Muted}" Margin="0,2,0,0" TextWrapping="Wrap"/>
        <TextBlock x:Name="AdminNote" Foreground="#D97706" Margin="0,8,0,0" TextWrapping="Wrap" Visibility="Collapsed"/>
      </StackPanel>
    </DockPanel>

    <Border Grid.Row="1" Background="{DynamicResource Card}" CornerRadius="8" Padding="4"
            BorderBrush="{DynamicResource Line}" BorderThickness="1">
      <ScrollViewer VerticalScrollBarVisibility="Auto">
        <StackPanel x:Name="Rows"/>
      </ScrollViewer>
    </Border>

    <StackPanel Grid.Row="2" Margin="0,16,0,0">
      <TextBlock x:Name="Summary" FontSize="17" FontWeight="SemiBold"/>
      <TextBlock x:Name="Detail" Foreground="{DynamicResource Muted}" Margin="0,2,0,10" TextWrapping="Wrap"/>
      <ProgressBar x:Name="Progress" Height="6" Minimum="0" Maximum="1" Value="0" BorderThickness="0"
                   Foreground="{DynamicResource Accent}" Background="{DynamicResource Line}" Margin="0,0,0,14"/>
      <DockPanel>
        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" VerticalAlignment="Center">
          <Button x:Name="ScanBtn" Style="{StaticResource BtnSecondary}" Margin="0,0,8,0"/>
          <Button x:Name="CleanBtn" Style="{StaticResource Btn}" IsEnabled="False"/>
        </StackPanel>
        <StackPanel VerticalAlignment="Center">
          <CheckBox x:Name="WeeklyBox" Foreground="{DynamicResource Fg}"/>
          <CheckBox x:Name="AdvancedBox" Foreground="{DynamicResource Fg}" Margin="0,6,0,0"/>
        </StackPanel>
      </DockPanel>
    </StackPanel>
  </Grid>
</Window>
'@

$Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $Xaml))
$Ui = @{}
foreach ($name in 'LangBox', 'Subtitle', 'AdminNote', 'Rows', 'Summary', 'Detail', 'Progress',
                  'ScanBtn', 'CleanBtn', 'WeeklyBox', 'AdvancedBox') {
    $Ui[$name] = $Window.FindName($name)
}

# ---------------------------------------------------------------------------
# Theme: follow the Windows light / dark app setting
# ---------------------------------------------------------------------------
$LightTheme = $true
try {
    $value = Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' `
        -Name AppsUseLightTheme -ErrorAction Stop
    $LightTheme = ($value -ne 0)
} catch { $null = $_ }

$Palette = if ($LightTheme) {
    @{ Bg = '#F3F4F6'; Card = '#FFFFFF'; Fg = '#111827'; Muted = '#6B7280'; Accent = '#2563EB'; Line = '#E5E7EB' }
} else {
    @{ Bg = '#1C1C1C'; Card = '#272727'; Fg = '#F3F4F6'; Muted = '#A1A1AA'; Accent = '#3B82F6'; Line = '#3A3A3A' }
}
$BrushConverter = New-Object Windows.Media.BrushConverter
foreach ($key in $Palette.Keys) {
    $Window.Resources[$key] = [Windows.Media.Brush]$BrushConverter.ConvertFromString($Palette[$key])
}

# ---------------------------------------------------------------------------
# Area rows
# ---------------------------------------------------------------------------
$Rows = [ordered]@{}
$GridLength = New-Object Windows.GridLengthConverter

function New-AreaRow($Target) {
    $border = New-Object Windows.Controls.Border
    $border.BorderThickness = '0,0,0,1'
    $border.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'Line')
    $border.Padding = '12,9,12,9'

    $grid = New-Object Windows.Controls.Grid
    foreach ($w in '*', '110', '170') {
        $col = New-Object Windows.Controls.ColumnDefinition
        $col.Width = $GridLength.ConvertFromString($w)
        $grid.ColumnDefinitions.Add($col)
    }

    $check = New-Object Windows.Controls.CheckBox
    $check.VerticalContentAlignment = 'Center'
    $check.IsChecked = (-not $Target.Advanced) -and ($Settings.DisabledAreas -notcontains $Target.Id)
    $name = New-Object Windows.Controls.TextBlock
    $name.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'Fg')
    $name.TextTrimming = 'CharacterEllipsis'
    $name.Margin = '4,0,0,0'
    $check.Content = $name

    $size = New-Object Windows.Controls.TextBlock
    $size.TextAlignment = 'Right'
    $size.VerticalAlignment = 'Center'
    $size.FontWeight = 'SemiBold'
    [Windows.Controls.Grid]::SetColumn($size, 1)

    $status = New-Object Windows.Controls.TextBlock
    $status.Margin = '18,0,0,0'
    $status.VerticalAlignment = 'Center'
    $status.TextTrimming = 'CharacterEllipsis'
    $status.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'Muted')
    [Windows.Controls.Grid]::SetColumn($status, 2)

    [void]$grid.Children.Add($check)
    [void]$grid.Children.Add($size)
    [void]$grid.Children.Add($status)
    $border.Child = $grid
    [void]$Ui.Rows.Children.Add($border)

    [pscustomobject]@{
        Target = $Target; Border = $border; Check = $check; NameText = $name; SizeText = $size
        StatusText = $status; Status = ''; Bytes = [long]0; Freed = $null
    }
}

foreach ($t in Get-WcTarget -Advanced) { $Rows[$t.Id] = New-AreaRow $t }

# ---------------------------------------------------------------------------
# State and rendering
# ---------------------------------------------------------------------------
$State = @{ Phase = 'start'; Busy = $false; TotalFreed = [long]0; Skipped = 0; Error = '' }

function Update-View {
    $Ui.Subtitle.Text = T 'Subtitle'
    $Ui.AdminNote.Text = T 'NotAdmin'
    $Ui.AdminNote.Visibility = if (Test-WcAdmin) { 'Collapsed' } else { 'Visible' }
    $Ui.ScanBtn.Content = T 'Scan'
    $Ui.CleanBtn.Content = T 'Clean'
    $Ui.WeeklyBox.Content = T 'Weekly'
    $Ui.AdvancedBox.Content = T 'ShowAdvanced'

    foreach ($row in $Rows.Values) {
        $row.NameText.Text = Get-WcTargetName $row.Target
        $row.Border.Visibility = if ($row.Target.Advanced -and -not $Ui.AdvancedBox.IsChecked) { 'Collapsed' } else { 'Visible' }
        if ($null -ne $row.Freed) {
            $row.SizeText.Text = Format-WcSize $row.Freed
            $row.StatusText.Text = T 'Done'
        } elseif ($row.Status) {
            $row.SizeText.Text = Format-WcSize $row.Bytes
            $row.StatusText.Text = Get-WcText $row.Status
        } else {
            $row.SizeText.Text = T 'NotScanned'
            $row.StatusText.Text = ''
        }
        $row.Check.IsEnabled = (-not $State.Busy) -and ($row.Status -eq '' -or $row.Status -eq 'Ready')
    }

    if ($State.Busy) { return }
    switch ($State.Phase) {
        'start' {
            $Ui.Summary.Text = T 'Start'
            $Ui.Detail.Text = T 'StartDetail'
        }
        'scanned' {
            $Ui.Summary.Text = (T 'Found') -f (Format-WcSize (Get-SelectedBytes))
            $Ui.Detail.Text = T 'FoundDetail'
        }
        'cleaned' {
            $Ui.Summary.Text = (T 'Freed') -f (Format-WcSize $State.TotalFreed)
            $Ui.Detail.Text = if ($State.Skipped -gt 0) { (T 'Skipped') -f $State.Skipped } else { T 'Done' }
        }
    }
    if ($State.Error) { $Ui.Detail.Text = (T 'Error') -f $State.Error }
    $Ui.ScanBtn.IsEnabled = $true
    $Ui.CleanBtn.IsEnabled = ($State.Phase -eq 'scanned') -and (@(Get-SelectedRow).Count -gt 0)
}

function Get-SelectedRow {
    $Rows.Values | Where-Object {
        $_.Check.IsChecked -and $_.Status -eq 'Ready' -and $_.Bytes -ne 0 -and $_.Border.Visibility -eq 'Visible'
    }
}

function Get-SelectedBytes {
    $sum = [long]0
    foreach ($row in Get-SelectedRow) { if ($row.Bytes -gt 0) { $sum += $row.Bytes } }
    $sum
}

function Save-Choice {
    $Settings.Language = Get-WcLanguage
    $Settings.DisabledAreas = @($Rows.Values | Where-Object { -not $_.Target.Advanced -and -not $_.Check.IsChecked } |
        ForEach-Object { $_.Target.Id })
    try { Save-WcSettings -Path $SettingsPath -Settings $Settings } catch { $null = $_ }
}

# ---------------------------------------------------------------------------
# Background work (scan or clean) in a separate runspace
# ---------------------------------------------------------------------------
$Worker = {
    param($ModulePath, $Ids, $Mode, $Language, $Sync)
    try {
        Import-Module $ModulePath -Force
        Set-WcLanguage $Language
        $targets = @(Get-WcTarget -Advanced | Where-Object { $Ids -contains $_.Id })
        foreach ($t in $targets) {
            $Sync.Current = Get-WcTargetName $t
            $status = Get-WcStatus -Target $t
            if ($Mode -eq 'scan') {
                $bytes = if ($status -eq 'NeedsAdmin') { [long]0 } else { Measure-WcTarget $t }
                $Sync.Results[$t.Id] = @{ Status = $status; Bytes = $bytes }
            } elseif ($status -eq 'Ready') {
                $r = Clear-WcTarget $t
                $Sync.Results[$t.Id] = @{ Status = $status; Freed = [long]$r.Freed; Skipped = [int]$r.Skipped }
            } else {
                # Became unavailable since the scan, e.g. the browser was opened
                $Sync.Results[$t.Id] = @{ Status = $status; Freed = $null; Skipped = 0 }
            }
            $Sync.Index++
        }
    } catch {
        $Sync.Error = $_.Exception.Message
    } finally {
        $Sync.Done = $true
    }
}

$Sync = [hashtable]::Synchronized(@{})
$Job = @{ PowerShell = $null; Handle = $null }
$Timer = New-Object Windows.Threading.DispatcherTimer
$Timer.Interval = [TimeSpan]::FromMilliseconds(150)

function Start-Work([string]$Mode, [string[]]$Ids) {
    $Sync.Clear()
    $Sync.Mode = $Mode
    $Sync.Total = [Math]::Max(1, $Ids.Count)
    $Sync.Index = 0
    $Sync.Current = ''
    $Sync.Results = [hashtable]::Synchronized(@{})
    $Sync.Done = $false
    $Sync.Error = ''
    $State.Busy = $true
    $State.Error = ''
    $Ui.ScanBtn.IsEnabled = $false
    $Ui.CleanBtn.IsEnabled = $false
    $Ui.Progress.Value = 0
    Update-View

    if ($SelfTest) {
        # Synchronous run for CI, no window shown
        & $Worker $ModulePath $Ids $Mode (Get-WcLanguage) $Sync
        Complete-Work
        return
    }
    # STA so the Recycle Bin shell object works in the background runspace
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = 'STA'
    $runspace.Open()
    $ps = [PowerShell]::Create()
    $ps.Runspace = $runspace
    [void]$ps.AddScript($Worker)
    [void]$ps.AddArgument($ModulePath)
    [void]$ps.AddArgument($Ids)
    [void]$ps.AddArgument($Mode)
    [void]$ps.AddArgument((Get-WcLanguage))
    [void]$ps.AddArgument($Sync)
    $Job.PowerShell = $ps
    $Job.Handle = $ps.BeginInvoke()
    $Timer.Start()
}

function Update-Progress {
    $Ui.Progress.Value = $Sync.Index / $Sync.Total
    $key = if ($Sync.Mode -eq 'scan') { 'Scanning' } else { 'Cleaning' }
    $Ui.Summary.Text = (T $key) -f $Sync.Current
    $Ui.Detail.Text = ''
    foreach ($id in @($Sync.Results.Keys)) {
        $row = $Rows[$id]
        $res = $Sync.Results[$id]
        if ($Sync.Mode -eq 'scan') {
            $row.SizeText.Text = Format-WcSize $res.Bytes
            $row.StatusText.Text = Get-WcText $res.Status
        } elseif ($null -ne $res.Freed) {
            $row.SizeText.Text = Format-WcSize $res.Freed
            $row.StatusText.Text = T 'Done'
        }
    }
    if ($Sync.Done) { Complete-Work }
}

function Complete-Work {
    $Timer.Stop()
    if ($Job.PowerShell) {
        try { $Job.PowerShell.EndInvoke($Job.Handle) | Out-Null } catch { $null = $_ }
        $Job.PowerShell.Runspace.Dispose()
        $Job.PowerShell.Dispose()
        $Job.PowerShell = $null
    }
    $State.Busy = $false
    $State.Error = $Sync.Error
    $Ui.Progress.Value = 1

    if ($Sync.Mode -eq 'scan') {
        foreach ($id in @($Sync.Results.Keys)) {
            $Rows[$id].Status = $Sync.Results[$id].Status
            $Rows[$id].Bytes = [long]$Sync.Results[$id].Bytes
            $Rows[$id].Freed = $null
        }
        $State.Phase = 'scanned'
    } else {
        $State.TotalFreed = [long]0
        $State.Skipped = 0
        $log = @('--- {0} (GUI) ---' -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))
        foreach ($id in @($Sync.Results.Keys)) {
            $res = $Sync.Results[$id]
            $Rows[$id].Status = $res.Status
            if ($null -ne $res.Freed) {
                $Rows[$id].Freed = [long]$res.Freed
                $State.TotalFreed += [long]$res.Freed
                $State.Skipped += [int]$res.Skipped
                $log += '{0}: {1}' -f $id, (Format-WcSize $res.Freed)
            }
        }
        $log += 'Total: {0}, skipped files: {1}' -f (Format-WcSize $State.TotalFreed), $State.Skipped
        try { Add-Content -LiteralPath $LogPath -Value $log -Encoding UTF8 } catch { $null = $_ }
        $State.Phase = 'cleaned'
    }
    Update-View
}

$Timer.Add_Tick({ Update-Progress })

# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------
$Ui.ScanBtn.Add_Click({
    foreach ($row in $Rows.Values) { $row.Status = ''; $row.Bytes = [long]0; $row.Freed = $null }
    Start-Work 'scan' @($Rows.Keys)
})

$Ui.CleanBtn.Add_Click({
    $selected = @(Get-SelectedRow)
    if ($selected.Count -eq 0) { return }
    $answer = [Windows.MessageBox]::Show($Window, ((T 'ConfirmBody') -f $selected.Count), (T 'ConfirmTitle'),
        [Windows.MessageBoxButton]::YesNo, [Windows.MessageBoxImage]::Question)
    if ($answer -ne [Windows.MessageBoxResult]::Yes) { return }
    Save-Choice
    Start-Work 'clean' @($selected | ForEach-Object { $_.Target.Id })
})

foreach ($row in $Rows.Values) {
    $row.Check.Add_Click({ if (-not $State.Busy) { Update-View } })
}

$Ui.AdvancedBox.Add_Click({ Update-View })

$Ui.LangBox.Add_SelectionChanged({
    $lang = $Ui.LangBox.SelectedItem.Tag
    if ($lang -and $lang -ne (Get-WcLanguage)) {
        Set-WcLanguage $lang
        if (-not $State.Busy) { Update-View }
    }
})

$Ui.WeeklyBox.Add_Click({
    $want = [bool]$Ui.WeeklyBox.IsChecked
    if (-not (Test-WcAdmin)) {
        $Ui.WeeklyBox.IsChecked = -not $want
        [void][Windows.MessageBox]::Show($Window, (T 'AdminNeeded'), 'WinCleaner')
        return
    }
    try {
        if ($want) {
            Save-Choice
            Register-WcSchedule -ScriptPath $ConsoleScript
        } else {
            Unregister-WcSchedule
        }
    } catch {
        $Ui.WeeklyBox.IsChecked = -not $want
        [void][Windows.MessageBox]::Show($Window, ((T 'Error') -f $_.Exception.Message), 'WinCleaner')
    }
})

$Window.Add_Closing({
    if ($Job.PowerShell) { $Timer.Stop(); $Job.PowerShell.Stop(); $Job.PowerShell.Dispose() }
    Save-Choice
})

function Save-WindowImage([string]$Path) {
    $root = $Window.Content
    $root.Background = $Window.Background
    $size = New-Object Windows.Size $Window.Width, $Window.Height
    $root.Measure($size)
    $root.Arrange((New-Object Windows.Rect 0, 0, $Window.Width, $Window.Height))
    $root.UpdateLayout()
    $bitmap = New-Object Windows.Media.Imaging.RenderTargetBitmap ([int]($Window.Width * 2)), ([int]($Window.Height * 2)), 192, 192, ([Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($root)
    $encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream = [IO.File]::Create($Path)
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
}

# ---------------------------------------------------------------------------
# Start
# ---------------------------------------------------------------------------
$Ui.LangBox.SelectedIndex = if ((Get-WcLanguage) -eq 'tr') { 0 } else { 1 }
$Weekly = $false
try { $Weekly = Get-WcSchedule } catch { $null = $_ }
$Ui.WeeklyBox.IsChecked = $Weekly
Update-View

if ($SelfTest) {
    foreach ($lang in 'en', 'tr') {
        Set-WcLanguage $lang
        Start-Work 'scan' @($Rows.Keys)
        if ($State.Error) { throw "Scan failed: $($State.Error)" }
        Write-Output ('[{0}] {1}' -f $lang, $Ui.Summary.Text)
        foreach ($row in $Rows.Values) {
            Write-Output ('  {0,-45} {1,12}  {2}' -f $row.NameText.Text, $row.SizeText.Text, $row.StatusText.Text)
        }
        if ($ScreenshotFolder) { Save-WindowImage (Join-Path $ScreenshotFolder "window-$lang.png") }
    }
    $Window.Close()
    return
}

[void]$Window.ShowDialog()
