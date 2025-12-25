#!/bin/bash

# Build script for LanguageSuggestion macOS app
# This script cleans the build folder and builds the project
# Usage: ./build.sh [-r]  (use -r to only run/open the app without building)

set -e  # Exit on error

PROJECT_NAME="LanguageSuggestion"
SCHEME_NAME="LanguageSuggestion"
CONFIGURATION="Debug"
BUILD_DIR="build"

# Check for -r flag (run only, no build)
RUN_ONLY=false
if [[ "$1" == "-r" ]]; then
    RUN_ONLY=true
fi

if [ "$RUN_ONLY" = false ]; then
    echo "🧹 Cleaning build folder..."
    rm -rf "$BUILD_DIR"
    rm -rf ~/Library/Developer/Xcode/DerivedData/${PROJECT_NAME}-*

    echo "🔨 Building project..."
    xcodebuild \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "${SCHEME_NAME}" \
        -configuration "${CONFIGURATION}" \
        clean build \
        -destination 'platform=macOS,arch=arm64' \
        -derivedDataPath "$BUILD_DIR" \
        ARCHS=arm64 \
        ONLY_ACTIVE_ARCH=YES \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO

    # Find the built .app file
    APP_PATH=$(find "$BUILD_DIR" -name "${PROJECT_NAME}.app" -type d | head -1)

    if [ -z "$APP_PATH" ]; then
        echo "❌ Error: Could not find built .app file"
        exit 1
    fi

    echo ""
    echo "✅ Build successful!"
    echo "📦 App location: $APP_PATH"
    echo ""
    echo "To run the app:"
    echo "  open \"$APP_PATH\""
    echo ""
    echo "To copy to Applications:"
    echo "  cp -R \"$APP_PATH\" /Applications/"
else
    # Find existing .app file
    APP_PATH=$(find "$BUILD_DIR" -name "${PROJECT_NAME}.app" -type d | head -1)

    if [ -z "$APP_PATH" ]; then
        echo "❌ Error: Could not find .app file. Please build first."
        exit 1
    fi

    echo "📦 App location: $APP_PATH"
fi

echo ""
echo "🚀 Launching app..."
open "$APP_PATH" || echo "⚠️ Could not open app automatically. You can open it manually with: open \"$APP_PATH\""

