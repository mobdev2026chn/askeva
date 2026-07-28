@echo off
REM AskEva Android App - Installation & Run Script for Windows

echo ================================
echo   AskEva Android App Setup
echo ================================
echo.

REM Check if Node.js is installed
where node >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo X Node.js is not installed!
    echo Please download from https://nodejs.org/
    pause
    exit /b 1
)

for /f "tokens=*" %%i in ('node --version') do set NODE_VERSION=%%i
echo. Node.js found: %NODE_VERSION%

REM Check if npm is installed
where npm >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo X npm is not installed!
    pause
    exit /b 1
)

for /f "tokens=*" %%i in ('npm --version') do set NPM_VERSION=%%i
echo. npm found: %NPM_VERSION%
echo.

REM Check if Expo CLI is installed globally
where expo >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo. Installing Expo CLI globally...
    call npm install -g expo-cli
    echo. Expo CLI installed
) else (
    for /f "tokens=*" %%i in ('expo --version') do set EXPO_VERSION=%%i
    echo. Expo CLI already installed: %EXPO_VERSION%
)

echo.
echo. Installing project dependencies...
call npm install

if %ERRORLEVEL% EQU 0 (
    echo.
    echo. All dependencies installed successfully!
    echo.
    echo ================================
    echo   Installation Complete!
    echo ================================
    echo.
    echo. Next Steps:
    echo 1. Download 'Expo Go' from Google Play Store
    echo 2. Run: npm start
    echo 3. Scan the QR code with Expo Go
    echo.
    echo. Useful Commands:
    echo   npm start          - Start development server
    echo   npm run android    - Start for Android
    echo   npm run web        - Start web version
    echo.
    pause
) else (
    echo.
    echo X Installation failed. Please check the errors above.
    pause
    exit /b 1
)
