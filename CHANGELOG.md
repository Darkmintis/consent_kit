## 1.0.0

Initial production release.

- `ConsentKit.initialize()` — Google-recommended UMP flow (info update → form → optional Mobile Ads).
- Returns `ConsentKitResult` with `status`, `canRequestAds`, `isPrivacyOptionsRequired`.
- Sync `canRequestAds` backed by UMP's real `canRequestAds()` API.
- `ConsentGate` — wrap your app for zero-boilerplate consent bootstrap.
- `PrivacyOptionsButton` — shows only when UMP requires a privacy entry point.
- Soft recovery when gathering fails but a previous session still allows ads.
- Debug-safe: `testDeviceIds` / `debugGeography` applied only in `kDebugMode`.
- `package:consent_kit/testing.dart` with `MockConsentPlatform`.
- Android & iOS only — throws `ConsentKitUnsupportedPlatformException` elsewhere.
