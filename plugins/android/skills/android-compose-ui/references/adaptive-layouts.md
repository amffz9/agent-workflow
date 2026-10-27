# Adaptive layouts (phones, foldables, tablets, desktop windows, bubbles)

## Why this is non-negotiable in 2026

- Android 16 (targetSdk 36) started ignoring `screenOrientation`, `resizeableActivity=false`,
  `minAspectRatio`/`maxAspectRatio` on large screens (sw ≥ 600 dp) with a temporary opt-out.
- Android 17 (targetSdk 37) removes the opt-out. Games (by Play category) are exempt.
- Android 17 adds App Bubbles (any app can float), a Bubble Bar on tablets, interactive desktop PiP,
  and Googlebooks (ChromeOS-on-Android laptops). Your activity can be resized to very small windows.
- Android 17 no longer recreates the activity for keyboard/navigation/touchscreen/color-mode
  config changes; you get `onConfigurationChanged`. Opt back in with `android:recreateOnConfigChanges`
  only if you truly rely on a full restart.

Compose handles most of this if you avoid fixed sizes and read window metrics reactively.

## Window size classes

```kotlin
import androidx.compose.material3.adaptive.currentWindowAdaptiveInfo
import androidx.window.core.layout.WindowSizeClass

@Composable
fun AppRoot() {
    val info = currentWindowAdaptiveInfo()
    val sizeClass = info.windowSizeClass
    val expandedWidth = sizeClass.isWidthAtLeastBreakpoint(WindowSizeClass.WIDTH_DP_EXPANDED_LOWER_BOUND) // ≥ 840dp
    val mediumWidth   = sizeClass.isWidthAtLeastBreakpoint(WindowSizeClass.WIDTH_DP_MEDIUM_LOWER_BOUND)   // ≥ 600dp
    val posture = info.windowPosture   // isTabletop, hingeList
    ...
}
```

Breakpoints (width): compact < 600 dp, medium 600–839 dp, expanded 840–1199 dp, large 1200–1599,
extra-large ≥ 1600. Height classes exist too (compact < 480 dp — e.g. landscape phones; don't put
a tall bottom bar there).

Use `WindowSizeClass` for **layout structure** (one pane vs two, rail vs bar). Use
`BoxWithConstraints` / `Modifier.onSizeChanged` for **component-level** decisions. Use
`LocalConfiguration.current.screenWidthDp` sparingly — it's the window, not the device, and it
recomposes broadly.

## Navigation that adapts

```kotlin
NavigationSuiteScaffold(
    navigationSuiteItems = {
        topLevelDestinations.forEach { dest ->
            item(selected = dest == current, onClick = { navigateTo(dest) },
                 icon = { Icon(dest.icon, null) }, label = { Text(dest.label) })
        }
    }
) { /* content */ }
```

`NavigationSuiteScaffold` picks `NavigationBar` (compact), `NavigationRail` (medium/expanded), or a
drawer based on `currentWindowAdaptiveInfo()`. Override with `layoutType` if the design demands it.

## Two-pane layouts

**With Material 3 Adaptive (no navigation lib coupling):**

```kotlin
val navigator = rememberListDetailPaneScaffoldNavigator<Item>()
val scope = rememberCoroutineScope()
BackHandler(navigator.canNavigateBack()) { scope.launch { navigator.navigateBack() } }
ListDetailPaneScaffold(
    directive = navigator.scaffoldDirective,
    value = navigator.scaffoldValue,
    listPane = { AnimatedPane { ItemList(onItemClick = { scope.launch { navigator.navigateTo(ListDetailPaneScaffoldRole.Detail, it) } }) } },
    detailPane = { AnimatedPane { navigator.currentDestination?.contentKey?.let { ItemDetail(it) } ?: EmptyDetail() } },
)
```

**With Navigation 3:** use `ListDetailSceneStrategy` / `SupportingPaneSceneStrategy` from
`androidx.compose.material3.adaptive:adaptive-navigation3` so a *single* back stack renders as one or
two panes depending on width. See `android-navigation`.

`SupportingPaneScaffold` is for main + supporting content (e.g. editor + properties).

## Foldables and postures

```kotlin
@OptIn(ExperimentalMediaQueryApi::class)
@Composable
fun Player() {
    if (mediaQuery { windowPosture == UiMediaScope.Posture.Tabletop }) TabletopLayout() else FlatLayout()
}
```

Fallback without the experimental API: `WindowInfoTracker.getOrCreate(context).windowLayoutInfo(activity)`
→ `displayFeatures.filterIsInstance<FoldingFeature>()`; `state == HALF_OPENED && orientation == HORIZONTAL`
means tabletop. Avoid placing controls across the hinge (`FoldingFeature.bounds`).

## Input beyond touch

- Keyboard: `Modifier.focusable()`, `FocusRequester`, `Modifier.onKeyEvent`/`onPreviewKeyEvent`,
  `KeyboardShortcut`-style handlers on desktop windows; ensure Tab order is sane (`focusProperties`).
- Mouse/trackpad: hover states (`Modifier.hoverable` + `InteractionSource`), right-click context
  menus (Compose text fields have desktop-style menus since 1.11), scroll wheel works on
  `Modifier.verticalScroll`/lazy lists automatically. Test with `performTrackpadInput`/`performMouseInput`.
- Stylus: `PointerType.Stylus`; use `Modifier.pointerInput` with `awaitPointerEventScope` for
  pressure-aware drawing; consider `androidx.ink` for inking.

## Small-window resilience (bubbles, PiP, split screen)

- Every screen must render at ~360×480 dp without crashes or clipped critical controls:
  scrollable containers (`verticalScroll`), `FlowRow` for chip groups, `LazyVerticalGrid` with
  `GridCells.Adaptive(minSize = 160.dp)`.
- Hide/collapse decorative headers when height class is compact.
- Don't cache window size in a `remember` without keys; read it each composition.

## Manifest / activity checklist

- Remove `android:screenOrientation` (except games). Remove `resizeableActivity="false"`.
- `android:configChanges` is usually unnecessary in Compose; rely on state restoration
  (`rememberSaveable`, `ViewModel`, `retain`).
- Support multi-window drag & drop with `Modifier.dragAndDropSource/Target` if content is
  shareable.
- For desktop/Googlebook, provide a `<meta-data android:name="android.app.shortcuts">` and window
  size hints only if the product needs them; otherwise defaults are fine.

## Testing adaptive UI

- Previews: `@PreviewScreenSizes` (phone, foldable, tablet, desktop) and `@Preview(device = Devices.TABLET)`.
- Emulator: resizable AVD (`android emulator create --template …` offers phone/foldable/tablet/desktop
  templates) or `adb shell wm size 1280x800 && adb shell wm density 240` (reset with `wm size reset`).
- Compose tests: `composeTestRule.setContent { CompositionLocalProvider(LocalWindowInfo …) }` is
  awkward; prefer parameterizing your composables on `WindowSizeClass` and testing each branch, plus
  screenshot tests per size.
