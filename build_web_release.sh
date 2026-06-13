#!/bin/bash
# Script de build web sécurisé pour Madaurore
# Obfusque le code source et supprime les source maps

echo "🔐 Building Flutter Web Release - SECURE MODE..."

# 1. Clean previous builds
echo "📝 Cleaning previous builds..."
flutter clean

# 2. Build web with obfuscation and no source maps
echo "🛠️  Building web release..."
flutter build web \
  --release \
  --no-tree-shake-icons \
  --split-debug-info=build/web_debug_info

# 3. Remove source maps from release build
echo "🔒 Removing source maps for security..."
find build/web -name "*.map" -delete

# 4. Verify no debug symbols left
if find build/web -name "*.map" | grep -q .; then
    echo "❌ ERROR: Source maps still present!"
    exit 1
fi

echo "✅ Build complete!"
echo "📦 Web app ready at: build/web/"
echo "🔐 Debug info stored at: build/web_debug_info/ (secure storage)"
echo ""
echo "⚠️  IMPORTANT: Keep build/web_debug_info/ private for development debugging"
