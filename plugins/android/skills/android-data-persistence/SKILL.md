---
name: android-data-persistence
description: Store, query, cache, and migrate data on Android and KMP — Room 3 (androidx.room3, the new Kotlin/KSP/coroutines-only version) and legacy Room 2, SQLite drivers, schema migrations, DataStore (Preferences and Proto) for settings, Paging 3 for large lists, in-memory caches, files and scoped storage (app-private files, MediaStore, Storage Access Framework, Photo Picker), and encryption at rest. Use this skill whenever the task mentions a database, SQL, entities/DAOs, "save locally", "remember the user's setting", offline cache, SharedPreferences, DataStore, Room, migrations, Paging, downloads, files, images on disk, or "the data disappears/resets". Load it before writing any Room code, because Room 3 changed packages, annotations, and requires suspend DAOs — older training data emits Room 2 code that will not compile against room3.
---

# Data persistence on Android

## Decision table

| Data | Use |
|---|---|
| Structured, relational, queried, observed | **Room 3** (`androidx.room3`) — Room 2.8 only if the project already uses it and isn't migrating |
| Key-value settings / small typed prefs | **DataStore** (Preferences) or Proto DataStore for typed schemas. Not `SharedPreferences` for new code. |
| Large paginated lists from network+db | **Paging 3** + Room `PagingSource` + `RemoteMediator` |
| Blobs (images, downloads, documents) | Files: app-private (`filesDir`/`cacheDir`), shared media via `MediaStore`, user-picked documents via SAF / Photo Picker. Store *paths/URIs* in the DB, not blobs. |
| Secrets (tokens, keys) | Android Keystore-backed encryption + DataStore/file; see `android-security`. Never plaintext prefs. |
| Cross-platform (KMP) | Room 3, DataStore, SQLDelight, Okio for files, `kotlinx-io` |

Source-of-truth principle: the UI observes the local store (`Flow`), the network updates it. See
`android-architecture` for repository shape.

## Room 3 (`androidx.room3`, stable 3.0.x since July 2026)

What changed vs Room 2 (why old snippets break):
- Package `androidx.room3`; artifacts `androidx.room3:room3-runtime`, `room3-compiler` (KSP only,
  no kapt/Java processor), `room3-ktx` gone (built in), `room3-paging`, `room3-testing`,
  `room3-sqlite-wrapper` (compat), `room3-livedata`, `room3-rxjava3`.
- Kotlin codegen only; DAO functions must be `suspend` or return `Flow` (blocking DAOs are a
  compile error). `CoroutineContext` replaces executors.
- Backed by `androidx.sqlite` **SQLiteDriver** APIs; `SupportSQLiteDatabase` is gone from the core.
  Migrations/callbacks receive `SQLiteConnection` and are `suspend`.
- `@TypeConverter` → `@ColumnTypeConverter`, `@TypeConverters` → `@ColumnTypeConverters`,
  `@ProvidedTypeConverter` → `@ProvidedColumnTypeConverter`. New `@DaoReturnTypeConverter` for
  custom return types (Paging/LiveData integrations use it and must be registered on the `@Database`).
- KMP-native (Android, JVM, iOS, JS/Wasm).

```toml
[versions] room3 = "3.0.1"; sqlite = "2.7.0"; ksp = "<kotlin>-<ksp>"
[libraries]
room3-runtime  = { module = "androidx.room3:room3-runtime",  version.ref = "room3" }
room3-compiler = { module = "androidx.room3:room3-compiler", version.ref = "room3" }
room3-paging   = { module = "androidx.room3:room3-paging",   version.ref = "room3" }
room3-testing  = { module = "androidx.room3:room3-testing",  version.ref = "room3" }
sqlite-bundled = { module = "androidx.sqlite:sqlite-bundled", version.ref = "sqlite" }
[plugins] room = { id = "androidx.room", version.ref = "room3" }; ksp = { id = "com.google.devtools.ksp", version.ref = "ksp" }
```

```kotlin
plugins { alias(libs.plugins.ksp); alias(libs.plugins.room) }
room { schemaDirectory("$projectDir/schemas") }         // exported schemas — commit them
dependencies { implementation(libs.room3.runtime); implementation(libs.sqlite.bundled); ksp(libs.room3.compiler) }
```

```kotlin
@Entity(tableName = "articles", indices = [Index("updated_at")])
data class ArticleEntity(
    @PrimaryKey val id: String,
    val title: String,
    @ColumnInfo(name = "updated_at") val updatedAt: Long,
    val tags: List<String>,             // via converter below
)

class Converters { @ColumnTypeConverter fun listToJson(v: List<String>) = Json.encodeToString(v); @ColumnTypeConverter fun jsonToList(s: String): List<String> = Json.decodeFromString(s) }

@Dao interface ArticleDao {
    @Query("SELECT * FROM articles ORDER BY updated_at DESC") fun observeAll(): Flow<List<ArticleEntity>>
    @Query("SELECT * FROM articles WHERE id = :id") suspend fun get(id: String): ArticleEntity?
    @Upsert suspend fun upsertAll(items: List<ArticleEntity>)
    @Query("DELETE FROM articles WHERE updated_at < :cutoff") suspend fun prune(cutoff: Long): Int
    @Transaction @Query("SELECT * FROM articles WHERE id = :id") suspend fun getWithComments(id: String): ArticleWithComments?
}

@Database(entities = [ArticleEntity::class, CommentEntity::class], version = 2, exportSchema = true)
@ColumnTypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() { abstract fun articleDao(): ArticleDao }

fun buildDatabase(ctx: Context, dispatchers: AppDispatchers): AppDatabase =
    Room.databaseBuilder<AppDatabase>(ctx, ctx.getDatabasePath("app.db").absolutePath)
        .setDriver(BundledSQLiteDriver())                  // consistent SQLite across API levels & platforms
        .setQueryCoroutineContext(dispatchers.io)
        .addMigrations(MIGRATION_1_2)
        .build()

val MIGRATION_1_2 = object : Migration(1, 2) {
    override suspend fun migrate(connection: SQLiteConnection) {
        connection.execSQL("ALTER TABLE articles ADD COLUMN tags TEXT NOT NULL DEFAULT '[]'")
    }
}
```

- `@Upsert` over `@Insert(onConflict = REPLACE)` (REPLACE deletes+inserts and fires cascades).
- `Flow` queries re-emit on any change to the queried tables; add `distinctUntilChanged()` if
  needed.
- **Migrations**: bump `version`, add a `Migration`, commit the new `schemas/<n>.json`. Auto
  migrations: `autoMigrations = [AutoMigration(from = 1, to = 2)]` for additive changes (with
  `@RenameColumn`/`@DeleteTable` specs). `fallbackToDestructiveMigration(dropAllTables = true)` only in
  debug/prototypes — it wipes user data.
- Relations: `@Relation` + `@Embedded` in a POJO, annotate the query `@Transaction`. Keep DAOs
  returning entities/POJOs; map to domain models in the repository.
- FTS: `@Fts4` entity for search. Views: `@DatabaseView`.
- Raw SQL: `@RawQuery(observedEntities = [...])` with `RoomRawQuery`.
- Bridge for legacy code needing `SupportSQLiteDatabase`: `room3-sqlite-wrapper` →
  `db.getSupportWrapper()`; plan to remove it.
- KMP: same code in `commonMain`; on iOS pass the file path via `NSFileManager`; use
  `BundledSQLiteDriver` everywhere.

Migrating Room 2 → 3 (mechanical but touches everything): `references/room3-migration.md`.

## Room 2.8.x (maintenance; existing projects)

Same annotation model with `androidx.room` package, `@TypeConverter`, non-suspend DAOs allowed
(`room-ktx` for suspend/Flow), `SupportSQLiteDatabase` in migrations. Room 2.8 already supports
`SQLiteDriver` + `BundledSQLiteDriver` and KMP — adopt those first; it makes the Room 3 move
smaller. Use KSP (`ksp(libs.room.compiler)`), never kapt.

## DataStore (1.2.x)

```kotlin
val Context.settings: DataStore<Preferences> by preferencesDataStore("settings")   // one instance per file, app-wide
object Keys { val DARK = booleanPreferencesKey("dark_theme"); val LAST_SYNC = longPreferencesKey("last_sync") }
val darkTheme: Flow<Boolean> = ctx.settings.data.catch { if (it is IOException) emit(emptyPreferences()) else throw it }.map { it[Keys.DARK] ?: false }
suspend fun setDark(v: Boolean) { ctx.settings.edit { it[Keys.DARK] = v } }
```

- **One `DataStore` per file per process** — creating two crashes. Provide it via DI as a singleton.
- Reads are `Flow`; `first()` for a one-shot. Writes are transactional and `suspend`.
- Proto DataStore (`datastore` + protobuf-lite or kotlinx.serialization with a custom `Serializer`)
  for typed, versioned settings. DataStore is KMP (`datastore-core`, `datastore-preferences-core`)
  with `PreferenceDataStoreFactory.createWithPath(okio path)`.
- Migrate from `SharedPreferences` with `SharedPreferencesMigration(ctx, "old_prefs")` in
  `preferencesDataStore(migrations = …)`.
- Don't store large or frequently-written data in DataStore (whole file rewrites); don't store
  secrets in it unencrypted.

## Paging 3 (3.4.x)

```kotlin
@Dao interface ArticleDao { @Query("SELECT * FROM articles ORDER BY updated_at DESC") fun pagingSource(): PagingSource<Int, ArticleEntity> }
// Room 3: register PagingSourceDaoReturnTypeConverter on the @Database (room3-paging)
val pager = Pager(PagingConfig(pageSize = 30, prefetchDistance = 10),
                  remoteMediator = ArticleRemoteMediator(api, db)) { dao.pagingSource() }
val flow: Flow<PagingData<Article>> = pager.flow.map { it.map(ArticleEntity::toDomain) }.cachedIn(viewModelScope)
// Compose: val items = flow.collectAsLazyPagingItems(); LazyColumn { items(items.itemCount, key = items.itemKey { it.id }) { i -> items[i]?.let { ArticleRow(it) } } }
```

`RemoteMediator` writes network pages into Room in a transaction and stores remote keys in a
table; the UI only observes Room. Handle `LoadState` (`items.loadState.refresh is LoadState.Error`)
for retry UI.

## Files & storage

- App-private: `ctx.filesDir` (persistent), `ctx.cacheDir` (evictable; keep < ~10% of free space,
  use `StorageManager` for quotas), `ctx.noBackupFilesDir`. No permission needed. Use Okio for
  streams; write to a temp file and rename for atomicity.
- Shared media (photos/videos/audio the user should see in gallery): `MediaStore` inserts with
  `IS_PENDING`; reading others' media needs `READ_MEDIA_IMAGES/VIDEO` (API 33+) or the
  **Photo Picker** (`PickVisualMedia` contract — no permission, preferred; Android 17 supports
  `PhotoPickerUiCustomizationParams` for portrait thumbnails).
- Documents: Storage Access Framework (`OpenDocument`, `CreateDocument`, `OpenDocumentTree`) —
  persist access with `takePersistableUriPermission`.
- Downloads: `DownloadManager` for large, user-visible downloads; WorkManager + OkHttp for
  app-managed ones. Don't hold files open across process death.
- Backup: Auto Backup (`android:fullBackupContent`/`dataExtractionRules`) — exclude caches, tokens,
  and databases that would be inconsistent when restored.
- Sizes: don't load whole files into memory; stream. For images, decode with Coil (`android-networking`)
  or `ImageDecoder` with sample size.

## Caching strategy (in-memory)

- ViewModel-scoped `StateFlow` is the cache for a screen. For app-wide memory caches use
  `LruCache<K, V>` or Coil's memory cache for images. Don't build a second DB in memory; Room +
  `Flow` is fast enough with indices.

## Testing persistence

- Room: `Room.inMemoryDatabaseBuilder<AppDatabase>(ctx).setDriver(BundledSQLiteDriver()).build()`
  in Robolectric/JVM tests (Room 3 + bundled driver runs on the JVM without a device); DAO tests
  are plain `runTest`. Migration tests: `MigrationTestHelper` (`room3-testing`) with exported schemas.
- DataStore: `PreferenceDataStoreFactory.create(scope = testScope) { tmpFolder.newFile("test.preferences_pb") }`.
- Files: `TemporaryFolder`/`@TempDir` and inject the base directory.

## Verify

- Schema JSON is exported and committed; migration test passes for every version bump.
- `adb shell run-as <pkg> ls databases/` then `adb pull` (debuggable builds) or Android Studio
  **App Inspection → Database Inspector** to view live tables and run queries.
- DataStore file: `adb shell run-as <pkg> ls files/datastore/`.
- Data survives `adb shell am kill <pkg>` and reinstall (`adb install -r`).
