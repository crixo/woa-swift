#!/usr/bin/env bash
# ==============================================================================
# preflight-check.sh   (step 0)
#
# Verifies that a release can start. Changes nothing except fast-forwarding
# the local main branch to the remote one.
#
#   - required tools are installed (macOS)
#   - the repository is clean, on the main branch, and up to date with remote
#   - the GitHub CLI is authenticated and can publish releases
#   - the Xcode scheme exists and is shared
#   - warns if Sparkle's generate_appcast cannot be found yet
#   - the code-signing certificate exists in the Keychain (unless --sign no)
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release-common.sh
source "${SCRIPT_DIR}/release-common.sh"
trap 'handle_error "$LINENO"' ERR

SCHEME=""
PROJECT_PATH=""
WORKSPACE_PATH=""
MAIN_BRANCH="main"
REMOTE="origin"
SPARKLE_BIN="${SPARKLE_BIN:-}"
SIGN="yes"
SIGN_IDENTITY="$DEFAULT_SIGN_IDENTITY"

show_help() {
    cat <<'HELP'
Usage: ./preflight-check.sh --scheme <name> (--project <path> | --workspace <path>) [options]

  --scheme <name>        Shared Xcode scheme to build (required).
  --project <path>       Path to the .xcodeproj.
  --workspace <path>     Path to the .xcworkspace (exclusive with --project).
  --main-branch <name>   Release branch (default: main).
  --remote <name>        Git remote (default: origin).
  --sparkle-bin <dir>    Folder containing generate_appcast (only used for a warning).
  --sign <yes|no>        Check the code-signing certificate (default: yes).
  --sign-identity <name> Certificate name in the Keychain (default: CrixoDev).
  -h, --help             Show this help.
HELP
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --scheme)       need_value "$1" "$#"; SCHEME="$2";         shift 2 ;;
            --project)      need_value "$1" "$#"; PROJECT_PATH="$2";   shift 2 ;;
            --workspace)    need_value "$1" "$#"; WORKSPACE_PATH="$2"; shift 2 ;;
            --main-branch)  need_value "$1" "$#"; MAIN_BRANCH="$2";    shift 2 ;;
            --remote)       need_value "$1" "$#"; REMOTE="$2";         shift 2 ;;
            --sparkle-bin)  need_value "$1" "$#"; SPARKLE_BIN="$2";    shift 2 ;;
            --sign)         need_value "$1" "$#"; parse_yes_no SIGN "$1" "$2"; shift 2 ;;
            --sign-identity) need_value "$1" "$#"; SIGN_IDENTITY="$2"; shift 2 ;;
            -h|--help)      show_help; exit 0 ;;
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

check_git_state() {
    log "Checking the git state..."

    git remote get-url "$REMOTE" >/dev/null 2>&1 ||
        die "Git remote '${REMOTE}' is not configured."

    require_branch "$MAIN_BRANCH"

    [[ -z "$(git status --porcelain)" ]] ||
        die "Uncommitted changes found. Commit or stash them first."

    git fetch "$REMOTE" "$MAIN_BRANCH" --tags --prune
    git pull --ff-only "$REMOTE" "$MAIN_BRANCH"

    [[ "$(git rev-parse "$MAIN_BRANCH")" == "$(git rev-parse "${REMOTE}/${MAIN_BRANCH}")" ]] ||
        die "Local ${MAIN_BRANCH} does not match ${REMOTE}/${MAIN_BRANCH}."
}

check_github_access() {
    local repository permission

    log "Checking GitHub access..."

    gh auth status >/dev/null 2>&1 || die "GitHub CLI not authenticated. Run: gh auth login"

    repository="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
    [[ -n "$repository" ]] || die "Unable to determine the GitHub repository."

    permission="$(gh repo view --json viewerPermission --jq '.viewerPermission')"
    case "$permission" in
        ADMIN|MAINTAIN|WRITE) log "GitHub repository: ${repository} (${permission})" ;;
        *) die "GitHub permission '${permission:-unknown}' cannot publish releases." ;;
    esac
}

check_xcode_scheme() {
    local container_args

    if [[ -n "$WORKSPACE_PATH" ]]; then
        [[ -d "$WORKSPACE_PATH" ]] || die "Workspace not found: ${WORKSPACE_PATH}"
        container_args=(-workspace "$WORKSPACE_PATH")
    else
        [[ -d "$PROJECT_PATH" ]] || die "Project not found: ${PROJECT_PATH}"
        container_args=(-project "$PROJECT_PATH")
    fi

    log "Checking the Xcode scheme: ${SCHEME}"

    xcodebuild "${container_args[@]}" -scheme "$SCHEME" -showBuildSettings >/dev/null ||
        die "Scheme '${SCHEME}' is not available or not shared."
}

check_sparkle_tools() {
    if find_sparkle_tool generate_appcast >/dev/null 2>&1; then
        log "Sparkle generate_appcast found."
    else
        warning "generate_appcast not found yet (it is needed by sparkle-sign.sh)."
        warning "Use --sparkle-bin, set SPARKLE_BIN, or build the project once so SwiftPM fetches Sparkle."
    fi
}

# Fails now, not at step 3, if the signing certificate is missing.
check_signing_identity() {
    if [[ "$SIGN" != "yes" ]]; then
        warning "Code signing is disabled (--sign no): the app will not be signed with '${SIGN_IDENTITY}'."
        return 0
    fi

    log "Checking the code-signing certificate: ${SIGN_IDENTITY}"

    signing_identity_available "$SIGN_IDENTITY" ||
        die "Code-signing identity '${SIGN_IDENTITY}' not found in the Keychain (see: security find-identity -p codesigning). Use --sign-identity or --sign no."
}

main() {
    parse_args "$@"
    require_tools git gh xcodebuild hdiutil ditto sed grep find awk
    if [[ "$SIGN" == "yes" ]]; then require_tools codesign security xattr file; fi
    enter_repo_root
    check_git_state
    check_github_access
    check_xcode_scheme
    check_sparkle_tools
    check_signing_identity

    success "Pre-flight checks passed."
}

main "$@"
