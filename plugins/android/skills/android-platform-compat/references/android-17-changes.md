# Android 17 (API 37) behavior changes — detail and fixes

Official: developer.android.com/about/versions/17/behavior-changes-17 (targeting) and
/behavior-changes-all (all apps). Test on an API 37 emulator (`android emulator create --api 37`).
Toggle individual changes before targeting: `adb shell am compat enable|disable <NAME> <pkg>`
(`adb shell am compat list <pkg>` to see names).

## Targeting API 37

### Large screens: restrictions ignored, no opt-out
Ignored: `android:screenOrientation`, `setRequestedOrientation()`, `resizeableActivity="false"`,
`minAspectRatio`/`maxAspectRatio`, `PROPERTY_COMPAT_ALLOW_*` opt-outs. Games (Play category) exempt.
Fix: adaptive layouts; remove orientation locks; test in split-screen, desktop mode, App Bubbles.

### `ACCESS_LOCAL_NETWORK`
```xml
<uses-permission android:name="android.permission.ACCESS_LOCAL_NETWORK"/>
```
```kotlin
val launcher = rememberLauncherForActivityResult(RequestPermission()) { granted -> if (granted) discover() else showLanUnavailable() }
LaunchedEffect(Unit) { if (ContextCompat.checkSelfPermission(ctx, "android.permission.ACCESS_LOCAL_NETWORK") != PERMISSION_GRANTED) launcher.launch("android.permission.ACCESS_LOCAL_NETWORK") }
```
Affects: sockets to private IP ranges, multicast/mDNS (`NsdManager`), UPnP, casting SDKs (use the
Cast picker), Wi-Fi Direct, local HTTP servers. Symptoms: `EPERM`, empty discovery.

### Certificate Transparency default-on
Private/internal CAs (enterprise, staging) fail unless:
```xml
<domain-config><domain>internal.example.com</domain><certificateTransparency enabled="false"/></domain-config>
```

### Lock-free MessageQueue
Breaks: reflection on `mMessages`, `mNext`, `mIdleHandlers`, "sync barrier" hacks, some
testing/`Idling` libraries, older Robolectric/Espresso shadows. Fix: update test libraries; for
instrumentation use `TestLooperManager.peekWhen()`/`poll()`; remove reflection.

### `static final` immutable
`Field.set` on static finals → `IllegalAccessException`; JNI `SetStatic*Field` → crash. Common in
tests that flip `BuildConfig.DEBUG`/`Build.VERSION.SDK_INT` — inject those values instead
(`BuildVersionProvider` interface, `@Config(sdk=)` in Robolectric).

### Safer native dynamic code loading
`System.load(path)` requires the file to be read-only: `file.setReadOnly()` before loading, or
ship libs in the APK. Downloaded native code is a red flag anyway.

### Background audio hardening
Playing/requesting focus/changing volume while backgrounded needs a foreground service with
while-in-use capabilities (`mediaPlayback` FGS started while visible) — or exact alarm + alarm usage.
`AudioManager` calls from background otherwise fail (denied focus / `SecurityException`).
Media apps: keep the `MediaSessionService` + `mediaPlayback` FGS pattern (Media3 handles this).

### SMS OTP delay (standard SMS)
Replace `SMS_RECEIVED` readers with **SMS Retriever API** (`SmsRetriever.getClient(ctx).startSmsRetriever()`,
app hash in the message) or **SMS User Consent**. Also applies (for all apps) to WebOTP-format
messages with a domain mismatch.

### Background activity launch (BAL) via IntentSender
Replace `MODE_BACKGROUND_ACTIVITY_START_ALLOWED` with
`ActivityOptions.makeBasic().setPendingIntentBackgroundActivityStartMode(MODE_BACKGROUND_ACTIVITY_START_ALLOW_IF_VISIBLE)`.
Enable `StrictMode.VmPolicy.Builder().detectBackgroundActivityLaunchAbuse…` style checks and the
updated lint checks.

### Widgets: RemoteViews memory limit
Limit = 1.5 × screenW × screenH × 4 bytes for bitmaps + icons in one `updateAppWidget`. Exceeding
throws `IllegalArgumentException` (fatal). Fix: downscale bitmaps to widget size; use `Icon`
resources instead of bitmaps; Glance handles sizing.

### ContentCapture
`setContentCaptureEnabled(false)` is a no-op → `window.setFlags(FLAG_SECURE, FLAG_SECURE)` for
screens with sensitive data (also blocks screenshots/recording).

### Contacts Provider
`ACCOUNT_NAME`/`ACCOUNT_TYPE`/`ACCOUNT_TYPE_AND_DATA_SET` gone from `Data` view → join
`RawContacts` by `RAW_CONTACT_ID`. Queries on `Data` without `READ_CONTACTS` are strict
(`StrictColumns`/`StrictGrammar`) — malformed selections throw. Prefer the new contact picker.

### ECH / `<domainEncryption>`
Default enabled; disable per domain if a middlebox/server breaks: `<domainEncryption enabled="false"/>`.

### Password fields with physical keyboards
`show_passwords_physical` hides all characters; Compose 1.12 `BasicSecureTextField` uses
`TextObfuscationMode.System`. Custom password fields should follow (`RevealLastTyped` only as an
explicit user choice).

### Bluetooth RFCOMM `read()` returns -1 on close
Read loops must check `-1`, not only catch `IOException`.

### Accessibility text-change types
Custom `InputConnection`s: call `AccessibilityEvent.setTextChangeTypes()`; standard text fields do
it automatically.

## All apps on Android 17

### Memory limits
Limit scales with device RAM; exceeding → process killed; `ApplicationExitInfo.description ==
"MemoryLimiter:AnonSwap"`. Prepare: R8 full mode + config analyzer, bitmap discipline, trim caches
in `onTrimMemory`, `ProfilingManager` `TRIGGER_TYPE_ANOMALY` to capture heap dumps in the field.

### Activity recreation defaults
No recreate for `keyboard`, `keyboardHidden`, `navigation`, `touchscreen`, `colorMode` changes;
`onConfigurationChanged()` is called instead. If code assumed recreation (e.g. re-reading
resources that depend on color mode), add `android:recreateOnConfigChanges="colorMode"` or handle
the callback.

### Windowing
App Bubbles (any app), Bubble Bar on tablets, interactive desktop PiP. Your activity may be very
small and change size continuously; avoid work in `onSizeChanged`-driven code paths and don't
cache window metrics.

### Media/camera
CameraX < 1.5.2 crashes on Android 17 (dynamic range mode) — update to 1.5.2 or 1.6+. Media3 1.11+.
New: Eclipsa HDR video, RAW14, VVC/H.266 support (OEM), constant-quality recording, hearing-aid
routing (`TYPE_BLE_HEARING_AID`), dedicated Assistant volume stream.

### Privacy/pickers
Contact picker, customizable Photo Picker aspect ratio, system location button (session-scoped
precise location), EyeDropper API, persistent location indicator.

### NPU
Direct NPU use (LiteRT NPU delegate, NNAPI, vendor SDKs) requires `<uses-feature android:name="android.software.neural_processing_unit"…>`/`FEATURE_NEURAL_PROCESSING_UNIT` declaration.

### Post-quantum crypto
ML-DSA keys in Keystore on supported devices; APK Signature Scheme v3.2 (hybrid). No app changes required unless you sign manually.

### AppFunctions / Android MCP
Expose app capabilities as agent-callable functions (`androidx.appfunctions`, alpha; `@AppFunction`
on KDoc-documented suspend functions). Optional; see Google's `appfunctions` skill.

## Verification checklist after targeting 37

- [ ] App launches and every screen renders in phone, tablet split-screen, desktop window, bubble.
- [ ] No orientation lock in manifest (except games).
- [ ] LAN features prompt for `ACCESS_LOCAL_NETWORK` and degrade gracefully.
- [ ] TLS to all backends works (CT); staging with private CA configured.
- [ ] No reflection on `MessageQueue`/`static final`; tests updated.
- [ ] Background audio works via FGS; no `SecurityException` on focus.
- [ ] OTP flow uses SMS Retriever.
- [ ] Widgets update without `IllegalArgumentException`.
- [ ] Memory: PSS stays flat across navigation; LeakCanary clean; heap < limit on a 4 GB device.
- [ ] `adb shell am compat list <pkg>` shows expected changes enabled.
