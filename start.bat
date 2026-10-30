@echo off
title AI Journal Companion Launcher

echo ==========================================
echo   Starting AI Journal Companion
echo ==========================================
echo.

REM --------------------------------------------------
REM CONFIGURATION
REM --------------------------------------------------

for %%I in ("%~dp0.") do set "SUBMISSION_DIR=%%~fI"

set "PROJECT_DIR=%SUBMISSION_DIR%"
set "VENV_PYTHON=%PROJECT_DIR%\.venv\Scripts\python.exe"

REM Android SDK ADB
set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"

REM Android application package
set "APP_PACKAGE=com.example.journal"

REM --------------------------------------------------
REM CHECK FILES
REM --------------------------------------------------

if not exist "%VENV_PYTHON%" (
    echo ERROR: Python virtual environment not found:
    echo %VENV_PYTHON%
    pause
    exit /b 1
)

if not exist "%ADB%" (
    echo ERROR: ADB not found:
    echo %ADB%
    echo.
    echo Check your Android SDK installation.
    pause
    exit /b 1
)

REM --------------------------------------------------
REM START OLLAMA
REM --------------------------------------------------

echo Starting Ollama...

start "Ollama Server" cmd /k "ollama serve"

timeout /t 3 /nobreak >nul

REM --------------------------------------------------
REM START FASTAPI
REM --------------------------------------------------

echo Starting FastAPI backend...

start "Journal FastAPI Backend" cmd /k "cd /d "%PROJECT_DIR%" && "%VENV_PYTHON%" -m uvicorn main:app --reload --host 0.0.0.0 --port 8000"

timeout /t 3 /nobreak >nul

REM --------------------------------------------------
REM START ANDROID APP
REM --------------------------------------------------

echo Starting Android Journal app...

"%ADB%" start-server
"%ADB%" wait-for-device

"%ADB%" shell monkey -p %APP_PACKAGE% -c android.intent.category.LAUNCHER 1

echo.
echo ==========================================
echo   AI Journal Companion Started
echo ==========================================
echo.
echo Ollama:  http://localhost:11434
echo FastAPI: http://localhost:8000
echo.
echo Backend: %PROJECT_DIR%\main.py
echo.
pause