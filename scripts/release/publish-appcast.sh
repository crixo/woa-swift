#!/usr/bin/env bash
# ==============================================================================
# publish-appcast.sh   (step 7, the go-live step)
#
# Pushes the tagged release commit to main. Because that commit contains
# appcast.xml, this is the moment installed apps start seeing the update
# (the feed is read from main).
#
# Before pushing it verifies that:
#   - the tag exists and its commit contains appcast.xml with this version
#   - the GitHub Release exists and has the zip asset the appcast points to
#   - main can be fast-forwarded to the tagged commit
#
# It pushes "<tag commit>:refs/heads/main", so it works from any checkout that
# has the tag. Safe to re-run: if main already contains the commit it stops.
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release-common.sh
source "${SCRIPT_DIR}/release-common.sh"
trap 'handle_error "$LINENO"' ERR

VERSION=""
DIST_DIR="dist"
REPOSITORY_NAME=""
REMOTE="origin"
MAIN_BRANCH="main"
APPCAST_PATH="appcast.xml"
DRY_RUN=false

TAG=""
TAG_COMMIT=""

show_help() {
    cat <<'HELP'
Usage: ./publish-appcast.sh [options]

  --version <x.y.z>       Release version (default: from the zip in --dist-dir,
                          else the latest vX.Y.Z tag).
  --dist-dir <path>       Used only to detect the version (default: dist).
  --repository <o/name>   GitHub repository (default: detected with gh).
  --remote <name>         Git remote (default: origin).
  --main-branch <name>    Branch that holds appcast.xml (default: main).
  --appcast-path <path>   appcast.xml location in the repo (default: appcast.xml).
  --dry-run               Run every check and simulate the push.
                          A missing GitHub Release only warns.
  -h, --help              Show this help.
HELP
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)       need_value "$1" "$#"; VERSION="$2";         shift 2 ;;
            --dist-dir)      need_value "$1" "$#"; DIST_DIR="$2";        shift 2 ;;
            --repository)    need_value "$1" "$#"; REPOSITORY_NAME="$2"; shift 2 ;;
            --remote)        need_value "$1" "$#"; REMOTE="$2";          shift 2 ;;
            --main-branch)   need_value "$1" "$#"; MAIN_BRANCH="$2";     shift 2 ;;
            --appcast-path)  need_value "$1" "$#"; APPCAST_PATH="$2";    shift 2 ;;
            --dry-run)       DRY_RUN=true; shift ;;
            -h|--help)       show_help; exit 0 ;;
            *) die "Unknown option: $1 (use --help)" ;;
        esac
    done
}

# The tag must exist and its commit must contain the appcast entry.
verify_tag() {
    if ! git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null 2>&1; then
        die "Tag ${TAG} does not exist locally. Run commit-and-tag.sh first."
    fi

    TAG_COMMIT="$(git rev-parse "${TAG}^{commit}")"

    appcast_has_version <(git show "${TAG}:${APPCAST_PATH}") "$VERSION" ||
        die "Tag ${TAG} does not contain ${APPCAST_PATH} with version ${VERSION}."

    log "Tag ${TAG} (${TAG_COMMIT:0:7}) contains ${APPCAST_PATH} with version ${VERSION}."
}

# The appcast points apps at the zip on the GitHub Release; publishing it
# before the asset exists would break updates.
verify_release_asset() {
    local assets asset problem=""

    log "Verifying the GitHub Release ${TAG} and its zip asset..."

    if ! assets="$(gh release view "$TAG" --repo "$REPOSITORY_NAME" --json assets --jq '.assets[].name' 2>/dev/null)"; then
        problem="GitHub Release ${TAG} was not found."
    else
        asset="$(grep -E -- "-${VERSION//./\\.}\\.app\\.zip\$" <<<"$assets" | head -n 1 || true)"
        [[ -n "$asset" ]] || problem="No *-${VERSION}.app.zip asset is attached to Release ${TAG}."
    fi

    if [[ -n "$problem" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            warning "${problem}"
            warning "Expected when rehearsing before the Release exists; a real run would stop here."
            return 0
        fi
        die "${problem} Publishing the appcast now would point apps at a missing file."
    fi

    # Best-effort reachability check; a private repository fails here by design.
    if command -v curl >/dev/null 2>&1; then
        if ! curl --fail --silent --location --range 0-0 --output /dev/null \
            "https://github.com/${REPOSITORY_NAME}/releases/download/${TAG}/${asset}"
        then
            warning "The asset download URL did not answer successfully."
            warning "Sparkle needs it to be publicly downloadable (public repository)."
        fi
    fi
}

main() {
    parse_args "$@"
    require_tools git gh grep
    enter_repo_root

    gh auth status >/dev/null 2>&1 || die "GitHub CLI not authenticated. Run: gh auth login"

    VERSION="$(resolve_version "$VERSION" "$DIST_DIR")"
    TAG="v${VERSION}"

    if [[ -z "$REPOSITORY_NAME" ]]; then
        REPOSITORY_NAME="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
    fi
    [[ -n "$REPOSITORY_NAME" ]] || die "Unable to determine the GitHub repository."

    verify_tag
    verify_release_asset

    git fetch "$REMOTE" "$MAIN_BRANCH"

    if git merge-base --is-ancestor "$TAG_COMMIT" "${REMOTE}/${MAIN_BRANCH}"; then
        success "${REMOTE}/${MAIN_BRANCH} already contains ${TAG}: nothing to publish."
        exit 0
    fi

    git merge-base --is-ancestor "${REMOTE}/${MAIN_BRANCH}" "$TAG_COMMIT" ||
        die "${REMOTE}/${MAIN_BRANCH} has moved since ${TAG} was created; it cannot be fast-forwarded to the tagged commit."

    if [[ "$DRY_RUN" == true ]]; then
        log "Simulating the push of ${TAG} to ${REMOTE}/${MAIN_BRANCH}..."
        git push --dry-run "$REMOTE" "${TAG_COMMIT}:refs/heads/${MAIN_BRANCH}" ||
            die "The simulated push failed."
        warning "Nothing was pushed."
        return 0
    fi

    log "Pushing ${TAG} to ${REMOTE}/${MAIN_BRANCH}..."
    if ! git push "$REMOTE" "${TAG_COMMIT}:refs/heads/${MAIN_BRANCH}"; then
        error "Pushing to ${MAIN_BRANCH} failed (is it protected?)."
        warning "The tag and the Release are published, but installed apps will not see ${TAG}."
        warning "After resolving the problem, re-run: ./publish-appcast.sh --version ${VERSION}"
        exit 1
    fi

    success "Appcast for ${TAG} is live on ${REMOTE}/${MAIN_BRANCH}."
    printf '\n  Feed URL: https://raw.githubusercontent.com/%s/%s/%s\n\n' \
        "$REPOSITORY_NAME" "$MAIN_BRANCH" "$APPCAST_PATH" >&2
    warning "raw.githubusercontent.com caches files for a few minutes before the new appcast is visible."
}

main "$@"
