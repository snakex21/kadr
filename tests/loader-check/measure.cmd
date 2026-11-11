@echo off
setlocal
cd /d "%~dp0..\.."
call tests\loader-check\profile.cmd after
if not "%errorlevel%"=="0" exit /b %errorlevel%
rem Baseline executable was retained BEFORE replacing the GDI+ scaler.
rem Run sequentially (not alongside builds/tests); iteration 0 warms each input.
tests\loader-check\profile-before.exe > tests\loader-check\profile-before.csv
if not "%errorlevel%"=="0" exit /b %errorlevel%
tests\loader-check\profile.exe > tests\loader-check\profile-after.csv
if not "%errorlevel%"=="0" exit /b %errorlevel%
python tests\loader-check\compare_profile.py
if not "%errorlevel%"=="0" exit /b %errorlevel%
python tests\loader-check\audit_pe.py
exit /b %errorlevel%
