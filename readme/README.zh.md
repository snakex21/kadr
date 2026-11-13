[English](../README.md) | [Polski](README.pl.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Italiano](README.it.md) | [Nederlands](README.nl.md) | [Čeština](README.cs.md) | [Magyar](README.hu.md) | [Română](README.ro.md) | [Türkçe](README.tr.md) | [Ελληνικά](README.el.md) | [العربية](README.ar.md) | [עברית](README.he.md) | [हिन्दी](README.hi.md) | [বাংলা](README.bn.md) | [اردو](README.ur.md) | **中文** | [日本語](README.ja.md) | [한국어](README.ko.md) | [Bahasa Indonesia](README.id.md) | [Tiếng Việt](README.vi.md) | [ไทย](README.th.md) | [فارسی](README.fa.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [मराठी](README.mr.md)

# Kadr

**一款快速、小巧、便携的 Windows 照片查看与编辑器——从 Windows XP 到 Windows 11，只有一个不到 1 MB 的 `Kadr.exe`。**

Kadr 是用 [Zig](https://ziglang.org/) 编写的原生 Win32/GDI+ 应用程序。无需安装程序，不依赖 .NET、Electron 或 Node.js：把 `Kadr.exe` 复制到任意位置即可运行。设置保存在程序旁边的 `Kadr.ini` 中（便携——不会向注册表或 AppData 写入任何内容）。

![Kadr 主窗口，浅色主题](../docs/screenshots/main-light.png)

## 目录

- [功能](#功能)
- [截图](#截图)
- [下载 / 安装](#下载--安装)
- [使用方法](#使用方法)
- [键盘快捷键](#键盘快捷键)
- [编辑器](#编辑器-1)
- [打印](#打印)
- [主题](#主题)
- [设置 (Kadr.ini)](#设置-kadrini)
- [从源码构建](#从源码构建)
- [运行测试](#运行测试)
- [许可证](#许可证)
- [致谢](#致谢)

## 功能

- **查看器**——打开照片，浏览文件夹（方向键、上一张/下一张），幻灯片放映，全屏，平滑缩放（适应窗口、1:1、在光标处用鼠标滚轮缩放、输入 `125%`、`37,5%` 或 `200×` 等数值），拖动平移，播放 GIF 动画，多页 TIFF 和 DjVu，按 EXIF 自动调整方向。
- **编辑器**——带实时裁剪框和比例预设的裁剪（自由、1:1、4:3、3:4、3:2、2:3、16:9、A4 纵向/横向）；画笔、荧光笔、橡皮擦、直线、箭头、矩形和文字；撤销/重做；旋转和翻转；亮度、对比度、饱和度和黑白。所有更改都保留在内存中，直到你保存为止。
- **打印**——实时打印预览，可设置纸张大小、方向、缩放（适应 / 填充（裁剪）/ 拉伸（整页）/ 100% / 自定义百分比 / 以 mm 为单位的宽度或高度）、页边距、位置、彩色或灰度。
- **文件工具**——保存（旋转）、另存为、导出 / 压缩（PNG、JPEG、BMP、TIFF、GIF），支持调整尺寸和估算文件大小，将图像或路径复制到剪贴板，重命名，移到回收站或永久删除，在文件夹中显示，设为桌面壁纸。
- **格式**——PNG、JPEG/JFIF、BMP/DIB、GIF、TIFF、DjVu、ICO、WMF/EMF、TGA、PCX、PSD（合并图像）、PBM/PGM/PPM/PNM、QOI。
- **30 种界面语言**——自动检测 Windows 语言（无法匹配时使用英语），也可以在菜单中更改；阿拉伯语、希伯来语、乌尔都语和波斯语采用从右到左的布局。
- **主题**——浅色、深色或自动（跟随 Windows 应用模式，实时切换）。
- **小巧**——只有一个不到 1 MB 的 `Kadr.exe`。
- **Windows XP 及更高版本**——可在 Windows XP SP3 (x86) 到 Windows 10/11 上运行。

## 截图

| 浅色主题 | 深色主题 |
|---|---|
| ![主窗口，浅色主题](../docs/screenshots/main-light.png) | ![主窗口，深色主题](../docs/screenshots/main-dark.png) |

**编辑器**——使用 3:2 预设的裁剪框，以及画笔、荧光笔、箭头、矩形和文字：

![带裁剪框和绘图的编辑器](../docs/screenshots/editor-crop.png)

**打印预览**，*Stretch (whole page)*（拉伸：整页）模式：

![打印预览，Stretch 模式](../docs/screenshots/print-stretch.png)

**“更多” (…) 菜单**及其 *主题* 子菜单：

![更多菜单及主题子菜单](../docs/screenshots/more-menu.png)

## 下载 / 安装

1. 从 [Releases 页面](https://github.com/snakex21/kadr/releases) 下载 `Kadr.exe`（仓库根目录中也保留了一个现成的 `Kadr.exe`）。
2. 将它放到任何有写入权限的文件夹（例如 U 盘）中并运行。没有安装程序。
3. 如需打开 DjVu 文件，请将仓库中的 `deps\djvu\` 文件夹放在 `Kadr.exe` 旁边。

若要双击打开图片，请在 Windows 中对图片使用 *打开方式 → 选择其他应用*，然后选择 `Kadr.exe`。

**系统要求：** Windows XP SP3 x86 或更高版本（Windows 10/11 同样可用）。别无其他要求。

> DjVu 解码器是较旧的 DjVuLibre 3.5.27——请只打开你信任的 DjVu 文件（详见 `THIRD-PARTY.txt`）。

## 使用方法

- **打开**图片：使用 **打开** (Ctrl+O)、将文件拖到窗口上，或在命令行中传入：`Kadr.exe photo.jpg`。
- **浏览**文件夹：使用 ← / → 或箭头按钮；计数器会显示当前位置（例如 `1 / 3`）。按住方向键可快速浏览。
- **缩放**：使用鼠标滚轮（以光标为中心缩放）、`+` / `−`、**适应窗口** (Home)、**1:1** (`1`)，或在缩放框中输入数值后按 Enter。拖动图片可平移。
- **旋转**：使用 R / L。旋转的是视图；**保存** (Ctrl+S) 会将旋转写入文件。
- **更多 (…)** 打开包含全部文件操作、编辑器、打印、幻灯片、全屏、帮助、*检查更新…*、*主题* 和 *语言* 的菜单。
- **检查更新…** 只会在你的网页浏览器中打开项目在 GitHub 上的发布页面——Kadr 本身从不连接互联网。

## 键盘快捷键

### 查看器

| 快捷键 | 操作 |
|---|---|
| Ctrl+O | 打开 |
| Ctrl+S | 保存（将旋转写入当前文件） |
| Ctrl+Shift+S | 另存为 |
| Ctrl+E | 编辑图片 |
| Ctrl+P | 打印 |
| Ctrl+C | 复制图像 |
| Ctrl+Shift+C | 复制路径 |
| F2 | 重命名 |
| Delete | 移到回收站 |
| Shift+Delete | 永久删除 |
| ← / → | 文件夹中的上一张 / 下一张图片（按住可快速浏览） |
| Home | 适应窗口 |
| 1 | 实际大小 (1:1) |
| + / −（小键盘同样可用） | 放大 / 缩小 |
| 鼠标滚轮 | 以光标为中心缩放 |
| 按住左键拖动 | 平移 |
| 双击 | 开启 / 关闭全屏 |
| R / L | 向右 / 向左旋转 |
| Space | 暂停 / 继续播放动画 |
| Page Up / Page Down | 上一页 / 下一页（TIFF、DjVu） |
| F5 | 幻灯片（每 4 秒切换） |
| F11 | 全屏 |
| Esc | 退出全屏，停止幻灯片 |
| F1 | 帮助与快捷键 |
| Shift+F10 或菜单键 | “更多”菜单（也可在图片上单击右键） |
| Tab / Shift+Tab、Enter 或 Space | 在工具栏按钮之间移动并按下按钮 |

### 缩放输入框

| 快捷键 | 操作 |
|---|---|
| Enter | 应用输入的缩放值（`125%`、`37,5%`、`200×` …） |
| Esc | 恢复当前值 |
| Ctrl+A | 全选 |

### 编辑器

| 快捷键 | 操作 |
|---|---|
| C | 裁剪 |
| P | Pen（画笔） |
| H | Highlighter（荧光笔） |
| E | Eraser（橡皮擦） |
| L | Line（直线） |
| A | Arrow（箭头） |
| B | Rectangle（矩形） |
| T | Text（文字） |
| Ctrl+Z | Undo（撤销） |
| Ctrl+Y 或 Ctrl+Shift+Z | Redo（重做） |
| Enter（裁剪工具）或双击 | 裁掉变暗的部分 |
| Enter / Esc（输入文字时） | 完成 / 取消文字 |
| Esc | 不保留更改并关闭编辑器 |

### 打印预览

| 快捷键 | 操作 |
|---|---|
| 在纸张上拖动图片 | 更改图片位置 |
| Esc | 关闭预览（会取消正在进行的打印任务） |

## 编辑器

使用 **Edit**（编辑，Ctrl+E）打开编辑器。所有更改都保存在内存中；在你保存之前，原始文件不会被改动。

- **裁剪**——带八个控制点的实时裁剪框；可拖动裁剪框或控制点，以像素为单位输入精确的 X / Y / 宽度 / 高度，或选择比例预设（自由、正方形 1:1、4:3、3:4、3:2（4×6 横向）、2:3、16:9、A4 纵向、A4 横向）。框外区域会变暗；**裁剪** (Enter) 将其裁掉，**Whole photo**（整张照片）则重置裁剪框。
- **绘图**——画笔、半透明荧光笔、橡皮擦（只擦除绘图和文字，绝不会擦除照片）、直线、箭头、矩形和文字，提供十种颜色，粗细可调。
- **Image**（图像）——撤销 / 重做，向左或向右旋转 90°，水平或垂直镜像，全部重置。
- **Colour and light**（色彩与光线）——亮度、对比度、饱和度和黑白。
- **完成**——*应用* 将编辑后的图片返回查看器，*Save as…*（另存为）以新名称保存副本，*Print…*（打印）直接进入打印预览，*取消* (Esc) 放弃所有更改。

## 打印

**打印** (Ctrl+P) 会打开纸张的实时预览。可选择打印机、纸张（A3–A6、B4/B5、Letter、Legal、Executive、Tabloid，照片尺寸 10×15、13×18、15×20、20×25 cm，4×6、5×7、8×10 in，自定义或打印机自带尺寸）、方向，以及彩色或灰度。在你手动更改之前，方向会自动跟随图片。

缩放模式：

| 模式 | 作用 |
|---|---|
| **适应窗口** | 整张图片放入页边距之内；保持比例，两侧可能留有空白。 |
| **填充 / 裁剪** | 图片铺满整个可打印区域；保持比例，超出的边缘会被裁掉。 |
| **Stretch (whole page)**（拉伸：整页） | 图片被精确拉伸到可打印区域——没有白边，但**不**保持比例。 |
| **100% · 实际大小 (96 DPI)** | 一个像素 = 1/96 英寸。 |
| **自定义百分比** | 相对于 96 DPI 的 0.1–1000 %（100% = 上一行的尺寸）。 |
| **宽度 / 高度 (mm)** | 精确的物理宽度或高度；另一边按比例计算。 |

**高级 ▸** 可设置自定义纸张尺寸、页边距以及在纸张上的精确位置（也可以在预览中拖动图片；*居中* 会把它放回中央）。灰色线条表示打印机的硬件打印边界。上次选择的缩放模式会记录在 `Kadr.ini` 中。

## 主题

**更多 (…) → 主题** 提供 **浅色**、**深色** 和 **自动**（默认）。

- **自动** 跟随 Windows 的 *应用模式*（设置 → 个性化 → 颜色，即 `AppsUseLightTheme` 值），在 Windows 中更改该设置时会实时切换。在没有该设置的系统上（Windows XP、Vista、7、8），自动即表示浅色。
- 主题覆盖主窗口、工具栏、按钮和图标、编辑器、打印预览以及 Kadr 自己的对话框。在深色模式下，图片背景为深灰色；在 Windows 10/11 上，标题栏和弹出菜单也会变为深色。
- 少数 Windows 原生部件保持系统外观：消息框（帮助、确认）、系统的打开 / 保存 / 打印对话框，以及滑块的滑钮。

## 设置 (Kadr.ini)

所有设置都保存在 `Kadr.exe` 旁边的 `Kadr.ini` 中。如果文件夹为只读，Kadr 会提示无法保存设置。

```ini
[General]
Language=en      ; pl, en, es, fr, de, pt, ru, uk, it, nl, cs, hu, ro, tr, el, ar, he, hi, bn, ur, zh, ja, ko, id, vi, th, fa, ta, te, mr
Theme=auto       ; auto, light or dark
[Print]
Scale=fit        ; fit, fill, stretch, actual, percent, width or height
```

也可以通过 **更多 (…) → 语言** 选择语言；更改在重新启动 Kadr 后生效。主题则立即生效。

界面语言：Polski, English, Español, Français, Deutsch, Português, Русский, Українська, Italiano, Nederlands, Čeština, Magyar, Română, Türkçe, Ελληνικά, العربية, עברית, हिन्दी, বাংলা, اردو, 中文, 日本語, 한국어, Bahasa Indonesia, Tiếng Việt, ไทย, فارسی, தமிழ், తెలుగు, मराठी.

## 从源码构建

要求：将 [Zig 0.11.0](https://ziglang.org/download/0.11.0/zig-windows-x86_64-0.11.0.zip) 解压到 `tools\zig-windows-x86_64-0.11.0\`（该压缩包不包含在仓库中；其 SHA-256 记录在 `THIRD-PARTY.txt` 中）。

```bat
build.cmd
```

生成结果为 `Kadr.exe`（目标 `x86-windows.xp`，Pentium III，`ReleaseSmall`），带有兼容 XP 的 PE 头。重新生成图标：`tools\build_icon.cmd`（Pillow + windres/objcopy）。

Kadr 只链接 Windows XP 上已有的库。较新的功能（深色标题栏、深色菜单和控件）会在运行时通过 `LoadLibrary` / `GetProcAddress` 加载，在旧系统上则会跳过。

## 运行测试

- 测试套件位于 `tests\` 的子文件夹中（`editor-check`、`print-options`、`loader-check`、`image-check`、`codec-check`、`render-check`、`export-check`）；每个套件都通过自己的 `check.cmd` 启动，它会构建并运行 Zig 测试程序。`tests\editor-check\check.cmd` 运行主窗口测试（包括主题设置和主题解析测试）、编辑器测试、语言覆盖检查以及一次 x86/XP 候选构建；`tests\print-options\check.cmd` 运行打印和布局测试。
- 单个模块的单元测试可以用 `zig test` 运行，例如 `zig test src\toolbar.zig`、`src\navigation.zig`、`src\image.zig`、`src\zoom.zig`、`src\theme.zig`（使用与 `check.cmd` 中相同的目标和 include 参数）。
- Python 3 辅助脚本：`python tests\i18n-check\run.py`（语言选择）、`python tests\locale_coverage.py`（检查所有界面字符串是否已在 30 种语言的目录中）、`python tests\audit_xp.py`（审查 `Kadr.exe` 的 XP 导入表和文件头）、`tests\measure_print.py`、`tests\tooltip_probe.py`、`tests\shot.py`。
- `tests\generate_fixtures.py` 用于生成测试图片（需要 Pillow）；它只在开发时使用，`Kadr.exe` 从不调用它。

## 许可证

**GPL-3.0-or-later**——完整文本见 [`LICENSE`](../LICENSE)。

第三方组件及其许可证（DjVuLibre、VC100/GDI+、Zig）：[`THIRD-PARTY.txt`](../THIRD-PARTY.txt)。DjVuLibre 适用的 GNU GPL v2 文本：[`COPYING.txt`](../COPYING.txt)。

本文为译文；以英文版本 ([README.md](../README.md)) 为准。

## 致谢

- 使用 [Zig](https://ziglang.org/) 基于 Win32 和 GDI+ 构建。
- DjVu 解码：[DjVuLibre](https://djvu.sourceforge.net/) 3.5.27 (GPL-2.0-or-later)。
- 界面图标和 Kadr 标志均为本项目的原创作品（`src/ui.zig`、`tools/make_icon.py`）。
- 截图中的图片是为本 README 生成的合成图像。
