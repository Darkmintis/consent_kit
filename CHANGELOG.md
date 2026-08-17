## 1.0.0

First launch.

- `ConsentKit.bootstrap()` - Google's UMP sequence without blocking `runApp`.
- `AdGate` and `guardAdLoad()` - ads never load unless UMP allows them.
- `PrivacyOptionsButton` - shows only when UMP requires a privacy entry point.
- `ConsentGate` - optional wrap; app paints immediately (`waitForConsent: true` to wait).
- Safe defaults: `canRequestAds` is `false` until UMP confirms. Reads do not throw before init.
- Debug-safe: `testDeviceIds` / `debugGeography` apply only in `kDebugMode`.
- Soft recovery when gathering fails but a previous session still allows ads.
- Web / desktop no-op - ads stay off instead of throwing.
- `initializeMobileAds` defaults to `true`.
- `package:consent_kit/testing.dart` with `MockConsentPlatform`.
