#!/usr/bin/env bash

# chmod +x install-woa-swift.sh
# Preferred: ZIP artifact
# ./install-woa-swift.sh v1.0.0
# Explicitly use DMG
# ./install-woa-swift.sh --dmg v1.0.0

# - Download → validate.
# - Install to /Applications/.WOA.app.new.
# - Validate staging.
# - Rename current app to /Applications/.WOA.app.bak.
# - Activate new version.
# - Validate activation.
# - If anything fails, restore the backup automatically.
# - Only delete the backup after a successful upgrade.
# - Remove quarantine attributes and launch the application.
# - Verifying the executable is present and executable.
# - Launch the application.

set -Eeuo pipefail

REPO="crixo/woa-swift"

usage() {
    cat <<EOF
Usage:
  $0 <version>

Example:
  $0 v0.1.0

Features:
  - Downloads the ZIP artifact from the specified GitHub release
  - Validates the application bundle before installation
  - Performs a transactional upgrade
  - Automatically rolls back on failure
  - Preserves the currently installed version until activation succeeds
EOF
    exit 1
}

[[ $# -eq 1 ]] || usage

VERSION="$1"
WORKDIR="$(mktemp -d)"

cleanup() {
    rm -rf "$WORKDIR"
}

trap cleanup EXIT

API_URL="https://api.github.com/repos/${REPO}/releases/tags/${VERSION}"

echo "Fetching release metadata for ${VERSION}..."

ASSET_URL=$(
    curl -fsSL "$API_URL" |
    python3 -c '
import json, sys

release = json.load(sys.stdin)

for asset in release.get("assets", []):
    name = asset["name"].lower()
    if name.endswith(".zip"):
        print(asset["browser_download_url"])
        sys.exit(0)

sys.exit("No ZIP artifact found in release.")
'
)

ASSET_NAME="$(basename "$ASSET_URL")"
ASSET_PATH="$WORKDIR/$ASSET_NAME"

echo "Downloading ${ASSET_NAME} ..."
curl -fL "$ASSET_URL" -o "$ASSET_PATH"

echo "Extracting archive..."
unzip -q "$ASSET_PATH" -d "$WORKDIR"

APP_PATH=$(
    find "$WORKDIR" \
        -type f \
        -path "*/Contents/Info.plist" \
        -not -path "*/__MACOSX/*" \
        | head -n1 \
        | sed 's|/Contents/Info.plist$||'
)

if [[ -z "${APP_PATH:-}" ]]; then
    echo
    echo "========================================"
    echo "UPGRADE FAILED"
    echo "No valid macOS application bundle found."
    echo "========================================"
    exit 1
fi

echo "Found application bundle:"
echo "  $APP_PATH"

if [[ ! -f "$APP_PATH/Contents/Info.plist" ]]; then
    echo
    echo "========================================"
    echo "UPGRADE FAILED"
    echo "Invalid application bundle."
    echo "========================================"
    exit 1
fi

EXECUTABLE=$(
    /usr/libexec/PlistBuddy \
        -c "Print :CFBundleExecutable" \
        "$APP_PATH/Contents/Info.plist"
)

if [[ -z "${EXECUTABLE:-}" ]]; then
    echo
    echo "========================================"
    echo "UPGRADE FAILED"
    echo "Unable to determine executable name."
    echo "========================================"
    exit 1
fi

if [[ ! -f "$APP_PATH/Contents/MacOS/$EXECUTABLE" ]]; then
    echo
    echo "========================================"
    echo "UPGRADE FAILED"
    echo "Executable missing in downloaded bundle."
    echo "========================================"
    exit 1
fi

APP_NAME="$(basename "$APP_PATH")"

LIVE_APP="/Applications/$APP_NAME"
STAGING_APP="/Applications/.${APP_NAME}.new"
BACKUP_APP="/Applications/.${APP_NAME}.bak"

echo
echo "Preparing upgrade..."

sudo rm -rf "$STAGING_APP"
sudo rm -rf "$BACKUP_APP"

#
# Stage candidate version
#

echo "Installing candidate version into staging area..."

sudo ditto "$APP_PATH" "$STAGING_APP"

#
# Validate staged bundle
#

if [[ ! -f "$STAGING_APP/Contents/Info.plist" ]]; then
    sudo rm -rf "$STAGING_APP"

    echo
    echo "========================================"
    echo "UPGRADE FAILED"
    echo "Invalid staged application."
    echo "Existing version preserved."
    echo "========================================"
    exit 1
fi

STAGED_EXECUTABLE=$(
    /usr/libexec/PlistBuddy \
        -c "Print :CFBundleExecutable" \
        "$STAGING_APP/Contents/Info.plist"
)

if [[ ! -x "$STAGING_APP/Contents/MacOS/$STAGED_EXECUTABLE" ]]; then
    sudo rm -rf "$STAGING_APP"

    echo
    echo "========================================"
    echo "UPGRADE FAILED"
    echo "Staged executable is invalid."
    echo "Existing version preserved."
    echo "========================================"
    exit 1
fi

echo "Staging validation passed."

#
# Backup current version
#

if [[ -e "$LIVE_APP" ]]; then
    echo "Backing up current version..."
    sudo mv "$LIVE_APP" "$BACKUP_APP"
fi

ROLLBACK_REQUIRED=false

#
# Activate new version
#

echo "Activating new version..."

if ! sudo mv "$STAGING_APP" "$LIVE_APP"; then
    ROLLBACK_REQUIRED=true
fi

#
# Validate activated version
#

if [[ "$ROLLBACK_REQUIRED" == false ]]; then

    if [[ ! -f "$LIVE_APP/Contents/Info.plist" ]]; then
        ROLLBACK_REQUIRED=true
    else

        FINAL_EXECUTABLE=$(
            /usr/libexec/PlistBuddy \
                -c "Print :CFBundleExecutable" \
                "$LIVE_APP/Contents/Info.plist" \
                2>/dev/null || true
        )

        if [[ -z "${FINAL_EXECUTABLE:-}" ]]; then
            ROLLBACK_REQUIRED=true
        elif [[ ! -x "$LIVE_APP/Contents/MacOS/$FINAL_EXECUTABLE" ]]; then
            ROLLBACK_REQUIRED=true
        fi
    fi
fi

#
# Rollback if activation failed
#

if [[ "$ROLLBACK_REQUIRED" == true ]]; then

    echo
    echo "Activation validation failed."
    echo "Rolling back..."

    sudo rm -rf "$LIVE_APP"
    sudo rm -rf "$STAGING_APP"

    if [[ -e "$BACKUP_APP" ]]; then
        sudo mv "$BACKUP_APP" "$LIVE_APP"

        echo
        echo "========================================"
        echo "UPGRADE FAILED"
        echo "Previous version restored successfully."
        echo "New version discarded."
        echo "========================================"
    else
        echo
        echo "========================================"
        echo "UPGRADE FAILED"
        echo "No previous version available."
        echo "New version discarded."
        echo "========================================"
    fi

    exit 1
fi

#
# Success: remove backup
#

sudo rm -rf "$BACKUP_APP"

echo
echo "========================================"
echo "UPGRADE SUCCESSFUL"
echo "Version: $VERSION"
echo "Application: $LIVE_APP"
echo "Executable: $LIVE_APP/Contents/MacOS/$FINAL_EXECUTABLE"
echo "========================================"

ls -lh "$LIVE_APP/Contents/MacOS/$FINAL_EXECUTABLE"

#
# Remove quarantine attributes
#
UNLOCK_SCRIPT="./unlock-woa.sh"

if [[ -x "$UNLOCK_SCRIPT" ]]; then
    echo
    echo "Running unlock script..."
    "$UNLOCK_SCRIPT" "$LIVE_APP"
else
    echo
    echo "WARNING: unlock-woa.sh not found or not executable."
    echo "Skipping Gatekeeper unlock step."
fi

#
# Verify the bundle is structurally launchable
#
EXECUTABLE=$(
    /usr/libexec/PlistBuddy \
    -c "Print :CFBundleExecutable" \
    "$LIVE_APP/Contents/Info.plist"
)

if [[ ! -x "$LIVE_APP/Contents/MacOS/$EXECUTABLE" ]]; then
    echo "Application executable missing"
    exit 1
fi

echo "Executable found"

echo "Launching application..."
open "$LIVE_APP"