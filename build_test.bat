@echo off
echo ========================================================
echo   Updating Database Models (build_runner)
echo ========================================================
call flutter pub run build_runner build --delete-conflicting-outputs
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to run build_runner. Please check if flutter is installed correctly.
    pause
    exit /b %errorlevel%
)

echo.
echo ========================================================
echo   Building Android APK (Test Version)
echo ========================================================
call flutter build apk
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to build APK.
    pause
    exit /b %errorlevel%
)

echo.
echo ========================================================
echo   Build Successful! 
echo   Your APK is located in: build\app\outputs\flutter-apk\app-release.apk
echo ========================================================
pause
