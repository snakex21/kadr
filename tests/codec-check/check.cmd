@echo off
setlocal
cd /d "%~dp0..\.."
set "ZIG=tools\zig-windows-x86_64-0.11.0\zig.exe"
python tests\codec-check\prepare.py
if errorlevel 1 exit /b 1
if not exist tests\codec-check\deps\djvu mkdir tests\codec-check\deps\djvu
xcopy /e /i /y deps\djvu tests\codec-check\deps\djvu >nul
if errorlevel 1 exit /b 1
set "COMMON=--main-pkg-path . -target x86-windows.xp-gnu -mcpu=pentium3 -fsingle-threaded -fno-stack-check -fno-stack-protector -Itools\zig-windows-x86_64-0.11.0\lib\libc\include\any-windows-any -lkernel32 -lgdiplus -luser32 -lgdi32 -lole32"
call :build tests\codec-check\harness.zig ReleaseSmall codec-check.exe
if errorlevel 1 exit /b 1
call :build tests\codec-check\harness.zig ReleaseSafe codec-check-safe.exe
if errorlevel 1 exit /b 1
call :build tests\image-check\harness.zig ReleaseSmall legacy-check.exe
if errorlevel 1 exit /b 1
call :build tests\image-check\harness.zig ReleaseSafe legacy-check-safe.exe
if errorlevel 1 exit /b 1
python tests\codec-check\audit_pe.py
if errorlevel 1 exit /b 1
for %%E in (codec-check.exe codec-check-safe.exe legacy-check.exe legacy-check-safe.exe) do (
    tests\codec-check\%%E
    if errorlevel 1 exit /b 1
)
echo Codec and retained legacy harnesses: both configurations passed.
exit /b 0
:build
"%ZIG%" build-exe %1 %COMMON% -O %2 -femit-bin=tests\codec-check\%3
exit /b %errorlevel%
