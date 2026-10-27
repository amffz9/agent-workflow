# DI frameworks — setup and idioms (2026)

## Hilt (Android-only; Dagger 2.5x; KSP)

```toml
[versions] hilt = "2.57.1"  # verify; androidxHilt = "1.4.0"; ksp = "<kotlin>-<ksp>"
[libraries]
hilt-android  = { module = "com.google.dagger:hilt-android", version.ref = "hilt" }
hilt-compiler = { module = "com.google.dagger:hilt-android-compiler", version.ref = "hilt" }
hilt-navigation-compose = { module = "androidx.hilt:hilt-navigation-compose", version.ref = "androidxHilt" }
hilt-work = { module = "androidx.hilt:hilt-work", version.ref = "androidxHilt" }
[plugins]
hilt = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
ksp  = { id = "com.google.devtools.ksp", version.ref = "ksp" }
```

```kotlin
plugins { alias(libs.plugins.hilt); alias(libs.plugins.ksp) }
dependencies { implementation(libs.hilt.android); ksp(libs.hilt.compiler) }   // never kapt

@HiltAndroidApp class App : Application()
@AndroidEntryPoint class MainActivity : ComponentActivity()

@Module @InstallIn(SingletonComponent::class)
abstract class DataModule {
    @Binds @Singleton abstract fun bindArticleRepo(impl: OfflineFirstArticleRepository): ArticleRepository
    companion object {
        @Provides @Singleton fun provideDb(@ApplicationContext ctx: Context): AppDatabase = buildDatabase(ctx)
        @Provides fun provideDao(db: AppDatabase): ArticleDao = db.articleDao()
    }
}

@HiltViewModel class ArticleViewModel @Inject constructor(repo: ArticleRepository, handle: SavedStateHandle) : ViewModel()

// Args from Nav3 keys → assisted injection
@HiltViewModel(assistedFactory = DetailViewModel.Factory::class)
class DetailViewModel @AssistedInject constructor(@Assisted val id: String, repo: ArticleRepository) : ViewModel() {
    @AssistedFactory interface Factory { fun create(id: String): DetailViewModel }
}
// in entry<Detail> { key -> val vm = hiltViewModel<DetailViewModel, DetailViewModel.Factory> { it.create(key.id) } }

// Qualifiers for dispatchers
@Qualifier @Retention(AnnotationRetention.BINARY) annotation class IoDispatcher
@Provides @IoDispatcher fun io(): CoroutineDispatcher = Dispatchers.IO

// WorkManager
@HiltWorker class SyncWorker @AssistedInject constructor(@Assisted ctx: Context, @Assisted params: WorkerParameters, repo: ArticleRepository) : CoroutineWorker(ctx, params)
// + androidx.hilt:hilt-work, HiltWorkerFactory in Application (Configuration.Provider), remove default initializer in manifest
```

Testing: `@HiltAndroidTest` + `HiltAndroidRule`, `@UninstallModules` + `@TestInstallIn` to swap
fakes; for plain unit tests just construct classes directly.

## Koin (Android + KMP; runtime DSL, optional KSP annotations)

```kotlin
// build: implementation(platform("io.insert-koin:koin-bom:4.x")); koin-core, koin-android,
// koin-androidx-compose (or koin-compose-viewmodel for KMP), koin-compose-viewmodel-navigation (Nav3), koin-test
val dataModule = module {
    single<ArticleRepository> { OfflineFirstArticleRepository(get(), get(), get()) }
    single { buildDatabase(androidContext()) }
    single { get<AppDatabase>().articleDao() }
    single { AppDispatchers() }
    viewModel { ArticleViewModel(get(), get()) }
    viewModel { (id: String) -> DetailViewModel(id, get()) }
}
class App : Application() { override fun onCreate() { super.onCreate(); startKoin { androidContext(this@App); modules(dataModule, uiModule) } } }
// Compose: val vm: DetailViewModel = koinViewModel { parametersOf(key.id) }
// Compile-time-ish safety: test { dataModule.verify() }  (koin-test), or Koin Annotations + KSP with KOIN_CONFIG_CHECK
```

KMP: define modules in `commonMain`; provide platform pieces via `expect fun platformModule(): Module`.

## Metro (Kotlin compiler plugin; KMP; Dagger/Anvil-style, compile-time)

```kotlin
// plugins { id("dev.zacsweers.metro") version "<x>" }
@DependencyGraph(AppScope::class)
interface AppGraph {
    val articleViewModelFactory: ArticleViewModel.Factory
    @Provides fun provideDb(ctx: Context): AppDatabase = buildDatabase(ctx)
    @DependencyGraph.Factory fun interface Factory { fun create(@Provides ctx: Context): AppGraph }
}
@Inject @SingleIn(AppScope::class)
@ContributesBinding(AppScope::class)
class OfflineFirstArticleRepository(...) : ArticleRepository
@Inject class ArticleViewModel(repo: ArticleRepository) : ViewModel() { @AssistedFactory fun interface Factory { fun create(): ArticleViewModel } }
```

Missing bindings fail the *build*, not app launch. Interop with Dagger/Anvil annotations exists for
migrations. Best fit when you want compile-time safety in `commonMain`.

## Manual DI (small apps)

```kotlin
class AppContainer(ctx: Context) {
    val dispatchers = AppDispatchers()
    val db by lazy { buildDatabase(ctx) }
    val api by lazy { buildApi() }
    val articleRepository: ArticleRepository by lazy { OfflineFirstArticleRepository(api, db.articleDao(), dispatchers) }
}
class App : Application() { lateinit var container: AppContainer; override fun onCreate() { super.onCreate(); container = AppContainer(this) } }
// ViewModel factory: viewModelFactory { initializer { ArticleViewModel((this[APPLICATION_KEY] as App).container.articleRepository) } }
```

## Choosing, in one paragraph

Hilt for Android-only teams that value Jetpack integration and don't plan KMP; Koin when you want
low ceremony and KMP now (verify the graph in tests); Metro when you want Dagger-grade compile-time
guarantees in KMP. Don't mix two frameworks in one module; bridging at the app boundary during a
migration is fine.
