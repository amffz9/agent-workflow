# Debugging tools reference

## Android Studio (Quail 4, 2026)

| Tool | Where | Use for |
|---|---|---|
| Logcat | bottom tool window | `package:mine level:error`, folding, per-process |
| App Quality Insights | tool window | Crashlytics + Play vitals crashes/ANRs mapped to source; Gemini-assisted analysis |
| Layout Inspector | Running Devices / Tools | Compose tree, params, recomposition counts, 3D, overlaps |
| Network Inspector | App Inspection | OkHttp/Ktor(OkHttp)/HttpURLConnection calls; headers, bodies, timing; export |
| Database Inspector | App Inspection | Room/SQLite live tables and ad-hoc SQL (debuggable) |
| Background Task Inspector | App Inspection | WorkManager work status, chains, retries |
| Profiler | Profiler tool window | Tasks: system trace, callstack sample, Java/Kotlin method trace, heap dump (+ LeakCanary analysis), allocations, energy, live telemetry; works on `profileable` release builds |
| Device Explorer | tool window | Browse `/data/data/<pkg>` on debuggable apps; pull DB/prefs |
| Journeys | Gemini/Agent | natural-language UI tests with assertions |
| Agent mode + Android skills | Gemini | Studio bundles Google's skills; `/plan` planning mode |

Terminal equivalents: `android layout`, `android screen capture`, `android studio check <file>`,
`android studio analyze-file <file>` (requires Studio running with the project open).

## dumpsys cheatsheet

```bash
adb shell dumpsys activity activities        # task/back stack, resumed activity
adb shell dumpsys activity top               # top activity + its Views/Compose owners; ViewModel? no — but fragments
adb shell dumpsys activity services <pkg>    # running services, FGS types
adb shell dumpsys activity broadcasts | grep <pkg>
adb shell dumpsys activity exit-info <pkg>   # ApplicationExitInfo history (why it died)
adb shell dumpsys activity processes | grep -A10 <pkg>   # oom_adj, cached/foreground state
adb shell dumpsys window windows | grep -E "mCurrentFocus|mFocusedApp"
adb shell dumpsys input | grep -A5 "FocusedWindow"
adb shell dumpsys meminfo <pkg>
adb shell dumpsys gfxinfo <pkg>
adb shell dumpsys jobscheduler | grep -A40 "<pkg>"
adb shell dumpsys alarm | grep -A5 <pkg>
adb shell dumpsys deviceidle | head -20
adb shell dumpsys batterystats <pkg>
adb shell dumpsys package <pkg>              # versions, permissions, components, targetSdk, signing
adb shell dumpsys notification --noredact | grep -A8 <pkg>
adb shell dumpsys connectivity | grep -E "NetworkAgentInfo|Default"
adb shell dumpsys usagestats | grep -A3 <pkg>   # standby bucket
adb shell dumpsys dbinfo <pkg>               # SQLite connection/pool stats
adb shell cmd package list features | grep -i nfc
```

## Process & lifecycle experiments

```bash
adb shell am kill <pkg>                      # process death while backgrounded (state restore test)
adb shell am force-stop <pkg>                # full stop (no restore)
adb shell am send-trim-memory <pkg> RUNNING_CRITICAL
adb shell cmd uimode night yes|no            # dark mode
adb shell settings put system font_scale 1.3
adb shell wm size 1280x800 && adb shell wm density 240   # tablet window; reset: wm size reset / wm density reset
adb shell settings put global debug.force_rtl 1
adb shell settings put global window_animation_scale 0.5
adb emu rotate                               # emulator only
adb shell cmd window set-fixed-to-user-rotation enabled   # (newer builds) test orientation behavior
adb shell settings put global always_finish_activities 1  # "Don't keep activities"
```

## Compose-specific debugging

- `Modifier.testTag("…")` + `testTagsAsResourceId` → visible to UiAutomator/`android layout`.
- Recomposition counting in dev: `SideEffect { Log.d("Recomp", "$name") }` inside a composable
  (temporary), or Layout Inspector counts.
- `LocalInspectionMode.current` to detect previews.
- Debug why a composable isn't skipped: compiler reports (`android-performance`).
- Snapshot state issues: `Snapshot.withMutableSnapshot { }` misuse, reading state in a
  non-composable callback without `snapshotFlow`.
- Shared elements/animated bounds: `LookaheadAnimationVisualDebugging`.
- Lazy layout item state: hoist `rememberLazyListState()`; verify keys are unique with a quick
  `require(items.distinctBy { it.id }.size == items.size)` in debug.

## Crash reporting hygiene

- Upload `mapping.txt` (R8) and native symbols with every release (Play Console → App bundle
  explorer, or Crashlytics Gradle plugin `mappingFileUploadEnabled`).
- Log breadcrumbs at navigation and key actions; attach non-PII custom keys (screen, user tier).
- Use `Thread.setDefaultUncaughtExceptionHandler` only to *add* info — chain to the previous handler.
- Coroutine exceptions: install a `CoroutineExceptionHandler` in app scopes to log; ViewModel
  `viewModelScope` failures otherwise crash the app on the main thread.

## Reading a bugreport

`adb bugreport <scratchpad>/br.zip; unzip -q <scratchpad>/br.zip -d <scratchpad>/br`. Key files: `bugreport-*.txt`
(everything; search `ANR in`, `am_crash`, `am_proc_died`, `am_low_memory`), `FS/data/anr/`,
`FS/data/tombstones/`, `dumpstate_board.txt`. Use `grep -n "<pkg>" bugreport-*.txt | head` to
jump around.
