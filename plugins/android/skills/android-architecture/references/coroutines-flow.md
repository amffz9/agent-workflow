# Coroutines & Flow patterns for Android

## Dispatchers, injected

```kotlin
class AppDispatchers(
    val io: CoroutineDispatcher = Dispatchers.IO,
    val default: CoroutineDispatcher = Dispatchers.Default,
    val main: CoroutineDispatcher = Dispatchers.Main.immediate,
)
// tests: AppDispatchers(io = testDispatcher, default = testDispatcher, main = testDispatcher)
```

`Dispatchers.IO` for blocking I/O (files, legacy DB, `InputStream`), `Default` for CPU (parsing
large JSON, image processing), `Main.immediate` for UI. Room/Retrofit/Ktor/DataStore `suspend`
APIs switch internally — don't wrap them in `withContext(IO)`.

## Application scope (for work that outlives a screen)

```kotlin
@Provides @Singleton @ApplicationScope
fun appScope(dispatchers: AppDispatchers): CoroutineScope = CoroutineScope(SupervisorJob() + dispatchers.default)
// use for "fire and forget that must finish" (e.g. logging a purchase) — or better, WorkManager if it must survive process death
```

## Flow recipes

```kotlin
// Combine sources into UI state
val uiState = combine(repo.items(), query, sort) { items, q, s -> items.filter { it.matches(q) }.sortedBy(s) }
    .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

// Debounced search
val results = query.debounce(300).distinctUntilChanged().flatMapLatest { q -> if (q.isBlank()) flowOf(emptyList()) else repo.search(q) }

// Retry with backoff
fun <T> Flow<T>.retryWithBackoff(times: Int = 3) = retryWhen { cause, attempt -> (cause is IOException && attempt < times).also { if (it) delay(500L * (1 shl attempt.toInt())) } }

// Wrap a listener
fun ConnectivityManager.isOnline(): Flow<Boolean> = callbackFlow {
    val cb = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(n: Network) { trySend(true) }
        override fun onLost(n: Network) { trySend(false) }
    }
    registerDefaultNetworkCallback(cb); awaitClose { unregisterNetworkCallback(cb) }
}.distinctUntilChanged()

// Parallel calls
suspend fun load() = coroutineScope { val a = async { api.a() }; val b = async { api.b() }; Merge(a.await(), b.await()) }

// Timeout + fallback
val fresh = withTimeoutOrNull(3_000) { api.fetch() } ?: cache.get()
```

## Errors and cancellation

```kotlin
try { work() }
catch (e: CancellationException) { throw e }      // never swallow
catch (e: IOException) { /* expected */ }

// runCatching swallows CancellationException — wrap it:
inline fun <T> resultOf(block: () -> T): Result<T> = try { Result.success(block()) } catch (e: CancellationException) { throw e } catch (e: Exception) { Result.failure(e) }
```

`SupervisorJob` for scopes where one child failing shouldn't cancel siblings (app scope, UI
scopes already are). `CoroutineExceptionHandler` only catches uncaught exceptions in `launch`, not
`async` (those surface on `await()`).

## Lifecycle-aware collection

```kotlin
// Compose
val state by viewModel.uiState.collectAsStateWithLifecycle()
// Activity / non-Compose
lifecycleScope.launch { repeatOnLifecycle(Lifecycle.State.STARTED) { viewModel.events.collect { } } }
```

`lifecycleScope.launchWhenStarted` is deprecated (suspends but keeps the producer running).

## Testing

```kotlin
@Test fun loads() = runTest {
    val dispatcher = StandardTestDispatcher(testScheduler)
    val vm = ArticleViewModel(FakeRepo(), AppDispatchers(dispatcher, dispatcher, dispatcher))
    vm.uiState.test {                 // Turbine
        assertEquals(Loading, awaitItem())
        advanceUntilIdle()
        assertEquals(Success(items), awaitItem())
    }
}
// Main dispatcher rule for viewModelScope:
class MainDispatcherRule(val d: TestDispatcher = UnconfinedTestDispatcher()) : TestWatcher() {
    override fun starting(desc: Description) = Dispatchers.setMain(d)
    override fun finished(desc: Description) = Dispatchers.resetMain()
}
```

`stateIn(WhileSubscribed)` flows need a collector in tests — Turbine's `test {}` or
`backgroundScope.launch { vm.uiState.collect() }` before asserting `.value`.

## Smells

- `viewModelScope.launch { repo.flow.collect { _state.value = it } }` → `stateIn`.
- `GlobalScope.launch`, `runBlocking` outside tests/`main`.
- `Dispatchers.Unconfined` in production.
- `flow.first()` where `.value` (StateFlow) was meant.
- `withContext(Dispatchers.IO)` around Room/Retrofit `suspend` calls.
- Nested `launch` inside `collect` for per-item work → `flatMapMerge`/`mapLatest`.
- Sharing a `MutableSharedFlow` as an event bus with `replay = 0` for UI events.
