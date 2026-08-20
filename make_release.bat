@echo off
chcp 65001 >nul
echo ============================================
echo   PVZ Card Game - GitHub Release Packager
echo   Auto-generates standard zip + apk
echo ============================================
echo.

set PROJECT_DIR=%~dp0
set GODOT="E:\项目储存\pvz-project\pvz-godot\tools\Godot_v4.6.2-stable_win64.exe"
set PROJECT="%PROJECT_DIR%."

:: ============================================
::  Step 1: Read version from version_manager.gd
:: ============================================
echo [0/5] Reading version...
setlocal enabledelayedexpansion
for /f "tokens=2 delims==" %%a in ('findstr /r "const VERSION_MAJOR" "%PROJECT_DIR%scripts\version_manager.gd"') do set MAJOR=%%a
for /f "tokens=2 delims==" %%a in ('findstr /r "const VERSION_MINOR" "%PROJECT_DIR%scripts\version_manager.gd"') do set MINOR=%%a
for /f "tokens=2 delims==" %%a in ('findstr /r "const VERSION_PATCH" "%PROJECT_DIR%scripts\version_manager.gd"') do set PATCH=%%a
set MAJOR=%MAJOR: =%
set MINOR=%MINOR: =%
set PATCH=%PATCH: =%
set VERSION=%MAJOR%.%MINOR%.%PATCH%
echo    Version: v%VERSION%
echo.

:: ============================================
::  Step 2: Clean old files
:: ============================================
echo [1/5] Cleaning old files...
if exist "%PROJECT_DIR%PVZ Plant Card Game.exe" del /F /Q "%PROJECT_DIR%PVZ Plant Card Game.exe" 2>nul
if exist "%PROJECT_DIR%PVZ Plant Card Game.pck" del /F /Q "%PROJECT_DIR%PVZ Plant Card Game.pck" 2>nul
if exist "%PROJECT_DIR%PVZ Plant Card Game.console.exe" del /F /Q "%PROJECT_DIR%PVZ Plant Card Game.console.exe" 2>nul
if exist "%PROJECT_DIR%PVZ_Plant_Card_Game.apk" del /F /Q "%PROJECT_DIR%PVZ_Plant_Card_Game.apk" 2>nul
if exist "%PROJECT_DIR%PVZ_Plant_Card_Game_debug.apk" del /F /Q "%PROJECT_DIR%PVZ_Plant_Card_Game_debug.apk" 2>nul
if exist "%PROJECT_DIR%PVZ-Card-Game_v*" del /F /Q "%PROJECT_DIR%PVZ-Card-Game_v*" 2>nul
if exist "%PROJECT_DIR%PVZ_v*" del /F /Q "%PROJECT_DIR%PVZ_v*" 2>nul
set RELEASE_DIR=%PROJECT_DIR%release_tmp\
if exist "%RELEASE_DIR%" rmdir /S /Q "%RELEASE_DIR%"
mkdir "%RELEASE_DIR%"
echo    Done
echo.

:: ============================================
::  Step 3: Export Windows
:: ============================================
echo [2/5] Exporting Windows build...
%GODOT% --headless --export-release "Windows Desktop" --path %PROJECT%
if %errorlevel% neq 0 (
    echo ❌ Windows export failed!
    pause
    exit /b 1
)
echo    ✅ Windows exported
echo.

:: ============================================
::  Step 4: Package Windows ZIP
:: ============================================
echo [3/5] Packaging Windows ZIP...
set WIN_DIR=%RELEASE_DIR%PVZ-Card-Game_win\
mkdir "%WIN_DIR%"
if exist "%PROJECT_DIR%PVZ Plant Card Game.exe" copy /Y "%PROJECT_DIR%PVZ Plant Card Game.exe" "%WIN_DIR%PVZ-Card-Game.exe" >nul
if exist "%PROJECT_DIR%PVZ Plant Card Game.pck" copy /Y "%PROJECT_DIR%PVZ Plant Card Game.pck" "%WIN_DIR%PVZ-Card-Game.pck" >nul
echo @echo off > "%WIN_DIR%\start.bat"
echo start PVZ-Card-Game.exe >> "%WIN_DIR%\start.bat"
echo Double-click start.bat to play. See README.md for details > "%WIN_DIR%\README.txt"
set WIN_ZIP=%PROJECT_DIR%PVZ-Card-Game_v%VERSION%_Windows.zip
if exist "%WIN_ZIP%" del /F /Q "%WIN_ZIP%"
powershell -Command "Compress-Archive -Path '%WIN_DIR%*' -DestinationPath '%WIN_ZIP%' -Force"
echo    ✅ Windows: PVZ-Card-Game_v%VERSION%_Windows.zip
echo.

:: ============================================
::  Step 5: Export Android APK
:: ============================================
echo [4/5] Exporting Android APK...
%GODOT% --headless --export-release "Android" --path %PROJECT%
if %errorlevel% neq 0 (
    echo ⚠️ Android export failed (SDK may not be configured), skipping...
    goto :final
)
set APK_FILE=
if exist "%PROJECT_DIR%PVZ_Plant_Card_Game.apk" (
    set APK_FILE=%PROJECT_DIR%PVZ_Plant_Card_Game.apk
) else if exist "%PROJECT_DIR%PVZ_Plant_Card_Game_debug.apk" (
    set APK_FILE=%PROJECT_DIR%PVZ_Plant_Card_Game_debug.apk
)
if not "%APK_FILE%"=="" (
    set TARGET_APK=%PROJECT_DIR%PVZ_v%VERSION%_Android.apk
    copy /Y "%APK_FILE%" "%TARGET_APK%" >nul
    echo    ✅ Android: PVZ_v%VERSION%_Android.apk
) else (
    echo    ⚠️ No APK found, skipping Android
)
echo.

:final
:: ============================================
::  Cleanup temp files
:: ============================================
echo [5/5] Cleaning temp files...
if exist "%PROJECT_DIR%PVZ Plant Card Game.exe" del /F /Q "%PROJECT_DIR%PVZ Plant Card Game.exe" 2>nul
if exist "%PROJECT_DIR%PVZ Plant Card Game.pck" del /F /Q "%PROJECT_DIR%PVZ Plant Card Game.pck" 2>nul
if exist "%PROJECT_DIR%PVZ Plant Card Game.console.exe" del /F /Q "%PROJECT_DIR%PVZ Plant Card Game.console.exe" 2>nul
if exist "%PROJECT_DIR%PVZ_Plant_Card_Game.apk" del /F /Q "%PROJECT_DIR%PVZ_Plant_Card_Game.apk" 2>nul
if exist "%PROJECT_DIR%PVZ_Plant_Card_Game_debug.apk" del /F /Q "%PROJECT_DIR%PVZ_Plant_Card_Game_debug.apk" 2>nul
rmdir /S /Q "%RELEASE_DIR%" 2>nul
echo    Done
echo.

echo ============================================
echo   ✅ Build complete! Files ready for GitHub Release:
echo ============================================
echo.
if exist "%WIN_ZIP%" (
    echo   💻 Windows:
    echo      %WIN_ZIP%
    echo.
)
if exist "%TARGET_APK%" (
    echo   📱 Android:
    echo      %TARGET_APK%
    echo.
)
echo ============================================
echo   📌 Next steps for GitHub Release:
echo   1. Open https://github.com/zanyi123/godot-pvz-plant-card-game/releases/new
echo   2. Title: v%VERSION%
echo   3. Paste CHANGELOG content
echo   4. Drag & drop the two files above
echo   5. Click Publish release
echo ============================================
pause
