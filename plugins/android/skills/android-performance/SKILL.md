---
name: android-performance
description: Measure and improve Android app performance — slow app startup, janky scrolling or animations, dropped frames, excessive recomposition in Compose, high memory use or OOM/LMK kills (including Android 17's strict memory limits), ANRs from slow main-thread work, battery drain, large APK/AAB size, R8/ProGuard optimization and keep rules, Baseline Profiles and Startup Profiles, Macrobenchmark/Microbenchmark, Perfetto/system tracing, Android Studio profilers, JankStats, and Android vitals. Use this skill whenever the user says slow, laggy, stutter, jank, freeze, lag, "takes forever to open", memory leak, OOM, "app got killed", battery, "reduce size", optimize, benchmark, profile, trace, or asks whether some code is efficient — even if they just want a code review with performance in mind. Always measure before and after; never guess.
---

# Android performance

The rule that matters most: **measure first, on a release-like build, on a real or representative
device**. Debug builds are 2–10× slower (no R8, JIT-only, debuggable overhead) and mislead every
intuition. Profile `release` (or a `benchmark` build type: minified, non-debuggable, with
`debuggable false` + `signingConfig debug` + `isProfileable true`).

## Workflow

1. **Define the metric and the target.** Startup (TTID/TTFD in ms), frame time (P50/P95, % janky
   frames, `frameOverrunMs`), memory (PSS/RSS, allocations), CPU time of a method, network bytes,
   APK size, battery (wake-ups, wakelock time).
2. **Reproduce and measure the baseline** with a benchmark or trace. Save the numbers.
3. **Find the hot spot** in the trace (main thread first, then binder/GC/IO), not in the code
   you *suspect*.
4. **Fix one thing, re-measure.** Keep the fix only if the metric moved.
5. **Guard against regression** with a Macrobenchmark in CI (or at least a documented manual
   benchmark) and Android vitals thresholds.

Google's tools in 2026: Android Studio Profiler (tasks: system trace, callstack sampling, heap
dump + **LeakCanary analysis**, allocations, energy), **Android Performance Analyzer (APA)** and
**App Performance Score** (developer.android.com/topic/performance/app-score) for a guided audit,
Perfetto (`adb shell perfetto` / `scripts/record_trace.sh`), Macrobenchmark
(`androidx.benchmark:benchmark-macro-junit4:1.4.x`), **R8 Configuration Analyzer**
(`./gradlew :app:analyzeReleaseR8Config`, AGP 9.3+), `ProfilingManager` for in-the-field traces
(API 35+, trigger-based on API 37), Play Console **Android vitals** for production data.
Commands and trace-reading tips: `references/profiling-toolkit.md`.

## Startup

Android vitals flags cold start ≥ 5 s, warm ≥ 2 s, hot ≥ 1.5 s as "excessive" — aim far lower
(cold TTID < 1 s on mid-range hardware). Measure with
`adb shell am start -W -n <pkg>/<activity>` (reports `TotalTime`) and Macrobenchmark
`StartupTimingMetric` (`timeToInitialDisplayMs`, `timeToFullDisplayMs` — call
`reportFullyDrawn()` / `ReportDrawn` composable when content is ready).

Checklist:
- **Enable R8 in release** (`isMinifyEnabled = true`, `isShrinkResources = true`) in **full mode**
  (default since AGP 8). Run the R8 Configuration Analyzer; a low optimization score means
  broad `-keep` rules (yours or a library's) are blocking inlining/class merging. Android 17's
  memory limits make R8 obfuscation/shrinking a memory win too.
- **Baseline Profiles** (`androidx.baselineprofile` Gradle plugin + a `:baselineprofile` test
  module; `BaselineProfileRule.collect { startActivityAndWait(); scroll/navigate key journeys }`).
  Store in `src/main/baselineProfiles/`; regenerate after big code changes (stale profiles match
  nothing — generate *after* R8 processing). Verify with Macrobenchmark
  `CompilationMode.Partial(baselineProfileMode = Require)` vs `None`. Typical win: 20–40 % cold
  start. Libraries ship their own; Compose does.
- **Startup Profiles** (DEX layout optimization) — same tooling with
  `includeInStartupProfile = true`; puts startup classes in the primary DEX. Needs R8.
- **`Application.onCreate` diet**: no synchronous network, DB, or SDK init that isn't needed for the
  first frame. Use the **App Startup** library (`androidx.startup`) or lazy DI (`Lazy<T>`, `Provider<T>`)
  and initialize SDKs off the main thread (`appScope.launch`). Measure each initializer with
  `Trace.beginSection`.
- **First screen**: don't block on a `ViewModel` that awaits network; show cached data instantly.
  Avoid `runBlocking` in `onCreate`. Keep the first composition small; defer heavy composables
  with `LaunchedEffect`-gated state or `Lazy*` layouts.
- **Splash**: `core-splashscreen` (`installSplashScreen()`), keep `setKeepOnScreenCondition` short.
- Check `adb shell dumpsys activity processes | grep -A2 <pkg>` for unexpected process starts
  (ContentProviders, WorkManager, push SDKs) and `Trace`/Perfetto "bindApplication" duration.

## Compose rendering performance (details: `references/compose-performance.md`)

- **Strong skipping is on by default** (Compose compiler with Kotlin 2.0.20+): composables with
  unstable params are still skipped if params are `===` equal, and lambdas are memoized. You
  mostly need: immutable data (`List`, `data class` with `val`s), `@Immutable`/`@Stable` on classes
  from other modules (or a `compose_compiler_config.conf` stability configuration file for
  third-party types), and to avoid creating new objects per composition.
- **Defer state reads** to the phase that needs them: `Modifier.offset { }`, `graphicsLayer { }`,
  `drawBehind { }` read state during layout/draw and skip recomposition. `derivedStateOf` for
  thresholds (`firstVisibleItemIndex > 0`).
- **Lazy lists**: `key` + `contentType`; fixed item sizes where possible; avoid nested scrollables;
  `LazyLayout` prefetch and pausable composition are on by default (Compose 1.10+) — scroll perf
  now matches Views in Google's benchmarks. Don't wrap the whole list in a `Card` with elevation
  (offscreen buffer).
- **Avoid backwards writes** (writing state that was read earlier in the same composition → loop).
- **Images**: request the display size (Coil does), don't decode on the main thread, use
  `ContentScale` not manual bitmaps.
- **Measure**: Layout Inspector recomposition counts (Studio), `ComposeCompilerReports`
  (`composeCompiler { reportsDestination = layout.buildDirectory.dir("compose_reports") }` → check
  `*-classes.txt` for `unstable` params and `*-composables.txt` for restartable/skippable), Macrobenchmark
  `FrameTimingMetric` on a scroll journey, Perfetto for "Compose:recompose"/"Compose:layout" slices.
- Text: Compose 1.12 TTID is now comparable to Views; if not, check fonts loading synchronously
  (use `FontLoadingStrategy.Async` / downloadable fonts).

## Memory

Android 17 enforces **strict per-app memory limits scaled to device RAM** and kills offenders
(`ApplicationExitInfo.getDescription() == "MemoryLimiter:AnonSwap"`). Treat memory as a hard budget.

- Measure: Profiler heap dump (now with LeakCanary analysis in Studio), `adb shell dumpsys meminfo <pkg>`
  (watch *Private Dirty*, *Graphics*, *Native*), `Debug.getNativeHeapAllocatedSize()`, Perfetto
  memory tracks. In the field: `ProfilingManager` trigger `TRIGGER_TYPE_ANOMALY` (API 37) captures
  a heap dump automatically when the limit is hit; `ApplicationExitInfo` tells you why the process died.
- Leaks: **LeakCanary** in debug (`debugImplementation("com.squareup.leakcanary:leakcanary-android")`)
  catches Activity/ViewModel/Fragment/View/Service leaks automatically. Usual culprits: static
  references to `Context`/`View`, listeners never unregistered (`DisposableEffect`), coroutines in
  `GlobalScope`, `ViewModel` holding a `Context`, anonymous inner classes in long-lived objects,
  `Handler` callbacks, RxJava disposables.
- Bitmaps are the #1 memory consumer: size to the view, use hardware bitmaps (Coil default),
  `inSampleSize`, evict caches on `onTrimMemory` (`ComponentCallbacks2`).
- Generational GC in Android 17 (backported via Play system updates to API 31+) reduces GC
  pauses; still avoid allocation storms in hot paths (`Modifier` chains in loops, boxing in
  `Flow<Int>`, string concatenation in draw).
- Native/JNI: `.so` size counts toward RSS; strip symbols (`android.packagingOptions.jniLibs.keepDebugSymbols`), 16 KB page alignment.
- Cache sizes: `LruCache` keyed to `ActivityManager.getMemoryClass()`; `cacheDir` files aren't
  RAM but count toward disk quotas.

## Main thread and ANRs

ANR = main thread blocked 5 s (input) / 10–20 s (broadcasts/services). Android vitals "bad" rate: 0.47 %.
- Never on main: disk I/O (even `SharedPreferences.apply` can block at commit), network, DB,
  bitmap decode, `Thread.sleep`, waiting on locks, `runBlocking`, heavy JSON parsing, reflection-heavy DI init.
- `StrictMode` in debug (`detectAll().penaltyLog()` for thread and VM policies) surfaces main-thread I/O early.
- Diagnose: `android-debugging` › ANR section (traces, Perfetto, `ProfilingManager`).
- Broadcast receivers must return in < 10 s; hand off to WorkManager. `Service.onStartCommand` too.
- Binder calls to system services can block (PackageManager queries, `getInstalledPackages`): cache results.

## Rendering (Views and mixed)

- `adb shell dumpsys gfxinfo <pkg> framestats` for frame stats; Profile GPU Rendering bars; Layout
  Inspector for overdraw and depth (Views: flatten hierarchies, `ConstraintLayout`, avoid nested weights).
- Target 16.6 ms (60 Hz) / 8.3 ms (120 Hz) per frame; the platform reports jank against the
  device's refresh rate. Use `JankStats` for production frame metrics per screen.
- Animations: never `invalidate()` in loops; use `RenderEffect`/`graphicsLayer` for blur/scale;
  offload to `AnimatedVectorDrawable`/Lottie only when needed.

## Battery & background

- Prefer **WorkManager** with constraints (charging, unmetered, idle) over alarms/timers; batch
  network; use `setExpedited` sparingly.
- Wakelocks: use `WorkManager` or `JobScheduler` instead; if you must, time-bounded
  (`acquire(timeout)`); Android vitals flags stuck partial wakelocks (> 1 h).
- Location: lowest accuracy/interval that works; passive/`FusedLocationProvider` batching; Android 17's
  session-based precise-location button avoids persistent grants.
- Sensors/GPS/camera off in `onStop`. Bluetooth scans batched.
- Doze/App Standby buckets: test with `adb shell cmd deviceidle force-idle` and
  `am set-standby-bucket`. Foreground services need a type (API 34+) and are limited (dataSync 6 h/day on 35+).
- Battery Historian / `adb shell dumpsys batterystats --reset` then reproduce then `dumpsys batterystats > out.txt`.

## App size

- App Bundles (`bundleRelease`) with Play Feature Delivery + asset packs; `android.enableR8.fullMode`
  (default); `isShrinkResources = true`; `resourceConfigurations`/`androidResources.localeFilters` to drop unused locales.
- Analyze: Android Studio **APK Analyzer** or `bundletool build-apks --mode=universal` +
  `unzip -l`; `./gradlew :app:analyzeReleaseR8Config` for kept code. Compare DEX method counts
  before/after.
- Images: WebP/AVIF, vector drawables for icons, no `ldpi/mdpi` rasters unless needed.
- Native libs: only needed ABIs via splits (bundles do this), `-Oz`/LTO, strip symbols, 16 KB alignment
  (required for Play since Nov 2025 for targetSdk 35+).
- Watch transitive dependencies (`./gradlew :app:dependencies`); prefer smaller libs (Coil over Glide
  in Compose apps; kotlinx.serialization over Gson+reflection).

## Verify (report numbers, not adjectives)

- Before/after table with the metric, device, build type, and iterations (Macrobenchmark
  default 5–10 iterations; report median).
- `adb shell am start -W` × 5, `dumpsys gfxinfo … framestats` deltas, `dumpsys meminfo` PSS deltas.
- Confirm no functional regression: run unit + UI tests; run lint (`ObsoleteSdkInt`,
  `UseCompatLoadingForDrawables`, etc.).
