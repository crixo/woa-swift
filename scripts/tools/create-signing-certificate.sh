#!/usr/bin/env bash
# ==============================================================================
# create-signing-certificate.sh   (companion of sign-app.sh)
#
# Creates the self-signed code-signing certificate used by sign-app.sh
# (by default "CrixoDev") and installs it in a Keychain:
#
#   1. generates an RSA key + self-signed X.509 certificate with the
#      Code Signing extended key usage;
#   2. imports key and certificate into the Keychain, allowing /usr/bin/codesign
#      to use the key;
#   3. marks the certificate as trusted for code signing (so it shows up in
#      "security find-identity -v -p codesigning");
#   4. optionally lets codesign use the key without a password prompt
#      (key partition list) and writes a password-protected .p12 backup.
#
# Run it ONCE per machine. Every release must then be signed with this same
# certificate: the designated requirement of a self-signed app is tied to the
# certificate, so a new certificate means Keychain "Always Allow" decisions of
# your users stop matching. Keep the .p12 backup somewhere safe.
#
# Location: scripts/tool/ (sign-app.sh and release-common.sh: scripts/release/).
#
# Gatekeeper is not affected: a self-signed app is still "unidentified developer".
#
# EXPORTING THE IDENTITY LATER (backup, or to move it to another Mac)
#   The key is imported as extractable, so it can be exported at any time.
#   You need your Keychain password and a new password for the .p12 file.
#
#   Easiest: Keychain Access > "login" keychain > My Certificates > right-click
#   the certificate > Export... > Personal Information Exchange (.p12).
#
#   Command line (exports ALL identities of that keychain, prompts for the
#   .p12 password):
#     security export -k ~/Library/Keychains/login.keychain-db \
#         -t identities -f pkcs12 -o CrixoDev-backup.p12
#
#   Restore on another Mac:
#     security import CrixoDev-backup.p12 \
#         -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign
#   then set the certificate's Code Signing trust to "Always Trust" (Keychain
#   Access > certificate > Trust), as the .p12 does not carry trust settings.
#
#   Or create the backup right away with: --backup-p12 <path>
#   See also: SIGNING-CERTIFICATE.md
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# This script lives in scripts/tool; the shared helpers live in scripts/release.
RELEASE_DIR="$(cd -- "${SCRIPT_DIR}/../release" && pwd)"
# shellcheck source=../release/release-common.sh
source "${RELEASE_DIR}/release-common.sh"
trap 'handle_error "$LINENO"' ERR

# Apple's LibreSSL: its PKCS#12 output (3DES/RC2) is accepted by "security import".
# OpenSSL 3 (Homebrew) defaults to AES, which "security import" rejects.
OPENSSL=/usr/bin/openssl

IDENTITY="$DEFAULT_SIGN_IDENTITY"
DAYS=3650
KEYCHAIN=""
BACKUP_P12=""
SET_PARTITION_LIST=1
FORCE=0
WORK_DIR=""

show_help() {
    cat <<HELP
Usage: ./scripts/tool/create-signing-certificate.sh [options]

  --identity <name>        Common name of the certificate
                           (default: ${DEFAULT_SIGN_IDENTITY}).
  --days <n>               Validity in days (default: ${DAYS}).
  --keychain <path>        Keychain to install into (default: your default,
                           normally the login keychain).
  --backup-p12 <path>      Also write a password-protected .p12 backup of the
                           key and certificate (you are asked for a password).
  --no-partition-list      Do not authorise codesign to use the key silently;
                           the first signing will then ask for your password
                           (click "Always Allow").
  --force                  Replace an existing identity with the same name.
                           This changes the designated requirement: apps signed
                           before will no longer match it.
  -h, --help               Show this help.
HELP
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --identity)           need_value "$1" "$#"; IDENTITY="$2";   shift 2 ;;
            --days)               need_value "$1" "$#"; DAYS="$2";       shift 2 ;;
            --keychain)           need_value "$1" "$#"; KEYCHAIN="$2";   shift 2 ;;
            --backup-p12)         need_value "$1" "$#"; BACKUP_P12="$2"; shift 2 ;;
            --no-partition-list)  SET_PARTITION_LIST=0; shift ;;
            --force)              FORCE=1; shift ;;
            -h|--help)            show_help; exit 0 ;;
            *) die "Unknown option: $1 (use --help)" ;;
        esac
    done

    [[ -n "$IDENTITY" ]] || die "--identity cannot be empty."
    [[ "$IDENTITY" =~ ^[A-Za-z0-9._\ -]+$ ]] ||
        die "--identity may only contain letters, digits, space, '.', '_' and '-'."
    [[ "$DAYS" =~ ^[0-9]+$ && "$DAYS" -gt 0 ]] || die "--days must be a positive integer."

    if [[ -z "$KEYCHAIN" ]]; then
        KEYCHAIN="$(security default-keychain -d user | sed 's/^[[:space:]]*"//; s/"[[:space:]]*$//')"
    fi
    [[ -f "$KEYCHAIN" ]] || die "Keychain not found: ${KEYCHAIN}"

    if [[ -n "$BACKUP_P12" ]]; then
        [[ ! -e "$BACKUP_P12" ]] || die "Backup file already exists: ${BACKUP_P12}"
        [[ -d "$(dirname -- "$BACKUP_P12")" ]] || die "Directory not found: $(dirname -- "$BACKUP_P12")"
    fi
}

cleanup() {
    [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
    return 0
}

# Reads a secret from the terminal without echo into the variable named $2.
read_secret() {
    local prompt="$1" var="$2" value
    [[ -t 0 ]] || die "A terminal is needed to ask for: ${prompt}"
    read -r -s -p "${prompt}: " value </dev/tty
    printf '\n' >&2
    [[ -n "$value" ]] || die "Empty input."
    printf -v "$var" '%s' "$value"
}

generate_certificate() {
    log "Generating key and self-signed certificate for '${IDENTITY}' (${DAYS} days)..."

    cat >"${WORK_DIR}/openssl.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions    = ext
prompt             = no

[dn]
CN = ${IDENTITY}

[ext]
basicConstraints     = critical,CA:false
keyUsage             = critical,digitalSignature
extendedKeyUsage     = critical,codeSigning
subjectKeyIdentifier = hash
CNF

    "$OPENSSL" req -x509 -newkey rsa:2048 -sha256 -nodes \
        -days "$DAYS" \
        -config "${WORK_DIR}/openssl.cnf" \
        -keyout "${WORK_DIR}/key.pem" \
        -out "${WORK_DIR}/cert.pem" 2>/dev/null
}

import_identity() {
    local pass
    pass="$("$OPENSSL" rand -hex 16)"

    # Only used to move the identity into the Keychain; deleted with WORK_DIR.
    CERT_P12_PASS="$pass" "$OPENSSL" pkcs12 -export \
        -inkey "${WORK_DIR}/key.pem" -in "${WORK_DIR}/cert.pem" \
        -name "$IDENTITY" -passout env:CERT_P12_PASS \
        -out "${WORK_DIR}/identity.p12"

    log "Importing the identity into ${KEYCHAIN}..."
    security import "${WORK_DIR}/identity.p12" -k "$KEYCHAIN" -P "$pass" \
        -T /usr/bin/codesign -T /usr/bin/security >/dev/null
}

trust_certificate() {
    log "Trusting the certificate for code signing (macOS may ask for your password)..."
    security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "${WORK_DIR}/cert.pem"
}

authorize_codesign() {
    local kc_password

    [[ "$SET_PARTITION_LIST" -eq 1 ]] || {
        log "Skipping key partition list: the first signing will ask for permission."
        return 0
    }

    log "Allowing codesign to use the key without prompts."
    read_secret "Keychain password for ${KEYCHAIN##*/}" kc_password
    security set-key-partition-list -S apple-tool:,apple: -s \
        -k "$kc_password" -D "$IDENTITY" -t private "$KEYCHAIN" >/dev/null
}

write_backup() {
    local backup_pass confirm

    [[ -n "$BACKUP_P12" ]] || return 0

    read_secret "Password for the .p12 backup" backup_pass
    read_secret "Repeat the password" confirm
    [[ "$backup_pass" == "$confirm" ]] || die "Passwords do not match."

    (
        umask 077
        CERT_BACKUP_PASS="$backup_pass" "$OPENSSL" pkcs12 -export \
            -inkey "${WORK_DIR}/key.pem" -in "${WORK_DIR}/cert.pem" \
            -name "$IDENTITY" -passout env:CERT_BACKUP_PASS \
            -out "$BACKUP_P12"
    )
    log "Backup written to ${BACKUP_P12} (keep it private and safe)."
}

main() {
    parse_args "$@"
    require_tools security codesign /usr/bin/openssl sed

    if signing_identity_available "$IDENTITY"; then
        if [[ "$FORCE" -eq 0 ]]; then
            success "Identity '${IDENTITY}' already exists: nothing to do (use --force to replace it)."
            return 0
        fi
        log "Removing the existing identity '${IDENTITY}'..."
        security delete-identity -c "$IDENTITY" "$KEYCHAIN"
    fi

    WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/crixo-cert.XXXXXX")"
    trap cleanup EXIT
    chmod 700 "$WORK_DIR"

    generate_certificate
    import_identity
    trust_certificate
    authorize_codesign
    write_backup

    signing_identity_available "$IDENTITY" ||
        die "The identity was installed but is not visible as a code-signing identity (see: security find-identity -p codesigning)."

    log "SHA-1 fingerprint:"
    "$OPENSSL" x509 -in "${WORK_DIR}/cert.pem" -noout -fingerprint -sha1 >&2

    success "Identity '${IDENTITY}' is ready. Sign with: ./scripts/release/sign-app.sh --app-path <App.app>"
}

main "$@"
