# Code-signing certificate

The local release scripts sign the app with a Keychain identity. The default
identity is `CrixoDev`, defined in
[`release-common.sh`](../scripts/release/release-common.sh). A self-signed
certificate keeps the app's designated requirement stable across releases
signed with the same identity; replacing it changes that requirement.

Self-signing does not make the app a Developer ID distribution and does not
notarize it. Gatekeeper can still identify it as an app from an unidentified
developer.

## Create the identity

The checked-in helper is in `scripts/tools/`:

```bash
bash scripts/tools/create-signing-certificate.sh \
  --backup-p12 "$HOME/CrixoDev-backup.p12"
```

The helper generates an RSA-2048 self-signed code-signing certificate using
`/usr/bin/openssl`, imports it into the selected Keychain, trusts it for code
signing, and configures codesign access unless `--no-partition-list` is used.
The optional backup is password-protected. The private key and temporary
files are removed from the helper's temporary directory after import.

| Option | Meaning |
|---|---|
| `--identity <name>` | Certificate name; default `CrixoDev` |
| `--days <n>` | Certificate lifetime; default 3650 days |
| `--keychain <path>` | Target Keychain; default is the user's default Keychain |
| `--backup-p12 <path>` | Create a password-protected backup |
| `--no-partition-list` | Allow codesign to prompt on first use |
| `--force` | Replace an existing identity; changes the designated requirement |

The identity is not recreated if it already exists unless `--force` is given.
Store the backup and its password securely outside the repository.

## Sign and verify

The release packager signs the extracted app by default. To sign an app
directly:

```bash
bash scripts/release/sign-app.sh \
  --app-path dist/WOA.app \
  --identity CrixoDev
```

Verify the final app bundle (not just the archive):

```bash
codesign --verify --deep --strict --verbose=2 dist/WOA.app
codesign -d --verbose=2 dist/WOA.app
codesign -d -r- dist/WOA.app
codesign -d --entitlements - dist/WOA.app
```

The designated requirement should match across releases signed with the same
certificate. `sign-app.sh` verifies the signature and signer at completion.

## Restore a backup

Import the `.p12` into the intended Keychain and trust its certificate for
code signing in Keychain Access. Then confirm it is available:

```bash
security find-identity -v -p codesigning
```

Do not share or commit the `.p12` or private key. See the helper's `--help`
output for supported import and backup options.
