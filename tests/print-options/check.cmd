@echo off
setlocal
cd /d "%~dp0..\..\src"
set "ZIG=..\tools\zig-windows-x86_64-0.11.0\zig.exe"
set "COMMON=-target x86-windows.xp-gnu -mcpu=pentium3 -fsingle-threaded -fno-stack-check -fno-stack-protector -I..\tools\zig-windows-x86_64-0.11.0\lib\libc\include\any-windows-any -lkernel32 -luser32 -lgdi32 -lcomdlg32 -lgdiplus -lcomctl32"
"%ZIG%" test printing.zig %COMMON% --test-no-exec -femit-bin=..\tests\print-options\printing-tests.exe
if errorlevel 1 exit /b 1
..\tests\print-options\printing-tests.exe > ..\tests\print-options\results.txt 2>&1
set "RESULT=%ERRORLEVEL%"
type ..\tests\print-options\results.txt
if not "%RESULT%"=="0" exit /b %RESULT%
"%ZIG%" test layout.zig -target x86-windows.xp-gnu -mcpu=pentium3 -fsingle-threaded -fno-stack-check -fno-stack-protector --test-no-exec -femit-bin=..\tests\print-options\layout-tests.exe
if errorlevel 1 exit /b 1
..\tests\print-options\layout-tests.exe >> ..\tests\print-options\results.txt 2>&1
if errorlevel 1 exit /b 1
"%ZIG%" build-exe ..\tests\print-options\harness.zig --main-pkg-path .. %COMMON% -O ReleaseSmall -femit-bin=..\tests\print-options\Kadr-print-options.exe
if errorlevel 1 exit /b 1
python ..\tests\print-options\audit.py
if errorlevel 1 exit /b 1
echo PASS: printing/layout tests and dedicated x86-XP preview harness build.
