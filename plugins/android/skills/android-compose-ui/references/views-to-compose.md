# Views/XML → Compose migration cheatsheet

Views are in maintenance mode; migrate incrementally, verifying each screen with screenshots/tests.
Google also publishes an AI-driven "XML to Compose migration" skill
(developer.android.com/develop/ui/compose/migrate/migrate-xml-views-to-jetpack-compose) — useful for
large, mechanical layouts.

## Strategy

1. **Bottom-up**: convert reusable leaf widgets first (buttons, cards, list rows) exposing them via
   `ComposeView` in existing layouts.
2. **Screen-by-screen**: convert a full Fragment to a composable; keep it hosted in the Fragment
   (`ComposeView` + `setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)`)
   until navigation moves.
3. **Navigation last**: once most screens are composables, replace Fragment navigation with
   Navigation 3 (`android-navigation`), and the `Activity` becomes a single `ComponentActivity`.
4. Keep the `ViewModel`s; change `LiveData` → `StateFlow` (`asLiveData()`/`observeAsState()` as bridges).

## Widget mapping

| XML / View | Compose |
|---|---|
| `LinearLayout` (vertical/horizontal) | `Column` / `Row` |
| `FrameLayout` | `Box` |
| `ConstraintLayout` | `Row/Column/Box` with `weight`/alignment first; `ConstraintLayout` (compose) only if really needed |
| `RelativeLayout` | `Box` + `Modifier.align`, or `Row/Column` |
| `ScrollView`/`NestedScrollView` | `Column(Modifier.verticalScroll(rememberScrollState()))` |
| `RecyclerView` + Adapter + ViewHolder | `LazyColumn/LazyRow/LazyVerticalGrid` + `items(key=)` — no adapter |
| `ViewPager2` | `HorizontalPager` |
| `TextView` | `Text` |
| `EditText`/`TextInputLayout` | `TextField`/`OutlinedTextField` with `TextFieldState` |
| `Button`/`MaterialButton` | `Button`/`OutlinedButton`/`TextButton` |
| `ImageView` | `Image` (local) / `AsyncImage` (Coil, remote) / `Icon` |
| `CheckBox`, `Switch`, `RadioButton` | same names |
| `ProgressBar` | `CircularProgressIndicator`/`LinearProgressIndicator` |
| `Toolbar`/`AppBarLayout` | `TopAppBar` in `Scaffold` |
| `BottomNavigationView` | `NavigationBar` / `NavigationSuiteScaffold` |
| `TabLayout` | `PrimaryTabRow` + `Tab` |
| `CardView` | `Card` |
| `Chip`/`ChipGroup` | `FilterChip`/`AssistChip` in `FlowRow` |
| `Spinner` | `ExposedDropdownMenuBox` |
| `AlertDialog`/`DialogFragment` | `AlertDialog` / `Dialog` |
| `BottomSheetDialogFragment` | `ModalBottomSheet` |
| `Snackbar.make` | `SnackbarHostState.showSnackbar` |
| `Toast` | `Toast` still fine (side effect in handler) or snackbar |
| `View.GONE` / `INVISIBLE` | don't emit the composable / `Modifier.alpha(0f)` (keeps space) |
| `View.setOnClickListener` | `Modifier.clickable` / `onClick` param |
| `visibility` animation | `AnimatedVisibility` |
| `ObjectAnimator` | `animate*AsState`, `Animatable`, `updateTransition` |
| `<include>`/`<merge>` | call a composable |
| `styles.xml`/`themes.xml` | `MaterialTheme` (colors/typography/shapes) |
| `dimens.xml` | Kotlin constants / theme tokens (`object Spacing { val m = 16.dp }`) |
| `strings.xml` | still `stringResource(R.string.x)` — keep resources |
| `drawable` vectors | `painterResource(R.drawable.x)` or `ImageVector.vectorResource` |
| `ViewBinding` | none — direct references |
| `onSaveInstanceState` | `rememberSaveable`, `SavedStateHandle` |
| `Fragment` args / `SafeArgs` | Nav3 `NavKey` data classes |
| `LiveData` | `StateFlow` + `collectAsStateWithLifecycle()` |
| `WindowInsetsCompat` listeners | `Modifier.windowInsetsPadding` / `safeDrawingPadding()` |

## Interop APIs

```kotlin
// Compose inside a View hierarchy
ComposeView(context).apply {
    setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
    setContent { AppTheme { Screen() } }
}

// View inside Compose (maps, ad views, WebView, legacy custom views)
AndroidView(factory = { ctx -> WebView(ctx).apply { settings.javaScriptEnabled = true } },
            update = { it.loadUrl(url) },
            onRelease = { it.destroy() })
AndroidViewBinding(LegacyLayoutBinding::inflate) { legacyText.text = title }
```

Testing hybrid UIs: Compose 1.12 adds `onRootWithViewInteraction` to scope semantic queries to a
specific View (e.g. a RecyclerView row) without test tags.

## Pitfalls during migration

- Two sources of truth: don't keep XML state and Compose state for the same data. Move it to the
  ViewModel first.
- `Fragment` lifecycle vs composition: use `DisposeOnViewTreeLifecycleDestroyed`; otherwise leaks.
- Theme mismatch: wrap every `ComposeView` content in `AppTheme` until the whole activity is Compose.
- Nested scrolling between a `RecyclerView` and a `LazyColumn` is painful; finish converting the
  screen instead of mixing.
- Keep the same string/plural resources; don't inline text.
