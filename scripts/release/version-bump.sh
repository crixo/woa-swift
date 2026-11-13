#!/usr/bin/env bash
# ==============================================================================
# version-bump.sh   (step 1)
#
# Calculates the next release version and writes it into project.pbxproj
# (MARKETING_VERSION and CURRENT_PROJECT_VERSION, every target/configuration).
#
# It only edits the working tree: nothing is committed here. The version change
# is committed together with appcast.xml by commit-and-tag.sh, so the tag
# contains both.
#
# The next version comes from the latest vX.Y.Z git tag:
#     minor bump (default)   v1.4.3 -> 1.5.0
#     --new-major            v1.4.3 -> 2.0.0
#     --version X.Y.Z        use exactly this version
#
# STDOUT: the version, and nothing else (logs go to stderr), so it can be
# captured:   VERSION="$(./version-bump.sh --project src/App.xcodeproj)"
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release-common.sh
source "${SCRIPT_DIR}/release-common.sh"
trap 'handle_error "$LINENO"' ERR

PROJECT_PATH=""
WORKSPACE_PATH=""
PBXPROJ_PATH=""
VERSION=""
TAG=""
NEW_MAJOR=false
NO_WRITE=false
REMOTE="origin"

show_help() {
    cat <<'HELP'
Usage: ./version-bump.sh (--project <path> | --workspace <path> | --pbxproj <path>) [options]

  --project <path>     Path to the .xcodeproj (project.pbxproj is derived).
  --workspace <path>   Path to the .xcworkspace; the repository must then
                       contain exactly one project.pbxproj (or use --pbxproj).
  --pbxproj <path>     Path to the project.pbxproj to edit.
  --version <x.y.z>    Use this version instead of calculating it.
  --new-major          Bump the major version instead of the minor one.
  --no-write           Calculate and print the version, do not edit any file.
  --remote <name>      Git remote used to check the tag is free (default: origin).
  -h, --help           Show this help.

Prints the version on stdout. Nothing is committed.
HELP
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --project)    need_value "$1" "$#"; PROJECT_PATH="$2";   shift 2 ;;
            --workspace)  need_value "$1" "$#"; WORKSPACE_PATH="$2"; shift 2 ;;
            --pbxproj)    need_value "$1" "$#"; PBXPROJ_PATH="$2";   shift 2 ;;
            --version)    need_value "$1" "$#"; VERSION="${2#v}";    shift 2 ;;
            --remote)     need_value "$1" "$#"; REMOTE="$2";         shift 2 ;;
            --new-major)  NEW_MAJOR=true; shift ;;
            --no-write)   NO_WRITE=true;  shift ;;
            -h|--help)    show_help; exit 0 ;;
            *) die "Unknown option: $1 (use --help)" ;;
        esac
    done

    if [[ "$NO_WRITE" == false &&
          -z "$PROJECT_PATH" && -z "$WORKSPACE_PATH" && -z "$PBXPROJ_PATH" ]]; then
        die "Pass --project, --workspace or --pbxproj (or --no-write)."
    fi
}

# Sets VERSION and TAG.
resolve_next_version() {
    local latest_tag major minor patch

    if [[ -z "$VERSION" ]]; then
        latest_tag="$(latest_version_tag)"

        if [[ -z "$latest_tag" ]]; then
            latest_tag="v0.0.0"
            warning "No version tag found; starting from ${latest_tag}."
        fi

        IFS='.' read -r major minor patch <<< "${latest_tag#v}"

        if [[ "$NEW_MAJOR" == true ]]; then
            VERSION="$((major + 1)).0.0"
        else
            VERSION="${major}.$((minor + 1)).0"
        fi

        log "Previous version: ${latest_tag}"
    fi

    [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
        die "Version '${VERSION}' is not in the form X.Y.Z."

    TAG="v${VERSION}"
    log "Next version:     ${TAG}"
}

# The next version must not be taken already.
check_tag_is_free() {
    if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null 2>&1; then
        die "Tag already exists locally: ${TAG}"
    fi

    if git ls-remote --exit-code --tags "$REMOTE" "refs/tags/${TAG}" >/dev/null 2>&1; then
        die "Tag already exists on ${REMOTE}: ${TAG}"
    fi

    if command -v gh >/dev/null 2>&1 && gh release view "$TAG" >/dev/null 2>&1; then
        die "A GitHub Release already exists for ${TAG}."
    fi
}

# Sets PBXPROJ_PATH.
locate_pbxproj() {
    local found count

    if [[ -z "$PBXPROJ_PATH" ]]; then
        if [[ -n "$PROJECT_PATH" ]]; then
            PBXPROJ_PATH="${PROJECT_PATH%/}/project.pbxproj"
        else
            found="$(
                find . -maxdepth 3 -type f -path '*.xcodeproj/project.pbxproj' \
                    ! -path './Pods/*' ! -path '*/.build/*' ! -path '*/SourcePackages/*'
            )"
            count="$(printf '%s\n' "$found" | grep -c . || true)"
            [[ "$count" -eq 1 ]] ||
                die "Found ${count} project.pbxproj files. Use --project or --pbxproj."
            PBXPROJ_PATH="${found#./}"
        fi
    fi

    [[ -f "$PBXPROJ_PATH" ]] || die "project.pbxproj not found: ${PBXPROJ_PATH}"
}

write_version() {
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
}

main() {
    parse_args "$@"
    require_tools git sed grep find
    enter_repo_root

    resolve_next_version
    check_tag_is_free

    if [[ "$NO_WRITE" == true ]]; then
        warning "--no-write: project.pbxproj is left untouched."
    else
        locate_pbxproj
        write_version
    fi

    # The only thing printed on stdout.
    printf '%s\n' "$VERSION"
}

main "$@"
