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
/// Swap this out in tests without depending on google_mobile_ads native APIs.
abstract class ConsentPlatform {
  /// Most recently cached consent status.
  ///
  /// `null` until [requestConsentInfoUpdate] has completed once.
  ConsentKitStatus? get cachedStatus;

  /// Most recently cached [canRequestAds] value from UMP.
  ///
  /// `null` until refreshed from the platform.
  bool? get cachedCanRequestAds;

  /// Most recently cached privacy-options requirement.
  ///
  /// `null` until refreshed from the platform.
  bool? get cachedPrivacyOptionsRequired;

  /// Request consent info update from Google UMP (call every app launch).
  Future<void> requestConsentInfoUpdate({
    required bool debugMode,
    List<String>? testDeviceIds,
    ConsentKitDebugGeography? debugGeography,
    bool? tagForUnderAgeOfConsent,
    Duration timeout = const Duration(seconds: 10),
  });

  /// Load and show the consent form if UMP requires it.
  Future<void> loadAndShowConsentFormIfRequired({
    Duration timeout = const Duration(seconds: 30),
  });

  /// Refresh and return the current consent status.
  Future<ConsentKitStatus> getConsentStatus();

  /// Whether UMP says ads may be requested.
  Future<bool> canRequestAds();

  /// Whether a privacy-options entry point must be shown.
  Future<bool> isPrivacyOptionsRequired();

  /// Whether a consent form is available for this user.
  Future<bool> isConsentFormAvailable();

  /// Show the privacy options form.
  Future<bool> showPrivacyOptionsForm();

  /// Reset consent state (testing / development only).
  Future<void> resetConsent();

  /// Initialize the Mobile Ads SDK when ads are allowed.
  Future<void> initializeMobileAds();
}
