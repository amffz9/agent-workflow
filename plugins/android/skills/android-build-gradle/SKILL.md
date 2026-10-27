---
name: android-build-gradle
description: Configure, fix, and speed up Android builds — Gradle and the Android Gradle Plugin (AGP 9.x with built-in Kotlin, the new DSL and Variant API, AGP 10 migration), version catalogs (libs.versions.toml), convention plugins and build-logic, build types/flavors/variants, signing and release builds, App Bundles, R8/ProGuard keep rules and the R8 Configuration Analyzer, KSP/Compose compiler/Kotlin plugin setup, dependency conflicts and resolution errors, configuration cache and build performance, 16 KB page-size alignment for native libs, Gradle/AGP/Kotlin/JDK compatibility, and upgrading toolchains. Use this skill whenever a task edits build.gradle(.kts), settings.gradle(.kts), gradle.properties, libs.versions.toml, gradle-wrapper.properties, or proguard-rules.pro; whenever a build fails with a Gradle/AGP/dependency/manifest-merge error; and whenever the user says "build is slow", "upgrade AGP/Kotlin/Gradle", "add a dependency", "add a module/flavor", or "set up CI".
---

# Android build system (Gradle + AGP)

## Compatibility matrix (Sept 2026 — verify against release notes)

| AGP | Min Gradle | JDK | Max compileSdk | Notes |
|---|---|---|---|---|
| 9.4 | 9.6 | 17 | 37 | current stable; `analyzeReleaseR8Config`; variant parity checks |
| 9.3 | 9.5 | 17 | 37 | R8 Config Analyzer |
| 9.1–9.2 | 9.3–9.4 | 17 | 37 | Compose 1.12 requires ≥ 9.1.1 |
| 9.0 | 9.1 | 17 | 36 | **built-in Kotlin**, new DSL + Variant API default (`android.newDsl.optOut` escape hatch, removed in 10) |
| 8.13 | 8.13 | 17 | 36 | last 8.x |
| 10.0 (late 2026) | 9.x+ | 17+ | 37+ | new DSL/Variant API mandatory; per-module opt-out (`android.newDsl.optOut=:mod`) ends |

Kotlin 2.4.20 works with AGP 9.x; the Compose compiler plugin version = Kotlin version. KSP
version is `<kotlin>-<ksp>` (e.g. `2.4.20-2.0.x`) — mismatches are the #1 "unresolved KSP" error.
Check quickly: `./gradlew --version`, `grep -E "agp|kotlin|ksp" gradle/libs.versions.toml`,
`cat gradle/wrapper/gradle-wrapper.properties`.

## Project shape that works

```
settings.gradle.kts      pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
                         dependencyResolutionManagement { repositoriesMode = FAIL_ON_PROJECT_REPOS; repositories { google(); mavenCentral() } }
                         includeBuild("build-logic"); include(":app", ":core:ui", ":feature:feed")
gradle/libs.versions.toml   all versions/libraries/plugins
gradle.properties        org.gradle.jvmargs=-Xmx4g -XX:+UseParallelGC ; org.gradle.configuration-cache=true ; org.gradle.caching=true ; android.useAndroidX=true ; android.nonTransitiveRClass=true
build-logic/             convention plugins: AndroidApplicationConventionPlugin, AndroidLibraryConventionPlugin, AndroidComposeConventionPlugin, …
app/build.gradle.kts     plugins { alias(libs.plugins.myapp.android.application); alias(libs.plugins.myapp.android.compose) }
```

Minimal app module on AGP 9 (Kotlin built in — no `org.jetbrains.kotlin.android` plugin needed for
new projects; existing projects keep it until they follow "Migrate to built-in Kotlin"):

```kotlin
plugins { alias(libs.plugins.android.application); alias(libs.plugins.kotlin.compose); alias(libs.plugins.ksp) }
android {
    namespace = "com.example.app"; compileSdk = 37
    defaultConfig { applicationId = "com.example.app"; minSdk = 26; targetSdk = 36; versionCode = 42; versionName = "1.8.0"; testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner" }
    buildTypes {
        release { isMinifyEnabled = true; isShrinkResources = true; proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro"); signingConfig = signingConfigs.getByName("release") }
        debug { applicationIdSuffix = ".debug"; isDebuggable = true }
    }
    buildFeatures { compose = true; buildConfig = true }
    kotlin { compilerOptions { jvmTarget = JvmTarget.JVM_17 } }     // AGP 9 built-in Kotlin DSL; older: kotlinOptions { jvmTarget = "17" }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17; isCoreLibraryDesugaringEnabled = true }
    packaging { resources.excludes += "/META-INF/{AL2.0,LGPL2.1}" }
}
dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5") /* java.time etc. on minSdk < 26 */ }
```

Adding a dependency: put it in the catalog (`[libraries] foo = { module = "g:a", version.ref = "foo" }`),
reference as `implementation(libs.foo)`. Verify coordinates exist on Google Maven / Maven Central
(`android studio version-lookup g:a`, or search mvnrepository). Prefer BOMs (Compose, OkHttp,
Koin, Firebase) to align versions.

## Convention plugins (multi-module)

`build-logic/convention/build.gradle.kts` applies `kotlin-dsl`, depends on
`com.android.tools.build:gradle`, `org.jetbrains.kotlin:kotlin-gradle-plugin`,
`org.jetbrains.kotlin:compose-compiler-gradle-plugin`, and registers plugins:

```kotlin
class AndroidLibraryConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        pluginManager.apply("com.android.library")
        extensions.configure<LibraryExtension> { compileSdk = 37; defaultConfig.minSdk = 26; configureKotlinJvm(this); lint { warningsAsErrors = true } }
        dependencies { "implementation"(libs.findLibrary("kotlinx-coroutines-android").get()) }
    }
}
```

Use `androidComponents { onVariants { } }` (the Variant API) for build customization — never the
removed `applicationVariants`/`libraryVariants` (AGP 9 default DSL drops them; AGP 10 removes the
opt-out). Recipes: github.com/android/gradle-recipes.

## Variants, flavors, BuildConfig

- Flavors for real product differences (free/paid, staging/prod backends), not for debugging.
  `flavorDimensions += "env"; productFlavors { create("staging") { dimension = "env"; buildConfigField("String", "BASE_URL", "\"https://staging.example.com/\"") } }`.
- Dynamic feature modules must mirror the base app's flavor dimensions 1:1 (AGP 9.4 warns;
  AGP 10 fails).
- Secrets: never in the repo. Read from `local.properties`/env in Gradle
  (`providers.gradleProperty`/`environmentVariable`) into `buildConfigField`, or use the
  Secrets Gradle Plugin for `MAPS_API_KEY`-style manifest placeholders. See `android-security`.
- `resValue`/`manifestPlaceholders` for per-variant names/icons.

## Signing and release

```kotlin
signingConfigs { create("release") { storeFile = file(providers.gradleProperty("RELEASE_STORE_FILE").orElse("release.jks").get()); storePassword = providers.gradleProperty("RELEASE_STORE_PASSWORD").orNull; keyAlias = providers.gradleProperty("RELEASE_KEY_ALIAS").orNull; keyPassword = providers.gradleProperty("RELEASE_KEY_PASSWORD").orNull; enableV3Signing = true; enableV4Signing = true } }
```

Play App Signing holds the app signing key; you upload with an upload key. `./gradlew :app:bundleRelease`
→ `.aab`; test locally with `bundletool build-apks --bundle app.aab --output app.apks --local-testing`
+ `bundletool install-apks`. Android 17 adds APK Signature Scheme v3.2 (hybrid ML-DSA/PQC) —
AGP handles it when the toolchain supports it; nothing to do in most apps.

Play requirements: targetSdk 36+ (as of Aug 31, 2026); 16 KB page-size support; Developer
Verification for the account.

## R8 / shrinking

- Release always has `isMinifyEnabled = true` + `isShrinkResources = true`; full mode is default.
  Debug stays unminified (fast, debuggable).
- Keep rules: **narrow**. Keep only what is accessed reflectively (serialization via reflection,
  JNI, `Class.forName`, WorkManager workers referenced by name are fine — WorkManager keeps them).
  Prefer `-keepclassmembers`/`@Keep` on specific members over `-keep class com.example.** { *; }`.
  Libraries ship consumer rules; kotlinx.serialization, Retrofit 3, Room 3, Compose need none of yours.
- Analyze: `./gradlew :app:analyzeReleaseR8Config` → `app/build/reports/r8/r8-config-analyzer-release.html`
  (shrinking/optimization/obfuscation scores, per-rule impact, subsumed/unused/identical rules,
  library rules that block optimization). Iterate until scores are high, then run the release
  build's test suite.
- Debug an R8 problem: `-printconfiguration build/full-config.txt`, `-whyareyoukeeping class X`,
  `mapping.txt` retrace; add `-dontobfuscate` temporarily to isolate obfuscation vs shrinking.
- Library modules: `consumerProguardFiles("consumer-rules.pro")` for rules consumers need; keep
  them minimal (broad consumer rules degrade every downstream app).
- AGP 9.2+ D8 drops runtime-invisible annotations unconditionally — don't rely on them at runtime.

## Native libs & 16 KB pages

Required for Play (targetSdk 35+). NDK r28+ aligns by default; AGP 8.5.1+ packages with
`useLegacyPackaging=false` (uncompressed, 16 KB-aligned). Check an APK/AAB with
`scripts/check_16kb.sh app.apk` (uses `zipalign -c -P 16 -v 4` / `readelf`). Update third-party SDKs
that ship prebuilt `.so`s; test on a 16 KB emulator image (`android sdk install` a
`google_apis_ps16k` system image or enable "16 KB page size" in an Android 16+ emulator).

## Build performance

1. `org.gradle.configuration-cache=true` (and keep it green: no `project.` access at execution
   time in custom tasks, no `exec` in configuration phase), `org.gradle.caching=true`,
   `org.gradle.parallel=true` (default in recent Gradle).
2. JVM: `org.gradle.jvmargs=-Xmx4g -XX:+UseParallelGC -XX:MaxMetaspaceSize=1g`; `kotlin.daemon.jvmargs`
   similarly. Don't over-allocate on CI runners.
3. KSP over kapt everywhere (kapt disables incremental compilation for the module).
4. Modularize; avoid `api` leaks; `android.nonTransitiveRClass=true`; `android.nonFinalResIds=true`.
5. Avoid `allprojects { }`/cross-project configuration; use convention plugins.
6. `./gradlew --profile` or Build Analyzer (Studio) to find the slow task; `--scan` for deep dives.
7. Lint only on CI (`lintDebug`), not in every local build; `lint { checkDependencies = false }`.
8. **Lightbuild** (developer.android.com/tools/agents/lightbuild): Google's fast-feedback compile
   for agents — use it for quick "does it compile" loops when available.
9. Don't run `clean` habitually; don't `--rerun-tasks` unless diagnosing caching.

## Diagnosing failures

```bash
./gradlew :app:assembleDebug --console=plain 2>&1 | grep -nE "^e: |error:|Caused by|What went wrong|> Task .* FAILED" -A5 | head -80
./gradlew :app:dependencies --configuration debugRuntimeClasspath > <scratchpad>/deps.txt        # conflicts: "(*)" and "->" arrows
./gradlew :app:dependencyInsight --dependency kotlinx-coroutines-core --configuration debugRuntimeClasspath
./gradlew help --task :app:assembleDebug            # confirm task exists
./gradlew buildEnvironment                          # plugin classpath (AGP/Kotlin versions actually used)
./gradlew :app:assembleDebug --no-configuration-cache   # rule out CC issues once
```

| Error | Fix |
|---|---|
| `Unsupported class file major version 6x` | Gradle too old for the JDK; upgrade wrapper (`./gradlew wrapper --gradle-version 9.7.1`) or set JDK 17/21 via `org.gradle.java.home`/toolchains |
| `The project is using an incompatible version (AGP x) of the Android Gradle plugin. Latest supported version is y` | Studio/AGP mismatch; align |
| `Minimum supported Gradle version is 9.6` | update wrapper |
| `Duplicate class …` | two artifacts with the same classes (e.g. `kotlin-stdlib-jdk8` + `kotlin-stdlib`, or Room 2 + Room 3 collision in one module); `exclude` or align versions |
| `Could not find com.foo:bar:1.2` | typo/nonexistent version; missing repo; offline |
| `Namespace not specified` | add `namespace = "…"` (AGP 8+); remove `package` from manifest |
| `Manifest merger failed : Attribute … also present at …` | add `tools:replace="android:xyz"` or align the value |
| `Execution failed for task ':app:kspDebugKotlin'` | read the KSP error above: Room query/entity issue, Hilt missing binding, Moshi |
| `KSP version mismatch` / `ksp plugin was loaded with Kotlin x` | align `ksp` with `kotlin` in the catalog |
| `This version of the Compose Compiler requires Kotlin version x` | apply `org.jetbrains.kotlin.plugin.compose` with the same version as Kotlin |
| `Configuration cache problems found` | fix the reported task/plugin; temporary `--no-configuration-cache` |
| `INSTALL_FAILED_…` at `installDebug` | see `android-dev-workflow` |
| `applicationVariants` unresolved | AGP 9 new DSL; migrate to `androidComponents.onVariants` (or `android.newDsl.optOut` temporarily) |
| `Reason: Task ':app:mergeReleaseResources' ... resource shrinker` | keep needed resources via `res/raw/keep.xml` `tools:keep` |

## Upgrading

Order: Gradle wrapper → AGP (use the **AGP Upgrade Assistant** in Studio or Google's
`agp-9-upgrade` skill: `android skills add agp-9-upgrade`) → Kotlin + KSP + Compose compiler
together → AndroidX libraries (Compose BOM first) → third-party plugins. One PR per step; run the
full test suite and a release build after each. Read the AGP release notes' "behavior changes".
For compileSdk bumps also read `android-platform-compat`.

## CI skeleton (GitHub Actions)

```yaml
- uses: actions/setup-java@v4 { with: { distribution: temurin, java-version: 17 } }
- uses: gradle/actions/setup-gradle@v4
- run: ./gradlew lintDebug testDebugUnitTest validateDebugScreenshotTest --continue --no-daemon
- run: ./gradlew :app:pixel6Api37DebugAndroidTest   # needs KVM runner (ubuntu-latest has /dev/kvm; enable with sudo chmod)
- run: ./gradlew :app:bundleRelease                  # signing via secrets → env → gradle props
```
