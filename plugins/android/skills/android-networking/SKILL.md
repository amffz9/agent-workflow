---
name: android-networking
description: Implement, debug, and harden networking in Android and KMP apps — REST/JSON APIs with Retrofit + OkHttp or Ktor client, kotlinx.serialization/Moshi, authentication headers and token refresh, timeouts/retries/backoff, HTTP caching and ETags, pagination, offline-first sync, connectivity monitoring, WebSockets/SSE/gRPC/GraphQL, image loading with Coil, file upload/download, background transfers with WorkManager, Network Security Config (TLS, certificate transparency, pinning, cleartext), the Android 17 local-network permission, and network debugging/testing with MockWebServer and the Network Inspector. Use this skill whenever the task mentions an API, endpoint, HTTP, JSON, fetch/upload/download, "call the backend", Retrofit, OkHttp, Ktor, interceptor, 401/timeout/SSL errors, "no internet" handling, or loading images from URLs — even if the word "network" isn't used.
---

# Android networking

## Choose the client (don't mix two stacks in one app)

| Situation | Stack |
|---|---|
| Android-only app, existing Retrofit | **Retrofit 3.x + OkHttp 5.x + kotlinx.serialization** (or Moshi if already used). Retrofit 3 requires OkHttp ≥ 4.12; use OkHttp 5.4+ (June 2026). |
| KMP / Compose Multiplatform, or greenfield that may go KMP | **Ktor client 3.x** with `OkHttp` engine on Android, `Darwin` on iOS, `ContentNegotiation` + kotlinx.serialization. |
| Raw HTTP, SDKs, WebSockets | OkHttp directly (`OkHttpClient`, `WebSocket`). |
| GraphQL | Apollo Kotlin 4/5 (KMP, normalized cache). |
| gRPC | grpc-kotlin (Android) or Wire (Square; KMP-friendly, also a protobuf runtime). |
| Google/platform HTTP stack | `HttpEngine` (`android.net.http`, API 34+) / Cronet via `org.chromium.net` — only if you need QUIC/Brotli/ECH on old APIs; OkHttp is fine for most apps. |

Verify versions in `libs.versions.toml`; as of Sept 2026: OkHttp 5.4.x, Retrofit 3.0.x, Ktor 3.6.x,
kotlinx.serialization 1.10.x, Coil 3.5.x. One `OkHttpClient`/`HttpClient` per app (connection
pooling, caches, thread pools are per instance); provide it via DI as a singleton.

## Retrofit + OkHttp baseline (`references/retrofit-okhttp.md` for the full setup)

```kotlin
@Serializable data class ArticleDto(val id: String, val title: String, @SerialName("updated_at") val updatedAt: Long, val tags: List<String> = emptyList())

interface ArticleApi {
    @GET("v1/articles") suspend fun articles(@Query("page") page: Int, @Query("size") size: Int = 30): PageDto<ArticleDto>
    @GET("v1/articles/{id}") suspend fun article(@Path("id") id: String): ArticleDto
    @POST("v1/articles") suspend fun create(@Body body: CreateArticleDto): ArticleDto
    @Multipart @POST("v1/upload") suspend fun upload(@Part file: MultipartBody.Part): UploadDto
}

val json = Json { ignoreUnknownKeys = true; coerceInputValues = true; explicitNulls = false }
val client = OkHttpClient.Builder()
    .connectTimeout(10.seconds.toJavaDuration()).readTimeout(30.seconds.toJavaDuration()).writeTimeout(30.seconds.toJavaDuration())
    .cache(Cache(File(ctx.cacheDir, "http"), 50L * 1024 * 1024))
    .addInterceptor(AuthInterceptor(tokenStore))                 // app interceptors: headers, auth
    .authenticator(TokenAuthenticator(tokenStore, authApi))      // 401 → refresh once → retry
    .addNetworkInterceptor(UserAgentInterceptor())               // network interceptors: see final request/response
    .apply { if (BuildConfig.DEBUG) addInterceptor(HttpLoggingInterceptor().apply { level = BASIC }) }
    .build()
val retrofit = Retrofit.Builder().baseUrl("https://api.example.com/").client(client)
    .addConverterFactory(json.asConverterFactory("application/json".toMediaType())).build()
val api = retrofit.create<ArticleApi>()
```

- `suspend fun` in the interface — no `Call<>`/RxJava. Retrofit throws `HttpException` for non-2xx
  and `IOException` for transport failures. Wrap in the repository: map to `Result`/sealed outcome.
- Return `Response<T>` only when you need headers/status; otherwise let it throw.
- kotlinx.serialization: mark DTOs `@Serializable`, use `@SerialName` for snake_case, give
  defaults for optional fields, `ignoreUnknownKeys = true` always (backend will add fields).
- Keep DTOs in the network module; map to domain models (`android-architecture`).
- Never log request/response bodies in release (`HttpLoggingInterceptor` level `BODY` leaks tokens
  and PII; use `BASIC`/`HEADERS` in debug only).

## Ktor client baseline (`references/ktor-client.md`)

```kotlin
val client = HttpClient(OkHttp) {                       // commonMain: HttpClient { } with expect/actual engine
    install(ContentNegotiation) { json(Json { ignoreUnknownKeys = true }) }
    install(HttpTimeout) { connectTimeoutMillis = 10_000; requestTimeoutMillis = 30_000 }
    install(HttpRequestRetry) { retryOnServerErrors(maxRetries = 2); exponentialDelay() }
    install(Auth) { bearer { loadTokens { tokenStore.tokens() }; refreshTokens { authApi.refresh(oldTokens?.refreshToken) } } }
    install(HttpCache)
    install(Logging) { level = if (isDebug) LogLevel.HEADERS else LogLevel.NONE }
    defaultRequest { url("https://api.example.com/"); header("Accept", "application/json") }
    expectSuccess = true                                  // non-2xx → ClientRequestException/ServerResponseException
}
suspend fun articles(page: Int): PageDto<ArticleDto> = client.get("v1/articles") { parameter("page", page) }.body()
```

## Auth, tokens, refresh

- Attach tokens in an **application interceptor** (Retrofit) / `Auth` plugin (Ktor). Read the
  token from an in-memory cache backed by encrypted storage (`android-security`).
- Refresh with OkHttp `Authenticator` (called only on 401; synchronize so parallel 401s refresh
  once; give up after one retry — check `response.priorResponse`). Ktor's `bearer { refreshTokens }`
  does this for you.
- Logout on refresh failure: clear tokens, emit an app-level "signed out" state; don't loop.
- Prefer **Credential Manager** / passkeys / OAuth via Custom Tabs (AppAuth) for login. Never
  embed client secrets in the APK (they're extractable); use PKCE.

## Resilience

- Timeouts: connect 10 s, read/write 30 s (longer for uploads; use per-request `@Headers`/`timeout()` or Ktor per-call `timeout {}`).
- Retries: OkHttp `retryOnConnectionFailure(true)` handles transport retries; add app-level retry
  with **exponential backoff + jitter** only for idempotent requests (GET, PUT with idempotency
  keys) and only for `IOException`/5xx/429 (honor `Retry-After`).
- Cancellation: Retrofit/Ktor `suspend` calls cancel the HTTP call when the coroutine is
  cancelled — scope network work to `viewModelScope`/`WhileSubscribed` so leaving a screen cancels it.
- Caching: OkHttp `Cache` honors `Cache-Control`/`ETag`; force-cache for offline reads with
  `CacheControl.FORCE_CACHE` fallback when offline. For real offline support, persist to Room
  (offline-first; see `android-data-persistence`), not the HTTP cache.
- Payload efficiency: gzip is automatic; OkHttp 5.2+ can negotiate **zstd**
  (`okhttp-zstd` + `CompressionInterceptor(Zstd, Gzip)`). Use protobuf/Wire for chatty binary APIs.
- Connectivity: don't gate requests on `isOnline` checks (races); attempt and handle failure.
  Do expose an `isOnline` `Flow` (`ConnectivityManager.registerDefaultNetworkCallback`) to show
  banners and to trigger sync when connectivity returns. Metered networks: `isActiveNetworkMetered`
  → defer large downloads.

## Pagination & sync

- Cursor-based pagination beats offset. With Paging 3, `RemoteMediator` writes pages into Room;
  the UI observes the DB.
- Background sync: `WorkManager` `PeriodicWorkRequest` (min 15 min) with
  `Constraints(requiredNetworkType = CONNECTED)`, `ExpeditedWorkRequest` for user-initiated sync,
  unique work names to avoid duplicates. Long downloads/uploads on API 34+: **user-initiated data
  transfer jobs** (`JobInfo.setUserInitiated`) or `DownloadManager`; `dataSync` foreground services are
  capped at 6 h/day on API 35+.
- Conflict handling: server timestamps/ETags; last-write-wins is acceptable for most apps; document it.

## Images

Coil 3 (`io.coil-kt.coil3:coil-compose`, `coil-network-okhttp` or `coil-network-ktor3`):

```kotlin
AsyncImage(model = ImageRequest.Builder(LocalContext.current).data(url).crossfade(true).build(),
           contentDescription = alt, placeholder = painterResource(R.drawable.ph), error = painterResource(R.drawable.err),
           contentScale = ContentScale.Crop, modifier = Modifier.size(96.dp))
```

Configure one `ImageLoader` (memory cache %, disk cache dir/size, shared `OkHttpClient` via
`OkHttpNetworkFetcherFactory(callFactory = { client })`) in `SingletonImageLoader.Factory` on the
`Application`. Request sizes matching the composable (Coil does this via constraints); avoid
`Bitmap` decoding by hand. SVG/GIF/video frames via `coil-svg`/`coil-gif`/`coil-video`.

## Network security (details in `references/network-security.md`)

- HTTPS everywhere; cleartext is blocked by default since API 28. If a dev server needs HTTP,
  scope it to a debug `network_security_config.xml` with `<domain-config cleartextTrafficPermitted="true">`
  for that host only, or `adb reverse` + `10.0.2.2`.
- **Android 17 (targetSdk 37):** Certificate Transparency is enforced by default (opt out per domain
  only if you must); Encrypted Client Hello is used when the client library and server support it
  (`<domainEncryption>` to control); **local network access requires `ACCESS_LOCAL_NETWORK`**
  (runtime permission, `NEARBY_DEVICES` group) or a system device picker — mDNS/NSD, casting, IoT
  discovery, and LAN IP calls all fail without it.
- Certificate pinning: only with an explicit rotation plan (`<pin-set expiration>` with backup pins);
  most apps shouldn't pin. Never `TrustManager`s that accept everything, even in debug — use the
  debug NSC `<debug-overrides>` to trust user CAs for proxying (Charles/mitmproxy).
- Don't send tokens in query strings (logged everywhere). Validate deep-link/redirect URLs.

## Debugging & testing

- **Network Inspector** (Android Studio App Inspection) shows every OkHttp/Ktor(OkHttp engine)
  call with headers/bodies/timing in debug builds — first stop for "the API call is wrong".
- `HttpLoggingInterceptor` at `HEADERS`/`BASIC` in debug; `adb logcat -s OkHttp`.
- Proxy: `adb shell settings put global http_proxy <host>:8888` (emulator: host is `10.0.2.2`),
  trust the proxy CA via `<debug-overrides>`; clear with `settings put global http_proxy :0`.
- Emulator networking: `10.0.2.2` = host machine; `adb reverse tcp:8080 tcp:8080` for devices.
- Unit tests: **MockWebServer** (`com.squareup.okhttp3:mockwebserver3` for OkHttp 5) with
  `enqueue(MockResponse(...))`, assert `takeRequest()`; Ktor `MockEngine`. Test JSON parsing
  against fixture files. Test 401→refresh→retry and offline paths explicitly.
- Instrumented: point the app at MockWebServer via a debug flavor `BASE_URL` `buildConfigField`.
- Slow/flaky network: emulator `-netdelay`/`-netspeed`, or `adb shell svc wifi disable`.

## Common mistakes

- Creating a new `OkHttpClient`/`Retrofit`/`HttpClient` per request or per repository.
- Catching `Exception` in the repository and returning `null` — swallows cancellation and hides
  HTTP errors; catch `IOException`/`HttpException` specifically.
- Doing network on `Dispatchers.Main` via blocking `execute()`; use `suspend` APIs.
- `ignoreUnknownKeys` missing → crash when the backend adds a field.
- Base URL without trailing slash / endpoint path with leading slash (Retrofit resolves
  differently). Base: `https://host/api/`, path: `v1/x`.
- Logging bodies in release; hardcoded API keys in Kotlin constants (see `android-security`).
- Blocking UI on connectivity checks; not cancelling requests when leaving the screen.
- Forgetting `INTERNET` permission (manifest) — obvious but still happens in new modules.
- Assuming LAN access works on Android 17 without `ACCESS_LOCAL_NETWORK`.
- Retrying non-idempotent POSTs on timeout (duplicate orders). Use idempotency keys.
