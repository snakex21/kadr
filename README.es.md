[English](README.md) | [Polski](README.pl.md) | **Español** | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Italiano](README.it.md) | [Nederlands](README.nl.md) | [Čeština](README.cs.md) | [Magyar](README.hu.md) | [Română](README.ro.md) | [Türkçe](README.tr.md) | [Ελληνικά](README.el.md) | [العربية](README.ar.md) | [עברית](README.he.md) | [हिन्दी](README.hi.md) | [বাংলা](README.bn.md) | [اردو](README.ur.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Bahasa Indonesia](README.id.md) | [Tiếng Việt](README.vi.md) | [ไทย](README.th.md) | [فارسی](README.fa.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [मराठी](README.mr.md)

# Kadr

**Un visor y editor de fotos rápido, diminuto y portátil para Windows — de Windows XP a Windows 11, en un único `Kadr.exe` de menos de 1 MB.**

Kadr es una aplicación nativa Win32/GDI+ escrita en [Zig](https://ziglang.org/). Sin instalador, sin .NET, sin Electron, sin Node.js: copia `Kadr.exe` donde quieras y ejecútalo. La configuración se guarda en `Kadr.ini` junto al programa (portátil — no se escribe nada en el registro ni en AppData).

![Ventana principal de Kadr, tema claro](docs/screenshots/main-light.png)

## Índice

- [Características](#características)
- [Capturas de pantalla](#capturas-de-pantalla)
- [Descarga / Instalación](#descarga--instalación)
- [Uso](#uso)
- [Atajos de teclado](#atajos-de-teclado)
- [Editor](#editor-1)
- [Impresión](#impresión)
- [Temas](#temas)
- [Configuración (Kadr.ini)](#configuración-kadrini)
- [Compilar desde el código fuente](#compilar-desde-el-código-fuente)
- [Ejecutar las pruebas](#ejecutar-las-pruebas)
- [Licencia](#licencia)
- [Créditos](#créditos)

## Características

- **Visor** — abre fotos, recorre la carpeta (teclas de flecha, anterior/siguiente), presentación, pantalla completa, zoom suave (ajustar, 1:1, rueda del ratón en la posición del cursor, valores escritos como `125%`, `37,5%` o `200×`), desplazamiento de la imagen, reproducción de GIF animados, TIFF y DjVu de varias páginas, orientación EXIF automática.
- **Editor** — recorte con marco en vivo y proporciones predefinidas (libre, 1:1, 4:3, 3:4, 3:2, 2:3, 16:9, A4 vertical/horizontal); lápiz, resaltador, borrador, línea, flecha, rectángulo y texto; deshacer/rehacer; girar y voltear; brillo, contraste, saturación y blanco y negro. Los cambios permanecen en memoria hasta que guardas.
- **Impresión** — vista previa de impresión en vivo con tamaño de papel, orientación, escala (ajustar / rellenar (recortar) / estirar (página completa) / 100% / % personalizado / ancho o alto en mm), márgenes, posición, color o escala de grises.
- **Herramientas de archivo** — guardar (rotación), guardar como, exportar / comprimir (PNG, JPEG, BMP, TIFF, GIF) con cambio de tamaño y estimación del tamaño, copiar la imagen o la ruta al portapapeles, cambiar nombre, enviar a la papelera o eliminar permanentemente, mostrar en la carpeta, usar como fondo de escritorio.
- **Formatos** — PNG, JPEG/JFIF, BMP/DIB, GIF, TIFF, DjVu, ICO, WMF/EMF, TGA, PCX, PSD (imagen combinada), PBM/PGM/PPM/PNM, QOI.
- **30 idiomas de interfaz** — el idioma de Windows se detecta automáticamente (si no está disponible, se usa el inglés) y se puede cambiar desde el menú; diseño de derecha a izquierda para árabe, hebreo, urdu y persa.
- **Temas** — claro, oscuro o automático (sigue el modo de aplicación de Windows y cambia en vivo).
- **Pequeño** — un único `Kadr.exe` de menos de 1 MB.
- **Windows XP y posteriores** — funciona desde Windows XP SP3 (x86) hasta Windows 10/11.

## Capturas de pantalla

| Tema claro | Tema oscuro |
|---|---|
| ![Ventana principal, tema claro](docs/screenshots/main-light.png) | ![Ventana principal, tema oscuro](docs/screenshots/main-dark.png) |

**Editor** — marco de recorte con la proporción 3:2, lápiz, resaltador, flecha, rectángulo y texto:

![Editor con marco de recorte y dibujos](docs/screenshots/editor-crop.png)

**Vista previa de impresión** en el modo *Stretch (whole page)* (estirar: página completa):

![Vista previa de impresión, modo Stretch](docs/screenshots/print-stretch.png)

**El menú «Más» (…)** con el submenú *Tema*:

![Menú Más con el submenú Tema](docs/screenshots/more-menu.png)

## Descarga / Instalación

1. Descarga `Kadr.exe` desde la [página de versiones](https://github.com/snakex21/kadr/releases) (en la raíz del repositorio también hay un `Kadr.exe` listo para usar).
2. Colócalo en cualquier carpeta en la que puedas escribir (por ejemplo, una memoria USB) y ejecútalo. No hay instalador.
3. Para los archivos DjVu, conserva la carpeta `deps\djvu\` del repositorio junto a `Kadr.exe`.

Para abrir imágenes con doble clic, usa en Windows *Abrir con → Elegir otra aplicación* sobre una imagen y selecciona `Kadr.exe`.

**Requisitos:** Windows XP SP3 x86 o posterior (Windows 10/11 también funcionan). Nada más.

> El decodificador DjVu es la versión antigua DjVuLibre 3.5.27 — abre solo archivos DjVu de confianza (detalles en `THIRD-PARTY.txt`).

## Uso

- **Abre** una imagen con **Abrir** (Ctrl+O), arrastrando un archivo a la ventana o pasándolo en la línea de comandos: `Kadr.exe photo.jpg`.
- **Recorre** la carpeta con ← / → o con los botones de flecha; el contador muestra la posición (p. ej., `1 / 3`). Mantén pulsada una tecla de flecha para avanzar rápido.
- **Haz zoom** con la rueda del ratón (amplía en la posición del cursor), `+` / `−`, **Ajustar** (Home), **1:1** (`1`) o escribe un valor en el campo de zoom y pulsa Enter. Arrastra la imagen para desplazarla.
- **Gira** con R / L. Se gira la vista; **Guardar** (Ctrl+S) escribe la rotación en el archivo.
- **Más (…)** abre el menú con todas las operaciones de archivo, el editor, la impresión, la presentación, la pantalla completa, la ayuda, *Buscar actualizaciones…*, *Tema* e *Idioma*.
- **Buscar actualizaciones…** solo abre la página de versiones del proyecto en GitHub en tu navegador web — Kadr en sí nunca se conecta a internet.

## Atajos de teclado

### Visor

| Atajo | Acción |
|---|---|
| Ctrl+O | Abrir |
| Ctrl+S | Guardar (escribe la rotación en el archivo actual) |
| Ctrl+Shift+S | Guardar como |
| Ctrl+E | Editar imagen |
| Ctrl+P | Imprimir |
| Ctrl+C | Copiar imagen |
| Ctrl+Shift+C | Copiar ruta |
| F2 | Cambiar nombre |
| Delete | Mover a la papelera |
| Shift+Delete | Eliminar permanentemente |
| ← / → | Imagen anterior / siguiente de la carpeta (mantener pulsada para avanzar rápido) |
| Home | Ajustar a la ventana |
| 1 | Tamaño real (1:1) |
| + / − (también en el teclado numérico) | Acercar / alejar |
| Rueda del ratón | Zoom en la posición del cursor |
| Arrastrar con el botón izquierdo | Desplazar la imagen |
| Doble clic | Activar / desactivar la pantalla completa |
| R / L | Girar a la derecha / a la izquierda |
| Space | Pausar / reanudar la animación |
| Page Up / Page Down | Página anterior / siguiente (TIFF, DjVu) |
| F5 | Presentación (cada 4 segundos) |
| F11 | Pantalla completa |
| Esc | Salir de la pantalla completa, detener la presentación |
| F1 | Ayuda y atajos |
| Shift+F10 o la tecla Menú | Menú «Más» (también con clic derecho sobre la imagen) |
| Tab / Shift+Tab, Enter o Space | Moverse entre los botones de la barra de herramientas y pulsarlos |

### Campo de zoom

| Atajo | Acción |
|---|---|
| Enter | Aplicar el zoom escrito (`125%`, `37,5%`, `200×` …) |
| Esc | Restaurar el valor actual |
| Ctrl+A | Seleccionar todo |

### Editor

| Atajo | Acción |
|---|---|
| C | Recortar |
| P | Pen (lápiz) |
| H | Highlighter (resaltador) |
| E | Eraser (borrador) |
| L | Line (línea) |
| A | Arrow (flecha) |
| B | Rectangle (rectángulo) |
| T | Text (texto) |
| Ctrl+Z | Undo (deshacer) |
| Ctrl+Y o Ctrl+Shift+Z | Redo (rehacer) |
| Enter (herramienta Recortar) o doble clic | Cortar la parte oscurecida |
| Enter / Esc (mientras escribes texto) | Terminar / cancelar el texto |
| Esc | Cerrar el editor sin cambios |

### Vista previa de impresión

| Atajo | Acción |
|---|---|
| Arrastrar la imagen sobre la hoja | Cambiar su posición |
| Esc | Cerrar la vista previa (cancela un trabajo de impresión en curso) |

## Editor

Abre el editor con **Edit** (editar, Ctrl+E). Todos los cambios se mantienen en memoria; el archivo original no se modifica hasta que guardas.

- **Recortar** — un marco en vivo con ocho tiradores; arrastra el marco o sus tiradores, escribe X / Y / ancho / alto exactos en píxeles o elige una proporción predefinida (libre, cuadrado 1:1, 4:3, 3:4, 3:2 (4×6 horizontal), 2:3, 16:9, A4 vertical, A4 horizontal). La zona fuera del marco se oscurece; **Recortar** (Enter) la elimina y **Whole photo** (foto completa) restablece el marco.
- **Dibujo** — lápiz, resaltador translúcido, borrador (borra solo dibujos y texto, nunca la foto), línea recta, flecha, rectángulo y texto, con diez colores y un grosor ajustable.
- **Image** (imagen) — deshacer / rehacer, girar 90° a la izquierda o a la derecha, voltear en horizontal o en vertical, restablecer todo.
- **Colour and light** (color y luz) — brillo, contraste, saturación y blanco y negro.
- **Finalizar** — *Aplicar* devuelve la imagen editada al visor, *Save as…* (guardar como) guarda una copia con otro nombre, *Print…* (imprimir) pasa directamente a la vista previa de impresión y *Cancelar* (Esc) descarta los cambios.

## Impresión

**Imprimir** (Ctrl+P) abre una vista previa de la hoja en vivo. Elige la impresora, el papel (A3–A6, B4/B5, Letter, Legal, Executive, Tabloid, tamaños fotográficos 10×15, 13×18, 15×20, 20×25 cm, 4×6, 5×7, 8×10 in, personalizado o el propio de la impresora), la orientación y color o escala de grises. La orientación sigue automáticamente a la imagen hasta que la cambias.

Modos de escala:

| Modo | Qué hace |
|---|---|
| **Ajustar** | La imagen entera cabe dentro de los márgenes; se mantienen las proporciones y puede quedar espacio en blanco en dos lados. |
| **Rellenar / recortar** | La imagen cubre toda el área imprimible; se mantienen las proporciones y se recortan los bordes que sobresalen. |
| **Stretch (whole page)** (estirar: página completa) | La imagen se estira exactamente al área imprimible — sin franjas blancas, pero las proporciones **no** se mantienen. |
| **100% · Tamaño real (96 DPI)** | Un píxel = 1/96 de pulgada. |
| **Porcentaje personalizado** | 0.1–1000 % respecto a 96 DPI (100% = el tamaño anterior). |
| **Ancho / Alto (mm)** | Ancho o alto físico exacto; el otro lado se calcula según las proporciones. |

**Avanzado ▸** añade el tamaño de papel personalizado, los márgenes y una posición exacta en la hoja (o arrastra la imagen en la vista previa; *Centrar* la devuelve al centro). La línea gris muestra el límite físico de la impresora. El último modo de escala elegido se recuerda en `Kadr.ini`.

## Temas

**Más (…) → Tema** ofrece **Claro**, **Oscuro** y **Automático** (el predeterminado).

- **Automático** sigue el *modo de aplicación* de Windows (Configuración → Personalización → Colores, el valor `AppsUseLightTheme`) y cambia en vivo cuando lo modificas en Windows. En sistemas sin esa opción (Windows XP, Vista, 7, 8), Automático equivale a Claro.
- El tema abarca la ventana principal, la barra de herramientas, los botones e iconos, el editor, la vista previa de impresión y los cuadros de diálogo propios de Kadr. En modo oscuro el fondo de la imagen es gris oscuro, y en Windows 10/11 las barras de título y los menús emergentes también son oscuros.
- Algunas partes nativas de Windows conservan el aspecto del sistema: los cuadros de mensaje (ayuda, confirmaciones), los cuadros de diálogo del sistema Abrir / Guardar / Imprimir y los cursores de los controles deslizantes.

## Configuración (Kadr.ini)

Toda la configuración se guarda en `Kadr.ini` junto a `Kadr.exe`. Si la carpeta es de solo lectura, Kadr avisa de que no se puede guardar la configuración.

```ini
[General]
Language=en      ; pl, en, es, fr, de, pt, ru, uk, it, nl, cs, hu, ro, tr, el, ar, he, hi, bn, ur, zh, ja, ko, id, vi, th, fa, ta, te, mr
Theme=auto       ; auto, light or dark
[Print]
Scale=fit        ; fit, fill, stretch, actual, percent, width or height
```

El idioma también se puede elegir en **Más (…) → Idioma**; el cambio se aplica al reiniciar Kadr. El tema se aplica de inmediato.

Idiomas de la interfaz: Polski, English, Español, Français, Deutsch, Português, Русский, Українська, Italiano, Nederlands, Čeština, Magyar, Română, Türkçe, Ελληνικά, العربية, עברית, हिन्दी, বাংলা, اردو, 中文, 日本語, 한국어, Bahasa Indonesia, Tiếng Việt, ไทย, فارسی, தமிழ், తెలుగు, मराठी.

## Compilar desde el código fuente

Requisitos: [Zig 0.11.0](https://ziglang.org/download/0.11.0/zig-windows-x86_64-0.11.0.zip) descomprimido en `tools\zig-windows-x86_64-0.11.0\` (el archivo comprimido no forma parte del repositorio; su SHA-256 figura en `THIRD-PARTY.txt`).

```bat
build.cmd
```

El resultado es `Kadr.exe` (destino `x86-windows.xp`, Pentium III, `ReleaseSmall`) con una cabecera PE compatible con XP. Para regenerar el icono: `tools\build_icon.cmd` (Pillow + windres/objcopy).

Kadr enlaza solo con bibliotecas que existen en Windows XP. Las funciones más recientes (barras de título oscuras, menús y controles oscuros) se cargan en tiempo de ejecución con `LoadLibrary` / `GetProcAddress` y se omiten en sistemas más antiguos.

## Ejecutar las pruebas

- Los conjuntos de pruebas están en subcarpetas de `tests\` (`editor-check`, `print-options`, `loader-check`, `image-check`, `codec-check`, `render-check`, `export-check`); cada uno se inicia con su `check.cmd`, que compila y ejecuta los programas de prueba en Zig. `tests\editor-check\check.cmd` ejecuta las pruebas de la ventana principal (incluidas las de la opción de tema y de la resolución del tema), las pruebas del editor, la comprobación de cobertura de idiomas y una compilación candidata x86/XP; `tests\print-options\check.cmd` ejecuta las pruebas de impresión y de maquetación.
- Las pruebas unitarias de módulos individuales se pueden ejecutar con `zig test`, p. ej. `zig test src\toolbar.zig`, `src\navigation.zig`, `src\image.zig`, `src\zoom.zig`, `src\theme.zig` (con el mismo destino y los mismos flags de inclusión que en `check.cmd`).
- Utilidades en Python 3: `python tests\i18n-check\run.py` (selección de idioma), `python tests\locale_coverage.py` (todas las cadenas de la interfaz están en el catálogo para los 30 idiomas), `python tests\audit_xp.py` (auditoría de importaciones y cabecera XP de `Kadr.exe`), `tests\measure_print.py`, `tests\tooltip_probe.py`, `tests\shot.py`.
- `tests\generate_fixtures.py` crea imágenes de prueba (requiere Pillow); solo se usa durante el desarrollo, nunca lo usa `Kadr.exe`.

## Licencia

**GPL-3.0-or-later** — texto completo en [`LICENSE`](LICENSE).

Componentes de terceros y sus licencias (DjVuLibre, VC100/GDI+, Zig): [`THIRD-PARTY.txt`](THIRD-PARTY.txt). Texto de la GNU GPL v2 para DjVuLibre: [`COPYING.txt`](COPYING.txt).

Esto es una traducción; la versión de referencia es la inglesa ([README.md](README.md)).

## Créditos

- Creado con [Zig](https://ziglang.org/) sobre Win32 y GDI+.
- Decodificación de DjVu: [DjVuLibre](https://djvu.sourceforge.net/) 3.5.27 (GPL-2.0-or-later).
- Los iconos de la interfaz y el logotipo de Kadr son obra original del proyecto (`src/ui.zig`, `tools/make_icon.py`).
- Las imágenes de las capturas de pantalla son imágenes sintéticas generadas para este README.
