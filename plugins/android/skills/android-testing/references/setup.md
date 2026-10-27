# Testing setup — dependencies and boilerplate

## Version catalog (verify versions)

```toml
[versions]
junit4 = "4.13.2"; junit5 = "5.13.0"; androidxTestExt = "1.3.0"; androidxTestRunner = "1.7.0"; androidxTestCore = "1.7.0"
espresso = "3.7.0"; uiautomator = "2.4.0"; robolectric = "4.16"; coroutinesTest = "1.11.0"; turbine = "1.2.1"
mockk = "1.14.5"; truth = "1.4.4"; roborazzi = "1.70.0"; screenshot = "0.0.1-alpha16"; mockwebserver = "5.4.0"
[libraries]
junit4 = { module = "junit:junit", version.ref = "junit4" }
androidx-test-ext-junit = { module = "androidx.test.ext:junit", version.ref = "androidxTestExt" }
androidx-test-runner = { module = "androidx.test:runner", version.ref = "androidxTestRunner" }
androidx-test-core = { module = "androidx.test:core-ktx", version.ref = "androidxTestCore" }
androidx-test-rules = { module = "androidx.test:rules", version.ref = "androidxTestCore" }
androidx-test-orchestrator = { module = "androidx.test:orchestrator", version = "1.6.0" }
espresso-core = { module = "androidx.test.espresso:espresso-core", version.ref = "espresso" }
uiautomator = { module = "androidx.test.uiautomator:uiautomator", version.ref = "uiautomator" }
compose-ui-test-junit4 = { module = "androidx.compose.ui:ui-test-junit4" }        # BOM-managed
compose-ui-test-manifest = { module = "androidx.compose.ui:ui-test-manifest" }
robolectric = { module = "org.robolectric:robolectric", version.ref = "robolectric" }
coroutines-test = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-test", version.ref = "coroutinesTest" }
turbine = { module = "app.cash.turbine:turbine", version.ref = "turbine" }
mockk = { module = "io.mockk:mockk", version.ref = "mockk" }
truth = { module = "com.google.truth:truth", version.ref = "truth" }
okhttp-mockwebserver = { module = "com.squareup.okhttp3:mockwebserver3", version.ref = "mockwebserver" }
roborazzi = { module = "io.github.takahirom.roborazzi:roborazzi", version.ref = "roborazzi" }
roborazzi-compose = { module = "io.github.takahirom.roborazzi:roborazzi-compose", version.ref = "roborazzi" }
hilt-android-testing = { module = "com.google.dagger:hilt-android-testing", version.ref = "hilt" }
[plugins]
roborazzi = { id = "io.github.takahirom.roborazzi", version.ref = "roborazzi" }
compose-screenshot = { id = "com.android.compose.screenshot", version.ref = "screenshot" }
```

## Module config

```kotlin
android {
    defaultConfig { testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner" }  // or com.example.HiltTestRunner
    testOptions {
        unitTests { isIncludeAndroidResources = true; isReturnDefaultValues = true }
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
        animationsDisabled = true
        managedDevices.allDevices { create<com.android.build.api.dsl.ManagedVirtualDevice>("pixel6Api37") { device = "Pixel 6"; apiLevel = 37; systemImageSource = "aosp-atd" } }
    }
    @Suppress("UnstableApiUsage") experimentalProperties["android.experimental.enableScreenshotTest"] = true   // or gradle.properties
}
dependencies {
    testImplementation(libs.junit4); testImplementation(libs.coroutines.test); testImplementation(libs.turbine); testImplementation(libs.truth)
    testImplementation(libs.robolectric); testImplementation(libs.compose.ui.test.junit4); debugImplementation(libs.compose.ui.test.manifest)
    testImplementation(libs.okhttp.mockwebserver)
    androidTestImplementation(libs.androidx.test.ext.junit); androidTestImplementation(libs.androidx.test.runner); androidTestImplementation(libs.espresso.core)
    androidTestImplementation(libs.uiautomator); androidTestImplementation(libs.compose.ui.test.junit4)
    androidTestUtil(libs.androidx.test.orchestrator)
    screenshotTestImplementation(libs.compose.ui.tooling)     // Compose Preview Screenshot Testing
}
```

## Rules and helpers

```kotlin
class MainDispatcherRule(val dispatcher: TestDispatcher = UnconfinedTestDispatcher()) : TestWatcher() {
    override fun starting(d: Description) = Dispatchers.setMain(dispatcher)
    override fun finished(d: Description) = Dispatchers.resetMain()
}
fun TestScope.testDispatcher() = StandardTestDispatcher(testScheduler)

class FakeArticleRepository : ArticleRepository {
    private val articles = MutableStateFlow<List<Article>>(emptyList())
    var failNextRefresh: Throwable? = null
    fun emit(list: List<Article>) { articles.value = list }
    override fun observeArticles() = articles
    override suspend fun refresh(): Result<Unit> = failNextRefresh?.let { failNextRefresh = null; Result.failure(it) } ?: Result.success(Unit)
    override suspend fun getArticle(id: String) = articles.value.firstOrNull { it.id == id }
}

// Hilt runner
class HiltTestRunner : AndroidJUnitRunner() { override fun newApplication(cl: ClassLoader?, name: String?, ctx: Context?) = super.newApplication(cl, HiltTestApplication::class.java.name, ctx) }
```

## Compose Preview Screenshot Testing (standalone plugin, AGP ≤ 9.4)

```kotlin
// build: plugins { alias(libs.plugins.compose.screenshot) }; gradle.properties: android.experimental.enableScreenshotTest=true
// src/screenshotTest/kotlin/.../FeedScreenshots.kt
class FeedScreenshots {
    @PreviewLightDark @PreviewFontScale
    @Preview(showBackground = true, widthDp = 360) @Preview(showBackground = true, widthDp = 840)
    @Composable fun Feed() = AppTheme { FeedScreen(FeedUiState(items = sample), onOpen = {}) }
}
// ./gradlew :app:updateDebugScreenshotTest   (record reference PNGs under src/screenshotTest/reference/)
// ./gradlew :app:validateDebugScreenshotTest (verify; HTML report in build/reports/screenshotTest/)
```
AGP 9.5+: apply screenshot testing via AGP test suites and annotate previews with `@PreviewTest`
(`android.experimental.enableScreenshotTest=true` + test suite DSL); the standalone plugin is deprecated.

## Roborazzi

```kotlin
// plugins { alias(libs.plugins.roborazzi) }; testImplementation(libs.roborazzi, libs.roborazzi.compose)
@RunWith(AndroidJUnit4::class) @GraphicsMode(GraphicsMode.Mode.NATIVE) @Config(sdk = [36], qualifiers = RobolectricDeviceQualifiers.Pixel7)
class FeedRoborazziTest {
    @get:Rule val rule = createComposeRule()
    @Test fun feed() { rule.setContent { AppTheme { FeedScreen(FeedUiState(items = sample), {}) } }; rule.onRoot().captureRoboImage() }
}
// ./gradlew :app:recordRoborazziDebug | verifyRoborazziDebug | compareRoborazziDebug
// roborazzi { generateComposePreviewRobolectricTests { enable = true; packages = listOf("com.example") } } to auto-generate from @Previews
```

## Instrumented flow with UiAutomator + Compose

```kotlin
@RunWith(AndroidJUnit4::class) class OnboardingFlowTest {
    @get:Rule val rule = createAndroidComposeRule<MainActivity>()
    private val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    @Test fun grantsNotificationsThenLandsOnFeed() {
        rule.onNodeWithText("Continue").performClick()
        device.wait(Until.findObject(By.textContains("Allow")), 3_000)?.click()      // system permission dialog
        rule.waitUntilExactlyOneExists(hasTestTag("feed"), 5_000)
    }
}
```

## Journeys (Android CLI)

Ask the agent: "Create a journey for signing in with demo@example.com / password and verifying the
feed shows at least one article; run it on the connected emulator." The CLI skill generates the
journey file and executes it, using `android screen`/`android layout` for grounding. Keep
journeys in the repo (`journeys/`) and run them from CI with the same CLI.
