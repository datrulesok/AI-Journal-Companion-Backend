@echo off
setlocal EnableExtensions EnableDelayedExpansion

title AI Journal Companion Launcher

echo ==========================================
echo   Starting AI Journal Companion
echo ==========================================
echo.

REM ==================================================
REM USE THIS BATCH FILE'S LOCATION
REM ==================================================

for %%I in ("%~dp0.") do set "SUBMISSION_DIR=%%~fI"

set "BACKEND_DIR=%SUBMISSION_DIR%"
set "ANDROID_DIR=%SUBMISSION_DIR%\AIJournalCompanion"

set "MAIN_PY=%BACKEND_DIR%\main.py"
set "VENV_DIR=%BACKEND_DIR%\.venv"
set "VENV_PYTHON=%VENV_DIR%\Scripts\python.exe"
set "APP_PACKAGE=com.example.journal"
set "APK_PATH=%SUBMISSION_DIR%\app-release.apk"

REM Leave empty to use the first available Android emulator.
set "AVD_NAME="

REM ==================================================
REM CHECK PROJECT FILES
REM ==================================================

if not exist "%MAIN_PY%" (
    echo ERROR: main.py was not found:
    echo %MAIN_PY%
    goto :FAILED
)

if not exist "%ANDROID_DIR%" (
    echo ERROR: Android project was not found:
    echo %ANDROID_DIR%
    goto :FAILED
)

if not exist "%APK_PATH%" (
    echo ERROR: Release APK was not found next to the script:
    echo %APK_PATH%
    goto :FAILED
)

REM ==================================================
REM FIND ANDROID SDK
REM ==================================================

set "ANDROID_SDK="

if defined ANDROID_SDK_ROOT (
    if exist "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" (
        set "ANDROID_SDK=%ANDROID_SDK_ROOT%"
    )
)

if not defined ANDROID_SDK (
    if defined ANDROID_HOME (
        if exist "%ANDROID_HOME%\platform-tools\adb.exe" (
            set "ANDROID_SDK=%ANDROID_HOME%"
        )
    )
)

if not defined ANDROID_SDK (
    if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
        set "ANDROID_SDK=%LOCALAPPDATA%\Android\Sdk"
    )
)

if not defined ANDROID_SDK (
    echo ERROR: The Android SDK could not be found.
    echo Install it through Android Studio's SDK Manager.
    goto :FAILED
)

set "ADB=%ANDROID_SDK%\platform-tools\adb.exe"
set "EMULATOR=%ANDROID_SDK%\emulator\emulator.exe"

echo Android SDK:
echo %ANDROID_SDK%
echo.

REM ==================================================
REM FIND PYTHON AND CREATE THE VIRTUAL ENVIRONMENT
REM ==================================================

if not exist "%VENV_PYTHON%" (
    echo Creating the Python virtual environment...

    where py.exe >nul 2>&1

    if not errorlevel 1 (
        py -3 -m venv "%VENV_DIR%"
    ) else (
        where python.exe >nul 2>&1

        if errorlevel 1 (
            echo ERROR: Python 3 could not be found.
            goto :FAILED
        )

        python -m venv "%VENV_DIR%"
    )

    if errorlevel 1 (
        echo ERROR: The Python virtual environment could not be created.
        goto :FAILED
    )
)

echo Checking Python packages...

"%VENV_PYTHON%" -c "import fastapi, uvicorn, requests, pydantic" >nul 2>&1

if errorlevel 1 (
    echo Installing Python packages...

    "%VENV_PYTHON%" -m pip install fastapi uvicorn requests pydantic

    if errorlevel 1 (
        echo ERROR: Python packages could not be installed.
        goto :FAILED
    )
)

echo Python backend environment is ready.
echo.

REM ==================================================
REM FIND OLLAMA
REM ==================================================

set "OLLAMA_EXE="

for /f "delims=" %%I in ('where ollama.exe 2^>nul') do (
    if not defined OLLAMA_EXE (
        set "OLLAMA_EXE=%%I"
    )
)

if not defined OLLAMA_EXE (
    if exist "%LOCALAPPDATA%\Programs\Ollama\ollama.exe" (
        set "OLLAMA_EXE=%LOCALAPPDATA%\Programs\Ollama\ollama.exe"
    )
)

if not defined OLLAMA_EXE (
    echo ERROR: Ollama could not be found.
    goto :FAILED
)

echo Ollama:
echo !OLLAMA_EXE!
echo.

REM ==================================================
REM START ADB
REM ==================================================

echo Starting ADB...

"%ADB%" start-server >nul

if errorlevel 1 (
    echo ERROR: ADB could not be started.
    goto :FAILED
)

REM ==================================================
REM FIND OR START AN ANDROID DEVICE
REM ==================================================

set "DEVICE_SERIAL="

for /f "skip=1 tokens=1,2" %%A in ('"%ADB%" devices') do (
    if "%%B"=="device" (
        if not defined DEVICE_SERIAL (
            set "DEVICE_SERIAL=%%A"
        )
    )
)

if defined DEVICE_SERIAL (
    echo Android device found: !DEVICE_SERIAL!
    goto :DEVICE_READY
)

if not exist "%EMULATOR%" (
    echo ERROR: No device is connected and the Android emulator is unavailable.
    goto :FAILED
)

echo No device is connected. Looking for an emulator...

if not defined AVD_NAME (
    for /f "delims=" %%A in ('"%EMULATOR%" -list-avds') do (
        if not defined AVD_NAME (
            set "AVD_NAME=%%A"
        )
    )
)

if not defined AVD_NAME (
    echo ERROR: No Android Virtual Device exists.
    echo Create one using Android Studio Device Manager.
    goto :FAILED
)

echo Starting emulator: !AVD_NAME!

start "Android Emulator" "%EMULATOR%" -avd "!AVD_NAME!"

echo Waiting for the emulator...

"%ADB%" wait-for-device

:WAIT_FOR_ANDROID_BOOT

set "BOOT_COMPLETED="

for /f "delims=" %%A in ('"%ADB%" shell getprop sys.boot_completed 2^>nul') do (
    set "BOOT_COMPLETED=%%A"
)

if not "!BOOT_COMPLETED!"=="1" (
    timeout /t 2 /nobreak >nul
    goto :WAIT_FOR_ANDROID_BOOT
)

set "DEVICE_SERIAL="

for /f "skip=1 tokens=1,2" %%A in ('"%ADB%" devices') do (
    if "%%B"=="device" (
        if not defined DEVICE_SERIAL (
            set "DEVICE_SERIAL=%%A"
        )
    )
)

if not defined DEVICE_SERIAL (
    echo ERROR: The emulator did not connect.
    goto :FAILED
)

:DEVICE_READY

echo Android device ready: !DEVICE_SERIAL!
echo.

REM ==================================================
REM START OLLAMA
REM ==================================================

echo Checking Ollama...

powershell -NoProfile -Command "try { Invoke-WebRequest -Uri 'http://127.0.0.1:11434/api/tags' -UseBasicParsing -TimeoutSec 2 | Out-Null; exit 0 } catch { exit 1 }"

if errorlevel 1 (
    echo Starting Ollama...
    start "Ollama Server" cmd /k ""!OLLAMA_EXE!" serve"
) else (
    echo Ollama is already running.
)

echo Waiting for Ollama...

set "OLLAMA_READY="

for /L %%A in (1,1,30) do (
    powershell -NoProfile -Command "try { Invoke-WebRequest -Uri 'http://127.0.0.1:11434/api/tags' -UseBasicParsing -TimeoutSec 2 | Out-Null; exit 0 } catch { exit 1 }" >nul 2>&1

    if not errorlevel 1 (
        set "OLLAMA_READY=1"
        goto :OLLAMA_READY
    )

    timeout /t 1 /nobreak >nul
)

:OLLAMA_READY

if not defined OLLAMA_READY (
    echo ERROR: Ollama did not start within 30 seconds.
    goto :FAILED
)

echo Ollama is ready.
echo.

REM ==================================================
REM CHECK THE MODEL
REM ==================================================

echo Checking for gemma:2b...

"!OLLAMA_EXE!" list | findstr /I /B /C:"gemma:2b" >nul

if errorlevel 1 (
    echo Downloading gemma:2b...
    "!OLLAMA_EXE!" pull gemma:2b

    if errorlevel 1 (
        echo ERROR: gemma:2b could not be downloaded.
        goto :FAILED
    )
)

echo gemma:2b is ready.
echo.

REM ==================================================
REM START FASTAPI
REM ==================================================

echo Checking FastAPI...

powershell -NoProfile -Command "try { Invoke-WebRequest -Uri 'http://127.0.0.1:8000/openapi.json' -UseBasicParsing -TimeoutSec 2 | Out-Null; exit 0 } catch { exit 1 }"

if errorlevel 1 (
    echo Starting FastAPI...
    start "Journal FastAPI Backend" /D "%BACKEND_DIR%" cmd /k ""%VENV_PYTHON%" -m uvicorn main:app --host 0.0.0.0 --port 8000"
) else (
    echo FastAPI is already running.
)

echo Waiting for FastAPI...

set "FASTAPI_READY="

for /L %%A in (1,1,30) do (
    powershell -NoProfile -Command "try { Invoke-WebRequest -Uri 'http://127.0.0.1:8000/openapi.json' -UseBasicParsing -TimeoutSec 2 | Out-Null; exit 0 } catch { exit 1 }" >nul 2>&1

    if not errorlevel 1 (
        set "FASTAPI_READY=1"
        goto :FASTAPI_READY
    )

    timeout /t 1 /nobreak >nul
)

:FASTAPI_READY

if not defined FASTAPI_READY (
    echo ERROR: FastAPI did not start within 30 seconds.
    goto :FAILED
)

echo FastAPI is ready.
echo.

REM ==================================================
REM APPLY ADB REVERSE MAPPING
REM ==================================================

echo Setting up ADB reverse mapping on port 8000...

"%ADB%" -s "!DEVICE_SERIAL!" reverse tcp:8000 tcp:8000

if errorlevel 1 (
    echo WARNING: Failed to reverse port 8000. Your app may not connect to the local API.
) else (
    echo Port 8000 successfully mapped to host machine.
)
echo.

REM ==================================================
REM INSTALL THE APP
REM ==================================================

echo Uninstalling old version to prevent signature conflicts...
"%ADB%" -s "!DEVICE_SERIAL!" uninstall "%APP_PACKAGE%" >nul 2>&1

echo Installing the release APK...
"%ADB%" -s "!DEVICE_SERIAL!" install -r "%APK_PATH%"

if errorlevel 1 (
    echo ERROR: The application could not be installed.
    goto :FAILED
)

REM ==================================================
REM LAUNCH THE APP
REM ==================================================

echo Launching AI Journal Companion...

"%ADB%" -s "!DEVICE_SERIAL!" shell am force-stop "%APP_PACKAGE%"
"%ADB%" -s "!DEVICE_SERIAL!" shell am start -n "%APP_PACKAGE%/.MainActivity"

if errorlevel 1 (
    echo ERROR: The application could not be launched.
    goto :FAILED
)

echo.
echo ==========================================
echo   AI Journal Companion Started
echo ==========================================
echo.
echo Submission folder:
echo   %SUBMISSION_DIR%
echo.
echo Ollama:
echo   http://127.0.0.1:11434
echo.
echo FastAPI:
echo   http://127.0.0.1:8000
echo.
echo Android Connection:
echo   Mapped 127.0.0.1:8000 via adb reverse
echo.
echo Android device:
echo   !DEVICE_SERIAL!
echo.

pause
exit /b 0

:FAILED

echo.
echo ==========================================
echo   Startup Failed
echo ==========================================
echo.

pause
exit /b 1