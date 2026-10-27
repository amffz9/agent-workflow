---
name: android-dev-workflow
description: The entry point for any work on an Android app or Kotlin Multiplatform app with an Android target. Use this skill whenever a task touches an Android project (build.gradle.kts, AndroidManifest.xml, app/ or feature modules, .kt files under src/main), whenever the user mentions Android, Jetpack, Compose, Gradle, adb, an emulator, an APK/AAB, or asks to build, run, install, test, or "make it work" on a device — even if they don't say "Android" and even for small edits. It teaches an agent how to orient in the project, build and run from the terminal (Gradle, Android CLI, adb), verify changes on a device or emulator, read build failures, and which sibling android-* skill to load next (UI, navigation, architecture, data, networking, performance, debugging, testing, build, platform compatibility, security).
---

# Android dev workflow (hub)

This is the hub of a family of Android skills. Load it first; it tells you how to work in an
Android project from a terminal and which specialized skill to read for the task at hand.

## Ecosystem snapshot (verify — this moves fast)

| Thing | State as of September 2026 |
|---|---|
| Latest platform | Android 17 = API 37 (stable June 16, 2026). Minor SDK releases 37.1/37.2 arrive as QPRs. |
| Google Play target requirement | New apps and updates must target API 36+ (since Aug 31, 2026). 16 KB page-size support required for apps targeting 15+ (since Nov 2025). |
| Android Studio | Quail 4 (2026.1.4) stable; Rabbit in canary. |
| AGP | 9.4 (Gradle ≥ 9.6, JDK 17+, Build Tools 36). AGP 10 lands late 2026 and makes the new DSL / Variant API mandatory. |
| Kotlin | 2.4.20 (K2 compiler; context parameters stable). |
| Compose | 1.12.x via BOM `2026.08.00`+ (requires compileSdk 37, AGP ≥ 9.1.1). Material 3 `1.4.x` (Expressive APIs mostly opt-in), Material 3 Adaptive `1.2.x`. |
| Navigation | Navigation 3 (`androidx.navigation3`) 1.1.x stable. Navigation 2 is maintenance. |
| Persistence | Room 3.0 (`androidx.room3`, KSP + coroutines only). Room 2.8.x is maintenance. DataStore 1.2.x. |
| Official stance | Android is **Compose-first**. Views, Fragments, RecyclerView, ViewPager are in maintenance mode (critical fixes only). |

When a version matters, don't guess from memory: check `gradle/libs.versions.toml`, run
`android studio version-lookup <group:artifact>` (Android CLI, needs a running Studio), or
query Google Maven (`https://maven.google.com/web/index.html`). Older training data will confidently
suggest stale versions, Nav2 `NavHost`, Room 2 `SupportSQLiteDatabase`, or `kapt` — check first.

## Step 1: Orient in the project (2 minutes, always)

Run `scripts/project_info.sh` (or do it by hand) to learn before you edit anything:

- **Build setup**: `settings.gradle.kts` (modules, plugin management), root `build.gradle.kts`,
  `gradle/libs.versions.toml` (versions), `gradle/wrapper/gradle-wrapper.properties`, `gradle.properties`
  (flags like `android.newDsl.optOut`, `org.gradle.configuration-cache`).
- **Targets**: `compileSdk`, `targetSdk`, `minSdk` in the app module. These gate which APIs and
  behavior changes apply (see `android-platform-compat`).
- **Stack**: Compose or XML Views? Nav3 or Nav2? Hilt/Koin/Metro? Retrofit/Ktor? Room 2 or 3? Detect
  from dependencies, not assumptions. Match the existing stack unless asked to migrate.
- **Conventions**: `build-logic/` or `buildSrc/` convention plugins, module naming (`:core:*`, `:feature:*`),
  lint/detekt/ktlint config, existing tests. Mirror them.
- **Agent context files**: `AGENTS.md`, `CLAUDE.md`, `.android/`, `.agents/`, README. Read them.

## Step 2: Build, install, run, verify — from the terminal

Prefer the **Android CLI** (`android`) when installed (`command -v android`); it is agent-first and
faster than raw adb. Fall back to Gradle + adb otherwise. See `references/cli-cheatsheet.md` for the
full command list.

```bash
# Environment and devices
android info                              # SDK path, connected devices, env vars
adb devices -l                            # fallback

# Emulator
android emulator list
android emulator create --template medium_phone --api 37   # names/flags: android emulator create -h
android emulator start <avd-name>

# Build + deploy + launch in one step (uses the project's Gradle config)
android run                               # add --module :app --variant debug --device <serial> as needed
./gradlew :app:installDebug && adb shell monkey -p <pkg> -c android.intent.category.LAUNCHER 1   # fallback

# Just build (fast feedback; do this after every meaningful edit)
./gradlew :app:assembleDebug --console=plain -q
./gradlew :app:compileDebugKotlin --console=plain -q      # fastest compile check for one module

# Look at what's on screen (do this instead of guessing the UI worked)
android screen capture --output <scratchpad>/screen.png           # then view the PNG
android layout                                            # semantic UI tree (Compose + Views)
android screen resolve "<text or description>"            # find a node to tap
adb exec-out screencap -p > <scratchpad>/screen.png               # fallback
adb shell uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml <scratchpad>/   # fallback

# Interact
adb shell input tap <x> <y>; adb shell input text "hello"; adb shell input keyevent KEYCODE_BACK

# Logs (filter by your app's PID so you aren't flooded)
adb logcat --pid=$(adb shell pidof -s <pkg>) -v threadtime
adb logcat -b crash -v threadtime            # crashes only

# Tests
./gradlew :app:testDebugUnitTest --console=plain
./gradlew :app:connectedDebugAndroidTest --console=plain   # needs a device/emulator
./gradlew :app:lintDebug --console=plain
```

Verification is not optional. A change to UI is verified with a screenshot or layout dump; a change
to logic is verified with a unit test or a logcat line; a change to build config is verified with a
clean-ish build (`./gradlew :app:assembleDebug`). Report what you verified and how.

### Working without a device

If no device/emulator can be started (CI container, no KVM), you can still:
- compile (`compileDebugKotlin`), run JVM unit tests, run Robolectric tests, run lint,
- run Compose Preview screenshot tests (host-side, Layoutlib),
- render a specific preview with `android studio render-compose-preview` if Studio is running.
Say clearly what you could not verify on-device.

## Step 3: Read failures properly

Gradle output is long; the actual error is usually one of these — find it with
`./gradlew ... 2>&1 | grep -nE "^e: |error:|FAILURE|What went wrong" -A 6`:

- `e: file:///...kt:LINE:COL` — Kotlin compile error. Fix at that exact location.
- `Unresolved reference` — missing import, wrong artifact, or API that doesn't exist in this version
  (common when training data is newer/older than the project). Check the version catalog.
- `Could not resolve ...` — dependency coordinates/version don't exist or repo missing. Verify on
  Google Maven / Maven Central before changing versions.
- `This version of AGP requires Gradle X` / `Unsupported class file major version` — toolchain
  mismatch (AGP ↔ Gradle ↔ JDK). See `android-build-gradle`.
- `Manifest merger failed` — conflicting manifest attributes; read the "Suggestion:" line.
- `Execution failed for task ':app:kspDebugKotlin'` — annotation processing (Room/Hilt/Moshi). The
  real message is a few lines above the task failure.
- `INSTALL_FAILED_*` — adb install issue (signature mismatch → uninstall first; insufficient storage;
  `INSTALL_FAILED_UPDATE_INCOMPATIBLE`).

Never "fix" a compile error by deleting the feature or suppressing warnings; fix the cause. If a
build is slow, don't run `clean` habitually — incremental builds and the configuration cache are the
default and `clean` throws them away.

## Step 4: Route to the right sibling skill

| Task smells like… | Read |
|---|---|
| Screens, composables, theming, layouts, lists, adaptive/large-screen, accessibility, XML→Compose | `android-compose-ui` |
| Navigating between screens, back stack, deep links, multi-pane navigation | `android-navigation` |
| ViewModels, state, repositories, DI (Hilt/Koin/Metro), modules, coroutines/Flow, KMP structure | `android-architecture` |
| Room/SQLite, DataStore, Paging, files, caching on disk | `android-data-persistence` |
| HTTP/REST/GraphQL/WebSockets, Retrofit/Ktor/OkHttp, serialization, images, offline sync, network security | `android-networking` |
| Startup time, jank, memory, battery, app size, R8, Baseline Profiles, benchmarks | `android-performance` |
| Crashes, ANRs, leaks, "it doesn't work", logcat, profiler, weird device behavior | `android-debugging` |
| Unit/UI/screenshot/instrumented tests, test flakiness, CI test setup, Journeys | `android-testing` |
| Gradle, AGP, version catalogs, build variants, signing, build speed, dependency conflicts, upgrades | `android-build-gradle` |
| targetSdk bumps, behavior changes (15/16/17), permissions, background work/FGS, Play requirements | `android-platform-compat` |
| Secrets, crypto, Keystore, auth/passkeys, Play Integrity, exported components, WebView, TLS | `android-security` |

Load more than one when the task spans areas (a new screen that calls an API and caches it = UI +
networking + data + architecture).

## Defaults for new code (when the project has no established convention)

- Kotlin + Jetpack Compose + Material 3. No new XML layouts, Fragments, or RecyclerView.
- Navigation 3 for navigation. Hilt for Android-only apps; Koin or Metro if the project is KMP.
- `ViewModel` + `StateFlow<UiState>` + unidirectional data flow; repositories over data sources.
- Coroutines/Flow for async; never RxJava or AsyncTask in new code.
- Retrofit + OkHttp + kotlinx.serialization (Android-only) or Ktor client (KMP).
- Room 3 for new databases (Room 2.8 if the project already uses Room 2 and isn't migrating).
- Coil 3 for images. WorkManager for deferrable background work.
- `compileSdk 37`, `targetSdk 36` (bump to 37 only after reviewing Android 17 behavior changes), `minSdk` per project (24–26 is typical in 2026).
- Version catalog (`libs.versions.toml`) for every dependency; KSP, never kapt.
- Write the unit test alongside the code; run it.

## Working style that avoids the classic agent failures

1. **Compile early, compile often.** A 40-line change with 3 compile errors is cheap to fix; a
   400-line change is not.
2. **Don't invent APIs.** If unsure whether `Modifier.foo()` exists in the project's Compose version,
   grep the Gradle cache (`find ~/.gradle/caches -name "*compose-ui*sources*"`) or check the docs
   (`android docs search "<query>"`) before writing code that uses it.
3. **Respect the target SDK.** APIs newer than `minSdk` need a `Build.VERSION.SDK_INT >= ...` guard or
   an AndroidX compat wrapper; lint (`NewApi`) will catch most, so run lint.
4. **One `Application`, one process, main thread rules.** Anything that blocks >100 ms belongs off the
   main thread; anything that touches UI belongs on it.
5. **Leave the repo better than you found it, not different.** Follow existing formatting (run
   `./gradlew ktlintFormat`/`spotlessApply` if configured), module boundaries, and naming.
6. **Say what you verified.** "Built `:app:assembleDebug` successfully, installed on emulator, screenshot
   shows the new button, unit tests green" beats "should work".
