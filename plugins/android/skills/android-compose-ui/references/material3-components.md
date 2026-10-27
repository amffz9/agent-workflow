# Material 3 components in Compose — what to reach for

Artifact: `androidx.compose.material3:material3` (1.4.x stable; 1.5 in alpha). Expressive APIs need
`@OptIn(ExperimentalMaterial3ExpressiveApi::class)`. Anything below marked *(exp)* is experimental
in 1.4 — fine to use, but expect API churn.

## Theme root

```kotlin
@Composable
fun AppTheme(darkTheme: Boolean = isSystemInDarkTheme(), dynamicColor: Boolean = true, content: @Composable () -> Unit) {
    val context = LocalContext.current
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S ->
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        darkTheme -> DarkColors
        else -> LightColors
    }
    MaterialTheme(colorScheme = colorScheme, typography = AppTypography, shapes = AppShapes, content = content)
    // or MaterialExpressiveTheme(colorScheme, motionScheme = MotionScheme.expressive(), ...) for the Expressive look
}
```

Generate `LightColors`/`DarkColors` from a seed with Material Theme Builder; export Kotlin.

## Component map

| Need | Component | Notes |
|---|---|---|
| Screen skeleton | `Scaffold` | Consume `innerPadding`. `contentWindowInsets` to tweak. |
| App bar | `TopAppBar`, `CenterAlignedTopAppBar`, `MediumTopAppBar`, `LargeTopAppBar`, *(exp)* `MediumFlexibleTopAppBar` | Scroll behavior via `TopAppBarDefaults.enterAlwaysScrollBehavior()` + `Modifier.nestedScroll(behavior.nestedScrollConnection)` on the scrollable. |
| Bottom nav | `NavigationBar` + `NavigationBarItem`; *(exp)* `ShortNavigationBar` | Or `NavigationSuiteScaffold` to adapt to rail/drawer. |
| Side nav | `NavigationRail`, `ModalNavigationDrawer`/`PermanentNavigationDrawer` | |
| Actions | `Button`, `FilledTonalButton`, `OutlinedButton`, `TextButton`, `ElevatedButton`, `IconButton`, `FilledIconButton`, `FloatingActionButton`, `ExtendedFloatingActionButton`; *(exp)* `ButtonGroup`, `SplitButton`, `FloatingActionButtonMenu`, `FloatingToolbar` | One primary action per screen. |
| Selection | `Checkbox`, `TriStateCheckbox`, `RadioButton`, `Switch`, `SegmentedButton` (`SingleChoiceSegmentedButtonRow`), `FilterChip`, `AssistChip`, `InputChip`, `SuggestionChip` | Chips wrap in `FlowRow`. |
| Text input | `TextField`/`OutlinedTextField` (state-based overloads accept `TextFieldState`), `BasicTextField`, `BasicSecureTextField`, `SecureTextField` | Use `KeyboardOptions(imeAction=…)`, `supportingText`, `isError`. |
| Lists | `ListItem` inside `LazyColumn`; `HorizontalDivider` | `ListItem` handles 1–3 lines, leading/trailing content. |
| Cards | `Card`, `ElevatedCard`, `OutlinedCard` | Clickable overloads exist. |
| Dialogs | `AlertDialog`, `BasicAlertDialog`, `DatePickerDialog`, `TimePicker`/`TimeInput` | |
| Sheets | `ModalBottomSheet(sheetState = rememberModalBottomSheetState())`, `BottomSheetScaffold` | Dismiss via `scope.launch { sheetState.hide() }.invokeOnCompletion { … }`. |
| Menus | `DropdownMenu` + `DropdownMenuItem`, `ExposedDropdownMenuBox` (combobox) | |
| Search | `SearchBar` / `DockedSearchBar` (`SearchBarDefaults.InputField`) | |
| Progress | `LinearProgressIndicator`, `CircularProgressIndicator`, *(exp)* `LoadingIndicator`, `ContainedLoadingIndicator`, wavy indicators | Determinate variants take `progress = { value }` lambda. |
| Feedback | `SnackbarHost` + `SnackbarHostState.showSnackbar()` (suspend), `Badge`/`BadgedBox`, `Tooltip` (`TooltipBox`) | Show snackbars from a coroutine, not the body. |
| Pull to refresh | `PullToRefreshBox(isRefreshing, onRefresh) { LazyColumn… }` | |
| Tabs | `PrimaryTabRow`/`SecondaryTabRow` + `Tab`; `PrimaryScrollableTabRow` | Pair with `HorizontalPager`. |
| Sliders | `Slider`, `RangeSlider` | *(exp)* centered/vertical variants. |
| Dividers/Surfaces | `HorizontalDivider`, `VerticalDivider`, `Surface` | `Surface` sets content color; use it as a container. |
| Carousel | *(exp)* `HorizontalMultiBrowseCarousel`, `HorizontalUncontainedCarousel` | |
| Date/time | `DatePicker` + `rememberDatePickerState()`, `DateRangePicker`, `TimePicker` | |
| Icons | `Icon(Icons.Default.Add, contentDescription)`; `Icons.AutoMirrored.Filled.ArrowBack` | |

## Typography and shapes

`MaterialTheme.typography.{displayLarge…labelSmall}`; Expressive adds emphasized styles
(`*Emphasized`) and new shapes (`MaterialShapes`, `MaterialTheme.shapes.largeIncreased`, etc.).
Custom fonts: `FontFamily(Font(R.font.inter_regular, FontWeight.Normal), …)` or downloadable fonts
via `GoogleFont` (Compose 1.12 supports variation settings on downloadable fonts).

## Color roles cheat-sheet

Use pairs: `primary/onPrimary`, `primaryContainer/onPrimaryContainer`, `surface/onSurface`,
`surfaceVariant/onSurfaceVariant`, `surfaceContainer{Lowest,Low,,High,Highest}` for elevation tiers,
`outline`/`outlineVariant` for borders, `error/onError`. Backgrounds: `background` = `surface` in M3.
Use `LocalContentColor`/`contentColorFor(container)` so text stays legible on any container.

## Gotchas

- `TopAppBar` in `Scaffold` needs `Modifier.nestedScroll` on the scroll container for collapse.
- `ModalBottomSheet` isn't part of the `Scaffold`; it draws in its own window and won't respect
  `Scaffold` insets — pass `contentWindowInsets` or handle `navigationBars` insets yourself.
- `AlertDialog(onDismissRequest)` must handle dismissal; `properties = DialogProperties(usePlatformDefaultWidth = false)` for wide dialogs on tablets.
- `LazyColumn` + `ListItem` with `Modifier.clickable` on the item, not the `ListItem` content.
- Don't nest `Surface` + `Card` + `Box(background)` — one container is enough.
- `Icons.Default.ArrowBack` is deprecated → `Icons.AutoMirrored.Filled.ArrowBack`.
- `rememberModalBottomSheetState(skipPartiallyExpanded = true)` for simple sheets.
