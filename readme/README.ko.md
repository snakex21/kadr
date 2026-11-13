[English](../README.md) | [Polski](README.pl.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Italiano](README.it.md) | [Nederlands](README.nl.md) | [Čeština](README.cs.md) | [Magyar](README.hu.md) | [Română](README.ro.md) | [Türkçe](README.tr.md) | [Ελληνικά](README.el.md) | [العربية](README.ar.md) | [עברית](README.he.md) | [हिन्दी](README.hi.md) | [বাংলা](README.bn.md) | [اردو](README.ur.md) | [中文](README.zh.md) | [日本語](README.ja.md) | **한국어** | [Bahasa Indonesia](README.id.md) | [Tiếng Việt](README.vi.md) | [ไทย](README.th.md) | [فارسی](README.fa.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [मराठी](README.mr.md)

# Kadr

**빠르고 작은 Windows용 휴대용 사진 뷰어 겸 편집기 — Windows XP부터 Windows 11까지, 1 MB도 안 되는 `Kadr.exe` 파일 하나로.**

Kadr는 [Zig](https://ziglang.org/)로 작성된 네이티브 Win32/GDI+ 애플리케이션입니다. 설치 프로그램도, .NET도, Electron도, Node.js도 필요 없습니다. `Kadr.exe`를 아무 곳에나 복사해서 실행하면 됩니다. 설정은 프로그램 옆의 `Kadr.ini`에 저장됩니다(포터블 — 레지스트리나 AppData에는 아무것도 기록하지 않습니다).

![Kadr 메인 창, 밝은 테마](../docs/screenshots/main-light.png)

## 목차

- [기능](#기능)
- [스크린샷](#스크린샷)
- [다운로드 / 설치](#다운로드--설치)
- [사용법](#사용법)
- [키보드 단축키](#키보드-단축키)
- [편집기](#편집기-1)
- [인쇄](#인쇄)
- [테마](#테마)
- [설정 (Kadr.ini)](#설정-kadrini)
- [소스에서 빌드하기](#소스에서-빌드하기)
- [테스트 실행](#테스트-실행)
- [라이선스](#라이선스)
- [감사의 말](#감사의-말)

## 기능

- **뷰어** — 사진 열기, 폴더 탐색(화살표 키, 이전/다음), 슬라이드 쇼, 전체 화면, 부드러운 확대/축소(맞춤, 1:1, 커서 위치 기준 마우스 휠, `125%`, `37,5%`, `200×` 같은 값 직접 입력), 화면 이동, 애니메이션 GIF 재생, 여러 페이지로 된 TIFF와 DjVu, EXIF 방향 자동 적용.
- **편집기** — 실시간 프레임과 비율 프리셋(자유, 1:1, 4:3, 3:4, 3:2, 2:3, 16:9, A4 세로/가로)을 사용한 자르기, 펜, 형광펜, 지우개, 선, 화살표, 사각형, 텍스트, 실행 취소/다시 실행, 회전과 뒤집기, 밝기, 대비, 채도, 흑백. 변경 사항은 저장할 때까지 메모리에만 남습니다.
- **인쇄** — 실시간 인쇄 미리 보기에서 용지 크기, 방향, 배율(맞춤 / 채우기(자르기) / 늘이기(페이지 전체) / 100% / 사용자 지정 % / mm 단위 너비 또는 높이), 여백, 위치, 컬러 또는 회색조를 설정합니다.
- **파일 도구** — 저장(회전), 다른 이름으로 저장, 크기 조정 및 용량 예상이 가능한 내보내기 / 압축(PNG, JPEG, BMP, TIFF, GIF), 이미지 또는 경로를 클립보드에 복사, 이름 바꾸기, 휴지통으로 이동 또는 영구 삭제, 폴더에서 보기, 바탕 화면 배경으로 설정.
- **형식** — PNG, JPEG/JFIF, BMP/DIB, GIF, TIFF, DjVu, ICO, WMF/EMF, TGA, PCX, PSD(병합된 이미지), PBM/PGM/PPM/PNM, QOI.
- **30개 인터페이스 언어** — Windows 언어를 자동으로 감지하며(없으면 영어 사용) 메뉴에서 바꿀 수 있습니다. 아랍어, 히브리어, 우르두어, 페르시아어는 오른쪽에서 왼쪽 레이아웃을 사용합니다.
- **테마** — 밝게, 어둡게 또는 자동(Windows 앱 모드를 따르며 실시간으로 전환).
- **작은 크기** — 1 MB보다 작은 `Kadr.exe` 하나.
- **Windows XP 이상** — Windows XP SP3(x86)부터 Windows 10/11까지 실행됩니다.

## 스크린샷

| 밝은 테마 | 어두운 테마 |
|---|---|
| ![메인 창, 밝은 테마](../docs/screenshots/main-light.png) | ![메인 창, 어두운 테마](../docs/screenshots/main-dark.png) |

**편집기** — 3:2 프리셋 자르기 프레임, 펜, 형광펜, 화살표, 사각형, 텍스트:

![자르기 프레임과 그림이 있는 편집기](../docs/screenshots/editor-crop.png)

*Stretch (whole page)*(늘이기: 페이지 전체) 모드의 **인쇄 미리 보기**:

![인쇄 미리 보기, 늘이기 모드](../docs/screenshots/print-stretch.png)

*테마* 하위 메뉴가 열린 **"더 보기"(…) 메뉴**:

![테마 하위 메뉴가 열린 더 보기 메뉴](../docs/screenshots/more-menu.png)

## 다운로드 / 설치

1. [릴리스 페이지](https://github.com/snakex21/kadr/releases)에서 `Kadr.exe`를 다운로드합니다(완성된 `Kadr.exe`는 저장소 루트에도 있습니다).
2. 쓰기 권한이 있는 아무 폴더(예: USB 메모리)에 넣고 실행합니다. 설치 프로그램은 없습니다.
3. DjVu 파일을 보려면 저장소의 `deps\djvu\` 폴더를 `Kadr.exe` 옆에 두세요.

더블 클릭으로 사진을 열려면 Windows에서 이미지 파일에 *연결 프로그램 → 다른 앱 선택*을 사용하고 `Kadr.exe`를 선택하세요.

**요구 사항:** Windows XP SP3 x86 이상(Windows 10/11에서도 작동). 그 밖에는 아무것도 필요 없습니다.

> DjVu 디코더는 오래된 DjVuLibre 3.5.27입니다. 신뢰할 수 있는 DjVu 파일만 여세요(자세한 내용은 `THIRD-PARTY.txt` 참조).

## 사용법

- **열기**: **열기**(Ctrl+O)를 누르거나, 파일을 창에 끌어 놓거나, 명령줄로 전달합니다: `Kadr.exe photo.jpg`.
- **탐색**: ← / → 또는 화살표 버튼으로 폴더를 넘겨 봅니다. 카운터에 현재 위치가 표시됩니다(예: `1 / 3`). 화살표 키를 누르고 있으면 빠르게 넘어갑니다.
- **확대/축소**: 마우스 휠(커서 위치 기준), `+` / `−`, **맞춤**(Home), **1:1**(`1`)을 사용하거나 배율 입력란에 값을 입력하고 Enter를 누릅니다. 사진을 끌면 화면이 이동합니다.
- **회전**: R / L. 화면만 회전하며, **저장**(Ctrl+S)을 누르면 회전이 파일에 기록됩니다.
- **더 보기(…)** 는 모든 파일 작업, 편집기, 인쇄, 슬라이드 쇼, 전체 화면, 도움말, *업데이트 확인…*, *테마*, *언어*가 있는 메뉴를 엽니다.
- **업데이트 확인…** 은 웹 브라우저에서 프로젝트의 GitHub 릴리스 페이지를 열기만 합니다. Kadr 자체는 인터넷에 절대 연결하지 않습니다.

## 키보드 단축키

### 뷰어

| 단축키 | 동작 |
|---|---|
| Ctrl+O | 열기 |
| Ctrl+S | 저장(현재 파일에 회전을 기록) |
| Ctrl+Shift+S | 다른 이름으로 저장 |
| Ctrl+E | 이미지 편집 |
| Ctrl+P | 인쇄 |
| Ctrl+C | 이미지 복사 |
| Ctrl+Shift+C | 경로 복사 |
| F2 | 이름 바꾸기 |
| Delete | 휴지통으로 이동 |
| Shift+Delete | 영구 삭제 |
| ← / → | 폴더의 이전 / 다음 이미지(누르고 있으면 빠르게 넘김) |
| Home | 창에 맞춤 |
| 1 | 실제 크기(1:1) |
| + / −(숫자 키패드 포함) | 확대 / 축소 |
| 마우스 휠 | 커서 위치 기준 확대/축소 |
| 왼쪽 버튼으로 끌기 | 화면 이동 |
| 더블 클릭 | 전체 화면 켜기 / 끄기 |
| R / L | 오른쪽 / 왼쪽으로 회전 |
| Space | 애니메이션 일시 정지 / 재개 |
| Page Up / Page Down | 이전 / 다음 페이지(TIFF, DjVu) |
| F5 | 슬라이드 쇼(4초마다) |
| F11 | 전체 화면 |
| Esc | 전체 화면 종료, 슬라이드 쇼 중지 |
| F1 | 도움말과 바로 가기 |
| Shift+F10 또는 메뉴 키 | "더 보기" 메뉴(사진을 마우스 오른쪽 버튼으로 클릭해도 열림) |
| Tab / Shift+Tab, Enter 또는 Space | 도구 모음 버튼 사이를 이동하고 누르기 |

### 배율 입력란

| 단축키 | 동작 |
|---|---|
| Enter | 입력한 배율 적용(`125%`, `37,5%`, `200×` …) |
| Esc | 현재 값으로 되돌리기 |
| Ctrl+A | 모두 선택 |

### 편집기

| 단축키 | 동작 |
|---|---|
| C | 자르기 |
| P | Pen(펜) |
| H | Highlighter(형광펜) |
| E | Eraser(지우개) |
| L | Line(선) |
| A | Arrow(화살표) |
| B | Rectangle(사각형) |
| T | Text(텍스트) |
| Ctrl+Z | Undo(실행 취소) |
| Ctrl+Y 또는 Ctrl+Shift+Z | Redo(다시 실행) |
| Enter(자르기 도구) 또는 더블 클릭 | 어둡게 표시된 부분 잘라내기 |
| Enter / Esc(텍스트 입력 중) | 텍스트 완료 / 취소 |
| Esc | 변경 없이 편집기 닫기 |

### 인쇄 미리 보기

| 단축키 | 동작 |
|---|---|
| 용지 위에서 사진 끌기 | 위치 변경 |
| Esc | 미리 보기 닫기(진행 중인 인쇄 작업 취소) |

## 편집기

**Edit**(편집, Ctrl+E)으로 편집기를 엽니다. 모든 변경 사항은 메모리에 보관되며, 저장하기 전까지 원본 파일은 건드리지 않습니다.

- **자르기** — 핸들 여덟 개가 달린 실시간 프레임입니다. 프레임이나 핸들을 끌거나, X / Y / 너비 / 높이를 픽셀 단위로 정확히 입력하거나, 비율 프리셋(자유, 정사각형 1:1, 4:3, 3:4, 3:2(4×6 가로), 2:3, 16:9, A4 세로, A4 가로)을 고르세요. 프레임 바깥 영역은 어둡게 표시되며, **자르기**(Enter)를 누르면 잘려 나가고 **Whole photo**(사진 전체)를 누르면 프레임이 초기화됩니다.
- **그리기** — 펜, 반투명 형광펜, 지우개(그림과 텍스트만 지우며 사진은 절대 지우지 않음), 직선, 화살표, 사각형, 텍스트. 색상 열 가지와 굵기 조절을 지원합니다.
- **이미지** — 실행 취소 / 다시 실행, 왼쪽 또는 오른쪽으로 90° 회전, 좌우 또는 상하 뒤집기, 모두 초기화.
- **색과 빛** — 밝기, 대비, 채도, 흑백.
- **마무리** — *적용*은 편집한 사진을 뷰어로 돌려보내고, *Save as…*(다른 이름으로 저장…)는 새 이름으로 사본을 저장하며, *Print…*(인쇄…)는 곧바로 인쇄 미리 보기로 이동하고, *취소*(Esc)는 변경 사항을 버립니다.

## 인쇄

**인쇄**(Ctrl+P)를 누르면 용지의 실시간 미리 보기가 열립니다. 프린터, 용지(A3–A6, B4/B5, Letter, Legal, Executive, Tabloid, 사진 크기 10×15, 13×18, 15×20, 20×25 cm, 4×6, 5×7, 8×10 in, 사용자 지정 또는 프린터 자체 용지), 방향, 컬러 또는 회색조를 선택하세요. 방향은 직접 바꾸기 전까지 사진에 맞춰 자동으로 정해집니다.

배율 모드:

| 모드 | 동작 |
|---|---|
| **맞춤** | 사진 전체가 여백 안에 들어갑니다. 비율이 유지되며 양쪽 두 변에 흰 공간이 남을 수 있습니다. |
| **채우기 / 자르기** | 사진이 인쇄 가능한 영역 전체를 덮습니다. 비율이 유지되며 넘치는 가장자리는 잘립니다. |
| **Stretch (whole page)**(늘이기: 페이지 전체) | 사진을 인쇄 가능한 영역에 정확히 맞게 늘입니다. 흰 띠는 없지만 비율은 유지되지 **않습니다**. |
| **100% · 실제 크기 (96 DPI)** | 1픽셀 = 1/96인치. |
| **사용자 지정 비율** | 96 DPI 기준 0.1–1000 %(100% = 위의 크기). |
| **너비 / 높이 (mm)** | 정확한 실제 너비 또는 높이. 나머지 변은 비율에 따라 정해집니다. |

**고급 ▸** 에서는 사용자 지정 용지 크기, 여백, 용지 위의 정확한 위치를 설정할 수 있습니다(또는 미리 보기에서 사진을 끌어도 되며, *가운데*를 누르면 다시 중앙으로 옵니다). 회색 선은 프린터의 하드웨어 한계를 나타냅니다. 마지막으로 선택한 배율 모드는 `Kadr.ini`에 기억됩니다.

## 테마

**더 보기(…) → 테마**에서 **밝게**, **어둡게**, **자동**(기본값)을 고를 수 있습니다.

- **자동**은 Windows *앱 모드*(설정 → 개인 설정 → 색, `AppsUseLightTheme` 값)를 따르며, Windows에서 바꾸면 실시간으로 전환됩니다. 이 설정이 없는 시스템(Windows XP, Vista, 7, 8)에서는 자동이 밝게와 같습니다.
- 테마는 메인 창, 도구 모음, 버튼과 아이콘, 편집기, 인쇄 미리 보기, Kadr 자체 대화 상자에 적용됩니다. 어두운 모드에서는 사진 배경이 짙은 회색이 되며, Windows 10/11에서는 제목 표시줄과 팝업 메뉴도 어두워집니다.
- 일부 Windows 기본 요소는 시스템 모양을 유지합니다: 메시지 상자(도움말, 확인), 열기 / 저장 / 인쇄 시스템 대화 상자, 슬라이더 손잡이.

## 설정 (Kadr.ini)

모든 설정은 `Kadr.exe` 옆의 `Kadr.ini`에 저장됩니다. 폴더가 읽기 전용이면 Kadr가 설정을 저장할 수 없다고 알려 줍니다.

```ini
[General]
Language=en      ; pl, en, es, fr, de, pt, ru, uk, it, nl, cs, hu, ro, tr, el, ar, he, hi, bn, ur, zh, ja, ko, id, vi, th, fa, ta, te, mr
Theme=auto       ; auto, light or dark
[Print]
Scale=fit        ; fit, fill, stretch, actual, percent, width or height
```

언어는 **더 보기(…) → 언어 / Language…** 에서도 고를 수 있으며, 변경 사항은 Kadr를 다시 시작한 뒤 적용됩니다. 테마는 즉시 적용됩니다.

인터페이스 언어: Polski, English, Español, Français, Deutsch, Português, Русский, Українська, Italiano, Nederlands, Čeština, Magyar, Română, Türkçe, Ελληνικά, العربية, עברית, हिन्दी, বাংলা, اردو, 中文, 日本語, 한국어, Bahasa Indonesia, Tiếng Việt, ไทย, فارسی, தமிழ், తెలుగు, मराठी.

## 소스에서 빌드하기

요구 사항: [Zig 0.11.0](https://ziglang.org/download/0.11.0/zig-windows-x86_64-0.11.0.zip)을 `tools\zig-windows-x86_64-0.11.0\`에 압축 해제(압축 파일은 저장소에 포함되어 있지 않으며, SHA-256 값은 `THIRD-PARTY.txt`에 있습니다).

```bat
build.cmd
```

결과물은 XP 호환 PE 헤더를 가진 `Kadr.exe`(대상 `x86-windows.xp`, Pentium III, `ReleaseSmall`)입니다. 아이콘 다시 생성: `tools\build_icon.cmd`(Pillow + windres/objcopy).

Kadr는 Windows XP에 있는 라이브러리에만 링크합니다. 새로운 기능(어두운 제목 표시줄, 어두운 메뉴와 컨트롤)은 실행 시 `LoadLibrary` / `GetProcAddress`로 불러오며, 오래된 시스템에서는 건너뜁니다.

## 테스트 실행

- 테스트 모음은 `tests\` 하위 폴더(`editor-check`, `print-options`, `loader-check`, `image-check`, `codec-check`, `render-check`, `export-check`)에 있습니다. 각각 해당 폴더의 `check.cmd`로 시작하며, 이 스크립트가 Zig 테스트 하네스를 빌드하고 실행합니다. `tests\editor-check\check.cmd`는 메인 창 테스트(테마 설정 및 테마 결정 테스트 포함), 편집기 테스트, 언어 범위 검사, x86/XP 후보 빌드를 실행하고, `tests\print-options\check.cmd`는 인쇄 및 레이아웃 테스트를 실행합니다.
- 개별 모듈의 단위 테스트는 `zig test`로 실행할 수 있습니다. 예: `zig test src\toolbar.zig`, `src\navigation.zig`, `src\image.zig`, `src\zoom.zig`, `src\theme.zig`(`check.cmd`와 같은 대상 및 include 플래그 사용).
- Python 3 도우미: `python tests\i18n-check\run.py`(언어 선택), `python tests\locale_coverage.py`(모든 UI 문자열이 30개 언어 카탈로그에 있는지), `python tests\audit_xp.py`(`Kadr.exe`의 XP 임포트/헤더 감사), `tests\measure_print.py`, `tests\tooltip_probe.py`, `tests\shot.py`.
- `tests\generate_fixtures.py`는 테스트 이미지를 만듭니다(Pillow 필요). 개발용으로만 쓰이며 `Kadr.exe`가 사용하는 일은 없습니다.

## 라이선스

**GPL-3.0-or-later** — 전문은 [`LICENSE`](../LICENSE)에 있습니다.

서드파티 구성 요소와 그 라이선스(DjVuLibre, VC100/GDI+, Zig): [`THIRD-PARTY.txt`](../THIRD-PARTY.txt). DjVuLibre용 GNU GPL v2 전문: [`COPYING.txt`](../COPYING.txt).

이 문서는 번역본이며, 영어판([README.md](../README.md))이 기준입니다.

## 감사의 말

- Win32와 GDI+ 위에서 [Zig](https://ziglang.org/)로 만들었습니다.
- DjVu 디코딩: [DjVuLibre](https://djvu.sourceforge.net/) 3.5.27 (GPL-2.0-or-later).
- 인터페이스 아이콘과 Kadr 로고는 이 프로젝트의 오리지널 그래픽입니다(`src/ui.zig`, `tools/make_icon.py`).
- 스크린샷 속 사진은 이 README를 위해 생성한 합성 이미지입니다.
