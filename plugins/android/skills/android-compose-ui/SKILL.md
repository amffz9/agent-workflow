---
name: android-compose-ui
description: Build, modify, and review Android user interfaces with Jetpack Compose and Material 3. Use this skill for any UI work in an Android or Compose Multiplatform app — new screens, composables, layouts, lists, forms, text fields, dialogs, bottom sheets, theming, dark mode, dynamic color, animations, gestures, edge-to-edge/insets, adaptive layouts for tablets/foldables/desktop windows, accessibility, previews, and converting XML/View/Fragment/RecyclerView UI to Compose. Trigger whenever the user mentions a screen, widget, button, layout, "make it look like", Material, Compose, @Composable, Modifier, LazyColumn, Scaffold, theme, or asks to fix a visual/UI bug — even if they don't say "Compose". Android is Compose-first as of 2026; do not create new XML layouts, Fragments, or RecyclerViews unless the user explicitly wants Views.
---

# Android UI with Jetpack Compose

Android is officially Compose-first (2026): all new platform UI guidance targets Compose, and
`android.widget`/Fragments/RecyclerView are in maintenance mode. Write UI in Compose with Material 3.

Current versions (verify in `libs.versions.toml`): Compose BOM `2026.08.00`+ → Compose `1.12.x`
(requires `compileSdk 37`, AGP ≥ 9.1.1); Material 3 `1.4.x`; Material 3 Adaptive `1.2.x`; Activity
Compose `1.13.x`; Lifecycle `2.10.x`. Older training data predates several APIs referenced here —
grep the dependency sources or `android docs search` before using something you're unsure exists.

## Setup you should see (or add)

```kotlin
// module build.gradle.kts (AGP 9: Kotlin is built in; Compose compiler is a Kotlin plugin)
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")   // version = Kotlin version
}
android { buildFeatures { compose = true } }   // still required
dependencies {
    val bom = platform("androidx.compose:compose-bom:2026.08.00")
    implementation(bom); androidTestImplementation(bom)
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview"); debugImplementation("androidx.compose.ui:ui-tooling")
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.10.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.10.0")
    implementation("androidx.compose.material3.adaptive:adaptive:1.2.0")            // when adaptive
    implementation("androidx.compose.material3.adaptive:adaptive-layout:1.2.0")
    implementation("androidx.compose.material3.adaptive:adaptive-navigation:1.2.0")
    implementation("androidx.compose.material3:material3-adaptive-navigation-suite")
    implementation("androidx.compose.material:material-icons-extended")            // only if needed (large)
}
```

Entry point: `ComponentActivity` + `setContent { AppTheme { App() } }`. Call `enableEdgeToEdge()`
before `setContent` (still recommended even though the platform enforces edge-to-edge for targetSdk 35+).

## Core rules (the ones that prevent most bugs)

1. **State down, events up.** Composables take state as parameters and expose `onX` lambdas. Hoist
   state to the lowest common ancestor that needs it; screen-level state lives in a `ViewModel` as
   `StateFlow<UiState>` and is read with `collectAsStateWithLifecycle()`.
2. **Composables are functions, not objects.** They may run many times, in any order, in parallel,
   and be skipped. No side effects in the body; use effect APIs (below). Never launch a coroutine or
   fire analytics directly in a composable body.
3. **`remember` what is expensive or must survive recomposition; `rememberSaveable` what must
   survive configuration change and process death; `retain {}` (Compose 1.10+) what must survive
   configuration change but is *not* serializable (a player, a large bitmap, a lambda);
   `rememberSerializable` for `@Serializable` state that must survive process death without Parcelable.**
4. **Every list item needs a stable `key`, and usually a `contentType`.** Without keys, reorders
   and deletions recompose everything and lose item state.
5. **Modifier order matters and modifiers are parameters.** Every reusable composable takes
   `modifier: Modifier = Modifier` as its first optional parameter and applies it to its root layout
   once. `padding().background()` ≠ `background().padding()`.
6. **Don't read state you don't need.** Reading `scrollState.value` in a composable body
   recomposes on every pixel; use `derivedStateOf` for thresholds and lambda-based modifiers
   (`Modifier.offset { }`, `graphicsLayer { }`, `drawBehind { }`) for high-frequency values.
7. **Prefer stateless components + a stateful wrapper** (`Counter(count, onIncrement)` +
   `Counter()`), which keeps previews and tests trivial.
8. **Use Material components before building your own.** `Button`, `Card`, `ListItem`,
   `TopAppBar`, `NavigationBar`, `ModalBottomSheet`, `DatePicker`, `SearchBar`, `PullToRefreshBox`,
   `SegmentedButton`, `Badge`, `Snackbar`… Custom-drawing something Material already ships is a
   maintenance and accessibility liability.

## State & effects — pick the right tool

| Need | Use |
|---|---|
| Run a suspend/async block tied to composition, restart when keys change | `LaunchedEffect(key1, key2) { }` |
| Register/unregister a listener, observer, receiver | `DisposableEffect(key) { onDispose { } }` |
| Publish composed state to non-Compose code, or fire a cheap one-shot when keys change | `SideEffect(key1, key2) { }` (keyed overload is Compose 1.12; runs *before* Launched/Disposable) |
| Get a scope to launch from an event handler (click) | `val scope = rememberCoroutineScope()` |
| Derive a value that changes less often than its inputs | `remember { derivedStateOf { list.size > 10 } }` |
| Convert a Flow to state, lifecycle-aware | `flow.collectAsStateWithLifecycle()` (never plain `collectAsState()` for cold/hot app flows) |
| Latest lambda without restarting an effect | `rememberUpdatedState(onEvent)` |
| Snapshot state as a Flow for side work | `snapshotFlow { state.value }` inside `LaunchedEffect` |
| One-shot UI events (snackbar, navigate) | Don't use `SharedFlow` "events". Model as state (`uiState.errorMessage`) and clear it after showing (`onErrorShown()`), or use a `Channel(BUFFERED)` consumed in a `LaunchedEffect` with lifecycle awareness (`repeatOnLifecycle`) — and document the choice. |

`UiState` modeling: a single `data class`/`sealed interface` per screen. Prefer
`data class ScreenUiState(val isLoading: Boolean, val items: List<Item>, val error: String?)`
for screens with several independent regions and a `sealed interface` (Loading/Success/Error) when
regions are mutually exclusive. Keep collections **immutable** (`List`, not `MutableList`) and
data classes stable so strong skipping can skip recomposition (see `android-performance`).

Text input: use `TextFieldState` + `rememberTextFieldState()` with `BasicTextField`/`TextField(state=)`
(state-based API) rather than `value/onValueChange` for new code; formatting/filters go in
`InputTransformation`/`OutputTransformation`. Compose 1.12 adds rich-text `addStyle()` in
`TextFieldBuffer`, `KeyboardType.Date/Time/DateTime/SignedDecimal`, and `BasicSecureTextField`
defaults to `TextObfuscationMode.System`. Password/passkey fields: add
`Modifier.semantics { credentialRequest = CredentialRequestData(...) }` for Credential Manager
integration (Compose 1.12) and the right `contentType` for autofill.

## Layout toolbox

- **Linear**: `Column`, `Row`, `Box`; `Arrangement`/`Alignment`; `Spacer(Modifier.weight(1f))`.
- **Lists/grids**: `LazyColumn`, `LazyRow`, `LazyVerticalGrid`, `LazyVerticalStaggeredGrid` with
  `items(items, key = { it.id }, contentType = { it.type })`. Use `rememberLazyListState()` for
  scroll position, `LazyListState.animateScrollToItem`. Sticky headers: `stickyHeader { }`.
  Pager: `HorizontalPager`/`VerticalPager` with `rememberPagerState { pageCount }`.
- **Flow**: `FlowRow`/`FlowColumn` (wrapping chips). Compose 1.11+ `FlexBox` and `Grid` (both
  `@Experimental*Api`, opt-in): `Grid(config = { repeat(4) { column(0.25f) }; gap(16.dp) })` with
  `Modifier.gridItem(columnSpan = 2)`; named areas (`area("header", …)`) in 1.12. Use them for
  dashboard-style 2D layouts; keep `Lazy*` for scrollable data.
- **Constraint**: `ConstraintLayout` (`androidx.constraintlayout:constraintlayout-compose`) only for
  genuinely complex relative positioning; most layouts don't need it.
- **Custom**: `Layout { measurables, constraints -> }` and `Modifier.layout { }`; intrinsic sizes
  via `Modifier.height(IntrinsicSize.Min)`; `SubcomposeLayout` for measuring-dependent content
  (rare; expensive).
- **Scaffolding**: `Scaffold(topBar, bottomBar, floatingActionButton, snackbarHost) { innerPadding ->
  content(Modifier.padding(innerPadding)) }` — always consume `innerPadding`.
- **Insets / edge-to-edge**: `Modifier.safeDrawingPadding()`, `windowInsetsPadding(WindowInsets.systemBars)`,
  `WindowInsets.ime` for keyboard, `Modifier.imePadding()`, `consumeWindowInsets`. Material
  components (`TopAppBar`, `NavigationBar`, `Scaffold`) handle insets themselves; don't double-pad.
  Use `contentWindowInsets` on `Scaffold` to control it.

### Adaptive UI is mandatory now

Android 16/17 ignore orientation, resizability, and aspect-ratio restrictions on large screens
(sw ≥ 600 dp); with targetSdk 37 there is no opt-out (games excepted). Your UI *will* be shown in
split-screen, free-form desktop windows, App Bubbles, and foldable postures. Design for window
size, not device type:

```kotlin
val windowSizeClass = currentWindowAdaptiveInfo().windowSizeClass   // material3-adaptive
val isExpanded = windowSizeClass.isWidthAtLeastBreakpoint(WindowSizeClass.WIDTH_DP_EXPANDED_LOWER_BOUND)
```

- Navigation: `NavigationSuiteScaffold` picks bottom bar / rail / drawer for you.
- Two-pane: `ListDetailPaneScaffold` / `SupportingPaneScaffold` (`adaptive-layout`), or with
  Navigation 3, `ListDetailSceneStrategy` / `SupportingPaneSceneStrategy` (see `android-navigation`).
- Postures / capabilities: `mediaQuery { windowPosture == UiMediaScope.Posture.Tabletop }`
  (Compose 1.11, experimental) or `WindowInfoTracker` + `FoldingFeature`.
- Input: Compose 1.11 treats trackpads as `PointerType.Mouse`; verify hover, right-click context
  menus, keyboard focus (`Modifier.focusable()`, `onKeyEvent`) and mouse scroll on desktop windows.
- Never lock orientation for non-game screens; don't assume `LocalConfiguration.current.screenWidthDp`
  equals device width — it's the *window* width.

Details and patterns: `references/adaptive-layouts.md`.

## Material 3, theming, and "Expressive"

- One `AppTheme` composable wrapping `MaterialTheme(colorScheme, typography, shapes)`. Dynamic color
  on API 31+: `dynamicLightColorScheme(context)` / `dynamicDarkColorScheme(context)`, falling back to
  `lightColorScheme()/darkColorScheme()` built from a seed (Material Theme Builder).
- Material 3 Expressive (motion schemes, new shapes, `ButtonGroup`, `FloatingToolbar`,
  `LoadingIndicator`, split buttons, expressive `NavigationBar`) ships in `material3 1.4.x` behind
  `@OptIn(ExperimentalMaterial3ExpressiveApi::class)` with `MaterialExpressiveTheme(...)` as the root.
  Use it when the product wants the 2025+ Android look; otherwise plain `MaterialTheme` is fine.
- Never hardcode colors/typography in composables. Read `MaterialTheme.colorScheme.*`,
  `MaterialTheme.typography.*`, `MaterialTheme.shapes.*`. Custom design tokens go in a
  `CompositionLocal` provided by your theme.
- Dark theme: test both. `isSystemInDarkTheme()` decides; images/illustrations need dark variants
  or tinting.
- Icons: `Icons.Default.*` from `material-icons-core`; `Icons.AutoMirrored.*` for directional icons
  (RTL). The extended icon set is large — pull individual `ImageVector`s or use a vector drawable.

Reference: `references/material3-components.md` (component → when to use → gotchas).

## Animation & motion (brief)

- `animate*AsState` for simple property changes; `AnimatedVisibility` for enter/exit;
  `AnimatedContent` for content swaps; `Crossfade`; `updateTransition` for multi-property state
  machines; `Animatable` for gesture-driven values; `Modifier.animateContentSize()`;
  `LazyItemScope.animateItem()` for list reorder/add/remove.
- Shared elements: `SharedTransitionLayout` + `Modifier.sharedElement/sharedBounds`; debug with
  `LookaheadAnimationVisualDebugging { }` (Compose 1.11).
- Predictive back: `PredictiveBackHandler { progress -> }` and, in 1.12, `DeferredAnimatedContent`
  for gesture-driven two-stage transitions. Ensure targetSdk 36+ apps opt in
  (`android:enableOnBackInvokedCallback` defaults to true when targeting 36).
- Motion should respect `LocalAccessibilityManager`/reduced-motion settings; keep durations ≤ 300 ms
  for common transitions and use `MaterialTheme.motionScheme` (Expressive) where available.

## Previews (use them; they're your fastest visual feedback)

```kotlin
@PreviewLightDark @PreviewScreenSizes @PreviewFontScale     // multipreview annotations
@Preview(showBackground = true)
@Composable private fun ItemCardPreview() = AppTheme { ItemCard(sampleItem, onClick = {}) }
```

- Keep previews stateless with sample data; wrap in the theme. Compose 1.11 `@PreviewWrapper(ThemeWrapper::class)`
  applies a `PreviewWrapperProvider` so every preview gets the theme without repetition.
- `@PreviewParameter(SampleProvider::class)` for data variants.
- Render from the terminal: `android studio render-compose-preview <file.kt> --preview <fn>`.
  Screenshot tests can be generated from previews (see `android-testing`).

## Accessibility (do it while writing, not after)

- `contentDescription` on meaningful images/icons; `null` for decorative ones.
- Touch targets ≥ 48 dp (Material components ensure this; custom clickable boxes need
  `Modifier.minimumInteractiveComponentSize()` or explicit size).
- Merge semantics for list rows (`Modifier.semantics(mergeDescendants = true)`), set `Role`, use
  `stateDescription`, `heading()`, `LiveRegionMode` for dynamic status, `clearAndSetSemantics` for
  custom components that would otherwise announce internals.
- Text scaling: never fix heights on text containers; test with `@PreviewFontScale`.
- Color contrast ≥ 4.5:1 — Material color roles guarantee this if you use `onX` colors with `X`.
- Run `android layout` or the Accessibility Scanner; Compose UI tests can assert semantics.
More in `references/accessibility.md`.

## Interop and migration from Views

- Embed Compose in Views: `ComposeView` (`setViewCompositionStrategy(DisposeOnViewTreeLifecycleDestroyed)`
  in Fragments). Embed Views in Compose: `AndroidView(factory = { … }, update = { … })`;
  `AndroidViewBinding` for ViewBinding layouts.
- Migrate bottom-up (leaf components first) or screen-by-screen; don't rewrite navigation until the
  screens are Compose. Google ships an "XML to Compose migration" agent skill
  (`android skills add`/see developer.android.com/develop/ui/compose/migrate) — consider using it for
  large layouts. Mapping cheatsheet in `references/views-to-compose.md`.
- `RecyclerView` → `LazyColumn` (keys!), `ViewPager2` → `HorizontalPager`, `Fragment` → composable +
  Nav3 entry, `LiveData` → `StateFlow` (or `observeAsState` temporarily), XML themes → `MaterialTheme`.

## Common mistakes to avoid

- Creating a `ViewModel` inside a composable with a constructor call, or calling `viewModel()` for
  a *screen* deep in a child composable. Get it at the screen/route level and pass state down.
- Using `LocalContext.current` to start activities or show `Toast` inside the body (side effect).
  Do it in a click handler or effect.
- `Modifier.clickable` on a `Text` inside a `Card` that's also clickable → nested click targets;
  pick one.
- `LazyColumn` inside a vertically scrollable `Column` (crashes: infinite height). Use a single
  `LazyColumn` with different item types instead.
- `mutableStateOf(list)` then `list.add(x)` — not observed. Use `mutableStateListOf` or replace the
  list with a new one.
- `remember { }` for values that depend on parameters without keys: `remember(param) { }`.
- Passing `Modifier.fillMaxSize()` in a reusable component instead of leaving it to the caller.
- Ignoring `innerPadding` from `Scaffold`; content hides under the app bar.
- Hardcoded `dp` widths that break on large windows; use `weight`, `fillMaxWidth(fraction)`,
  `widthIn(max = 600.dp)` and adaptive scaffolds.
- Locking orientation via manifest `screenOrientation` — ignored on large screens and a Play quality
  issue.
- New XML layouts, Fragments, or `RecyclerView` in a Compose codebase.

## Verify before you're done

1. `./gradlew :module:compileDebugKotlin` passes. Run `./gradlew :app:lintDebug` for `NewApi`,
   `ComposableNaming`, `UnusedMaterial3ScaffoldPaddingParameter`, `RememberReturnType`, etc.
2. Render a preview (`android studio render-compose-preview`) or run the app and take a screenshot
   (`android screen capture` / `adb exec-out screencap`). Look at it.
3. Rotate / resize (`adb shell wm size 1200x800` for a tablet-ish window; `adb emu rotate`), toggle
   dark mode (`adb shell cmd uimode night yes`), font scale (`adb shell settings put system font_scale 1.3`).
4. Add or update a Compose UI test or screenshot test (see `android-testing`).
