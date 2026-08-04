@echo off
setlocal

title Douyin Order Manager - Build Installer (Inno Setup)

cd /d "%~dp0\.."

REM ---------------------------------------------------------------------------
REM Inno Setup (ISCC.exe) is required to compile the installer.
REM Auto-detect common install locations; if missing, print help and pause.
REM Uses goto labels (no stray ") so parsing never breaks and never flashes.
REM ---------------------------------------------------------------------------
set "ISCC="
if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" set "ISCC=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"

if not defined ISCC goto :noinnosetup
goto :haveinnosetup

:noinnosetup
echo.
echo [ERROR] Inno Setup was not found.
echo.
echo To build the installer exe, install the free Inno Setup 6 first:
echo   https://jrsoftware.org/isdl.php
echo.
echo If you changed app code, rebuild the Release folder before this:
echo   scripts\build_windows.bat
echo.
pause
exit /b 1

:haveinnosetup
echo Using Inno Setup: %ISCC%
echo.
echo Compiling installer from build\windows\x64\runner\Release
echo.
"%ISCC%" installer.iss
if errorlevel 1 goto :fail

echo.
echo Installer created:
echo   installer\doudian_shop_setup.exe
echo.
goto :done

:fail
echo.
echo Installer build FAILED. Read the error message above.
echo.

:done
pause
