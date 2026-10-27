# Navigation 2 → Navigation 3 migration

Official guide: developer.android.com/guide/navigation/navigation-3/migration-guide (June 2026).
Prerequisites: Compose screens (no Fragments as destinations), type-safe routes in Nav2 (migrate
string routes to `@Serializable` routes first — they become your `NavKey`s), compileSdk ≥ 36.

## Concept mapping

| Navigation 2 | Navigation 3 |
|---|---|
| `NavHost(navController, startDestination)` | `NavDisplay(backStack, entryProvider)` |
| `composable<Route> { backStackEntry -> }` | `entry<Route> { key -> }` |
| `navController.navigate(Route(id))` | `backStack.add(Route(id))` |
| `navController.popBackStack()` | `backStack.removeLastOrNull()` |
| `popUpTo(...) { inclusive = true }` | manipulate the list: `backStack.removeAll { it is X }` / `backStack.clear(); backStack.add(Root)` |
| `launchSingleTop` | `if (backStack.lastOrNull() != Route) backStack.add(Route)` |
| `backStackEntry.toRoute<Route>()` | `key` parameter is already the typed route |
| `hiltViewModel()` scoped to `NavBackStackEntry` | `hiltViewModel()` inside `entry` with `rememberViewModelStoreNavEntryDecorator()` |
| Nested graphs `navigation<Graph>` | Just more entries; group by sealed interface; multi-backstack via separate lists |
| `dialog<Route>` | `entry<Route>(metadata = DialogSceneStrategy.dialog())` + `DialogSceneStrategy` |
| `NavDeepLink` | Intent parsing → initial back stack (1.1) / `DeepLinkMatcher` (1.2) |
| `navController.currentBackStackEntryAsState()` | `backStack.lastOrNull()` (it's state) |
| `NavigationBar` selected = `currentDestination.hierarchy.any { it.hasRoute(X) }` | `currentTab == X` from your navigation state |
| Shared ViewModel between graph destinations | Scope to the Activity/`ViewModelStoreOwner` above `NavDisplay`, or a parent-keyed store |

## Step-by-step

1. Add `navigation3-runtime`, `navigation3-ui`, `lifecycle-viewmodel-navigation3`; keep Nav2 for now.
2. Make every route class implement `NavKey` (they're already `@Serializable`).
3. Introduce a `NavigationState` (top-level tabs + per-tab `rememberNavBackStack`) and a
   `Navigator` that exposes `navigate(key)`, `back()`, `switchTab(tab)`. Copy Google's sample code
   from the migration guide; note its comment that `rememberSerializable` is intentional.
4. Replace `NavHost` with `NavDisplay(entries = navigationState.toEntries(entryProvider), …)`
   (or `backStack = …` for single-stack apps).
5. Move destinations from the `NavGraph` into `entryProvider { entry<…> }`; replace
   `navController.*` calls in screens with lambdas provided by the `Navigator`.
6. Replace `dialog`/bottom sheet destinations with `SceneStrategy` metadata.
7. Delete Nav2 dependencies. Run UI tests for every flow, including back from every screen and
   process-death restore (`adb shell am kill <pkg>` then relaunch from recents).

## Gotchas seen in real migrations

- `popUpTo` semantics: Nav2's inclusive/non-inclusive nuance is gone; write explicit list ops and
  unit test them.
- Nav2 kept one ViewModel per `NavBackStackEntry` *per graph*; Nav3 scopes per entry key. If two
  entries with equal keys exist in the stack, they share a ViewModel store — make keys unique
  (e.g. include an instance id) if that's not desired.
- `SavedStateHandle` navigation args (`savedStateHandle["id"]`) aren't populated by Nav3; pass args
  explicitly via factories/assisted injection.
- `NavigationSuiteScaffold` selected state comes from your own state, not the NavController.
- Nav3 UI has no KMP artifact yet (runtime does); for Compose Multiplatform implement a small
  custom `NavDisplay`, or keep the shared code in `Navigator` and write per-platform displays.
