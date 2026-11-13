[English](README.md) | [Polski](README.pl.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | **Português** | [Русский](README.ru.md) | [Українська](README.uk.md) | [Italiano](README.it.md) | [Nederlands](README.nl.md) | [Čeština](README.cs.md) | [Magyar](README.hu.md) | [Română](README.ro.md) | [Türkçe](README.tr.md) | [Ελληνικά](README.el.md) | [العربية](README.ar.md) | [עברית](README.he.md) | [हिन्दी](README.hi.md) | [বাংলা](README.bn.md) | [اردو](README.ur.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Bahasa Indonesia](README.id.md) | [Tiếng Việt](README.vi.md) | [ไทย](README.th.md) | [فارسی](README.fa.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [मराठी](README.mr.md)

# Kadr

**Um visualizador e editor de fotos rápido, minúsculo e portátil para Windows — do Windows XP ao Windows 11, em um único `Kadr.exe` com menos de 1 MB.**

O Kadr é um aplicativo nativo Win32/GDI+ escrito em [Zig](https://ziglang.org/). Sem instalador, sem .NET, sem Electron, sem Node.js: copie o `Kadr.exe` para qualquer lugar e execute. As configurações ficam em `Kadr.ini`, ao lado do programa (portátil — nada é gravado no registro nem em AppData).

![Janela principal do Kadr, tema claro](docs/screenshots/main-light.png)

## Sumário

- [Recursos](#recursos)
- [Capturas de tela](#capturas-de-tela)
- [Download / Instalação](#download--instalação)
- [Uso](#uso)
- [Atalhos de teclado](#atalhos-de-teclado)
- [Editor](#editor-1)
- [Impressão](#impressão)
- [Temas](#temas)
- [Configurações (Kadr.ini)](#configurações-kadrini)
- [Compilação a partir do código-fonte](#compilação-a-partir-do-código-fonte)
- [Execução dos testes](#execução-dos-testes)
- [Licença](#licença)
- [Créditos](#créditos)

## Recursos

- **Visualizador** — abra fotos, navegue pela pasta (setas do teclado, anterior/próxima), apresentação de slides, tela cheia, zoom suave (ajustar, 1:1, roda do mouse na posição do cursor, valores digitados como `125%`, `37,5%` ou `200×`), arrastar para mover a imagem, reprodução de GIFs animados, TIFF e DjVu com várias páginas, orientação EXIF automática.
- **Editor** — recorte com moldura ao vivo e proporções predefinidas (livre, 1:1, 4:3, 3:4, 3:2, 2:3, 16:9, A4 retrato/paisagem); caneta, marca-texto, borracha, linha, seta, retângulo e texto; desfazer/refazer; girar e espelhar; brilho, contraste, saturação e preto e branco. As alterações ficam na memória até você salvar.
- **Impressão** — visualização de impressão ao vivo com tamanho do papel, orientação, escala (Ajustar / Preencher (cortar) / Stretch (página inteira) / 100% / % personalizada / largura ou altura em mm), margens, posição, cores ou tons de cinza.
- **Ferramentas de arquivo** — salvar (rotação), salvar como, exportar / comprimir (PNG, JPEG, BMP, TIFF, GIF) com redimensionamento e estimativa de tamanho, copiar a imagem ou o caminho para a área de transferência, renomear, mover para a Lixeira ou excluir permanentemente, mostrar na pasta, definir como papel de parede da área de trabalho.
- **Formatos** — PNG, JPEG/JFIF, BMP/DIB, GIF, TIFF, DjVu, ICO, WMF/EMF, TGA, PCX, PSD (imagem mesclada), PBM/PGM/PPM/PNM, QOI.
- **30 idiomas de interface** — o idioma do Windows é detectado automaticamente (com inglês como alternativa) e pode ser trocado pelo menu; layout da direita para a esquerda para árabe, hebraico, urdu e persa.
- **Temas** — claro, escuro ou automático (segue o modo de aplicativo do Windows e muda na hora).
- **Pequeno** — um único `Kadr.exe` com menos de 1 MB.
- **Windows XP e posteriores** — roda do Windows XP SP3 (x86) até o Windows 10/11.

## Capturas de tela

| Tema claro | Tema escuro |
|---|---|
| ![Janela principal, tema claro](docs/screenshots/main-light.png) | ![Janela principal, tema escuro](docs/screenshots/main-dark.png) |

**Editor** — moldura de recorte com a proporção 3:2, caneta, marca-texto, seta, retângulo e texto:

![Editor com moldura de recorte e desenhos](docs/screenshots/editor-crop.png)

**Visualização de impressão** no modo *Stretch (whole page)* (Esticar: página inteira):

![Visualização de impressão, modo Stretch](docs/screenshots/print-stretch.png)

**O menu "Mais" (…)** com o submenu *Tema*:

![Menu Mais com o submenu Tema](docs/screenshots/more-menu.png)

## Download / Instalação

1. Baixe o `Kadr.exe` da [página de Releases](https://github.com/snakex21/kadr/releases) (um `Kadr.exe` pronto também fica na raiz do repositório).
2. Coloque-o em qualquer pasta com permissão de gravação (por exemplo, um pendrive) e execute. Não há instalador.
3. Para arquivos DjVu, mantenha a pasta `deps\djvu\` do repositório ao lado do `Kadr.exe`.

Para abrir imagens com um clique duplo, use no Windows *Abrir com → Escolher outro aplicativo* em uma imagem e selecione `Kadr.exe`.

**Requisitos:** Windows XP SP3 x86 ou mais recente (Windows 10/11 também funcionam). Nada mais.

> O decodificador DjVu é o antigo DjVuLibre 3.5.27 — abra apenas arquivos DjVu de fontes confiáveis (detalhes em `THIRD-PARTY.txt`).

## Uso

- **Abra** uma imagem com **Abrir** (Ctrl+O), arrastando um arquivo para a janela ou passando-o na linha de comando: `Kadr.exe photo.jpg`.
- **Navegue** pela pasta com ← / → ou com os botões de seta; o contador mostra a posição (por exemplo, `1 / 3`). Mantenha uma seta pressionada para navegar rapidamente.
- **Aplique zoom** com a roda do mouse (o zoom acompanha o cursor), `+` / `−`, **Ajustar** (Home), **1:1** (`1`) ou digite um valor no campo de zoom e pressione Enter. Arraste a imagem para movê-la.
- **Gire** com R / L. A rotação vale para a visualização; **Salvar** (Ctrl+S) grava a rotação no arquivo.
- **Mais (…)** abre o menu com todas as operações de arquivo, o editor, a impressão, a apresentação de slides, a tela cheia, a ajuda, *Verificar atualizações…*, *Tema* e *Idioma*.
- **Verificar atualizações…** apenas abre a página de releases do projeto no GitHub no seu navegador — o próprio Kadr nunca se conecta à internet.

## Atalhos de teclado

### Visualizador

| Atalho | Ação |
|---|---|
| Ctrl+O | Abrir |
| Ctrl+S | Salvar (grava a rotação no arquivo atual) |
| Ctrl+Shift+S | Salvar como |
| Ctrl+E | Editar imagem |
| Ctrl+P | Imprimir |
| Ctrl+C | Copiar imagem |
| Ctrl+Shift+C | Copiar caminho |
| F2 | Renomear |
| Delete | Mover para a Lixeira |
| Shift+Delete | Excluir permanentemente |
| ← / → | Imagem anterior / próxima da pasta (mantenha pressionado para navegar rapidamente) |
| Home | Ajustar à janela |
| 1 | Tamanho real (1:1) |
| + / − (também no teclado numérico) | Ampliar / reduzir |
| Roda do mouse | Zoom na posição do cursor |
| Arrastar com o botão esquerdo | Mover a imagem |
| Clique duplo | Ativar / desativar tela cheia |
| R / L | Girar à direita / à esquerda |
| Espaço | Pausar / retomar a animação |
| Page Up / Page Down | Página anterior / próxima (TIFF, DjVu) |
| F5 | Apresentação (a cada 4 segundos) |
| F11 | Tela cheia |
| Esc | Sair da tela cheia, parar a apresentação |
| F1 | Ajuda e atalhos |
| Shift+F10 ou a tecla Menu | Menu "Mais" (também com clique direito na imagem) |
| Tab / Shift+Tab, Enter ou Espaço | Percorrer os botões da barra de ferramentas e acioná-los |

### Campo de zoom

| Atalho | Ação |
|---|---|
| Enter | Aplicar o zoom digitado (`125%`, `37,5%`, `200×` …) |
| Esc | Restaurar o valor atual |
| Ctrl+A | Selecionar tudo |

### Editor

| Atalho | Ação |
|---|---|
| C | Recortar |
| P | Pen (caneta) |
| H | Highlighter (marca-texto) |
| E | Eraser (borracha) |
| L | Line (linha) |
| A | Arrow (seta) |
| B | Rectangle (retângulo) |
| T | Text (texto) |
| Ctrl+Z | Undo (desfazer) |
| Ctrl+Y ou Ctrl+Shift+Z | Redo (refazer) |
| Enter (ferramenta Recortar) ou clique duplo | Cortar a parte escurecida |
| Enter / Esc (ao digitar texto) | Concluir / cancelar o texto |
| Esc | Fechar o editor sem alterações |

### Visualização de impressão

| Atalho | Ação |
|---|---|
| Arrastar a imagem na folha | Alterar a posição dela |
| Esc | Fechar a visualização (cancela um trabalho de impressão em andamento) |

## Editor

Abra o editor com o botão **Edit** (Ctrl+E). Todas as alterações ficam na memória; o arquivo original não é modificado até você salvar.

- **Recortar** — uma moldura ao vivo com oito alças; arraste a moldura ou as alças, digite X / Y / largura / altura exatos em pixels ou escolha uma proporção predefinida (livre, quadrado 1:1, 4:3, 3:4, 3:2 (4×6 paisagem), 2:3, 16:9, A4 retrato, A4 paisagem). A área fora da moldura fica escurecida; **Recortar** (Enter) corta essa área e **Whole photo** (foto inteira) redefine a moldura.
- **Desenho** — caneta, marca-texto translúcido, borracha (apaga apenas desenhos e textos, nunca a foto), linha reta, seta, retângulo e texto, com dez cores e espessura ajustável.
- **Imagem** — desfazer / refazer, girar 90° para a esquerda ou para a direita, espelhar na horizontal ou na vertical, redefinir tudo.
- **Cor e luz** — brilho, contraste, saturação e preto e branco.
- **Conclusão** — *Aplicar* devolve a imagem editada ao visualizador, *Save as…* (salvar como) salva uma cópia com outro nome, *Print…* (imprimir) vai direto para a visualização de impressão, *Cancelar* (Esc) descarta as alterações.

## Impressão

**Imprimir** (Ctrl+P) abre uma visualização ao vivo da folha. Escolha a impressora, o papel (A3–A6, B4/B5, Letter, Legal, Executive, Tabloid, tamanhos de foto 10×15, 13×18, 15×20, 20×25 cm, 4×6, 5×7, 8×10 in, personalizado ou o da própria impressora), a orientação e cores ou tons de cinza. A orientação acompanha a imagem automaticamente até você alterá-la.

Modos de escala:

| Modo | O que faz |
|---|---|
| **Ajustar** | A imagem inteira cabe dentro das margens; as proporções são mantidas e pode sobrar espaço em branco em dois lados. |
| **Preencher / cortar** | A imagem cobre toda a área imprimível; as proporções são mantidas e as bordas excedentes são cortadas. |
| **Stretch (whole page)** | A imagem é esticada exatamente até a área imprimível — sem faixas brancas, mas as proporções **não** são mantidas. |
| **100% · Tamanho real (96 DPI)** | Um pixel = 1/96 de polegada. |
| **Porcentagem personalizada** | 0,1–1000% em relação a 96 DPI (100% = o tamanho acima). |
| **Largura (mm) / Altura (mm)** | Largura ou altura física exata; o outro lado segue as proporções. |

**Avançado ▸** adiciona tamanho de papel personalizado, margens e uma posição exata na folha (ou arraste a imagem na visualização; *Centralizar* a coloca de volta no meio). A linha cinza mostra o limite físico da impressora. O último modo de escala escolhido fica salvo em `Kadr.ini`.

## Temas

**Mais (…) → Tema** oferece **Claro**, **Escuro** e **Automático** (o padrão).

- **Automático** segue o *modo de aplicativo* do Windows (Configurações → Personalização → Cores, o valor `AppsUseLightTheme`) e muda na hora quando você o altera no Windows. Em sistemas sem essa configuração (Windows XP, Vista, 7, 8), Automático significa Claro.
- O tema abrange a janela principal, a barra de ferramentas, os botões e ícones, o editor, a visualização de impressão e as caixas de diálogo do próprio Kadr. No modo escuro, o fundo da imagem é cinza-escuro e, no Windows 10/11, as barras de título e os menus de contexto também ficam escuros.
- Algumas partes nativas do Windows mantêm a aparência do sistema: as caixas de mensagem (ajuda, confirmações), as caixas de diálogo do sistema Abrir / Salvar / Imprimir e os cursores dos controles deslizantes.

## Configurações (Kadr.ini)

Todas as configurações ficam em `Kadr.ini`, ao lado do `Kadr.exe`. Se a pasta for somente leitura, o Kadr avisa que as configurações não podem ser salvas.

```ini
[General]
Language=en      ; pl, en, es, fr, de, pt, ru, uk, it, nl, cs, hu, ro, tr, el, ar, he, hi, bn, ur, zh, ja, ko, id, vi, th, fa, ta, te, mr
Theme=auto       ; auto, light or dark
[Print]
Scale=fit        ; fit, fill, stretch, actual, percent, width or height
```

O idioma também pode ser escolhido em **Mais (…) → Idioma**; a mudança vale depois de reiniciar o Kadr. O tema é aplicado imediatamente.

Idiomas da interface: Polski, English, Español, Français, Deutsch, Português, Русский, Українська, Italiano, Nederlands, Čeština, Magyar, Română, Türkçe, Ελληνικά, العربية, עברית, हिन्दी, বাংলা, اردو, 中文, 日本語, 한국어, Bahasa Indonesia, Tiếng Việt, ไทย, فارسی, தமிழ், తెలుగు, मराठी.

## Compilação a partir do código-fonte

Requisitos: [Zig 0.11.0](https://ziglang.org/download/0.11.0/zig-windows-x86_64-0.11.0.zip) descompactado em `tools\zig-windows-x86_64-0.11.0\` (o arquivo compactado não faz parte do repositório; o SHA-256 dele está em `THIRD-PARTY.txt`).

```bat
build.cmd
```

O resultado é o `Kadr.exe` (alvo `x86-windows.xp`, Pentium III, `ReleaseSmall`) com um cabeçalho PE compatível com XP. Para regenerar o ícone: `tools\build_icon.cmd` (Pillow + windres/objcopy).

O Kadr só se vincula a bibliotecas que existem no Windows XP. Recursos mais novos (barras de título escuras, menus e controles escuros) são carregados em tempo de execução com `LoadLibrary` / `GetProcAddress` e ignorados em sistemas mais antigos.

## Execução dos testes

- As suítes de teste ficam em subpastas de `tests\` (`editor-check`, `print-options`, `loader-check`, `image-check`, `codec-check`, `render-check`, `export-check`); cada uma é iniciada com o seu `check.cmd`, que compila e executa harnesses em Zig. `tests\editor-check\check.cmd` executa os testes da janela principal (incluindo os testes da configuração e da resolução do tema), os testes do editor, a verificação de cobertura de idiomas e uma compilação candidata x86/XP; `tests\print-options\check.cmd` executa os testes de impressão e de layout.
- Os testes unitários de módulos individuais podem ser executados com `zig test`, por exemplo `zig test src\toolbar.zig`, `src\navigation.zig`, `src\image.zig`, `src\zoom.zig`, `src\theme.zig` (com o mesmo alvo e as mesmas flags de include do `check.cmd`).
- Scripts auxiliares em Python 3: `python tests\i18n-check\run.py` (seleção de idioma), `python tests\locale_coverage.py` (todos os textos da interface estão no catálogo para os 30 idiomas), `python tests\audit_xp.py` (auditoria de importações/cabeçalho XP do `Kadr.exe`), `tests\measure_print.py`, `tests\tooltip_probe.py`, `tests\shot.py`.
- `tests\generate_fixtures.py` cria imagens de teste (requer Pillow); é usado apenas no desenvolvimento, nunca pelo `Kadr.exe`.

## Licença

**GPL-3.0-or-later** — texto completo em [`LICENSE`](LICENSE).

Componentes de terceiros e suas licenças (DjVuLibre, VC100/GDI+, Zig): [`THIRD-PARTY.txt`](THIRD-PARTY.txt). Texto da GNU GPL v2 para o DjVuLibre: [`COPYING.txt`](COPYING.txt).

Esta é uma tradução; a versão em inglês ([README.md](README.md)) é a que prevalece.

## Créditos

- Feito com [Zig](https://ziglang.org/) sobre Win32 e GDI+.
- Decodificação DjVu: [DjVuLibre](https://djvu.sourceforge.net/) 3.5.27 (GPL-2.0-or-later).
- Os ícones da interface e o logotipo do Kadr são arte original do projeto (`src/ui.zig`, `tools/make_icon.py`).
- As imagens nas capturas de tela são imagens sintéticas geradas para este README.
