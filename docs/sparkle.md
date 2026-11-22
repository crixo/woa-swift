# Sparkle updates

WOA links Sparkle from Swift Package Manager and configures it in
[`Info.plist`](../src/WOA/Resources/Info.plist). The app starts the updater at
launch. Automatic checks are enabled with a 24-hour scheduled interval, and
the app menu provides **Check for Updates…**.

The feed URL is
`https://raw.githubusercontent.com/crixo/woa-swift/main/appcast.xml`. The
checked-in feed contains signed `.app.zip` assets; GitHub Release DMGs are for
manual installation and are not the update enclosure.

## Signing and packaging

Sparkle update signatures use an EdDSA key. The public key is embedded as
`SUPublicEDKey` in the app's plist. Keep the matching private key in the
Keychain or supply an exported key file to the release script; never commit the
private key.

The local release sequence is:

1. Archive the app and package a signed app bundle as `.app`, `.app.zip`, and
   `.dmg`.
2. `scripts/release/sparkle-sign.sh` uses Sparkle's `generate_appcast` to sign
   the ZIP and update `appcast.xml`.
3. The version and appcast are committed and tagged.
4. The GitHub Release with the ZIP/DMG assets is created.
5. The tagged commit is pushed to `main`, publishing the feed.

The order ensures the feed is not live before its GitHub Release asset exists.
See [Build, release, and installation](build-and-release.md).

## Generate or back up keys

Sparkle's `generate_keys` utility is available with the Sparkle package tools.
It can create a signing key in the login Keychain and print the public key.
The release scripts search `SPARKLE_BIN`, `PATH`, and Xcode DerivedData for
`generate_appcast`; use `--sparkle-bin` when needed.

The orchestrator accepts `--ed-key-file <path>` for an exported EdDSA private
key. Protect backups and keep them outside the repository. Losing the private
key prevents signing future update archives that match the public key already
embedded in released apps.

## Check updates

Users can choose **Check for Updates…** from the app menu. Automatic checking
is also enabled. The app does not set Sparkle's automatic-download preference
in the checked-in plist; Sparkle's standard user prompts govern downloading
and installation.

## Validate and troubleshoot

`sparkle-sign.sh` validates the app's bundle version, public-key format,
configured feed URL, embedded Sparkle framework, ZIP version, generated
signature, enclosure URL, and appcast structure. It checks XML well-formedness
with `xmllint` when that utility is installed. To diagnose a missing update:

- Verify `SUFeedURL` and `SUPublicEDKey` in the built app's `Contents/Info.plist`.
- Confirm the appcast is published on `main` and its enclosure points to a
  publicly downloadable GitHub Release `.app.zip`.
- Confirm the ZIP asset exists and the appcast signature was generated with
  the private key matching the embedded public key.
- Use **Check for Updates…** to trigger a manual check. Scheduled checks are
  not expected to occur on every launch.
- Allow a short delay after publishing; `raw.githubusercontent.com` may cache
  the appcast.

WOA's release scripts use a self-signed code-signing certificate and do not
notarize the app. This is separate from Sparkle's EdDSA archive signature.
See [Code-signing certificate](SIGNING-CERTIFICATE.md).
