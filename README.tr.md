# WinCleaner

**Windows 10 ve 11 için açık kaynak, şeffaf temizleyici.** Sadece yer kaplayan geçici dosyaları ve önbellekleri güvenle siler.

[English](README.md)

- **Exe yok.** Çalıştırmadan önce satır satır okuyabileceğin düz PowerShell.
- **İnternet erişimi yok, veri toplama yok.** Script hiçbir yere bağlanmaz. Koda bir ağ komutu eklenirse otomatik kontrol hata verir.
- **Önce tarar, onay vermeden silmez.** Hiçbir şey silinmeden önce her alanın ne kadar yer kapladığını görürsün.

## Kullanım

1. [Releases](../../releases) sayfasından son zip'i indir ve ayıkla.
2. `WinCleaner.bat` dosyasına çift tıkla ve yönetici iznini onayla. WinCleaner penceresi açılır.
3. **Tara** düğmesine bas. Tarama hiçbir şeyi silmez.
4. Temizlemek istemediğin alanların işaretini kaldır, **Temizle** düğmesine bas ve onayla.

Pencere, Windows'un açık ya da koyu temasına uyar. **Haftalık otomatik temizlik** kutusunu işaretlersen aynı seçimlerle her Pazar çalışır.

Konsolu mu tercih edersin? `WinCleaner-Console.bat` bir tablo gösterir ve temizlemeden önce `E/H` sorar.

Dil, Windows'un görüntü diline göre seçilir (Türkçe ya da İngilizce).

### Komut satırı seçenekleri

| Seçenek | Ne yapar |
|---|---|
| `-Tara` (`-Scan`) | Sadece tarar, hiçbir şey silmez |
| `-Evet` (`-Yes`) | Onay sormadan temizler |
| `-Advanced` | Gelişmiş alanları da çalıştırır (Windows bileşen deposu temizliği, uzun sürer) |
| `-Language tr` / `-Language en` | Dili zorla seçer |
| `-InstallSchedule` | Haftalık temizlik ekler: her Pazar 12:00 (bilgisayar kapalıysa ilk açılışta) |
| `-RemoveSchedule` | Haftalık temizliği kaldırır |

Örnek: `.\WinCleaner.ps1 -Tara`

### Ayarlar

Alanları kapatmak ya da varsayılanları değiştirmek için `settings.example.json` dosyasını `settings.json` adıyla kopyala. Alan kimlikleri `src/WinCleaner.Core.psm1` dosyasında yazar.

## Neler temizlenir

| Alan | Not |
|---|---|
| Kullanıcı ve Windows Temp klasörleri | Son 24 saatte değişen dosyalar atlanır |
| Windows Update indirme önbelleği | Güncelleme servisi kısa süre durdurulup yeniden başlatılır |
| Teslim İyileştirme önbelleği | Önce Windows komutuyla, kalanlar servis durdurularak silinir |
| Küçük resim ve simge önbelleği | Windows gerektiğinde yeniden oluşturur |
| DirectX gölgelendirici önbelleği | Oyunlar gerektiğinde yeniden oluşturur |
| Ekran kartı gölgelendirici önbelleği (NVIDIA, AMD) | Sürücü gerektiğinde yeniden oluşturur |
| Ekran kartı sürücü kurulum artıkları | `C:\NVIDIA`, `C:\AMD` ve NVIDIA indirme klasörünün içi |
| Edge, Chrome, Brave, Vivaldi, Opera, Firefox önbellekleri | Tarayıcı açıksa atlanır |
| Discord ve Microsoft Teams önbellekleri | Uygulama açıksa atlanır |
| Çökme dökümleri ve hata raporları | |
| Eski Windows günlük dosyaları | Son 7 günün günlükleri korunur |
| Geri Dönüşüm Kutusu | Geri alınamaz |
| *Gelişmiş:* Windows bileşen deposu | `DISM /StartComponentCleanup` çalıştırır, sadece `-Advanced` ile |

## Asla dokunulmayanlar

Belgeler, İndirilenler, Masaüstü, şifreler, çerezler, tarayıcı geçmişi, yer imleri, kurulu programlar ve sistem ayarları.

## Güvenlik

- Kullanımdaki dosyalar zorla silinmez, atlanır.
- Junction ve sembolik bağlantıların içine girilmez, hedef klasörlerin dışına çıkılamaz.
- Sürücü kökleri ve profil klasörleri sabit bir yasak listesinde.
- Her temizlik script'in yanındaki `WinCleaner.log` dosyasına kaydedilir.

## İndirdiğin dosyayı doğrula

Her sürüm sayfasında zip'in SHA256 özeti yazar. PowerShell'de kontrol et:

```powershell
Get-FileHash .\WinCleaner.zip -Algorithm SHA256
```

Çıkan değer sürüm sayfasındakiyle aynı olmalı. Ayrıntılar için [SECURITY.md](SECURITY.md).

## Gereksinimler

Windows 10 veya 11 ve içinde hazır gelen Windows PowerShell 5.1. Ek kurulum gerekmez.

## Yol haritası

- [x] Türkçe ve İngilizce arayüz
- [x] Yeni alanlar: Brave, Opera, Vivaldi, Discord, Teams, ekran kartı önbellekleri ve kurulum artıkları, Windows günlükleri
- [x] İsteğe bağlı haftalık otomatik temizlik
- [x] Gelişmiş bölüm (varsayılan kapalı)
- [x] Onay kutuları, ilerleme çubuğu, açık/koyu tema ile pencereli arayüz

## Lisans

[MIT](LICENSE)
