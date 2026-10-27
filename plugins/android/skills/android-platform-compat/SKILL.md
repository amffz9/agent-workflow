---
name: android-platform-compat
description: Keep Android apps compatible with current platform versions and Google Play policy — bumping targetSdk/compileSdk (to 36 or 37), the behavior changes in Android 15, 16, and 17 (edge-to-edge enforcement, predictive back, large-screen resizability, 16 KB pages, memory limits, lock-free MessageQueue, static-final enforcement, local network permission, certificate transparency, background audio hardening, SMS OTP delays), runtime permissions and the newer privacy pickers (photo picker, contact picker, session location), foreground service types and background execution limits, WorkManager and alarms, notifications, app links, minSdk/API-level guards, and Play requirements (target API deadlines, 16 KB, Developer Verification). Use this skill whenever the task mentions targetSdk, compileSdk, API level, "Android 17", "update for the latest Android", permissions, "app got rejected", Play Console warnings, foreground services, background work, Doze, notifications, or behavior that differs across Android versions.
---

# Android platform compatibility

## Where things stand (September 2026)

- **Android 17 = API 37**, stable June 16, 2026. Minor SDK releases (37.1 in QPR1, 37.2 in QPR2)
  add APIs behind `SdkExtensions` checks.
- **Google Play**: new apps and updates must target **API 36+** (since Aug 31, 2026; extension
  to Nov 1 on request). Existing apps must target 35+ to stay visible to new users on newer
  devices. Wear/Auto: 35+; TV/XR: 34+. Apps targeting 15+ must support **16 KB page sizes**
  (since Nov 1, 2025). **Developer Verification** (identity verification for all developers
  distributing to certified devices) is rolling out in 2026 — check the Play Console.
- Recommended: `compileSdk = 37` (required by Compose 1.12+), `targetSdk = 36` now, `37` once
  you've worked through the Android 17 list below. `minSdk` 24–26 covers ~99 % of active devices.

## targetSdk bump procedure

1. Bump `compileSdk` first (compile against new APIs; fix deprecations/lint), keep `targetSdk`.
2. Read **both** behavior-change pages for each version you skip:
   `developer.android.com/about/versions/<N>/behavior-changes-all` (affects everyone on that OS)
   and `behavior-changes-<N>` (only when targeting). Check the compatibility framework toggles:
   `adb shell am compat enable <CHANGE_NAME> <pkg>` lets you test a change before targeting.
3. Bump `targetSdk`; run the app on an emulator with that API and on the newest; walk every
   screen and background feature; run instrumented tests.
4. Fix, then check Play Console pre-launch report and Android vitals after rollout.
Use Studio's **Android SDK Upgrade Assistant** for a guided checklist.

## Android 17 (API 37) — what breaks (`references/android-17-changes.md` has the full list)

Targeting 37:
- **Large screens**: orientation/resizability/aspect-ratio restrictions ignored with no opt-out
  (games exempt). Make layouts adaptive (`android-compose-ui`).
- **Local network**: `ACCESS_LOCAL_NETWORK` runtime permission (or system pickers) for LAN
  traffic — casting, mDNS/NSD, IoT, printers, local dev servers on a LAN.
- **Certificate Transparency on by default**: private CAs need per-domain opt-out in NSC.
- **Lock-free `MessageQueue`**: reflection on its internals breaks; use `TestLooperManager.peekWhen/poll`
  in tests.
- **`static final` truly final**: reflection/JNI writes throw/crash. Remove test hacks that flip
  constants.
- **Safer native DCL**: `System.load()` only from read-only files.
- **Background audio hardening**: background playback/focus/volume needs a while-in-use FGS or
  exact-alarm + `USAGE_ALARM`.
- **SMS OTP**: standard OTP SMS delayed 3 h for non-default apps → use SMS Retriever / User Consent.
- **BAL hardening** for `IntentSender`; use `MODE_BACKGROUND_ACTIVITY_START_ALLOW_IF_VISIBLE`.
- **Widgets**: RemoteViews bitmap+icon memory limit → crash on excess.
- **ContentCapture**: `setContentCaptureEnabled(false)` no longer works; use `FLAG_SECURE`.
- **Contacts Provider**: PII columns removed from `Data` view; strict SQL without `READ_CONTACTS`.
- **ECH** (Encrypted Client Hello) used when possible; `<domainEncryption>` to control.
- **Passwords with physical keyboards** hide the last character by default (Compose 1.12 follows).
All apps on 17: **memory limits** (process killed at the limit; `MemoryLimiter:AnonSwap`),
generational GC, activity not recreated for keyboard/nav/touchscreen/color-mode config changes
(`onConfigurationChanged` instead; `android:recreateOnConfigChanges` to opt in), App Bubbles /
Bubble Bar / interactive PiP windowing, WebOTP-format SMS delays, NPU access declaration
(`FEATURE_NEURAL_PROCESSING_UNIT`), CameraX 1.5.2/1.6+ required to avoid a dynamic-range crash.

## Android 16 (API 36) recap

- Edge-to-edge opt-out (`windowOptOutEdgeToEdgeEnforcement`) removed for targetSdk 36.
- **Predictive back** animations on by default for targetSdk 36 (`enableOnBackInvokedCallback`
  defaults true) — migrate `onBackPressed()` overrides to `OnBackPressedCallback`/`BackHandler`.
- Large-screen restrictions ignored (with a temporary opt-out that 17 removes).
- Adaptive refresh rate, progress-centric notifications (`ProgressStyle`), `Intent` matching
  stricter for `MATCH_EXTERNAL`, `elegantTextHeight` default, Health Connect medical records,
  audio sharing (LE Audio), `JobScheduler` quota tightening, ART updates via Play.
- 16 KB page size support becomes a Play requirement for apps targeting 15+ (Nov 2025).

## Android 15 (API 35) recap

- **Edge-to-edge enforced** for targetSdk 35: handle insets (`enableEdgeToEdge()`, `safeDrawing`).
- Foreground service changes: `dataSync`/`mediaProcessing` types limited to 6 h per 24 h;
  `BOOT_COMPLETED` can't start several FGS types; `SYSTEM_ALERT_WINDOW` no longer exempts BAL.
- Private space (apps can be hidden/paused), `PendingIntent` creator restrictions, safer intents
  (explicit component or action match), `elegantTextHeight`, TextView `letterSpacing`, 16 KB
  page support in AOSP, `onBackInvoked` predictive back for opted-in apps, restrictions on
  `Bluetooth` APIs, `ROLE_*` changes.

## Android 14 (API 34) recap (still in the wild)

FGS types **required** in manifest + `startForeground()`; exact alarms denied by default
(`SCHEDULE_EXACT_ALARM`); runtime-registered receivers need `RECEIVER_EXPORTED/NOT_EXPORTED`;
`READ_MEDIA_VISUAL_USER_SELECTED` partial photo access; safer dynamic code loading (DEX/JAR read-only);
implicit intents must be explicit to internal components; minimum installable targetSdk 23.

## Permissions

- Ask **in context**, once, with rationale (`shouldShowRequestPermissionRationale`); use
  `rememberLauncherForActivityResult(RequestPermission()/RequestMultiplePermissions())`. Never
  loop requests; on permanent denial deep-link to app settings.
- Prefer **no-permission pickers**: Photo Picker (`PickVisualMedia`), Android 17 **contact picker**
  (`ACTION_PICK_CONTACTS`, field-scoped, temporary access) instead of `READ_CONTACTS`, system
  **location button** for one-session precise location, **EyeDropper** (`ACTION_OPEN_EYE_DROPPER`)
  instead of screen capture, document picker (SAF), `MediaStore.createWriteRequest`.
- Notifications: `POST_NOTIFICATIONS` (33+), channels, no full-screen intents without
  `USE_FULL_SCREEN_INTENT` approval (34+).
- Location: coarse before fine; background location is a separate request and a Play policy review.
- Media: `READ_MEDIA_IMAGES/VIDEO/AUDIO` (33+) with partial access (34+); avoid `MANAGE_EXTERNAL_STORAGE`
  (policy-restricted).
- Bluetooth/Nearby: `BLUETOOTH_SCAN/CONNECT/ADVERTISE`, `NEARBY_WIFI_DEVICES`, and now
  `ACCESS_LOCAL_NETWORK` (all in the `NEARBY_DEVICES` group).
- Declare only what you use; Play flags dangerous permissions in the Data safety form.

## Background work — pick the right primitive

| Need | Use |
|---|---|
| Deferrable, guaranteed (sync, upload, cleanup) | **WorkManager 2.11** (`CoroutineWorker`, constraints, unique work, expedited when user-facing) |
| Immediate, user-visible, long-running (music, navigation, workout, call) | **Foreground service** with the right `foregroundServiceType` (+ type permission, e.g. `FOREGROUND_SERVICE_MEDIA_PLAYBACK`); started while app is visible |
| Large user-initiated transfer (34+) | **User-initiated data transfer job** (`JobInfo.Builder.setUserInitiated`) — not `dataSync` FGS (6 h cap on 35+) |
| Exact time (alarm clock, reminder) | `AlarmManager.setExactAndAllowWhileIdle` with `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` (alarm apps), else inexact `setAndAllowWhileIdle`/WorkManager |
| React to system events | Runtime-registered receivers (explicit export flag) or WorkManager triggers; manifest receivers only for the allowed implicit broadcasts |
| Push | FCM high-priority for time-critical; normal priority otherwise; do the work in a Worker |
| Periodic refresh | `PeriodicWorkRequest` (≥ 15 min, subject to Doze/buckets) |

Test with `adb shell cmd deviceidle force-idle`, `am set-standby-bucket`, and the Background Task
Inspector. Expect Doze/App Standby/OEM battery managers to delay work; design for eventual
execution and idempotency.

## Version guards

```kotlin
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.BAKLAVA /* 36 */) { … }
if (SdkExtensions.getExtensionVersion(Build.VERSION_CODES.S) >= 13) { … }   // extension SDK APIs (Photo Picker backports etc.)
@RequiresApi(37) fun useNewApi()   // lint NewApi enforces; use androidx.core *Compat first
```

Prefer AndroidX compat wrappers (`ContextCompat`, `NotificationCompat`, `WindowCompat`,
`ActivityCompat`, `PendingIntentCompat`, `BuildCompat`) over raw guards. Android 17's `Build.VERSION_CODES`
constant: check `android.os.Build.VERSION_CODES` in the SDK (`CINNAMON_BUN` per the AOSP codename; use the integer 37 if unsure).

## App links & intents

- `<intent-filter android:autoVerify="true">` + `/.well-known/assetlinks.json`; verify with
  `adb shell pm get-app-links <pkg>`; Android 12+ requires verification for HTTPS links to open the app.
- Package visibility (30+): `<queries>` for intents you resolve.
- Safer intents (35+/17): explicit `component` or matching `action`; `PendingIntent` mutability
  flags; BAL rules — background launches need visibility or user interaction.

## Quality bars Play checks

Android vitals thresholds: crash rate < 1.09 % (per-device < 8 %), ANR < 0.47 %, excessive
wakeups/wakelocks, slow start (> 5 s cold), slow rendering; large-screen quality (resizable,
no letterboxing), accessibility, Data safety accuracy, target API.
