# Ktor client 3.x (Android + KMP)

## Dependencies

```toml
[versions] ktor = "3.6.0"   # verify
[libraries]
ktor-client-core = { module = "io.ktor:ktor-client-core", version.ref = "ktor" }
ktor-client-okhttp = { module = "io.ktor:ktor-client-okhttp", version.ref = "ktor" }      # androidMain
ktor-client-darwin = { module = "io.ktor:ktor-client-darwin", version.ref = "ktor" }      # iosMain
ktor-client-content-negotiation = { module = "io.ktor:ktor-client-content-negotiation", version.ref = "ktor" }
ktor-serialization-kotlinx-json = { module = "io.ktor:ktor-serialization-kotlinx-json", version.ref = "ktor" }
ktor-client-auth = { module = "io.ktor:ktor-client-auth", version.ref = "ktor" }
ktor-client-logging = { module = "io.ktor:ktor-client-logging", version.ref = "ktor" }
ktor-client-mock = { module = "io.ktor:ktor-client-mock", version.ref = "ktor" }
```

`commonMain` depends on core + plugins; each platform source set adds its engine. Alternatively
use `ktor-client-cio` on all platforms (pure Kotlin, no OkHttp/NSURLSession features like system
proxies/certificate handling — prefer platform engines in production).

## Shared client factory

```kotlin
// commonMain
expect fun httpClientEngine(): HttpClientEngineFactory<*>
fun createHttpClient(tokens: TokenStore, isDebug: Boolean) = HttpClient(httpClientEngine()) {
    install(ContentNegotiation) { json(Json { ignoreUnknownKeys = true; explicitNulls = false; coerceInputValues = true }) }
    install(HttpTimeout) { connectTimeoutMillis = 10_000; requestTimeoutMillis = 30_000; socketTimeoutMillis = 30_000 }
    install(HttpRequestRetry) { maxRetries = 2; retryIf { req, resp -> req.method == HttpMethod.Get && resp.status.value in 500..599 }; retryOnExceptionIf { _, c -> c is IOException }; exponentialDelay(base = 2.0, maxDelayMs = 4_000) }
    install(Auth) {
        bearer {
            loadTokens { tokens.current()?.let { BearerTokens(it.access, it.refresh) } }
            refreshTokens { val new = client.post("v1/auth/refresh") { markAsRefreshTokenRequest(); setBody(RefreshDto(oldTokens?.refreshToken)) }.body<TokenDto>(); tokens.save(new); BearerTokens(new.access, new.refresh) }
            sendWithoutRequest { it.url.host == "api.example.com" }
        }
    }
    install(HttpCache)
    if (isDebug) install(Logging) { level = LogLevel.HEADERS; sanitizeHeader { it == HttpHeaders.Authorization } }
    defaultRequest { url("https://api.example.com/"); contentType(ContentType.Application.Json) }
    expectSuccess = true
}
// androidMain
actual fun httpClientEngine(): HttpClientEngineFactory<*> = OkHttp   // configure: engine { config { … }; addInterceptor(…) } inside HttpClient { } if needed
// iosMain
actual fun httpClientEngine(): HttpClientEngineFactory<*> = Darwin
```

## API layer

```kotlin
class ArticleApi(private val client: HttpClient) {
    suspend fun articles(page: Int): PageDto<ArticleDto> = client.get("v1/articles") { parameter("page", page) }.body()
    suspend fun create(dto: CreateArticleDto): ArticleDto = client.post("v1/articles") { setBody(dto) }.body()
    suspend fun upload(bytes: ByteArray, name: String): UploadDto = client.submitFormWithBinaryData("v1/upload", formData {
        append("file", bytes, Headers.build { append(HttpHeaders.ContentType, "image/jpeg"); append(HttpHeaders.ContentDisposition, "filename=\"$name\"") })
    }) { onUpload { sent, total -> /* progress */ } }.body()
    suspend fun download(url: String, sink: Sink) = client.prepareGet(url).execute { resp -> resp.bodyAsChannel().copyTo(sink) }
}
```

Errors: with `expectSuccess = true`, non-2xx throws `ClientRequestException` (4xx) /
`ServerResponseException` (5xx) / `RedirectResponseException`; transport errors throw
`IOException` subclasses (`ConnectTimeoutException`, `SocketTimeoutException`,
`UnresolvedAddressException`). Map in the repository like the Retrofit variant.

## WebSockets / SSE

```kotlin
install(WebSockets) { pingIntervalMillis = 20_000 }
client.webSocket("wss://api.example.com/live") { for (frame in incoming) if (frame is Frame.Text) handle(frame.readText()) }
install(SSE); client.sse("v1/events") { incoming.collect { event -> … } }
```

Reconnect with backoff in a `Flow` (`retryWhen`) scoped to the screen or a foreground service.

## Testing with MockEngine

```kotlin
val engine = MockEngine { req -> respond(fixture("articles.json"), HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) }
val api = ArticleApi(HttpClient(engine) { install(ContentNegotiation) { json() } })
```

## Lifecycle

One `HttpClient` for the app; `client.close()` only when the DI scope ends (rarely on mobile).
Ktor is coroutine-native — cancellation of the calling coroutine cancels the request.
