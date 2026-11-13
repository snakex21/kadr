[English](README.md) | [Polski](README.pl.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Italiano](README.it.md) | [Nederlands](README.nl.md) | [Čeština](README.cs.md) | [Magyar](README.hu.md) | [Română](README.ro.md) | [Türkçe](README.tr.md) | [Ελληνικά](README.el.md) | [العربية](README.ar.md) | [עברית](README.he.md) | [हिन्दी](README.hi.md) | [বাংলা](README.bn.md) | [اردو](README.ur.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Bahasa Indonesia](README.id.md) | **Tiếng Việt** | [ไทย](README.th.md) | [فارسی](README.fa.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [मराठी](README.mr.md)

# Kadr

**Trình xem và chỉnh sửa ảnh nhanh, siêu nhỏ, di động cho Windows — từ Windows XP đến Windows 11, gói gọn trong một tệp `Kadr.exe` dưới 1 MB.**

Kadr là ứng dụng Win32/GDI+ gốc được viết bằng [Zig](https://ziglang.org/). Không cần trình cài đặt, không .NET, không Electron, không Node.js: chỉ cần chép `Kadr.exe` vào bất kỳ đâu và chạy. Cài đặt được lưu trong `Kadr.ini` cạnh chương trình (di động — không ghi gì vào registry hay AppData).

![Cửa sổ chính của Kadr, chủ đề sáng](docs/screenshots/main-light.png)

## Mục lục

- [Tính năng](#tính-năng)
- [Ảnh chụp màn hình](#ảnh-chụp-màn-hình)
- [Tải về / Cài đặt](#tải-về--cài-đặt)
- [Cách dùng](#cách-dùng)
- [Phím tắt](#phím-tắt)
- [Trình chỉnh sửa](#trình-chỉnh-sửa-1)
- [In](#in)
- [Chủ đề](#chủ-đề)
- [Cài đặt (Kadr.ini)](#cài-đặt-kadrini)
- [Biên dịch từ mã nguồn](#biên-dịch-từ-mã-nguồn)
- [Chạy kiểm thử](#chạy-kiểm-thử)
- [Giấy phép](#giấy-phép)
- [Ghi công](#ghi-công)

## Tính năng

- **Trình xem** — mở ảnh, duyệt thư mục (phím mũi tên, trước/sau), trình chiếu, toàn màn hình, thu phóng mượt (vừa khung, 1:1, con lăn chuột tại vị trí con trỏ, nhập giá trị như `125%`, `37,5%` hoặc `200×`), kéo để di chuyển ảnh, phát GIF động, TIFF và DjVu nhiều trang, tự xoay theo hướng EXIF.
- **Trình chỉnh sửa** — cắt ảnh với khung trực tiếp và các tỷ lệ có sẵn (tự do, 1:1, 4:3, 3:4, 3:2, 2:3, 16:9, A4 dọc/ngang); bút, bút đánh dấu, tẩy, đường thẳng, mũi tên, hình chữ nhật và chữ; hoàn tác/làm lại; xoay và lật; độ sáng, độ tương phản, độ bão hòa và đen trắng. Các thay đổi chỉ nằm trong bộ nhớ cho đến khi bạn lưu.
- **In** — xem trước bản in trực tiếp với khổ giấy, hướng, tỷ lệ (Vừa khung / Lấp đầy (cắt) / Kéo giãn (cả trang) / 100% / % tùy chỉnh / chiều rộng hoặc chiều cao theo mm), lề, vị trí, in màu hoặc thang xám.
- **Công cụ tệp** — lưu (góc xoay), lưu thành, xuất / nén (PNG, JPEG, BMP, TIFF, GIF) kèm đổi kích thước và ước tính dung lượng, sao chép ảnh hoặc đường dẫn vào bộ nhớ tạm, đổi tên, chuyển vào Thùng rác hoặc xóa vĩnh viễn, hiện trong thư mục, đặt làm hình nền màn hình.
- **Định dạng** — PNG, JPEG/JFIF, BMP/DIB, GIF, TIFF, DjVu, ICO, WMF/EMF, TGA, PCX, PSD (ảnh đã gộp lớp), PBM/PGM/PPM/PNM, QOI.
- **30 ngôn ngữ giao diện** — ngôn ngữ của Windows được nhận diện tự động (mặc định về tiếng Anh nếu không có) và có thể đổi từ menu; bố cục từ phải sang trái cho tiếng Ả Rập, tiếng Hebrew, tiếng Urdu và tiếng Ba Tư.
- **Chủ đề** — sáng, tối hoặc tự động (theo chế độ ứng dụng của Windows, chuyển đổi ngay lập tức).
- **Nhỏ gọn** — chỉ một tệp `Kadr.exe` nhỏ hơn 1 MB.
- **Windows XP trở lên** — chạy từ Windows XP SP3 (x86) đến Windows 10/11.

## Ảnh chụp màn hình

| Chủ đề sáng | Chủ đề tối |
|---|---|
| ![Cửa sổ chính, chủ đề sáng](docs/screenshots/main-light.png) | ![Cửa sổ chính, chủ đề tối](docs/screenshots/main-dark.png) |

**Trình chỉnh sửa** — khung cắt với tỷ lệ 3:2, bút, bút đánh dấu, mũi tên, hình chữ nhật và chữ:

![Trình chỉnh sửa với khung cắt và hình vẽ](docs/screenshots/editor-crop.png)

**Xem trước khi in** ở chế độ *Stretch (whole page)* (Kéo giãn: cả trang):

![Xem trước khi in, chế độ Kéo giãn](docs/screenshots/print-stretch.png)

**Menu "Thêm" (…)** với menu con *Chủ đề*:

![Menu Thêm với menu con Chủ đề](docs/screenshots/more-menu.png)

## Tải về / Cài đặt

1. Tải `Kadr.exe` từ [trang Releases](https://github.com/snakex21/kadr/releases) (một bản `Kadr.exe` dựng sẵn cũng có trong thư mục gốc của kho mã).
2. Đặt nó vào bất kỳ thư mục nào bạn có quyền ghi (ví dụ USB) và chạy. Không có trình cài đặt.
3. Để mở tệp DjVu, hãy giữ thư mục `deps\djvu\` từ kho mã ở cạnh `Kadr.exe`.

Để mở ảnh bằng nhấp đúp, hãy dùng *Mở bằng → Chọn ứng dụng khác* của Windows trên một tệp ảnh và chọn `Kadr.exe`.

**Yêu cầu:** Windows XP SP3 x86 trở lên (Windows 10/11 cũng chạy được). Không cần gì khác.

> Bộ giải mã DjVu là DjVuLibre 3.5.27 phiên bản cũ — chỉ mở các tệp DjVu mà bạn tin cậy (chi tiết trong `THIRD-PARTY.txt`).

## Cách dùng

- **Mở** ảnh bằng nút **Mở** (Ctrl+O), kéo tệp vào cửa sổ hoặc truyền qua dòng lệnh: `Kadr.exe photo.jpg`.
- **Duyệt** thư mục bằng ← / → hoặc các nút mũi tên; bộ đếm cho biết vị trí (ví dụ `1 / 3`). Giữ phím mũi tên để duyệt nhanh.
- **Thu phóng** bằng con lăn chuột (phóng tại vị trí con trỏ), `+` / `−`, **Vừa khung** (Home), **1:1** (`1`) hoặc nhập giá trị vào ô thu phóng rồi nhấn Enter. Kéo ảnh để di chuyển.
- **Xoay** bằng R / L. Chỉ phần hiển thị được xoay; **Lưu** (Ctrl+S) ghi góc xoay vào tệp.
- **Thêm (…)** mở menu chứa mọi thao tác tệp, trình chỉnh sửa, in, trình chiếu, toàn màn hình, trợ giúp, *Kiểm tra cập nhật…*, *Chủ đề* và *Ngôn ngữ*.
- **Kiểm tra cập nhật…** chỉ mở trang phát hành của dự án trên GitHub trong trình duyệt web — bản thân Kadr không bao giờ kết nối Internet.

## Phím tắt

### Trình xem

| Phím tắt | Thao tác |
|---|---|
| Ctrl+O | Mở |
| Ctrl+S | Lưu (ghi góc xoay vào tệp hiện tại) |
| Ctrl+Shift+S | Lưu thành |
| Ctrl+E | Chỉnh sửa ảnh |
| Ctrl+P | In |
| Ctrl+C | Sao chép ảnh |
| Ctrl+Shift+C | Sao chép đường dẫn |
| F2 | Đổi tên |
| Delete | Chuyển vào Thùng rác |
| Shift+Delete | Xóa vĩnh viễn |
| ← / → | Ảnh trước / tiếp theo trong thư mục (giữ để duyệt nhanh) |
| Home | Vừa cửa sổ |
| 1 | Kích thước thật (1:1) |
| + / − (cả bàn phím số) | Phóng to / Thu nhỏ |
| Con lăn chuột | Thu phóng tại vị trí con trỏ |
| Kéo bằng nút trái | Di chuyển ảnh |
| Nhấp đúp | Bật / tắt toàn màn hình |
| R / L | Xoay phải / trái |
| Space | Tạm dừng / tiếp tục hoạt ảnh |
| Page Up / Page Down | Trang trước / tiếp theo (TIFF, DjVu) |
| F5 | Trình chiếu (mỗi 4 giây) |
| F11 | Toàn màn hình |
| Esc | Thoát toàn màn hình, dừng trình chiếu |
| F1 | Trợ giúp và phím tắt |
| Shift+F10 hoặc phím Menu | Menu "Thêm" (hoặc nhấp chuột phải lên ảnh) |
| Tab / Shift+Tab, Enter hoặc Space | Di chuyển giữa các nút trên thanh công cụ và nhấn chúng |

### Ô thu phóng

| Phím tắt | Thao tác |
|---|---|
| Enter | Áp dụng mức thu phóng đã nhập (`125%`, `37,5%`, `200×` …) |
| Esc | Khôi phục giá trị hiện tại |
| Ctrl+A | Chọn tất cả |

### Trình chỉnh sửa

| Phím tắt | Thao tác |
|---|---|
| C | Cắt |
| P | Pen (bút) |
| H | Highlighter (bút đánh dấu) |
| E | Eraser (tẩy) |
| L | Line (đường thẳng) |
| A | Arrow (mũi tên) |
| B | Rectangle (hình chữ nhật) |
| T | Text (chữ) |
| Ctrl+Z | Undo (hoàn tác) |
| Ctrl+Y hoặc Ctrl+Shift+Z | Redo (làm lại) |
| Enter (công cụ Cắt) hoặc nhấp đúp | Cắt bỏ phần bị làm tối |
| Enter / Esc (khi đang nhập chữ) | Hoàn tất / hủy chữ |
| Esc | Đóng trình chỉnh sửa mà không thay đổi |

### Xem trước khi in

| Phím tắt | Thao tác |
|---|---|
| Kéo ảnh trên trang giấy | Thay đổi vị trí của ảnh |
| Esc | Đóng bản xem trước (hủy lệnh in đang chạy) |

## Trình chỉnh sửa

Mở trình chỉnh sửa bằng **Edit** (Chỉnh sửa; Ctrl+E). Mọi thay đổi được giữ trong bộ nhớ; tệp gốc không bị động đến cho đến khi bạn lưu.

- **Cắt** — khung trực tiếp với tám tay nắm; kéo khung hoặc các tay nắm, nhập chính xác X / Y / chiều rộng / chiều cao theo pixel, hoặc chọn tỷ lệ có sẵn (tự do, vuông 1:1, 4:3, 3:4, 3:2 (4×6 ngang), 2:3, 16:9, A4 dọc, A4 ngang). Vùng bên ngoài khung bị làm tối; **Cắt** (Enter) cắt bỏ vùng đó và **Whole photo** (toàn bộ ảnh) đặt lại khung.
- **Vẽ** — bút, bút đánh dấu bán trong suốt, tẩy (chỉ xóa nét vẽ và chữ, không bao giờ xóa ảnh), đường thẳng, mũi tên, hình chữ nhật và chữ, với mười màu và độ dày điều chỉnh được.
- **Hình ảnh** — hoàn tác / làm lại, xoay 90° sang trái hoặc phải, lật ngang hoặc dọc, đặt lại tất cả.
- **Màu sắc và ánh sáng** — độ sáng, độ tương phản, độ bão hòa và đen trắng.
- **Hoàn tất** — *Áp dụng* đưa ảnh đã chỉnh sửa về trình xem, *Save as…* (Lưu thành…) lưu bản sao với tên mới, *Print…* (In…) chuyển thẳng đến bản xem trước khi in, *Hủy* (Esc) bỏ các thay đổi.

## In

**In** (Ctrl+P) mở bản xem trước trực tiếp của trang giấy. Chọn máy in, giấy (A3–A6, B4/B5, Letter, Legal, Executive, Tabloid, khổ ảnh 10×15, 13×18, 15×20, 20×25 cm, 4×6, 5×7, 8×10 in, tùy chỉnh hoặc khổ của máy in), hướng giấy và in màu hoặc thang xám. Hướng giấy tự động theo ảnh cho đến khi bạn thay đổi.

Các chế độ tỷ lệ:

| Chế độ | Tác dụng |
|---|---|
| **Vừa khung** | Toàn bộ ảnh nằm trong lề; giữ nguyên tỷ lệ, có thể còn khoảng trắng ở hai cạnh. |
| **Lấp đầy / cắt** | Ảnh phủ kín toàn bộ vùng in được; giữ nguyên tỷ lệ và các mép thừa bị cắt bỏ. |
| **Stretch (whole page)** (Kéo giãn: cả trang) | Ảnh được kéo giãn vừa khít vùng in được — không có dải trắng, nhưng tỷ lệ **không** được giữ nguyên. |
| **100% · Kích thước thật (96 DPI)** | Một pixel = 1/96 inch. |
| **Phần trăm tùy chỉnh** | 0,1–1000 % so với 96 DPI (100% = kích thước ở trên). |
| **Chiều rộng / Chiều cao (mm)** | Chiều rộng hoặc chiều cao vật lý chính xác; cạnh còn lại theo tỷ lệ. |

**Nâng cao ▸** bổ sung khổ giấy tùy chỉnh, lề và vị trí chính xác trên trang giấy (hoặc kéo ảnh trong bản xem trước; *Căn giữa* đưa ảnh về chính giữa). Đường màu xám cho biết giới hạn phần cứng của máy in. Chế độ tỷ lệ chọn gần nhất được ghi nhớ trong `Kadr.ini`.

## Chủ đề

**Thêm (…) → Chủ đề** có **Sáng**, **Tối** và **Tự động** (mặc định).

- **Tự động** theo *chế độ ứng dụng* của Windows (Cài đặt → Cá nhân hóa → Màu sắc, giá trị `AppsUseLightTheme`) và chuyển đổi ngay khi bạn thay đổi trong Windows. Trên các hệ thống không có thiết lập này (Windows XP, Vista, 7, 8), Tự động nghĩa là Sáng.
- Chủ đề áp dụng cho cửa sổ chính, thanh công cụ, các nút và biểu tượng, trình chỉnh sửa, bản xem trước khi in và các hộp thoại riêng của Kadr. Ở chế độ tối, nền ảnh có màu xám đậm, và trên Windows 10/11 thanh tiêu đề cùng menu bật lên cũng tối.
- Một số thành phần gốc của Windows vẫn giữ giao diện hệ thống: hộp thông báo (trợ giúp, xác nhận), các hộp thoại hệ thống Mở / Lưu / In và núm thanh trượt.

## Cài đặt (Kadr.ini)

Mọi cài đặt được lưu trong `Kadr.ini` cạnh `Kadr.exe`. Nếu thư mục chỉ cho phép đọc, Kadr sẽ báo rằng không thể lưu cài đặt.

```ini
[General]
Language=en      ; pl, en, es, fr, de, pt, ru, uk, it, nl, cs, hu, ro, tr, el, ar, he, hi, bn, ur, zh, ja, ko, id, vi, th, fa, ta, te, mr
Theme=auto       ; auto, light or dark
[Print]
Scale=fit        ; fit, fill, stretch, actual, percent, width or height
```

Ngôn ngữ cũng có thể chọn trong **Thêm (…) → Ngôn ngữ / Language…**; thay đổi có hiệu lực sau khi khởi động lại Kadr. Chủ đề được áp dụng ngay lập tức.

Ngôn ngữ giao diện: Polski, English, Español, Français, Deutsch, Português, Русский, Українська, Italiano, Nederlands, Čeština, Magyar, Română, Türkçe, Ελληνικά, العربية, עברית, हिन्दी, বাংলা, اردو, 中文, 日本語, 한국어, Bahasa Indonesia, Tiếng Việt, ไทย, فارسی, தமிழ், తెలుగు, मराठी.

## Biên dịch từ mã nguồn

Yêu cầu: [Zig 0.11.0](https://ziglang.org/download/0.11.0/zig-windows-x86_64-0.11.0.zip) được giải nén vào `tools\zig-windows-x86_64-0.11.0\` (tệp nén không nằm trong kho mã; mã SHA-256 của nó có trong `THIRD-PARTY.txt`).

```bat
build.cmd
```

Kết quả là `Kadr.exe` (đích `x86-windows.xp`, Pentium III, `ReleaseSmall`) với phần đầu PE tương thích XP. Tạo lại biểu tượng: `tools\build_icon.cmd` (Pillow + windres/objcopy).

Kadr chỉ liên kết với các thư viện có sẵn trên Windows XP. Các tính năng mới hơn (thanh tiêu đề tối, menu và điều khiển tối) được nạp lúc chạy bằng `LoadLibrary` / `GetProcAddress` và được bỏ qua trên hệ thống cũ hơn.

## Chạy kiểm thử

- Các bộ kiểm thử nằm trong thư mục con của `tests\` (`editor-check`, `print-options`, `loader-check`, `image-check`, `codec-check`, `render-check`, `export-check`); mỗi bộ được khởi chạy bằng `check.cmd` của nó, tệp này biên dịch và chạy các chương trình kiểm thử Zig. `tests\editor-check\check.cmd` chạy các kiểm thử cửa sổ chính (bao gồm kiểm thử thiết lập chủ đề và xác định chủ đề), kiểm thử trình chỉnh sửa, kiểm tra độ phủ ngôn ngữ và một bản dựng ứng viên x86/XP; `tests\print-options\check.cmd` chạy các kiểm thử in và bố cục.
- Kiểm thử đơn vị của từng mô-đun có thể chạy bằng `zig test`, ví dụ `zig test src\toolbar.zig`, `src\navigation.zig`, `src\image.zig`, `src\zoom.zig`, `src\theme.zig` (với cùng cờ đích và include như trong `check.cmd`).
- Công cụ hỗ trợ Python 3: `python tests\i18n-check\run.py` (chọn ngôn ngữ), `python tests\locale_coverage.py` (mọi chuỗi giao diện đều có trong danh mục cho 30 ngôn ngữ), `python tests\audit_xp.py` (kiểm tra import/phần đầu XP của `Kadr.exe`), `tests\measure_print.py`, `tests\tooltip_probe.py`, `tests\shot.py`.
- `tests\generate_fixtures.py` tạo ảnh kiểm thử (cần Pillow); chỉ dùng cho phát triển, không bao giờ được `Kadr.exe` sử dụng.

## Giấy phép

**GPL-3.0-or-later** — toàn văn trong [`LICENSE`](LICENSE).

Các thành phần bên thứ ba và giấy phép của chúng (DjVuLibre, VC100/GDI+, Zig): [`THIRD-PARTY.txt`](THIRD-PARTY.txt). Văn bản GNU GPL v2 cho DjVuLibre: [`COPYING.txt`](COPYING.txt).

Đây là bản dịch; phiên bản tiếng Anh ([README.md](README.md)) là bản chính thức.

## Ghi công

- Được xây dựng bằng [Zig](https://ziglang.org/) trên Win32 và GDI+.
- Giải mã DjVu: [DjVuLibre](https://djvu.sourceforge.net/) 3.5.27 (GPL-2.0-or-later).
- Các biểu tượng giao diện và logo Kadr là đồ họa gốc của dự án (`src/ui.zig`, `tools/make_icon.py`).
- Các bức ảnh trong ảnh chụp màn hình là ảnh tổng hợp được tạo cho README này.
