@echo off
setlocal
cd /d "%~dp0..\..\src"
set "ZIG=..\tools\zig-windows-x86_64-0.11.0\zig.exe"
set "COMMON=--main-pkg-path .. -I..\tools\zig-windows-x86_64-0.11.0\lib\libc\include\any-windows-any -target x86-windows.xp-gnu -mcpu=pentium3 -fsingle-threaded -fno-stack-check -fno-stack-protector -lkernel32 -luser32 -lgdi32 -lcomdlg32 -lshell32 -lgdiplus -lole32 -lcomctl32"
"%ZIG%" test ..\tests\export-check\unit.zig %COMMON% -O ReleaseSafe --test-no-exec -femit-bin=..\tests\export-check\unit.exe
if errorlevel 1 exit /b 1
"%ZIG%" build-exe ..\tests\export-check\app.zig %COMMON% -O ReleaseSafe -femit-bin=..\tests\export-check\dialog.exe
if errorlevel 1 exit /b 1
"%ZIG%" build-exe ..\tests\export-check\app.zig %COMMON% -O ReleaseSmall -fstrip -femit-bin=..\tests\export-check\dialog-small.exe
if errorlevel 1 exit /b 1
cd ..\tests\export-check
python audit_pe.py --fix
if errorlevel 1 exit /b 1
unit.exe
if errorlevel 1 exit /b 1
python native.py
if errorlevel 1 exit /b 1
