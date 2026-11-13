#!/usr/bin/env bash
# ==============================================================================
# package-artifacts.sh   (step 3)
#
# Turns an Xcode archive (made by build-in-release.sh) into the release files:
#
#     dist/<name>.app
#     dist/<name>-<version>.app.zip     (used by Sparkle and the GitHub Release)
#     dist/<name>-<version>.dmg         (for manual downloads)
#
# It also verifies that the version baked into Info.plist is the release
# version. The dist directory is recreated from scratch on every run.
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release-common.sh
source "${SCRIPT_DIR}/release-common.sh"
trap 'handle_error "$LINENO"' ERR

ARCHIVE_PATH=""
VERSION=""
APP_NAME=""
EXPORT_OPTIONS_PLIST=""
BUILD_DIR="build"
DIST_DIR="dist"

APP_PATH=""
APP_ZIP=""
DMG_PATH=""

show_help() {
    cat <<'HELP'
Usage: ./package-artifacts.sh --archive-path <path> --version <x.y.z> [options]

  --archive-path <path>          The .xcarchive to package (required).
  --version <x.y.z>              Release version expected in Info.plist (required).
  --app-name <name>              App name without ".app" (default: detected).
  --export-options-plist <path>  Use xcodebuild -exportArchive with this plist
                                 (default: copy the .app from the archive).
  --build-dir <path>             Intermediate files (default: build).
  --dist-dir <path>              Final artifacts (default: dist). Recreated.
  -h, --help                     Show this help.
HELP
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --archive-path)          need_value "$1" "$#"; ARCHIVE_PATH="$2";         shift 2 ;;
            --version)               need_value "$1" "$#"; VERSION="${2#v}";          shift 2 ;;
            --app-name)              need_value "$1" "$#"; APP_NAME="$2";             shift 2 ;;
            --export-options-plist)  need_value "$1" "$#"; EXPORT_OPTIONS_PLIST="$2"; shift 2 ;;
            --build-dir)             need_value "$1" "$#"; BUILD_DIR="$2";            shift 2 ;;
            --dist-dir)              need_value "$1" "$#"; DIST_DIR="$2";             shift 2 ;;
            -h|--help)               show_help; exit 0 ;;
            *) die "Unknown option: $1 (use --help)" ;;
        esac
    done

    [[ -n "$ARCHIVE_PATH" ]] || die "--archive-path is required."
    [[ -n "$VERSION" ]]      || die "--version is required."
    [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
        die "Version '${VERSION}' is not in the form X.Y.Z."
    [[ "$BUILD_DIR" != "$DIST_DIR" ]] ||
        die "--build-dir and --dist-dir must be different."

    case "$DIST_DIR" in
        ""|"."|".."|"/") die "Refusing to recreate the directory '${DIST_DIR}'." ;;
    esac
}

# Copies the .app into DIST_DIR (through an export if a plist was given).
# Sets APP_NAME, APP_PATH, APP_ZIP and DMG_PATH.
collect_app_bundle() {
    local source_app export_path="${BUILD_DIR}/export-${VERSION}"

    [[ -d "$ARCHIVE_PATH" ]] || die "Archive not found: ${ARCHIVE_PATH}"

    rm -rf "$DIST_DIR"
    mkdir -p "$DIST_DIR"

    if [[ -n "$EXPORT_OPTIONS_PLIST" ]]; then
        [[ -f "$EXPORT_OPTIONS_PLIST" ]] || die "Export options plist not found: ${EXPORT_OPTIONS_PLIST}"

        rm -rf "$export_path"
        mkdir -p "$export_path"

        log "Exporting archive..."
        xcodebuild -exportArchive \
            -archivePath "$ARCHIVE_PATH" \
            -exportPath "$export_path" \
            -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

        source_app="$(find "$export_path" -maxdepth 2 -type d -name '*.app' -print -quit)"
        [[ -n "$source_app" ]] || die "No .app found in the export directory."
    else
        source_app="$(find "${ARCHIVE_PATH}/Products/Applications" -maxdepth 1 -type d -name '*.app' -print -quit 2>/dev/null || true)"
        [[ -n "$source_app" ]] || die "No .app found in the archive."
    fi

    [[ -n "$APP_NAME" ]] || APP_NAME="$(basename "$source_app" .app)"

    APP_PATH="${DIST_DIR}/${APP_NAME}.app"
    APP_ZIP="${DIST_DIR}/${APP_NAME}-${VERSION}.app.zip"
    DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"

    ditto "$source_app" "$APP_PATH"
    [[ -d "$APP_PATH" ]] || die "App bundle was not created: ${APP_PATH}"
}

# The version baked into the built app must equal the release version.
verify_app_version() {
    local plist="${APP_PATH}/Contents/Info.plist" short bundle

    [[ -f "$plist" ]] || die "Info.plist not found: ${plist}"

    short="$(plist_value "$plist" CFBundleShortVersionString)"
    bundle="$(plist_value "$plist" CFBundleVersion)"

    [[ "$short" == "$VERSION" ]]  || die "CFBundleShortVersionString is '${short}', expected '${VERSION}'."
    [[ "$bundle" == "$VERSION" ]] || die "CFBundleVersion is '${bundle}', expected '${VERSION}'."

    log "Verified app version: ${short} (build ${bundle})"
}

package_zip() {
    log "Creating ${APP_ZIP}..."
    ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$APP_ZIP"
}

package_dmg() {
    local staging="${BUILD_DIR}/dmg-${VERSION}"

    log "Creating ${DMG_PATH}..."

    rm -rf "$staging"
    mkdir -p "$staging"
    ditto "$APP_PATH" "${staging}/${APP_NAME}.app"
    ln -s /Applications "${staging}/Applications"

    hdiutil create -volname "$APP_NAME" -srcfolder "$staging" -ov -format UDZO "$DMG_PATH" >/dev/null
    hdiutil verify "$DMG_PATH" >/dev/null
}

validate_artifacts() {
    local file
    for file in "$APP_ZIP" "$DMG_PATH"; do
        [[ -s "$file" ]] || die "Artifact missing or empty: ${file}"
        log "$(basename "$file"): $(stat -f '%z' "$file") bytes"
    done
}

main() {
    parse_args "$@"
    require_tools xcodebuild hdiutil ditto find

    collect_app_bundle
    verify_app_version
    package_zip
    package_dmg
    validate_artifacts

    success "Artifacts for ${VERSION} created in ${DIST_DIR}/"
}

main "$@"
