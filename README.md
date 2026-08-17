<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/darkmintis/consent_kit/main/assets/logo-dark.svg">
  <img alt="ConsentKit" src="https://raw.githubusercontent.com/darkmintis/consent_kit/main/assets/logo-light.svg" width="320">
</picture>

# consent_kit

**Google UMP for Flutter AdMob in three lines.** Start the app immediately, gather consent in the background, and never request ads until UMP says you can.

[![Flutter](https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-3DDC84?logo=android)](https://developer.android.com)
[![iOS](https://img.shields.io/badge/iOS-000000?logo=apple)](https://developer.apple.com/ios)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Features

- **Fire-and-forget `bootstrap()`** - Google's UMP sequence without a `ConsentManager` class.
- **App UI is not blocked** - the native consent form can appear over your app, like Google's sample.
- **`AdGate` + `guardAdLoad`** - ads never load unless `canRequestAds` is true.
- **`PrivacyOptionsButton`** - shows only when UMP requires a privacy entry point.
- **Safe defaults** - `canRequestAds` is `false` until UMP confirms. Reads never throw before init.
- **Debug-safe** - test device IDs / debug geography apply only in `kDebugMode`.
- **Web / desktop no-op** - same `main()`; ads stay off instead of crashing.
- **Soft recovery** - if gathering fails, previous-session consent can still allow ads.
- **Testable** - inject `ConsentPlatform` or use `package:consent_kit/testing.dart`.

---

## Installation

```yaml
dependencies:
  consent_kit: ^1.0.0
  google_mobile_ads: ^5.0.0   # or any 5.x-9.x
```

```bash
flutter pub get
```

### Platform setup (required for ads)

**Android** - `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
  <application>
    <meta-data
      android:name="com.google.android.gms.ads.APPLICATION_ID"
      android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy"/>
  </application>
</manifest>
```

**iOS** - `ios/Runner/Info.plist`:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy</string>
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads.</string>
```

Create these in [AdMob Privacy & messaging](https://support.google.com/admob/answer/10113207):

1. A GDPR user messaging (UMP) message for your app.
2. An IDFA / App Tracking Transparency message for iOS. UMP presents ATT when that message exists. This package does not add a second ATT prompt.

---

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:consent_kit/consent_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ConsentKit.bootstrap();
  runApp(const MyApp());
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
        body: AdGate(
          builder: (context) => const Text('Load your banner here'),
        ),
      ),
    );
  }
}
```

Debug-only (ignored in release):

```dart
ConsentKit.bootstrap(
  config: const ConsentKitConfig(
    testDeviceIds: ['YOUR_TEST_DEVICE_ID'],
    debugGeography: ConsentKitDebugGeography.eea,
  ),
);
```

### Load ads safely

```dart
await ConsentKit.guardAdLoad(() => banner.load());
```

Or wrap the widget:

```dart
AdGate(
  builder: (context) => MyBannerAd(),
)
```

### Optional: wrap with `ConsentGate`

Same as calling `bootstrap()` in `main`. The app still builds immediately.

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ConsentGate(
      child: const MyApp(),
    ),
  );
}
```

Set `waitForConsent: true` only if you want a spinner before first paint.

---

## API reference

### `ConsentKit.bootstrap()` / `initialize()`

```dart
static Future<ConsentKitResult> bootstrap({
  ConsentKitConfig? config,
})
```

Google-recommended flow:

1. `requestConsentInfoUpdate`
2. `loadAndShowConsentFormIfRequired`
3. Refresh status / `canRequestAds` / privacy-options requirement
4. `MobileAds.instance.initialize()` when ads are allowed (default)

On gathering errors, recovers if a previous session still allows ads (`result.recoveredFromError == true`).

On web and desktop, uses a stub: `canRequestAds` stays `false`.

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
| `canRequestAds` | Sync. `false` until UMP allows ads |
| `guardAdLoad(load)` | Runs `load` only when ads are allowed |
| `ready` | Future that completes when bootstrap finishes |
| `listenable` | Rebuild widgets when consent changes |
| `refreshCanRequestAds()` | Live async check |
| `consentStatus` | Async status (`null` if not ready) |
| `isPrivacyOptionsRequired()` | Async privacy entry-point check |
| `privacyOptionsRequired` | Sync cached value |
| `showPrivacyOptions()` | Present privacy form |
| `initializeMobileAds()` | Init ads if allowed |
| `resetConsent()` | Dev/test reset (then re-`bootstrap`) |
| `isInitialized` / `lastResult` | State helpers |

### `ConsentKitConfig`

| Field | Default | Notes |
|-------|---------|-------|
| `testDeviceIds` | `null` | Debug only |
| `debugGeography` | `null` | Debug only (`eea` / `notEea`) |
| `tagForUnderAgeOfConsent` | `null` | TFUA |
| `initializeMobileAds` | `true` | Init Mobile Ads after consent |
| `infoUpdateTimeout` | 10s | |
| `formTimeout` | 30s | |

### Widgets

- **`ConsentGate`** - starts bootstrap; shows your app immediately.
- **`AdGate`** - builds child only when ads are allowed.
- **`PrivacyOptionsButton`** - GDPR-safe entry point; hidden when not required.

### Exceptions

| Exception | When |
|-----------|------|
| `ConsentKitException` | Consent / ads failure |
| `ConsentKitNotInitializedException` | `ready` / `resetConsent` before bootstrap |
| `ConsentKitUnsupportedPlatformException` | Only if you call `assertSupportedPlatform()` on web/desktop |

---

## Debug mode

In debug builds only, ConsentKit applies `testDeviceIds` and `debugGeography`, and logs with `[ConsentKit]`.

Release builds ignore those settings at the API level - safe to leave in source.

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

  await ConsentKit.bootstrap(platform: mock);

  expect(ConsentKit.canRequestAds, isFalse);
});
```

---

## Example

```bash
cd example
flutter run
```

Run on an **Android or iOS** device/emulator (not Chrome). The demo:

1. Calls `bootstrap()` and shows **gathering** while UMP runs.
2. Presents the native consent form when EEA applies (or when you force it).
3. Updates live status (`canRequestAds`, privacy options, recovered-from-error).
4. Loads a Google **test banner** inside `AdGate` only after ads are allowed.
5. Lets you paste a hashed test device ID and tap **Reset and show form again**.

Debug geography is EEA. UMP only honors that on a registered test device. Copy the hashed ID from logcat / Xcode (the `ConsentDebugSettings` / `UMPDebugSettings` line), paste it in the demo, then reset.

---

## Platform support

| Platform | Support |
|----------|---------|
| Android | Full |
| iOS | Full (add ATT usage string; UMP shows ATT if you create an IDFA message in AdMob) |
| Web / desktop | No-op - ads stay off |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
