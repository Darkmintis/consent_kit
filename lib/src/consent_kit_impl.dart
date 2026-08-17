import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'consent_config.dart';
import 'consent_exception.dart';
import 'consent_platform.dart';

/// Maps [ConsentKitDebugGeography] to Google's [DebugGeography].
DebugGeography _mapDebugGeography(ConsentKitDebugGeography geography) {
  switch (geography) {
    case ConsentKitDebugGeography.eea:
      return DebugGeography.debugGeographyEea;
    case ConsentKitDebugGeography.notEea:
      return DebugGeography.debugGeographyOther;
  }
}

/// Maps Google's [ConsentStatus] to [ConsentKitStatus].
ConsentKitStatus _mapConsentStatus(ConsentStatus status) {
  switch (status) {
    case ConsentStatus.obtained:
      return ConsentKitStatus.obtained;
    case ConsentStatus.notRequired:
      return ConsentKitStatus.notRequired;
    case ConsentStatus.required:
      return ConsentKitStatus.required;
    case ConsentStatus.unknown:
      return ConsentKitStatus.unknown;
  }
}

/// Production implementation of [ConsentPlatform] backed by Google's UMP SDK.
class ConsentKitImpl implements ConsentPlatform {
  ConsentKitStatus? _cachedStatus;
  bool? _cachedCanRequestAds;
  bool? _cachedPrivacyOptionsRequired;
  bool _mobileAdsInitialized = false;

  @override
  ConsentKitStatus? get cachedStatus => _cachedStatus;

  @override
  bool? get cachedCanRequestAds => _cachedCanRequestAds;

  @override
  bool? get cachedPrivacyOptionsRequired => _cachedPrivacyOptionsRequired;

  @override
  Future<void> requestConsentInfoUpdate({
    required bool debugMode,
    List<String>? testDeviceIds,
    ConsentKitDebugGeography? debugGeography,
    bool? tagForUnderAgeOfConsent,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final params = _buildConsentRequestParameters(
        debugMode: debugMode,
        testDeviceIds: testDeviceIds,
        debugGeography: debugGeography,
        tagForUnderAgeOfConsent: tagForUnderAgeOfConsent,
      );

      final completer = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () {
          if (!completer.isCompleted) completer.complete();
        },
        (FormError error) {
          if (!completer.isCompleted) {
            completer.completeError(
              ConsentKitException(
                'Consent info update failed: ${error.message}',
              ),
            );
          }
        },
      );

      await completer.future.timeout(
        timeout,
        onTimeout: () {
          throw ConsentKitException(
            'Consent info update timed out after ${timeout.inSeconds} seconds.',
          );
        },
      );

      await _refreshCaches(debugMode: debugMode);
    } on ConsentKitException {
      rethrow;
    } catch (e) {
      throw ConsentKitException(
        'Unexpected error during consent info update.',
        cause: e,
      );
    }
  }

  ConsentRequestParameters _buildConsentRequestParameters({
    required bool debugMode,
    List<String>? testDeviceIds,
    ConsentKitDebugGeography? debugGeography,
    bool? tagForUnderAgeOfConsent,
  }) {
    ConsentDebugSettings? debugSettings;

    if (debugMode) {
      debugSettings = ConsentDebugSettings(
        debugGeography: debugGeography != null
            ? _mapDebugGeography(debugGeography)
            : null,
        testIdentifiers: testDeviceIds ?? [],
      );

      if (debugGeography != null) {
        debugPrint('[ConsentKit] Debug geography: $debugGeography');
      }
      if (testDeviceIds != null && testDeviceIds.isNotEmpty) {
        debugPrint('[ConsentKit] Test device IDs: $testDeviceIds');
      }
    }

    return ConsentRequestParameters(
      consentDebugSettings: debugSettings,
      tagForUnderAgeOfConsent: tagForUnderAgeOfConsent,
    );
  }

  Future<void> _refreshCaches({required bool debugMode}) async {
    final status = await ConsentInformation.instance.getConsentStatus();
    _cachedStatus = _mapConsentStatus(status);
    _cachedCanRequestAds = await ConsentInformation.instance.canRequestAds();
    final privacy = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    _cachedPrivacyOptionsRequired =
        privacy == PrivacyOptionsRequirementStatus.required;

    if (debugMode) {
      debugPrint(
        '[ConsentKit] status=$_cachedStatus '
        'canRequestAds=$_cachedCanRequestAds '
        'privacyOptionsRequired=$_cachedPrivacyOptionsRequired',
      );
    }
  }

  @override
  Future<void> loadAndShowConsentFormIfRequired({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final completer = Completer<void>();
      ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
        if (completer.isCompleted) return;
        if (error != null) {
          completer.completeError(
            ConsentKitException('Consent form error: ${error.message}'),
          );
        } else {
          completer.complete();
        }
      });
      await completer.future.timeout(
        timeout,
        onTimeout: () {
          throw ConsentKitException(
            'Consent form timed out after ${timeout.inSeconds} seconds.',
          );
        },
      );

      await _refreshCaches(debugMode: kDebugMode);
    } on ConsentKitException {
      rethrow;
    } catch (e) {
      throw ConsentKitException(
        'Failed to load and show consent form.',
        cause: e,
      );
    }
  }

  @override
  Future<ConsentKitStatus> getConsentStatus() async {
    try {
      final status = await ConsentInformation.instance.getConsentStatus();
      _cachedStatus = _mapConsentStatus(status);
      return _cachedStatus!;
    } catch (e) {
      if (_cachedStatus != null) return _cachedStatus!;
      throw ConsentKitException(
        'Failed to get consent status.',
        cause: e,
      );
    }
  }

  @override
  Future<bool> canRequestAds() async {
    try {
      _cachedCanRequestAds = await ConsentInformation.instance.canRequestAds();
      return _cachedCanRequestAds!;
    } catch (e) {
      if (_cachedCanRequestAds != null) return _cachedCanRequestAds!;
      throw ConsentKitException(
        'Failed to check canRequestAds.',
        cause: e,
      );
    }
  }

  @override
  Future<bool> isPrivacyOptionsRequired() async {
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      _cachedPrivacyOptionsRequired =
          status == PrivacyOptionsRequirementStatus.required;
      return _cachedPrivacyOptionsRequired!;
    } catch (e) {
      if (_cachedPrivacyOptionsRequired != null) {
        return _cachedPrivacyOptionsRequired!;
      }
      throw ConsentKitException(
        'Failed to check privacy options requirement.',
        cause: e,
      );
    }
  }

  @override
  Future<bool> isConsentFormAvailable() async {
    try {
      return await ConsentInformation.instance.isConsentFormAvailable();
    } catch (e) {
      throw ConsentKitException(
        'Failed to check consent form availability.',
        cause: e,
      );
    }
  }

  @override
  Future<bool> showPrivacyOptionsForm() async {
    try {
      final completer = Completer<bool>();
      ConsentForm.showPrivacyOptionsForm((FormError? error) {
        if (completer.isCompleted) return;
        completer.complete(error == null);
      });
      final shown = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => false,
      );
      if (shown) {
        await _refreshCaches(debugMode: kDebugMode);
      }
      return shown;
    } on ConsentKitException {
      rethrow;
    } catch (e) {
      throw ConsentKitException(
        'Failed to show privacy options form.',
        cause: e,
      );
    }
  }

  @override
  Future<void> resetConsent() async {
    try {
      await ConsentInformation.instance.reset();
      _cachedStatus = ConsentKitStatus.unknown;
      _cachedCanRequestAds = false;
      _cachedPrivacyOptionsRequired = false;
      _mobileAdsInitialized = false;
    } catch (e) {
      throw ConsentKitException(
        'Failed to reset consent.',
        cause: e,
      );
    }
  }

  @override
  Future<void> initializeMobileAds() async {
    if (_mobileAdsInitialized) return;
    await MobileAds.instance.initialize();
    _mobileAdsInitialized = true;
    if (kDebugMode) {
      debugPrint('[ConsentKit] Mobile Ads SDK initialized.');
    }
  }

  /// Whether the current platform can run Google UMP (Android or iOS).
  ///
  /// Uses Flutter foundation APIs so the package stays import-safe on web.
  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Throws if the current platform cannot run Google UMP.
  static void assertSupportedPlatform() {
    if (!isSupportedPlatform) {
      throw ConsentKitUnsupportedPlatformException();
    }
  }
}
