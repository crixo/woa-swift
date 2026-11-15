# WOA: Xcode Project & Target Settings Reference

Notes on how Info.plist, build settings, and other Xcode configuration relate in this project (SwiftUI macOS app, Xcode 26, sandboxed, Sparkle auto-updates).

## Info.plist vs. Xcode settings

Info.plist and the target's Xcode settings are two views of the same data. At build time Xcode:

1. Reads the physical `Info.plist`
2. Substitutes `$(VARIABLES)` from build settings
3. Adds any generated keys (`INFOPLIST_KEY_*`)
4. Writes the merged result into the built app: `WOA.app/Contents/Info.plist`

The merged file is what macOS and Sparkle read at runtime.

### The `GENERATE_INFOPLIST_FILE` switch

| Value | Behavior |
|---|---|
| `NO` | Only the physical file (located by `INFOPLIST_FILE`) is used. The Info tab edits that file directly. |
| `YES` | Xcode generates keys from `INFOPLIST_KEY_*` build settings and merges in the physical file. On conflict, the file's values win. |

Check it in Target → Build Settings (search "Info.plist").

### Key-to-source mapping (current Info.plist)

| Key | Source of the real value |
|---|---|
| `CFBundleShortVersionString` = `$(MARKETING_VERSION)` | General → Version / Build Settings |
| `CFBundleVersion` = `$(CURRENT_PROJECT_VERSION)` | General → Build / Build Settings |
| `LSMinimumSystemVersion` = `$(MACOSX_DEPLOYMENT_TARGET)` | General → Minimum Deployments |
| `CFBundleExecutable` = `$(EXECUTABLE_NAME)` | Derived from `PRODUCT_NAME` |
| `CFBundleIdentifier` = `com.woa.application` | **Hardcoded**; not controlled by Xcode |
| `CFBundleName` = `WOA` | **Hardcoded** |
| `SU*` keys, copyright, category, principal class | The file itself |

### Rules of thumb

- Version, build number, bundle ID, deployment target: change in **General** or **Build Settings**, never hardcode in the plist.
- Permission strings, URL types, `LSApplicationQueriesSchemes`, etc.: Info tab or the plist directly.
- Sparkle `SU*` keys have no `INFOPLIST_KEY_` equivalent, so a physical Info.plist is required regardless.

## Project vs. target settings

- Project-level settings are defaults inherited by every target.
- Target-level settings override them.
- Info.plist is per target.

Precedence for a setting defined in multiple places (highest wins):

1. Target build settings
2. Target `.xcconfig`
3. Project build settings
4. Project `.xcconfig`
5. Xcode platform defaults

To see where a value comes from, open Build Settings and switch from "Combined" to **Levels**. From the terminal:

```
xcodebuild -showBuildSettings -target WOA
```

## Where Xcode stores everything

Almost everything is in **`WOA.xcodeproj/project.pbxproj`**: project and target build settings per configuration, targets, build phases, file references and groups, Swift Package dependencies, signing style and team, deployment targets, localization regions, and the Info tab's `INFOPLIST_KEY_*` values.

| What you see in Xcode | Where it's stored |
|---|---|
| Signing & Capabilities (sandbox, mach-lookup, etc.) | `WOA.entitlements`, via `CODE_SIGN_ENTITLEMENTS`; newer Xcode also has settings like `ENABLE_APP_SANDBOX` and `ENABLE_HARDENED_RUNTIME` merged into entitlements at build time |
| Info tab / Info.plist keys | `Info.plist`, plus `INFOPLIST_KEY_*` in the pbxproj if generation is on |
| Schemes (run args, env vars, configuration per action) | `WOA.xcodeproj/xcshareddata/xcschemes/*.xcscheme` if shared, else `xcuserdata/<user>.xcuserdatad/xcschemes/` |
| Resolved package versions | `.../project.xcworkspace/xcshareddata/swiftpm/Package.resolved` |
| App icon, accent color | `Assets.xcassets`, via `ASSETCATALOG_COMPILER_APPICON_NAME` etc. |
| Configuration files (Project → Info → Configurations) | `.xcconfig` files, if used |
| Breakpoints, window layout, scheme order | `xcuserdata/` (personal, normally gitignored) |

## Version control

- **Commit:** `project.pbxproj`, shared schemes, `Package.resolved`, `WOA.entitlements`, `Info.plist`.
- **Ignore:** `xcuserdata/`.
- Avoid hand-editing `project.pbxproj`; a stray edit can corrupt the project. It is still useful to read in diffs to see what a settings change did.

## Verifying what ships

Build, then right-click the `.app` in Products → Show in Finder → Show Package Contents → `Contents/Info.plist`. That merged file is the ground truth, regardless of what the Xcode editors show.

## Project-specific notes

- Sparkle feed: `SUFeedURL` points to `appcast.xml` at the repo root on `main`, served by `scripts/sparkle-appcast.sh`.
- `SUEnableInstallerLauncherService` is required because the app is sandboxed; it pairs with the mach-lookup entries in `WOA.entitlements`.
- `LSApplicationCategoryType` = `public.app-category.medical`.
