import 'package:consent_kit/src/consent_config.dart';
import 'package:consent_kit/src/consent_platform.dart';

/// A mock [ConsentPlatform] for unit testing.
///
/// Simulates consent operations without any native dependencies.
class MockConsentPlatform implements ConsentPlatform {
  ConsentKitStatus? _cachedStatus;
  bool _formAvailable = false;
  bool _privacyOptionsResult = true;
  bool _shouldFail = false;

  @override
  ConsentKitStatus? get cachedStatus => _cachedStatus;

  void setCachedStatus(ConsentKitStatus status) {
    _cachedStatus = status;
  }

  void setFormAvailable(bool available) {
    _formAvailable = available;
  }

  void setPrivacyOptionsResult(bool result) {
    _privacyOptionsResult = result;
  }

  void setShouldFail(bool shouldFail) {
    _shouldFail = shouldFail;
  }

  @override
  Future<void> requestConsentInfoUpdate({
    required bool debugMode,
    List<String>? testDeviceIds,
    ConsentKitDebugGeography? debugGeography,
    bool? tagForUnderAgeOfConsent,
  }) async {
    if (_shouldFail) {
      throw Exception('Simulated failure');
    }
  }

  @override
  Future<ConsentKitStatus> getConsentStatus() async {
    if (_shouldFail) {
      throw Exception('Simulated failure');
    }
    return _cachedStatus ?? ConsentKitStatus.unknown;
  }

  @override
  Future<bool> isConsentFormAvailable() async {
    return _formAvailable;
  }

  @override
  Future<void> loadAndShowConsentFormIfRequired() async {
    if (_shouldFail) {
      throw Exception('Simulated failure');
    }
  }

  @override
  Future<bool> showPrivacyOptionsForm() async {
    if (_shouldFail) {
      throw Exception('Simulated failure');
    }
    return _privacyOptionsResult;
  }

  @override
  Future<void> resetConsent() async {
    if (_shouldFail) {
      throw Exception('Simulated failure');
    }
    _cachedStatus = ConsentKitStatus.unknown;
  }
}
