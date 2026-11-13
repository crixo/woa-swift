#!/usr/bin/env bash
# ==============================================================================
# commit-and-tag.sh   (step 5)
#
# Creates ONE local commit containing the version bump (project.pbxproj) and
# the signed appcast.xml, then tags that commit with vX.Y.Z.
# This is what makes the tag include appcast.xml.
#
# Everything stays local: nothing is pushed. The tag is pushed by
# publish-github-release.sh and the commit reaches main in publish-appcast.sh.
#
# Only project.pbxproj and appcast.xml may have changed; any other modified
# tracked file stops the script.
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release-common.sh
source "${SCRIPT_DIR}/release-common.sh"
trap 'handle_error "$LINENO"' ERR

VERSION=""
DIST_DIR="dist"
APPCAST_PATH="appcast.xml"
MAIN_BRANCH="main"
TAG=""

show_help() {
    cat <<'HELP'
Usage: ./commit-and-tag.sh [options]

  --version <x.y.z>      Release version (default: from the zip in --dist-dir,
                         else the latest vX.Y.Z tag).
  --dist-dir <path>      Used only to detect the version (default: dist).
  --appcast-path <path>  appcast.xml location in the repo (default: appcast.xml).
  --main-branch <name>   Branch that must be checked out (default: main).
  -h, --help             Show this help.

Commits project.pbxproj + appcast.xml in one commit and tags it. Nothing is pushed.
HELP
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)       need_value "$1" "$#"; VERSION="$2";      shift 2 ;;
            --dist-dir)      need_value "$1" "$#"; DIST_DIR="$2";     shift 2 ;;
            --appcast-path)  need_value "$1" "$#"; APPCAST_PATH="$2"; shift 2 ;;
            --main-branch)   need_value "$1" "$#"; MAIN_BRANCH="$2";  shift 2 ;;
            -h|--help)       show_help; exit 0 ;;
            *) die "Unknown option: $1 (use --help)" ;;
        esac
    done
}

# Only project.pbxproj and the appcast may differ from HEAD.
check_only_expected_changes() {
    local line path

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        path="${line:3}"

        case "$path" in
            "$APPCAST_PATH"|*project.pbxproj) ;;
            *) die "Unexpected change in the working tree: ${path}" ;;
        esac
    done < <(git status --porcelain --untracked-files=no)
}

main() {
    parse_args "$@"
    require_tools git grep
    enter_repo_root
    require_branch "$MAIN_BRANCH"

    VERSION="$(resolve_version "$VERSION" "$DIST_DIR")"
    TAG="v${VERSION}"

    if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null 2>&1; then
        die "Tag already exists locally: ${TAG}"
    fi

    [[ -f "$APPCAST_PATH" ]] || die "${APPCAST_PATH} not found. Run sparkle-sign.sh first."
    appcast_has_version "$APPCAST_PATH" "$VERSION" ||
        die "${APPCAST_PATH} has no entry for ${VERSION}. Run sparkle-sign.sh first."

    check_only_expected_changes

    git add -u -- ':(glob)**/project.pbxproj'
    git add -- "$APPCAST_PATH"

    if git diff --cached --quiet; then
        die "Nothing to commit."
    fi

    log "Committing version ${VERSION} and ${APPCAST_PATH}..."
    git commit -q -m "chore: release ${TAG}"

    log "Creating annotated tag ${TAG} on the new commit..."
    git tag -a "$TAG" -m "Release ${TAG}"

    # The tag must really contain the appcast entry.
    appcast_has_version <(git show "${TAG}:${APPCAST_PATH}") "$VERSION" ||
        die "Tag ${TAG} does not contain ${APPCAST_PATH} with version ${VERSION}."

    success "Created commit $(git rev-parse --short HEAD) tagged ${TAG} (local only)."
}

main "$@"
