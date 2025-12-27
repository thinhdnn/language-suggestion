#!/bin/bash

# Build script for LanguageSuggestion macOS app
# This script cleans the build folder and builds the project
# Usage: 
#   ./build.sh           - Build and run tests, then launch app
#   ./build.sh -r        - Only run/open the app without building
#   ./build.sh -s        - Build without running tests
#   ./build.sh -t        - Only run tests (skip build and launch)

# Note: We don't use 'set -e' because we want to handle test failures gracefully
# Individual commands that must succeed will use explicit error checking

PROJECT_NAME="LanguageSuggestion"
SCHEME_NAME="LanguageSuggestion"
CONFIGURATION="Debug"
BUILD_DIR="build"

# Parse flags
RUN_ONLY=false
SKIP_TESTS=false
TEST_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--run-only)
            RUN_ONLY=true
            shift
            ;;
        -s|--skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        -t|--test-only)
            TEST_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: ./build.sh [-r|--run-only] [-s|--skip-tests] [-t|--test-only]"
            exit 1
            ;;
    esac
done

# Function to run tests
run_tests() {
    echo ""
    echo "🧪 Running tests..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if xcodebuild \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "${SCHEME_NAME}" \
        -configuration "${CONFIGURATION}" \
        test \
        -destination 'platform=macOS,arch=arm64' \
        -derivedDataPath "$BUILD_DIR" \
        ARCHS=arm64 \
        ONLY_ACTIVE_ARCH=YES \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO 2>&1 | tee /tmp/xcodebuild_test.log; then
        echo ""
        echo "✅ All tests passed!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 0
    else
        echo ""
        echo "❌ Some tests failed. Check the output above for details."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Try to extract test results from log
        if grep -q "Test Suite.*failed" /tmp/xcodebuild_test.log; then
            echo ""
            echo "Failed test summary:"
            grep -A 5 "Test Suite.*failed" /tmp/xcodebuild_test.log | head -20
        fi
        
        return 1
    fi
}

if [ "$TEST_ONLY" = true ]; then
    # Only run tests
    run_tests
    exit $?
fi

if [ "$RUN_ONLY" = false ]; then
    echo "🧹 Cleaning build folder..."
    rm -rf "$BUILD_DIR"
    rm -rf ~/Library/Developer/Xcode/DerivedData/${PROJECT_NAME}-*

    echo "🔨 Building project..."
    if ! xcodebuild \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "${SCHEME_NAME}" \
        -configuration "${CONFIGURATION}" \
        clean build \
        -destination 'platform=macOS,arch=arm64' \
        -derivedDataPath "$BUILD_DIR" \
        ARCHS=arm64 \
        ONLY_ACTIVE_ARCH=YES \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO; then
        echo "❌ Build failed!"
        exit 1
    fi

    # Find the built .app file
    APP_PATH=$(find "$BUILD_DIR" -name "${PROJECT_NAME}.app" -type d | head -1)

    if [ -z "$APP_PATH" ]; then
        echo "❌ Error: Could not find built .app file"
        exit 1
    fi

    echo ""
    echo "✅ Build successful!"
    echo "📦 App location: $APP_PATH"
    
    # Run tests if not skipped
    if [ "$SKIP_TESTS" = false ]; then
        TEST_RESULT=0
        run_tests || TEST_RESULT=$?
        
        if [ $TEST_RESULT -ne 0 ]; then
            echo ""
            echo "⚠️  Tests failed, but continuing with app launch..."
            echo "   Use -s flag to skip tests: ./build.sh -s"
        fi
    else
        echo ""
        echo "⏭️  Skipping tests (use -s flag to skip explicitly)"
    fi
    
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

# Launch app (unless test-only mode)
if [ "$TEST_ONLY" = false ]; then
    echo ""
    echo "🚀 Launching app..."
    open "$APP_PATH" || echo "⚠️ Could not open app automatically. You can open it manually with: open \"$APP_PATH\""
fi

