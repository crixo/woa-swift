#!/usr/bin/env bash
# ==============================================================================
# publish-github-release.sh   (step 6)
#
# Pushes the release tag (created by commit-and-tag.sh) and creates the GitHub
# Release with the .app.zip and the .dmg attached.
#
# Safe to re-run: if the tag is already on the remote with the same content it
# is not pushed again. If the Release already exists the script stops.
#
# The commit behind the tag is NOT pushed to main here: that is the last step
# (publish-appcast.sh), so the update feed only goes live once the Release and
# its assets exist.
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release-common.sh
source "${SCRIPT_DIR}/release-common.sh"
trap 'handle_error "$LINENO"' ERR

VERSION=""
DIST_DIR="dist"
REMOTE="origin"
DRY_RUN=false

TAG=""
APP_ZIP=""
DMG_PATH=""
APP_NAME=""

show_help() {
    cat <<'HELP'
Usage: ./publish-github-release.sh [options]

  --version <x.y.z>   Release version (default: from the zip in --dist-dir,
                      else the latest vX.Y.Z tag).
  --dist-dir <path>   Where package-artifacts.sh left the files (default: dist).
  --remote <name>     Git remote (default: origin).
  --dry-run           Simulate the tag push and show the release command.
  -h, --help          Show this help.
HELP
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)   need_value "$1" "$#"; VERSION="$2";  shift 2 ;;
            --dist-dir)  need_value "$1" "$#"; DIST_DIR="$2"; shift 2 ;;
            --remote)    need_value "$1" "$#"; REMOTE="$2";   shift 2 ;;
            --dry-run)   DRY_RUN=true; shift ;;
            -h|--help)   show_help; exit 0 ;;
            *) die "Unknown option: $1 (use --help)" ;;
        esac
    done
}

# Pushes the tag unless the remote already has the identical one.
push_tag() {
    local local_sha remote_sha

    local_sha="$(git rev-parse "refs/tags/${TAG}")"
    remote_sha="$(git ls-remote --tags "$REMOTE" "refs/tags/${TAG}" | awk '{print $1}' | head -n 1 || true)"

    if [[ -n "$remote_sha" ]]; then
        [[ "$remote_sha" == "$local_sha" ]] ||
            die "Tag ${TAG} exists on ${REMOTE} but points somewhere else."
        log "Tag ${TAG} is already on ${REMOTE}."
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log "Simulating the push of ${TAG}..."
        git push --dry-run "$REMOTE" "refs/tags/${TAG}" ||
            die "The simulated tag push failed."
        return 0
    fi

    log "Pushing ${TAG} to ${REMOTE}..."
    git push "$REMOTE" "refs/tags/${TAG}" || die "Unable to push tag ${TAG}."
}

create_release() {
    if [[ "$DRY_RUN" == true ]]; then
        printf '\nCommand a real run would execute:\n\n' >&2
        printf 'gh release create %q %q %q --verify-tag --title %q --generate-notes\n\n' \
            "$TAG" "${APP_ZIP}#${APP_NAME}.app.zip" "${DMG_PATH}#${APP_NAME}.dmg" "$TAG" >&2
        warning "No tag was pushed and no Release was created."
        return 0
    fi

    log "Creating GitHub Release ${TAG}..."

    if ! gh release create "$TAG" \
        "${APP_ZIP}#${APP_NAME}.app.zip" \
        "${DMG_PATH}#${APP_NAME}.dmg" \
        --verify-tag --title "$TAG" --generate-notes
    then
        error "GitHub Release creation failed."
        warning "Tag ${TAG} is already pushed (intentionally not deleted)."
        warning "After fixing the problem, re-run: ./publish-github-release.sh --version ${VERSION}"
        exit 1
    fi

    success "GitHub Release ${TAG}: $(gh release view "$TAG" --json url --jq '.url')"
}

main() {
    local zip_name

    parse_args "$@"
    require_tools git gh awk find
    enter_repo_root

    gh auth status >/dev/null 2>&1 || die "GitHub CLI not authenticated. Run: gh auth login"

    VERSION="$(resolve_version "$VERSION" "$DIST_DIR")"
    TAG="v${VERSION}"

    if ! git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null 2>&1; then
        die "Tag ${TAG} does not exist locally. Run commit-and-tag.sh first."
    fi

    APP_ZIP="$(find_single_artifact "$DIST_DIR" "zip for version ${VERSION}" "--dist-dir" -type f -name "*-${VERSION}.app.zip")"
    DMG_PATH="$(find_single_artifact "$DIST_DIR" "dmg for version ${VERSION}" "--dist-dir" -type f -name "*-${VERSION}.dmg")"

    zip_name="$(basename -- "$APP_ZIP")"
    APP_NAME="${zip_name%-${VERSION}.app.zip}"

    if gh release view "$TAG" >/dev/null 2>&1; then
        die "A GitHub Release already exists for ${TAG}."
    fi

    push_tag
    create_release
}

main "$@"
