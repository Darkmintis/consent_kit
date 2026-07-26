<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/darkmintis/consent_kit/main/assets/logo-dark.svg">
  <img alt="ConsentKit" src="https://raw.githubusercontent.com/darkmintis/consent_kit/main/assets/logo-light.svg" width="320">
</picture>

# consent_kit

**The simplest and safest way to integrate Google's User Messaging Platform (UMP) for consent management in mobile ads.**

[![Flutter](https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-3DDC84?logo=android)](https://developer.android.com)
[![iOS](https://img.shields.io/badge/iOS-000000?logo=apple)](https://developer.apple.com/ios)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Features

- **One-call initialization** — UMP info update + form + optional Mobile Ads init.
- **`ConsentGate` widget** — wrap your app; consent runs before UI.
- **`PrivacyOptionsButton`** — shows only when UMP requires a privacy entry point.
- **Real `canRequestAds`** — backed by Google UMP (cached for sync reads).
- **Debug-safe** — test device IDs / debug geography apply only in `kDebugMode`.
- **Soft recovery** — if gathering fails, previous-session consent can still allow ads.
- **Testable** — inject `ConsentPlatform` or use `package:consent_kit/testing.dart`.

---

## Installation

```yaml
dependencies:
  consent_kit: ^1.0.0
  google_mobile_ads: ^5.0.0   # or any 5.x–9.x
```

```bash
flutter pub get
```

### Platform setup (required for ads)

**Android** — `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
  <application>
    <meta-data
      android:name="com.google.android.gms.ads.APPLICATION_ID"
      android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy"/>
  </application>
</manifest>
```

**iOS** — `ios/Runner/Info.plist`:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy</string>
```

Create a privacy message in the [AdMob Privacy & messaging](https://support.google.com/admob/answer/10113207) console for your app.

---

## Quick start (recommended)

```dart
import 'package:flutter/material.dart';
import 'package:consent_kit/consent_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ConsentGate(
      config: const ConsentKitConfig(
        testDeviceIds: ['YOUR_TEST_DEVICE_ID'], // debug only
        debugGeography: ConsentKitDebugGeography.eea, // debug only
        initializeMobileAds: true,
      ),
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('My App'),
          actions: const [PrivacyOptionsButton()],
        ),
        body: Center(
          child: Text(
            ConsentKit.canRequestAds ? 'Ads allowed' : 'Ads not allowed',
          ),
        ),
      ),
    );
  }
}
```

### Imperative API

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final result = await ConsentKit.initialize(
    config: const ConsentKitConfig(initializeMobileAds: true),
  );

  if (result.canRequestAds) {
    // Load ads
  }

  runApp(const MyApp());
}
```

---

## API reference

### `ConsentKit.initialize()`

```dart
static Future<ConsentKitResult> initialize({
  ConsentKitConfig? config,
  @visibleForTesting ConsentPlatform? platform,
})
```

Google-recommended flow:

1. `requestConsentInfoUpdate`
2. `loadAndShowConsentFormIfRequired`
3. Refresh status / `canRequestAds` / privacy-options requirement
4. Optionally `MobileAds.instance.initialize()` when allowed

On gathering errors, recovers if a previous session still allows ads (`result.recoveredFromError == true`).

### `ConsentKitResult`

| Field | Meaning |
|-------|---------|
| `status` | `obtained` / `notRequired` / `required` / `unknown` |
| `canRequestAds` | UMP says ads may be requested |
| `isPrivacyOptionsRequired` | App must show a privacy entry point |
| `recoveredFromError` | Soft recovery from a gathering failure |

### Other APIs

| API | Description |
|-----|-------------|
| `canRequestAds` | Sync cached UMP value |
| `refreshCanRequestAds()` | Live async check |
| `consentStatus` | Async status (`null` if not ready) |
| `isPrivacyOptionsRequired()` | Async privacy entry-point check |
| `privacyOptionsRequired` | Sync cached value |
| `showPrivacyOptions()` | Present privacy form |
| `initializeMobileAds()` | Init ads if allowed |
| `resetConsent()` | Dev/test reset (then re-`initialize`) |
| `isInitialized` / `lastResult` | State helpers |

### `ConsentKitConfig`

| Field | Default | Notes |
|-------|---------|-------|
| `testDeviceIds` | `null` | Debug only |
| `debugGeography` | `null` | Debug only (`eea` / `notEea`) |
| `tagForUnderAgeOfConsent` | `null` | TFUA |
| `initializeMobileAds` | `false` | Init Mobile Ads after consent |
| `infoUpdateTimeout` | 10s | |
| `formTimeout` | 30s | |

### Widgets

- **`ConsentGate`** — consent bootstrap before your app builds.
- **`PrivacyOptionsButton`** — GDPR-safe entry point; hidden when not required.

### Exceptions

| Exception | When |
|-----------|------|
| `ConsentKitException` | Consent / ads failure |
| `ConsentKitNotInitializedException` | Used before `initialize()` |
| `ConsentKitUnsupportedPlatformException` | Not Android/iOS |

---

## Debug mode

In debug builds only, ConsentKit applies `testDeviceIds` and `debugGeography`, and logs with `[ConsentKit]`.

Release builds ignore those settings at the API level — safe to leave in source.

```
[ConsentKit] Test device IDs: [ABCD-1234]
```

---

## Testing

```dart
import 'package:consent_kit/consent_kit.dart';
import 'package:consent_kit/testing.dart';

test('handles ads not allowed', () async {
  final mock = MockConsentPlatform()
    ..setCanRequestAds(false)
    ..setCachedStatus(ConsentKitStatus.required);

  await ConsentKit.initialize(platform: mock);

  expect(ConsentKit.canRequestAds, isFalse);
});
```

---

## Example

```bash
cd example
flutter run
```

One-screen demo: live status, can-request-ads, privacy options, and reset.

---

## Platform support

| Platform | Support |
|----------|---------|
| Android | Full |
| iOS | Full |
| Web / desktop | Throws `ConsentKitUnsupportedPlatformException` |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
