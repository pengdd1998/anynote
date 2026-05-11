# AnyNote APK Build Script (PowerShell)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AnyNote APK Build Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check for Flutter
Write-Host "Checking for Flutter installation..." -ForegroundColor Yellow
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue

if (-not $flutterCmd) {
    Write-Host "ERROR: Flutter not found in PATH!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Flutter SDK:" -ForegroundColor Yellow
    Write-Host "1. Download from: https://flutter.dev/docs/get-started/install/windows" -ForegroundColor White
    Write-Host "2. Extract to: C:\flutter" -ForegroundColor White
    Write-Host "3. Add to PATH: System Properties > Environment Variables > Path > C:\flutter\bin" -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Flutter found at:" -ForegroundColor Green
Write-Host "  " $flutterCmd.Source"
Write-Host ""

# Show Flutter version
Write-Host "Flutter version:" -ForegroundColor Cyan
& flutter --version
Write-Host ""

# Navigate to frontend directory
$frontendDir = Join-Path $PSScriptRoot "frontend"
if (-not (Test-Path $frontendDir)) {
    Write-Host "ERROR: frontend directory not found at: $frontendDir" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Working directory: $frontendDir" -ForegroundColor Cyan
Write-Host ""

# Change to frontend directory
Set-Location $frontendDir

# Get dependencies
Write-Host "Getting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to get dependencies" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "Dependencies installed successfully" -ForegroundColor Green
Write-Host ""

# Clean build
Write-Host "Cleaning previous build..." -ForegroundColor Yellow
flutter clean
Write-Host ""

# Build release APK
Write-Host "Building release APK..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Gray
Write-Host ""

flutter build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: APK build failed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Try running 'flutter doctor' to check for issues" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""

# Check for APK file
$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apkPath) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "APK Build Successful!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "APK Location:" -ForegroundColor Cyan
    Write-Host "  $apkPath" -ForegroundColor White

    # Get file size
    $fileSize = (Get-Item $apkPath).Length / 1MB
    Write-Host "APK Size:" -ForegroundColor Cyan
    Write-Host ("  {0:N2} MB" -f $fileSize) -ForegroundColor White
    Write-Host ""

    # Ask about installation
    $install = Read-Host "Install to connected device? (y/n)"
    if ($install -eq "y") {
        Write-Host ""
        Write-Host "Checking for connected devices..." -ForegroundColor Yellow
        adb devices

        Write-Host "Installing APK..." -ForegroundColor Yellow
        adb install -r $apkPath

        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "APK installed successfully!" -ForegroundColor Green
            Write-Host ""
            $launch = Read-Host "Launch app now? (y/n)"
            if ($launch -eq "y") {
                Write-Host "Launching app..." -ForegroundColor Yellow
                adb shell am start -n com.anynote.app/.MainActivity
                Write-Host "App launched!" -ForegroundColor Green
            }
        } else {
            Write-Host ""
            Write-Host "ERROR: Failed to install APK" -ForegroundColor Red
        }
    }
} else {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "APK Build Failed!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "APK file not found at expected location: $apkPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please check the error messages above." -ForegroundColor Yellow
}

Write-Host ""
Read-Host "Press Enter to exit"
