@echo off
chcp 65001 >nul
echo ============================================
echo   PVZ卡牌游戏 - 一键双平台导出
echo ============================================
echo.

set GODOT="E:\cursor储存\pvz-godot\tools\Godot_v4.6.2-stable_win64.exe"
set PROJECT="E:\cursor储存\pvz-godot\pvz-plant-card-game"
set RELEASE_DIR="%PROJECT%\PVZ卡牌游戏_发布版"

echo [1/3] 导出 Windows 版本...
%GODOT% --headless --export-release "Windows Desktop" --path %PROJECT%
if %errorlevel% neq 0 (
    echo ❌ Windows 导出失败！
    pause
    exit /b 1
)
echo ✅ Windows 导出成功！

echo.
echo [2/3] 清理发布版旧文件并复制新版本...
if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"
:: 删除所有旧 exe/pck（包括中英文两种文件名）
del /F /Q "%RELEASE_DIR%\*.exe" 2>nul
del /F /Q "%RELEASE_DIR%\*.pck" 2>nul
:: 复制新导出的文件到发布版（重命名为中文名）
if exist "%PROJECT%\PVZ Plant Card Game.exe" (
    copy /Y "%PROJECT%\PVZ Plant Card Game.exe" "%RELEASE_DIR%\PVZ卡牌游戏.exe" >nul
    echo ✅ .exe 已复制
)
if exist "%PROJECT%\PVZ Plant Card Game.pck" (
    copy /Y "%PROJECT%\PVZ Plant Card Game.pck" "%RELEASE_DIR%\PVZ卡牌游戏.pck" >nul
    echo ✅ .pck 已复制
)
:: 生成启动脚本
echo @echo off > "%RELEASE_DIR%\启动游戏.bat"
echo start PVZ卡牌游戏.exe >> "%RELEASE_DIR%\启动游戏.bat"

echo.
echo [3/3] 导出 Android APK...
%GODOT% --headless --export-debug "Android" --path %PROJECT%
if %errorlevel% neq 0 (
    echo ❌ Android 导出失败！
    pause
    exit /b 1
)
echo ✅ Android 导出成功！

echo.
echo ============================================
echo   全部导出完成！
echo ============================================
echo   Windows: PVZ卡牌游戏_发布版\PVZ卡牌游戏.exe
if exist "%PROJECT%\PVZ_Plant_Card_Game_debug.apk" (
    echo   Android: PVZ_Plant_Card_Game_debug.apk
) else (
    echo   Android: PVZ_Plant_Card_Game.apk
)
echo ============================================
pause
