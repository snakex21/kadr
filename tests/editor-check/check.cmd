@echo off
setlocal
cd /d "%~dp0..\..\src"
set "ZIG=..\tools\zig-windows-x86_64-0.11.0\zig.exe"
set "COMMON=-target x86-windows.xp-gnu -mcpu=pentium3 -fsingle-threaded -fno-stack-check -fno-stack-protector -I..\tools\zig-windows-x86_64-0.11.0\lib\libc\include\any-windows-any -lkernel32 -luser32 -lgdi32 -lcomdlg32 -lshell32 -lgdiplus -lole32 -lcomctl32"
"%ZIG%" test main.zig %COMMON% --test-no-exec -femit-bin=..\tests\editor-check\main-tests.exe
if errorlevel 1 exit /b 1
..\tests\editor-check\main-tests.exe > ..\tests\editor-check\unit-results.txt 2>&1
if errorlevel 1 (type ..\tests\editor-check\unit-results.txt & exit /b 1)
"%ZIG%" test editor.zig %COMMON% --test-no-exec -femit-bin=..\tests\editor-check\editor-tests.exe
if errorlevel 1 exit /b 1
..\tests\editor-check\editor-tests.exe >> ..\tests\editor-check\unit-results.txt 2>&1
if errorlevel 1 exit /b 1
python -B ..\tests\locale_coverage.py
if errorlevel 1 exit /b 1
"%ZIG%" build-exe main.zig ..\assets\kadr-res.o %COMMON% -O ReleaseSmall -fstrip -femit-bin=..\tests\Kadr-editor.exe --subsystem windows
if errorlevel 1 exit /b 1
type ..\tests\editor-check\unit-results.txt
echo PASS: editor and main tests, language coverage, x86-XP candidate build
