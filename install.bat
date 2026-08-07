@echo off
setlocal enabledelayedexpansion

:: ── Self-elevate to Administrator right away ────────────────────
:: "net session" silently fails if we're not admin - the standard batch
:: trick for detecting elevation. If not elevated, relaunch this same
:: script with a UAC prompt and exit the non-elevated copy.
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -WorkingDirectory '%~dp0' -Verb RunAs"
    exit /b
)

echo ================================================
echo   Head-Tilt Steering - One-Click Setup
echo ================================================
echo   (Running as Administrator)
echo ================================================
echo.
echo This sets up everything needed: downloads bridge.py
echo if it's missing, installs Python if it's missing,
echo installs the required packages, registers the
echo "headtiltsteer://" link so the website's "Launch
echo Bridge" button works, and starts the bridge.
echo.

set "SCRIPT_DIR=%~dp0"
set "BRIDGE_PATH=%SCRIPT_DIR%bridge.py"
set "BRIDGE_RAW_URL=https://raw.githubusercontent.com/mishaljijo6-cmyk/autoclutch/f2f2d32465086c81be5fa45d11b024b9c05f0ca5/bridge.py"

:: ── Get bridge.py, downloading it if it's not already sitting here ──
if exist "%BRIDGE_PATH%" (
    echo Found bridge.py already in this folder - skipping download.
) else (
    echo bridge.py not found here - downloading it from GitHub...
    powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%BRIDGE_RAW_URL%' -OutFile '%BRIDGE_PATH%' -UseBasicParsing } catch { exit 1 }"
    if not exist "%BRIDGE_PATH%" (
        echo ERROR: Could not download bridge.py - check your internet connection.
        pause
        exit /b 1
    )
    echo Downloaded bridge.py successfully.
)
echo.

:: ── Find Python, auto-installing it only if it's missing ──────────
call :detect_python
if not defined PYTHON_PATH (
    echo No usable Python installation was found on this system.
    echo Installing Python automatically - this can take a minute...
    echo.
    call :install_python
    call :refresh_path
    call :detect_python
) else (
    echo Found existing Python at: %PYTHON_PATH% - skipping install.
)

if not defined PYTHON_PATH (
    echo.
    echo ================================================
    echo   Automatic Python install did not complete
    echo ================================================
    echo Please install it yourself from https://python.org
    echo ^(check "Add python.exe to PATH" during setup^), then
    echo re-run this install.bat. If Python was JUST installed
    echo by this script but still isn't detected, simply
    echo close this window and double-click install.bat again -
    echo a fresh window will see the updated PATH.
    pause
    exit /b 1
)

echo.
echo Installing required Python packages (websockets, pydirectinput)...
"%PYTHON_PATH%" -m pip install --quiet --upgrade "websockets>=12" pydirectinput
if %errorlevel% neq 0 (
    echo WARNING: pip install reported an error. Try manually:
    echo   python -m pip install websockets pydirectinput
    pause
)

echo.
echo Registering the headtiltsteer:// link handler...

reg add "HKCU\Software\Classes\headtiltsteer" /ve /d "URL:HeadTilt Steer Bridge Protocol" /f >nul
reg add "HKCU\Software\Classes\headtiltsteer" /v "URL Protocol" /d "" /f >nul
reg add "HKCU\Software\Classes\headtiltsteer\shell" /f >nul
reg add "HKCU\Software\Classes\headtiltsteer\shell\open" /f >nul
reg add "HKCU\Software\Classes\headtiltsteer\shell\open\command" /ve /d "\"%PYTHON_PATH%\" \"%BRIDGE_PATH%\" \"%%1\"" /f >nul

if %errorlevel% neq 0 (
    echo ERROR: Could not write the registry entry.
    pause
    exit /b 1
)

echo.
echo ================================================
echo   Setup complete!
echo ================================================
echo From now on, the website's "Launch Bridge" button
echo will start bridge.py on its own. The FIRST time you
echo click it, Windows will show a one-time popup asking
echo to confirm opening "HeadTilt Steer Bridge Protocol"
echo - click Open / Allow. After that it launches silently.
echo.
echo Starting the bridge now...
echo.
timeout /t 2 >nul

:: This whole script is already elevated, so the bridge inherits that -
:: no second UAC prompt needed here.
start "Head-Tilt Bridge Server" "%PYTHON_PATH%" "%BRIDGE_PATH%"

echo.
echo A "Head-Tilt Bridge Server" window should now be open
echo and running. Keep it open while you play. You can
echo close this installer window.
echo.
pause
exit /b 0

:: ══════════════════════════════════════════════════════════════════
::  Subroutines
:: ══════════════════════════════════════════════════════════════════

:: Sets PYTHON_PATH if a real, usable Python is found on PATH.
:: Skips the Microsoft Store "app execution alias" stub - on many Windows
:: installs, "python.exe" on PATH just opens the Store instead of running
:: Python. It still shows up in "where python", so it has to be actively
:: skipped.
:detect_python
set "PYTHON_PATH="
where py >nul 2>nul
if %errorlevel% equ 0 (
    for /f "delims=" %%i in ('where py') do (
        set "PYTHON_PATH=%%i"
        goto :eof
    )
)
for /f "delims=" %%i in ('where python 2^>nul') do (
    echo %%i | findstr /i "WindowsApps" >nul
    if errorlevel 1 (
        set "PYTHON_PATH=%%i"
        goto :eof
    )
)
goto :eof

:: Installs Python with no user interaction. Tries winget first (it always
:: fetches the current signed release straight from Microsoft's catalog);
:: if winget isn't available or fails, falls back to downloading the
:: official python.org installer directly and running it silently.
:install_python
where winget >nul 2>nul
if %errorlevel% equ 0 (
    echo Trying winget...
    winget install --id Python.Python.3.13 -e --silent --accept-package-agreements --accept-source-agreements
    if !errorlevel! equ 0 (
        echo winget install finished.
        goto :eof
    )
    echo winget did not succeed here, falling back to a direct download...
)

echo Downloading the official Python installer from python.org...
set "PY_INSTALLER=%TEMP%\python-installer.exe"
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.13.15/python-3.13.15-amd64.exe' -OutFile '%PY_INSTALLER%' -UseBasicParsing } catch { exit 1 }"
if not exist "%PY_INSTALLER%" (
    echo Could not download the Python installer - check your internet connection.
    goto :eof
)
echo Running the Python installer silently ^(this takes a moment, no window will pop up^)...
"%PY_INSTALLER%" /quiet InstallAllUsers=0 PrependPath=1 Include_launcher=1
del "%PY_INSTALLER%" >nul 2>nul
goto :eof

:: Re-reads PATH from the registry into this already-running cmd session.
:: A normal "installer changed PATH" only takes effect in NEW terminals;
:: this pulls the updated value in immediately so we don't have to ask the
:: user to close and reopen the window mid-setup.
:refresh_path
set "SYS_PATH="
set "USR_PATH="
for /f "usebackq tokens=2,*" %%A in (`reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul`) do set "SYS_PATH=%%B"
for /f "usebackq tokens=2,*" %%A in (`reg query "HKCU\Environment" /v Path 2^>nul`) do set "USR_PATH=%%B"
set "PATH=%SYS_PATH%;%USR_PATH%;%PATH%"
goto :eof
