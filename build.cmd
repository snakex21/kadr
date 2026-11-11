@echo off
setlocal
cd /d "%~dp0"
set "ZIG=%~dp0tools\zig-windows-x86_64-0.11.0\zig.exe"
if not exist "%ZIG%" (
  echo Brak Zig 0.11.0. Rozpakuj tools\zig-0.11.0.zip do tools.
  exit /b 1
)
"%ZIG%" build-exe src\main.zig assets\kadr-res.o -Itools\zig-windows-x86_64-0.11.0\lib\libc\include\any-windows-any -target x86-windows.xp-gnu -mcpu=pentium3 -O ReleaseSmall -fsingle-threaded -fno-stack-check -fno-stack-protector -fstrip -femit-bin=Kadr.exe --subsystem windows -lkernel32 -luser32 -lgdi32 -lcomdlg32 -lshell32 -lgdiplus -lole32 -lcomctl32
if errorlevel 1 exit /b 1
"%ZIG%" run tools\fix_xp_header.zig -O ReleaseSafe
if errorlevel 1 exit /b 1
echo Gotowe: Kadr.exe
