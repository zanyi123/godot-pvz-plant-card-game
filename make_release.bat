@echo off
chcp 65001 >nul
echo ============================================
echo   PVZ卡牌游戏 - GitHub Release 打包工具
echo   自动生成标准命名的 zip + apk 文件
echo ============================================
echo.

set PROJECT_DIR=%~dp0
set GODOT="E:\项目储存\pvz-project\pvz-godot\tools\Godot_v4.6.2-stable_win64.exe"
set PROJECT="%PROJECT_DIR%."

:: ============================================
::  第一步：从 version_manager.gd 读取版本号
:: ============================================
echo [0/5] 读取版本号...
setlocal enabledelayedexpansion
for /f "tokens=2 delims==" %%a in ('findstr /r "const VERSION_MAJOR" "%PROJECT_DIR%scripts\version_manager.gd"') do set MAJOR=%%a
for /f "tokens=2 delims==" %%a in ('findstr /r "const VERSION_MINOR" "%PROJECT_DIR%scripts\version_manager.gd"') do set MINOR=%%a
for /f "tokens=2 delims==" %%a in ('findstr /r "const VERSION_PATCH" "%PROJECT_DIR%scripts\version_manager.gd"') do set PATCH=%%a
set MAJOR=%MAJOR: =%
set MINOR=%MINOR: =%
set PATCH=%PATCH: =%
set VERSION=%MAJOR%.%MINOR%.%PATCH%
echo    当前版本: v%VERSION%
echo.

:: ============================================
::  第二步：清理旧文件
:: ============================================
echo [1/5] 清理旧文件...
if exist "%PROJECT_DIR%PVZ Plant Card Game.exe" del /F /Q "%PROJECT_DIR%PVZ Plant Card Game.exe" 2>nul
if exist "%PROJECT_DIR%PVZ Plant Card Game.pck" del /F /Q "%PROJECT_DIR%PVZ Plant Card Game.pck" 2>nul
if exist "%PROJECT_DIR%PVZ Plant Card Game.console.exe" del /F /Q "%PROJECT_DIR%PVZ Plant Card Game.console.exe" 2>nul
if exist "%PROJECT_DIR%PVZ_Plant_Card_Game.apk" del /F /Q "%PROJECT_DIR%PVZ_Plant_Card_Game.apk" 2>nul
if exist "%PROJECT_DIR%PVZ_Plant_Card_Game_debug.apk" del /F /Q "%PROJECT_DIR%PVZ_Plant_Card_Game_debug.apk" 2>nul
set RELEASE_DIR=%PROJECT_DIR%release_tmp\
if exist "%RELEASE_DIR%" rmdir /S /Q "%RELEASE_DIR%"
mkdir "%RELEASE_DIR%"
echo    清理完成
echo.

:: ============================================
::  第三步：导出 Windows 版
:: ============================================
echo [2/5] 导出 Windows 版本...
%GODOT% --headless --export-release "Windows Desktop" --path %PROJECT%
if %errorlevel% neq 0 (
    echo ❌ Windows 导出失败！
    pause
    exit /b 1
)
echo    ✅ Windows 导出成功
echo.

:: ============================================
::  第四步：打包 Windows zip
:: ============================================
echo [3/5] 打包 Windows ZIP...
set WIN_DIR=%RELEASE_DIR%PVZ卡牌游戏_win\
mkdir "%WIN_DIR%"
if exist "%PROJECT_DIR%PVZ Plant Card Game.exe" copy /Y "%PROJECT_DIR%PVZ Plant Card Game.exe" "%WIN_DIR%PVZ卡牌游戏.exe" >nul
if exist "%PROJECT_DIR%PVZ Plant Card Game.pck" copy /Y "%PROJECT_DIR%PVZ Plant Card Game.pck" "%WIN_DIR%PVZ卡牌游戏.pck" >nul
echo @echo off > "%WIN_DIR%\启动游戏.bat"
echo start PVZ卡牌游戏.exe >> "%WIN_DIR%\启动游戏.bat"
echo 双版本解压即可游玩，如遇问题请查看仓库 README.md > "%WIN_DIR%\安装说明.txt"
set WIN_ZIP=%PROJECT_DIR%PVZ卡牌游戏_v%VERSION%_Windows.zip
if exist "%WIN_ZIP%" del /F /Q "%WIN_ZIP%"
powershell -Command "Compress-Archive -Path '%WIN_DIR%*' -DestinationPath '%WIN_ZIP%' -Force"
echo    ✅ Windows 压缩包: PVZ卡牌游戏_v%VERSION%_Windows.zip
echo.

:: ============================================
::  第五步：导出 Android APK
:: ============================================
echo [4/5] 导出 Android APK...
%GODOT% --headless --export-release "Android" --path %PROJECT%
if %errorlevel% neq 0 (
    echo ⚠️ Android 导出失败（可能是没有配置 Android SDK），跳过...
    goto :final
)
set APK_FILE=
if exist "%PROJECT_DIR%PVZ_Plant_Card_Game.apk" (
    set APK_FILE=%PROJECT_DIR%PVZ_Plant_Card_Game.apk
) else if exist "%PROJECT_DIR%PVZ_Plant_Card_Game_debug.apk" (
    set APK_FILE=%PROJECT_DIR%PVZ_Plant_Card_Game_debug.apk
)
if not "%APK_FILE%"=="" (
    set TARGET_APK=%PROJECT_DIR%PVZ卡牌游戏_v%VERSION%_Android.apk
    copy /Y "%APK_FILE%" "%TARGET_APK%" >nul
    echo    ✅ Android APK: PVZ卡牌游戏_v%VERSION%_Android.apk
) else (
    echo    ⚠️ 未找到 APK 文件，跳过 Android
)
echo.

:final
:: ============================================
::  清理临时文件
:: ============================================
echo [5/5] 清理临时文件...
if exist "%PROJECT_DIR%PVZ Plant Card Game.exe" del /F /Q "%PROJECT_DIR%PVZ Plant Card Game.exe" 2>nul
if exist "%PROJECT_DIR%PVZ Plant Card Game.pck" del /F /Q "%PROJECT_DIR%PVZ Plant Card Game.pck" 2>nul
if exist "%PROJECT_DIR%PVZ Plant Card Game.console.exe" del /F /Q "%PROJECT_DIR%PVZ Plant Card Game.console.exe" 2>nul
if exist "%PROJECT_DIR%PVZ_Plant_Card_Game.apk" del /F /Q "%PROJECT_DIR%PVZ_Plant_Card_Game.apk" 2>nul
if exist "%PROJECT_DIR%PVZ_Plant_Card_Game_debug.apk" del /F /Q "%PROJECT_DIR%PVZ_Plant_Card_Game_debug.apk" 2>nul
rmdir /S /Q "%RELEASE_DIR%" 2>nul
echo    清理完成
echo.

echo ============================================
echo   ✅ 打包完成！以下是上传 GitHub Release 的文件：
echo ============================================
echo.
if exist "%WIN_ZIP%" (
    echo   💻 Windows 版：
    echo      %WIN_ZIP%
    echo.
)
if exist "%TARGET_APK%" (
    echo   📱 Android 版：
    echo      %TARGET_APK%
    echo.
)
echo ============================================
echo   📌 接下来去 GitHub 操作：
echo   1. 打开 https://github.com/zanyi123/godot-pvz-plant-card-game/releases/new
echo   2. 标题填 v%VERSION%
echo   3. 内容填写 CHANGELOG 本次更新内容
echo   4. 把上面两个文件拖进去上传
echo   5. 点 Publish release
echo ============================================
pause
