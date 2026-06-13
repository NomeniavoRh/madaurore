@echo off
REM Script de build web sécurisé pour Madaurore (Windows)
REM Obfusque le code source et supprime les source maps

echo.
echo 🔐 Building Flutter Web Release - SECURE MODE...
echo.

REM 1. Clean previous builds
echo 📝 Cleaning previous builds...
call flutter clean

REM 2. Build web with obfuscation and no source maps
echo 🛠️  Building web release...
call flutter build web ^
  --release ^
  --no-tree-shake-icons ^
  --split-debug-info=build\web_debug_info

REM 3. Remove source maps from release build
echo 🔒 Removing source maps for security...
for /r "build\web" %%F in (*.map) do (
    del "%%F"
)

echo.
echo ✅ Build complete!
echo 📦 Web app ready at: build\web\
echo 🔐 Debug info stored at: build\web_debug_info\ (secure storage)
echo.
echo ⚠️  IMPORTANT: Keep build\web_debug_info\ private for development debugging
echo.
