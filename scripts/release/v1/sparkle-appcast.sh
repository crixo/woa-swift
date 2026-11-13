#!/usr/bin/env bash
# ==============================================================================
# sparkle-appcast.sh
#
# Publishes the Sparkle update feed (appcast.xml) for a release that was
# already built and published by build-tag-release.sh.
#
# Run it AFTER build-tag-release.sh, from anywhere inside the repository:
#
#     ./sparkle-appcast.sh
#
# With no options it releases the latest vX.Y.Z tag, using the artifacts that
# build-tag-release.sh left in the dist directory.
#
# WHAT IT DOES, IN ORDER
#   1. Checks tools, git state (on main, up to date) and GitHub access.
#   2. Resolves the version (latest tag) and finds the .app and .app.zip.
#   3. PREPARE  Validates the app for Sparkle (keys, feed URL, framework),
#               signs the zip with generate_appcast and stages the new
#               appcast.xml under <build-dir>/sparkle-<version>/.
#               Nothing in the repository or on the remote is touched.
#   4. VERIFY   Checks that the GitHub Release and its zip asset exist, so the
#               appcast never points apps at a missing file.
#   5. PUBLISH  Commits appcast.xml to the main branch and pushes it.
#               With --dry-run only the push is simulated.
#
# REHEARSAL BEFORE A REAL RELEASE
#   build-tag-release.sh --dry-run leaves a built app and zip in dist/.
#   You can check the Sparkle side against them before releasing:
#
#     ./sparkle-appcast.sh --version 0.4.0 --dry-run
#
#   Because the GitHub Release does not exist yet, step 4 only warns.
#
# RE-RUNNING
#   If the push failed after the appcast was committed, run the script again:
#   it detects the unpushed commit and just pushes it.
#   If the version is already published, it stops without changing anything.
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'


# ==============================================================================
# 1. CONFIGURATION (defaults, overridable by command-line options)
# ==============================================================================

# --- What to release ---------------------------------------------------------
VERSION=""                  # --version (default: latest vX.Y.Z tag)
APP_PATH=""                 # --app-path (default: the single .app in dist)
ZIP_PATH=""                 # --zip-path (default: dist/*-<version>.app.zip)
DIST_DIR="dist"             # --dist-dir

# --- Git / GitHub ------------------------------------------------------------
REPOSITORY_NAME=""          # --repository (default: detected with gh)
REMOTE="origin"
MAIN_BRANCH="main"

# --- Sparkle -----------------------------------------------------------------
BUILD_DIR="build"           # intermediate files live in <build-dir>/sparkle-<version>
APPCAST_PATH="appcast.xml"  # location of the appcast in the repository
FEED_URL=""                 # --feed-url (default: raw.githubusercontent URL)
ED_KEY_FILE=""              # --ed-key-file (default: login Keychain)
SPARKLE_BIN="${SPARKLE_BIN:-}"
PLISTBUDDY="${PLISTBUDDY:-/usr/libexec/PlistBuddy}"

# --- Behaviour flags ---------------------------------------------------------
DRY_RUN=false               # --dry-run

# --- Runtime state (derived while the script runs; do not set by hand) -------
TAG=""                      # v<version>
ZIP_NAME=""                 # file name of the zip = asset name on the Release
WORK_DIR=""
INPUT_DIR=""
GENERATED_APPCAST=""        # what generate_appcast produced (one <item>)
NEW_ITEM_FILE=""            # the extracted new <item>
STAGED_APPCAST=""           # the full appcast that will be committed
DOWNLOAD_PREFIX=""          # where GitHub serves the Release assets
ENCLOSURE_URL=""            # download URL found in the generated entry


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
    error "Sparkle appcast failed at line ${1:-unknown} with exit code ${exit_code}."
    exit "$exit_code"
}
trap 'handle_error "$LINENO"' ERR


# ==============================================================================
# 3. COMMAND-LINE PARSING AND VALIDATION
# ==============================================================================

show_help() {
    cat <<'HELP'
Usage: ./sparkle-appcast.sh [options]

Run it after build-tag-release.sh. With no options it publishes the appcast
for the latest vX.Y.Z tag, using the artifacts left in the dist directory.

What to release
  --version <x.y.z>       Version without the leading "v"
                          (default: latest vX.Y.Z git tag).
  --app-path <path>       Application bundle
                          (default: the single .app in --dist-dir).
  --zip-path <path>       Application zip uploaded to the GitHub Release; its
                          file name must be the asset name on the Release
                          (default: <dist-dir>/*-<version>.app.zip).
  --dist-dir <path>       Where build-tag-release.sh left the artifacts
                          (default: dist).

Git / GitHub
  --repository <o/name>   GitHub repository hosting the Release
                          (default: detected with gh).
  --remote <name>         Git remote (default: origin).
  --main-branch <name>    Branch that holds appcast.xml (default: main).

Sparkle
  --build-dir <path>      Intermediate files (default: build).
  --appcast-path <path>   appcast.xml location in the repo (default: appcast.xml).
  --feed-url <url>        Expected SUFeedURL (default:
                          https://raw.githubusercontent.com/<repo>/<branch>/<appcast-path>).
  --sparkle-bin <dir>     Folder containing generate_appcast. If omitted:
                          $SPARKLE_BIN, then PATH, then Xcode's DerivedData.
  --ed-key-file <path>    Exported EdDSA private key (CI). If omitted the key
                          is read from the login Keychain.

Execution
  --dry-run               Validate, sign and stage the appcast, and simulate
                          the push. Nothing is committed or pushed.
  -h, --help              Show this help.
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
            --version)       need_value "$1" "$#"; VERSION="$2";         shift 2 ;;
            --app-path)      need_value "$1" "$#"; APP_PATH="$2";        shift 2 ;;
            --zip-path)      need_value "$1" "$#"; ZIP_PATH="$2";        shift 2 ;;
            --dist-dir)      need_value "$1" "$#"; DIST_DIR="$2";        shift 2 ;;
            --repository)    need_value "$1" "$#"; REPOSITORY_NAME="$2"; shift 2 ;;
            --remote)        need_value "$1" "$#"; REMOTE="$2";          shift 2 ;;
            --main-branch)   need_value "$1" "$#"; MAIN_BRANCH="$2";     shift 2 ;;
            --build-dir)     need_value "$1" "$#"; BUILD_DIR="$2";       shift 2 ;;
            --appcast-path)  need_value "$1" "$#"; APPCAST_PATH="$2";    shift 2 ;;
            --feed-url)      need_value "$1" "$#"; FEED_URL="$2";        shift 2 ;;
            --sparkle-bin)   need_value "$1" "$#"; SPARKLE_BIN="$2";     shift 2 ;;
            --ed-key-file)   need_value "$1" "$#"; ED_KEY_FILE="$2";     shift 2 ;;
            --dry-run)       DRY_RUN=true; shift ;;
            -h|--help)       show_help; exit 0 ;;
            *) die "Unknown option: $1 (use --help)" ;;
        esac
    done
}

validate_args() {
    [[ -n "$REMOTE" ]]       || die "--remote cannot be empty."
    [[ -n "$MAIN_BRANCH" ]]  || die "--main-branch cannot be empty."
    [[ -n "$BUILD_DIR" ]]    || die "--build-dir cannot be empty."
    [[ -n "$DIST_DIR" ]]     || die "--dist-dir cannot be empty."
    [[ -n "$APPCAST_PATH" ]] || die "--appcast-path cannot be empty."

    # Accept "v1.2.3" as well as "1.2.3".
    VERSION="${VERSION#v}"

    if [[ "$DRY_RUN" == true ]]; then
        warning "DRY-RUN: the appcast is staged and checked, nothing is committed or pushed."
    fi
}


# ==============================================================================
# 4. PRE-FLIGHT CHECKS (tools, git, GitHub)
# ==============================================================================

require_tools() {
    local tool
    for tool in git gh awk grep sed tr find; do
        command -v "$tool" >/dev/null 2>&1 || die "Required command not found: ${tool}"
    done

    [[ "$(uname -s)" == "Darwin" ]] || die "Sparkle's tools run on macOS only."
}

# Moves to the repo root and requires to be on an up-to-date main branch.
# Every relative path (dist, build, appcast) is relative to the repo root.
check_git_state() {
    local current_branch

    git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
        die "Not inside a Git repository."

    cd "$(git rev-parse --show-toplevel)"

    git remote get-url "$REMOTE" >/dev/null 2>&1 ||
        die "Git remote '${REMOTE}' is not configured."

    current_branch="$(git branch --show-current)"
    [[ "$current_branch" == "$MAIN_BRANCH" ]] ||
        die "The appcast must be committed on ${MAIN_BRANCH}, but the current branch is '${current_branch}'."

    # Only the appcast itself must be clean: the commit is limited to that file.
    [[ -z "$(git status --porcelain -- "$APPCAST_PATH")" ]] ||
        die "${APPCAST_PATH} has uncommitted changes. Commit or discard them first."

    log "Fetching ${MAIN_BRANCH} and tags from ${REMOTE}..."
    git fetch "$REMOTE" "$MAIN_BRANCH" --tags --prune
    git pull --ff-only "$REMOTE" "$MAIN_BRANCH"
}

# Requires an authenticated gh; detects the repository if not given.
check_github_access() {
    log "Verifying GitHub access..."

    gh auth status >/dev/null 2>&1 || die "GitHub CLI not authenticated. Run: gh auth login"

    if [[ -z "$REPOSITORY_NAME" ]]; then
        REPOSITORY_NAME="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
    fi

    [[ -n "$REPOSITORY_NAME" ]] || die "Unable to determine the GitHub repository."
    log "GitHub repository: ${REPOSITORY_NAME}"
}


# ==============================================================================
# 5. RESOLVE WHAT TO RELEASE (version, artifacts, derived paths)
# ==============================================================================

# Sets VERSION (latest vX.Y.Z tag unless --version was given) and TAG.
resolve_version() {
    local latest_tag

    if [[ -z "$VERSION" ]]; then
        latest_tag="$(
            git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname |
            grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' |
            head -n 1 || true
        )"

        [[ -n "$latest_tag" ]] ||
            die "No vX.Y.Z tag found. Pass --version, or run build-tag-release.sh first."

        VERSION="${latest_tag#v}"
    fi

    [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
        die "Version '${VERSION}' is not in the form X.Y.Z."

    TAG="v${VERSION}"
    log "Version: ${VERSION} (tag ${TAG})"
}

# Finds exactly one match in DIST_DIR for the given find arguments.
# Prints it; dies with a clear message otherwise.
find_single_artifact() {
    local description="$1" option="$2"
    shift 2

    local found count
    found="$(find "$DIST_DIR" -maxdepth 1 "$@" 2>/dev/null || true)"
    count="$(printf '%s\n' "$found" | grep -c . || true)"

    [[ "$count" -eq 1 ]] ||
        die "Expected exactly one ${description} in ${DIST_DIR}, found ${count}. Use ${option}."

    printf '%s\n' "$found"
}

# Sets APP_PATH and ZIP_PATH from the dist directory unless given.
resolve_artifacts() {
    if [[ -z "$APP_PATH" ]]; then
        APP_PATH="$(find_single_artifact "application bundle" "--app-path" -type d -name '*.app')"
    fi

    if [[ -z "$ZIP_PATH" ]]; then
        ZIP_PATH="$(find_single_artifact "zip for version ${VERSION}" "--zip-path" -type f -name "*-${VERSION}.app.zip")"
    fi

    log "App: ${APP_PATH}"
    log "Zip: ${ZIP_PATH}"
}

# Fills every path and URL derived from the values above.
derive_paths() {
    ZIP_NAME="$(basename -- "$ZIP_PATH")"

    WORK_DIR="${BUILD_DIR}/sparkle-${VERSION}"
    INPUT_DIR="${WORK_DIR}/input"
    GENERATED_APPCAST="${INPUT_DIR}/appcast.xml"
    NEW_ITEM_FILE="${WORK_DIR}/new-item.xml"
    STAGED_APPCAST="${WORK_DIR}/appcast.xml"

    # GitHub always serves Release assets from this location. The asset name is
    # the file name of the uploaded file (a "#label" suffix on `gh release
    # create` only changes the display label), which is why ZIP_NAME must match
    # the uploaded file.
    DOWNLOAD_PREFIX="https://github.com/${REPOSITORY_NAME}/releases/download/${TAG}/"

    if [[ -z "$FEED_URL" ]]; then
        FEED_URL="https://raw.githubusercontent.com/${REPOSITORY_NAME}/${MAIN_BRANCH}/${APPCAST_PATH}"
    fi
}


# ==============================================================================
# 6. HELPERS
# ==============================================================================

plist_value() {
    local plist="$1" key="$2"
    "$PLISTBUDDY" -c "Print :${key}" "$plist" 2>/dev/null || true
}

count_items() {
    grep -c '<item[ >]' "$1" || true
}

appcast_has_version() {
    local appcast="$1"

    grep -Fq "<sparkle:version>${VERSION}</sparkle:version>" "$appcast" ||
        grep -Fq "sparkle:version=\"${VERSION}\"" "$appcast"
}

# Prints the path of a Sparkle command-line tool, or returns 1 if not found.
find_sparkle_tool() {
    local tool="$1" candidate

    if [[ -n "$SPARKLE_BIN" ]]; then
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

    # Location used when Sparkle is added to the Xcode project with SwiftPM.
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

# Pushes the main branch. On failure the appcast commit stays local and the
# way to recover is printed.
push_main_branch() {
    log "Pushing ${MAIN_BRANCH} to ${REMOTE}..."

    if ! git push "$REMOTE" "$MAIN_BRANCH"; then
        error "Pushing the appcast commit failed."

        warning "The appcast commit exists locally on ${MAIN_BRANCH} but was NOT pushed."
        warning "Installed apps will not see ${TAG} until it is pushed."
        warning "If ${MAIN_BRANCH} is protected, push the commit through a pull request instead."

        printf '\nAfter resolving the problem, just run this script again (or: git push %q %q).\n' \
            "$REMOTE" "$MAIN_BRANCH"

        exit 1
    fi
}


# ==============================================================================
# 7. ALREADY-PUBLISHED CHECK (makes the script safe to re-run)
# ==============================================================================

# Does nothing if the appcast does not contain this version yet.
# Otherwise it never builds a second entry:
#   - committed locally but not pushed -> pushes it and finishes
#   - already pushed                   -> stops with an explanation
check_not_already_published() {
    local unpushed

    [[ -f "$APPCAST_PATH" ]] || return 0
    appcast_has_version "$APPCAST_PATH" || return 0

    unpushed="$(git log --format=%H "${REMOTE}/${MAIN_BRANCH}..${MAIN_BRANCH}" -- "$APPCAST_PATH")"

    [[ -n "$unpushed" ]] ||
        die "${APPCAST_PATH} already contains version ${VERSION} and it is already pushed. Nothing to do."

    warning "${APPCAST_PATH} already has version ${VERSION} in a local commit that was never pushed."

    if [[ "$DRY_RUN" == true ]]; then
        log "Dry run: a real run would push ${MAIN_BRANCH} now."
        exit 0
    fi

    push_main_branch
    print_published_summary
    exit 0
}


# ==============================================================================
# 8. PREPARE: VALIDATE, SIGN AND STAGE THE APPCAST (publishes nothing)
# ==============================================================================

# The app must be correctly set up for Sparkle, or updates would silently fail.
validate_app_for_sparkle() {
    local info_plist="${APP_PATH}/Contents/Info.plist"
    local bundle_version public_key feed_url

    log "Validating the application for Sparkle..."

    [[ -d "$APP_PATH" ]]  || die "Application bundle not found: ${APP_PATH}"
    [[ -s "$ZIP_PATH" ]]  || die "Application ZIP not found or empty: ${ZIP_PATH}"
    [[ -f "$info_plist" ]] || die "Application Info.plist was not found: ${info_plist}"

    # Sparkle compares CFBundleVersion, so it must be the release version.
    bundle_version="$(plist_value "$info_plist" CFBundleVersion)"
    [[ "$bundle_version" == "$VERSION" ]] ||
        die "CFBundleVersion is '${bundle_version}', expected '${VERSION}'."

    public_key="$(plist_value "$info_plist" SUPublicEDKey)"
    [[ -n "$public_key" ]] ||
        die "SUPublicEDKey is missing from the app's Info.plist. Run Sparkle's generate_keys and add the printed public key to the app target."

    # A Sparkle EdDSA public key is 32 bytes in base64: 43 characters + "=".
    [[ "$public_key" =~ ^[A-Za-z0-9+/]{43}=$ ]] ||
        die "SUPublicEDKey ('${public_key}') is not a valid Sparkle public key. Replace the placeholder with the key printed by generate_keys."

    feed_url="$(plist_value "$info_plist" SUFeedURL)"
    [[ -n "$feed_url" ]] ||
        die "SUFeedURL is missing from the app's Info.plist. Expected: ${FEED_URL}"

    if [[ "$feed_url" != "$FEED_URL" ]]; then
        warning "SUFeedURL in the app is '${feed_url}'."
        warning "Expected '${FEED_URL}'. Installed apps will read the URL baked into the app."
    fi

    [[ -d "${APP_PATH}/Contents/Frameworks/Sparkle.framework" ]] ||
        die "Sparkle.framework is not embedded in ${APP_PATH}. Add the Sparkle package to the app target (Embed & Sign)."

    if command -v codesign >/dev/null 2>&1; then
        if ! codesign --verify --deep --strict "$APP_PATH" >/dev/null 2>&1; then
            warning "${APP_PATH} does not pass 'codesign --verify --deep --strict'."
            warning "Notarization is not required, but at least ad-hoc signing is: Apple Silicon will not run unsigned code, including Sparkle's helpers."
        fi
    fi
}

# Checks what generate_appcast produced. Sets ENCLOSURE_URL.
validate_generated_item() {
    local item_count enclosure_name

    log "Validating the generated appcast entry..."

    [[ -s "$GENERATED_APPCAST" ]] ||
        die "generate_appcast did not produce ${GENERATED_APPCAST}."

    item_count="$(count_items "$GENERATED_APPCAST")"
    [[ "$item_count" == "1" ]] ||
        die "Expected exactly one <item> in the generated appcast, found ${item_count}."

    grep -Fq 'sparkle:edSignature=' "$GENERATED_APPCAST" ||
        die "The generated appcast entry has no sparkle:edSignature. Is the EdDSA private key available?"

    appcast_has_version "$GENERATED_APPCAST" ||
        die "The generated appcast entry does not carry version ${VERSION}."

    ENCLOSURE_URL="$(
        tr '\n' ' ' <"$GENERATED_APPCAST" |
            grep -o '<enclosure[^>]*>' |
            head -n 1 |
            sed -n 's/.*[[:space:]]url="\([^"]*\)".*/\1/p' ||
        true
    )"

    [[ -n "$ENCLOSURE_URL" ]] ||
        die "Unable to read the enclosure URL from the generated appcast."

    [[ "$ENCLOSURE_URL" == "${DOWNLOAD_PREFIX}"* ]] ||
        die "Enclosure URL '${ENCLOSURE_URL}' does not start with '${DOWNLOAD_PREFIX}'."

    enclosure_name="${ENCLOSURE_URL#"$DOWNLOAD_PREFIX"}"
    enclosure_name="${enclosure_name//%20/ }"

    [[ "$enclosure_name" == "$ZIP_NAME" ]] ||
        die "Enclosure file name '${enclosure_name}' does not match the uploaded asset '${ZIP_NAME}'."
}

# Builds STAGED_APPCAST: the existing appcast plus the new entry on top.
merge_into_existing_appcast() {
    local existing_items=0 merged_items

    if [[ ! -f "$APPCAST_PATH" ]]; then
        log "No existing ${APPCAST_PATH}: this is the first appcast entry."
        cp "$GENERATED_APPCAST" "$STAGED_APPCAST"
        return 0
    fi

    log "Merging the new entry into the existing ${APPCAST_PATH}..."

    if command -v xmllint >/dev/null 2>&1; then
        xmllint --noout "$APPCAST_PATH" ||
            die "The existing ${APPCAST_PATH} is not well-formed XML."
    fi

    existing_items="$(count_items "$APPCAST_PATH")"

    # Only the new <item> block is taken from the generated file. Existing
    # entries are left exactly as they are, so each one keeps its own tag in its
    # download URL and nothing depends on how generate_appcast treats old items.
    awk '/<item[ >]/ { keep = 1 } keep { print } /<\/item>/ { keep = 0 }' \
        "$GENERATED_APPCAST" >"$NEW_ITEM_FILE"

    [[ -s "$NEW_ITEM_FILE" ]] ||
        die "Unable to extract the new <item> from the generated appcast."

    # Newest first: insert before the first existing <item>, or before </channel>.
    awk -v item_file="$NEW_ITEM_FILE" '
        function emit(   line) {
            while ((getline line < item_file) > 0) print line
            close(item_file)
            inserted = 1
        }
        !inserted && /<item[ >]/    { emit() }
        !inserted && /<\/channel>/  { emit() }
        { print }
    ' "$APPCAST_PATH" >"$STAGED_APPCAST"

    merged_items="$(count_items "$STAGED_APPCAST")"
    [[ "$merged_items" == "$((existing_items + 1))" ]] ||
        die "Merge check failed: expected $((existing_items + 1)) items, found ${merged_items}."
}

# The whole PREPARE phase. Leaves the finished appcast in STAGED_APPCAST.
prepare_appcast() {
    local generate_appcast
    local generate_arguments

    validate_app_for_sparkle

    generate_appcast="$(find_sparkle_tool generate_appcast)" ||
        die "generate_appcast not found. Use --sparkle-bin <dir>, set SPARKLE_BIN, or add Sparkle's bin directory to PATH."

    log "Using generate_appcast: ${generate_appcast}"

    rm -rf "$WORK_DIR"
    mkdir -p "$INPUT_DIR"

    # One archive only: the appcast entry for this version is generated alone
    # and merged afterwards.
    cp "$ZIP_PATH" "${INPUT_DIR}/${ZIP_NAME}"

    generate_arguments=(
        "$INPUT_DIR"
        --download-url-prefix "$DOWNLOAD_PREFIX"
    )

    if [[ -n "$ED_KEY_FILE" ]]; then
        [[ -f "$ED_KEY_FILE" ]] || die "EdDSA key file not found: ${ED_KEY_FILE}"
        generate_arguments+=(--ed-key-file "$ED_KEY_FILE")
    fi

    log "Signing ${ZIP_NAME} and generating its appcast entry..."
    "$generate_appcast" "${generate_arguments[@]}"

    validate_generated_item
    merge_into_existing_appcast

    if command -v xmllint >/dev/null 2>&1; then
        xmllint --noout "$STAGED_APPCAST" ||
            die "The staged appcast is not well-formed XML."
    fi

    grep -Fq "$ENCLOSURE_URL" "$STAGED_APPCAST" ||
        die "The staged appcast does not contain the new download URL."

    success "Sparkle appcast prepared: ${STAGED_APPCAST}"
    printf '\n  Entries:      %s\n  Version:      %s\n  Download URL: %s\n  Feed URL:     %s\n\n' \
        "$(count_items "$STAGED_APPCAST")" "$VERSION" "$ENCLOSURE_URL" "$FEED_URL"
}


# ==============================================================================
# 9. VERIFY: THE GITHUB RELEASE AND ITS ASSET MUST EXIST
# ==============================================================================

# The appcast points apps at the zip on the GitHub Release, so publishing it
# before the asset exists would break updates.
# In --dry-run a missing Release only warns: that is expected when rehearsing
# before the real release.
verify_release_asset() {
    local assets problem=""

    log "Verifying that ${ZIP_NAME} is attached to GitHub Release ${TAG}..."

    if ! assets="$(gh release view "$TAG" --repo "$REPOSITORY_NAME" --json assets --jq '.assets[].name' 2>/dev/null)"; then
        problem="GitHub Release ${TAG} was not found."
    elif ! grep -Fxq -- "$ZIP_NAME" <<<"$assets"; then
        problem="Asset '${ZIP_NAME}' is not attached to Release ${TAG}."
    fi

    if [[ -z "$problem" ]]; then
        check_download_url
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        warning "${problem}"
        warning "Expected when rehearsing before the release exists; a real run would stop here."
        return 0
    fi

    die "${problem} Publishing the appcast now would point apps at a missing file."
}

# Best-effort reachability check; a private repository fails here by design.
check_download_url() {
    command -v curl >/dev/null 2>&1 || return 0

    if ! curl --fail --silent --location --range 0-0 --output /dev/null \
        "${DOWNLOAD_PREFIX}${ZIP_NAME// /%20}"
    then
        warning "The download URL did not answer successfully."
        warning "Sparkle needs it to be publicly downloadable (public repository)."
    fi

    return 0
}


# ==============================================================================
# 10. PUBLISH: COMMIT AND PUSH THE APPCAST
# ==============================================================================

print_publish_commands() {
    printf '  cp %q %q\n' "$STAGED_APPCAST" "$APPCAST_PATH"
    printf '  git add -- %q\n' "$APPCAST_PATH"
    printf '  git commit -m %q -- %q\n' "Update appcast for ${TAG}" "$APPCAST_PATH"
    printf '  git push %q %q\n' "$REMOTE" "$MAIN_BRANCH"
}

# --dry-run: simulate the push and show what a real run would do.
simulate_publish() {
    log "Testing whether ${MAIN_BRANCH} could be pushed to ${REMOTE}..."

    git push --dry-run "$REMOTE" "${MAIN_BRANCH}:${MAIN_BRANCH}" ||
        die "The simulated push of ${MAIN_BRANCH} failed."

    printf '\nCommands a real run would execute:\n\n'
    print_publish_commands
    printf '\n'

    warning "No appcast was committed."
    warning "No appcast was pushed."
}

print_published_summary() {
    success "Appcast for ${TAG} pushed to ${REMOTE}/${MAIN_BRANCH}."
    printf '\n  Feed URL: %s\n\n' "$FEED_URL"

    warning "raw.githubusercontent.com caches files for a few minutes before the new appcast is visible."
}

publish_appcast() {
    if [[ "$DRY_RUN" == true ]]; then
        simulate_publish
        return 0
    fi

    log "Updating ${APPCAST_PATH}..."

    mkdir -p "$(dirname -- "$APPCAST_PATH")"
    cp "$STAGED_APPCAST" "$APPCAST_PATH"

    git add -- "$APPCAST_PATH"

    git diff --cached --quiet -- "$APPCAST_PATH" &&
        die "${APPCAST_PATH} has no changes to commit."

    git commit -m "Update appcast for ${TAG}" -- "$APPCAST_PATH"

    push_main_branch
    print_published_summary
}


# ==============================================================================
# 11. MAIN: THE WHOLE FLOW, IN ORDER
# ==============================================================================

main() {
    # Setup and pre-flight checks
    parse_args "$@"
    validate_args
    require_tools
    check_git_state
    check_github_access

    # What to release
    resolve_version
    resolve_artifacts
    derive_paths
    check_not_already_published   # safe re-run: pushes a pending commit or stops

    # Prepare (publishes nothing), then verify the Release, then publish
    prepare_appcast
    verify_release_asset
    publish_appcast
}

main "$@"
