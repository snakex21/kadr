@echo off
setlocal
cd /d "%~dp0..\.."
set "ZIG=tools\zig-windows-x86_64-0.11.0\zig.exe"
python tests\loader-check\prepare.py
if not "%errorlevel%"=="0" exit /b %errorlevel%
set "COMMON=--main-pkg-path . -target x86-windows.xp-gnu -mcpu=pentium3 -fsingle-threaded -fno-stack-check -fno-stack-protector -Itools\zig-windows-x86_64-0.11.0\lib\libc\include\any-windows-any -lkernel32 -lgdiplus -luser32 -lgdi32 -lole32"
"%ZIG%" build-exe tests\loader-check\harness.zig %COMMON% -O ReleaseSmall -femit-bin=tests\loader-check\loader-check.exe
if not "%errorlevel%"=="0" exit /b %errorlevel%
"%ZIG%" build-exe tests\loader-check\harness.zig %COMMON% -O ReleaseSafe -femit-bin=tests\loader-check\loader-check-safe.exe
if not "%errorlevel%"=="0" exit /b %errorlevel%
"%ZIG%" test src\loader.zig %COMMON% -O ReleaseSafe -femit-bin=tests\loader-check\sampling-safe.exe
if not "%errorlevel%"=="0" exit /b %errorlevel%
python tests\loader-check\audit_pe.py
if not "%errorlevel%"=="0" exit /b %errorlevel%
tests\loader-check\loader-check.exe
if not "%errorlevel%"=="0" exit /b %errorlevel%
tests\loader-check\loader-check-safe.exe
if not "%errorlevel%"=="0" exit /b %errorlevel%
echo Loader harness: both configurations passed.
