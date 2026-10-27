# Compose performance deep dive

## Mental model

Three phases per frame: **composition** (run composables, build the tree) → **layout** (measure/place)
→ **draw**. Reading a `State` in a phase subscribes that phase to it. The cheapest fix is often to
move a state read to a later phase so composition doesn't re-run.

## Stability and skipping (2026 rules)

- The Compose compiler's **strong skipping mode** is the default. A composable is skipped when all
  parameters compare equal — `equals()` for stable types, `===` for unstable ones. Lambdas are
  automatically remembered (captured unstable values compared by reference).
- Types are stable if: primitives, `String`, function types, enums, `@Immutable`/`@Stable`
  annotated classes, or classes whose public `val`s are all stable. `List<T>`/`Map` from
  `kotlin.collections` are considered unstable by the compiler (they *could* be mutable) — under
  strong skipping this only matters when you allocate a *new* list with equal content each
  composition; then use `kotlinx.collections.immutable` (`ImmutableList`) or mark the holder
  `@Immutable`.
- Classes from other Gradle modules/libraries that the compiler can't analyze default to unstable;
  fix with a stability configuration file:
  `composeCompiler { stabilityConfigurationFiles.add(rootProject.layout.projectDirectory.file("compose_stability.conf")) }`
  containing lines like `com.example.model.*` / `java.time.LocalDate`.
- Inspect with compiler reports: `composeCompiler { reportsDestination = layout.buildDirectory.dir("compose_reports"); metricsDestination = … }`
  then read `<module>-classes.txt` (look for `unstable class`) and `<module>-composables.txt`
  (`restartable skippable` is what you want; `unstable` params listed per composable).

## Patterns that fix recomposition storms

```kotlin
// 1. Defer high-frequency reads to layout/draw
Box(Modifier.offset { IntOffset(0, scrollState.value / 2) })            // not Modifier.offset(y = (scrollState.value/2).dp)
Box(Modifier.graphicsLayer { alpha = progress.value })                  // not Modifier.alpha(progress.value)
Canvas(Modifier.fillMaxSize()) { drawCircle(color, radius = radiusState.value) }  // draw-phase read

// 2. derivedStateOf for thresholds
val showFab by remember { derivedStateOf { listState.firstVisibleItemIndex > 3 } }

// 3. Lambda parameters instead of values for things only the child draws
LinearProgressIndicator(progress = { progress })    // Material 3 API is already lambda-based

// 4. Keys + contentType in lazy layouts; stable item ids
LazyColumn { items(items, key = { it.id }, contentType = { it.kind }) { ItemRow(it) } }

// 5. Hoist expensive computations out of composition, or remember with keys
val sorted = remember(items, sortOrder) { items.sortedWith(sortOrder.comparator) }   // or do it in the ViewModel

// 6. Don't create new objects per composition in parameters
val colors = remember { ButtonDefaults.buttonColors(...) }   // when custom colors are static

// 7. Avoid reading LocalConfiguration / whole-window state in leaf composables
```

## Layout-phase tips

- Avoid `SubcomposeLayout` (`BoxWithConstraints`, `LazyColumn` inside non-lazy parents) where a
  plain `Layout` works; subcomposition is expensive.
- `Modifier.height(IntrinsicSize.Min)` triggers extra measure passes — use sparingly.
- Nesting many `Row/Column` with `weight` is fine; deep nesting of `Box` + `padding` chains is
  cheap in Compose (unlike Views). Avoid `Modifier.layout` doing allocations.
- Text: `Text` with `maxLines`/`overflow` set, pre-computed `AnnotatedString` remembered.

## Draw-phase tips

- `Modifier.clip` + `shadow` + `alpha < 1` promote to offscreen layers — combine into one
  `graphicsLayer { shape = …; clip = true; shadowElevation = … }`.
- Use `drawWithCache { onDrawBehind { } }` to cache `Path`s/`Brush`es.
- Compose 1.12 `LayerOutsets` avoids implicit clipping when a layer needs to draw outside bounds
  (instead of oversizing the composable).

## Lists

- Item composables should be `restartable skippable` (check reports). Pass primitives/IDs when
  the row only needs them.
- Provide fixed sizes when known (`Modifier.height(72.dp)`) to help prefetch.
- Large images: `AsyncImage` with size hints; `ContentScale.Crop`.
- `LazyVerticalStaggeredGrid` and nested `LazyRow`s are fine; give inner rows `key`s and
  `rememberLazyListState()` hoisted into the item's saved state.
- Compose 1.10+: pausable composition in prefetch is on by default; `LazyLayoutPrefetchStrategy`
  can be tuned for carousels.

## Animations

- Use `animate*AsState`/`Animatable` (they write state read in draw/layout via lambdas in most
  Material components). Avoid animating a value that's read in composition by many children.
- `AnimatedVisibility`/`AnimatedContent` create layers; don't nest them per list item unnecessarily.
- Shared element transitions: keep `sharedBounds` on containers, not text; debug with
  `LookaheadAnimationVisualDebugging`.

## Measuring

- **Layout Inspector** (Studio): enable "Show recomposition counts"; red = recomposed a lot, skipped
  counts tell you what's fine.
- **Macrobenchmark** scroll journey with `FrameTimingMetric` (report `frameOverrunMs` P50/P90/P99)
  and `TraceSectionMetric("Compose:recompose")`.
- **Perfetto**: look for long `Compose:recompose`, `Compose:layout`, `Compose:draw` slices on the
  main thread; `Choreographer#doFrame` > 16 ms = jank.
- **Microbenchmark** for pure functions used in composition (formatters, diffing).

## Anti-patterns checklist

- Reading `scrollState.value`/`animatedValue` directly in a composable body.
- `ViewModel` exposing `MutableList` or mutable data classes in `UiState`.
- Passing `viewModel` objects down the tree (unstable, and leaks concerns).
- `Modifier` chains built inside `items {}` from computed values without `remember`.
- `LaunchedEffect(Unit)` that launches per item in a list (N coroutines).
- Heavy work in `remember { }` without keys, or with keys that change every frame.
- Big `when` over a `sealed` UiState at the root that swaps the entire screen tree on minor
  changes — structure state so subtrees keep identity.
