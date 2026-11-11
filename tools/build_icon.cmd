@echo off
setlocal
cd /d "%~dp0.."
python tools\make_icon.py
if errorlevel 1 exit /b 1
windres --target pe-i386 -i assets\kadr.rc -o assets\kadr-res.o -O coff
if errorlevel 1 exit /b 1
rem Resource-only COFF has no executable handlers; declare SafeSEH compatibility.
objcopy --add-symbol @feat.00=1,global assets\kadr-res.o
if errorlevel 1 exit /b 1
