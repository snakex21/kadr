@echo off
setlocal
cd /d "%~dp0..\.."
set "ZIG=tools\zig-windows-x86_64-0.11.0\zig.exe"
python tests\image-check\prepare.py
if errorlevel 1 exit /b 1
"%ZIG%" build-exe tests\image-check\harness.zig --main-pkg-path . -target x86-windows.xp-gnu -mcpu=pentium3 -O ReleaseSmall -fsingle-threaded -fno-stack-check -fno-stack-protector -isystem tools\zig-windows-x86_64-0.11.0\lib\libc\include\any-windows-any -femit-bin=tests\image-check\image-check.exe -lkernel32 -lgdiplus -luser32 -lgdi32 -lole32
if errorlevel 1 exit /b 1
"%ZIG%" build-exe tests\image-check\harness.zig --main-pkg-path . -target x86-windows.xp-gnu -mcpu=pentium3 -O ReleaseSafe -fsingle-threaded -fno-stack-check -fno-stack-protector -isystem tools\zig-windows-x86_64-0.11.0\lib\libc\include\any-windows-any -femit-bin=tests\image-check\image-check-safe.exe -lkernel32 -lgdiplus -luser32 -lgdi32 -lole32
if errorlevel 1 exit /b 1
python tests\image-check\audit_pe.py
if errorlevel 1 exit /b 1
tests\image-check\image-check.exe
if errorlevel 1 exit /b 1
tests\image-check\image-check-safe.exe
if errorlevel 1 exit /b 1
echo Image harness: both configurations passed.
