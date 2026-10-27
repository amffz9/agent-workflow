# Profiling toolkit — commands and setups

## Benchmark build type (measure release-like without release signing)

```kotlin
android {
    buildTypes {
        create("benchmark") {
            initWith(getByName("release"))
            signingConfig = signingConfigs.getByName("debug")
            matchingFallbacks += listOf("release")
            isDebuggable = false
            isProfileable = true          // allows profilers/Macrobenchmark on non-debuggable builds
        }
    }
}
```

## Macrobenchmark module (`:macrobenchmark`)

```kotlin
plugins { id("com.android.test"); id("org.jetbrains.kotlin.android") }   // AGP 9: built-in Kotlin may make the second unnecessary
android {
    namespace = "com.example.macrobenchmark"; compileSdk = 37
    defaultConfig { minSdk = 28; testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner" }
    targetProjectPath = ":app"
    experimentalProperties["android.experimental.self-instrumenting"] = true
    testOptions.managedDevices.allDevices { create<ManagedVirtualDevice>("pixel6Api37") { device = "Pixel 6"; apiLevel = 37; systemImageSource = "aosp" } }
}
dependencies { implementation("androidx.benchmark:benchmark-macro-junit4:1.4.1"); implementation("androidx.test.uiautomator:uiautomator:2.4.0"); implementation("androidx.test.ext:junit:1.3.0") }
```

```kotlin
@RunWith(AndroidJUnit4::class)
class StartupBenchmark {
    @get:Rule val rule = MacrobenchmarkRule()
    @Test fun coldStartNoProfile() = startup(CompilationMode.None())
    @Test fun coldStartWithProfile() = startup(CompilationMode.Partial(BaselineProfileMode.Require))
    private fun startup(mode: CompilationMode) = rule.measureRepeated(
        packageName = "com.example.app", metrics = listOf(StartupTimingMetric()), iterations = 10,
        startupMode = StartupMode.COLD, compilationMode = mode,
    ) { pressHome(); startActivityAndWait() }
}

class ScrollBenchmark {
    @get:Rule val rule = MacrobenchmarkRule()
    @Test fun feedScroll() = rule.measureRepeated(
        packageName = "com.example.app", metrics = listOf(FrameTimingMetric(), TraceSectionMetric("Compose:recompose", mode = TraceSectionMetric.Mode.Sum)),
        iterations = 5, startupMode = StartupMode.WARM, compilationMode = CompilationMode.Partial(),
        setupBlock = { startActivityAndWait(); device.wait(Until.hasObject(By.res("feed")), 5_000) },
    ) { device.findObject(By.res("feed")).also { it.setGestureMargin(device.displayWidth / 5); it.fling(Direction.DOWN); it.fling(Direction.UP) } }
}
```

Run: `./gradlew :macrobenchmark:connectedBenchmarkAndroidTest` (or `pixel6Api37BenchmarkAndroidTest`
with GMD). Results in `macrobenchmark/build/outputs/connected_android_test_additional_output/`
as JSON + Perfetto traces. Use physical devices for final numbers; emulators for relative checks.

Compose: `Modifier.testTag("feed")` + `testTagsAsResourceId = true` on the root
`Modifier.semantics { }` so UiAutomator's `By.res` finds Compose nodes.

## Baseline Profile generation

```kotlin
// :baselineprofile module: plugins { id("com.android.test"); id("androidx.baselineprofile") }
class BaselineProfileGenerator {
    @get:Rule val rule = BaselineProfileRule()
    @Test fun generate() = rule.collect(packageName = "com.example.app", includeInStartupProfile = true) {
        startActivityAndWait()
        device.findObject(By.res("feed"))?.fling(Direction.DOWN)
        device.findObject(By.text("Profile"))?.click(); device.waitForIdle()
    }
}
// :app: plugins { id("androidx.baselineprofile") }; dependencies { baselineProfile(project(":baselineprofile")); implementation("androidx.profileinstaller:profileinstaller:1.4.1") }
// baselineProfile { automaticGenerationDuringBuild = false; saveInSrc = true }
```

`./gradlew :app:generateBaselineProfile` → `app/src/main/generated/baselineProfiles/baseline-prof.txt`
(and `startup-prof.txt`). Commit them; regenerate per release. Verify install on device:
`adb shell dumpsys package dexopt | grep -A3 <pkg>` shows `[status=speed-profile]` after
`adb shell cmd package compile -r bg-dexopt <pkg>`.

## Perfetto / system tracing

```bash
# Quick 10s trace with app + system tracks (see scripts/record_trace.sh)
adb shell perfetto -o /data/misc/perfetto-traces/trace.pftrace -t 10s \
  sched freq idle am wm gfx view binder_driver hal dalvik camera input res memory \
  --app com.example.app
adb pull /data/misc/perfetto-traces/trace.pftrace <scratchpad>/
# Open at https://ui.perfetto.dev (drag & drop) or Android Studio Profiler → Load trace
```

Custom sections: `androidx.tracing:tracing-ktx` `trace("LoadFeed") { … }` (Kotlin) /
`Trace.beginAsyncSection` for suspend work; Compose adds `Compose:*` sections automatically in
debug/profileable builds when `androidx.compose.runtime:runtime-tracing` is on the classpath.

Reading a trace, in order: main thread (look for long slices, `binder transaction`, `GC`),
`RenderThread`, then `Choreographer#doFrame` gaps, `Jank`/`Expected timeline` tracks, IO waits
(`block:block_rq_issue`), CPU frequency (thermal throttling), other processes stealing CPU.

## dumpsys quickies

```bash
adb shell am start -W -n <pkg>/.MainActivity          # TotalTime = TTID-ish
adb shell dumpsys gfxinfo <pkg> framestats            # per-frame timestamps; jank%; 90/95/99th
adb shell dumpsys gfxinfo <pkg> reset
adb shell dumpsys meminfo <pkg>                       # PSS by category; Views/Activities counts
adb shell dumpsys activity processes | grep -B2 -A8 <pkg>   # oom_adj, state
adb shell dumpsys batterystats --charged <pkg>
adb shell dumpsys package dexopt | grep -A4 <pkg>    # compilation status
adb shell cmd package compile -m speed-profile -f <pkg>     # force AOT with profile
adb shell cmd package compile --reset <pkg>          # back to JIT (measure 'no profile')
adb shell setprop debug.hwui.profile visual_bars      # on-screen frame bars
```

## Microbenchmark (pure Kotlin/JVM-ish code on device)

```kotlin
@RunWith(AndroidJUnit4::class) class ParserBenchmark {
    @get:Rule val rule = BenchmarkRule()
    @Test fun parse() = rule.measureRepeated { runWithMeasurementDisabled { json } .let { parser.parse(it) } }
}
```
Module: `androidx.benchmark:benchmark-junit4`; run with `testBuildType = "release"` and
`androidx.benchmark.suppressErrors` only when you must use an emulator.

## JankStats in production

```kotlin
val jankStats = JankStats.createAndTrack(window) { frame -> if (frame.isJank) analytics.jank(frame.states, frame.frameDurationUiNanos) }
PerformanceMetricsState.getHolderForHierarchy(view).state?.putState("screen", "Feed")
```

## ProfilingManager (in-the-field traces, API 35+)

```kotlin
val pm = context.getSystemService(ProfilingManager::class.java)
pm.requestProfiling(ProfilingManager.PROFILING_TYPE_SYSTEM_TRACE, params, "feed-scroll", mainExecutor) { result -> upload(result.resultFilePath) }
// API 37: pm.addProfilingTriggers(listOf(ProfilingTrigger.Builder(ProfilingTrigger.TRIGGER_TYPE_ANOMALY).build()))  // heap dump on memory-limit hit
```
Rate-limited by the system; use `androidx.core.os.Profiling` for a Flow-based wrapper.
