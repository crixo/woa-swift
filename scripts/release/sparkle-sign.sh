#!/usr/bin/env bash
# ==============================================================================
# sparkle-sign.sh   (step 4)
#
# Signs the release zip with Sparkle's generate_appcast and adds the new entry
# to appcast.xml IN THE WORKING TREE. Nothing is committed or pushed here:
# commit-and-tag.sh commits appcast.xml so that the tag contains it.
#
# This works before the GitHub Release exists because the download URL of a
# Release asset is predictable:
#     https://github.com/<owner>/<repo>/releases/download/v<version>/<zip name>
#
# What it checks before touching appcast.xml:
#   - the app is set up for Sparkle (EdDSA public key, feed URL, framework)
#   - the generated entry has a signature, the right version and the right URL
#   - the merged appcast is well-formed and has exactly one more entry
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release-common.sh
source "${SCRIPT_DIR}/release-common.sh"
trap 'handle_error "$LINENO"' ERR

VERSION=""
APP_PATH=""
ZIP_PATH=""
DIST_DIR="dist"
BUILD_DIR="build"
REPOSITORY_NAME=""
MAIN_BRANCH="main"
APPCAST_PATH="appcast.xml"
FEED_URL=""
ED_KEY_FILE=""
SPARKLE_BIN="${SPARKLE_BIN:-}"

TAG=""
ZIP_NAME=""
WORK_DIR=""
INPUT_DIR=""
GENERATED_APPCAST=""
NEW_ITEM_FILE=""
STAGED_APPCAST=""
DOWNLOAD_PREFIX=""
ENCLOSURE_URL=""

show_help() {
    cat <<'HELP'
Usage: ./sparkle-sign.sh [options]

  --version <x.y.z>       Release version (default: from the zip in --dist-dir,
                          else the latest vX.Y.Z tag).
  --app-path <path>       Application bundle (default: the single .app in --dist-dir).
  --zip-path <path>       Application zip (default: <dist-dir>/*-<version>.app.zip).
  --dist-dir <path>       Where package-artifacts.sh left the files (default: dist).
  --build-dir <path>      Intermediate files (default: build).
  --repository <o/name>   GitHub repository that will host the Release
                          (default: detected with gh).
  --main-branch <name>    Branch that holds appcast.xml (default: main).
  --appcast-path <path>   appcast.xml location in the repo (default: appcast.xml).
  --feed-url <url>        Expected SUFeedURL (default: raw.githubusercontent.com URL).
  --sparkle-bin <dir>     Folder containing generate_appcast. If omitted:
                          $SPARKLE_BIN, then PATH, then Xcode's DerivedData.
  --ed-key-file <path>    Exported EdDSA private key (CI). Default: login Keychain.
  -h, --help              Show this help.

Edits appcast.xml in the working tree only. Nothing is committed.
HELP
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)       need_value "$1" "$#"; VERSION="$2";         shift 2 ;;
            --app-path)      need_value "$1" "$#"; APP_PATH="$2";        shift 2 ;;
            --zip-path)      need_value "$1" "$#"; ZIP_PATH="$2";        shift 2 ;;
            --dist-dir)      need_value "$1" "$#"; DIST_DIR="$2";        shift 2 ;;
            --build-dir)     need_value "$1" "$#"; BUILD_DIR="$2";       shift 2 ;;
            --repository)    need_value "$1" "$#"; REPOSITORY_NAME="$2"; shift 2 ;;
            --main-branch)   need_value "$1" "$#"; MAIN_BRANCH="$2";     shift 2 ;;
            --appcast-path)  need_value "$1" "$#"; APPCAST_PATH="$2";    shift 2 ;;
            --feed-url)      need_value "$1" "$#"; FEED_URL="$2";        shift 2 ;;
            --sparkle-bin)   need_value "$1" "$#"; SPARKLE_BIN="$2";     shift 2 ;;
            --ed-key-file)   need_value "$1" "$#"; ED_KEY_FILE="$2";     shift 2 ;;
            -h|--help)       show_help; exit 0 ;;
            *) die "Unknown option: $1 (use --help)" ;;
        esac
    done
}

# Fills every path and URL derived from the inputs.
resolve_inputs() {
    VERSION="$(resolve_version "$VERSION" "$DIST_DIR")"
    TAG="v${VERSION}"
    log "Version: ${VERSION} (tag ${TAG})"

    if [[ -z "$APP_PATH" ]]; then
        APP_PATH="$(find_single_artifact "$DIST_DIR" "application bundle" "--app-path" -type d -name '*.app')"
    fi
    if [[ -z "$ZIP_PATH" ]]; then
        ZIP_PATH="$(find_single_artifact "$DIST_DIR" "zip for version ${VERSION}" "--zip-path" -type f -name "*-${VERSION}.app.zip")"
    fi

    if [[ -z "$REPOSITORY_NAME" ]]; then
        REPOSITORY_NAME="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
    fi
    [[ -n "$REPOSITORY_NAME" ]] || die "Unable to determine the GitHub repository."

    ZIP_NAME="$(basename -- "$ZIP_PATH")"
    WORK_DIR="${BUILD_DIR}/sparkle-${VERSION}"
    INPUT_DIR="${WORK_DIR}/input"
    GENERATED_APPCAST="${INPUT_DIR}/appcast.xml"
    NEW_ITEM_FILE="${WORK_DIR}/new-item.xml"
    STAGED_APPCAST="${WORK_DIR}/appcast.xml"

    # GitHub serves Release assets from here; the asset name is the file name.
    DOWNLOAD_PREFIX="https://github.com/${REPOSITORY_NAME}/releases/download/${TAG}/"

    if [[ -z "$FEED_URL" ]]; then
        FEED_URL="https://raw.githubusercontent.com/${REPOSITORY_NAME}/${MAIN_BRANCH}/${APPCAST_PATH}"
    fi

    log "App: ${APP_PATH}"
    log "Zip: ${ZIP_PATH}"
}

# appcast.xml must be clean and must not already contain this version.
check_appcast_state() {
    [[ -z "$(git status --porcelain -- "$APPCAST_PATH")" ]] ||
        die "${APPCAST_PATH} has uncommitted changes. Commit or discard them first."

    if [[ -f "$APPCAST_PATH" ]] && appcast_has_version "$APPCAST_PATH" "$VERSION"; then
        die "${APPCAST_PATH} already contains version ${VERSION}."
    fi
}

# The app must be correctly set up for Sparkle, or updates would silently fail.
validate_app_for_sparkle() {
    local info_plist="${APP_PATH}/Contents/Info.plist"
    local bundle_version public_key feed_url

    log "Validating the application for Sparkle..."

    [[ -d "$APP_PATH" ]]   || die "Application bundle not found: ${APP_PATH}"
    [[ -s "$ZIP_PATH" ]]   || die "Application ZIP not found or empty: ${ZIP_PATH}"
    [[ -f "$info_plist" ]] || die "Application Info.plist was not found: ${info_plist}"

    bundle_version="$(plist_value "$info_plist" CFBundleVersion)"
    [[ "$bundle_version" == "$VERSION" ]] ||
        die "CFBundleVersion is '${bundle_version}', expected '${VERSION}'."

    public_key="$(plist_value "$info_plist" SUPublicEDKey)"
    [[ -n "$public_key" ]] ||
        die "SUPublicEDKey is missing from the app's Info.plist. Run Sparkle's generate_keys and add the printed public key to the app target."

    # A Sparkle EdDSA public key is 32 bytes in base64: 43 characters + "=".
    [[ "$public_key" =~ ^[A-Za-z0-9+/]{43}=$ ]] ||
        die "SUPublicEDKey ('${public_key}') is not a valid Sparkle public key."

    feed_url="$(plist_value "$info_plist" SUFeedURL)"
    [[ -n "$feed_url" ]] ||
        die "SUFeedURL is missing from the app's Info.plist. Expected: ${FEED_URL}"

    if [[ "$feed_url" != "$FEED_URL" ]]; then
        warning "SUFeedURL in the app is '${feed_url}'."
        warning "Expected '${FEED_URL}'. Installed apps read the URL baked into the app."
    fi

    [[ -d "${APP_PATH}/Contents/Frameworks/Sparkle.framework" ]] ||
        die "Sparkle.framework is not embedded in ${APP_PATH}. Add the Sparkle package to the app target (Embed & Sign)."

    if command -v codesign >/dev/null 2>&1; then
        if ! codesign --verify --deep --strict "$APP_PATH" >/dev/null 2>&1; then
            warning "${APP_PATH} does not pass 'codesign --verify --deep --strict'."
            warning "Notarization is not required, but at least ad-hoc signing is."
        fi
    fi
}

# Checks what generate_appcast produced. Sets ENCLOSURE_URL.
validate_generated_item() {
    local item_count enclosure_name

    log "Validating the generated appcast entry..."

    [[ -s "$GENERATED_APPCAST" ]] ||
        die "generate_appcast did not produce ${GENERATED_APPCAST}."

    item_count="$(count_items "$GENERATED_APPCAST")"
    [[ "$item_count" == "1" ]] ||
        die "Expected exactly one <item> in the generated appcast, found ${item_count}."

    grep -Fq 'sparkle:edSignature=' "$GENERATED_APPCAST" ||
        die "The generated entry has no sparkle:edSignature. Is the EdDSA private key available?"

    appcast_has_version "$GENERATED_APPCAST" "$VERSION" ||
        die "The generated entry does not carry version ${VERSION}."

    ENCLOSURE_URL="$(
        tr '\n' ' ' <"$GENERATED_APPCAST" |
            grep -o '<enclosure[^>]*>' |
            head -n 1 |
            sed -n 's/.*[[:space:]]url="\([^"]*\)".*/\1/p' ||
        true
    )"

    [[ -n "$ENCLOSURE_URL" ]] ||
        die "Unable to read the enclosure URL from the generated appcast."

    [[ "$ENCLOSURE_URL" == "${DOWNLOAD_PREFIX}"* ]] ||
        die "Enclosure URL '${ENCLOSURE_URL}' does not start with '${DOWNLOAD_PREFIX}'."

    enclosure_name="${ENCLOSURE_URL#"$DOWNLOAD_PREFIX"}"
    enclosure_name="${enclosure_name//%20/ }"

    [[ "$enclosure_name" == "$ZIP_NAME" ]] ||
        die "Enclosure file name '${enclosure_name}' does not match the zip '${ZIP_NAME}'."
}

# Builds STAGED_APPCAST: the existing appcast plus the new entry on top.
# Existing entries are kept exactly as they are.
merge_into_existing_appcast() {
    local existing_items=0 merged_items

    if [[ ! -f "$APPCAST_PATH" ]]; then
        log "No existing ${APPCAST_PATH}: this is the first appcast entry."
        cp "$GENERATED_APPCAST" "$STAGED_APPCAST"
        return 0
    fi

    log "Merging the new entry into the existing ${APPCAST_PATH}..."

    if command -v xmllint >/dev/null 2>&1; then
        xmllint --noout "$APPCAST_PATH" ||
            die "The existing ${APPCAST_PATH} is not well-formed XML."
    fi

    existing_items="$(count_items "$APPCAST_PATH")"

    awk '/<item[ >]/ { keep = 1 } keep { print } /<\/item>/ { keep = 0 }' \
        "$GENERATED_APPCAST" >"$NEW_ITEM_FILE"

    [[ -s "$NEW_ITEM_FILE" ]] ||
        die "Unable to extract the new <item> from the generated appcast."

    # Newest first: insert before the first existing <item>, or before </channel>.
    awk -v item_file="$NEW_ITEM_FILE" '
        function emit(   line) {
            while ((getline line < item_file) > 0) print line
            close(item_file)
            inserted = 1
        }
        !inserted && /<item[ >]/    { emit() }
        !inserted && /<\/channel>/  { emit() }
        { print }
    ' "$APPCAST_PATH" >"$STAGED_APPCAST"

    merged_items="$(count_items "$STAGED_APPCAST")"
    [[ "$merged_items" == "$((existing_items + 1))" ]] ||
        die "Merge check failed: expected $((existing_items + 1)) items, found ${merged_items}."
}

# Signs the zip and stages the new appcast under WORK_DIR.
prepare_appcast() {
    local generate_appcast generate_arguments

    validate_app_for_sparkle

    generate_appcast="$(find_sparkle_tool generate_appcast)" ||
        die "generate_appcast not found. Use --sparkle-bin <dir>, set SPARKLE_BIN, or add Sparkle's bin directory to PATH."

    log "Using generate_appcast: ${generate_appcast}"

    rm -rf "$WORK_DIR"
    mkdir -p "$INPUT_DIR"

    # One archive only: the entry for this version is generated alone and
    # merged afterwards.
    cp "$ZIP_PATH" "${INPUT_DIR}/${ZIP_NAME}"

    generate_arguments=(
        "$INPUT_DIR"
        --download-url-prefix "$DOWNLOAD_PREFIX"
    )

    if [[ -n "$ED_KEY_FILE" ]]; then
        [[ -f "$ED_KEY_FILE" ]] || die "EdDSA key file not found: ${ED_KEY_FILE}"
        generate_arguments+=(--ed-key-file "$ED_KEY_FILE")
    fi

    log "Signing ${ZIP_NAME} and generating its appcast entry..."
    "$generate_appcast" "${generate_arguments[@]}"

    validate_generated_item
    merge_into_existing_appcast

    if command -v xmllint >/dev/null 2>&1; then
        xmllint --noout "$STAGED_APPCAST" ||
            die "The staged appcast is not well-formed XML."
    fi

    grep -Fq "$ENCLOSURE_URL" "$STAGED_APPCAST" ||
        die "The staged appcast does not contain the new download URL."
}

# Copies the staged appcast into the working tree (no commit).
install_appcast() {
    mkdir -p "$(dirname -- "$APPCAST_PATH")"
    cp "$STAGED_APPCAST" "$APPCAST_PATH"

    success "${APPCAST_PATH} updated for ${TAG} (not committed)."
    printf '\n  Entries:      %s\n  Version:      %s\n  Download URL: %s\n  Feed URL:     %s\n\n' \
        "$(count_items "$APPCAST_PATH")" "$VERSION" "$ENCLOSURE_URL" "$FEED_URL" >&2
}

main() {
    parse_args "$@"
    require_tools git gh awk grep sed tr find
    enter_repo_root

    resolve_inputs
    check_appcast_state
    prepare_appcast
    install_appcast
}

main "$@"
