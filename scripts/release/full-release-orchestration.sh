#!/usr/bin/env bash
# ==============================================================================
# full-release-orchestration.sh
#
# Runs the whole release by calling the step scripts, in this order:
#
#   0. preflight-check.sh          tools, clean git, GitHub access, scheme
#   1. version-bump.sh             next version -> project.pbxproj (working tree)
#   2. build-in-release.sh         xcodebuild archive
#   3. package-artifacts.sh        .app, .app.zip, .dmg
#   4. sparkle-sign.sh             sign the zip, update appcast.xml (working tree)
#   5. commit-and-tag.sh           ONE commit: version + appcast.xml, then the tag
#   6. publish-github-release.sh   push the tag, create the Release with assets
#   7. publish-appcast.sh          push the commit to main (the feed goes live)
#
# Each step is a separate script and can be run on its own. This script only
# decides the order, forwards options, and undoes the local changes if a step
# fails before the tag has been pushed.
#
# Why this order: the tag must contain appcast.xml, and appcast.xml needs the
# signature of the final zip. The zip is therefore built first, signed, and only
# then committed and tagged. The commit reaches main last, so the feed never
# points at a Release that does not exist yet.
#
# USAGE
#   Rehearsal (builds everything, publishes nothing, rolls back):
#     ./scripts/release/full-release-orchestration.sh --scheme WOA --project src/WOA.xcodeproj --dry-run
#   Real release:
#     ./scripts/release/full-release-orchestration.sh --scheme WOA --project src/WOA.xcodeproj
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release-common.sh
source "${SCRIPT_DIR}/release-common.sh"
trap 'handle_error "$LINENO"' ERR

# --- Options -----------------------------------------------------------------
SCHEME=""
PROJECT_PATH=""
WORKSPACE_PATH=""
APP_NAME=""
EXPORT_OPTIONS_PLIST=""
CONFIGURATION="Release"
MAIN_BRANCH="main"
REMOTE="origin"
BUILD_DIR="build"
DIST_DIR="dist"
APPCAST_PATH="appcast.xml"
VERSION_OVERRIDE=""
NEW_MAJOR=false
SKIP_VERSION_BUMP=false
DRY_RUN=false
SPARKLE_BIN="${SPARKLE_BIN:-}"
ED_KEY_FILE=""
FEED_URL=""
REPOSITORY_NAME=""

# --- State -------------------------------------------------------------------
VERSION=""
TAG=""
ARCHIVE_PATH=""
PRE_HEAD=""          # set once the pre-flight passed: the commit to roll back to

show_help() {
    cat <<'HELP'
Usage: ./full-release-orchestration.sh --scheme <name> (--project <path> | --workspace <path>) [options]

Xcode
  --scheme <name>               Shared Xcode scheme (required).
  --project <path>              Path to the .xcodeproj.
  --workspace <path>            Path to the .xcworkspace (exclusive with --project).
  --app-name <name>             App name without ".app" (default: detected).
  --export-options-plist <path> Export the archive with this plist.
  --configuration <name>        Build configuration (default: Release).

Git / output
  --main-branch <name>          Release branch (default: main).
  --remote <name>               Git remote (default: origin).
  --build-dir <path>            Intermediate files (default: build).
  --dist-dir <path>             Final artifacts (default: dist).
  --appcast-path <path>         appcast.xml location (default: appcast.xml).

Version
  --version <x.y.z>             Use this version instead of calculating it.
  --new-major                   Bump the major version (1.4.3 -> 2.0.0).
  --skip-version-bump           Do not write the version into project.pbxproj
                                (the build still gets it as a build setting).

Sparkle
  --sparkle-bin <dir>           Folder containing generate_appcast.
  --ed-key-file <path>          Exported EdDSA private key (default: Keychain).
  --feed-url <url>              Expected SUFeedURL.
  --repository <owner/name>     GitHub repository (default: detected).

Execution
  --dry-run                     Do everything locally, simulate the pushes,
                                publish nothing and roll back.
  -h, --help                    Show this help.
HELP
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
            --appcast-path)          need_value "$1" "$#"; APPCAST_PATH="$2";         shift 2 ;;
            --version)               need_value "$1" "$#"; VERSION_OVERRIDE="${2#v}"; shift 2 ;;
            --sparkle-bin)           need_value "$1" "$#"; SPARKLE_BIN="$2";          shift 2 ;;
            --ed-key-file)           need_value "$1" "$#"; ED_KEY_FILE="$2";          shift 2 ;;
            --feed-url)              need_value "$1" "$#"; FEED_URL="$2";             shift 2 ;;
            --repository)            need_value "$1" "$#"; REPOSITORY_NAME="$2";      shift 2 ;;
            --new-major)             NEW_MAJOR=true;         shift ;;
            --skip-version-bump)     SKIP_VERSION_BUMP=true; shift ;;
            --dry-run)               DRY_RUN=true;           shift ;;
            -h|--help)               show_help; exit 0 ;;
            *) die "Unknown option: $1 (use --help)" ;;
        esac
    done

    [[ -n "$SCHEME" ]] || die "--scheme is required."

    if [[ -n "$WORKSPACE_PATH" && -n "$PROJECT_PATH" ]]; then
        die "--workspace and --project cannot be used together."
    fi
    if [[ -z "$WORKSPACE_PATH" && -z "$PROJECT_PATH" ]]; then
        die "Either --project or --workspace must be provided."
    fi
}

# --- Rollback ----------------------------------------------------------------

undo_local_changes() {
    warning "Rolling back the local changes (version bump, appcast, commit, tag)..."

    if [[ -n "$TAG" ]]; then
        git tag -d "$TAG" >/dev/null 2>&1 || true
    fi

    if git reset --hard "$PRE_HEAD" >/dev/null 2>&1; then
        # appcast.xml may be a new, untracked file: remove it too.
        git clean -fdq -- "$APPCAST_PATH" >/dev/null 2>&1 || true
        warning "Repository restored to ${PRE_HEAD:0:7}."
    else
        warning "Automatic rollback failed. Run manually: git reset --hard ${PRE_HEAD}"
    fi
}

# Runs on every exit.
#   - before the pre-flight passed: nothing to undo
#   - tag already on the remote:    never undo, explain how to resume
#   - otherwise (failure or dry run): undo the local changes
on_exit() {
    local exit_code=$? remote_status=0
    trap - EXIT

    [[ -n "$PRE_HEAD" ]] || exit "$exit_code"

    if [[ -n "$TAG" ]]; then
        git ls-remote --exit-code --tags "$REMOTE" "refs/tags/${TAG}" >/dev/null 2>&1 || remote_status=$?

        if [[ "$remote_status" -eq 0 ]]; then
            if [[ "$exit_code" -ne 0 ]]; then
                warning "Tag ${TAG} is already on ${REMOTE}: nothing was rolled back."
                warning "Resume with the failed step:"
                warning "  ./publish-github-release.sh --version ${VERSION}   (if the Release is missing)"
                warning "  ./publish-appcast.sh --version ${VERSION}          (to put the update feed live)"
            fi
            exit "$exit_code"
        fi

        if [[ "$remote_status" -ne 2 ]]; then
            warning "Cannot reach ${REMOTE} to see whether ${TAG} was pushed: local state left untouched."
            exit "$exit_code"
        fi
    fi

    if [[ "$exit_code" -ne 0 || "$DRY_RUN" == true ]]; then
        undo_local_changes
    fi

    exit "$exit_code"
}
trap on_exit EXIT

# --- Steps -------------------------------------------------------------------

step() {
    printf '\n\033[1;35m━━ %s\033[0m\n' "$1" >&2
}

main() {
    local container_args

    parse_args "$@"

    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not inside a Git repository."
    cd "$(git rev-parse --show-toplevel)"

    if [[ "$DRY_RUN" == true ]]; then
        warning "DRY-RUN: everything is built and checked, nothing is published, local changes are rolled back."
    fi

    if [[ -n "$WORKSPACE_PATH" ]]; then
        container_args=(--workspace "$WORKSPACE_PATH")
    else
        container_args=(--project "$PROJECT_PATH")
    fi

    # ---- 0. Pre-flight ----
    step "0/7 Pre-flight checks"
    local preflight_args=(--scheme "$SCHEME" --main-branch "$MAIN_BRANCH" --remote "$REMOTE")
    if [[ -n "$SPARKLE_BIN" ]]; then
        preflight_args+=(--sparkle-bin "$SPARKLE_BIN")
    fi
    "${SCRIPT_DIR}/preflight-check.sh" "${container_args[@]}" "${preflight_args[@]}"

    # From here on the repository is clean: a rollback target exists.
    PRE_HEAD="$(git rev-parse HEAD)"

    # ---- 1. Version ----
    step "1/7 Version"
    local bump_args=(--remote "$REMOTE")
    if [[ -n "$VERSION_OVERRIDE" ]]; then bump_args+=(--version "$VERSION_OVERRIDE"); fi
    if [[ "$NEW_MAJOR" == true ]];     then bump_args+=(--new-major); fi
    if [[ "$SKIP_VERSION_BUMP" == true ]]; then bump_args+=(--no-write); fi
    VERSION="$("${SCRIPT_DIR}/version-bump.sh" "${container_args[@]}" "${bump_args[@]}")"
    TAG="v${VERSION}"

    # ---- 2. Build ----
    step "2/7 Build ${SCHEME} ${VERSION}"
    ARCHIVE_PATH="${BUILD_DIR}/archive/${SCHEME}-${VERSION}.xcarchive"
    "${SCRIPT_DIR}/build-in-release.sh" \
        "${container_args[@]}" \
        --scheme "$SCHEME" \
        --configuration "$CONFIGURATION" \
        --archive-path "$ARCHIVE_PATH" \
        --version "$VERSION"

    # ---- 3. Package ----
    step "3/7 Package"
    local package_args=(--archive-path "$ARCHIVE_PATH" --version "$VERSION" --build-dir "$BUILD_DIR" --dist-dir "$DIST_DIR")
    if [[ -n "$APP_NAME" ]];             then package_args+=(--app-name "$APP_NAME"); fi
    if [[ -n "$EXPORT_OPTIONS_PLIST" ]]; then package_args+=(--export-options-plist "$EXPORT_OPTIONS_PLIST"); fi
    "${SCRIPT_DIR}/package-artifacts.sh" "${package_args[@]}"

    # ---- 4. Sparkle ----
    step "4/7 Sparkle signing"
    local sparkle_args=(--version "$VERSION" --dist-dir "$DIST_DIR" --build-dir "$BUILD_DIR" --main-branch "$MAIN_BRANCH" --appcast-path "$APPCAST_PATH")
    if [[ -n "$SPARKLE_BIN" ]];      then sparkle_args+=(--sparkle-bin "$SPARKLE_BIN"); fi
    if [[ -n "$ED_KEY_FILE" ]];      then sparkle_args+=(--ed-key-file "$ED_KEY_FILE"); fi
    if [[ -n "$FEED_URL" ]];         then sparkle_args+=(--feed-url "$FEED_URL"); fi
    if [[ -n "$REPOSITORY_NAME" ]];  then sparkle_args+=(--repository "$REPOSITORY_NAME"); fi
    "${SCRIPT_DIR}/sparkle-sign.sh" "${sparkle_args[@]}"

    # ---- 5. Commit and tag ----
    step "5/7 Commit and tag"
    "${SCRIPT_DIR}/commit-and-tag.sh" \
        --version "$VERSION" \
        --dist-dir "$DIST_DIR" \
        --appcast-path "$APPCAST_PATH" \
        --main-branch "$MAIN_BRANCH"

    # ---- 6. GitHub Release ----
    step "6/7 GitHub Release"
    local release_args=(--version "$VERSION" --dist-dir "$DIST_DIR" --remote "$REMOTE")
    if [[ "$DRY_RUN" == true ]]; then release_args+=(--dry-run); fi
    "${SCRIPT_DIR}/publish-github-release.sh" "${release_args[@]}"

    # ---- 7. Go live ----
    step "7/7 Publish the appcast"
    local appcast_args=(--version "$VERSION" --dist-dir "$DIST_DIR" --remote "$REMOTE" --main-branch "$MAIN_BRANCH" --appcast-path "$APPCAST_PATH")
    if [[ -n "$REPOSITORY_NAME" ]]; then appcast_args+=(--repository "$REPOSITORY_NAME"); fi
    if [[ "$DRY_RUN" == true ]];    then appcast_args+=(--dry-run); fi
    "${SCRIPT_DIR}/publish-appcast.sh" "${appcast_args[@]}"

    if [[ "$DRY_RUN" == true ]]; then
        success "Dry run completed: version ${VERSION} (tag ${TAG}) would be released."
        warning "Nothing was pushed, tagged or released. Local changes are being rolled back."
    else
        success "Release ${TAG} completed."
    fi
}

main "$@"
