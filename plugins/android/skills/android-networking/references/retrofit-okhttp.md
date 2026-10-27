# Retrofit 3 + OkHttp 5 + kotlinx.serialization — full setup

## Dependencies

```toml
[versions] okhttp = "5.4.0"; retrofit = "3.0.0"; kotlinxSerialization = "1.10.0"; coil = "3.5.0"
[libraries]
okhttp-bom = { module = "com.squareup.okhttp3:okhttp-bom", version.ref = "okhttp" }
okhttp = { module = "com.squareup.okhttp3:okhttp" }
okhttp-logging = { module = "com.squareup.okhttp3:logging-interceptor" }
okhttp-mockwebserver = { module = "com.squareup.okhttp3:mockwebserver3" }
retrofit = { module = "com.squareup.retrofit2:retrofit", version.ref = "retrofit" }
retrofit-kotlinx-serialization = { module = "com.squareup.retrofit2:converter-kotlinx-serialization", version.ref = "retrofit" }
kotlinx-serialization-json = { module = "org.jetbrains.kotlinx:kotlinx-serialization-json", version.ref = "kotlinxSerialization" }
[plugins] kotlin-serialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
```

```kotlin
plugins { alias(libs.plugins.kotlin.serialization) }
dependencies {
    implementation(platform(libs.okhttp.bom)); implementation(libs.okhttp); debugImplementation(libs.okhttp.logging)
    implementation(libs.retrofit); implementation(libs.retrofit.kotlinx.serialization); implementation(libs.kotlinx.serialization.json)
    testImplementation(libs.okhttp.mockwebserver)
}
```

Retrofit 3 still uses the `retrofit2` package (binary compatible with 2.x). Retrofit's own
`converter-kotlinx-serialization` replaces the old JakeWharton converter.

## Interceptors

```kotlin
class AuthInterceptor(private val tokens: TokenStore) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val req = chain.request()
        if (req.header("No-Auth") != null) return chain.proceed(req.newBuilder().removeHeader("No-Auth").build())
        val token = tokens.accessToken() ?: return chain.proceed(req)
        return chain.proceed(req.newBuilder().header("Authorization", "Bearer $token").build())
    }
}

class TokenAuthenticator(private val tokens: TokenStore, private val refresh: RefreshApi) : Authenticator {
    private val lock = Any()
    override fun authenticate(route: Route?, response: Response): Request? {
        if (response.priorResponse != null) return null                      // already retried once
        val failedToken = response.request.header("Authorization")?.removePrefix("Bearer ")
        synchronized(lock) {
            val current = tokens.accessToken()
            val fresh = if (current != null && current != failedToken) current   // another call refreshed
                        else runBlocking { refresh.refresh(tokens.refreshToken() ?: return null) }?.also { tokens.save(it) }?.accessToken
                        ?: run { tokens.clear(); return null }
            return response.request.newBuilder().header("Authorization", "Bearer $fresh").build()
        }
    }
}
```

`runBlocking` inside an `Authenticator` is acceptable: it runs on OkHttp's thread, not main.
Mark login/refresh endpoints with a `@Headers("No-Auth: true")` marker so they skip auth.

OkHttp 5.4: interceptors can override client-level settings (cache, DNS, connection pool) per
call via `chain` builders — handy for per-host proxies or cache-bypass without a second client.

## Error model in the repository

```kotlin
sealed interface NetError { data object Offline : NetError; data class Http(val code: Int, val body: String?) : NetError; data object Timeout : NetError; data class Unknown(val cause: Throwable) : NetError }

suspend fun <T> apiCall(block: suspend () -> T): Result<T> = try { Result.success(block()) }
catch (e: CancellationException) { throw e }
catch (e: HttpException) { Result.failure(ApiException(NetError.Http(e.code(), e.response()?.errorBody()?.string()))) }
catch (e: SocketTimeoutException) { Result.failure(ApiException(NetError.Timeout)) }
catch (e: IOException) { Result.failure(ApiException(NetError.Offline)) }
catch (e: SerializationException) { Result.failure(ApiException(NetError.Unknown(e))) }
```

Parse structured error bodies (`{"error":{"code":"…","message":"…"}}`) into a DTO for user-facing
messages; never show raw HTML/stack traces.

## Uploads / downloads

```kotlin
// upload with progress
val body = file.asRequestBody("image/jpeg".toMediaType()).withProgress { sent, total -> progress.value = sent.toFloat() / total }
api.upload(MultipartBody.Part.createFormData("file", file.name, body))
// streaming download (don't buffer whole body)
@Streaming @GET suspend fun download(@Url url: String): ResponseBody
response.byteStream().use { input -> target.outputStream().use { input.copyTo(it) } }   // on IO dispatcher
```

Large/long transfers belong in WorkManager (`CoroutineWorker`, `setForeground` for >10 min on
API 34+ use user-initiated data transfer jobs) so they survive the screen.

## MockWebServer test

```kotlin
class ArticleApiTest {
    private val server = MockWebServer()
    private lateinit var api: ArticleApi
    @Before fun setUp() { server.start(); api = buildRetrofit(server.url("/")).create() }
    @After fun tearDown() = server.close()

    @Test fun parsesArticles() = runTest {
        server.enqueue(MockResponse.Builder().code(200).body(fixture("articles.json")).addHeader("Content-Type", "application/json").build())
        val page = api.articles(page = 1)
        assertEquals(2, page.items.size)
        assertEquals("/v1/articles?page=1&size=30", server.takeRequest().target)
    }
    @Test fun refreshesOn401() = runTest { server.enqueue(MockResponse(code = 401)); server.enqueue(MockResponse(body = tokenJson)); server.enqueue(MockResponse(body = okJson)); api.article("1"); assertEquals(3, server.requestCount) }
}
```

## R8

Retrofit 3 + kotlinx.serialization ship consumer keep rules; you still need
`-keepclassmembers @kotlinx.serialization.Serializable class ** { *** Companion; }` variants only if
using reflection-based access. Check `analyzeReleaseR8Config` after adding rules; DTOs used via
kotlinx.serialization don't need `-keep` for fields (the plugin generates serializers).
