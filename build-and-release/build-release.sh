#!/bin/bash
set -euo pipefail

# Builds the WOA app in Release configuration and logs output to build-release.log.
# Must be run on macOS with Xcode installed.

PROJECT_PATH="src/WOA.xcodeproj"
SCHEME="WOA"
CONFIGURATION="Release"
LOG_FILE="build-release.log"
BUILD_DIR="build"

echo "Building $SCHEME ($CONFIGURATION)..." | tee "$LOG_FILE"

xcodebuild \
	-project "$PROJECT_PATH" \
	-scheme "$SCHEME" \
	-configuration "$CONFIGURATION" \
	-derivedDataPath "$BUILD_DIR" \
	build 2>&1 | tee -a "$LOG_FILE"

echo "Build complete. Output in $BUILD_DIR/Build/Products/$CONFIGURATION" | tee -a "$LOG_FILE"
