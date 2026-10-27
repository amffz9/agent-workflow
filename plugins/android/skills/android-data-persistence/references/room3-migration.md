# Migrating Room 2.x → Room 3.0

Official guide: developer.android.com/training/data-storage/room/migration-2-to-3. Room 2 stays in
maintenance (patches on 2.8.x). Do the migration in one PR per module; it's mostly mechanical.

## Pre-flight (do these on Room 2.8 first)

1. Convert every DAO to `suspend`/`Flow` (drop blocking/`LiveData` DAOs). Room 3 forbids blocking.
2. Switch to KSP if still on kapt. Room 3 has no kapt/Java processor (KSP still processes Java
   sources, but generated code is Kotlin — the module needs the Kotlin plugin).
3. Adopt `SQLiteDriver`: `.setDriver(BundledSQLiteDriver())` + migrations written against
   `SQLiteConnection` where possible (`room-sqlite-wrapper` bridges the rest).
4. Export schemas (`room { schemaDirectory(...) }`) and commit them; write migration tests.

## The change list

| Room 2 | Room 3 |
|---|---|
| `androidx.room:room-runtime`, `room-compiler`, `room-ktx`, `room-paging`, `room-testing` | `androidx.room3:room3-runtime`, `room3-compiler`, (ktx built-in), `room3-paging`, `room3-testing`, `room3-sqlite-wrapper` |
| `import androidx.room.*` | `import androidx.room3.*` |
| `@TypeConverter` / `@TypeConverters` / `@ProvidedTypeConverter` | `@ColumnTypeConverter` / `@ColumnTypeConverters` / `@ProvidedColumnTypeConverter` |
| `Migration(1, 2) { override fun migrate(db: SupportSQLiteDatabase) }` | `Migration(1, 2) { override suspend fun migrate(connection: SQLiteConnection) }` |
| `RoomDatabase.Callback.onCreate(db: SupportSQLiteDatabase)` | `onCreate(connection: SQLiteConnection)` (suspend) |
| `db.openHelper.writableDatabase` | `db.getSupportWrapper()` (room3-sqlite-wrapper, temporary) or `db.useWriterConnection { }` |
| `setQueryExecutor` / `setTransactionExecutor` | `setQueryCoroutineContext(dispatcher)` |
| `fun get(): Entity` (blocking) | `suspend fun get(): Entity` |
| `fun observe(): LiveData<T>` | `Flow<T>` (or `room3-livedata` + `LiveDataDaoReturnTypeConverter` registered on `@Database`) |
| `PagingSource` return type just works | add `@DaoReturnTypeConverters(PagingSourceDaoReturnTypeConverter::class)` (room3-paging) |
| `db.runInTransaction { }` | `db.withTransaction { }` (suspend) / `useWriterConnection` |
| `SupportSQLiteQuery` in `@RawQuery` | `RoomRawQuery` |
| `Room.databaseBuilder(ctx, AppDatabase::class.java, "app.db")` | `Room.databaseBuilder<AppDatabase>(ctx, name)` (reified; in KMP pass a full path) |

## Recipe

```bash
# 1. Dependencies (version catalog): rename artifacts; room plugin id stays "androidx.room" (version = room3)
# 2. Package rename (review each hunk — don't touch generated or third-party code)
grep -rl "androidx.room" --include=*.kt src/ | xargs sed -i 's/androidx\.room\./androidx.room3./g; s/androidx\.room$/androidx.room3/'
# 3. Annotation renames
grep -rl "@TypeConverter" --include=*.kt src/ | xargs sed -i 's/@TypeConverters/@ColumnTypeConverters/g; s/@TypeConverter\b/@ColumnTypeConverter/g; s/@ProvidedTypeConverter/@ProvidedColumnTypeConverter/g'
# 4. Fix compile errors: migrations → suspend + SQLiteConnection; blocking DAOs → suspend; callbacks
./gradlew :core:database:compileDebugKotlin
# 5. Register DAO return-type converters if you use Paging/LiveData/Rx
# 6. Run DAO + migration tests on JVM (BundledSQLiteDriver) and instrumented
```

## Gotchas

- `SQLiteConnection.execSQL` doesn't return cursors; for reads inside a migration use
  `connection.prepare("SELECT …").use { stmt -> while (stmt.step()) { stmt.getText(0) } }`.
- `@Transaction` DAO functions must be `suspend` (or return `Flow`).
- Blocking access from Java callers: expose a Kotlin facade with `runBlocking` only at the legacy
  boundary, and plan to remove it.
- The `androidx.room` (2.x) and `androidx.room3` packages can coexist in one app during a staged
  migration (different packages), but each database must live in exactly one of them.
- Hilt/Koin modules providing `AppDatabase`/DAOs need import updates too — the compiler will tell
  you; run `compileDebugKotlin` per module.
- Schema JSON format is compatible; keep the same `schemas/` directory and version numbers.
