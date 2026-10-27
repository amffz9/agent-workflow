---
name: android-security
description: Secure Android apps and review them for vulnerabilities — API keys and secrets management, encrypting data at rest with Android Keystore (EncryptedSharedPreferences is deprecated), token storage, authentication with Credential Manager/passkeys/OAuth PKCE, biometrics, Play Integrity and anti-tampering, exported components and intent/PendingIntent hygiene, deep-link and WebView safety, content providers and FileProvider, TLS/pinning/network security config, R8 obfuscation, logging and PII, permissions minimization, and Android 17 security changes (BAL hardening, safer native code loading, post-quantum signing, SMS OTP protection). Use this skill whenever a task involves login, tokens, passwords, keys, secrets, encryption, "is this secure", auth, biometric, fingerprint, "protect", "harden", a security review/audit, handling user PII, or Play policy rejections about security/data safety.
---

# Android app security

Threat model first: the device may be rooted, the APK will be decompiled, the network may be
hostile, other apps may send crafted intents. Design so that none of these alone exposes user data.

## Secrets and keys

- **Anything in the APK is public**: `BuildConfig` fields, string resources, native strings,
  obfuscated constants. Don't put private API keys, signing keys, or OAuth client secrets there.
  Move privileged operations behind your backend; use **Play Integrity** to attest the caller.
- Keys that must be client-side (maps, analytics) are *restricted* keys: restrict by package name +
  SHA-256 signing cert in the provider console; rotate if leaked.
- Build-time injection (keeps keys out of git, not out of the APK): `local.properties`/env →
  `buildConfigField`/`manifestPlaceholders` via the Secrets Gradle Plugin; add the files to `.gitignore`.
- Signing keys: Play App Signing; keep the upload key in a password manager/HSM; never in CI logs.

## Data at rest

- `androidx.security:security-crypto` (**EncryptedSharedPreferences / EncryptedFile**) is
  **deprecated** (since 1.1.0-alpha07; 1.1.0 stable is the final release). Don't add it to new code.
- Recommended pattern: generate an AES-256-GCM key in **Android Keystore**
  (`KeyGenParameterSpec` with `setUserAuthenticationRequired` if it should need biometrics), encrypt
  the small secret (tokens, DB passphrase) yourself with `Cipher`, and store the ciphertext + IV in
  DataStore/a file. Or use **Tink** (`com.google.crypto.tink:tink-android`) with an Android Keystore
  master key (`AndroidKeysetManager`) — Google's recommended replacement for `security-crypto`.

```kotlin
object KeystoreCrypto {
    private const val ALIAS = "app_master_key"
    private fun key(): SecretKey = (KeyStore.getInstance("AndroidKeyStore").apply { load(null) }.getKey(ALIAS, null) as? SecretKey) ?: KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
        init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).setKeySize(256)
            .setIsStrongBoxBacked(true).build())     // fall back to false if StrongBoxUnavailableException
    }.generateKey()
    fun encrypt(plain: ByteArray): ByteArray = Cipher.getInstance("AES/GCM/NoPadding").run { init(Cipher.ENCRYPT_MODE, key()); iv + doFinal(plain) }
    fun decrypt(blob: ByteArray): ByteArray = Cipher.getInstance("AES/GCM/NoPadding").run { init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, blob.copyOfRange(0, 12))); doFinal(blob.copyOfRange(12, blob.size)) }
}
```

- Databases: Room + SQLCipher (`net.zetetic:sqlcipher-android` with the `androidx.sqlite` driver
  API) only when the threat model needs it (medical, finance); the passphrase itself lives
  Keystore-encrypted. App-private storage is already sandboxed on unrooted devices.
- Never store secrets in `SharedPreferences`/DataStore plaintext, external storage, logs, or
  `Bundle`s that get saved.
- Backup: exclude token/secret files via `dataExtractionRules` (`<exclude>`), and consider
  `android:allowBackup` implications.
- Wipe on logout; `Keystore` keys can be deleted (`deleteEntry`) to render backups unreadable.

## Authentication

- **Credential Manager** (`androidx.credentials` 1.5+): passkeys (`CreatePublicKeyCredentialRequest`),
  passwords, and Sign in with Google in one API; Compose 1.12 text fields integrate via
  `credentialRequest` semantics + autofill `contentType`. Prefer passkeys.
- OAuth/OIDC: Authorization Code + **PKCE** through Custom Tabs (AppAuth); no client secret;
  validate `state`; use App Links (not custom schemes) for redirects when possible.
- Tokens: short-lived access token in memory; refresh token Keystore-encrypted; rotate refresh
  tokens; bind sessions to device where the backend supports it (DPoP/Play Integrity).
- Biometrics: `androidx.biometric` `BiometricPrompt` with `CryptoObject` tied to a Keystore key
  (`setUserAuthenticationRequired(true)`, `setUserAuthenticationParameters(timeout, AUTH_BIOMETRIC_STRONG)`)
  so the secret is *cryptographically* gated, not just UI-gated. Use `BIOMETRIC_STRONG or DEVICE_CREDENTIAL`.
- SMS OTP: **SMS Retriever / User Consent APIs** (Android 17 delays standard OTP SMS 3 h).
- Session: clear on 401 refresh failure; don't leak auth state into logs/analytics.

## App integrity

- **Play Integrity API**: request a token (standard requests for frequent checks, classic for
  high-value actions), verify on your backend, act on verdicts (device, app, account, recent
  device activity). Don't hard-fail on `MEETS_BASIC_INTEGRITY` alone for legitimate rooted users
  unless policy requires it.
- R8 obfuscation (release) raises the bar; it is not security. Don't rely on client checks for
  entitlements — enforce server-side (Play Billing verification on the server).
- Android 17: **APK Signature Scheme v3.2** (hybrid ML-DSA) and Keystore ML-DSA keys are
  available for quantum-safe signatures; adopt when your toolchain supports them.
- Safer dynamic code loading: never download and `load()` DEX/JAR/native code (Android 14/17
  enforce read-only; Play policy forbids downloading executable code).
- Tamper checks in the client are easily bypassed; use them as *signals*, not gates.

## Components and intents

- `android:exported="false"` unless the component must be public (required explicit since API 31).
  Exported components get a `permission` (signature-level for your own apps) or validate every
  input.
- Validate incoming intents/deep links: parse URIs strictly, allowlist hosts/paths, never load
  attacker-provided URLs into WebView or use them for navigation without checks; treat extras as
  untrusted (type checks, size limits).
- `PendingIntent`: `FLAG_IMMUTABLE` by default; `FLAG_MUTABLE` only with explicit component and
  restricted extras; never blank base intents. Android 17 BAL: use
  `MODE_BACKGROUND_ACTIVITY_START_ALLOW_IF_VISIBLE` in `ActivityOptions`.
- Implicit intents to other apps: don't include secrets; use `Intent.createChooser`; on 30+
  declare `<queries>`. Receiving `ACTION_SEND` data: verify MIME and size.
- `ContentProvider`: `exported=false` unless sharing; use `FileProvider` with `<paths>` and
  `FLAG_GRANT_READ_URI_PERMISSION` (temporary) for sharing files; no `file://` URIs.
- Broadcasts: runtime receivers with `RECEIVER_NOT_EXPORTED`; use `LocalBroadcastManager`
  replacements (Flows) for in-app events.
- Task hijacking / StrandHogg: `android:taskAffinity=""` on sensitive activities,
  `launchMode="singleTask"` where sensible; `FLAG_SECURE` on screens with secrets (also required
  on Android 17 to block Content Capture).
- Clipboard: don't auto-copy secrets; if you must, `ClipDescription.EXTRA_IS_SENSITIVE`.

## WebView

`javaScriptEnabled` only if needed; `allowFileAccess=false`, `allowContentAccess=false`;
`WebViewAssetLoader` for local assets; `shouldOverrideUrlLoading` allowlist; no
`addJavascriptInterface` for untrusted pages (and `@JavascriptInterface` only on minimal, validated
methods); `setSafeBrowsingEnabled(true)`; clear cookies on logout; don't render auth pages —
use Custom Tabs.

## Network

Summarized here; details in `android-networking/references/network-security.md`: HTTPS only,
NSC with CT (default on 17) and optional pins with backups/expiry, no trust-all managers,
`ACCESS_LOCAL_NETWORK` on 17, no secrets in URLs, disable body logging in release, ECH.

## Logging and PII

- No tokens, passwords, emails, precise location, or full request bodies in logs; `Timber` trees
  that no-op in release; lint `LogNotTimber`; strip `Log.d/v` with R8
  (`-assumenosideeffects class android.util.Log { public static *** d(...); public static *** v(...); }`).
- Analytics/crash reporting: pseudonymous IDs; scrub custom keys; respect consent
  (`FirebaseAnalytics.setConsent`); Data safety form must match reality.
- `FLAG_SECURE` on screens showing secrets/financials; block screenshots in sensitive flows.

## Permissions minimization

Request the least (see `android-platform-compat`); use system pickers (photo, contact, location
button, eyedropper) to avoid holding data permissions; declare `usesPermissionFlags="neverForLocation"`
for BLE scanning when you don't infer location; remove unused permissions (merged manifest:
`app/build/intermediates/merged_manifest/`).

## Security review checklist (run through before "done")

- [ ] No secrets in source/APK; keys restricted; backend enforces authorization.
- [ ] Tokens/PII encrypted with Keystore (not `security-crypto`), excluded from backup.
- [ ] Login via Credential Manager/passkeys or OAuth PKCE in Custom Tabs; biometric gating uses `CryptoObject`.
- [ ] All components `exported=false` unless justified; exported ones validate input/permission.
- [ ] `PendingIntent` immutable; deep links allowlisted; WebView locked down.
- [ ] NSC: no cleartext outside debug; CT-compatible certs; pins (if any) with backups.
- [ ] Release build minified; mapping uploaded; verbose logs stripped.
- [ ] Play Integrity for high-value actions; purchases verified server-side.
- [ ] Android 17: `ACCESS_LOCAL_NETWORK` where needed; SMS Retriever; BAL `ALLOW_IF_VISIBLE`;
      native libs read-only; `FLAG_SECURE` replaces `setContentCaptureEnabled(false)`.
- [ ] Lint security checks clean (`ExportedContentProvider`, `SetJavaScriptEnabled`,
      `TrustAllX509TrustManager`, `HardcodedDebugMode`, `UnsafeIntentLaunch`, `InsecureStorage`…),
      and a dependency vulnerability scan (OWASP dependency-check / GitHub Dependabot / Play SDK Index).
