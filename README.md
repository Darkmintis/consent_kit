<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/darkmintis/consent_kit/main/assets/logo-dark.svg">
  <img alt="ConsentKit" src="https://raw.githubusercontent.com/darkmintis/consent_kit/main/assets/logo-light.svg" width="320">
</picture>

# consent\_kit

**The simplest and safest way to integrate Google's User Messaging Platform (UMP) for consent management in mobile ads.**

[![Flutter](https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-3DDC84?logo=android)](https://developer.android.com)
[![iOS](https://img.shields.io/badge/iOS-000000?logo=apple)](https://developer.apple.com/ios)
[![License](https://img.shields.io/badge/License-BSD--3-blue)](LICENSE)

---

## Features

- **One-call initialization** — the entire consent flow (info update + form presentation) in a single `await`.
- **Synchronous `canRequestAds` getter** — no async dance; check ad-readiness instantly.
- **Debug-safe by design** — test device IDs and debug geography are **only** applied in `kDebugMode`; they literally cannot leak into release builds.
- **Platform abstraction** — inject a mock `ConsentPlatform` for deterministic unit testing.
- **Clear errors** — typed exceptions with actionable messages instead of generic failures.
- **Android & iOS only** — throws `ConsentKitUnsupportedPlatformException` on web or desktop.

---

## What it solves

Integrating Google UMP directly is error-prone:

| Problem | ConsentKit solution |
|--------|--------------------|
| Forgetting to wrap debug settings in `kDebugMode` checks | Debug settings are **never** applied in release builds — guaranteed at the API level. |
| Calling async APIs when a sync check would suffice | `CanRequestAds` is a **synchronous getter** backed by a cached status. |
| Complex callback-based APIs | Full `async`/`await` API — no callbacks. |
| Exception handling boilerplate | Typed exceptions (`ConsentKitException`, `ConsentKitNotInitializedException`, `ConsentKitUnsupportedPlatformException`) with descriptive messages. |
| Hard-to-test code (static calls, native platform dependency) | `@visibleForTesting platform` injection; mock the entire native layer. |
| Form lifecycle management | Form is automatically loaded and shown when required. |

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  consent_kit: ^1.0.0
```

Then run:

```bash
flutter pub get
```

---

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:consent_kit/consent_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Single call — handles consent info update and form presentation.
  await ConsentKit.initialize(
    config: ConsentKitConfig(
      testDeviceIds: ['YOUR_TEST_DEVICE_ID'],
      debugGeography: ConsentKitDebugGeography.eea,
    ),
  );

  // Synchronous check — no await needed.
  if (ConsentKit.canRequestAds) {
    // Load and show ads.
  }

  runApp(const MyApp());
}
```

---

## API Reference

### `ConsentKit.initialize()`

```dart
static Future<void> initialize({
  ConsentKitConfig? config,
  @visibleForTesting ConsentPlatform? platform,
})
```

Initializes the consent flow. Must be called once before any other method.

- Updates consent info via Google UMP.
- Automatically shows the consent form if the user is in the EEA and consent is required.
- In debug mode, applies `config.testDeviceIds` and `config.debugGeography`.
- In release mode, those settings are **silently ignored**.

Throws:
- `ConsentKitNotInitializedException` if an operation is attempted before initialization.
- `ConsentKitUnsupportedPlatformException` on non-mobile platforms.
- `ConsentKitException` on any other failure.

### `ConsentKit.canRequestAds`

```dart
static bool get canRequestAds
```

Synchronous. Returns `true` unless consent is **explicitly denied** (`ConsentKitStatus.required`).

Returns `true` for:
- `ConsentKitStatus.obtained` — user gave consent.
- `ConsentKitStatus.notRequired` — user is outside EEA.
- `ConsentKitStatus.unknown` — graceful degradation.

### `ConsentKit.consentStatus`

```dart
static Future<ConsentKitStatus?> get consentStatus
```

Returns the current `ConsentKitStatus`, or `null` if initialization hasn't completed.

### `ConsentKit.showPrivacyOptions()`

```dart
static Future<bool> showPrivacyOptions()
```

Shows the privacy options form (for EU users to change their preferences). Returns `true` if the form was presented successfully.

### `ConsentKit.resetConsent()`

```dart
static Future<void> resetConsent()
```

Resets the consent state. Useful during development. After calling this, `initialize()` must be called again.

### `ConsentKitConfig`

| Field | Type | Description |
|-------|------|-------------|
| `testDeviceIds` | `List<String>?` | Device IDs for debug testing (applied only in `kDebugMode`). |
| `debugGeography` | `ConsentKitDebugGeography?` | Force EEA or non-EEA geography (applied only in `kDebugMode`). |
| `tagForUnderAgeOfConsent` | `bool?` | Tag for users under the age of consent. |

### `ConsentKitStatus`

| Value | Meaning |
|-------|---------|
| `obtained` | User has given consent. |
| `notRequired` | User is outside EEA — consent not needed. |
| `required` | Consent is required but has not been obtained. |
| `unknown` | Status could not be determined. |

### Exceptions

| Exception | When |
|-----------|------|
| `ConsentKitException` | Generic consent failure — wraps the underlying error. |
| `ConsentKitNotInitializedException` | Operation called before `initialize()`. |
| `ConsentKitUnsupportedPlatformException` | `initialize()` called on web or desktop. |

---

## Debug Mode

In debug builds (`kDebugMode == true`), `ConsentKit` automatically:

1. Applies `testDeviceIds` from your config.
2. Applies `debugGeography` from your config.
3. Prints debug logs prefixed with `[ConsentKit]`.

**In release builds, none of this happens.** The debug settings parameters are safely ignored at the API level — no conditional checks needed in your code.

```dart
// This is safe — testDeviceIds are only used in debug mode.
await ConsentKit.initialize(
  config: ConsentKitConfig(
    testDeviceIds: ['ABCD-1234'],
    debugGeography: ConsentKitDebugGeography.eea,
  ),
);
```

### Getting your test device ID

Run the app on a device/emulator and check the logs:

```
[ConsentKit] Test device IDs: [ABCD-1234]
```

Or check the Google UMP log output for a line like:

```
"Use new consent debug settings: CONSENT_DEBUG_SETTINGS(... testDeviceIdentifiers: [\"ABCD-1234\"])"
```

---

## Testing

The package is designed for testability:

```dart
import 'package:consent_kit/consent_kit.dart';

void main() {
  test('handles consent denied', () async {
    final mock = MockConsentPlatform();
    mock.setCachedStatus(ConsentKitStatus.required);

    await ConsentKit.initialize(platform: mock);

    expect(ConsentKit.canRequestAds, isFalse);
  });
}
```

See [`test/consent_kit_test.dart`](test/consent_kit_test.dart) for the full test suite and [`test/mock_consent_platform.dart`](test/mock_consent_platform.dart) for the mock implementation.

---

## Example App

A complete example app is in the [`example/`](example/) directory:

```bash
cd example
flutter run
```

It demonstrates:
- Initialization with debug config.
- Displaying consent status.
- Privacy options button.
- Consent reset.

---

## Platform Support

| Platform | Support |
|----------|---------|
| Android  | ✅ Full |
| iOS      | ✅ Full |
| Web      | ❌ Throws `ConsentKitUnsupportedPlatformException` |
| macOS    | ❌ Throws `ConsentKitUnsupportedPlatformException` |
| Windows  | ❌ Throws `ConsentKitUnsupportedPlatformException` |
| Linux    | ❌ Throws `ConsentKitUnsupportedPlatformException` |

---

## Contributing

1. Fork the repo.
2. Create a feature branch (`git checkout -b feat/amazing-feature`).
3. Run `flutter analyze` — must be clean.
4. Run `flutter test` — must pass.
5. Commit and open a PR.

---

## License

BSD 3-Clause. See [LICENSE](LICENSE).
