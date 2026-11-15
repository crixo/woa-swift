#!/usr/bin/env bash
# ==============================================================================
# reset-to-previous-version.sh   (undo of step 1: version-bump.sh)
#
# version-bump.sh takes the current version from the latest vX.Y.Z git tag and
# writes the next one into project.pbxproj. This script goes back.
#
# The current version is read from both sources: the latest tag and the
# project files (MARKETING_VERSION).
#
#   In both cases appcast.xml is set to its content at the target tag, so the
#   entry added by sparkle-sign.sh for the reset version is gone.
#
#   Tag and project files MATCH     (tag v0.4.0, project 0.4.0)
#       -> reset to the previous tag (v0.3.0):
#          project.pbxproj is set to 0.3.0 and the tag v0.4.0 is deleted
#          (locally, and on the remote if it is there), so version-bump.sh
#          will calculate from v0.3.0. A GitHub Release for v0.4.0 is not
#          touched: if one exists, a warning says so.
#
#   Tag and project files DIFFER    (tag v0.4.0, project 0.5.0)
#       -> the tag wins, v0.4.0 is the version to reset to:
#          only project.pbxproj is set to 0.4.0. No tag is touched.
#
# --dry-run changes nothing (no tag, no project file) and describes the actions
# the script would perform without it.
#
# STDOUT: the original and the new current version. Logs go to stderr.
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../release/release-common.sh
source "${SCRIPT_DIR}/../release/release-common.sh"
trap 'handle_error "$LINENO"' ERR

PROJECT_PATH=""
WORKSPACE_PATH=""
PBXPROJ_PATH=""
DRY_RUN=false
REMOTE="origin"
APPCAST_PATH="appcast.xml"

show_help() {
    cat <<'HELP'
Usage: ./reset-to-previous-version.sh (--project <path> | --workspace <path> | --pbxproj <path>) [options]

  --project <path>     Path to the .xcodeproj (project.pbxproj is derived).
  --workspace <path>   Path to the .xcworkspace; the repository must then
                       contain exactly one project.pbxproj (or use --pbxproj).
  --pbxproj <path>     Path to the project.pbxproj to edit.
  --appcast-path <path>  appcast.xml location in the repo (default: appcast.xml).
  --dry-run            Change nothing, only describe what would be done.
  --remote <name>      Git remote the deleted tag is also removed from, if it
                       is there (default: origin).
  -h, --help           Show this help.

Tag and project files match -> go back to the previous tag (project files are
rewritten, the latest tag is deleted locally and on the remote).
Tag and project files differ -> the tag wins (only the project files are rewritten).
HELP
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --project)    need_value "$1" "$#"; PROJECT_PATH="$2";   shift 2 ;;
            --workspace)  need_value "$1" "$#"; WORKSPACE_PATH="$2"; shift 2 ;;
            --pbxproj)    need_value "$1" "$#"; PBXPROJ_PATH="$2";   shift 2 ;;
            --remote)     need_value "$1" "$#"; REMOTE="$2";         shift 2 ;;
            --appcast-path) need_value "$1" "$#"; APPCAST_PATH="$2"; shift 2 ;;
            --dry-run)    DRY_RUN=true; shift ;;
            -h|--help)    show_help; exit 0 ;;
            *) die "Unknown option: $1 (use --help)" ;;
        esac
    done

    if [[ -z "$PROJECT_PATH" && -z "$WORKSPACE_PATH" && -z "$PBXPROJ_PATH" ]]; then
        die "Pass --project, --workspace or --pbxproj."
    fi
}

# Sets PBXPROJ_PATH (same lookup as version-bump.sh).
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
    sed -i '' -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = ${1};/g" "$PBXPROJ_PATH"
    sed -i '' -E "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = ${1};/g" "$PBXPROJ_PATH"
}

tag_is_on_remote() {
    git ls-remote --exit-code --tags "$REMOTE" "refs/tags/${1}" >/dev/null 2>&1
}

# appcast.xml goes back to its content at the target tag: the entry of the
# version being reset disappears (and any uncommitted entry added by
# sparkle-sign.sh). If the tag has no appcast yet, the file is removed.
set_appcast_to_tag() {
    if git cat-file -e "${1}:${APPCAST_PATH}" 2>/dev/null; then
        git show "${1}:${APPCAST_PATH}" >"$APPCAST_PATH"
    else
        rm -f "$APPCAST_PATH"
    fi
}

release_exists() {
    command -v gh >/dev/null 2>&1 && gh release view "$1" >/dev/null 2>&1
}

say() {
    if [[ "$DRY_RUN" == true ]]; then
        log "[dry-run] would: $1"
    else
        log "$1"
    fi
}

main() {
    local latest previous target project_versions original

    parse_args "$@"
    require_tools git sed grep find tr
    enter_repo_root
    locate_pbxproj

    latest="$(latest_version_tag)"
    [[ -n "$latest" ]] || die "No vX.Y.Z tag found: nothing to reset."

    project_versions="$(
        grep -oE 'MARKETING_VERSION = [^;]+' "$PBXPROJ_PATH" |
            sed 's/MARKETING_VERSION = //' | sort -u || true
    )"
    [[ -n "$project_versions" ]] || die "No MARKETING_VERSION in ${PBXPROJ_PATH}."

    original="v$(printf '%s' "$project_versions" | tr '\n' ',')"

    if [[ "$project_versions" == "${latest#v}" ]]; then
        # Tag and project files match: go back to the previous tag.
        previous="$(
            git tag --list 'v*' --sort=-v:refname |
                grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' |
                grep -A1 -Fx "$latest" | sed -n 2p || true
        )"
        [[ -n "$previous" ]] ||
            die "No version tag before ${latest}: there is no previous version to go back to."

        target="$previous"

        # Project files
        say "write version ${target#v} into ${PBXPROJ_PATH}"
        if [[ "$DRY_RUN" == false ]]; then write_version "${target#v}"; fi

        say "set ${APPCAST_PATH} to its content at tag ${target}"
        if [[ "$DRY_RUN" == false ]]; then set_appcast_to_tag "$target"; fi

        # Tags
        if tag_is_on_remote "$latest"; then
            say "delete tag ${latest} on ${REMOTE}"
            if [[ "$DRY_RUN" == false ]]; then git push "$REMOTE" --delete "refs/tags/${latest}"; fi
        else
            say "change nothing on ${REMOTE} (tag ${latest} is not there)"
        fi

        say "delete local tag ${latest} (to undo: git update-ref refs/tags/${latest} $(git rev-parse "refs/tags/${latest}"))"
        if [[ "$DRY_RUN" == false ]]; then git tag -d "$latest" >/dev/null; fi

        # Releases: never touched, but version-bump.sh refuses a version that has one.
        if release_exists "$latest"; then
            say "leave the GitHub Release ${latest} untouched"
            warning "The GitHub Release ${latest} still exists: version-bump.sh will refuse to create ${latest} again until it is deleted:  gh release delete ${latest} --yes"
        else
            say "change no GitHub Release (none exists for ${latest})"
        fi
    else
        # Tag and project files differ: the tag wins.
        warning "Tag (${latest}) and project files (${original}) do not match: the tag wins."
        target="$latest"

        say "write version ${target#v} into ${PBXPROJ_PATH}"
        if [[ "$DRY_RUN" == false ]]; then write_version "${target#v}"; fi

        say "set ${APPCAST_PATH} to its content at tag ${target}"
        if [[ "$DRY_RUN" == false ]]; then set_appcast_to_tag "$target"; fi

        say "change no tag and no GitHub Release"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log "[dry-run] nothing was changed."
    else
        log "Done. version-bump.sh will now calculate from ${target}."
    fi

    printf 'original current: %s\n' "$original"
    if [[ "$DRY_RUN" == true ]]; then
        printf ' reset candidate: %s\n' "$target"
    else
        printf 'current: %s\n' "$target"
    fi
}

main "$@"
