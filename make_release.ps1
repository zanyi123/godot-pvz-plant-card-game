# PVZ Card Game - GitHub Release Packager
# Auto-generates standard zip + apk

$ErrorActionPreference = "Continue"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$GodotExe = "E:\项目储存\pvz-project\pvz-godot\tools\Godot_v4.6.2-stable_win64.exe"
$ProjectPath = "$ProjectDir\."

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  PVZ Card Game - GitHub Release Packager" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Read version
Write-Host "[0/5] Reading version..." -ForegroundColor Yellow
$versionFile = Join-Path $ProjectDir "scripts\version_manager.gd"
$major = $minor = $patch = "0"
if (Test-Path $versionFile) {
    $content = Get-Content $versionFile
    foreach ($line in $content) {
        if ($line -match 'VERSION_MAJOR\s*:\s*int\s*=\s*(\d+)') { $major = $Matches[1] }
        if ($line -match 'VERSION_MINOR\s*:\s*int\s*=\s*(\d+)') { $minor = $Matches[1] }
        if ($line -match 'VERSION_PATCH\s*:\s*int\s*=\s*(\d+)') { $patch = $Matches[1] }
    }
}
$Version = "$major.$minor.$patch"
Write-Host "   Version: v$Version" -ForegroundColor Green
Write-Host ""

# Step 2: Clean
Write-Host "[1/5] Cleaning old files..." -ForegroundColor Yellow
Get-ChildItem -Path $ProjectDir -Filter "PVZ-Card-Game_v*" -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -Path $ProjectDir -Filter "PVZ_v*.apk" -ErrorAction SilentlyContinue | Remove-Item -Force
if (Test-Path "$ProjectDir\release_tmp") { Remove-Item "$ProjectDir\release_tmp" -Recurse -Force }
# Clean Godot default outputs
@("PVZ Plant Card Game.exe", "PVZ Plant Card Game.pck", "PVZ Plant Card Game.console.exe",
  "PVZ_Plant_Card_Game.apk", "PVZ_Plant_Card_Game_debug.apk") | ForEach-Object {
    $f = Join-Path $ProjectDir $_
    if (Test-Path $f) { Remove-Item $f -Force }
}
Write-Host "   Done" -ForegroundColor Green
Write-Host ""

# Step 3: Export Windows
Write-Host "[2/5] Exporting Windows build..." -ForegroundColor Yellow
& $GodotExe --headless --export-release "Windows Desktop" --path $ProjectPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "   Windows export failed!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "   Windows exported" -ForegroundColor Green
Write-Host ""

# Step 4: Package Windows ZIP
Write-Host "[3/5] Packaging Windows ZIP..." -ForegroundColor Yellow
$WinDir = Join-Path $ProjectDir "release_tmp\PVZ-Card-Game_win"
New-Item -ItemType Directory -Path $WinDir -Force | Out-Null

if (Test-Path "$ProjectDir\PVZ Plant Card Game.exe") {
    Copy-Item "$ProjectDir\PVZ Plant Card Game.exe" "$WinDir\PVZ-Card-Game.exe" -Force
}
if (Test-Path "$ProjectDir\PVZ Plant Card Game.pck") {
    Copy-Item "$ProjectDir\PVZ Plant Card Game.pck" "$WinDir\PVZ-Card-Game.pck" -Force
}

@"
@echo off
start PVZ-Card-Game.exe
"@ | Out-File -FilePath "$WinDir\start.bat" -Encoding ASCII

"Double-click start.bat to play." | Out-File -FilePath "$WinDir\README.txt" -Encoding UTF8

$WinZip = Join-Path $ProjectDir "PVZ-Card-Game_v${Version}_Windows.zip"
Compress-Archive -Path "$WinDir\*" -DestinationPath $WinZip -Force
if (Test-Path $WinZip) {
    Write-Host "   Windows: PVZ-Card-Game_v${Version}_Windows.zip" -ForegroundColor Green
} else {
    Write-Host "   ZIP creation failed!" -ForegroundColor Red
}
Write-Host ""

# Step 5: Export Android
Write-Host "[4/5] Exporting Android APK..." -ForegroundColor Yellow
& $GodotExe --headless --export-release "Android" --path $ProjectPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "   Android export failed, skipping..." -ForegroundColor Yellow
    goto :final
}

$ApkFile = $null
if (Test-Path "$ProjectDir\PVZ_Plant_Card_Game.apk") {
    $ApkFile = "$ProjectDir\PVZ_Plant_Card_Game.apk"
} elseif (Test-Path "$ProjectDir\PVZ_Plant_Card_Game_debug.apk") {
    $ApkFile = "$ProjectDir\PVZ_Plant_Card_Game_debug.apk"
}

if ($ApkFile) {
    $TargetApk = Join-Path $ProjectDir "PVZ_v${Version}_Android.apk"
    Copy-Item $ApkFile $TargetApk -Force
    Write-Host "   Android: PVZ_v${Version}_Android.apk" -ForegroundColor Green
} else {
    Write-Host "   No APK found, skipping" -ForegroundColor Yellow
}
Write-Host ""

:final
# Cleanup
Write-Host "[5/5] Cleaning temp files..." -ForegroundColor Yellow
@("PVZ Plant Card Game.exe", "PVZ Plant Card Game.pck", "PVZ Plant Card Game.console.exe",
  "PVZ_Plant_Card_Game.apk", "PVZ_Plant_Card_Game_debug.apk") | ForEach-Object {
    $f = Join-Path $ProjectDir $_
    if (Test-Path $f) { Remove-Item $f -Force }
}
if (Test-Path "$ProjectDir\release_tmp") { Remove-Item "$ProjectDir\release_tmp" -Recurse -Force }
Write-Host "   Done" -ForegroundColor Green
Write-Host ""

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Build complete! Files for GitHub Release:" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
if (Test-Path $WinZip) {
    Write-Host "  Windows:" -ForegroundColor White
    Write-Host "    $WinZip" -ForegroundColor Green
    Write-Host ""
}
if (Test-Path $TargetApk) {
    Write-Host "  Android:" -ForegroundColor White
    Write-Host "    $TargetApk" -ForegroundColor Green
    Write-Host ""
}
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Next steps for GitHub Release:" -ForegroundColor Yellow
Write-Host "  1. Open https://github.com/zanyi123/godot-pvz-plant-card-game/releases/new"
Write-Host "  2. Title: v$Version"
Write-Host "  3. Paste CHANGELOG content"
Write-Host "  4. Drag & drop the files above"
Write-Host "  5. Click Publish release"
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
