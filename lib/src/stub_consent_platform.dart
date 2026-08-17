import 'consent_config.dart';
import 'consent_platform.dart';

/// No-op consent backend for web, desktop, and other non-AdMob platforms.
///
/// Ads stay off. The same Dart `main()` can run without throwing.
class StubConsentPlatform implements ConsentPlatform {
  ConsentKitStatus _status = ConsentKitStatus.notRequired;
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;

  @override
  ConsentKitStatus? get cachedStatus => _status;

  @override
  bool? get cachedCanRequestAds => _canRequestAds;

  @override
  bool? get cachedPrivacyOptionsRequired => _privacyOptionsRequired;

  @override
  Future<void> requestConsentInfoUpdate({
    required bool debugMode,
    List<String>? testDeviceIds,
    ConsentKitDebugGeography? debugGeography,
    bool? tagForUnderAgeOfConsent,
    Duration timeout = const Duration(seconds: 10),
  }) async {}

  @override
  Future<void> loadAndShowConsentFormIfRequired({
    Duration timeout = const Duration(seconds: 30),
  }) async {}

  @override
  Future<ConsentKitStatus> getConsentStatus() async => _status;

  @override
  Future<bool> canRequestAds() async => _canRequestAds;

  @override
  Future<bool> isPrivacyOptionsRequired() async => _privacyOptionsRequired;

  @override
  Future<bool> isConsentFormAvailable() async => false;

  @override
  Future<bool> showPrivacyOptionsForm() async => false;

  @override
  Future<void> resetConsent() async {
    _status = ConsentKitStatus.notRequired;
    _canRequestAds = false;
    _privacyOptionsRequired = false;
  }

  @override
  Future<void> initializeMobileAds() async {}
}
