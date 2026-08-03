@echo off
setlocal enabledelayedexpansion
title Python Environment Setup Script
color 0b

echo =======================================================
echo   Python Environment One-Click Setup Script
echo =======================================================
echo.

python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python is not detected. Please ensure Python is installed and added to your system PATH.
    pause
    exit /b
)

echo [Step 0] Upgrading pip...
python -m pip install --upgrade pip
echo.

echo [Step 1] Installing Core Dependencies...
python -m pip install fastapi uvicorn openai python-dotenv
echo.

echo [Step 2] Installing Network Libraries...
python -m pip install requests httpx paramiko netmiko websockets
echo.

echo [Step 3] Installing System Libraries...
python -m pip install psutil pywin32 wmi
echo.

echo [Step 4] Installing Utilities...
python -m pip install pydantic beautifulsoup4 pyyaml colorama
echo.

echo =======================================================
echo   All packages have been installed successfully!
echo =======================================================
pause
