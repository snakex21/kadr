[English](../README.md) | [Polski](README.pl.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Italiano](README.it.md) | [Nederlands](README.nl.md) | [Čeština](README.cs.md) | [Magyar](README.hu.md) | [Română](README.ro.md) | **Türkçe** | [Ελληνικά](README.el.md) | [العربية](README.ar.md) | [עברית](README.he.md) | [हिन्दी](README.hi.md) | [বাংলা](README.bn.md) | [اردو](README.ur.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Bahasa Indonesia](README.id.md) | [Tiếng Việt](README.vi.md) | [ไทย](README.th.md) | [فارسی](README.fa.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [मराठी](README.mr.md)

# Kadr

**Windows için hızlı, küçücük ve taşınabilir bir fotoğraf görüntüleyici ve düzenleyici — Windows XP'den Windows 11'e kadar, 1 MB'ın altındaki tek bir `Kadr.exe` dosyasında.**

Kadr, [Zig](https://ziglang.org/) ile yazılmış yerel bir Win32/GDI+ uygulamasıdır. Kurulum programı yok, .NET yok, Electron yok, Node.js yok: `Kadr.exe` dosyasını istediğiniz yere kopyalayın ve çalıştırın. Ayarlar programın yanındaki `Kadr.ini` dosyasında saklanır (taşınabilir — kayıt defterine veya AppData klasörüne hiçbir şey yazılmaz).

![Kadr ana penceresi, açık tema](../docs/screenshots/main-light.png)

## İçindekiler

- [Özellikler](#özellikler)
- [Ekran görüntüleri](#ekran-görüntüleri)
- [Kadr’ı indirme / Kurulum](#kadrı-indirme--kurulum)
- [Kullanım](#kullanım)
- [Klavye kısayolları](#klavye-kısayolları)
- [Düzenleyici](#düzenleyici-1)
- [Yazdırma](#yazdırma)
- [Temalar](#temalar)
- [Ayarlar (Kadr.ini)](#ayarlar-kadrini)
- [Kaynak koddan derleme](#kaynak-koddan-derleme)
- [Testleri çalıştırma](#testleri-çalıştırma)
- [Lisans](#lisans)
- [Emeği geçenler](#emeği-geçenler)

## Özellikler

- **Görüntüleyici** — fotoğraf açma, klasörde gezinme (ok tuşları, önceki/sonraki), slayt gösterisi, tam ekran, akıcı yakınlaştırma (sığdır, 1:1, imleç konumunda fare tekerleği, `125%`, `37,5%` veya `200×` gibi elle girilen değerler), kaydırma, hareketli GIF oynatma, çok sayfalı TIFF ve DjVu, otomatik EXIF yönlendirmesi.
- **Düzenleyici** — canlı çerçeve ve hazır oranlarla kırpma (serbest, 1:1, 4:3, 3:4, 3:2, 2:3, 16:9, A4 dikey/yatay); kalem, vurgulayıcı, silgi, çizgi, ok, dikdörtgen ve metin; geri al/yinele; döndürme ve çevirme; parlaklık, kontrast, doygunluk ve siyah beyaz. Değişiklikler siz kaydedene kadar bellekte kalır.
- **Yazdırma** — kâğıt boyutu, yön, ölçek (Sığdır (tüm resim) / Doldur (kırp) / Uzat (tüm sayfa) / %100 / özel % / mm cinsinden genişlik veya yükseklik), kenar boşlukları, konum, renkli veya gri tonlamalı baskı seçenekleriyle canlı baskı önizlemesi.
- **Dosya araçları** — kaydetme (döndürme), farklı kaydetme, yeniden boyutlandırma ve boyut tahminiyle dışa aktarma / sıkıştırma (PNG, JPEG, BMP, TIFF, GIF), görüntüyü veya yolu panoya kopyalama, yeniden adlandırma, Geri Dönüşüm Kutusu'na taşıma veya kalıcı olarak silme, klasörde gösterme, masaüstü duvar kâğıdı yapma.
- **Biçimler** — PNG, JPEG/JFIF, BMP/DIB, GIF, TIFF, DjVu, ICO, WMF/EMF, TGA, PCX, PSD (birleştirilmiş görüntü), PBM/PGM/PPM/PNM, QOI.
- **30 arayüz dili** — Windows dili otomatik olarak algılanır (algılanamazsa İngilizce kullanılır) ve menüden değiştirilebilir; Arapça, İbranice, Urduca ve Farsça için sağdan sola düzen.
- **Temalar** — açık, koyu veya otomatik (Windows uygulama modunu izler, anında değişir).
- **Küçük** — 1 MB'tan küçük tek bir `Kadr.exe`.
- **Windows XP ve sonrası** — Windows XP SP3 (x86) sürümünden Windows 10/11'e kadar çalışır.

## Ekran görüntüleri

| Açık tema | Koyu tema |
|---|---|
| ![Ana pencere, açık tema](../docs/screenshots/main-light.png) | ![Ana pencere, koyu tema](../docs/screenshots/main-dark.png) |

**Düzenleyici** — 3:2 oranlı kırpma çerçevesi, kalem, vurgulayıcı, ok, dikdörtgen ve metin:

![Kırpma çerçevesi ve çizimlerle düzenleyici](../docs/screenshots/editor-crop.png)

*Uzat (tüm sayfa)* modunda **baskı önizleme**:

![Baskı önizleme, Uzat modu](../docs/screenshots/print-stretch.png)

*Tema* alt menüsüyle birlikte **"Daha fazla" (…) menüsü**:

![Tema alt menüsüyle Daha fazla menüsü](../docs/screenshots/more-menu.png)

## Kadr’ı indirme / Kurulum

1. `Kadr.exe` dosyasını [Releases sayfasından](https://github.com/snakex21/kadr/releases) indirin (deponun kök klasöründe de hazır bir `Kadr.exe` bulunur).
2. Dosyayı yazma izniniz olan herhangi bir klasöre (örneğin bir USB belleğe) koyun ve çalıştırın. Kurulum programı yoktur.
3. DjVu dosyaları için depodaki `deps\djvu\` klasörünü `Kadr.exe` dosyasının yanında tutun.

Resimleri çift tıklamayla açmak için Windows'ta bir resme sağ tıklayıp *Birlikte aç → Başka bir uygulama seç* seçeneğini kullanın ve `Kadr.exe` dosyasını seçin.

**Gereksinimler:** Windows XP SP3 x86 veya daha yenisi (Windows 10/11 de çalışır). Başka hiçbir şey gerekmez.

> DjVu kod çözücüsü eski DjVuLibre 3.5.27 sürümüdür — yalnızca güvendiğiniz DjVu dosyalarını açın (ayrıntılar `THIRD-PARTY.txt` dosyasında).

## Kullanım

- Bir resmi **Aç** (Ctrl+O) ile, dosyayı pencereye sürükleyerek veya komut satırında vererek **açın**: `Kadr.exe photo.jpg`.
- Klasörde ← / → tuşlarıyla veya ok düğmeleriyle **gezinin**; sayaç konumu gösterir (örn. `1 / 3`). Hızlı gezinmek için ok tuşunu basılı tutun.
- Fare tekerleğiyle (imlecin bulunduğu yere yakınlaştırır), `+` / `−`, **Sığdır** (Home), **1:1** (`1`) ile **yakınlaştırın** veya yakınlaştırma alanına bir değer yazıp Enter'a basın. Kaydırmak için resmi sürükleyin.
- R / L ile **döndürün**. Yalnızca görünüm döndürülür; **Kaydet** (Ctrl+S) döndürmeyi dosyaya yazar.
- **Daha fazla (…)**, tüm dosya işlemlerini, düzenleyiciyi, yazdırmayı, slayt gösterisini, tam ekranı, yardımı, *Güncellemeleri denetle…*, *Tema* ve *Dil* öğelerini içeren menüyü açar.
- **Güncellemeleri denetle…** yalnızca projenin GitHub sürümler sayfasını web tarayıcınızda açar — Kadr'ın kendisi hiçbir zaman internete bağlanmaz.

## Klavye kısayolları

### Görüntüleyici

| Kısayol | İşlem |
|---|---|
| Ctrl+O | Aç |
| Ctrl+S | Kaydet (döndürmeyi geçerli dosyaya yazar) |
| Ctrl+Shift+S | Farklı kaydet |
| Ctrl+E | Resmi düzenle |
| Ctrl+P | Yazdır |
| Ctrl+C | Görüntüyü kopyala |
| Ctrl+Shift+C | Yolu kopyala |
| F2 | Yeniden adlandır |
| Delete | Geri Dönüşüm Kutusu’na taşı |
| Shift+Delete | Kalıcı olarak sil |
| ← / → | Klasördeki önceki / sonraki resim (hızlı gezinmek için basılı tutun) |
| Home | Pencereye sığdır |
| 1 | Gerçek boyut (1:1) |
| + / − (sayısal tuş takımında da) | Yakınlaştır / uzaklaştır |
| Fare tekerleği | İmleç konumunda yakınlaştırma |
| Sol tuşla sürükleme | Kaydırma |
| Çift tıklama | Tam ekranı aç / kapat |
| R / L | Sağa / sola döndür |
| Boşluk | Animasyonu duraklat / sürdür |
| Page Up / Page Down | Önceki / sonraki sayfa (TIFF, DjVu) |
| F5 | Slayt gösterisi (4 saniyede bir) |
| F11 | Tam ekran |
| Esc | Tam ekrandan çık, slayt gösterisini durdur |
| F1 | Yardım ve kısayollar |
| Shift+F10 veya Menü tuşu | "Daha fazla" menüsü (resme sağ tıklayarak da açılır) |
| Tab / Shift+Tab, Enter veya Boşluk | Araç çubuğu düğmeleri arasında gezinme ve onlara basma |

### Yakınlaştırma alanı

| Kısayol | İşlem |
|---|---|
| Enter | Yazılan yakınlaştırmayı uygula (`125%`, `37,5%`, `200×` …) |
| Esc | Geçerli değeri geri yükle |
| Ctrl+A | Tümünü seç |

### Düzenleyici

| Kısayol | İşlem |
|---|---|
| C | Kırp |
| P | Kalem |
| H | Vurgulayıcı |
| E | Silgi |
| L | Çizgi |
| A | Ok |
| B | Dikdörtgen |
| T | Metin |
| Ctrl+Z | Geri al |
| Ctrl+Y veya Ctrl+Shift+Z | Yinele |
| Enter (Kırp aracı) veya çift tıklama | Karartılmış kısmı kesip at |
| Enter / Esc (metin yazarken) | Metni bitir / iptal et |
| Esc | Düzenleyiciyi değişiklik yapmadan kapat |

### Baskı önizleme

| Kısayol | İşlem |
|---|---|
| Resmi sayfa üzerinde sürükleme | Resmin konumunu değiştirir |
| Esc | Önizlemeyi kapat (devam eden yazdırma işini iptal eder) |

## Düzenleyici

Düzenleyiciyi **Düzenle** (Ctrl+E) ile açın. Tüm değişiklikler bellekte tutulur; siz kaydedene kadar özgün dosyaya dokunulmaz.

- **Kırp** — sekiz tutamaçlı canlı bir çerçeve; çerçeveyi veya tutamaçlarını sürükleyin, piksel cinsinden tam X / Y / genişlik / yükseklik değerlerini yazın ya da hazır bir oran seçin (serbest, kare 1:1, 4:3, 3:4, 3:2 (4×6 yatay), 2:3, 16:9, A4 dikey, A4 yatay). Çerçevenin dışındaki alan karartılır; **Kırp** (Enter) bu alanı keser, **Tüm fotoğraf** ise çerçeveyi sıfırlar.
- **Çizim** — kalem, yarı saydam vurgulayıcı, silgi (yalnızca çizimleri ve metni siler, fotoğrafı asla), düz çizgi, ok, dikdörtgen ve metin; on renk ve ayarlanabilir kalınlık.
- **Resim** — geri al / yinele, 90° sola veya sağa döndürme, yatay veya dikey aynalama, tümünü sıfırlama.
- **Renk ve ışık** — parlaklık, kontrast, doygunluk ve siyah beyaz.
- **Bitirme** — *Uygula* düzenlenen resmi görüntüleyiciye geri gönderir, *Farklı kaydet…* bir kopyayı yeni adla kaydeder, *Yazdır…* doğrudan baskı önizlemesine geçer, *İptal* (Esc) değişiklikleri atar.

## Yazdırma

**Yazdır** (Ctrl+P) sayfanın canlı önizlemesini açar. Yazıcıyı, kâğıdı (A3–A6, B4/B5, Letter, Legal, Executive, Tabloid, 10×15, 13×18, 15×20, 20×25 cm, 4×6, 5×7, 8×10 in fotoğraf boyutları, özel boyut veya yazıcının kendi boyutu), yönü ve renkli ya da gri tonlamalı baskıyı seçin. Siz değiştirene kadar yön resme göre otomatik ayarlanır.

Ölçek modları:

| Mod | Ne yapar |
|---|---|
| **Sığdır (tüm resim)** | Resmin tamamı kenar boşluklarının içine sığar; oranlar korunur, iki kenarda beyaz boşluk kalabilir. |
| **Doldur (kırp)** | Resim yazdırılabilir alanın tamamını kaplar; oranlar korunur ve taşan kenarlar kırpılır. |
| **Uzat (tüm sayfa)** | Resim tam olarak yazdırılabilir alana uzatılır — beyaz şerit kalmaz, ancak oranlar **korunmaz**. |
| **100% · Gerçek boyut (96 DPI)** | Bir piksel = 1/96 inç. |
| **Özel yüzde** | 96 DPI'ya göre %0,1–1000 (%100 = yukarıdaki boyut). |
| **Genişlik (mm) / Yükseklik (mm)** | Tam fiziksel genişlik veya yükseklik; diğer kenar oranlara göre belirlenir. |

**Gelişmiş ▸** özel kâğıt boyutu, kenar boşlukları ve sayfa üzerinde tam konum ayarlarını ekler (ya da resmi önizlemede sürükleyin; *Ortala* resmi yeniden ortaya alır). Gri çizgi, yazıcının donanımsal sınırını gösterir. Son seçilen ölçek modu `Kadr.ini` dosyasında hatırlanır.

## Temalar

**Daha fazla (…) → Tema**; **Açık**, **Koyu** ve **Otomatik** (varsayılan) seçeneklerini sunar.

- **Otomatik**, Windows *uygulama modunu* (Ayarlar → Kişiselleştirme → Renkler, `AppsUseLightTheme` değeri) izler ve bunu Windows'ta değiştirdiğinizde anında geçiş yapar. Bu ayarın bulunmadığı sistemlerde (Windows XP, Vista, 7, 8) Otomatik, Açık anlamına gelir.
- Tema; ana pencereyi, araç çubuğunu, düğmeleri ve simgeleri, düzenleyiciyi, baskı önizlemesini ve Kadr'ın kendi iletişim kutularını kapsar. Koyu modda resim arka planı koyu gridir; Windows 10/11'de başlık çubukları ve açılır menüler de koyu olur.
- Bazı yerel Windows bileşenleri sistem görünümünü korur: ileti kutuları (yardım, onaylar), Aç / Kaydet / Yazdır sistem iletişim kutuları ve kaydırıcı tutamaçları.

## Ayarlar (Kadr.ini)

Tüm ayarlar `Kadr.exe` dosyasının yanındaki `Kadr.ini` dosyasında saklanır. Klasör salt okunursa Kadr, ayarların kaydedilemeyeceğini bildirir.

```ini
[General]
Language=en      ; pl, en, es, fr, de, pt, ru, uk, it, nl, cs, hu, ro, tr, el, ar, he, hi, bn, ur, zh, ja, ko, id, vi, th, fa, ta, te, mr
Theme=auto       ; auto, light or dark
[Print]
Scale=fit        ; fit, fill, stretch, actual, percent, width or height
```

Dil, **Daha fazla (…) → Dil** üzerinden de seçilebilir; değişiklik Kadr yeniden başlatıldıktan sonra geçerli olur. Tema ise hemen uygulanır.

Arayüz dilleri: Polski, English, Español, Français, Deutsch, Português, Русский, Українська, Italiano, Nederlands, Čeština, Magyar, Română, Türkçe, Ελληνικά, العربية, עברית, हिन्दी, বাংলা, اردو, 中文, 日本語, 한국어, Bahasa Indonesia, Tiếng Việt, ไทย, فارسی, தமிழ், తెలుగు, मराठी.

## Kaynak koddan derleme

Gereksinimler: `tools\zig-windows-x86_64-0.11.0\` klasörüne açılmış [Zig 0.11.0](https://ziglang.org/download/0.11.0/zig-windows-x86_64-0.11.0.zip) (arşiv deponun parçası değildir; SHA-256 değeri `THIRD-PARTY.txt` dosyasındadır).

```bat
build.cmd
```

Sonuç, XP uyumlu PE başlığına sahip `Kadr.exe` dosyasıdır (hedef `x86-windows.xp`, Pentium III, `ReleaseSmall`). Simgeyi yeniden oluşturmak için: `tools\build_icon.cmd` (Pillow + windres/objcopy).

Kadr yalnızca Windows XP'de bulunan kitaplıklara bağlanır. Daha yeni özellikler (koyu başlık çubukları, koyu menüler ve denetimler) çalışma zamanında `LoadLibrary` / `GetProcAddress` ile yüklenir ve eski sistemlerde atlanır.

## Testleri çalıştırma

- Test paketleri `tests\` alt klasörlerinde bulunur (`editor-check`, `print-options`, `loader-check`, `image-check`, `codec-check`, `render-check`, `export-check`); her biri, Zig test düzeneklerini derleyip çalıştıran kendi `check.cmd` dosyasıyla başlatılır. `tests\editor-check\check.cmd`; ana pencere testlerini (tema ayarı ve tema çözümleme testleri dahil), düzenleyici testlerini, dil kapsamı denetimini ve bir x86/XP aday derlemesini çalıştırır; `tests\print-options\check.cmd` yazdırma ve düzen testlerini çalıştırır.
- Tek tek modüllerdeki birim testleri `zig test` ile çalıştırılabilir; örn. `zig test src\toolbar.zig`, `src\navigation.zig`, `src\image.zig`, `src\zoom.zig`, `src\theme.zig` (`check.cmd` içindekiyle aynı hedef ve include bayraklarıyla).
- Python 3 yardımcıları: `python tests\i18n-check\run.py` (dil seçimi), `python tests\locale_coverage.py` (tüm arayüz metinleri 30 dil için katalogda mı), `python tests\audit_xp.py` (`Kadr.exe` için XP içe aktarma/başlık denetimi), `tests\measure_print.py`, `tests\tooltip_probe.py`, `tests\shot.py`.
- `tests\generate_fixtures.py` test görüntüleri oluşturur (Pillow gerektirir); yalnızca geliştirme sırasında kullanılır, `Kadr.exe` tarafından asla kullanılmaz.

## Lisans

**GPL-3.0-or-later** — tam metin [`LICENSE`](../LICENSE) dosyasındadır.

Üçüncü taraf bileşenler ve lisansları (DjVuLibre, VC100/GDI+, Zig): [`THIRD-PARTY.txt`](../THIRD-PARTY.txt). DjVuLibre için GNU GPL v2 metni: [`COPYING.txt`](../COPYING.txt).

Bu bir çeviridir; esas alınan metin İngilizce sürümdür ([README.md](../README.md)).

## Emeği geçenler

- Win32 ve GDI+ üzerinde [Zig](https://ziglang.org/) ile geliştirilmiştir.
- DjVu kod çözme: [DjVuLibre](https://djvu.sourceforge.net/) 3.5.27 (GPL-2.0-or-later).
- Arayüz simgeleri ve Kadr logosu projeye ait özgün çalışmalardır (`src/ui.zig`, `tools/make_icon.py`).
- Ekran görüntülerindeki resimler bu README için üretilmiş yapay görüntülerdir.
