## 1.0.0

- Production-ready release.
- `ConsentKit.initialize()` – single call consent flow with automatic form presentation.
- `ConsentKit.canRequestAds` – synchronous getter, returns `true` unless consent explicitly denied.
- `ConsentKit.consentStatus` – async status retrieval.
- `ConsentKit.showPrivacyOptions()` – privacy options form for EU users.
- `ConsentKit.resetConsent()` – reset for development/testing.
- Debug mode auto-detection (`kDebugMode`): test device IDs and debug geography applied only in debug builds, never in release.
- Platform abstraction (`ConsentPlatform`) for unit testing.
- `@visibleForTesting ConsentPlatform` injection in `initialize()`.
- Full exception types: `ConsentKitException`, `ConsentKitNotInitializedException`, `ConsentKitUnsupportedPlatformException`.
- Comprehensive test suite: 17 unit tests.
- Example app included.
- Android & iOS only — throws on unsupported platforms.
