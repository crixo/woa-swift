# Code-signing certificate: creation, use and export

This describes the self-signed certificate used by `sign-app.sh` and the script
that creates it, `create-signing-certificate.sh`.

## Why a certificate

`sign-app.sh` signs the `.app` with a certificate from the Keychain (default
name: `DEFAULT_SIGN_IDENTITY` from `release-common.sh`, i.e. "CrixoDev"). For a
self-signed certificate the app's designated requirement is tied to the
certificate itself. Two releases signed with the **same** certificate have the
same requirement, which keeps Keychain "Always Allow" decisions valid across
updates. A **new** certificate breaks that.

Gatekeeper is not affected: a self-signed app is still "unidentified developer".

## Files

| File | Role |
|------|------|
| `scripts/release/release-common.sh` | Shared helpers and `DEFAULT_SIGN_IDENTITY` |
| `scripts/release/sign-app.sh` | Signs an `.app` with it |
| `scripts/tool/create-signing-certificate.sh` | Creates the certificate (run once per Mac); sources `../release/release-common.sh` |

## 1. Creation

```
./scripts/tool/create-signing-certificate.sh --backup-p12 ~/CrixoDev-backup.p12
```

Options:

| Option | Meaning |
|--------|---------|
| `--identity <name>` | Certificate common name (default `DEFAULT_SIGN_IDENTITY`). Use the same value with `sign-app.sh --identity`. |
| `--days <n>` | Validity in days (default 3650) |
| `--keychain <path>` | Target keychain (default: your default, normally login) |
| `--backup-p12 <path>` | Also write a password-protected `.p12` backup |
| `--no-partition-list` | Skip silent-access setup; first signing will prompt |
| `--force` | Replace an existing identity with the same name (changes the designated requirement) |

What the script does:

1. Generates an RSA 2048 key and a self-signed X.509 certificate with the
   Code Signing extended key usage (`/usr/bin/openssl`, because Homebrew
   OpenSSL 3 produces `.p12` files that `security import` rejects).
2. Imports key and certificate into the Keychain, allowing `/usr/bin/codesign`.
3. Marks the certificate as trusted for code signing. macOS may ask for your
   password.
4. Unless `--no-partition-list`, asks for your Keychain password (hidden
   prompt) so `codesign` can use the key without prompts.
5. With `--backup-p12`, asks twice for a password and writes the backup.
6. Checks that the identity is visible as a code-signing identity.

If the identity already exists the script does nothing, unless `--force`.

### Where passwords live

- **The private key has no password of its own.** It is generated unencrypted
  in a temporary directory (mode 700), deleted when the script exits, and after
  import it lives only in the Keychain, encrypted by the Keychain password
  (normally your login password).
- **Temporary `.p12` password:** random, in a shell variable only, never on
  disk. Passed to `security import -P` as an argument, so briefly visible in
  `ps` to local users; the file it protects is deleted seconds later.
- **Keychain password:** asked with a hidden prompt, used once, not stored
  (also briefly visible in `ps` as an argument).
- **Backup password:** asked twice, not stored. If you forget it, the backup
  cannot be opened.

## 2. Use

```
./scripts/release/sign-app.sh --app-path build/Crixo.app
```

No password is asked if the partition-list step was done. Otherwise macOS shows
a Keychain dialog the first time; click **Always Allow**.

## 3. Verify the signature

**What is verified:** the signed `.app` bundle (for example `build/Crixo.app`),
i.e. the exact artifact passed to `sign-app.sh --app-path`. `sign-app.sh` signs
only the `.app`, not the `.zip`/`.dmg` that may contain it. To verify a packaged
release, unzip it (or mount the `.dmg`) and check the `.app` inside, after any
step that could alter it. Verify the final copy you ship, not only the build
output.

`sign-app.sh` already runs checks 1 and 2 at the end. To repeat them by hand:

```
# 1. Integrity: validly signed, nothing modified afterwards (exit code 0 = OK)
codesign --verify --deep --strict --verbose=2 ./dist/WOA.app

# 2. Who signed it: expect Authority=CrixoDev
codesign -d --verbose=2 ./dist/WOA.app

# 3. Designated requirement: must be identical across releases
codesign -d -r- ./dist/WOA.app

# 4. Entitlements (for example the sandbox)
codesign -d --entitlements - ./dist/WOA.app
```

To confirm two releases were signed with the same certificate, compare the
`designated =>` line of check 3 for both `.app` bundles; the lines must match.

`spctl --assess --type execute --verbose ./dist/WOA.app` reports `rejected`.
This is expected for a self-signed, non-notarized app and does not mean the
signature is broken. Users open the app with right-click > **Open**.

## 4. Export

The key is imported as extractable, so it can be exported at any time. You need
your Keychain password and a new password for the `.p12`.

### Keychain Access (recommended)

1. Open Keychain Access, select the **login** keychain and **My Certificates**.
2. Find the certificate (it must show an expandable arrow with the private key).
3. Right-click it > **Export "CrixoDev"...**
4. Format **Personal Information Exchange (.p12)**, save, set a password.
5. Enter the Keychain password and click **Allow** if asked to give access to
   the key.

### Command line

```
security export -k ~/Library/Keychains/login.keychain-db \
    -t identities -f pkcs12 -o CrixoDev-backup.p12
```

This exports **all** identities of that keychain, not only this one, and
prompts for the `.p12` password. Prefer Keychain Access if you have other
certificates.

## 5. Restore on another Mac

```
security import CrixoDev-backup.p12 \
    -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign
```

The `.p12` does not carry trust settings. In Keychain Access open the
certificate > **Trust** > set **Code Signing** to **Always Trust**. Then check:

```
security find-identity -v -p codesigning
```

The restored certificate is the same one, so the designated requirement is
unchanged.

## Backup checklist

- Keep the `.p12` and its password in a safe place (password manager, offline
  storage), **not** in the repository.
- Redo the backup if you ever use `--force`, because that creates a new
  certificate.
- If the certificate expires (default 10 years), a new one means a new
  designated requirement.
