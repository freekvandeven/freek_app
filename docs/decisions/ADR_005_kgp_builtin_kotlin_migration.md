# ADR-005 — Kotlin Gradle Plugin (KGP) → Built-in Kotlin migration

## Date

2026-07-20

## Status

Accepted (partial migration now; full migration blocked, see Consequences)

## Context

Every Android build prints a Flutter Gradle Plugin warning: the app project itself, plus 8
plugins (`device_info_plus`, `file_picker`, `firebase_storage`, `home_widget`,
`package_info_plus`, `photo_manager`, `share_plus`, `wakelock_plus`), apply the standalone
Kotlin Gradle Plugin (KGP — `apply plugin: 'kotlin-android'` / `id("kotlin-android")`) instead
of relying on Flutter's newer "Built-in Kotlin" support, and "future versions of Flutter will
fail to build" as a result. `android/gradle.properties` already carries two flags Flutter's own
migrator added defensively: `android.builtInKotlin=false` and `android.newDsl=false`.

This ADR records a hands-on investigation (reading Flutter SDK's own Gradle plugin source,
downloading and inspecting each flagged plugin's Android build scripts across versions, and
running real debug/release Android builds with dependency overrides) into what the warning
actually means, what's fixable today, and what's genuinely blocked.

### What actually breaks, and when

Reading `flutter_tools/gradle/src/main/kotlin/FlutterPluginUtils.kt` and
`gradle_errors.dart` in the Flutter SDK clarifies the real mechanics:

- The warning is **advisory only** under the Android Gradle Plugin (AGP) version this project
  currently pins (8.11.1, in `android/settings.gradle.kts`). It does not fail the build today.
- The **actual hard failure** only happens once AGP is bumped to 9.0+: AGP 9 makes Kotlin
  support built-in at the AGP level and rejects `apply plugin: 'org.jetbrains.kotlin.android'`
  outright ("The 'org.jetbrains.kotlin.android' plugin is no longer required for Kotlin support
  since AGP 9.0" — `gradle_errors.dart`'s `applyingKotlinAndroidPluginErrorHandler`). AGP 9.x is
  already released upstream (9.3.0 stable as of this writing) but this project has not adopted
  it — that's a separate, larger migration (Gradle wrapper bump, AGP's own breaking changes,
  possibly the `android.newDsl` flag) and is out of scope here.
- `android.builtInKotlin` is written by Flutter's Dart-side migrator
  (`disable_built_in_kotlin_migration.dart`) but is **not read anywhere** in the currently
  installed Flutter SDK's Gradle-side Kotlin sources (verified by exhaustive grep). Flipping it
  had zero observable effect in testing. It's almost certainly a placeholder for an AGP-9-level
  flag that only takes effect once AGP itself is upgraded — there's nothing to gain from
  touching it while pinned to AGP 8.x, and no reason to believe it's safe to touch blindly
  before that upgrade is actually planned.
- Flutter's own advisory detector (`detectApplyingKotlinGradlePlugin`) works by **regex-matching
  the raw text** of each subproject's `build.gradle`/`build.gradle.kts`, not by evaluating
  Groovy/Kotlin control flow. For `.kts` files it only matches the declarative
  `plugins { id("kotlin-android") } ` block form — an imperative `apply(plugin = "...")` call,
  even unconditional, is invisible to it. For `.gradle` (Groovy) files it matches **both** the
  declarative form and the legacy `apply plugin: '...'` line, and that legacy-line match fires
  even when the line sits inside an `if` block, since regex has no notion of the surrounding
  braces. This explains a result that looked like a contradiction during testing: bumping
  `device_info_plus`/`package_info_plus`/`share_plus` (all migrated to `.kts` with an
  `if (agpMajor < 9) apply(plugin = "...")` guard) cleared them from the warning immediately,
  while `file_picker`'s prerelease (`12.0.0-beta.1`, same guard but written in Groovy) stayed
  flagged despite being functionally just as AGP-9-safe.

### Per-plugin status (checked against each plugin's latest published version, including
### prereleases, via pub.dev's API and by downloading and inspecting `android/build.gradle*`)

| Plugin | Current | Fix released? | Blocker |
|---|---|---|---|
| `device_info_plus` | 11.5.0 (transitive) | Yes, 13.1.0+ (`.kts`, AGP-version-gated) | Capped `<12.0.0` by `super_native_extensions` (no newer release relaxes this — powers `super_clipboard`/`super_drag_and_drop`, WISH-0072/WISH-0077), **and** 13.x requires `win32 ^5.11.0`+, cascading into the win32 conflict below |
| `package_info_plus` | 9.0.1 | Yes, 10.0.0+ (`.kts`, AGP-version-gated) | 10.x requires `win32 ^6.0.0`+ (jumped exactly at the same release as the Kotlin fix) |
| `share_plus` | 10.1.4 | Yes, 13.0.0+ (`.kts`, AGP-version-gated) | Same story: 13.0.0 is where both the Kotlin fix and the `win32 ^6.0.0` jump land together; every 10.x–12.x release keeps the old unconditional Groovy `apply plugin` |
| `wakelock_plus` | 1.5.2 | **No** — even latest (1.6.1) still applies KGP unconditionally in Groovy | Needs an upstream fix; 1.6.1's only relevant change is requiring `package_info_plus ^10.1.0` |
| `file_picker` | 11.0.2 (already latest **stable**) | Only in a **prerelease** (`12.0.0-beta.1`), and even that doesn't clear Flutter's advisory warning (Groovy legacy-line detection, see above) | No stable release exists; the beta additionally requires `win32 ^6.0.1`, which is the same version the other three need |
| `firebase_storage` | 13.4.3 (13.4.5 resolvable) | **No** — latest (13.4.5) still applies KGP unconditionally | Upstream fix needed |
| `home_widget` | 0.9.3 (already latest) | **No** — 0.9.3 is the newest release that exists at all, still unconditional | Upstream fix needed |
| `photo_manager` | 3.9.0 (3.10.0 resolvable) | **No** — latest (3.10.0) still applies KGP unconditionally | Upstream fix needed |

The **win32 cluster** (`device_info_plus`, `package_info_plus`, `share_plus`, `wakelock_plus`,
`file_picker`) is a single all-or-nothing unit: their Kotlin fixes shipped in the exact same
release that bumped their Windows-desktop `win32` dependency to `^6.x`, and the only package
that provides a `win32 ^6`-compatible release is `file_picker`'s beta — which a fully-overridden
test build proved still doesn't satisfy Flutter's advisory detector (Groovy legacy-line
matching) and, separately, hit a real Kotlin compile error inside `share_plus 13.2.1`'s own
sources during testing. Adopting a prerelease dependency app-wide, for a fix that wouldn't even
clear the warning, is not worth the risk.

The remaining three (`firebase_storage`, `home_widget`, `photo_manager`) have no fix at any
published version — nothing to sweep to yet.

## Options Considered

### Option 1 — Do nothing until AGP 9 is adopted

- **Pros**: No risk of the stale-cache/compile surprises hit during testing (see Consequences);
  defers all effort to a single future pass.
- **Cons**: Leaves the app-level fix (proven safe, see below) undone for no reason; risks
  discovering the full scope of blockers *during* a future Flutter/AGP upgrade instead of ahead
  of it, which is exactly what this item was filed to avoid.

### Option 2 — Force the win32 cluster onto the beta/major versions now via `dependency_overrides`

- **Pros**: Would clear 3 of 8 plugins from the warning list.
- **Cons**: Pins a prerelease (`file_picker 12.0.0-beta.1`) in a shipping app; doesn't even
  fully work (Groovy detection gap, and a real `share_plus 13.2.1` compile failure surfaced
  during testing); `device_info_plus` stays blocked regardless via `super_native_extensions`.
  Rejected as not worth the risk for an incomplete, non-functional result.

### Option 3 — Fix only what's proven safe today (app-level KGP), document the rest, defer the plugin sweep

- **Pros**: Captures the one genuinely safe, zero-risk improvement now (removing the app
  module's own explicit KGP application); leaves a precise, evidence-based record — instead of
  a vague "revisit later" — of exactly which plugins are blocked and why, so a future pass (or
  the eventual AGP 9 upgrade) starts from a clear map instead of rediscovering all of this from
  scratch.
- **Cons**: The 8-plugin warning persists until upstream releases catch up.

## Decision

**Option 3.** Removed the explicit `id("kotlin-android")` from `android/app/build.gradle.kts`
(see IMPR-0022). Flutter's built-in per-module Kotlin injection
(`pluginManager.apply("kotlin-android")`, triggered whenever a subproject's build script no
longer declares KGP itself) picks it up automatically — verified with clean debug **and**
release Android builds; the app-level half of the warning is gone, the plugin classes still
link correctly, and behaviour is unchanged. This required a `flutter clean` in testing because
an earlier `dependency_overrides` experiment (used to verify the regex-detection behaviour
described above) had left `android/build/` in a state referencing package versions no longer in
`pubspec.lock` — worth knowing if this surfaces again during any future gradle-config change.

`android.builtInKotlin` and `android.newDsl` in `android/gradle.properties` are **left
untouched** — testing showed the built-in-Kotlin flag has no observable effect while pinned to
AGP 8.x, and flipping either flag without an actual AGP 9 upgrade in flight would be guessing
ahead of evidence.

The 8-plugin warning is **not** resolved by this change and can't be, safely, until:
- `wakelock_plus`, `firebase_storage`, `home_widget`, and `photo_manager` ship an upstream fix
  (currently: no fix at any released version, including latest), and
- `file_picker` ships a **stable** (non-beta) release compatible with `win32 ^6`, which in turn
  unblocks `package_info_plus`, `share_plus`, and `wakelock_plus` moving together, and
- `super_native_extensions` (via `super_clipboard`/`super_drag_and_drop`, WISH-0072/WISH-0077)
  raises its `device_info_plus <12.0.0` cap, or this app stops depending on it.

## Consequences

- The app module itself is now genuinely forward-compatible with Flutter's Built-in Kotlin
  support and, eventually, AGP 9 — one less thing to worry about when that upgrade happens.
- The remaining 8-plugin warning is expected and can be ignored until the trigger conditions
  above change — re-run `flutter pub outdated` and re-check each plugin's `android/build.gradle`
  (or `.kts`) periodically, or re-read this ADR before the next Flutter SDK major upgrade.
- Do not attempt to force the win32 cluster forward via `dependency_overrides` again without
  first confirming `file_picker` has shipped a **stable** release — the beta path was tested
  here and doesn't fully work.
- If `super_native_extensions` becomes the last blocker on `device_info_plus` after the win32
  cluster is otherwise resolved, that's a separate cost/benefit call (drop clipboard-paste /
  drag-and-drop image upload vs. stay pinned) for whoever picks this back up.
