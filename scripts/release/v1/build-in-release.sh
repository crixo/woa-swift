#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

SCHEME=""
WORKSPACE_PATH=""
PROJECT_PATH=""
CONFIGURATION="Release"
ARCHIVE_PATH=""
VERSION=""
CODE_SIGNING_ALLOWED=""

log() {
    printf '\033[1;34m[INFO]\033[0m %s\n' "$*"
}

success() {
    printf '\033[1;32m[SUCCESS]\033[0m %s\n' "$*"
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

    error "Release build failed at line ${line_number} with exit code ${exit_code}."
    exit "$exit_code"
}

trap 'handle_error "$LINENO"' ERR

show_help() {
    cat <<'HELP'
Usage:

  ./scripts/build-in-release.sh --scheme <scheme> (--project <path> | --workspace <path>) [options]

Required parameters:

  --scheme <name>
      Xcode scheme to archive.

  --project <path>
      Path to the Xcode project.

  --workspace <path>
      Path to the Xcode workspace. Mutually exclusive with --project.

Build parameters:

  --configuration <name>
      Xcode build configuration. Default: Release.

  --archive-path <path>
      Destination for the Xcode archive.
      Default: build/archive/<scheme>.xcarchive

  --version <version>
      Set MARKETING_VERSION and CURRENT_PROJECT_VERSION in the archive build.

  --code-signing-allowed <YES|NO>
      Set the CODE_SIGNING_ALLOWED Xcode build setting.

  -h, --help
      Display this help.
HELP
}

require_parameter_value() {
    local parameter_name="$1"
    local parameter_count="$2"

    [[ "$parameter_count" -ge 2 ]] ||
        die "Missing value for parameter: ${parameter_name}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --scheme)
            require_parameter_value "$1" "$#"
            SCHEME="$2"
            shift 2
            ;;
        --project)
            require_parameter_value "$1" "$#"
            PROJECT_PATH="$2"
            shift 2
            ;;
        --workspace)
            require_parameter_value "$1" "$#"
            WORKSPACE_PATH="$2"
            shift 2
            ;;
        --configuration)
            require_parameter_value "$1" "$#"
            CONFIGURATION="$2"
            shift 2
            ;;
        --archive-path)
            require_parameter_value "$1" "$#"
            ARCHIVE_PATH="$2"
            shift 2
            ;;
        --version)
            require_parameter_value "$1" "$#"
            VERSION="$2"
            shift 2
            ;;
        --code-signing-allowed)
            require_parameter_value "$1" "$#"
            CODE_SIGNING_ALLOWED="$2"
            shift 2
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

[[ -n "$SCHEME" ]] ||
    die "The required --scheme parameter was not provided."

[[ -n "$CONFIGURATION" ]] ||
    die "--configuration cannot be empty."

if [[ -n "$CODE_SIGNING_ALLOWED" &&
    "$CODE_SIGNING_ALLOWED" != "YES" &&
    "$CODE_SIGNING_ALLOWED" != "NO" ]]
then
    die "--code-signing-allowed must be YES or NO."
fi

if [[ -n "$WORKSPACE_PATH" && -n "$PROJECT_PATH" ]]; then
    die "--workspace and --project cannot be used together."
fi

if [[ -z "$WORKSPACE_PATH" && -z "$PROJECT_PATH" ]]; then
    die "Either --project or --workspace must be provided."
fi

if [[ -n "$WORKSPACE_PATH" ]]; then
    XCODE_CONTAINER_ARGUMENTS=(-workspace "$WORKSPACE_PATH")
else
    XCODE_CONTAINER_ARGUMENTS=(-project "$PROJECT_PATH")
fi

if [[ -z "$ARCHIVE_PATH" ]]; then
    ARCHIVE_PATH="build/archive/${SCHEME}.xcarchive"
fi

command -v xcodebuild >/dev/null 2>&1 ||
    die "Required command not found: xcodebuild"

[[ "$(uname -s)" == "Darwin" ]] ||
    die "This script must run on macOS."

mkdir -p "$(dirname "$ARCHIVE_PATH")"

log "Building ${SCHEME} in ${CONFIGURATION} configuration..."

XCODE_BUILD_ARGUMENTS=(
    "${XCODE_CONTAINER_ARGUMENTS[@]}"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -destination 'generic/platform=macOS'
    -archivePath "$ARCHIVE_PATH"
)

if [[ -n "$VERSION" ]]; then
    XCODE_BUILD_ARGUMENTS+=(
        "MARKETING_VERSION=${VERSION}"
        "CURRENT_PROJECT_VERSION=${VERSION}"
    )
fi

if [[ -n "$CODE_SIGNING_ALLOWED" ]]; then
    XCODE_BUILD_ARGUMENTS+=("CODE_SIGNING_ALLOWED=${CODE_SIGNING_ALLOWED}")
fi

xcodebuild -quiet "${XCODE_BUILD_ARGUMENTS[@]}" clean archive

[[ -d "$ARCHIVE_PATH" ]] ||
    die "Xcode archive was not created: ${ARCHIVE_PATH}"

success "Release archive created successfully: ${ARCHIVE_PATH}"
