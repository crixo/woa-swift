#!/usr/bin/env bash
# ==============================================================================
# build-tag-release.sh
#
# Builds a macOS app, tags a release and publishes it on GitHub.
# (The Sparkle appcast is NOT handled here: run sparkle-appcast.sh afterwards.)
#
# WHAT IT DOES, IN ORDER
#   1. Checks tools, git state, GitHub access and the Xcode scheme.
#   2. Calculates the next version from the latest vX.Y.Z git tag.
#   3. Writes that version into project.pbxproj and commits it locally.
#   4. Builds the archive, verifies the version baked in Info.plist,
#      creates the .app.zip and the .dmg in the dist directory.
#   5. --dry-run stops here and rolls everything back. Otherwise:
#   6. Pushes the version commit, creates and pushes the tag,
#      creates the GitHub Release with the zip and the dmg.
#
# VERSIONING
#   project.pbxproj is the single source of truth for the app version.
#   The app reads it at runtime from CFBundleShortVersionString
#   (Info.plist must use $(MARKETING_VERSION) and $(CURRENT_PROJECT_VERSION)).
#   The version commit is pushed BEFORE the tag, so a tag always points at a
#   commit whose source contains the released version.
#
# SAFETY
#   Until step 6 nothing is published. If anything fails before the version
#   commit is pushed (or in --dry-run), the version change is rolled back and
#   the repository is left exactly as it was found.
#
# USAGE
#   Dry run first:
#     ./build-tag-release.sh --scheme WOA --project src/WOA.xcodeproj \
#         --app-name WOA --dry-run
#   Then the real release:
#     ./build-tag-release.sh --scheme WOA --project src/WOA.xcodeproj \
#         --app-name WOA
#   Then, to publish the Sparkle update feed:
#     ./sparkle-appcast.sh
#
#   Run ./build-tag-release.sh --help for all options.
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'


# ==============================================================================
# 1. CONFIGURATION (defaults, overridable by command-line options)
# ==============================================================================

# --- Xcode -------------------------------------------------------------------
SCHEME=""                   # required
WORKSPACE_PATH=""           # --workspace
PROJECT_PATH=""             # --project
APP_NAME=""                 # --app-name (derived from the archive if empty)
EXPORT_OPTIONS_PLIST=""     # --export-options-plist (optional)
CONFIGURATION="Release"

# --- Git / GitHub ------------------------------------------------------------
MAIN_BRANCH="main"
REMOTE="origin"

# --- Output directories ------------------------------------------------------
BUILD_DIR="build"           # intermediate files (archive, dmg staging)
DIST_DIR="dist"             # final artifacts (.app, .zip, .dmg)

# --- Behaviour flags ---------------------------------------------------------
NEW_MAJOR=false             # --new-major: 1.4.3 -> 2.0.0 instead of 1.5.0
DRY_RUN=false               # --dry-run
SKIP_VERSION_BUMP=false     # --skip-version-bump

# --- Runtime state (filled in while the script runs; do not set by hand) -----
XCODE_CONTAINER_ARGS=()     # -workspace X / -project X for xcodebuild
PBXPROJ_PATH=""             # project.pbxproj that holds the version
REPOSITORY_NAME=""          # owner/repo on GitHub
LATEST_TAG=""
VERSION=""                  # e.g. 0.4.0
TAG=""                      # e.g. v0.4.0
APP_PATH=""                 # dist/<name>.app
APP_ZIP=""                  # dist/<name>-<version>.app.zip
DMG_PATH=""                 # dist/<name>-<version>.dmg
ARCHIVE_PATH=""
EXPORT_PATH=""

# Version-commit bookkeeping, used by the rollback in section 2.
VERSION_BUMP_COMMITTED=false
VERSION_BUMP_PUSHED=false
PRE_BUMP_COMMIT=""


# ==============================================================================
# 2. LOGGING AND ERROR HANDLING
# ==============================================================================

log()     { printf '\033[1;34m[INFO]\033[0m %s\n'    "$*"; }
success() { printf '\033[1;32m[SUCCESS]\033[0m %s\n' "$*"; }
warning() { printf '\033[1;33m[WARNING]\033[0m %s\n' "$*" >&2; }
error()   { printf '\033[1;31m[ERROR]\033[0m %s\n'   "$*" >&2; }

die() {
    error "$*"
    exit 1
}

# Runs when any command fails (set -e). Reports where, then exits.
handle_error() {
    local exit_code=$?
    error "Release failed at line ${1:-unknown} with exit code ${exit_code}."
    exit "$exit_code"
}
trap 'handle_error "$LINENO"' ERR

# Runs on EVERY exit (success, dry-run, die, error).
# If the version commit was created but never pushed, it is undone here.
# Once it has been pushed it is never touched.
rollback_version_bump() {
    [[ "$VERSION_BUMP_PUSHED" == true ]] && return 0

    if [[ "$VERSION_BUMP_COMMITTED" == true ]]; then
        warning "Rolling back the local version commit..."
        if git reset --hard "$PRE_BUMP_COMMIT" >/dev/null 2>&1; then
            warning "Repository restored to ${PRE_BUMP_COMMIT}."
        else
            warning "Automatic rollback failed. Run manually: git reset --hard ${PRE_BUMP_COMMIT}"
        fi
    fi

    return 0
}
trap rollback_version_bump EXIT


# ==============================================================================
# 3. COMMAND-LINE PARSING AND VALIDATION
# ==============================================================================

show_help() {
    cat <<'HELP'
Usage: ./build-tag-release.sh --scheme <scheme> [options]

Xcode
  --scheme <name>               Shared Xcode scheme to build (required).
  --project <path>              Path to the .xcodeproj.
  --workspace <path>            Path to the .xcworkspace.
                                (--project and --workspace are exclusive; if
                                neither is given, one is auto-detected.)
  --app-name <name>             App name without ".app" (default: detected).
  --export-options-plist <path> Use xcodebuild -exportArchive with this plist
                                (default: copy the .app from the archive).
  --configuration <name>        Build configuration (default: Release).

Git / output
  --main-branch <name>          Branch to release (default: main).
  --remote <name>               Git remote (default: origin).
  --build-dir <path>            Intermediate files (default: build).
  --dist-dir <path>             Final artifacts (default: dist).

Version
  --new-major                   Bump the major version (v1.4.3 -> v2.0.0).
                                Default bumps the minor (v1.4.3 -> v1.5.0).
  --skip-version-bump           Do not write the version into project.pbxproj.

Execution
  --dry-run                     Build and validate everything, publish nothing,
                                roll back the version change.
  -h, --help                    Show this help.

The Sparkle appcast is published separately by ./sparkle-appcast.sh.
HELP
}

# Fails if an option that needs a value was given without one.
need_value() {
    local option="$1" remaining="$2"
    [[ "$remaining" -ge 2 ]] || die "Missing value for ${option}"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --scheme)                need_value "$1" "$#"; SCHEME="$2";               shift 2 ;;
            --project)               need_value "$1" "$#"; PROJECT_PATH="$2";         shift 2 ;;
            --workspace)             need_value "$1" "$#"; WORKSPACE_PATH="$2";       shift 2 ;;
            --app-name)              need_value "$1" "$#"; APP_NAME="$2";             shift 2 ;;
            --export-options-plist)  need_value "$1" "$#"; EXPORT_OPTIONS_PLIST="$2"; shift 2 ;;
            --configuration)         need_value "$1" "$#"; CONFIGURATION="$2";        shift 2 ;;
            --main-branch)           need_value "$1" "$#"; MAIN_BRANCH="$2";          shift 2 ;;
            --remote)                need_value "$1" "$#"; REMOTE="$2";               shift 2 ;;
            --build-dir)             need_value "$1" "$#"; BUILD_DIR="$2";            shift 2 ;;
            --dist-dir)              need_value "$1" "$#"; DIST_DIR="$2";             shift 2 ;;
            --new-major)             NEW_MAJOR=true;         shift ;;
            --skip-version-bump)     SKIP_VERSION_BUMP=true; shift ;;
            --dry-run)               DRY_RUN=true;           shift ;;
            -h|--help)               show_help; exit 0 ;;
            *) die "Unknown option: $1 (use --help)" ;;
        esac
    done
}

validate_args() {
    [[ -n "$SCHEME" ]] || die "--scheme is required."

    if [[ -n "$WORKSPACE_PATH" && -n "$PROJECT_PATH" ]]; then
        die "--workspace and --project cannot be used together."
    fi

    [[ "$BUILD_DIR" != "$DIST_DIR" ]] ||
        die "--build-dir and --dist-dir must be different."

    if [[ "$DRY_RUN" == true ]]; then
        warning "DRY-RUN: everything is built and validated, nothing is published."
    fi
}


# ==============================================================================
# 4. PRE-FLIGHT CHECKS (tools, git, GitHub, Xcode)
# ==============================================================================

require_tools() {
    local tool
    for tool in git gh xcodebuild hdiutil ditto sed grep find; do
        command -v "$tool" >/dev/null 2>&1 || die "Required command not found: ${tool}"
    done

    [[ "$(uname -s)" == "Darwin" ]] || die "This script must run on macOS."
}

# Moves to the repo root and requires a clean tree on a named branch.
check_git_state() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
        die "Not inside a Git repository."

    cd "$(git rev-parse --show-toplevel)"

    [[ -n "$(git branch --show-current)" ]] || die "Detached HEAD is not supported."

    git remote get-url "$REMOTE" >/dev/null 2>&1 ||
        die "Git remote '${REMOTE}' is not configured."

    [[ -z "$(git status --porcelain)" ]] ||
        die "Uncommitted changes found. Commit or stash them first."
}

# Requires an authenticated gh with permission to publish releases.
check_github_access() {
    local permission

    log "Verifying GitHub access..."

    gh auth status >/dev/null 2>&1 || die "GitHub CLI not authenticated. Run: gh auth login"

    REPOSITORY_NAME="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
    [[ -n "$REPOSITORY_NAME" ]] || die "Unable to determine the GitHub repository."

    permission="$(gh repo view --json viewerPermission --jq '.viewerPermission')"
    case "$permission" in
        ADMIN|MAINTAIN|WRITE) log "GitHub repository: ${REPOSITORY_NAME} (${permission})" ;;
        *) die "GitHub permission '${permission:-unknown}' cannot publish releases." ;;
    esac
}

# Fills XCODE_CONTAINER_ARGS and PROJECT_PATH / WORKSPACE_PATH.
resolve_xcode_container() {
    local found

    if [[ -n "$WORKSPACE_PATH" ]]; then
        [[ -d "$WORKSPACE_PATH" && "$WORKSPACE_PATH" == *.xcworkspace ]] ||
            die "Workspace not found or not a .xcworkspace: ${WORKSPACE_PATH}"
        XCODE_CONTAINER_ARGS=(-workspace "$WORKSPACE_PATH")

    elif [[ -n "$PROJECT_PATH" ]]; then
        [[ -d "$PROJECT_PATH" && "$PROJECT_PATH" == *.xcodeproj ]] ||
            die "Project not found or not a .xcodeproj: ${PROJECT_PATH}"
        XCODE_CONTAINER_ARGS=(-project "$PROJECT_PATH")

    else
        found="$(find . -maxdepth 2 -type d -name '*.xcworkspace' ! -path '*/project.xcworkspace' -print -quit)"
        if [[ -n "$found" ]]; then
            WORKSPACE_PATH="${found#./}"
            XCODE_CONTAINER_ARGS=(-workspace "$WORKSPACE_PATH")
        else
            found="$(find . -maxdepth 2 -type d -name '*.xcodeproj' -print -quit)"
            [[ -n "$found" ]] || die "No .xcworkspace or .xcodeproj found."
            PROJECT_PATH="${found#./}"
            XCODE_CONTAINER_ARGS=(-project "$PROJECT_PATH")
        fi
    fi

    log "Xcode container: ${WORKSPACE_PATH:-$PROJECT_PATH}"
}

verify_scheme() {
    log "Verifying Xcode scheme: ${SCHEME}"

    xcodebuild "${XCODE_CONTAINER_ARGS[@]}" -scheme "$SCHEME" -showBuildSettings >/dev/null ||
        die "Scheme '${SCHEME}' is not available or not shared."
}

# Switches to the main branch and requires it to match the remote exactly.
sync_main_branch() {
    log "Fetching ${MAIN_BRANCH} and tags from ${REMOTE}..."
    git fetch "$REMOTE" "$MAIN_BRANCH" --tags --prune

    if [[ "$(git branch --show-current)" != "$MAIN_BRANCH" ]]; then
        log "Switching to ${MAIN_BRANCH}..."
        git switch "$MAIN_BRANCH"
    fi

    git pull --ff-only "$REMOTE" "$MAIN_BRANCH"

    [[ "$(git rev-parse "$MAIN_BRANCH")" == "$(git rev-parse "${REMOTE}/${MAIN_BRANCH}")" ]] ||
        die "Local ${MAIN_BRANCH} does not match ${REMOTE}/${MAIN_BRANCH}."
}


# ==============================================================================
# 5. VERSION: CALCULATE THE NEXT ONE AND WRITE IT INTO THE PROJECT
# ==============================================================================

# Reads the latest vX.Y.Z tag and sets VERSION and TAG to the next one.
calculate_next_version() {
    local major minor patch

    LATEST_TAG="$(
        git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname |
        grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' |
        head -n 1 || true
    )"

    if [[ -z "$LATEST_TAG" ]]; then
        LATEST_TAG="v0.0.0"
        warning "No version tag found; starting from ${LATEST_TAG}."
    fi

    IFS='.' read -r major minor patch <<< "${LATEST_TAG#v}"

    if [[ "$NEW_MAJOR" == true ]]; then
        VERSION="$((major + 1)).0.0"
    else
        VERSION="${major}.$((minor + 1)).0"
    fi
    TAG="v${VERSION}"

    log "Previous version: ${LATEST_TAG}"
    log "Next version:     ${TAG}"
}

# Fails if the tag or release for the next version already exists.
check_tag_is_free() {
    git rev-parse "$TAG" >/dev/null 2>&1 &&
        die "Tag already exists locally: ${TAG}"

    git ls-remote --exit-code --tags "$REMOTE" "refs/tags/${TAG}" >/dev/null 2>&1 &&
        die "Tag already exists on ${REMOTE}: ${TAG}"

    gh release view "$TAG" >/dev/null 2>&1 &&
        die "A GitHub Release already exists for ${TAG}."

    return 0
}

# Sets PBXPROJ_PATH to the project.pbxproj that holds the version.
# Derived from --project; with a workspace, the repo must contain exactly one.
locate_pbxproj() {
    local found count

    if [[ -n "$PROJECT_PATH" ]]; then
        PBXPROJ_PATH="${PROJECT_PATH%/}/project.pbxproj"
    else
        found="$(
            find . -maxdepth 3 -type f -path '*.xcodeproj/project.pbxproj' \
                ! -path './Pods/*' ! -path '*/.build/*' ! -path '*/SourcePackages/*'
        )"
        count="$(printf '%s\n' "$found" | grep -c . || true)"
        [[ "$count" -eq 1 ]] ||
            die "Found ${count} project.pbxproj files. Use --project, or --skip-version-bump."
        PBXPROJ_PATH="${found#./}"
    fi

    [[ -f "$PBXPROJ_PATH" ]] || die "project.pbxproj not found: ${PBXPROJ_PATH}"
}

# Writes VERSION into MARKETING_VERSION and CURRENT_PROJECT_VERSION (every
# build configuration, every target) and commits it locally.
# The commit is pushed later by push_version_commit(); until then it is rolled
# back automatically on failure or --dry-run.
apply_version_bump() {
    if [[ "$SKIP_VERSION_BUMP" == true ]]; then
        warning "Version bump skipped: the project keeps its current MARKETING_VERSION."
        return 0
    fi

    locate_pbxproj
    log "Writing version ${VERSION} into ${PBXPROJ_PATH}..."

    grep -qE 'MARKETING_VERSION = ' "$PBXPROJ_PATH" ||
        die "No MARKETING_VERSION in ${PBXPROJ_PATH}."

    sed -i '' -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = ${VERSION};/g" "$PBXPROJ_PATH"
    sed -i '' -E "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = ${VERSION};/g" "$PBXPROJ_PATH"

    # Every MARKETING_VERSION line must now carry the new version.
    if grep -E 'MARKETING_VERSION = ' "$PBXPROJ_PATH" | grep -qvF "MARKETING_VERSION = ${VERSION};"; then
        git checkout -- "$PBXPROJ_PATH"
        die "Some MARKETING_VERSION entries were not updated to ${VERSION}."
    fi

    if git diff --quiet -- "$PBXPROJ_PATH"; then
        log "Project is already at ${VERSION}; no version commit needed."
        return 0
    fi

    PRE_BUMP_COMMIT="$(git rev-parse HEAD)"
    git add -- "$PBXPROJ_PATH"
    git commit -m "chore: bump version to ${VERSION}" >/dev/null
    VERSION_BUMP_COMMITTED=true

    log "Created local commit: chore: bump version to ${VERSION}"
}

# Pushes the version commit to the main branch. Called only after the build
# and every validation succeeded, right before the tag is created.
push_version_commit() {
    [[ "$VERSION_BUMP_COMMITTED" == true ]] || return 0

    log "Pushing version commit to ${REMOTE}/${MAIN_BRANCH}..."

    git push "$REMOTE" "$MAIN_BRANCH" ||
        die "Cannot push the version commit (is ${MAIN_BRANCH} protected?). It will be rolled back."

    VERSION_BUMP_PUSHED=true
}


# ==============================================================================
# 6. BUILD: ARCHIVE, APP BUNDLE, INFO.PLIST CHECK
# ==============================================================================

prepare_directories() {
    ARCHIVE_PATH="${BUILD_DIR}/${SCHEME}-${VERSION}.xcarchive"
    EXPORT_PATH="${BUILD_DIR}/export-${VERSION}"

    rm -rf "$BUILD_DIR" "$DIST_DIR"
    mkdir -p "$BUILD_DIR" "$DIST_DIR" "$EXPORT_PATH"
}

# Delegates the archive build to build-in-release.sh.
build_archive() {
    local args=(
        --scheme "$SCHEME"
        --configuration "$CONFIGURATION"
        --archive-path "$ARCHIVE_PATH"
        --version "$VERSION"
    )

    if [[ -n "$WORKSPACE_PATH" ]]; then
        args+=(--workspace "$WORKSPACE_PATH")
    else
        args+=(--project "$PROJECT_PATH")
    fi

    log "Building archive..."
    "$(dirname -- "${BASH_SOURCE[0]}")/build-in-release.sh" "${args[@]}"
}

# Copies the built .app into DIST_DIR (via export if a plist was given).
# Sets APP_NAME, APP_PATH, APP_ZIP and DMG_PATH.
collect_app_bundle() {
    local source_app

    if [[ -n "$EXPORT_OPTIONS_PLIST" ]]; then
        [[ -f "$EXPORT_OPTIONS_PLIST" ]] || die "Export options plist not found: ${EXPORT_OPTIONS_PLIST}"

        log "Exporting archive..."
        xcodebuild -exportArchive \
            -archivePath "$ARCHIVE_PATH" \
            -exportPath "$EXPORT_PATH" \
            -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

        source_app="$(find "$EXPORT_PATH" -maxdepth 2 -type d -name '*.app' -print -quit)"
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
# This proves that the value written into project.pbxproj really ships.
verify_app_version() {
    local plist="${APP_PATH}/Contents/Info.plist" short bundle

    [[ -f "$plist" ]] || die "Info.plist not found: ${plist}"

    short="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")"
    bundle="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")"

    [[ "$short" == "$VERSION" ]]  || die "CFBundleShortVersionString is '${short}', expected '${VERSION}'."
    [[ "$bundle" == "$VERSION" ]] || die "CFBundleVersion is '${bundle}', expected '${VERSION}'."

    log "Verified app version: ${short} (build ${bundle})"
}


# ==============================================================================
# 7. PACKAGING: ZIP AND DMG
# ==============================================================================

package_zip() {
    log "Creating ${APP_ZIP}..."
    ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$APP_ZIP"
}

package_dmg() {
    local staging="${BUILD_DIR}/dmg-${VERSION}"

    log "Creating ${DMG_PATH}..."

    mkdir -p "$staging"
    ditto "$APP_PATH" "${staging}/${APP_NAME}.app"
    ln -s /Applications "${staging}/Applications"

    hdiutil create -volname "$APP_NAME" -srcfolder "$staging" -ov -format UDZO "$DMG_PATH"
    hdiutil verify "$DMG_PATH" >/dev/null
}

validate_artifacts() {
    local file
    for file in "$APP_ZIP" "$DMG_PATH"; do
        [[ -s "$file" ]] || die "Artifact missing or empty: ${file}"
        log "$(basename "$file"): $(stat -f '%z' "$file") bytes"
    done
}


# ==============================================================================
# 8. PUBLISH: TAG AND GITHUB RELEASE
# ==============================================================================

create_and_push_tag() {
    log "Creating annotated tag ${TAG} on ${MAIN_BRANCH}..."
    git tag -a "$TAG" -m "Release ${TAG}" "$MAIN_BRANCH"

    log "Pushing ${TAG} to ${REMOTE}..."
    if ! git push "$REMOTE" "refs/tags/${TAG}"; then
        git tag -d "$TAG" >/dev/null 2>&1 || true

        if [[ "$VERSION_BUMP_PUSHED" == true ]]; then
            warning "The version commit is already on ${REMOTE}/${MAIN_BRANCH}."
            warning "Re-running the script is safe: it will find the project already at ${VERSION}."
        fi

        die "Unable to push tag ${TAG}."
    fi
}

create_github_release() {
    log "Creating GitHub Release ${TAG}..."

    if ! gh release create "$TAG" \
        "${APP_ZIP}#${APP_NAME}.app.zip" \
        "${DMG_PATH}#${APP_NAME}.dmg" \
        --verify-tag --title "$TAG" --generate-notes
    then
        error "GitHub Release creation failed."
        warning "Tag ${TAG} is already pushed (intentionally not deleted)."
        printf '\nAfter fixing the problem, retry with:\n\n'
        printf 'gh release create %q %q %q --verify-tag --title %q --generate-notes\n' \
            "$TAG" "${APP_ZIP}#${APP_NAME}.app.zip" "${DMG_PATH}#${APP_NAME}.dmg" "$TAG"
        exit 1
    fi

    gh release view "$TAG" >/dev/null
}


# ==============================================================================
# 9. DRY-RUN REPORT AND FINAL SUMMARY
# ==============================================================================

# Simulates the pushes, prints what would happen, then exits.
# The EXIT trap rolls the version commit back.
finish_dry_run() {
    log "Simulating the tag push..."
    git push --dry-run "$REMOTE" "${MAIN_BRANCH}:refs/tags/${TAG}" ||
        die "The simulated tag push failed."

    if [[ "$VERSION_BUMP_COMMITTED" == true ]]; then
        log "Simulating the version commit push..."
        git push --dry-run "$REMOTE" "${MAIN_BRANCH}:${MAIN_BRANCH}" ||
            die "The simulated push of the version commit failed."
    fi

    printf '\n'
    success "Dry run completed successfully."
    printf '\n  Repository: %s\n  Version:    %s (tag %s)\n  App ZIP:    %s\n  DMG:        %s\n\n' \
        "$REPOSITORY_NAME" "$VERSION" "$TAG" "$APP_ZIP" "$DMG_PATH"

    warning "Nothing was pushed, tagged or released."
    [[ "$VERSION_BUMP_COMMITTED" != true ]] ||
        warning "The version commit is being rolled back."

    exit 0
}

print_summary() {
    success "Release ${TAG} completed successfully."
    printf '\n  Repository: %s\n  Tag:        %s\n  App ZIP:    %s\n  DMG:        %s\n  Release:    %s\n' \
        "$REPOSITORY_NAME" "$TAG" "$APP_ZIP" "$DMG_PATH" \
        "$(gh release view "$TAG" --json url --jq '.url')"

    [[ "$VERSION_BUMP_PUSHED" != true ]] ||
        printf '  Version:    %s (committed to %s)\n' "$VERSION" "$MAIN_BRANCH"

    printf '\nNext: publish the Sparkle update feed with ./sparkle-appcast.sh\n'

    return 0
}


# ==============================================================================
# 10. MAIN: THE WHOLE FLOW, IN ORDER
# ==============================================================================

main() {
    # Setup and pre-flight checks
    parse_args "$@"
    validate_args
    require_tools
    check_git_state
    check_github_access
    resolve_xcode_container
    verify_scheme
    sync_main_branch

    # Version
    calculate_next_version
    check_tag_is_free
    apply_version_bump            # local commit, rolled back on failure

    # Build and package
    prepare_directories
    build_archive
    collect_app_bundle
    verify_app_version
    package_zip
    package_dmg
    validate_artifacts

    # --dry-run ends here (and rolls back)
    if [[ "$DRY_RUN" == true ]]; then
        finish_dry_run
    fi

    # Publish, in this order: version commit -> tag -> release
    push_version_commit
    create_and_push_tag
    create_github_release

    print_summary
}

main "$@"
