---
name: android-navigation
description: Implement or fix navigation in Android/Compose apps with Navigation 3 (androidx.navigation3) — back stacks, routes/keys, passing arguments between screens, back handling and predictive back, dialogs and bottom sheets as destinations, nested/tabbed multi-backstack navigation, deep links, ViewModel scoping per screen, and adaptive list-detail / supporting-pane navigation on large screens. Use this skill whenever a task involves moving between screens, "navigate to", "go back", NavHost, NavController, NavDisplay, NavKey, routes, deep links, app links, tabs with their own history, or migrating from Navigation 2 / Fragments. Load it before writing any navigation code, because older training data produces Navigation 2 NavHost and composable("route") code, which is the wrong default for new Compose apps in 2026.
---

# Android navigation (Navigation 3)

Navigation 3 (`androidx.navigation3`, stable 1.0 Nov 2025; 1.1.x current; 1.2 alpha adds deep-link
helpers) is the Compose-first navigation library. **The back stack is a plain list you own**; the
library renders it. Navigation 2 (`NavHost`, `NavController`) is maintenance-only — use it only when
the project already does and isn't migrating.

## Detect what the project uses

- `androidx.navigation3:*` in the version catalog → Nav3 (this skill).
- `androidx.navigation:navigation-compose` (2.x) → Nav2. Keep consistent; offer a migration only if
  asked or if the task is a rewrite. Migration notes: `references/nav2-migration.md`.
- Fragments + `navigation-fragment` → legacy; migrate screens to Compose first (`android-compose-ui`).

## Dependencies

```toml
[versions]
navigation3 = "1.1.6"          # verify latest
lifecycleNav3 = "2.10.0"
adaptiveNav3 = "1.2.0"
[libraries]
navigation3-runtime = { module = "androidx.navigation3:navigation3-runtime", version.ref = "navigation3" }
navigation3-ui      = { module = "androidx.navigation3:navigation3-ui",      version.ref = "navigation3" }
lifecycle-viewmodel-navigation3 = { module = "androidx.lifecycle:lifecycle-viewmodel-navigation3", version.ref = "lifecycleNav3" }
material3-adaptive-navigation3 = { module = "androidx.compose.material3.adaptive:adaptive-navigation3", version.ref = "adaptiveNav3" }
kotlinx-serialization-json = { module = "org.jetbrains.kotlinx:kotlinx-serialization-json", version = "1.10.0" }
```

Apply `org.jetbrains.kotlin.plugin.serialization` — keys must be `@Serializable`.

## The five concepts

| Concept | What it is |
|---|---|
| `NavKey` | Marker interface for a destination key. Implement with `@Serializable data object` / `data class` carrying the screen's arguments. |
| `NavBackStack` | A `SnapshotStateList`-like list of keys. `backStack.add(Key)` navigates; `backStack.removeLastOrNull()` goes back. `rememberNavBackStack(Start)` persists it across config change and process death. |
| `NavEntry` | Key + the composable content for it (+ metadata). |
| `entryProvider { entry<Key> { key -> … } }` | DSL mapping keys to `NavEntry`s. |
| `NavDisplay` | Observes the back stack and renders the top entry (or several, via a `SceneStrategy`), handles back and transitions. |

## Canonical setup

```kotlin
@Serializable sealed interface Route : NavKey
@Serializable data object Home : Route
@Serializable data class Detail(val id: String) : Route
@Serializable data object Settings : Route

@Composable
fun AppNavigation() {
    val backStack = rememberNavBackStack(Home)                  // survives rotation + process death
    NavDisplay(
        backStack = backStack,
        onBack = { backStack.removeLastOrNull() },              // system back / predictive back
        entryDecorators = listOf(
            rememberSaveableStateHolderNavEntryDecorator(),     // rememberSaveable per entry
            rememberViewModelStoreNavEntryDecorator(),          // ViewModel per entry (lifecycle-viewmodel-navigation3)
        ),
        entryProvider = entryProvider {
            entry<Home> { HomeScreen(onOpen = { id -> backStack.add(Detail(id)) }, onSettings = { backStack.add(Settings) }) }
            entry<Detail> { key -> DetailScreen(id = key.id, onBack = { backStack.removeLastOrNull() }) }
            entry<Settings> { SettingsScreen() }
        },
    )
}
```

- Keep `backStack` operations in one place (a `Navigator` class or the screen-level composable) and
  pass *lambdas* into screens; screens never see the back stack.
- Typed back stack: `rememberSerializable(serializer = serializer()) { NavBackStack<Route>(Home) }`
  gives `NavBackStack<Route>` instead of `NavBackStack<NavKey>`. Keys must be registered in the
  serializer module if you use a custom `SavedStateConfiguration`.
- Don't create the back stack in a `ViewModel` unless you also handle saved state; the Nav3 sample
  "NavigationState" pattern (rememberSerializable + per-tab `rememberNavBackStack`) is the reference.

## ViewModels per screen

With `rememberViewModelStoreNavEntryDecorator()` in `entryDecorators`, `viewModel()` /
`hiltViewModel()` / `koinViewModel()` called inside an `entry<…>` block is scoped to that entry and
cleared when the entry leaves the back stack. Pass key arguments into the ViewModel via
`SavedStateHandle` (Hilt: `@Inject constructor(savedStateHandle: SavedStateHandle)`; read
`savedStateHandle.toRoute<Detail>()`-style helpers aren't Nav3 — instead pass the key explicitly:
`hiltViewModel<DetailViewModel, DetailViewModel.Factory> { it.create(key.id) }` with
`@AssistedInject`, or `koinViewModel { parametersOf(key.id) }`).

## Transitions

Per-entry metadata via `NavDisplay.transitionSpec { }`, `popTransitionSpec { }`,
`predictivePopTransitionSpec { }` in the `entry<…>(metadata = …)` call, or global defaults on
`NavDisplay(transitionSpec = …)`. Shared elements: pass a `SharedTransitionScope` to `NavDisplay` /
`rememberSceneState`. Predictive back is built in — don't add your own `BackHandler` at the root.

## Dialogs, bottom sheets, overlays

Use a `SceneStrategy` so overlays are *entries on the back stack* (back closes them, state restores):

```kotlin
NavDisplay(
    backStack = backStack,
    sceneStrategies = listOf(DialogSceneStrategy()),      // Nav3 1.1+: a List<SceneStrategy>
    entryProvider = entryProvider {
        entry<ConfirmDelete>(metadata = DialogSceneStrategy.dialog()) { ConfirmDialog(...) }
        // Material 3 bottom sheet: material3-adaptive-navigation3 provides a BottomSheet scene strategy;
        // otherwise a DialogSceneStrategy + ModalBottomSheet content works.
    },
)
```

Entries under an overlay have their lifecycle capped at STARTED (so `dropUnlessResumed` works).

## Adaptive (list-detail, supporting pane)

```kotlin
val listDetailStrategy = rememberListDetailSceneStrategy<NavKey>()
NavDisplay(
    backStack = backStack,
    sceneStrategies = listOf(listDetailStrategy),
    entryProvider = entryProvider {
        entry<Home>(metadata = ListDetailSceneStrategy.listPane(detailPlaceholder = { EmptyDetail() })) { HomeList(onOpen = { backStack.add(Detail(it)) }) }
        entry<Detail>(metadata = ListDetailSceneStrategy.detailPane()) { key -> DetailScreen(key.id) }
        entry<Extra>(metadata = ListDetailSceneStrategy.extraPane()) { ... }
    },
)
```

One back stack renders as two panes on wide windows and one pane on phones — no branching
navigation logic. `SupportingPaneSceneStrategy` for main + supporting content. Combine with
`NavigationSuiteScaffold` for the top-level chrome. This is the recommended way to satisfy Android
17's mandatory large-screen resizability (see `android-compose-ui` › adaptive).

## Tabs with independent histories (multi-backstack)

Model each top-level destination with its own `rememberNavBackStack(tabRoot)`, keep
`currentTab` in `rememberSerializable`, and build the entries for `NavDisplay` from the active
stacks (`rememberDecoratedNavEntries` per stack, flattened). Google's migration guide ships a
`NavigationState`/`Navigator` pair implementing exactly this; copy it rather than inventing one.
Back on a non-start tab with an exhausted stack should return to the start tab (Material spec).

## Deep links

Nav3 1.2 (alpha) adds `DeepLinkRequest` (`fromUriString`, from `Intent`) and `DeepLinkMatcher` to
map URIs to keys. On stable 1.1, parse the `Intent` yourself in the Activity and build the back
stack synthetically (e.g. `listOf(Home, Detail(id))`) before/when creating it:

```kotlin
val initial = remember { intent.toRoutesOrNull() ?: listOf(Home) }
val backStack = rememberNavBackStack(*initial.toTypedArray())
// handle onNewIntent for singleTask launches: update the back stack from the new intent
```

Declare `<intent-filter>` with `android:autoVerify="true"` for App Links and host
`/.well-known/assetlinks.json`. Test: `adb shell am start -W -a android.intent.action.VIEW -d "https://example.com/item/42" <pkg>`.

## Handling back correctly

- `onBack` on `NavDisplay` receives the system back. Keep it `{ backStack.removeLastOrNull() }`
  unless a screen needs to intercept (unsaved changes): use `BackHandler(enabled = hasChanges) { showDiscardDialog = true }`
  *inside* the screen; it takes precedence while enabled.
- Never pop below the root; guard `if (backStack.size > 1)`.
- Process death: `rememberNavBackStack` restores; any non-serializable key crashes on restore, which
  is why all keys are `@Serializable` (you'll see `SerializationException` if you forget a nested type
  or use a non-serializable field — annotate or `@Transient` it).

## Testing navigation

- Unit test your `Navigator`/state holder (pure Kotlin, no Compose).
- Compose UI test: set content with `NavDisplay` and assert screens by semantics after clicks;
  `Espresso.pressBack()`/`composeTestRule.activity.onBackPressedDispatcher.onBackPressed()` for back.
- Screenshot-test both pane configurations for adaptive strategies.

## Common mistakes

- Writing `NavHost`/`composable("route/{id}")`/`navController.navigate("route/$id")` in a Nav3
  project (or vice versa). Check the dependency first.
- Forgetting `rememberSaveableStateHolderNavEntryDecorator()` when you supply custom decorators —
  `rememberSaveable` inside screens silently stops surviving navigation.
- Forgetting `rememberViewModelStoreNavEntryDecorator()` and getting one ViewModel shared across all
  entries (or leaking across back navigation).
- Non-serializable keys or `Any`-typed fields → crash on process death.
- Putting the back stack in a global singleton without saved state.
- Passing whole objects as key arguments; pass IDs and reload from the repository.
- Using `sceneStrategy = A then B` (pre-1.1 API) — it's now `sceneStrategies = listOf(A, B)`.
