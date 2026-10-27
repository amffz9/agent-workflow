# Network security on Android (2026)

## Network Security Config

`res/xml/network_security_config.xml`, referenced from the manifest
`<application android:networkSecurityConfig="@xml/network_security_config">`.

```xml
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors><certificates src="system"/></trust-anchors>
        <certificateTransparency enabled="true"/>        <!-- default when targetSdk 37; explicit for 36 -->
        <domainEncryption enabled="true"/>               <!-- Android 17 ECH; "disabled" per domain if a server misbehaves -->
    </base-config>
    <domain-config>
        <domain includeSubdomains="true">api.example.com</domain>
        <pin-set expiration="2027-06-01">
            <pin digest="SHA-256">base64==</pin>          <!-- primary -->
            <pin digest="SHA-256">backupbase64==</pin>    <!-- backup, different key -->
        </pin-set>
    </domain-config>
    <debug-overrides>                                     <!-- only in debuggable builds -->
        <trust-anchors><certificates src="user"/></trust-anchors>
    </debug-overrides>
</network-security-config>
```

Put a dev-only variant in `src/debug/res/xml/` if you need cleartext to a local server:
`<domain-config cleartextTrafficPermitted="true"><domain>10.0.2.2</domain></domain-config>`.

## Android version behaviors

| API | Behavior |
|---|---|
| 24+ | User-installed CAs untrusted by default (need `<debug-overrides>` or `src="user"`). |
| 28+ | Cleartext blocked by default. |
| 29+ | TLS 1.3 default; `SSLSocket` cleartext blocked. |
| 34+ | `HttpEngine` platform API (QUIC/HTTP3). |
| 36 (16) | Certificate Transparency available, opt-in via NSC. |
| 37 (17) | **CT enforced by default** (targetSdk 37); **ECH** used when supported; **`ACCESS_LOCAL_NETWORK`** runtime permission required for LAN traffic (targetSdk 37); MessageQueue/static-final changes are unrelated but ship together. |

### Local network permission (Android 17)

Anything talking to `192.168.x.x`/`10.x`/`.local`/multicast/NSD/mDNS/casting/printers/IoT:

```xml
<uses-permission android:name="android.permission.ACCESS_LOCAL_NETWORK"/>
```

Request at runtime (`NEARBY_DEVICES` group; if the user already granted e.g. `BLUETOOTH_CONNECT`
they aren't re-prompted). Prefer system-mediated pickers (Cast, companion device, device picker)
when they fit — they need no permission. Without the grant, sockets to LAN addresses fail with
`EPERM`/`ConnectException` and NSD discovery returns nothing; handle that state in the UI.

## Certificate pinning — when and how

- Pin only if you control the server and have a rotation plan; misconfigured pins brick the app.
- Always ship at least one **backup pin** (different key pair) and an `expiration` so pinning
  self-disables after the date rather than breaking.
- Pin the intermediate or leaf SPKI, not the root, if you rotate leaves often… or pin the
  intermediate CA to survive leaf rotation. Document which.
- OkHttp `CertificatePinner` works too but NSC is declarative and applies to all stacks (WebView
  excluded — WebView ignores pins).
- Never implement `X509TrustManager` that returns without checking. Google Play rejects apps with
  unsafe `TrustManager`/`HostnameVerifier` implementations.

## Tokens and secrets in transit/at rest

- HTTPS + `Authorization: Bearer` header. No tokens in URLs.
- Store refresh tokens encrypted (Keystore-wrapped key + file/DataStore; see `android-security`).
- Short-lived access tokens in memory; refresh on 401.
- OAuth: Authorization Code + PKCE via Custom Tabs (AppAuth-Android); never embed client secrets.
- Passkeys/Credential Manager for first-party login (`androidx.credentials`), which Compose text
  fields integrate with via `credentialRequest` semantics (Compose 1.12).

## WebView

- Load only HTTPS; `setJavaScriptEnabled(false)` unless required; no `addJavascriptInterface`
  with untrusted content; `setAllowFileAccess(false)`; validate URLs in `shouldOverrideUrlLoading`.
- Use `WebViewAssetLoader` for local content instead of `file://`.
- Safe Browsing is on by default (`android:usesCleartextTraffic` doesn't apply to WebView TLS).

## Proxies and debugging safely

- Charles/mitmproxy/Proxyman: install their CA as a *user* certificate; the debug NSC
  `<debug-overrides>` trusts it; release builds don't.
- Pinning blocks proxies by design — provide a debug build type without pins or with
  `<debug-overrides>` that omits `pin-set`.
- `adb shell settings put global http_proxy 10.0.2.2:8888` on the emulator; reset with `:0`.

## Checklist before release

- [ ] No `cleartextTrafficPermitted="true"` outside debug.
- [ ] No custom trust-all `TrustManager`/`HostnameVerifier`.
- [ ] Pins (if any) have backups and expiration; rotation documented.
- [ ] Logging interceptor disabled/`NONE` in release; no PII in logs.
- [ ] `ACCESS_LOCAL_NETWORK` declared + requested if the app uses LAN (targetSdk 37).
- [ ] CT-compatible certificates on your servers (public CAs are; private CAs need
      `<certificateTransparency enabled="false"/>` for that domain).
- [ ] Deep-link/redirect URL allowlists.
