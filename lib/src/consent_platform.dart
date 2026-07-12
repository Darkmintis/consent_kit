import 'consent_config.dart';

/// Status of consent as returned by Google UMP.
enum ConsentKitStatus {
  /// Consent has been obtained from the user.
  obtained,

  /// Consent is not required (user is outside the EEA).
  notRequired,

  /// Consent is required but has not been obtained yet.
  required,

  /// Consent status is unknown or could not be determined.
  unknown,
}

/// Abstract platform interface for consent operations.
///
/// This abstraction exists so the implementation can be swapped out in tests
/// without depending on google_mobile_ads native APIs.
abstract class ConsentPlatform {
  /// The most recently cached consent status.
  ///
  /// Returns `null` if [requestConsentInfoUpdate] has not been called yet.
  /// This is a synchronous cache for [ConsentKit.canRequestAds].
  ConsentKitStatus? get cachedStatus;

  /// Request consent info update from Google UMP.
  ///
  /// This is the first step in the consent flow. It must be called before
  /// any other consent operations.
  Future<void> requestConsentInfoUpdate({
    required bool debugMode,
    List<String>? testDeviceIds,
    ConsentKitDebugGeography? debugGeography,
    bool? tagForUnderAgeOfConsent,
  });

  /// Get the current consent status.
  Future<ConsentKitStatus> getConsentStatus();

  /// Check if a consent form is available (indicates the user is in the EEA).
  Future<bool> isConsentFormAvailable();

  /// Load and show the consent form if required.
  Future<void> loadAndShowConsentFormIfRequired();

  /// Show the privacy options form for users to change their consent.
  Future<bool> showPrivacyOptionsForm();

  /// Reset consent state (for testing or compliance).
  Future<void> resetConsent();
}
