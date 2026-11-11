@echo off
setlocal
cd /d "%~dp0..\.."
python tests\loader-check\prepare.py
if errorlevel 1 exit /b 1
python tests\loader-check\prepare_profile.py
if errorlevel 1 exit /b 1
set "ZIG=tools\zig-windows-x86_64-0.11.0\zig.exe"
"%ZIG%" build-exe tests\loader-check\profile.zig --main-pkg-path . -target x86-windows.xp-gnu -mcpu=pentium3 -fsingle-threaded -fno-stack-check -fno-stack-protector -Itools\zig-windows-x86_64-0.11.0\lib\libc\include\any-windows-any -lkernel32 -lgdiplus -luser32 -lgdi32 -lole32 -O ReleaseSmall -femit-bin=tests\loader-check\profile.exe
if errorlevel 1 exit /b 1
if "%~1"=="" (
    tests\loader-check\profile.exe
) else (
    tests\loader-check\profile.exe > tests\loader-check\profile-%~1.csv
)
exit /b %errorlevel%
