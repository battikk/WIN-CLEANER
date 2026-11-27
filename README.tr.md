# WinCleaner

**Windows 10 ve 11 için açık kaynak, şeffaf temizleyici.** Sadece yer kaplayan geçici dosyaları ve önbellekleri güvenle siler.

[English](README.md)

- **Exe yok.** Çalıştırmadan önce satır satır okuyabileceğin düz PowerShell.
- **İnternet erişimi yok, veri toplama yok.** Script hiçbir yere bağlanmaz. Koda bir ağ komutu eklenirse otomatik kontrol hata verir.
- **Önce tarar, onay vermeden silmez.** Hiçbir şey silinmeden önce her alanın ne kadar yer kapladığını görürsün.

> Durum: erken sürüm. İngilizce dil, pencereli arayüz ve yeni temizlik alanları yolda (bkz. [Yol haritası](#yol-haritası)).

## Kullanım

1. [Releases](../../releases) sayfasından son zip'i indir ve ayıkla.
2. `WinCleaner.bat` dosyasına çift tıkla ve yönetici iznini onayla.
3. Alanların ve boyutların listelendiği tabloyu incele.
4. Temizlemek için `E`, hiçbir şey silmeden çıkmak için `H` yaz.

Sadece tarama: `.\WinCleaner.ps1 -Tara`
Onay sormadan temizlik (zamanlanmış görev için): `.\WinCleaner.ps1 -Evet`

## Neler temizlenir

| Alan | Not |
|---|---|
| Kullanıcı ve Windows Temp klasörleri | Son 24 saatte değişen dosyalar atlanır |
| Windows Update indirme önbelleği | Güncelleme servisi kısa süre durdurulup yeniden başlatılır |
| Teslim İyileştirme önbelleği | Önce Windows komutuyla, kalanlar servis durdurularak silinir |
| Küçük resim ve simge önbelleği | Windows gerektiğinde yeniden oluşturur |
| DirectX gölgelendirici önbelleği | Oyunlar gerektiğinde yeniden oluşturur |
| Edge, Chrome, Firefox önbellekleri | Tarayıcı açıksa atlanır |
| Çökme dökümleri ve hata raporları | |
| Geri Dönüşüm Kutusu | Geri alınamaz |

## Asla dokunulmayanlar

Belgeler, İndirilenler, Masaüstü, şifreler, çerezler, tarayıcı geçmişi, yer imleri, kurulu programlar ve sistem ayarları.

## Güvenlik

- Kullanımdaki dosyalar zorla silinmez, atlanır.
- Junction ve sembolik bağlantıların içine girilmez, hedef klasörlerin dışına çıkılamaz.
- Sürücü kökleri ve profil klasörleri sabit bir yasak listesinde.
- Her temizlik script'in yanındaki `temizlik-log.txt` dosyasına kaydedilir.

## İndirdiğin dosyayı doğrula

Her sürüm sayfasında zip'in SHA256 özeti yazar. PowerShell'de kontrol et:

```powershell
Get-FileHash .\WinCleaner.zip -Algorithm SHA256
```

Çıkan değer sürüm sayfasındakiyle aynı olmalı. Ayrıntılar için [SECURITY.md](SECURITY.md).

## Gereksinimler

Windows 10 veya 11 ve içinde hazır gelen Windows PowerShell 5.1. Ek kurulum gerekmez.

## Yol haritası

- Türkçe ve İngilizce arayüz
- Onay kutuları, ilerleme çubuğu, açık/koyu tema ile pencereli arayüz
- Yeni alanlar: Brave, Opera, Vivaldi, Discord, Teams, Spotify, ekran kartı sürücü artıkları, Windows günlükleri
- İsteğe bağlı haftalık otomatik temizlik
- Gelişmiş bölüm (varsayılan kapalı): bileşen deposu temizliği gibi ağır işlemler

## Lisans

[MIT](LICENSE)
