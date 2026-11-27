#Requires -Version 5.1
<#
.SYNOPSIS
    Windows 10/11 gereksiz dosya ve önbellek temizleyici.

.DESCRIPTION
    Yalnızca güvenle silinebilecek geçici dosya ve önbellekleri temizler.
    Belgeler, İndirilenler, şifreler, tarayıcı geçmişi ve çerezlere DOKUNMAZ.

    Varsayılan çalışma: önce tarar, her alanın kapladığı yeri gösterir,
    sonra onay ister. Onay vermezsen hiçbir şey silinmez.

.PARAMETER Tara
    Sadece tarama yapar, hiçbir şey silmez.

.PARAMETER Evet
    Onay sormadan temizler (zamanlanmış görev için).

.EXAMPLE
    .\WinCleaner.ps1 -Tara
#>
[CmdletBinding()]
param(
    [switch]$Tara,
    [switch]$Evet
)

$ErrorActionPreference = 'Continue'

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
$LogPath = Join-Path $PSScriptRoot 'temizlik-log.txt'
$L = $env:LOCALAPPDATA
$W = $env:SystemRoot
$PD = $env:ProgramData
$script:Atlanan = 0

# Bu klasörlerin kendisi asla temizlenmez (yanlış ortam değişkenine karşı koruma).
$Yasakli = @(
    "$env:SystemDrive\", $W, $env:USERPROFILE, $L, $env:APPDATA, $PD,
    $env:ProgramFiles, ${env:ProgramFiles(x86)}
) | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\').ToLowerInvariant() }

# ---------------------------------------------------------------------------
# Temizlenecek alanlar
#   Yollar   : klasör ise İÇİ boşaltılır (klasör kalır), dosya ise dosya silinir
#   Yonetici : yönetici izni gerekir
#   MinSaat  : bu süreden yeni dosyalara dokunulmaz (çalışan kurulumlar için)
#   Islem    : bu program açıksa alan atlanır
# ---------------------------------------------------------------------------
$Hedefler = @(
    @{ Ad = 'Kullanıcı Temp klasörü'
       Yollar = @($env:TEMP); MinSaat = 24 }
    @{ Ad = 'Windows Temp klasörü'
       Yollar = @("$W\Temp"); Yonetici = $true; MinSaat = 24 }
    @{ Ad = 'Windows Update indirme önbelleği'
       Yollar = @("$W\SoftwareDistribution\Download"); Yonetici = $true
       Servisler = @('wuauserv', 'bits') }
    @{ Ad = 'Teslim İyileştirme önbelleği'
       Yollar = @("$W\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache")
       Yonetici = $true; Ozel = 'TeslimIyilestirme'; Servisler = @('DoSvc') }
    @{ Ad = 'Küçük resim ve simge önbelleği'
       Yollar = @("$L\Microsoft\Windows\Explorer\thumbcache_*.db", "$L\Microsoft\Windows\Explorer\iconcache_*.db") }
    @{ Ad = 'DirectX gölgelendirici önbelleği'
       Yollar = @("$L\D3DSCache") }
    @{ Ad = 'Microsoft Edge önbelleği'
       Yollar = @("$L\Microsoft\Edge\User Data\*\Cache", "$L\Microsoft\Edge\User Data\*\Code Cache",
                  "$L\Microsoft\Edge\User Data\*\GPUCache"); Islem = 'msedge' }
    @{ Ad = 'Google Chrome önbelleği'
       Yollar = @("$L\Google\Chrome\User Data\*\Cache", "$L\Google\Chrome\User Data\*\Code Cache",
                  "$L\Google\Chrome\User Data\*\GPUCache"); Islem = 'chrome' }
    @{ Ad = 'Mozilla Firefox önbelleği'
       Yollar = @("$L\Mozilla\Firefox\Profiles\*\cache2"); Islem = 'firefox' }
    @{ Ad = 'Uygulama çökme dökümleri'
       Yollar = @("$L\CrashDumps") }
    @{ Ad = 'Sistem hata dökümleri ve raporları'
       Yollar = @("$PD\Microsoft\Windows\WER\ReportArchive", "$PD\Microsoft\Windows\WER\ReportQueue",
                  "$W\Minidump", "$W\MEMORY.DMP"); Yonetici = $true }
    @{ Ad = 'Geri Dönüşüm Kutusu'
       Ozel = 'GeriDonusum' }
)

# ---------------------------------------------------------------------------
# Yardımcı fonksiyonlar
# ---------------------------------------------------------------------------
function Format-Boyut([long]$b) {
    if ($b -ge 1GB) { '{0:N2} GB' -f ($b / 1GB) }
    elseif ($b -ge 1MB) { '{0:N1} MB' -f ($b / 1MB) }
    else { '{0:N0} KB' -f ($b / 1KB) }
}

function Test-Baglanti([IO.FileSystemInfo]$Oge) {
    # Junction / sembolik bağlantı: içine asla girilmez
    ($Oge.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
}

function Get-HedefOgeleri($Yollar) {
    foreach ($y in $Yollar) {
        if (-not $y) { continue }
        foreach ($oge in @(Get-Item -Path $y -Force -ErrorAction SilentlyContinue)) {
            if ($Yasakli -contains $oge.FullName.TrimEnd('\').ToLowerInvariant()) { continue }
            $oge
        }
    }
}

# Hedefin altındaki silinecek öğeler: klasörse içindekiler, dosyaysa kendisi
function Get-Cocuklar([IO.FileSystemInfo]$Oge) {
    if ($Oge -is [IO.DirectoryInfo] -and -not (Test-Baglanti $Oge)) {
        try { $Oge.GetFileSystemInfos() } catch { @() }
    } else { $Oge }
}

function Get-Boyut([IO.FileSystemInfo]$Oge, [datetime]$Sinir) {
    if (Test-Baglanti $Oge) { return [long]0 }
    if ($Oge -is [IO.FileInfo]) {
        if ($Oge.LastWriteTime -lt $Sinir) { return [long]$Oge.Length } else { return [long]0 }
    }
    $t = [long]0
    try { $cocuklar = $Oge.GetFileSystemInfos() } catch { return [long]0 }
    foreach ($c in $cocuklar) { $t += Get-Boyut $c $Sinir }
    return $t
}

function Remove-Oge([IO.FileSystemInfo]$Oge, [datetime]$Sinir) {
    if (Test-Baglanti $Oge) {
        # Sadece bağlantının kendisini sil, hedefine dokunma
        try {
            if ($Oge -is [IO.DirectoryInfo]) { [IO.Directory]::Delete($Oge.FullName, $false) }
            else { $Oge.Delete() }
        } catch { }
        return [long]0
    }
    if ($Oge -is [IO.FileInfo]) {
        if ($Oge.LastWriteTime -ge $Sinir) { return [long]0 }
        $boy = [long]$Oge.Length
        try {
            if ($Oge.IsReadOnly) { $Oge.IsReadOnly = $false }
            $Oge.Delete()
            return $boy
        } catch {
            $script:Atlanan++   # kullanımda olan dosya
            return [long]0
        }
    }
    $t = [long]0
    try { $cocuklar = $Oge.GetFileSystemInfos() } catch { return [long]0 }
    foreach ($c in $cocuklar) { $t += Remove-Oge $c $Sinir }
    try {
        if ($Oge.GetFileSystemInfos().Count -eq 0) { $Oge.Delete() }
    } catch { }
    return $t
}

function Get-GeriDonusumBoyutu {
    try {
        $kabuk = New-Object -ComObject Shell.Application
        $t = [long]0
        foreach ($i in $kabuk.NameSpace(10).Items()) { $t += [long]$i.Size }
        return $t
    } catch { return [long]0 }
}

function Get-Durum($h) {
    if ($h.Yonetici -and -not $IsAdmin) { return 'Yönetici gerekli' }
    if ($h.Islem -and (Get-Process -Name $h.Islem -ErrorAction SilentlyContinue)) {
        return 'Program açık, kapatın'
    }
    return 'Hazır'
}

function Measure-Hedef($h) {
    if ($h.Ozel -eq 'GeriDonusum') { return Get-GeriDonusumBoyutu }
    $sinir = (Get-Date).AddHours(-[double]$h.MinSaat)
    $t = [long]0
    foreach ($oge in Get-HedefOgeleri $h.Yollar) {
        foreach ($c in Get-Cocuklar $oge) { $t += Get-Boyut $c $sinir }
    }
    return $t
}

function Clear-Hedef($h) {
    switch ($h.Ozel) {
        'GeriDonusum' {
            $once = Get-GeriDonusumBoyutu
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            return [long]($once - (Get-GeriDonusumBoyutu))
        }
    }

    # Teslim İyileştirme: önce Windows'un kendi komutu, kalanları aşağıda
    # servis durdurularak elle silinir (komut her şeyi silmeyebiliyor).
    $ek = [long]0
    if ($h.Ozel -eq 'TeslimIyilestirme' -and (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue)) {
        $once = Measure-Hedef $h
        Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue *> $null
        $ek = [long]([Math]::Max(0, $once - (Measure-Hedef $h)))
    }

    $durdurulan = @()
    foreach ($s in @($h.Servisler)) {
        if (-not $s) { continue }
        $srv = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($srv -and $srv.Status -eq 'Running') {
            Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
            $durdurulan += $s
        }
    }
    try {
        $sinir = (Get-Date).AddHours(-[double]$h.MinSaat)
        $t = [long]0
        foreach ($oge in Get-HedefOgeleri $h.Yollar) {
            foreach ($c in Get-Cocuklar $oge) { $t += Remove-Oge $c $sinir }
        }
        return [long]($t + $ek)
    } finally {
        foreach ($s in $durdurulan) { Start-Service -Name $s -ErrorAction SilentlyContinue }
    }
}

function Write-Log($Metin) {
    try { Add-Content -Path $LogPath -Value $Metin -Encoding UTF8 } catch { }
}

# ---------------------------------------------------------------------------
# Tarama
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '=== WinCleaner ===' -ForegroundColor Cyan
if (-not $IsAdmin) {
    Write-Host 'Uyarı: Yönetici olarak çalışmıyor. Bazı alanlar atlanacak.' -ForegroundColor Yellow
    Write-Host 'Tümünü temizlemek için WinCleaner.bat dosyasını kullanın.' -ForegroundColor Yellow
}
Write-Host 'Taranıyor, biraz sürebilir...'
Write-Host ''

$Sonuclar = @()
$No = 0
foreach ($h in $Hedefler) {
    $No++
    $durum = Get-Durum $h
    $boyut = if ($durum -eq 'Yönetici gerekli') { [long]0 } else { Measure-Hedef $h }
    $Sonuclar += [pscustomobject]@{
        No = $No; Alan = $h.Ad; Boyut = Format-Boyut $boyut; Durum = $durum
        Bayt = $boyut; Hedef = $h
    }
}

$Sonuclar | Format-Table No, Alan, @{ L = 'Boyut'; E = { $_.Boyut }; A = 'Right' }, Durum -AutoSize | Out-Host

$Hazir = @($Sonuclar | Where-Object { $_.Durum -eq 'Hazır' -and $_.Bayt -gt 0 })
$Toplam = [long]($Hazir | Measure-Object -Property Bayt -Sum).Sum
Write-Host ("Temizlenebilecek toplam alan: {0}" -f (Format-Boyut $Toplam)) -ForegroundColor Green
Write-Host '(Gerçek kazanç biraz daha az olabilir, kullanımdaki dosyalar atlanır.)'
Write-Host ''

if ($Tara) {
    Write-Host 'Sadece tarama yapıldı, hiçbir şey silinmedi.'
    return
}
if ($Hazir.Count -eq 0) {
    Write-Host 'Temizlenecek bir şey yok.'
    return
}
if (-not $Evet) {
    $cevap = Read-Host 'Bu alanlar temizlensin mi? (E/H)'
    if ($cevap -notmatch '^\s*[EeYy]') {
        Write-Host 'İptal edildi, hiçbir şey silinmedi.'
        return
    }
}

# ---------------------------------------------------------------------------
# Temizlik
# ---------------------------------------------------------------------------
Write-Host ''
$Acilan = [long]0
Write-Log ("--- {0} ---" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))
foreach ($s in $Hazir) {
    Write-Host ("Temizleniyor: {0}..." -f $s.Alan) -NoNewline
    $kazanc = Clear-Hedef $s.Hedef
    $Acilan += $kazanc
    Write-Host (" {0}" -f (Format-Boyut $kazanc)) -ForegroundColor Green
    Write-Log ("{0}: {1}" -f $s.Alan, (Format-Boyut $kazanc))
}

Write-Host ''
Write-Host ("Toplam açılan alan: {0}" -f (Format-Boyut $Acilan)) -ForegroundColor Cyan
if ($script:Atlanan -gt 0) {
    Write-Host ("Kullanımda olduğu için atlanan dosya sayısı: {0}" -f $script:Atlanan)
}
Write-Log ("Toplam: {0}, atlanan dosya: {1}" -f (Format-Boyut $Acilan), $script:Atlanan)
