import '../consent_config.dart';
import '../consent_platform.dart';

/// Captured arguments from the last [requestConsentInfoUpdate] call.
class MockConsentInfoUpdateCall {
  final bool debugMode;
  final List<String>? testDeviceIds;
  final ConsentKitDebugGeography? debugGeography;
  final bool? tagForUnderAgeOfConsent;
  final Duration timeout;

  const MockConsentInfoUpdateCall({
    required this.debugMode,
    required this.testDeviceIds,
    required this.debugGeography,
    required this.tagForUnderAgeOfConsent,
    required this.timeout,
  });
}

/// A mock [ConsentPlatform] for unit testing.
///
/// Simulates consent operations without any native dependencies.
class MockConsentPlatform implements ConsentPlatform {
  ConsentKitStatus? _cachedStatus;
  bool? _cachedCanRequestAds;
  bool? _cachedPrivacyOptionsRequired;
  bool _formAvailable = false;
  bool _privacyOptionsResult = true;
  bool _shouldFailInfoUpdate = false;
  bool _shouldFailForm = false;
  bool _shouldFailGetStatus = false;
  bool _shouldFailCanRequestAds = false;
  bool _shouldFailPrivacyOptions = false;
  bool _shouldFailMobileAds = false;
  bool _mobileAdsInitialized = false;

  int requestInfoUpdateCallCount = 0;
  int loadFormCallCount = 0;
  int showPrivacyOptionsCallCount = 0;
  int resetCallCount = 0;
  int initializeMobileAdsCallCount = 0;

  MockConsentInfoUpdateCall? lastInfoUpdateCall;

  @override
  ConsentKitStatus? get cachedStatus => _cachedStatus;

  @override
  bool? get cachedCanRequestAds => _cachedCanRequestAds;

  @override
  bool? get cachedPrivacyOptionsRequired => _cachedPrivacyOptionsRequired;

  /// Whether Mobile Ads was initialized via this mock.
  bool get mobileAdsInitialized => _mobileAdsInitialized;

  void setCachedStatus(ConsentKitStatus status) {
    _cachedStatus = status;
  }

  void setCanRequestAds(bool value) {
    _cachedCanRequestAds = value;
  }

  void setPrivacyOptionsRequired(bool value) {
    _cachedPrivacyOptionsRequired = value;
  }

  void setFormAvailable(bool available) {
    _formAvailable = available;
  }

  void setPrivacyOptionsResult(bool result) {
    _privacyOptionsResult = result;
  }

  void setShouldFailInfoUpdate(bool shouldFail) {
    _shouldFailInfoUpdate = shouldFail;
  }

  void setShouldFailForm(bool shouldFail) {
    _shouldFailForm = shouldFail;
  }

  void setShouldFailGetStatus(bool shouldFail) {
    _shouldFailGetStatus = shouldFail;
  }

  void setShouldFailCanRequestAds(bool shouldFail) {
    _shouldFailCanRequestAds = shouldFail;
  }

  void setShouldFailPrivacyOptions(bool shouldFail) {
    _shouldFailPrivacyOptions = shouldFail;
  }

  void setShouldFailMobileAds(bool shouldFail) {
    _shouldFailMobileAds = shouldFail;
  }

  /// Convenience: fail the next info update.
  void setShouldFail(bool shouldFail) {
    _shouldFailInfoUpdate = shouldFail;
  }

  @override
  Future<void> requestConsentInfoUpdate({
    required bool debugMode,
    List<String>? testDeviceIds,
    ConsentKitDebugGeography? debugGeography,
    bool? tagForUnderAgeOfConsent,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    requestInfoUpdateCallCount++;
    lastInfoUpdateCall = MockConsentInfoUpdateCall(
      debugMode: debugMode,
      testDeviceIds: testDeviceIds,
      debugGeography: debugGeography,
      tagForUnderAgeOfConsent: tagForUnderAgeOfConsent,
      timeout: timeout,
    );

    if (_shouldFailInfoUpdate) {
      throw Exception('Simulated info update failure');
    }
    _cachedStatus ??= ConsentKitStatus.notRequired;
    _cachedCanRequestAds ??= true;
    _cachedPrivacyOptionsRequired ??= false;
  }

  @override
  Future<void> loadAndShowConsentFormIfRequired({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    loadFormCallCount++;
    if (_shouldFailForm) {
      throw Exception('Simulated form failure');
    }
  }

  @override
  Future<ConsentKitStatus> getConsentStatus() async {
    if (_shouldFailGetStatus) {
      throw Exception('Simulated getConsentStatus failure');
    }
    return _cachedStatus ?? ConsentKitStatus.unknown;
  }

  @override
  Future<bool> canRequestAds() async {
    if (_shouldFailCanRequestAds) {
      throw Exception('Simulated canRequestAds failure');
    }
    return _cachedCanRequestAds ?? false;
  }

  @override
  Future<bool> isPrivacyOptionsRequired() async {
    if (_shouldFailPrivacyOptions) {
      throw Exception('Simulated privacy options failure');
    }
    return _cachedPrivacyOptionsRequired ?? false;
  }

  @override
  Future<bool> isConsentFormAvailable() async {
    return _formAvailable;
  }

  @override
  Future<bool> showPrivacyOptionsForm() async {
    showPrivacyOptionsCallCount++;
    if (_shouldFailPrivacyOptions) {
      throw Exception('Simulated show privacy options failure');
    }
    return _privacyOptionsResult;
  }

  @override
  Future<void> resetConsent() async {
    resetCallCount++;
    _cachedStatus = ConsentKitStatus.unknown;
    _cachedCanRequestAds = false;
    _cachedPrivacyOptionsRequired = false;
  }

  @override
  Future<void> initializeMobileAds() async {
    initializeMobileAdsCallCount++;
    if (_shouldFailMobileAds) {
      throw Exception('Simulated Mobile Ads init failure');
    }
    _mobileAdsInitialized = true;
  }
}
