@echo off
setlocal
cd /d "%~dp0..\.."
set "ZIG=tools\zig-windows-x86_64-0.11.0\zig.exe"
python tests\render-check\prepare.py
if errorlevel 1 exit /b 1
set "COMMON=--main-pkg-path . -target x86-windows.xp-gnu -mcpu=pentium3 -fsingle-threaded -fno-stack-check -fno-stack-protector -Itools\zig-windows-x86_64-0.11.0\lib\libc\include\any-windows-any -lkernel32 -lgdiplus -luser32 -lgdi32 -lpsapi"
"%ZIG%" build-exe tests\render-check\harness.zig %COMMON% -O ReleaseSmall -femit-bin=tests\render-check\render-check.exe
if errorlevel 1 exit /b 1
"%ZIG%" build-exe tests\render-check\harness.zig %COMMON% -O ReleaseSafe -femit-bin=tests\render-check\render-check-safe.exe
if errorlevel 1 exit /b 1
python tests\render-check\audit_pe.py
if errorlevel 1 exit /b 1
python tests\render-check\run.py
if errorlevel 1 exit /b 1
echo Render harness: both configurations passed.
