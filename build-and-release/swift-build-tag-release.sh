#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

# Recommended invocation
# First, run the complete process without publishing anything:
# ./release.sh \
#     --scheme WOA \
#     --project src/WOA.xcodeproj \
#     --app-name WOA \
#     --dry-run
# If the dry run succeeds, execute the actual minor release:
# ./release.sh \
#     --scheme WOA \
#     --project src/WOA.xcodeproj \
#     --app-name WOA    

# ==============================================================================
# Default parameter values
# ==============================================================================

SCHEME=""
WORKSPACE_PATH=""
PROJECT_PATH=""
APP_NAME=""
EXPORT_OPTIONS_PLIST=""

MAIN_BRANCH="main"
REMOTE="origin"
CONFIGURATION="Release"
DIST_DIR="dist"
BUILD_DIR="build"

NEW_MAJOR=false
DRY_RUN=false
ORIGINAL_BRANCH=""

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

    error "Release failed at line ${line_number} with exit code ${exit_code}."

    if [[ -n "$ORIGINAL_BRANCH" ]]; then
        warning "Current branch: $(git branch --show-current 2>/dev/null || printf 'unknown')"
    fi

    exit "$exit_code"
}

trap 'handle_error "$LINENO"' ERR

# ==============================================================================
# Help
# ==============================================================================

show_help() {
    cat <<'HELP'
Usage:

  ./release.sh --scheme <scheme> [options]

Required parameters:

  --scheme <name>
      Xcode shared scheme to build.

Xcode project parameters:

  --workspace <path>
      Path to the Xcode workspace.

  --project <path>
      Path to the Xcode project.

      --workspace and --project are mutually exclusive.

      If neither is specified, the script automatically searches for:
        1. A .xcworkspace
        2. A .xcodeproj

Application parameters:

  --app-name <name>
      Application name without the .app extension.

      If omitted, the name is derived from the application found in the
      Xcode archive.

  --export-options-plist <path>
      ExportOptions.plist used by xcodebuild -exportArchive.

      If omitted, the application is copied directly from the Xcode archive.

Git parameters:

  --main-branch <name>
      Branch to release.

      Default:
        main

  --remote <name>
      Git remote to use.

      Default:
        origin

Build parameters:

  --configuration <name>
      Xcode build configuration.

      Default:
        Release

  --build-dir <path>
      Directory for intermediate build files.

      Default:
        build

  --dist-dir <path>
      Directory for final artifacts.

      Default:
        dist

Version parameters:

  --new-major
      Increment the major version and reset minor and patch to zero.

      Example:
        v1.4.3 -> v2.0.0

      If omitted, the minor version is incremented and patch is reset to zero.

      Example:
        v1.4.3 -> v1.5.0

Execution parameters:

  --dry-run
      Build and validate everything without creating or pushing a Git tag,
      creating a GitHub Release, or uploading artifacts.

  -h, --help
      Display this help.

Examples:

  Standard minor release:

    ./release.sh \
        --scheme MyApp

  Major release:

    ./release.sh \
        --scheme MyApp \
        --new-major

  Dry run:

    ./release.sh \
        --scheme MyApp \
        --dry-run

  Major release dry run:

    ./release.sh \
        --scheme MyApp \
        --new-major \
        --dry-run

  Explicit workspace:

    ./release.sh \
        --scheme MyApp \
        --workspace MyApp.xcworkspace \
        --app-name MyApp

  Explicit project:

    ./release.sh \
        --scheme MyApp \
        --project MyApp.xcodeproj \
        --app-name MyApp

  Complete example:

    ./release.sh \
        --scheme MyApp \
        --workspace MyApp.xcworkspace \
        --app-name MyApp \
        --export-options-plist ExportOptions.plist \
        --main-branch main \
        --remote origin \
        --configuration Release \
        --build-dir build \
        --dist-dir dist \
        --new-major \
        --dry-run
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

while [[ $# -gt 0 ]]; do
    case "$1" in
        --scheme)
            require_parameter_value "$1" "$#"
            SCHEME="$2"
            shift 2
            ;;

        --workspace)
            require_parameter_value "$1" "$#"
            WORKSPACE_PATH="$2"
            shift 2
            ;;

        --project)
            require_parameter_value "$1" "$#"
            PROJECT_PATH="$2"
            shift 2
            ;;

        --app-name)
            require_parameter_value "$1" "$#"
            APP_NAME="$2"
            shift 2
            ;;

        --export-options-plist)
            require_parameter_value "$1" "$#"
            EXPORT_OPTIONS_PLIST="$2"
            shift 2
            ;;

        --main-branch)
            require_parameter_value "$1" "$#"
            MAIN_BRANCH="$2"
            shift 2
            ;;

        --remote)
            require_parameter_value "$1" "$#"
            REMOTE="$2"
            shift 2
            ;;

        --configuration)
            require_parameter_value "$1" "$#"
            CONFIGURATION="$2"
            shift 2
            ;;

        --build-dir)
            require_parameter_value "$1" "$#"
            BUILD_DIR="$2"
            shift 2
            ;;

        --dist-dir)
            require_parameter_value "$1" "$#"
            DIST_DIR="$2"
            shift 2
            ;;

        --new-major)
            NEW_MAJOR=true
            shift
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

[[ -n "$SCHEME" ]] ||
    die "The required --scheme parameter was not provided."

if [[ -n "$WORKSPACE_PATH" && -n "$PROJECT_PATH" ]]; then
    die "--workspace and --project cannot be used together."
fi

[[ -n "$MAIN_BRANCH" ]] ||
    die "--main-branch cannot be empty."

[[ -n "$REMOTE" ]] ||
    die "--remote cannot be empty."

[[ -n "$CONFIGURATION" ]] ||
    die "--configuration cannot be empty."

[[ -n "$BUILD_DIR" ]] ||
    die "--build-dir cannot be empty."

[[ -n "$DIST_DIR" ]] ||
    die "--dist-dir cannot be empty."

if [[ "$BUILD_DIR" == "$DIST_DIR" ]]; then
    die "--build-dir and --dist-dir must reference different directories."
fi

if [[ "$DRY_RUN" == true ]]; then
    warning "DRY-RUN MODE ENABLED"
    warning "Artifacts will be built and validated, but nothing will be published."
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
require_command xcodebuild
require_command hdiutil
require_command ditto
require_command gh
require_command find
require_command grep
require_command head
require_command stat
require_command uname

[[ "$(uname -s)" == "Darwin" ]] ||
    die "This script must run on macOS."

# ==============================================================================
# Git repository validation
# ==============================================================================

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    die "The current directory is not inside a Git repository."

REPOSITORY_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPOSITORY_ROOT"

ORIGINAL_BRANCH="$(git branch --show-current)"

[[ -n "$ORIGINAL_BRANCH" ]] ||
    die "Detached HEAD is not supported."

git remote get-url "$REMOTE" >/dev/null 2>&1 ||
    die "Git remote '${REMOTE}' is not configured."

if [[ -n "$(git status --porcelain)" ]]; then
    die "The working tree contains uncommitted changes. Commit or stash them before running the release."
fi

# ==============================================================================
# GitHub validation
# ==============================================================================

log "Verifying GitHub CLI authentication..."

gh auth status >/dev/null 2>&1 ||
    die "GitHub CLI is not authenticated. Run: gh auth login"

log "Verifying GitHub repository access..."

REPOSITORY_NAME="$(
    gh repo view \
        --json nameWithOwner \
        --jq '.nameWithOwner'
)"

[[ -n "$REPOSITORY_NAME" ]] ||
    die "Unable to determine the GitHub repository."

VIEWER_PERMISSION="$(
    gh repo view \
        --json viewerPermission \
        --jq '.viewerPermission'
)"

case "$VIEWER_PERMISSION" in
    ADMIN|MAINTAIN|WRITE)
        log "GitHub repository: ${REPOSITORY_NAME}"
        log "GitHub permission: ${VIEWER_PERMISSION}"
        ;;

    READ|TRIAGE)
        die "The authenticated GitHub account has ${VIEWER_PERMISSION} permission and cannot publish releases."
        ;;

    *)
        die "Unable to verify GitHub write permission. Permission returned: ${VIEWER_PERMISSION:-unknown}"
        ;;
esac

# ==============================================================================
# Detect Xcode workspace or project
# ==============================================================================

XCODE_CONTAINER_ARGUMENTS=()

if [[ -n "$WORKSPACE_PATH" ]]; then
    [[ -d "$WORKSPACE_PATH" ]] ||
        die "Workspace not found: ${WORKSPACE_PATH}"

    [[ "$WORKSPACE_PATH" == *.xcworkspace ]] ||
        die "--workspace must reference a .xcworkspace directory."

    XCODE_CONTAINER_ARGUMENTS=(
        -workspace "$WORKSPACE_PATH"
    )

    log "Using workspace: ${WORKSPACE_PATH}"

elif [[ -n "$PROJECT_PATH" ]]; then
    [[ -d "$PROJECT_PATH" ]] ||
        die "Project not found: ${PROJECT_PATH}"

    [[ "$PROJECT_PATH" == *.xcodeproj ]] ||
        die "--project must reference a .xcodeproj directory."

    XCODE_CONTAINER_ARGUMENTS=(
        -project "$PROJECT_PATH"
    )

    log "Using project: ${PROJECT_PATH}"

else
    DETECTED_WORKSPACE="$(
        find . \
            -maxdepth 2 \
            -type d \
            -name '*.xcworkspace' \
            ! -path '*/project.xcworkspace' \
            -print \
            -quit
    )"

    DETECTED_PROJECT="$(
        find . \
            -maxdepth 2 \
            -type d \
            -name '*.xcodeproj' \
            -print \
            -quit
    )"

    if [[ -n "$DETECTED_WORKSPACE" ]]; then
        WORKSPACE_PATH="${DETECTED_WORKSPACE#./}"

        XCODE_CONTAINER_ARGUMENTS=(
            -workspace "$WORKSPACE_PATH"
        )

        log "Automatically detected workspace: ${WORKSPACE_PATH}"

    elif [[ -n "$DETECTED_PROJECT" ]]; then
        PROJECT_PATH="${DETECTED_PROJECT#./}"

        XCODE_CONTAINER_ARGUMENTS=(
            -project "$PROJECT_PATH"
        )

        log "Automatically detected project: ${PROJECT_PATH}"

    else
        die "No .xcworkspace or .xcodeproj was found."
    fi
fi

# ==============================================================================
# Scheme validation
# ==============================================================================

log "Verifying Xcode scheme: ${SCHEME}"

if ! xcodebuild \
    "${XCODE_CONTAINER_ARGUMENTS[@]}" \
    -scheme "$SCHEME" \
    -showBuildSettings \
    >/dev/null
then
    die "The Xcode scheme '${SCHEME}' is not available or is not shared."
fi

# ==============================================================================
# Synchronize the release branch
# ==============================================================================

log "Fetching branch and tags from ${REMOTE}..."

git fetch \
    "$REMOTE" \
    "$MAIN_BRANCH" \
    --tags \
    --prune

if [[ "$ORIGINAL_BRANCH" != "$MAIN_BRANCH" ]]; then
    log "Switching from ${ORIGINAL_BRANCH} to ${MAIN_BRANCH}..."
    git switch "$MAIN_BRANCH"
fi

log "Updating ${MAIN_BRANCH} using fast-forward only..."

git pull \
    --ff-only \
    "$REMOTE" \
    "$MAIN_BRANCH"

LOCAL_MAIN_COMMIT="$(git rev-parse "$MAIN_BRANCH")"
REMOTE_MAIN_COMMIT="$(git rev-parse "${REMOTE}/${MAIN_BRANCH}")"

if [[ "$LOCAL_MAIN_COMMIT" != "$REMOTE_MAIN_COMMIT" ]]; then
    die "Local ${MAIN_BRANCH} does not match ${REMOTE}/${MAIN_BRANCH}."
fi

# ==============================================================================
# Calculate the next version
# ==============================================================================

LATEST_TAG="$(
    git tag \
        --merged "$MAIN_BRANCH" \
        --list 'v[0-9]*.[0-9]*.[0-9]*' \
        --sort=-v:refname |
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' |
    head -n 1 ||
    true
)"

if [[ -z "$LATEST_TAG" ]]; then
    LATEST_TAG="v0.0.0"
    warning "No semantic version tag was found on ${MAIN_BRANCH}."
    warning "Using ${LATEST_TAG} as the initial baseline."
fi

VERSION_WITHOUT_PREFIX="${LATEST_TAG#v}"

IFS='.' read -r \
    CURRENT_MAJOR \
    CURRENT_MINOR \
    CURRENT_PATCH \
    <<< "$VERSION_WITHOUT_PREFIX"

if [[ "$NEW_MAJOR" == true ]]; then
    NEXT_MAJOR=$((CURRENT_MAJOR + 1))
    NEXT_MINOR=0
    NEXT_PATCH=0
else
    NEXT_MAJOR="$CURRENT_MAJOR"
    NEXT_MINOR=$((CURRENT_MINOR + 1))
    NEXT_PATCH=0
fi

VERSION="${NEXT_MAJOR}.${NEXT_MINOR}.${NEXT_PATCH}"
TAG="v${VERSION}"

log "Previous version: ${LATEST_TAG}"
log "Next version:     ${TAG}"

# ==============================================================================
# Tag and release conflict validation
# ==============================================================================

if git rev-parse "$TAG" >/dev/null 2>&1; then
    die "Tag already exists locally: ${TAG}"
fi

if git ls-remote \
    --exit-code \
    --tags \
    "$REMOTE" \
    "refs/tags/${TAG}" \
    >/dev/null 2>&1
then
    die "Tag already exists on ${REMOTE}: ${TAG}"
fi

if gh release view "$TAG" >/dev/null 2>&1; then
    die "A GitHub Release already exists for ${TAG}."
fi

# ==============================================================================
# Prepare directories
# ==============================================================================

ARCHIVE_PATH="${BUILD_DIR}/${SCHEME}-${VERSION}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export-${VERSION}"
DMG_STAGING_DIR="${BUILD_DIR}/dmg-${VERSION}"

rm -rf "$BUILD_DIR" "$DIST_DIR"

mkdir -p \
    "$BUILD_DIR" \
    "$DIST_DIR" \
    "$EXPORT_PATH"

# ==============================================================================
# Build the Xcode archive
# ==============================================================================

log "Building ${SCHEME} in ${CONFIGURATION} configuration..."

xcodebuild \
    "${XCODE_CONTAINER_ARGUMENTS[@]}" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    MARKETING_VERSION="$VERSION" \
    clean archive

[[ -d "$ARCHIVE_PATH" ]] ||
    die "Xcode archive was not created: ${ARCHIVE_PATH}"

# ==============================================================================
# Obtain the application bundle
# ==============================================================================

ARCHIVED_APP="$(
    find "${ARCHIVE_PATH}/Products/Applications" \
        -maxdepth 1 \
        -type d \
        -name '*.app' \
        -print \
        -quit 2>/dev/null ||
    true
)"

if [[ -n "$EXPORT_OPTIONS_PLIST" ]]; then
    [[ -f "$EXPORT_OPTIONS_PLIST" ]] ||
        die "Export options plist not found: ${EXPORT_OPTIONS_PLIST}"

    log "Exporting archive using ${EXPORT_OPTIONS_PLIST}..."

    xcodebuild \
        -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

    EXPORTED_APP="$(
        find "$EXPORT_PATH" \
            -maxdepth 2 \
            -type d \
            -name '*.app' \
            -print \
            -quit
    )"

    [[ -n "$EXPORTED_APP" ]] ||
        die "No .app bundle was found in the export directory."

    SOURCE_APP="$EXPORTED_APP"

else
    [[ -n "$ARCHIVED_APP" ]] ||
        die "No .app bundle was found in the Xcode archive."

    SOURCE_APP="$ARCHIVED_APP"
fi

DETECTED_APP_NAME="$(basename "$SOURCE_APP" .app)"

if [[ -z "$APP_NAME" ]]; then
    APP_NAME="$DETECTED_APP_NAME"
    log "Automatically detected application name: ${APP_NAME}"
fi

APP_PATH="${DIST_DIR}/${APP_NAME}.app"
APP_ZIP="${DIST_DIR}/${APP_NAME}-${VERSION}.app.zip"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"

log "Copying application bundle to ${APP_PATH}..."

ditto \
    "$SOURCE_APP" \
    "$APP_PATH"

[[ -d "$APP_PATH" ]] ||
    die "Application bundle was not created: ${APP_PATH}"

# ==============================================================================
# Create the uploadable application ZIP
# ==============================================================================

log "Creating application ZIP..."

ditto \
    -c \
    -k \
    --sequesterRsrc \
    --keepParent \
    "$APP_PATH" \
    "$APP_ZIP"

[[ -f "$APP_ZIP" ]] ||
    die "Application ZIP was not created: ${APP_ZIP}"

# ==============================================================================
# Create the DMG
# ==============================================================================

mkdir -p "$DMG_STAGING_DIR"

ditto \
    "$APP_PATH" \
    "${DMG_STAGING_DIR}/${APP_NAME}.app"

ln -s \
    /Applications \
    "${DMG_STAGING_DIR}/Applications"

log "Creating DMG..."

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

[[ -f "$DMG_PATH" ]] ||
    die "DMG was not created: ${DMG_PATH}"

log "Verifying DMG integrity..."

hdiutil verify "$DMG_PATH" >/dev/null

# ==============================================================================
# Validate artifacts
# ==============================================================================

log "Validating release artifacts..."

[[ -r "$APP_ZIP" ]] ||
    die "Application ZIP is not readable: ${APP_ZIP}"

[[ -s "$APP_ZIP" ]] ||
    die "Application ZIP is empty: ${APP_ZIP}"

[[ -r "$DMG_PATH" ]] ||
    die "DMG is not readable: ${DMG_PATH}"

[[ -s "$DMG_PATH" ]] ||
    die "DMG is empty: ${DMG_PATH}"

APP_ZIP_SIZE="$(stat -f '%z' "$APP_ZIP")"
DMG_SIZE="$(stat -f '%z' "$DMG_PATH")"

log "Application ZIP size: ${APP_ZIP_SIZE} bytes"
log "DMG size:             ${DMG_SIZE} bytes"

# ==============================================================================
# Dry-run feasibility validation
# ==============================================================================

if [[ "$DRY_RUN" == true ]]; then
    log "Testing whether ${TAG} could be pushed to ${REMOTE}..."

    # Simulates the creation of the remote tag directly from the current
    # release branch. No local or remote tag is created.
    if ! git push \
        --dry-run \
        "$REMOTE" \
        "${MAIN_BRANCH}:refs/tags/${TAG}"
    then
        die "The simulated tag push failed for ${TAG}."
    fi

    printf '\n'
    success "Dry run completed successfully."

    printf '\n'
    printf 'Calculated release:\n'
    printf '  Repository: %s\n' "$REPOSITORY_NAME"
    printf '  Branch:     %s\n' "$MAIN_BRANCH"
    printf '  Version:    %s\n' "$VERSION"
    printf '  Tag:        %s\n' "$TAG"

    printf '\n'
    printf 'Generated and validated artifacts:\n'
    printf '  App:     %s\n' "$APP_PATH"
    printf '  App ZIP: %s\n' "$APP_ZIP"
    printf '  DMG:     %s\n' "$DMG_PATH"

    printf '\n'
    printf 'Commands that would be executed:\n'

    printf '\n'
    printf '  git tag -a %q -m %q %q\n' \
        "$TAG" \
        "Release ${TAG}" \
        "$MAIN_BRANCH"

    printf '\n'
    printf '  git push %q %q\n' \
        "$REMOTE" \
        "refs/tags/${TAG}"

    printf '\n'
    printf '  gh release create %q %q %q --verify-tag --title %q --generate-notes\n' \
        "$TAG" \
        "${APP_ZIP}#${APP_NAME}.app.zip" \
        "${DMG_PATH}#${APP_NAME}.dmg" \
        "$TAG"

    printf '\n'
    printf 'Feasibility checks:\n'
    printf '  Xcode scheme:                 OK\n'
    printf '  Xcode Release archive:        OK\n'
    printf '  Application bundle:           OK\n'
    printf '  Application ZIP:              OK\n'
    printf '  DMG creation:                 OK\n'
    printf '  DMG verification:             OK\n'
    printf '  Local tag availability:       OK\n'
    printf '  Remote tag availability:      OK\n'
    printf '  Simulated remote tag push:    OK\n'
    printf '  GitHub repository access:     OK\n'
    printf '  GitHub write permission:      OK\n'
    printf '  GitHub Release availability:  OK\n'

    printf '\n'
    warning "No local tag was created."
    warning "No remote tag was pushed."
    warning "No GitHub Release was created."
    warning "No artifacts were uploaded."

    exit 0
fi

# ==============================================================================
# Create the local Git tag
# ==============================================================================

log "Creating annotated tag ${TAG} on ${MAIN_BRANCH}..."

git tag \
    -a "$TAG" \
    -m "Release ${TAG}" \
    "$MAIN_BRANCH"

# ==============================================================================
# Push the Git tag
# ==============================================================================

log "Pushing ${TAG} to ${REMOTE}..."

if ! git push "$REMOTE" "refs/tags/${TAG}"; then
    warning "Tag push failed."
    warning "Removing local tag ${TAG}."

    git tag -d "$TAG" >/dev/null 2>&1 || true

    die "Unable to push tag ${TAG}."
fi

# ==============================================================================
# Create GitHub Release and upload artifacts
# ==============================================================================

log "Creating GitHub Release ${TAG}..."

if ! gh release create "$TAG" \
    "$APP_ZIP#${APP_NAME}.app.zip" \
    "$DMG_PATH#${APP_NAME}.dmg" \
    --verify-tag \
    --title "$TAG" \
    --generate-notes
then
    error "GitHub Release creation failed."

    warning "The Git tag ${TAG} has already been pushed to ${REMOTE}."
    warning "The pushed tag was intentionally not deleted."

    printf '\n'
    printf 'After resolving the problem, retry with:\n'
    printf '\n'

    printf 'gh release create %q %q %q --verify-tag --title %q --generate-notes\n' \
        "$TAG" \
        "${APP_ZIP}#${APP_NAME}.app.zip" \
        "${DMG_PATH}#${APP_NAME}.dmg" \
        "$TAG"

    exit 1
fi

# ==============================================================================
# Final release validation
# ==============================================================================

log "Verifying the published GitHub Release..."

gh release view "$TAG" >/dev/null

RELEASE_URL="$(
    gh release view "$TAG" \
        --json url \
        --jq '.url'
)"

success "Release ${TAG} completed successfully."

printf '\n'
printf 'Release details:\n'
printf '  Repository: %s\n' "$REPOSITORY_NAME"
printf '  Branch:     %s\n' "$MAIN_BRANCH"
printf '  Tag:        %s\n' "$TAG"
printf '  App:        %s\n' "$APP_PATH"
printf '  App ZIP:    %s\n' "$APP_ZIP"
printf '  DMG:        %s\n' "$DMG_PATH"
printf '  Release:    %s\n' "$RELEASE_URL"