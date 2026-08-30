@echo off
chcp 65001 > nul
title تشغيل نايل ماركت - Nayli Market Desktop POS
echo ========================================================
echo        جاري تشغيل نظام نايل ماركت المكتبي (Nayli Market POS)
echo ========================================================
echo.

cd /d "%~dp0"

echo [1/2] التحقق من الحزم والاعتماديات...
call flutter pub get

echo [2/2] إطلاق برنامج سطح المكتب...
call flutter run -d windows

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [تنبيه] جاري المحاولة عبر المتصفح السريع (Chrome POS)...
    call flutter run -d chrome
)

pause

