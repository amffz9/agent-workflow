# Android command-line cheatsheet for agents

Three layers, in order of preference: **Android CLI** (`android`, agent-first, 2026), **Gradle**
(`./gradlew`), **adb / emulator / sdkmanager** (always available, lowest level).

## Android CLI (`android`)

Install/update: download from https://developer.android.com/tools/agents, then `android update`.
`android init` installs the `android-cli` skill for detected agents. Check presence with
`command -v android`. Disable telemetry with `--no-metrics`. Persist flags in `~/.androidrc`
(e.g. `--sdk=/path/to/sdk`). Every command supports `-h`.

| Command | What it does |
|---|---|
| `android info` | SDK location, connected devices, env vars |
| `android create --name=<pkg> [--min-sdk N] [--dry-run]` | Scaffold a new project from a template |
| `android describe` | JSON metadata: modules, build targets, artifact (APK) output paths |
| `android sdk list / install / update / remove` | Manage SDK packages (platforms, build-tools, system images) |
| `android emulator list / create / start / stop / remove` | AVD management (templates like `medium_phone`, `large_desktop`; Windows emulator cmd currently disabled) |
| `android run` | Build → deploy → launch on a connected device/emulator |
| `android install <apk...>` | Incremental install (faster than adb) without launching |
| `android layout` | Semantic layout tree of the foreground app (Compose semantics + Views) |
| `android screen capture` | Screenshot of the device |
| `android screen resolve <query>` | Resolve a text/description query to on-screen node + bounds |
| `android docs search "<q>"` / `android docs fetch <url>` | Official Android Knowledge Base |
| `android skills find/add/list/update/remove` | Google's official skills (e.g. `android skills add r8-analyzer`) |
| `android studio check <file>` | Lint/inspections via a running Android Studio |
| `android studio analyze-file <file>` | Semantic analysis (symbols, errors) |
| `android studio find-declaration / find-usages` | IDE-quality navigation |
| `android studio render-compose-preview <file> [--preview <name>]` | Render a @Preview to PNG without a device |
| `android studio version-lookup <group:artifact>` | Latest/compatible library version |
| `android studio open-file <file>` | Open in the IDE |
| Journeys | Natural-language UI tests driven by your agent; see `android-testing` |

`android studio *` commands require a running Android Studio instance with the project open.

## Gradle

```bash
./gradlew tasks --all | grep -i <keyword>        # discover task names
./gradlew projects                                # module list
./gradlew :app:dependencies --configuration debugRuntimeClasspath   # resolved deps
./gradlew :app:dependencyInsight --dependency okhttp --configuration debugRuntimeClasspath

./gradlew :app:assembleDebug                      # APK at app/build/outputs/apk/debug/
./gradlew :app:bundleRelease                      # AAB at app/build/outputs/bundle/release/
./gradlew :app:installDebug                       # build + adb install
./gradlew :app:compileDebugKotlin                 # quickest compile check
./gradlew :app:testDebugUnitTest --tests "com.example.FooTest"
./gradlew :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.example.FooTest
./gradlew :app:lintDebug                          # report: app/build/reports/lint-results-debug.html
./gradlew :app:validateScreenshotTestDebug        # Compose preview screenshot tests (if configured)
./gradlew :app:analyzeReleaseR8Config             # R8 configuration analyzer report (AGP 9.3+)
./gradlew :app:generateBaselineProfile            # Baseline profile generation (needs device)

# Useful flags
--console=plain -q       # less noise for logs
--offline                # don't hit the network
--stacktrace / --info    # when a task fails without a clear message
--no-daemon              # CI
--configuration-cache    # on by default in new projects; keep it working
--scan                   # build scan (needs terms acceptance)
```

Build outputs: `app/build/outputs/`, reports: `app/build/reports/`, test results:
`app/build/test-results/`, mapping for release: `app/build/outputs/mapping/release/mapping.txt`.

## adb

```bash
adb devices -l                                   # list; use -s <serial> when >1 device
adb -s emulator-5554 shell ...                   # target a device
adb install -r -t app.apk                        # reinstall, allow test APK
adb install-multiple base.apk split.apk          # split APKs
adb uninstall <pkg>
adb shell pm list packages | grep <name>
adb shell pm clear <pkg>                         # wipe app data (fresh install state)
adb shell pm grant <pkg> android.permission.CAMERA
adb shell pm revoke <pkg> android.permission.POST_NOTIFICATIONS
adb shell am start -n <pkg>/<.Activity>
adb shell am start -W -a android.intent.action.VIEW -d "https://example.com/item/42" <pkg>   # deep link
adb shell am force-stop <pkg>
adb shell am kill <pkg>                          # simulate process death (background only)
adb shell pidof -s <pkg>
adb logcat -v threadtime --pid=<pid>
adb logcat -v threadtime "*:E"                   # errors only
adb logcat -e "regex"                            # regex filter
adb logcat -b crash                              # crash buffer
adb logcat -c                                    # clear
adb exec-out screencap -p > <scratchpad>/s.png
adb shell screenrecord /sdcard/r.mp4 --time-limit 30 && adb pull /sdcard/r.mp4 <scratchpad>/
adb shell input tap X Y | swipe X1 Y1 X2 Y2 300 | text "str" | keyevent KEYCODE_BACK
adb shell wm size                                # screen size (px)
adb shell wm density
adb shell settings put global window_animation_scale 0   # (and transition_, animator_) speed up UI tests
adb shell dumpsys activity activities | grep -E "mResumedActivity|topResumedActivity"
adb shell dumpsys window | grep mCurrentFocus
adb shell dumpsys meminfo <pkg>
adb shell dumpsys gfxinfo <pkg> framestats
adb shell dumpsys package <pkg> | grep -A3 -E "targetSdk|permission"
adb shell getprop ro.build.version.sdk           # device API level
adb shell getprop ro.build.version.release
adb bugreport <scratchpad>/bugreport.zip
adb pull /data/anr/ <scratchpad>/anr/                    # ANR traces (may need root/debuggable)
adb push local remote / adb pull remote local
adb reverse tcp:8080 tcp:8080                    # device localhost:8080 -> host:8080 (local backend)
adb shell cmd deviceidle force-idle              # simulate Doze
adb shell cmd appops set <pkg> RUN_IN_BACKGROUND deny
adb shell am set-standby-bucket <pkg> restricted
```

## Emulator / SDK (raw tools)

```bash
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --list | head -50
sdkmanager "platforms;android-37" "build-tools;36.0.0" "system-images;android-37;google_apis;arm64-v8a"
sdkmanager --licenses
avdmanager create avd -n api37 -k "system-images;android-37;google_apis;arm64-v8a" -d pixel_8
$ANDROID_HOME/emulator/emulator -avd api37 -no-window -no-audio -gpu swiftshader_indirect -no-boot-anim &   # headless (CI)
adb wait-for-device shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done'
emulator -list-avds
```

Choose `arm64-v8a` images on Apple Silicon, `x86_64` on Intel/AMD hosts with KVM/HAXM. Headless
emulators in CI need KVM (`ls /dev/kvm`); without it, use Gradle Managed Devices on a KVM runner or
Firebase Test Lab.

## Where files live

| Path | Content |
|---|---|
| `$ANDROID_HOME` (or `ANDROID_SDK_ROOT`) | SDK; `platform-tools/adb`, `emulator/`, `build-tools/<v>/` (aapt2, apksigner, zipalign, d8) |
| `~/.gradle/caches/` | Dependencies (grep here for sources/jars) |
| `~/.android/avd/` | AVDs |
| `local.properties` | `sdk.dir=` (never commit) |
| `~/.gradle/gradle.properties` | user-wide Gradle props (JVM args, signing secrets) |
