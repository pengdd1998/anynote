@echo off
REM AnyNote APK Build Script
REM This script builds a release APK for AnyNote

echo ========================================
echo AnyNote APK Build Script
echo ========================================
echo.

REM Check if Flutter is in PATH
where flutter >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Flutter not found in PATH!
    echo.
    echo Please add Flutter to your PATH or update the FLUTTER_PATH variable below.
    echo.
    goto :end
)

echo Flutter found:
flutter --version
echo.

REM Navigate to frontend directory
cd /d "%~dp0frontend"
if %ERRORLEVEL% NEQ 0 (
    echo Failed to navigate to frontend directory
    goto :end
)

echo Current directory: %CD%
echo.

REM Get dependencies
echo Getting Flutter dependencies...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo Failed to get dependencies
    goto :end
)
echo.

REM Clean build
echo Cleaning build...
flutter clean
echo.

REM Build release APK
echo Building release APK...
echo This may take several minutes...
flutter build apk --release
if %ERRORLEVEL% NEQ 0 (
    echo Failed to build APK
    goto :end
)
echo.

REM Check if APK was created
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo ========================================
    echo APK Build Successful!
    echo ========================================
    echo.
    echo APK Location: build\app\outputs\flutter-apk\app-release.apk

    REM Ask if user wants to install to device
    set /p install="Install to connected device? (y/n): "
    if /i "%install%"=="y" (
        echo.
        echo Installing to device...
        adb devices
        adb install -r "build\app\outputs\flutter-apk\app-release.apk"
        if %ERRORLEVEL% EQU 0 (
            echo.
            echo APK installed successfully!
            echo Launching app...
            adb shell am start -n com.anynote.app/.MainActivity
        ) else (
            echo Failed to install APK
        )
    )
) else (
    echo Build completed but APK file not found at expected location
)
) else (
    echo ========================================
    echo APK Build Failed!
    echo ========================================
    echo.
    echo Please check the error messages above.
)

:end
echo.
pause
