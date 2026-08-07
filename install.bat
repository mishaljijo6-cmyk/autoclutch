@echo off
setlocal enabledelayedexpansion

echo ================================================
echo   Head-Tilt Steering - One-Time Bridge Setup
echo ================================================
echo.
echo This registers a "headtiltsteer://" link on YOUR
echo Windows account only (no admin rights needed for
echo this step) so the website's "Launch Bridge" button
echo can start bridge.py automatically from now on.
echo.

set "SCRIPT_DIR=%~dp0"
set "BRIDGE_PATH=%SCRIPT_DIR%bridge.py"

if not exist "%BRIDGE_PATH%" (
    echo ERROR: bridge.py was not found next to install.bat.
    echo Keep both files together in the same folder and re-run this.
    pause
    exit /b 1
)

where python >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Python was not found on your PATH.
    echo Install it from https://python.org and check
    echo "Add python.exe to PATH" during setup, then re-run this.
    pause
    exit /b 1
)

for /f "delims=" %%i in ('where python') do (
    set "PYTHON_PATH=%%i"
    goto :gotpython
)
:gotpython

echo Found Python at: %PYTHON_PATH%
echo.
echo Installing required Python packages (websockets, pynput)...
"%PYTHON_PATH%" -m pip install --quiet --upgrade websockets pynput
if %errorlevel% neq 0 (
    echo WARNING: pip install reported an error - the bridge may not run
    echo until this is fixed. You can retry manually with:
    echo   python -m pip install websockets pynput
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
echo Go back to the website and click "Launch Bridge".
echo The FIRST time, Windows will show a one-time popup
echo asking to confirm opening "HeadTilt Steer Bridge
echo Protocol" - click Open / Allow. After that it will
echo launch silently every time.
echo.
echo bridge.py will still ask for Administrator rights
echo when it starts (needed for key presses to reach
echo games) - that popup is separate and expected.
echo.
pause
