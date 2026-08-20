@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set PROJECT_DIR=%~dp0
set GODOT="E:\项目储存\pvz-project\pvz-godot\tools\Godot_v4.6.2-stable_win64.exe"
set PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
set PROJECT="%PROJECT_DIR%."

echo ============================================
echo   PVZ Card Game - GitHub Release Packager
echo ============================================
echo.

:: Step 1: Read version
echo [0/5] Reading version...
set MAJOR=0&set MINOR=0&set PATCH=0
for /f "tokens=5" %%a in ('findstr /c:"VERSION_MAJOR" "%PROJECT_DIR%scripts\version_manager.gd"') do set MAJOR=%%a
for /f "tokens=5" %%a in ('findstr /c:"VERSION_MINOR" "%PROJECT_DIR%scripts\version_manager.gd"') do set MINOR=%%a
for /f "tokens=5" %%a in ('findstr /c:"VERSION_PATCH" "%PROJECT_DIR%scripts\version_manager.gd"') do set PATCH=%%a
set VERSION=%MAJOR%.%MINOR%.%PATCH%
echo    Version: v%VERSION%
echo.

:: Step 2: Clean
echo [1/5] Cleaning...
del /F /Q "%PROJECT_DIR%PVZ Plant Card Game.exe" 2>nul
del /F /Q "%PROJECT_DIR%PVZ Plant Card Game.pck" 2>nul
del /F /Q "%PROJECT_DIR%PVZ Plant Card Game.console.exe" 2>nul
del /F /Q "%PROJECT_DIR%PVZ_Plant_Card_Game.apk" 2>nul
del /F /Q "%PROJECT_DIR%PVZ_Plant_Card_Game_debug.apk" 2>nul
if exist "%PROJECT_DIR%release_tmp" rmdir /S /Q "%PROJECT_DIR%release_tmp"
if exist "%PROJECT_DIR%PVZ-Card-Game_v*" del /F /Q "%PROJECT_DIR%PVZ-Card-Game_v*"
echo    Done
echo.

:: Step 3: Export Windows
echo [2/5] Exporting Windows...
%GODOT% --headless --export-release "Windows Desktop" --path %PROJECT%
if %errorlevel% neq 0 (
    echo    FAILED!
    pause
    exit /b 1
)
echo    Done
echo.

:: Step 4: Package Windows ZIP
echo [3/5] Packaging Windows ZIP...
set WIN_DIR=%PROJECT_DIR%release_tmp\PVZ-Card-Game_win
mkdir "%WIN_DIR%"
if exist "%PROJECT_DIR%PVZ Plant Card Game.exe" copy /Y "%PROJECT_DIR%PVZ Plant Card Game.exe" "%WIN_DIR%PVZ-Card-Game.exe" >nul
if exist "%PROJECT_DIR%PVZ Plant Card Game.pck" copy /Y "%PROJECT_DIR%PVZ Plant Card Game.pck" "%WIN_DIR%PVZ-Card-Game.pck" >nul
echo @echo off > "%WIN_DIR%\start.bat"
echo start PVZ-Card-Game.exe >> "%WIN_DIR%\start.bat"
echo Double-click start.bat to play. > "%WIN_DIR%\README.txt"
set WIN_ZIP=%PROJECT_DIR%PVZ-Card-Game_v%VERSION%_Windows.zip
%PS% -Command "Compress-Archive -Path '%WIN_DIR%*' -DestinationPath '%WIN_ZIP%' -Force"
if exist "%WIN_ZIP%" (
    echo    Done: PVZ-Card-Game_v%VERSION%_Windows.zip
) else (
    echo    FAILED!
)
echo.

:: Step 5: Export Android
echo [4/5] Exporting Android...
%GODOT% --headless --export-release "Android" --path %PROJECT%
if %errorlevel% neq 0 (
    echo    Skipped (keystore not configured)
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
    echo    Done: PVZ_v%VERSION%_Android.apk
) else (
    echo    No APK found
)
echo.

:final
:: Cleanup
echo [5/5] Cleaning temp files...
del /F /Q "%PROJECT_DIR%PVZ Plant Card Game.exe" 2>nul
del /F /Q "%PROJECT_DIR%PVZ Plant Card Game.pck" 2>nul
del /F /Q "%PROJECT_DIR%PVZ Plant Card Game.console.exe" 2>nul
del /F /Q "%PROJECT_DIR%PVZ_Plant_Card_Game.apk" 2>nul
del /F /Q "%PROJECT_DIR%PVZ_Plant_Card_Game_debug.apk" 2>nul
if exist "%PROJECT_DIR%release_tmp" rmdir /S /Q "%PROJECT_DIR%release_tmp"
echo    Done
echo.

echo ============================================
echo   BUILD COMPLETE!
echo ============================================
if exist "%WIN_ZIP%" echo   Windows: %WIN_ZIP%
if exist "%TARGET_APK%" echo   Android: %TARGET_APK%
echo.
echo   Next: Upload to GitHub Release
echo ============================================
pause
