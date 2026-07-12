/// Debug geography options for testing consent flows.
///
/// Only applies in debug mode. In release builds, the geography is always
/// determined by the device's actual location via Google UMP.
enum ConsentKitDebugGeography {
  /// Force the device to appear as if it is in the EEA (European Economic Area).
  /// This will trigger the GDPR consent form even outside the EEA.
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
  /// List of test device IDs to use in debug mode.
  ///
  /// These are the device IDs shown in the logcat / Xcode console when
  /// the Google UMP SDK identifies a test device. Only applied when the
  /// app is built in debug mode.
  final List<String>? testDeviceIds;

  /// Debug geography to force for consent testing.
  ///
  /// Only applied in debug mode. In release builds this is ignored.
  final ConsentKitDebugGeography? debugGeography;

  /// Tag for under age of consent.
  ///
  /// If set to `true`, the consent form will be configured for users under
  /// the age of consent in the EEA.
  final bool? tagForUnderAgeOfConsent;

  const ConsentKitConfig({
    this.testDeviceIds,
    this.debugGeography,
    this.tagForUnderAgeOfConsent,
  });
}
