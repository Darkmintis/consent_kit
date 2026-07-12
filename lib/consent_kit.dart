export 'src/consent_config.dart';
export 'src/consent_exception.dart';
export 'src/consent_platform.dart';

import 'package:flutter/foundation.dart';
import 'src/consent_config.dart';
import 'src/consent_exception.dart';
import 'src/consent_kit_impl.dart';
import 'src/consent_platform.dart';

/// The entry point for ConsentKit.
///
/// ConsentKit provides the simplest and safest way to integrate Google's User
/// Messaging Platform (UMP) for consent management in mobile ads.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:consent_kit/consent_kit.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   await ConsentKit.initialize();
///
///   if (ConsentKit.canRequestAds) {
///     // Load ads
///   }
/// }
/// ```
class ConsentKit {
  ConsentKit._();

  static ConsentPlatform? _impl;
  static bool _initialized = false;

  /// Hard-resets static state for testing.
  ///
  /// Unlike [resetConsent], this does not call the platform and does not
  /// require prior initialization. Safe to call in `tearDown`.
  @visibleForTesting
  static void resetForTesting() {
    _impl = null;
    _initialized = false;
  }

  /// Initialize the consent flow.
  ///
  /// This must be called once before any other ConsentKit methods. It will:
  /// 1. Check that the platform is Android or iOS.
  /// 2. Request consent info update from Google UMP.
  /// 3. Show the consent form if required (EU users).
  ///
  /// In debug mode, [config] settings like [ConsentKitConfig.testDeviceIds]
  /// and [ConsentKitConfig.debugGeography] are applied automatically. In
  /// release builds, those settings are safely ignored.
  ///
  /// [platform] is used for dependency injection in tests. Do not provide
  /// it in production code — the default [ConsentKitImpl] will be used.
  ///
  /// Throws [ConsentKitUnsupportedPlatformException] on non-mobile platforms.
  /// Throws [ConsentKitException] on initialization failure.
  static Future<void> initialize({
    ConsentKitConfig? config,
    @visibleForTesting ConsentPlatform? platform,
  }) async {
    if (_initialized) {
      if (kDebugMode) {
        debugPrint('[ConsentKit] Already initialized. Skipping.');
      }
      return;
    }

    final cfg = config ?? const ConsentKitConfig();
    if (platform != null) {
      _impl = platform;
    } else {
      ConsentKitImpl.assertSupportedPlatform();
      _impl = ConsentKitImpl();
    }

    try {
      await _impl!.requestConsentInfoUpdate(
        debugMode: kDebugMode,
        testDeviceIds: kDebugMode ? cfg.testDeviceIds : null,
        debugGeography: kDebugMode ? cfg.debugGeography : null,
        tagForUnderAgeOfConsent: cfg.tagForUnderAgeOfConsent,
      );
    } catch (e) {
      _impl = null;
      _initialized = false;
      if (e is ConsentKitException) rethrow;
      throw ConsentKitException(
        'Consent initialization failed.',
        cause: e,
      );
    }

    _initialized = true;

    if (kDebugMode) {
      debugPrint('[ConsentKit] Initialized successfully.');
    }
  }

  /// Whether the app can request ads based on the current consent status.
  ///
  /// Returns `true` when:
  /// - Consent has been obtained.
  /// - Consent is not required (non-EEA user).
  /// - Consent status is unknown (graceful degradation).
  ///
  /// Returns `false` only when consent is explicitly denied.
  ///
  /// Must be called after [initialize].
  static bool get canRequestAds {
    _assertInitialized();
    final status = _impl!.cachedStatus;
    if (status == null) return true;
    return status == ConsentKitStatus.obtained ||
        status == ConsentKitStatus.notRequired ||
        status == ConsentKitStatus.unknown;
  }

  /// The current consent status.
  ///
  /// Returns `null` if the status could not be determined or if
  /// [initialize] has not been called yet.
  static Future<ConsentKitStatus?> get consentStatus async {
    if (!_initialized || _impl == null) return null;
    try {
      return await _impl!.getConsentStatus();
    } catch (_) {
      return null;
    }
  }

  /// Show the privacy options form.
  ///
  /// This allows EU users to review and change their consent preferences.
  /// Returns `true` if the form was presented successfully.
  ///
  /// Must be called after [initialize].
  static Future<bool> showPrivacyOptions() async {
    _assertInitialized();
    return _impl!.showPrivacyOptionsForm();
  }

  /// Reset the consent state.
  ///
  /// This is primarily useful during development and testing. After calling
  /// this, [initialize] must be called again before using other methods.
  ///
  /// Must be called after [initialize].
  static Future<void> resetConsent() async {
    _assertInitialized();
    await _impl!.resetConsent();
    _initialized = false;
  }

  static void _assertInitialized() {
    if (!_initialized || _impl == null) {
      throw ConsentKitNotInitializedException();
    }
  }
}
