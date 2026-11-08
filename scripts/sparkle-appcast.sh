#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

# Sparkle appcast helper, invoked by build-tag-release.sh.
#
# Two phases, because the appcast must go live only AFTER the GitHub Release
# (and its zip asset) exists:
#
#   prepare   Validate the app, sign the zip with generate_appcast and stage an
#             updated appcast.xml under <build-dir>/sparkle-<version>/.
#             Touches nothing in the repository and nothing on the remote, so it
#             is safe to run during --dry-run.
#
#   publish   Commit the staged appcast.xml to the release branch and push it.
#             With --dry-run it only simulates the push and prints the commands.
#
# Standalone example (paths are relative to the repository root):
#
#   ./scripts/sparkle-appcast.sh prepare \
#       --version 1.1.0 --tag v1.1.0 --repository crixo/woa-swift \
#       --app-path dist/WOA.app --zip-path dist/WOA-1.1.0.app.zip

# ==============================================================================
# Default parameter values
# ==============================================================================

MODE=""

VERSION=""
TAG=""
REPOSITORY_NAME=""
REMOTE="origin"
MAIN_BRANCH="main"
BUILD_DIR="build"
APP_PATH=""
ZIP_PATH=""
APPCAST_PATH="appcast.xml"
FEED_URL=""
ED_KEY_FILE=""
SPARKLE_BIN="${SPARKLE_BIN:-}"
PLISTBUDDY="${PLISTBUDDY:-/usr/libexec/PlistBuddy}"

DRY_RUN=false

# ==============================================================================
# Logging
# ==============================================================================

log() {
    printf '\033[1;34m[INFO]\033[0m %s\n' "$*"
}

success() {
    printf '\033[1;32m[SUCCESS]\033[0m %s\n' "$*"
}

warning() {
    printf '\033[1;33m[WARNING]\033[0m %s\n' "$*" >&2
}

error() {
    printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2
}

die() {
    error "$*"
    exit 1
}

handle_error() {
    local exit_code=$?
    local line_number="${1:-unknown}"

    error "Sparkle ${MODE:-script} failed at line ${line_number} with exit code ${exit_code}."
    exit "$exit_code"
}

trap 'handle_error "$LINENO"' ERR

# ==============================================================================
# Help
# ==============================================================================

show_help() {
    cat <<'HELP'
Usage:

  ./scripts/sparkle-appcast.sh <prepare|publish> [options]

Modes:

  prepare
      Validate the app, sign the zip and stage an updated appcast.xml in
      <build-dir>/sparkle-<version>/. Publishes nothing.

  publish
      Commit the staged appcast.xml to the release branch and push it.
      Run it only after the GitHub Release with the zip asset exists.

Required parameters:

  --version <x.y.z>
      Release version without the leading "v".

  --tag <vx.y.z>
      Release tag. Must be "v" + --version.

  --repository <owner/name>
      GitHub repository that hosts the Release assets.

  --zip-path <path>
      Application zip that is uploaded to the GitHub Release.
      Its file name must be the asset name on the Release.

  --app-path <path>
      Application bundle (prepare only). Used to validate the Sparkle setup.

Optional parameters:

  --remote <name>
      Git remote. Default: origin

  --main-branch <name>
      Branch that holds appcast.xml. Default: main

  --build-dir <path>
      Intermediate files directory. Default: build

  --appcast-path <path>
      Location of appcast.xml in the repository. Default: appcast.xml

  --feed-url <url>
      Expected SUFeedURL. Default:
      https://raw.githubusercontent.com/<repository>/<main-branch>/<appcast-path>

  --sparkle-bin <dir>
      Directory containing generate_appcast. If omitted the script looks at
      $SPARKLE_BIN, then PATH, then Xcode's DerivedData Sparkle artifacts.

  --ed-key-file <path>
      File with the exported EdDSA private key (CI use). If omitted the key is
      read from the login Keychain, where generate_keys stored it.

  --dry-run
      publish only: simulate the push and print the commands, change nothing.

  -h, --help
      Display this help.
HELP
}

# ==============================================================================
# Parameter parsing
# ==============================================================================

require_parameter_value() {
    local parameter_name="$1"
    local parameter_count="$2"

    if [[ "$parameter_count" -lt 2 ]]; then
        die "Missing value for parameter: ${parameter_name}"
    fi
}

case "${1:-}" in
    prepare|publish)
        MODE="$1"
        shift
        ;;

    -h|--help)
        show_help
        exit 0
        ;;

    "")
        die "Missing mode. Use: prepare or publish. See --help."
        ;;

    *)
        die "Unknown mode: $1. Use: prepare or publish. See --help."
        ;;
esac

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            require_parameter_value "$1" "$#"
            VERSION="$2"
            shift 2
            ;;

        --tag)
            require_parameter_value "$1" "$#"
            TAG="$2"
            shift 2
            ;;

        --repository)
            require_parameter_value "$1" "$#"
            REPOSITORY_NAME="$2"
            shift 2
            ;;

        --remote)
            require_parameter_value "$1" "$#"
            REMOTE="$2"
            shift 2
            ;;

        --main-branch)
            require_parameter_value "$1" "$#"
            MAIN_BRANCH="$2"
            shift 2
            ;;

        --build-dir)
            require_parameter_value "$1" "$#"
            BUILD_DIR="$2"
            shift 2
            ;;

        --app-path)
            require_parameter_value "$1" "$#"
            APP_PATH="$2"
            shift 2
            ;;

        --zip-path)
            require_parameter_value "$1" "$#"
            ZIP_PATH="$2"
            shift 2
            ;;

        --appcast-path)
            require_parameter_value "$1" "$#"
            APPCAST_PATH="$2"
            shift 2
            ;;

        --feed-url)
            require_parameter_value "$1" "$#"
            FEED_URL="$2"
            shift 2
            ;;

        --sparkle-bin)
            require_parameter_value "$1" "$#"
            SPARKLE_BIN="$2"
            shift 2
            ;;

        --ed-key-file)
            require_parameter_value "$1" "$#"
            ED_KEY_FILE="$2"
            shift 2
            ;;

        --dry-run)
            DRY_RUN=true
            shift
            ;;

        -h|--help)
            show_help
            exit 0
            ;;

        *)
            die "Unknown parameter: $1. Use --help to display supported parameters."
            ;;
    esac
done

# ==============================================================================
# Parameter validation
# ==============================================================================

[[ -n "$VERSION" ]] ||
    die "The required --version parameter was not provided."

[[ -n "$TAG" ]] ||
    die "The required --tag parameter was not provided."

[[ "$TAG" == "v${VERSION}" ]] ||
    die "--tag must be 'v${VERSION}', got '${TAG}'."

[[ -n "$REPOSITORY_NAME" ]] ||
    die "The required --repository parameter was not provided."

[[ -n "$ZIP_PATH" ]] ||
    die "The required --zip-path parameter was not provided."

[[ -n "$REMOTE" ]] ||
    die "--remote cannot be empty."

[[ -n "$MAIN_BRANCH" ]] ||
    die "--main-branch cannot be empty."

[[ -n "$BUILD_DIR" ]] ||
    die "--build-dir cannot be empty."

[[ -n "$APPCAST_PATH" ]] ||
    die "--appcast-path cannot be empty."

if [[ "$MODE" == "prepare" ]]; then
    [[ -n "$APP_PATH" ]] ||
        die "The --app-path parameter is required for prepare."

    [[ "$DRY_RUN" == false ]] ||
        warning "--dry-run has no effect on prepare: it never publishes anything."
fi

# ==============================================================================
# Dependency validation
# ==============================================================================

require_command() {
    local command_name="$1"

    command -v "$command_name" >/dev/null 2>&1 ||
        die "Required command not found: ${command_name}"
}

require_command git
require_command awk
require_command grep
require_command sed
require_command tr

if [[ "$MODE" == "prepare" ]]; then
    [[ "$(uname -s)" == "Darwin" ]] ||
        die "Sparkle's tools run on macOS only."
fi

if [[ "$MODE" == "publish" && "$DRY_RUN" == false ]]; then
    require_command gh
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    die "The current directory is not inside a Git repository."

# Like build-tag-release.sh: every relative path is relative to the repo root.
cd "$(git rev-parse --show-toplevel)"

# ==============================================================================
# Derived values
# ==============================================================================

ZIP_NAME="$(basename -- "$ZIP_PATH")"

WORK_DIR="${BUILD_DIR}/sparkle-${VERSION}"
INPUT_DIR="${WORK_DIR}/input"
GENERATED_APPCAST="${INPUT_DIR}/appcast.xml"
NEW_ITEM_FILE="${WORK_DIR}/new-item.xml"
STAGED_APPCAST="${WORK_DIR}/appcast.xml"

# GitHub always serves Release assets from this location. The asset name is the
# file name of the uploaded file (a "#label" suffix on `gh release create` only
# changes the display label), which is why ZIP_NAME must match the uploaded file.
DOWNLOAD_PREFIX="https://github.com/${REPOSITORY_NAME}/releases/download/${TAG}/"

if [[ -z "$FEED_URL" ]]; then
    FEED_URL="https://raw.githubusercontent.com/${REPOSITORY_NAME}/${MAIN_BRANCH}/${APPCAST_PATH}"
fi

# ==============================================================================
# Helpers
# ==============================================================================

plist_value() {
    local plist="$1"
    local key="$2"

    "$PLISTBUDDY" -c "Print :${key}" "$plist" 2>/dev/null || true
}

count_items() {
    grep -c '<item[ >]' "$1" || true
}

appcast_has_version() {
    local appcast="$1"

    grep -Fq "<sparkle:version>${VERSION}</sparkle:version>" "$appcast" ||
        grep -Fq "sparkle:version=\"${VERSION}\"" "$appcast"
}

find_sparkle_tool() {
    local tool="$1"
    local candidate

    if [[ -n "$SPARKLE_BIN" ]]; then
        candidate="${SPARKLE_BIN}/${tool}"

        [[ -x "$candidate" ]] ||
            die "${tool} not found or not executable in --sparkle-bin: ${SPARKLE_BIN}"

        printf '%s\n' "$candidate"
        return 0
    fi

    if command -v "$tool" >/dev/null 2>&1; then
        command -v "$tool"
        return 0
    fi

    # Location used when Sparkle is added to the Xcode project with SwiftPM.
    for candidate in \
        "${HOME}"/Library/Developer/Xcode/DerivedData/*/SourcePackages/artifacts/sparkle/Sparkle/bin/"$tool"
    do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

# ==============================================================================
# prepare
# ==============================================================================

validate_app_for_sparkle() {
    log "Validating the application for Sparkle..."

    [[ -d "$APP_PATH" ]] ||
        die "Application bundle not found: ${APP_PATH}"

    [[ -s "$ZIP_PATH" ]] ||
        die "Application ZIP not found or empty: ${ZIP_PATH}"

    local info_plist="${APP_PATH}/Contents/Info.plist"

    [[ -f "$info_plist" ]] ||
        die "Application Info.plist was not found: ${info_plist}"

    local bundle_version
    bundle_version="$(plist_value "$info_plist" CFBundleVersion)"

    # Sparkle compares CFBundleVersion, so it must be the release version.
    [[ "$bundle_version" == "$VERSION" ]] ||
        die "CFBundleVersion is '${bundle_version}', expected '${VERSION}'."

    local public_key
    public_key="$(plist_value "$info_plist" SUPublicEDKey)"

    [[ -n "$public_key" ]] ||
        die "SUPublicEDKey is missing from the app's Info.plist. Run Sparkle's generate_keys and add the printed public key to the app target."

    # A Sparkle EdDSA public key is 32 bytes in base64: 43 characters + "=".
    [[ "$public_key" =~ ^[A-Za-z0-9+/]{43}=$ ]] ||
        die "SUPublicEDKey ('${public_key}') is not a valid Sparkle public key. Replace the placeholder with the key printed by generate_keys."

    local feed_url
    feed_url="$(plist_value "$info_plist" SUFeedURL)"

    [[ -n "$feed_url" ]] ||
        die "SUFeedURL is missing from the app's Info.plist. Expected: ${FEED_URL}"

    if [[ "$feed_url" != "$FEED_URL" ]]; then
        warning "SUFeedURL in the app is '${feed_url}'."
        warning "Expected '${FEED_URL}'. Installed apps will read the URL baked into the app."
    fi

    [[ -d "${APP_PATH}/Contents/Frameworks/Sparkle.framework" ]] ||
        die "Sparkle.framework is not embedded in ${APP_PATH}. Add the Sparkle package to the app target (Embed & Sign)."

    if command -v codesign >/dev/null 2>&1; then
        if ! codesign --verify --deep --strict "$APP_PATH" >/dev/null 2>&1; then
            warning "${APP_PATH} does not pass 'codesign --verify --deep --strict'."
            warning "Notarization is not required, but at least ad-hoc signing is: Apple Silicon will not run unsigned code, including Sparkle's helpers."
        fi
    fi
}

validate_generated_item() {
    log "Validating the generated appcast entry..."

    [[ -s "$GENERATED_APPCAST" ]] ||
        die "generate_appcast did not produce ${GENERATED_APPCAST}."

    local item_count
    item_count="$(count_items "$GENERATED_APPCAST")"

    [[ "$item_count" == "1" ]] ||
        die "Expected exactly one <item> in the generated appcast, found ${item_count}."

    grep -Fq 'sparkle:edSignature=' "$GENERATED_APPCAST" ||
        die "The generated appcast entry has no sparkle:edSignature. Is the EdDSA private key available?"

    appcast_has_version "$GENERATED_APPCAST" ||
        die "The generated appcast entry does not carry version ${VERSION}."

    ENCLOSURE_URL="$(
        tr '\n' ' ' <"$GENERATED_APPCAST" |
            grep -o '<enclosure[^>]*>' |
            head -n 1 |
            sed -n 's/.*[[:space:]]url="\([^"]*\)".*/\1/p' ||
        true
    )"

    [[ -n "$ENCLOSURE_URL" ]] ||
        die "Unable to read the enclosure URL from the generated appcast."

    if [[ "$ENCLOSURE_URL" != "${DOWNLOAD_PREFIX}"* ]]; then
        die "Enclosure URL '${ENCLOSURE_URL}' does not start with '${DOWNLOAD_PREFIX}'."
    fi

    local enclosure_name="${ENCLOSURE_URL#"$DOWNLOAD_PREFIX"}"
    enclosure_name="${enclosure_name//%20/ }"

    [[ "$enclosure_name" == "$ZIP_NAME" ]] ||
        die "Enclosure file name '${enclosure_name}' does not match the uploaded asset '${ZIP_NAME}'."
}

merge_into_existing_appcast() {
    local existing_items=0

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

    if appcast_has_version "$APPCAST_PATH"; then
        die "${APPCAST_PATH} already contains an entry for version ${VERSION}."
    fi

    existing_items="$(count_items "$APPCAST_PATH")"

    # Only the new <item> block is taken from the generated file. Existing
    # entries are left exactly as they are, so each one keeps its own tag in its
    # download URL and nothing depends on how generate_appcast treats old items.
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

    local merged_items
    merged_items="$(count_items "$STAGED_APPCAST")"

    [[ "$merged_items" == "$((existing_items + 1))" ]] ||
        die "Merge check failed: expected $((existing_items + 1)) items, found ${merged_items}."
}

run_prepare() {
    validate_app_for_sparkle

    local generate_appcast
    generate_appcast="$(find_sparkle_tool generate_appcast)" ||
        die "generate_appcast not found. Use --sparkle-bin <dir>, set SPARKLE_BIN, or add Sparkle's bin directory to PATH."

    log "Using generate_appcast: ${generate_appcast}"

    rm -rf "$WORK_DIR"
    mkdir -p "$INPUT_DIR"

    # One archive only: the appcast entry for this version is generated alone
    # and merged afterwards.
    cp "$ZIP_PATH" "${INPUT_DIR}/${ZIP_NAME}"

    local generate_arguments=(
        "$INPUT_DIR"
        --download-url-prefix "$DOWNLOAD_PREFIX"
    )

    if [[ -n "$ED_KEY_FILE" ]]; then
        [[ -f "$ED_KEY_FILE" ]] ||
            die "EdDSA key file not found: ${ED_KEY_FILE}"

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

    success "Sparkle appcast prepared: ${STAGED_APPCAST}"

    printf '\n'
    printf 'Sparkle appcast:\n'
    printf '  Staged file:  %s\n' "$STAGED_APPCAST"
    printf '  Entries:      %s\n' "$(count_items "$STAGED_APPCAST")"
    printf '  Version:      %s\n' "$VERSION"
    printf '  Download URL: %s\n' "$ENCLOSURE_URL"
    printf '  Feed URL:     %s\n' "$FEED_URL"
    printf '\n'
}

# ==============================================================================
# publish
# ==============================================================================

print_publish_commands() {
    local commit_message="Update appcast for ${TAG}"

    printf '  cp %q %q\n' "$STAGED_APPCAST" "$APPCAST_PATH"
    printf '  git add -- %q\n' "$APPCAST_PATH"
    printf '  git commit -m %q -- %q\n' "$commit_message" "$APPCAST_PATH"
    printf '  git push %q %q\n' "$REMOTE" "$MAIN_BRANCH"
}

run_publish() {
    [[ -f "$STAGED_APPCAST" ]] ||
        die "Staged appcast not found: ${STAGED_APPCAST}. Run 'prepare' first."

    local current_branch
    current_branch="$(git branch --show-current)"

    [[ "$current_branch" == "$MAIN_BRANCH" ]] ||
        die "The appcast must be committed on ${MAIN_BRANCH}, but the current branch is '${current_branch}'."

    if [[ "$DRY_RUN" == true ]]; then
        log "Testing whether ${MAIN_BRANCH} could be pushed to ${REMOTE}..."

        if ! git push --dry-run "$REMOTE" "${MAIN_BRANCH}:${MAIN_BRANCH}"; then
            die "The simulated push of ${MAIN_BRANCH} failed."
        fi

        printf '\n'
        printf 'Sparkle commands that would be executed after the GitHub Release is published:\n'
        printf '\n'
        print_publish_commands
        printf '\n'

        warning "No appcast was committed."
        warning "No appcast was pushed."
        return 0
    fi

    local commit_message="Update appcast for ${TAG}"

    log "Verifying that ${ZIP_NAME} is attached to GitHub Release ${TAG}..."

    local release_assets
    release_assets="$(
        gh release view "$TAG" \
            --repo "$REPOSITORY_NAME" \
            --json assets \
            --jq '.assets[].name'
    )" || die "Unable to read GitHub Release ${TAG}. The appcast must not be published before the Release exists."

    if ! grep -Fxq -- "$ZIP_NAME" <<<"$release_assets"; then
        die "Asset '${ZIP_NAME}' is not attached to Release ${TAG}. Publishing the appcast now would point apps at a missing file."
    fi

    # Best-effort reachability check; a private repository fails here by design.
    if command -v curl >/dev/null 2>&1; then
        if ! curl \
            --fail \
            --silent \
            --location \
            --range 0-0 \
            --output /dev/null \
            "${DOWNLOAD_PREFIX}${ZIP_NAME// /%20}"
        then
            warning "The download URL did not answer successfully."
            warning "Sparkle needs it to be publicly downloadable (public repository)."
        fi
    fi

    log "Updating ${APPCAST_PATH}..."

    mkdir -p "$(dirname -- "$APPCAST_PATH")"
    cp "$STAGED_APPCAST" "$APPCAST_PATH"

    git add -- "$APPCAST_PATH"

    if git diff --cached --quiet -- "$APPCAST_PATH"; then
        # Nothing new to commit. That is expected when a previous publish
        # committed the appcast but the push failed: just push it now.
        if [[ -n "$(git log --format=%H "${REMOTE}/${MAIN_BRANCH}..${MAIN_BRANCH}" -- "$APPCAST_PATH")" ]]; then
            log "${APPCAST_PATH} is already committed locally but not pushed."
        else
            die "${APPCAST_PATH} has no changes to commit."
        fi
    else
        git commit -m "$commit_message" -- "$APPCAST_PATH"
    fi

    log "Pushing ${MAIN_BRANCH} to ${REMOTE}..."

    if ! git push "$REMOTE" "$MAIN_BRANCH"; then
        error "Pushing the appcast commit failed."

        warning "The appcast commit exists locally on ${MAIN_BRANCH} but was NOT pushed."
        warning "Installed apps will not see ${TAG} until it is pushed."
        warning "If ${MAIN_BRANCH} is protected, push the commit through a pull request instead."

        printf '\n'
        printf 'After resolving the problem, retry with:\n'
        printf '\n'
        printf '  git push %q %q\n' "$REMOTE" "$MAIN_BRANCH"

        exit 1
    fi

    success "Appcast for ${TAG} pushed to ${REMOTE}/${MAIN_BRANCH}."

    printf '\n'
    printf 'Sparkle feed:\n'
    printf '  Feed URL: %s\n' "$FEED_URL"
    printf '\n'

    warning "raw.githubusercontent.com caches files for a few minutes before the new appcast is visible."
}

# ==============================================================================
# Main
# ==============================================================================

case "$MODE" in
    prepare)
        run_prepare
        ;;

    publish)
        run_publish
        ;;
esac
