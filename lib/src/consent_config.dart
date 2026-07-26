/// Debug geography options for testing consent flows.
///
/// Only applies in debug mode. In release builds, geography is always
/// determined by the device's actual location via Google UMP.
enum ConsentKitDebugGeography {
  /// Force the device to appear as if it is in the EEA.
  /// Triggers the GDPR consent form even outside the EEA.
  eea,

  /// Force the device to appear as if it is NOT in the EEA.
  /// Useful for testing the non-EU flow while physically in the EEA.
  notEea,
}

/// Configuration for [ConsentKit.initialize].
///
/// Example:
/// ```dart
/// await ConsentKit.initialize(
///   config: ConsentKitConfig(
///     testDeviceIds: ['YOUR_TEST_DEVICE_ID'],
///     debugGeography: ConsentKitDebugGeography.eea,
///   ),
/// );
/// ```
class ConsentKitConfig {
  /// Test device IDs for debug mode (from logcat / Xcode consoles).
  ///
  /// Only applied when the app is built in debug mode (`kDebugMode`).
  final List<String>? testDeviceIds;

  /// Debug geography to force for consent testing.
  ///
  /// Only applied in debug mode. Ignored in release builds.
  final ConsentKitDebugGeography? debugGeography;

  /// Tag for users under the age of consent (TFUA).
  ///
  /// When `true`, UMP will not request consent from the user.
  final bool? tagForUnderAgeOfConsent;

  /// When `true` (default), also initializes `MobileAds` after consent
  /// if ads are allowed. Set to `false` if you initialize ads yourself.
  final bool initializeMobileAds;

  /// Timeout for the consent-info update request.
  final Duration infoUpdateTimeout;

  /// Timeout for loading / showing the consent form.
  final Duration formTimeout;

  const ConsentKitConfig({
    this.testDeviceIds,
    this.debugGeography,
    this.tagForUnderAgeOfConsent,
    this.initializeMobileAds = false,
    this.infoUpdateTimeout = const Duration(seconds: 10),
    this.formTimeout = const Duration(seconds: 30),
  });
}
