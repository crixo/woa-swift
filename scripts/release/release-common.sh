#!/usr/bin/env bash
# shellcheck shell=bash
# ==============================================================================
# release-common.sh
#
# Helpers shared by the release scripts. It is sourced, never executed:
#
#     source "${SCRIPT_DIR}/release-common.sh"
#
# Logs go to STDERR so that STDOUT stays free for machine-readable output
# (version-bump.sh prints the version on stdout).
#
# Compatible with the bash 3.2 that ships with macOS: no mapfile, no
# associative arrays, and optional arrays are never expanded when empty.
# ==============================================================================

SCRIPT_NAME="$(basename -- "$0")"

# --- Logging -----------------------------------------------------------------

log()     { printf '\033[1;34m[INFO]\033[0m %s\n'    "$*" >&2; }
success() { printf '\033[1;32m[SUCCESS]\033[0m %s\n' "$*" >&2; }
warning() { printf '\033[1;33m[WARNING]\033[0m %s\n' "$*" >&2; }
error()   { printf '\033[1;31m[ERROR]\033[0m %s\n'   "$*" >&2; }

die() {
    error "$*"
    exit 1
}

# Each script installs it with:  trap 'handle_error "$LINENO"' ERR
handle_error() {
    local exit_code=$?
    error "${SCRIPT_NAME} failed at line ${1:-unknown} with exit code ${exit_code}."
    exit "$exit_code"
}

# --- Argument helpers --------------------------------------------------------

# Fails if an option that needs a value was given without one.
need_value() {
    local option="$1" remaining="$2"
    [[ "$remaining" -ge 2 ]] || die "Missing value for ${option}"
}

# --- Environment helpers -----------------------------------------------------

# Usage: require_tools git gh ...   (also requires macOS)
require_tools() {
    local tool
    for tool in "$@"; do
        command -v "$tool" >/dev/null 2>&1 || die "Required command not found: ${tool}"
    done

    [[ "$(uname -s)" == "Darwin" ]] || die "This script must run on macOS."
}

# Moves to the repository root. Relative paths given to the scripts are
# therefore relative to the repository root.
enter_repo_root() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
        die "Not inside a Git repository."

    cd "$(git rev-parse --show-toplevel)"
}

require_branch() {
    local expected="$1" current
    current="$(git branch --show-current)"

    [[ "$current" == "$expected" ]] ||
        die "The current branch is '${current:-detached HEAD}', expected '${expected}'."
}

# --- Version helpers ---------------------------------------------------------

# Prints the latest vX.Y.Z tag (empty if there is none).
latest_version_tag() {
    git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname |
        grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' |
        head -n 1 || true
}

# Prints X.Y.Z taken from the single *-X.Y.Z.app.zip in the dist directory.
# Returns 1 if there is not exactly one.
version_from_dist() {
    local dist_dir="$1" zips count name

    zips="$(find "$dist_dir" -maxdepth 1 -type f -name '*-[0-9]*.[0-9]*.[0-9]*.app.zip' 2>/dev/null || true)"
    count="$(printf '%s\n' "$zips" | grep -c . || true)"
    [[ "$count" -eq 1 ]] || return 1

    name="$(basename -- "$zips")"
    [[ "$name" =~ -([0-9]+\.[0-9]+\.[0-9]+)\.app\.zip$ ]] || return 1

    printf '%s\n' "${BASH_REMATCH[1]}"
}

# Resolves the version a script works on. Priority:
#   1. the explicit --version (a leading "v" is accepted)
#   2. the single app zip left in the dist directory
#   3. the latest vX.Y.Z git tag
# Usage: VERSION="$(resolve_version "$VERSION" "$DIST_DIR")"
resolve_version() {
    local explicit="$1" dist_dir="$2" version=""

    if [[ -n "$explicit" ]]; then
        version="${explicit#v}"
    else
        version="$(version_from_dist "$dist_dir" 2>/dev/null)" || version=""

        if [[ -z "$version" ]]; then
            version="$(latest_version_tag)"
            version="${version#v}"
        fi
    fi

    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
        die "Unable to determine the version. Pass --version X.Y.Z."

    printf '%s\n' "$version"
}

# --- Artifact and file helpers -----------------------------------------------

# Prints the single match of `find <dir> -maxdepth 1 <args>`; dies otherwise.
# Usage: find_single_artifact <dir> <description> <option-name> <find args...>
find_single_artifact() {
    local dir="$1" description="$2" option="$3"
    shift 3

    local found count
    found="$(find "$dir" -maxdepth 1 "$@" 2>/dev/null || true)"
    count="$(printf '%s\n' "$found" | grep -c . || true)"

    [[ "$count" -eq 1 ]] ||
        die "Expected exactly one ${description} in ${dir}, found ${count}. Use ${option}."

    printf '%s\n' "$found"
}

plist_value() {
    local plist="$1" key="$2"
    "${PLISTBUDDY:-/usr/libexec/PlistBuddy}" -c "Print :${key}" "$plist" 2>/dev/null || true
}

# --- Sparkle helpers ---------------------------------------------------------

count_items() {
    grep -c '<item[ >]' "$1" || true
}

# Succeeds if the appcast file carries <sparkle:version> equal to the version.
# Usage: appcast_has_version <file> <version>   (<file> may be <(process))
appcast_has_version() {
    local file="$1" escaped="${2//./\\.}"

    grep -Eq "<sparkle:version>${escaped}</sparkle:version>|sparkle:version=\"${escaped}\"" "$file"
}

# Prints the path of a Sparkle command-line tool, or returns 1 if not found.
# Search order: $SPARKLE_BIN, PATH, Xcode's DerivedData (SwiftPM artifacts).
find_sparkle_tool() {
    local tool="$1" candidate

    if [[ -n "${SPARKLE_BIN:-}" ]]; then
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
