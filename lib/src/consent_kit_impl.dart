import 'dart:async';
import 'dart:io';

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

  /// The most recently cached consent status.
  /// Returns `null` if [requestConsentInfoUpdate] has not been called yet.
  @override
  ConsentKitStatus? get cachedStatus => _cachedStatus;

  @override
  Future<void> requestConsentInfoUpdate({
    required bool debugMode,
    List<String>? testDeviceIds,
    ConsentKitDebugGeography? debugGeography,
    bool? tagForUnderAgeOfConsent,
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
        const Duration(seconds: 10),
        onTimeout: () {
          throw ConsentKitException(
            'Consent info update timed out after 10 seconds.',
          );
        },
      );

      final status = await ConsentInformation.instance.getConsentStatus();
      _cachedStatus = _mapConsentStatus(status);

      if (debugMode) {
        debugPrint('[ConsentKit] Consent status: $_cachedStatus');
      }

      final formAvailable =
          await ConsentInformation.instance.isConsentFormAvailable();
      final isRequired = status == ConsentStatus.required;

      if (formAvailable && isRequired) {
        if (debugMode) {
          debugPrint('[ConsentKit] Consent form is required. Showing form...');
        }
        await loadAndShowConsentFormIfRequired();
      }
    } on ConsentKitException {
      rethrow;
    } catch (e) {
      throw ConsentKitException(
        'Unexpected error during consent initialization.',
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
  Future<void> loadAndShowConsentFormIfRequired() async {
    try {
      final completer = Completer<void>();
      ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
        if (completer.isCompleted) return;
        if (error != null) {
          completer.completeError(
            ConsentKitException(
              'Consent form error: ${error.message}',
            ),
          );
        } else {
          completer.complete();
        }
      });
      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw ConsentKitException(
            'Consent form timed out after 30 seconds.',
          );
        },
      );

      final status = await ConsentInformation.instance.getConsentStatus();
      _cachedStatus = _mapConsentStatus(status);
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
  Future<bool> showPrivacyOptionsForm() async {
    try {
      final completer = Completer<bool>();
      ConsentForm.showPrivacyOptionsForm((FormError? error) {
        if (completer.isCompleted) return;
        completer.complete(error == null);
      });
      return completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );
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
    } catch (e) {
      throw ConsentKitException(
        'Failed to reset consent.',
        cause: e,
      );
    }
  }

  /// Check if the current platform is supported (Android or iOS).
  static void assertSupportedPlatform() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw ConsentKitUnsupportedPlatformException();
    }
  }
}
