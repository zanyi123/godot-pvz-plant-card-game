@echo off
chcp 65001 >nul
echo ============================================
echo   PVZ卡牌游戏 - 一键发布包
echo ============================================
echo.

set PROJECT_DIR=%~dp0
set GODOT="E:\项目储存\pvz-project\tools\Godot_v4.6.2-stable_win64.exe"
set PROJECT="%PROJECT_DIR%."
set RELEASE_DIR="%PROJECT_DIR%PVZ卡牌游戏_发布版"

:: 创建发布目录
if not exist "%RELEASE_DIR%" (
    mkdir "%RELEASE_DIR%"
)

:: 复制版本说明（如果有）
if exist "%PROJECT_DIR%RELEASE_CHECKLIST.md" (
    copy /Y "%PROJECT_DIR%RELEASE_CHECKLIST.md" "%RELEASE_DIR%\版本说明.txt" >nul
)

echo [1/3] 导出 Windows 版本...
%GODOT% --headless --export-release "Windows Desktop" --path %PROJECT%
if %errorlevel% neq 0 (
    echo ❌ Windows 导出失败！
    pause
    exit /b 1
)
echo ✅ Windows 导出成功！

echo.
echo [2/3] 清理临时文件...
del /F /Q "%PROJECT_DIR%PVZ Plant Card Game.console.exe" 2>nul

echo.
echo [3/3] 复制到发布文件夹...
if exist "%PROJECT_DIR%PVZ Plant Card Game.exe" (
    copy /Y "%PROJECT_DIR%PVZ Plant Card Game.exe" "%RELEASE_DIR%\PVZ卡牌游戏.exe" >nul
    echo ✅ .exe 已复制
)
if exist "%PROJECT_DIR%PVZ Plant Card Game.pck" (
    copy /Y "%PROJECT_DIR%PVZ Plant Card Game.pck" "%RELEASE_DIR%\PVZ卡牌游戏.pck" >nul
    echo ✅ .pck 已复制
)

:: 生成运行脚本
echo @echo off > "%RELEASE_DIR%\启动游戏.bat"
echo start PVZ卡牌游戏.exe >> "%RELEASE_DIR%\启动游戏.bat"
echo ✅ 启动脚本已生成

echo.
echo ============================================
echo   发布完成！
echo ============================================
echo   文件夹: %RELEASE_DIR%
echo   包含: PVZ卡牌游戏.exe + .pck + 启动脚本
echo ============================================

:: 询问是否复制到桌面
echo.
set /p COPY_TO_DESKTOP="是否复制到桌面？(Y/N): "
if /i "%COPY_TO_DESKTOP%"=="Y" (
    set DESKTOP="%USERPROFILE%\Desktop\PVZ卡牌游戏"
    if exist "%DESKTOP%" (
        rmdir /S /Q "%DESKTOP%"
    )
    xcopy /E /I /Y "%RELEASE_DIR%" "%DESKTOP%" >nul
    echo ✅ 已复制到桌面: %DESKTOP%
)

:: 询问是否打压缩包
echo.
set /p MAKE_ZIP="是否打压缩包？(Y/N): "
if /i "%MAKE_ZIP%"=="Y" (
    set ZIP_FILE="%PROJECT_DIR%PVZ卡牌游戏_v1.0.0.zip"
    powershell -Command "Compress-Archive -Path '%RELEASE_DIR%\*' -DestinationPath '%ZIP_FILE%' -Force"
    echo ✅ 压缩包已生成: %ZIP_FILE%
)

echo.
pause
