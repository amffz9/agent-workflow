---
name: android-debugging
description: Diagnose and fix bugs in Android apps — crashes and stack traces (Kotlin/Java and native), ANRs and freezes, memory leaks and OOM kills, "it works on my device but not theirs", UI that doesn't update or looks wrong, state lost on rotation or process death, flaky behavior after backgrounding, network calls that fail, permissions denied, deep links not opening, WorkManager/services not running, and release-only bugs (R8/ProGuard, obfuscated traces). Covers logcat mastery, adb inspection, Android Studio profilers/inspectors, Layout Inspector and the Android CLI layout/screen tools, StrictMode, LeakCanary, bugreports, Play Console/Crashlytics traces, and Android 15/16/17 behavior-change gotchas. Use this skill whenever the user reports an error, exception, crash, ANR, freeze, "not working", "nothing happens", unexpected behavior, or pastes a stack trace or logcat output — before proposing any fix.
---

# Android debugging

Debugging is a search problem: shrink the hypothesis space with evidence before editing code.
Agents fail here by guessing a fix from the symptom. Get the trace, the log, or the screenshot
first — the tools below make that cheap.

## Triage loop

1. **Reproduce** with exact steps, device/API level, build type (debug vs release), and whether it's
   first launch / after update / after backgrounding. `adb shell getprop ro.build.version.sdk`.
2. **Capture evidence**: the full stack trace (not the first line), logcat around the event
   filtered by PID, a screenshot/layout dump for UI bugs, a trace for perf/ANR.
3. **Locate**: the first frame in *your* package in the trace; the last log line before the
   failure; the state at that moment (add a temporary `Log.d` if needed — remove it after).
4. **Hypothesize → test** with the smallest change (a log, a breakpoint-equivalent assertion, a
   unit test that reproduces).
5. **Fix the cause, add a regression test, verify on device**, then remove scaffolding.

Never silence an exception to "fix" a crash; never add `try/catch (Exception)` around the crash
site without understanding it; never bump a dependency version blindly to make an error go away.

## Logcat (know these cold)

```bash
PID=$(adb shell pidof -s <pkg>); adb logcat -v threadtime --pid=$PID          # your app only
adb logcat -v threadtime "*:E"                                                  # errors from anything (system too)
adb logcat -b crash -v threadtime                                               # crash buffer (survives app death)
adb logcat -e "ArticleRepository|SQLite" -v color                               # regex filter
adb logcat -s OkHttp:D WorkManager:D                                            # tags
adb logcat -v threadtime -T "$(date '+%m-%d %H:%M:%S.000')"                     # from now
adb logcat -d > <scratchpad>/logcat.txt                                                 # dump and exit
adb logcat -c                                                                   # clear before repro
adb shell setprop log.tag.MyTag VERBOSE                                         # enable Log.isLoggable(tag, VERBOSE)
```

`scripts/capture_crash.sh <pkg>` clears the buffer, waits for you to reproduce, and saves the
crash + surrounding app logs. What to look for: `FATAL EXCEPTION`, `AndroidRuntime`,
`Process ... has died`, `ANR in`, `Low memory killer`/`lmkd`, `StrictMode policy violation`,
`W/System.err`, `E/AndroidRuntime`, `Choreographer: Skipped N frames`, `E/SQLiteLog`,
`WindowManager: Activity … has leaked`, `libc: Fatal signal` (native), `MemoryLimiter`.

Android Studio's Logcat supports the same syntax (`package:mine level:error tag:OkHttp`).

## Crashes

- **Read the whole trace.** `Caused by:` chains: the *last* `Caused by` is the root cause. Find
  the first frame in your package (`at com.example...`) — that's where to look, even when the
  exception is thrown deep inside a library.
- **Release-only crash**: retrace with `mapping.txt` (`$ANDROID_HOME/cmdline-tools/latest/bin/retrace mapping.txt stacktrace.txt`,
  or upload mapping to Play/Crashlytics). Usually R8 removed/renamed something accessed by
  reflection (serialization, `Class.forName`, JNI) → add a *narrow* keep rule; verify with
  `./gradlew :app:analyzeReleaseR8Config`. Test release builds before shipping
  (`./gradlew :app:installRelease` with a debug signing config).
- **Native crash** (`Fatal signal 11 (SIGSEGV)`, `tombstone`): `adb logcat -b crash`, then
  symbolize with `ndk-stack -sym app/build/intermediates/merged_native_libs/... -dump <scratchpad>/logcat.txt`
  or `adb bugreport` → `FS/data/tombstones/`. Android 17: `System.load()` of writable `.so`
  files throws `UnsatisfiedLinkError` (targetSdk 37) — files must be read-only.
- **Common Android exceptions → cause**:

| Exception | Usual cause |
|---|---|
| `NetworkOnMainThreadException` | blocking network on main; use suspend/IO |
| `CalledFromWrongThreadException` / "Only the original thread…" | UI touched off-main |
| `IllegalStateException: ... has been destroyed` / "Fragment not attached" | using an Activity/Fragment after its lifecycle ended; scope work with `viewModelScope`/`repeatOnLifecycle` |
| `ForegroundServiceStartNotAllowedException` / `BackgroundServiceStartNotAllowedException` | FGS from background (API 31+); FGS type missing (34+); dataSync timeout (35+) |
| `SecurityException: Permission Denial` | runtime permission not granted / exported component / `ACCESS_LOCAL_NETWORK` (17) |
| `Resources$NotFoundException` | resource missing for a config/density; shrinkResources removed it; wrong `Context` |
| `ActivityNotFoundException` | no app handles the intent; on API 30+ add `<queries>` for package visibility |
| `TransactionTooLargeException` | > ~500 KB in Bundle/Intent/saved state; pass IDs, persist large data |
| `IllegalArgumentException: Navigation destination …` / Nav3 `SerializationException` on restore | missing entry / non-serializable `NavKey` |
| `SQLiteException: no such column` | migration missing or schema changed without version bump |
| `kotlinx.serialization.MissingFieldException` / `JsonDecodingException` | DTO doesn't match JSON; missing default/`ignoreUnknownKeys` |
| `NullPointerException` from Java interop / platform types | annotate Java APIs or use `?.`; check `!!` |
| `ConcurrentModificationException` | mutating a list while iterating (often from a `Flow` collector) |
| `IllegalAccessException` on reflection of `static final` | Android 17 targetSdk 37 — remove the hack |
| `NoClassDefFoundError`/`NoSuchMethodError` at runtime | dependency version conflict; `./gradlew :app:dependencyInsight --dependency <lib>` |
| `OutOfMemoryError` | bitmaps; leaks; see memory section |
| Compose `IllegalStateException: Vertically scrollable component was measured with an infinity maximum height` | lazy list inside a scrollable column |
| Compose `Key "x" was already used` | duplicate `key` in a lazy layout |
| Compose `Reading a state that was created after the snapshot…` | state created inside `remember` and read incorrectly; create before use |

## ANRs and freezes

- Signals: "App isn't responding" dialog; `ANR in com.example` in logcat; Android vitals.
- Get the main-thread stack at the moment: `adb pull /data/anr/` (debuggable/rooted) or
  `adb bugreport <scratchpad>/br.zip` → `FS/data/anr/anr_*` and `VM TRACES AT LAST ANR`. Look at
  thread `"main"` — is it waiting on a lock (`- waiting to lock <0x…> held by thread N`),
  in I/O (`FileInputStream.read`, `SQLiteConnection`), in binder (`BinderProxy.transactNative`),
  or in your code? Then find who holds the lock.
- Reproduce with **StrictMode** in debug builds (`Application.onCreate`):
  `StrictMode.setThreadPolicy(ThreadPolicy.Builder().detectAll().penaltyLog().penaltyFlashScreen().build())`,
  `setVmPolicy(VmPolicy.Builder().detectAll().penaltyLog().build())` — catches disk/network on
  main, leaked closables, leaked Activities.
- Record a trace during the freeze (`android-performance` › `scripts/record_trace.sh`) and inspect
  the main thread. `ProfilingManager` can capture traces in the field (API 35+).
- Watch for: `SharedPreferences` commit at `onPause`, synchronous `WorkManager.getWorkInfos().get()`,
  `runBlocking`, `Thread.join`, `Semaphore` waits, `ContentResolver` queries, `PackageManager`
  scans, `Bitmap.decode*`, JSON parsing of large payloads, Room without suspend (Room 3 forbids it).
- Broadcast receivers/services: `onReceive` must finish in 10 s → `goAsync()` + WorkManager.
- Input dispatch ANR with an idle main thread often means a *window* problem (dialog over a dead
  activity, `Window` focus stuck) — check `dumpsys window` and `dumpsys input`.

## Memory leaks and OOM/LMK

- Add **LeakCanary** (`debugImplementation("com.squareup.leakcanary:leakcanary-android:2.14")`);
  it reports a leak trace with the retaining chain. Android Studio Quail's Profiler runs the
  LeakCanary (Shark) analyzer on any heap dump (Profiler → "Find memory leaks" task).
- Manual: `adb shell am dumpheap <pkg> /data/local<scratchpad>/heap.hprof` → `adb pull` → open in
  Studio (converts to standard hprof). Or Profiler → Capture heap dump → "Leaks" tab.
- Process killed with no crash? `ApplicationExitInfo`
  (`activityManager.getHistoricalProcessExitReasons(pkg, 0, 5)`) → `REASON_LOW_MEMORY`,
  `REASON_ANR`, `REASON_CRASH_NATIVE`, or description `MemoryLimiter:AnonSwap` (Android 17 memory
  limit). `adb logcat | grep -E "lowmemorykiller|lmkd|Killing"`.
- `adb shell dumpsys meminfo <pkg>`: rising *Activities*/*Views* counts across navigation =
  leak; large *Graphics* = bitmaps; *Native* growth = JNI/OkHttp/native caches.
- Typical fixes: unregister in `DisposableEffect`/`onStop`; use `viewModelScope`; don't store
  `Context`/`View` in singletons/ViewModels; `WeakReference` is a smell, not a fix.

## UI doesn't update / looks wrong (Compose)

- **State not observed**: plain `var`/`MutableList` instead of `mutableStateOf`/
  `mutableStateListOf`; `Flow` collected with `collectAsState()` but never emitting; `remember`
  without keys holding stale values; `StateFlow` updated with `value = value.apply { … }` (same
  reference → no emission — use `copy`/`update`).
- **Inspect**: `android layout` (semantic tree with text, bounds, state), `android screen capture`,
  Android Studio **Layout Inspector** (Compose tree, parameters, recomposition counts, 3D view),
  `adb shell dumpsys activity top` for the activity/fragment state, `uiautomator dump`.
- **Nothing happens on click**: another composable intercepts touches (a transparent overlay, a
  `Box` with `clickable` above), `enabled = false`, the click handler reads a stale lambda
  (`rememberUpdatedState`), or the state changes but the reading composable was skipped (params
  unstable? see `android-performance`).
- **Wrong size/position**: modifier order; missing `innerPadding`; `fillMaxSize` in a lazy item;
  insets double-applied; window vs device size on large screens (`android-compose-ui` › adaptive).
- **Preview differs from device**: theme not applied in preview; `LocalInspectionMode` branches;
  resources missing in the preview module.
- Keyboard/IME: `Modifier.imePadding()` + `windowSoftInputMode="adjustResize"` (default on 30+ with
  edge-to-edge); `BringIntoViewRequester` for focused fields.
- Animation/shared-element oddities: wrap in `LookaheadAnimationVisualDebugging` (Compose 1.11).

## State lost on rotation / process death

- Rotation: values in composables without `remember`/`rememberSaveable`; `ViewModel` created
  manually per composition; `retain` for non-serializable. Android 17 no longer recreates the
  activity for several config changes — if you *depended* on recreation to reload, use
  `onConfigurationChanged` or `android:recreateOnConfigChanges`.
- Process death (the real test): background the app, then `adb shell am kill <pkg>`, reopen from
  recents. Fixes: `SavedStateHandle`, `rememberSaveable`/`rememberSerializable`, Nav3
  `rememberNavBackStack` with serializable keys, persist drafts to DataStore/Room. Developer
  option "Don't keep activities" for the activity-recreation subset.
- `TransactionTooLargeException` on save: you're saving too much (lists of DTOs); save IDs.

## Networking failures

- Use the **Network Inspector** (Studio → App Inspection) or a logging interceptor at `BASIC`.
- `UnknownHostException` → DNS/offline/emulator DNS (`-dns-server 8.8.8.8`); `SSLHandshakeException`
  → cert chain/pinning/CT/clock (`adb shell date`), user CA not trusted in release; `SocketTimeoutException`
  → server/latency, increase read timeout or fix backend; `CleartextTraffic` → NSC; `401` loops →
  authenticator bug; `EPERM` on LAN → `ACCESS_LOCAL_NETWORK` (Android 17).
- Emulator host = `10.0.2.2`; physical device = `adb reverse tcp:PORT tcp:PORT`.
- JSON mismatch → log the raw body once, compare with DTO (`ignoreUnknownKeys`, `@SerialName`, defaults).

## Background work not running

- WorkManager: `adb shell dumpsys jobscheduler | grep -A30 <pkg>` (constraints, next run), Studio
  **Background Task Inspector**, `WorkManager.getWorkInfosForUniqueWorkFlow`. Periodic work min
  interval is 15 min and is deferred by Doze; expedited work needs quota. Unique work with
  `KEEP` never re-enqueues — use `UPDATE`/`REPLACE` when parameters change.
- Test Doze/standby: `adb shell cmd deviceidle force-idle`, `adb shell cmd deviceidle unforce`,
  `adb shell am set-standby-bucket <pkg> rare`, `adb shell cmd jobscheduler run -f <pkg> <jobId>`.
- Foreground services: type declared in manifest + `startForeground(id, notif, type)`; started
  from background → exception (API 31+); `dataSync`/`mediaProcessing` 6 h limit (35+); Android 17
  background audio needs an FGS with while-in-use capability.
- Broadcasts: implicit broadcasts mostly don't reach manifest receivers since API 26; register
  at runtime with `RECEIVER_EXPORTED/NOT_EXPORTED` (required on 34+).
- Alarms: exact alarms need `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` and are denied by default on 33+.

## Permissions, intents, deep links

- `adb shell dumpsys package <pkg> | grep -A20 "runtime permissions"`; grant/revoke with
  `pm grant/revoke`; reset with `adb shell pm reset-permissions`.
- Deep link test: `adb shell am start -W -a android.intent.action.VIEW -d "https://example.com/p/1" <pkg>`;
  App Links verification state: `adb shell pm get-app-links <pkg>`; re-verify: `pm verify-app-links --re-verify <pkg>`.
- Package visibility (API 30+): `<queries>` for `resolveActivity`/`queryIntentActivities`.
- `PendingIntent` needs `FLAG_IMMUTABLE` or `FLAG_MUTABLE` (API 31+); background activity launches
  are blocked — Android 17 tightens `IntentSender` BAL; use `MODE_BACKGROUND_ACTIVITY_START_ALLOW_IF_VISIBLE`.

## Build/run-time environment issues

- "Works in Studio, fails in CLI": different JDK (`./gradlew -version`), missing `local.properties`,
  env vars (`ANDROID_HOME`), Gradle daemon with stale config cache (`--no-configuration-cache` once).
- `INSTALL_FAILED_UPDATE_INCOMPATIBLE` → uninstall (signature changed). `INSTALL_FAILED_INSUFFICIENT_STORAGE`
  → wipe emulator data. `INSTALL_FAILED_VERIFICATION_FAILURE` → Play Protect/Developer Verification;
  `adb shell settings put global verifier_verify_adb_installs 0` on test devices.
- App not visible on the device after install: it's a different variant/applicationId suffix
  (`.debug`). Check `adb shell pm list packages | grep <name>`.

## Android 15 / 16 / 17 gotchas that look like bugs

| Symptom | Cause (targetSdk) |
|---|---|
| Content under status/nav bars | Edge-to-edge enforced (35+); handle insets |
| Back gesture doesn't call `onBackPressed` | Predictive back enabled by default (36); use `OnBackPressedCallback`/`BackHandler` |
| App forced into a resizable/free-form window; orientation lock ignored | Large-screen restrictions ignored (36 opt-out, 37 mandatory) |
| Crash at start on 16 KB device (`dlopen` failure) | Native libs not 16 KB aligned |
| LAN/mDNS/cast discovery empty | `ACCESS_LOCAL_NETWORK` missing (37) |
| TLS fails on private CA | Certificate Transparency default-on (37) |
| Reflection on `MessageQueue`/`static final` crashes | Lock-free MessageQueue / final fields (37) |
| Process killed without crash, `MemoryLimiter:AnonSwap` | Android 17 memory limits |
| Audio focus/playback denied in background | Background audio hardening (17) |
| SMS OTP arrives 3 h late | SMS OTP protection (17); migrate to SMS Retriever |
| Activity not recreated on keyboard attach | Android 17 default; use `onConfigurationChanged` |
| Widget crashes with `IllegalArgumentException` on update | RemoteViews bitmap memory limit (37) |

Full lists: `android-platform-compat`.

## Debugging tools reference

`references/tools.md` — Android Studio inspectors (Layout, Network, Database, Background Task,
App Quality Insights), profiler tasks, `dumpsys` cheatsheet, Compose debugging helpers,
`scripts/capture_crash.sh` and `scripts/anr_dump.sh`.
