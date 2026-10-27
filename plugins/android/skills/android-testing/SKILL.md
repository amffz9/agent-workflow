---
name: android-testing
description: Write, fix, and run tests for Android and KMP apps — JVM unit tests (JUnit 4/5, kotlinx-coroutines-test, Turbine, MockK/fakes), ViewModel and repository tests, Room DAO and migration tests, Compose UI tests with the v2 test APIs (StandardTestDispatcher default since Compose 1.11), Robolectric, instrumented/Espresso/UiAutomator tests, screenshot tests (Compose Preview Screenshot Testing, Roborazzi, Paparazzi), Hilt/Koin test setup, MockWebServer, Gradle Managed Devices, Test Orchestrator, Journeys (natural-language agent tests via Android CLI), coverage, and CI. Use this skill whenever the user asks to add tests, "make sure this works", fix a failing or flaky test, set up testing infrastructure, mock something, or before declaring any Android change done — and whenever a test file (src/test, src/androidTest, src/screenshotTest) is being edited.
---

# Android testing

Test pyramid for 2026 Android apps: **many JVM unit tests** (fast, no device) → **Compose UI /
Robolectric tests** (JVM, render the real UI) → **screenshot tests** (JVM, catch visual regressions)
→ **a few instrumented E2E tests** (device/emulator) → **Journeys** for exploratory agent-driven
checks. Put logic where it's cheap to test (ViewModels, repositories, use cases) so most tests
live in `src/test`.

## Run

```bash
./gradlew :app:testDebugUnitTest --tests "com.example.feed.*"            # JVM unit + Robolectric
./gradlew :app:connectedDebugAndroidTest                                  # instrumented on connected device
./gradlew :app:pixel6Api37DebugAndroidTest                                # Gradle Managed Device (no manual emulator)
./gradlew :app:validateDebugScreenshotTest / :app:updateDebugScreenshotTest   # Compose Preview screenshot tests
./gradlew :app:recordRoborazziDebug / verifyRoborazziDebug                # Roborazzi
./gradlew test --continue                                                 # all modules, keep going
```

Reports: `<module>/build/reports/tests/testDebugUnitTest/index.html`, instrumented in
`build/reports/androidTests/connected/`. AGP 9.2+ can aggregate all test/coverage reports into
one dashboard (`android.experimental.reportAggregationSupport=true`).

Filter one test: `--tests "*FeedViewModelTest.loads*"`; instrumented:
`-Pandroid.testInstrumentationRunnerArguments.class=com.example.FeedTest#loads`.

## Unit tests (src/test)

```kotlin
class FeedViewModelTest {
    @get:Rule val mainDispatcherRule = MainDispatcherRule()            // sets Dispatchers.Main to a TestDispatcher
    private val repo = FakeArticleRepository()                          // fake > mock

    @Test fun `shows articles after load`() = runTest {
        repo.emit(listOf(article("1")))
        val vm = FeedViewModel(repo, AppDispatchers(testDispatcher()))
        vm.uiState.test {                                               // Turbine
            assertEquals(FeedUiState(isLoading = true), awaitItem())
            assertEquals(listOf(article("1")), awaitItem().items)
        }
    }
    @Test fun `refresh failure surfaces error once`() = runTest {
        repo.failNextRefresh = IOException("offline")
        val vm = FeedViewModel(repo, AppDispatchers(testDispatcher()))
        backgroundScope.launch { vm.uiState.collect() }                 // keep WhileSubscribed alive
        vm.refresh(); advanceUntilIdle()
        assertEquals("You're offline", vm.uiState.value.errorMessage)
        vm.onErrorShown(); assertNull(vm.uiState.value.errorMessage)
    }
}
```

Rules of thumb:
- **Fakes over mocks** for repositories/data sources (a `FakeArticleRepository` with a
  `MutableStateFlow` you control). MockK only for third-party interfaces you can't fake cheaply;
  never mock data classes or the class under test.
- `runTest` + `StandardTestDispatcher` + `advanceUntilIdle()`; inject dispatchers. Use
  `UnconfinedTestDispatcher` for `Dispatchers.Main` in the rule when you want eager execution.
- Assert on `UiState` values, not on internal calls.
- Parameterize with JUnit 4 `Parameterized`/JUnit 5 `@ParameterizedTest` (JUnit 5 via
  `de.mannodermaus.android-junit5` for Android modules; pure Kotlin modules can use it directly). Kotest is fine if the project uses it.
- Truth/AssertJ/kotlin.test — follow the project. Test names as sentences.
- Room DAOs and migrations run on the JVM with `BundledSQLiteDriver` (Room 2.8+/3): no device needed
  (`android-data-persistence`).
- Network: MockWebServer / Ktor `MockEngine` with JSON fixtures in `src/test/resources`.

## Compose UI tests (JVM via Robolectric, or instrumented)

Since Compose 1.11 the **v2 test APIs are default**: `runComposeUiTest { }` /
`createComposeRule()` use `StandardTestDispatcher`, so launched coroutines *queue* until the clock
advances. Flaky "read-ahead" tests are gone, but tests that relied on immediate execution need
`waitForIdle()`/`advanceUntilIdle()` or `mainClock.advanceTimeBy()`. Migration guide:
developer.android.com/develop/ui/compose/testing/migrate-v2.

```kotlin
@RunWith(AndroidJUnit4::class)            // Robolectric on JVM if robolectric is on the test classpath (+ @Config(sdk=[36])) or instrumented
class FeedScreenTest {
    @get:Rule val rule = createComposeRule()   // createAndroidComposeRule<MainActivity>() when you need an Activity

    @Test fun clickingArticleOpensIt() {
        var opened: String? = null
        rule.setContent { AppTheme { FeedScreen(state = FeedUiState(items = sample), onOpen = { opened = it }) } }
        rule.onNodeWithText("First article").performClick()
        assertEquals("1", opened)
    }
    @Test fun errorIsAnnounced() {
        rule.setContent { AppTheme { FeedScreen(state = FeedUiState(errorMessage = "Offline"), onOpen = {}) } }
        rule.onNode(hasText("Offline") and hasAnyAncestor(isDialog().not())).assertIsDisplayed()
    }
    @Test fun loadingHidesList() {
        rule.mainClock.autoAdvance = false
        rule.setContent { AppTheme { FeedScreen(FeedUiState(isLoading = true), {}) } }
        rule.mainClock.advanceTimeByFrame()
        rule.onNodeWithTag("feed").assertDoesNotExist()
        rule.onNode(isProgressIndicator()).assertIsDisplayed()          // custom matcher on ProgressBarRangeInfo
    }
}
```

- Find nodes by **semantics** (`onNodeWithText`, `onNodeWithContentDescription`, `hasClickAction()`,
  `isToggleable()`); use `Modifier.testTag` only when no meaningful semantics exist. Set
  `useUnmergedTree = true` to reach children inside merged rows.
- `waitUntil { … }` / `waitUntilExactlyOneExists(matcher)` for async UI; never `Thread.sleep`.
- Animation tests: Compose 1.12 `hasPendingWork()` + `runWithoutImplicitWait { }` with
  `mainClock.autoAdvance = false` to step frames cheaply.
- Input: `performClick`, `performTextInput`, `performTouchInput { swipeUp() }`,
  `performMouseInput`, `performTrackpadInput` (1.11), `performKeyInput`, `performScrollToNode`.
- Test stateless screens with fake state; test the ViewModel separately. Full-screen tests with
  a real ViewModel + fake repository are fine but fewer.
- Navigation: render `NavDisplay` with a real back stack; assert screens appear; back via
  `Espresso.pressBack()` (instrumented) or `rule.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }`.
- Hybrid View/Compose UIs: Compose 1.12 `onRootWithViewInteraction(onView(withId(R.id.list)))`
  scopes Compose queries to a View.
- Robolectric config: `testOptions { unitTests { isIncludeAndroidResources = true } }`,
  `@Config(sdk = [36])` (Robolectric lags newest API by months — check its release notes for 37),
  `@GraphicsMode(NATIVE)` for screenshot-quality rendering.

## Screenshot tests

Three good options; pick one per project.

1. **Compose Preview Screenshot Testing** (Google): screenshots generated from `@Preview`
   composables in a `screenshotTest` source set. On AGP 9.4 use the standalone plugin
   `com.android.compose.screenshot` with `android.experimental.enableScreenshotTest=true`;
   AGP 9.5+ integrates it into **AGP test suites** (`@PreviewTest` annotation, multiple suites,
   config-cache friendly) and deprecates the standalone plugin. Tasks: `update…ScreenshotTest`
   to record, `validate…ScreenshotTest` to verify; reports under `build/reports/screenshotTest/`.
2. **Roborazzi** (Robolectric-based; 1.70+): `captureRoboImage()` in Compose tests or
   auto-generated tests from previews (`generateComposePreviewRobolectricTests`); works for
   Compose Multiplatform previews and Desktop.
3. **Paparazzi** (Cash App; Layoutlib, no Robolectric): fastest, XML + Compose.

Rules: deterministic data (fixed dates, seeded random), disable animations/blinking cursors,
record on CI's OS (font rendering differs across macOS/Linux) or use a Docker image, review
diffs like code, set a small tolerance only for antialiasing. Cover light/dark, font scale 1.3,
and compact/expanded widths for adaptive screens.

## Instrumented tests (src/androidTest)

- Compose tests can run instrumented unchanged. Espresso for View screens; **UiAutomator 2.4**
  for cross-app flows, notifications, permission dialogs (`device.findObject(By.text("Allow")).click()`).
- Prefer **Gradle Managed Devices** (`testOptions.managedDevices.allDevices { create<ManagedVirtualDevice>("pixel6Api37") { device="Pixel 6"; apiLevel=37; systemImageSource="aosp-atd" } }`);
  ATD images are faster. Needs KVM on Linux CI.
- **Test Orchestrator** (`execution = "ANDROIDX_TEST_ORCHESTRATOR"`, `clearPackageData = true`) isolates
  tests; combine with `adb shell settings put global animator_duration_scale 0` (GMD does this).
- Permissions: `GrantPermissionRule.grant(android.Manifest.permission.CAMERA)`; deny paths via UiAutomator.
- Hilt: `@HiltAndroidTest` + `HiltAndroidRule` + a `HiltTestRunner`; swap modules with
  `@TestInstallIn`. Koin: `startKoin` in a test rule with fake modules or `KoinTestRule`.
- Idling: avoid `IdlingResource` plumbing by testing Compose with fakes; for real network use
  MockWebServer with a debug `BASE_URL`.
- Macrobenchmarks are instrumented tests too (`android-performance`).

## Journeys (agent-driven UI tests)

With Android CLI (or Studio's Gemini), describe a journey in natural language ("Sign in with the
demo account, open the first article, assert the title is visible") and let the agent execute it
on a device with vision + `android layout`/`android screen`. Use Journeys for exploratory and
smoke coverage of flows that are painful to script; keep deterministic assertions in Compose
tests. They can run in CI via the CLI.

## Flaky tests — diagnose, don't retry blindly

- Time: unmocked `Clock`/`System.currentTimeMillis` → inject `Clock`; `delay` in code → virtual
  time via `runTest`.
- Dispatchers: hard-coded `Dispatchers.IO` → inject; `stateIn` without a collector → collect in
  `backgroundScope`.
- Order/shared state: singletons, `object` caches, static flags → reset in `@Before`; Orchestrator.
- UI: animations, `Thread.sleep`, unstable `key`s, reading text with trailing whitespace.
- Robolectric SDK vs code paths (`Build.VERSION.SDK_INT` guards) → `@Config(sdk=[…])` per branch.
- Emulator flakiness → GMD + ATD images, `--rerun-tasks` only to reproduce, quarantine with a
  tracking issue rather than `@Ignore` forever.

## Coverage & CI

- Kover (`org.jetbrains.kotlinx.kover`) or Jacoco via AGP `enableUnitTestCoverage`/`enableAndroidTestCoverage`; AGP 9.2+ unified coverage reports.
- CI matrix: unit + screenshot on every PR (JVM, fast); instrumented nightly or on `main` via GMD
  or Firebase Test Lab; benchmarks on a fixed physical device pool.
- Cache `~/.gradle` and the emulator system images; use `--no-daemon`, `-Dorg.gradle.jvmargs=-Xmx4g`.

## Definition of done for a change

- New/changed logic has a unit test that fails without the change.
- New/changed UI has a Compose UI test or screenshot test for its key states (loading, empty,
  error, content).
- `./gradlew testDebugUnitTest` and lint pass; instrumented tests pass if the change touches
  navigation, permissions, or platform integration.
