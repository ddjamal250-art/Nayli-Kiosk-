@echo off
chcp 65001 > nul
title Nayli Market - Build Windows Release
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
echo   Building Windows App (Release Version)
echo ========================================================
call flutter build windows --release
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to build Windows App.
    pause
    exit /b %errorlevel%
)

echo.
echo ========================================================
echo   Build Successful! 
echo   Your app is located in: build\windows\x64\runner\Release
echo ========================================================
pause
