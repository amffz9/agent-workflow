---
name: android-architecture
description: Design and structure Android and Kotlin Multiplatform app code — UI/domain/data layers, ViewModels and UiState modeling, repositories and data sources, unidirectional data flow, one-shot events, dependency injection (Hilt, Koin, Metro, Dagger), module structure and modularization, coroutines and Flow usage (dispatchers, structured concurrency, stateIn/shareIn), error handling, and sharing code with iOS via KMP. Use this skill whenever the user asks where code should live, how to structure a feature, "set up a ViewModel/repository/use case", "add DI", "split into modules", "clean architecture", MVVM/MVI, "is this the right way", or when a task creates any new class that isn't pure UI. Also load it for code reviews of Android Kotlin code and when converting callbacks/RxJava/LiveData/AsyncTask to coroutines and Flow.
---

# Android app architecture

Goal: code that is testable without a device, survives configuration changes and process death,
and keeps UI, business rules, and I/O separated. This follows Google's recommended architecture
(2026 edition) and adds the DI/KMP decisions that guidance leaves to you.

## Layers and dependency direction

```
UI layer        composables + ViewModels (state holders)      ──depends on──▶
Domain layer    (optional) use cases / pure Kotlin business rules ──depends on──▶
Data layer      repositories ──▶ data sources (network, db, prefs, sensors)
```

- **UI layer** renders `UiState` and sends events. No I/O, no business rules.
- **Domain layer** is optional; add use cases only when logic is reused by several ViewModels or is
  complex enough to deserve isolated tests. A use case is a class with one `suspend operator fun invoke()`
  (or returns `Flow`). Don't create pass-through use cases.
- **Data layer** owns the truth. A repository exposes domain models (not DTOs/entities), decides
  caching/offline strategy, and is the *only* thing that touches data sources. One repository per
  data type (`UserRepository`, not `ApiRepository`).
- Dependencies point downward only. Lower layers never import Compose, `Context` (except data
  sources that need it), or Android UI types.

## The UI layer done right

```kotlin
data class CheckoutUiState(
    val items: List<CartItem> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null,      // consumed via onErrorShown()
    val isSubmitting: Boolean = false,
)

@HiltViewModel
class CheckoutViewModel @Inject constructor(
    private val cartRepository: CartRepository,
    private val submitOrder: SubmitOrderUseCase,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {
    private val transient = MutableStateFlow(TransientState())
    val uiState: StateFlow<CheckoutUiState> = combine(cartRepository.observeCart(), transient) { cart, t ->
        CheckoutUiState(items = cart.items, isLoading = false, errorMessage = t.error, isSubmitting = t.submitting)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), CheckoutUiState(isLoading = true))

    fun submit() = viewModelScope.launch {
        transient.update { it.copy(submitting = true) }
        submitOrder().onFailure { e -> transient.update { it.copy(error = e.toUserMessage()) } }
        transient.update { it.copy(submitting = false) }
    }
    fun onErrorShown() = transient.update { it.copy(error = null) }
}
```

Rules:
- **One `StateFlow<UiState>` per screen**, built with `stateIn(WhileSubscribed(5_000))` so it
  stops upstream work when the UI is gone but survives rotation.
- **Events are functions on the ViewModel**; the UI calls them. No `SharedFlow` of "actions" unless
  the team already uses MVI (then follow the project's reducer pattern).
- **One-shot effects (navigate, snackbar, toast)**: model as state that the UI acknowledges
  (`errorMessage` + `onErrorShown()`), or navigate from the UI in response to state
  (`if (uiState.orderId != null) onOrderPlaced(uiState.orderId)`). A `Channel(BUFFERED)` consumed
  under `repeatOnLifecycle` is acceptable when events truly can't be state; never `SharedFlow(replay=0)`
  (drops events while the UI is stopped).
- **`SavedStateHandle`** for what must survive process death but isn't in a repository (form
  input, selected tab). Prefer `savedStateHandle.getStateFlow(key, default)`.
- ViewModels never reference `Activity`, `Fragment`, `View`, Compose, or hold `Context`
  (`@ApplicationContext` in a data source is fine). No `LiveData` in new code.
- Keep `UiState` immutable and stable: `data class`, `List` (not `MutableList`), primitives/`String`,
  `@Immutable`/`@Stable` on model classes when they cross module boundaries (see
  `android-performance` on Compose stability).
- Screen-level composable: `val state by viewModel.uiState.collectAsStateWithLifecycle()` then a
  stateless `Screen(state, onX = viewModel::x)`.

## The data layer done right

```kotlin
interface ArticleRepository {
    fun observeArticles(): Flow<List<Article>>               // stream from the local source of truth
    suspend fun refresh(): Result<Unit>                       // network → db
    suspend fun getArticle(id: String): Article?
}

class OfflineFirstArticleRepository @Inject constructor(
    private val api: ArticleApi,                 // remote data source
    private val dao: ArticleDao,                 // local data source (Room 3)
    private val dispatchers: AppDispatchers,     // injectable dispatchers (test with StandardTestDispatcher)
) : ArticleRepository {
    override fun observeArticles() = dao.observeAll().map { it.map(ArticleEntity::toDomain) }
    override suspend fun refresh() = withContext(dispatchers.io) {
        runCatching { dao.upsertAll(api.articles().map(ArticleDto::toEntity)) }
    }
    override suspend fun getArticle(id: String) = dao.get(id)?.toDomain()
}
```

- **Offline-first when data is read more than written**: DB is the source of truth, network updates
  it, UI observes the DB. Sync with WorkManager for background refresh.
- **Map at boundaries**: DTO (network) → Entity (db) → Domain model. Never leak Retrofit/Room types
  upward.
- **Expose `suspend` for one-shots and `Flow` for streams.** Room 3 already forces this.
- **Errors**: return `Result<T>` or a sealed `Outcome` from repositories for expected failures
  (network down, 404); throw only for programmer errors. Map exceptions to user-facing messages in
  the ViewModel, not the repository.
- **Dispatchers**: inject them (`AppDispatchers(io, default, main)`); Room and Retrofit `suspend`
  APIs are already main-safe, so only wrap CPU work or blocking APIs in `withContext`.
- **Single instance per repository** (`@Singleton` / Koin `single`). Data sources can be too.

## Dependency injection — choose deliberately

| Project | Recommendation |
|---|---|
| Android-only, existing Hilt | Keep Hilt (KSP: `ksp("com.google.dagger:hilt-android-compiler")`, `androidx.hilt:hilt-navigation-compose` for `hiltViewModel()`). |
| Android-only, greenfield | Hilt is still the default with the best Jetpack integration (`@HiltViewModel`, WorkManager, `@AssistedInject` for args). Metro is a strong compile-time alternative if the team prefers KMP-readiness. |
| KMP / Compose Multiplatform | **Koin** (runtime DSL or Koin Annotations + KSP for compile-time checks; `koin-compose-viewmodel`, `koin-compose-viewmodel-navigation` for Nav3) or **Metro** (Kotlin compiler plugin, Dagger/Anvil-like `@Inject`/`@Provides`/`@ContributesBinding`, compile-time graph validation, native KMP). Hilt does not work in `commonMain`. |
| Small app / library | Manual constructor injection with a hand-written `AppContainer` is fine; DI frameworks are for scaling. |

Whatever you pick: **constructor injection everywhere**, field injection only at Android entry
points (Activity, Worker). Interfaces for repositories/data sources so tests inject fakes (prefer
fakes over mocks). Snippets for each framework: `references/di-frameworks.md`.

## Coroutines & Flow essentials

- **Structured concurrency**: launch in `viewModelScope`, `lifecycleScope`, or an injected
  application scope (`CoroutineScope(SupervisorJob() + dispatchers.default)`) — never `GlobalScope`.
- **Cancellation is cooperative**: long loops call `ensureActive()`/`yield()`; don't catch
  `CancellationException` (rethrow it if you catch `Exception`).
- **`Flow` for streams, `suspend` for one-shots.** `callbackFlow { awaitClose { } }` wraps
  listeners. `flowOn(dispatcher)` affects *upstream* only.
- **Hot sharing**: `stateIn` for state, `shareIn` for events; `SharingStarted.WhileSubscribed(5_000)`
  in ViewModels; `Eagerly` only for app-lifetime singletons.
- **Collect in UI lifecycle-aware**: `collectAsStateWithLifecycle()` in Compose; `repeatOnLifecycle(STARTED)`
  in Activities.
- **Avoid**: `runBlocking` on the main thread, `Dispatchers.IO` for CPU work, `launch` inside
  `Flow` operators, `MutableStateFlow` exposed publicly (expose `StateFlow`), `first()` on a hot
  flow when you want the current value (`.value`).
- Concurrency tests: `kotlinx-coroutines-test` `runTest` + `StandardTestDispatcher` +
  `Turbine` for flows. Compose 1.11+ tests default to `StandardTestDispatcher` too.
- Kotlin 2.4: context parameters are stable — reasonable for passing a `CoroutineScope`/logger
  through domain code; don't use them for DI.
More patterns: `references/coroutines-flow.md`.

## Modularization

Start single-module; split when build times or team boundaries hurt. Recommended shape:

```
:app                      // wiring, Application, NavDisplay, DI root
:core:ui                  // theme, design system components
:core:common              // Result types, dispatchers, utils
:core:data                // repositories (impl) — or per-domain :data:articles
:core:network             // Retrofit/Ktor, DTOs
:core:database            // Room 3, entities, DAOs
:core:datastore
:core:model               // domain models (pure Kotlin)
:feature:<name>           // screens + ViewModels; depends on :core:*, never on other features
:core:testing             // fakes, test rules
```

- Features don't depend on each other; navigation between them goes through keys defined in a
  shared `:core:navigation` (or the app module).
- Use **convention plugins** (`build-logic/`) so every module shares the same Android/Kotlin/Compose
  config (see `android-build-gradle`).
- `api` vs `implementation`: expose only what consumers need; over-exposed `api` deps kill build
  parallelism.
- Enable Gradle configuration cache and, if you go big, `org.gradle.unsafe.isolated-projects`.

## Kotlin Multiplatform (when sharing with iOS/desktop/web)

- `shared` (or `:core:*` KMP modules) hold domain + data layers; UI can be shared with Compose
  Multiplatform or stay native. Keep `expect/actual` minimal (platform data sources).
- KMP-ready libraries: Ktor client, kotlinx.serialization, Room 3, DataStore, SQLDelight,
  Koin/Metro, Coil 3, Lifecycle ViewModel (`lifecycle-viewmodel` is multiplatform), Nav3 runtime.
  Not KMP: Hilt, Retrofit, OkHttp (JVM/Android only — use it as the Ktor engine on Android),
  WorkManager (Android-only; wrap behind an interface).
- ViewModels: `androidx.lifecycle.ViewModel` works in `commonMain`; on iOS host them with
  SwiftUI observation via a small wrapper (KMP-ObservableViewModel or SKIE) or
  `viewModelScope`-driven `StateFlow` bridging.
- `Kotlin Toolchain`/`kotlin-multiplatform` plugin; use `androidTarget()`, `iosArm64()/iosSimulatorArm64()`;
  export a framework via `binaries.framework` or use SPM packaging (Kotlin 2.4 supports Swift
  packages as deps).

## Reviewing Android code — what to look for

1. Business logic in composables or Activities → move to ViewModel/domain.
2. Repository returning DTOs, or ViewModel calling Retrofit directly.
3. `viewModelScope.launch` collecting a repository flow to copy into `MutableStateFlow` → use
   `stateIn`/`combine` instead.
4. Mutable collections in `UiState`, `var` in data classes.
5. `GlobalScope`, `runBlocking`, swallowed `CancellationException`, `Dispatchers.Main` in data layer.
6. Missing `SavedStateHandle` for user input that must survive process death.
7. Singletons via `object` with mutable state instead of DI-scoped classes.
8. Feature modules depending on each other; `:app` types referenced from `:core`.
9. Interfaces with a single implementation *and* no test fake — fine to drop the interface, or add
   the fake.
10. Android 17: reflection on `static final` fields or `MessageQueue` internals (now crashes).

## Common conversions

| From | To |
|---|---|
| `LiveData<T>` | `StateFlow<T>` / `Flow<T>`; `.asLiveData()` only at legacy boundaries |
| RxJava `Observable/Single` | `Flow` / `suspend`; bridge with `kotlinx-coroutines-rx3` (`.asFlow()`, `.await()`) during migration |
| Callbacks | `suspendCancellableCoroutine { cont -> … cont.invokeOnCancellation { } }` or `callbackFlow` |
| `AsyncTask`, `Thread`, `Handler.post` | `viewModelScope.launch(dispatchers.io) { }` |
| `Fragment` shared ViewModel | Activity-scoped ViewModel or a parent Nav3 entry store |
| `EventBus` | Repository `Flow` or a scoped `SharedFlow`/`Channel` behind an interface |
