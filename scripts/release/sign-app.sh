#!/usr/bin/env bash
# ==============================================================================
# sign-app.sh   (called by package-artifacts.sh, step 3)
#
# Code-signs a .app bundle with a certificate from the Keychain (by default the
# self-signed "CrixoDev" code-signing certificate).
#
# Order matters: every piece of nested code (frameworks, XPC services, helper
# apps, plug-ins, dylibs, helper executables) is signed first, deepest first,
# and the app itself last. This is what Apple recommends instead of the
# deprecated "codesign --deep" for signing.
#
# Existing entitlements and flags (for example the sandbox) are preserved,
# unless --entitlements is given for the app itself. No timestamp is requested:
# a self-signed certificate has no timestamp authority behind it.
#
# At the end the signature is verified, the signing identity is checked, and
# the designated requirement is printed. For a self-signed certificate it is
# tied to the certificate itself, so two releases signed with the same
# certificate must print the same requirement: that is what keeps Keychain
# "Always Allow" decisions valid across updates.
#
# Gatekeeper is not affected: a self-signed app is still "unidentified developer".
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release-common.sh
source "${SCRIPT_DIR}/release-common.sh"
trap 'handle_error "$LINENO"' ERR

APP_PATH=""
IDENTITY="$DEFAULT_SIGN_IDENTITY"
ENTITLEMENTS=""

show_help() {
    cat <<HELP
Usage: ./sign-app.sh --app-path <path> [options]

  --app-path <path>        The .app bundle to sign (required).
  --identity <name>        Name of the code-signing certificate in the Keychain
                           (default: ${DEFAULT_SIGN_IDENTITY}).
  --entitlements <path>    Entitlements file for the app itself
                           (default: keep the ones already in the app).
  -h, --help               Show this help.
HELP
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --app-path)      need_value "$1" "$#"; APP_PATH="$2";     shift 2 ;;
            --identity)      need_value "$1" "$#"; IDENTITY="$2";     shift 2 ;;
            --entitlements)  need_value "$1" "$#"; ENTITLEMENTS="$2"; shift 2 ;;
            -h|--help)       show_help; exit 0 ;;
            *) die "Unknown option: $1 (use --help)" ;;
        esac
    done

    [[ -n "$APP_PATH" ]] || die "--app-path is required."
    [[ -d "$APP_PATH" ]] || die "App bundle not found: ${APP_PATH}"
    [[ -n "$IDENTITY" ]] || die "--identity cannot be empty."

    if [[ -n "$ENTITLEMENTS" ]]; then
        [[ -f "$ENTITLEMENTS" ]] || die "Entitlements file not found: ${ENTITLEMENTS}"
    fi
}

# Signs nested code, deepest first. A directory is signed after everything it
# contains because find -depth lists children before their parent.
sign_nested_code() {
    local contents="${APP_PATH}/Contents" main_executable item count=0

    main_executable="$(plist_value "${contents}/Info.plist" CFBundleExecutable)"
    [[ -n "$main_executable" ]] || die "CFBundleExecutable not found in ${contents}/Info.plist"
    main_executable="${contents}/MacOS/${main_executable}"

    while IFS= read -r -d '' item; do
        # The app's own executable is signed together with the app.
        [[ "$item" != "$main_executable" ]] || continue

        # Plain files: only Mach-O binaries are code.
        if [[ -f "$item" && ! -L "$item" ]]; then
            [[ "$(file -b "$item")" == *Mach-O* ]] || continue
        fi

        log "Signing ${item#"${APP_PATH}"/}"
        codesign --force --sign "$IDENTITY" --timestamp=none \
            --preserve-metadata=identifier,entitlements,flags \
            "$item"
        count=$((count + 1))
    done < <(
        find "$contents" -depth \( \
            \( -type d \( -name '*.framework' -o -name '*.xpc' -o -name '*.appex' \
                          -o -name '*.app' -o -name '*.bundle' \) \) -o \
            \( -type f \( -name '*.dylib' -o -name '*.so' -o -perm -u+x \) \) \
        \) -print0
    )

    log "Signed ${count} nested item(s)."
}

sign_app_bundle() {
    local args=(--force --sign "$IDENTITY" --timestamp=none)

    if [[ -n "$ENTITLEMENTS" ]]; then
        args+=(--entitlements "$ENTITLEMENTS" --preserve-metadata=identifier,flags)
    else
        args+=(--preserve-metadata=identifier,entitlements,flags)
    fi

    log "Signing ${APP_PATH}..."
    codesign "${args[@]}" "$APP_PATH"
}

verify_signature() {
    local details

    log "Verifying the signature..."
    codesign --verify --deep --strict --verbose=2 "$APP_PATH"

    details="$(codesign -d --verbose=2 "$APP_PATH" 2>&1)"
    printf '%s\n' "$details" | grep -Fq "Authority=${IDENTITY}" ||
        die "The app is not signed by '${IDENTITY}'."

    log "Designated requirement (must be identical across releases):"
    codesign -d -r- "$APP_PATH" 2>&1 | sed -n 's/^designated => /  /p' >&2
}

main() {
    parse_args "$@"
    require_tools codesign security xattr file find

    signing_identity_available "$IDENTITY" ||
        die "Code-signing identity '${IDENTITY}' not found in the Keychain (see: security find-identity -p codesigning)."

    # Extended attributes (Finder info, resource forks) make codesign fail.
    xattr -cr "$APP_PATH"

    sign_nested_code
    sign_app_bundle
    verify_signature

    success "Signed $(basename "$APP_PATH") with '${IDENTITY}'."
}

main "$@"
