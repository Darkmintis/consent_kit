export 'src/consent_config.dart';
export 'src/consent_exception.dart';
export 'src/consent_platform.dart';
export 'src/consent_result.dart';
export 'src/widgets/consent_gate.dart';
export 'src/widgets/privacy_options_button.dart';

import 'package:flutter/foundation.dart';

import 'src/consent_config.dart';
import 'src/consent_exception.dart';
import 'src/consent_kit_impl.dart';
import 'src/consent_platform.dart';
import 'src/consent_result.dart';

/// The entry point for ConsentKit.
///
/// The simplest and safest way to integrate Google's User Messaging Platform
/// (UMP) for consent management in mobile ads.
///
/// ## Quick Start
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   final result = await ConsentKit.initialize(
///     config: ConsentKitConfig(initializeMobileAds: true),
///   );
///
///   if (result.canRequestAds) {
///     // Load ads
///   }
///
///   runApp(const MyApp());
/// }
/// ```
///
/// Or wrap your app with [ConsentGate] for zero-boilerplate UI:
///
/// ```dart
/// runApp(
///   ConsentGate(
///     config: ConsentKitConfig(initializeMobileAds: true),
///     builder: (context) => const MyApp(),
///   ),
/// );
/// ```
class ConsentKit {
  ConsentKit._();

  static ConsentPlatform? _impl;
  static bool _initialized = false;
  static ConsentKitResult? _lastResult;

  /// Whether [initialize] has completed successfully.
  static bool get isInitialized => _initialized && _impl != null;

  /// The result of the most recent successful [initialize] call.
  static ConsentKitResult? get lastResult => _lastResult;

  /// Hard-resets static state for testing.
  ///
  /// Unlike [resetConsent], this does not call the platform and does not
  /// require prior initialization. Safe to call in `tearDown`.
  @visibleForTesting
  static void resetForTesting() {
    _impl = null;
    _initialized = false;
    _lastResult = null;
  }

  /// Initialize the consent flow (call once per app launch).
  ///
  /// Follows Google's recommended UMP sequence:
  /// 1. `requestConsentInfoUpdate`
  /// 2. `loadAndShowConsentFormIfRequired`
  /// 3. Refresh `canRequestAds` / privacy-options requirement
  /// 4. Optionally initialize Mobile Ads when [ConsentKitConfig.initializeMobileAds]
  ///    is `true` and ads are allowed
  ///
  /// On gathering errors, recovers using the previous session's consent when
  /// UMP still reports that ads may be requested.
  ///
  /// Debug settings in [config] are applied only in `kDebugMode`.
  ///
  /// [platform] is for tests only — do not pass it in production.
  static Future<ConsentKitResult> initialize({
    ConsentKitConfig? config,
    @visibleForTesting ConsentPlatform? platform,
  }) async {
    if (_initialized && _lastResult != null) {
      if (kDebugMode) {
        debugPrint('[ConsentKit] Already initialized. Skipping.');
      }
      return _lastResult!;
    }

    final cfg = config ?? const ConsentKitConfig();
    if (platform != null) {
      _impl = platform;
    } else {
      ConsentKitImpl.assertSupportedPlatform();
      _impl = ConsentKitImpl();
    }

    Object? gatheredError;

    try {
      await _impl!.requestConsentInfoUpdate(
        debugMode: kDebugMode,
        testDeviceIds: kDebugMode ? cfg.testDeviceIds : null,
        debugGeography: kDebugMode ? cfg.debugGeography : null,
        tagForUnderAgeOfConsent: cfg.tagForUnderAgeOfConsent,
        timeout: cfg.infoUpdateTimeout,
      );

      await _impl!.loadAndShowConsentFormIfRequired(
        timeout: cfg.formTimeout,
      );
    } catch (e) {
      gatheredError = e;
      if (kDebugMode) {
        debugPrint('[ConsentKit] Consent gathering error: $e');
      }

      // Google: on error, still check canRequestAds from a previous session.
      final canAds = await _safeCanRequestAds();
      if (!canAds) {
        _impl = null;
        _initialized = false;
        _lastResult = null;
        if (e is ConsentKitException) rethrow;
        throw ConsentKitException(
          'Consent initialization failed.',
          cause: e,
        );
      }
    }

    final result = await _buildResult(
      recoveredFromError: gatheredError != null,
      error: gatheredError,
    );

    if (cfg.initializeMobileAds && result.canRequestAds) {
      try {
        await _impl!.initializeMobileAds();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ConsentKit] Mobile Ads init failed: $e');
        }
      }
    }

    _initialized = true;
    _lastResult = result;

    if (kDebugMode) {
      debugPrint('[ConsentKit] Initialized: $result');
    }

    return result;
  }

  /// Whether the app can request ads (synchronous, cached).
  ///
  /// Prefer reading this after [initialize]. Returns `false` when UMP has not
  /// confirmed that ads are allowed.
  ///
  /// Must be called after [initialize].
  static bool get canRequestAds {
    _assertInitialized();
    return _impl!.cachedCanRequestAds ?? false;
  }

  /// Refresh and return whether ads may be requested (async, live from UMP).
  static Future<bool> refreshCanRequestAds() async {
    _assertInitialized();
    return _impl!.canRequestAds();
  }

  /// The current consent status.
  ///
  /// Returns `null` if initialization hasn't completed or the lookup fails.
  static Future<ConsentKitStatus?> get consentStatus async {
    if (!_initialized || _impl == null) return null;
    try {
      return await _impl!.getConsentStatus();
    } catch (_) {
      return null;
    }
  }

  /// Whether a privacy-options entry point must be shown (EU requirement).
  ///
  /// Use this to show/hide a settings button. Prefer [PrivacyOptionsButton]
  /// which handles this automatically.
  static Future<bool> isPrivacyOptionsRequired() async {
    _assertInitialized();
    return _impl!.isPrivacyOptionsRequired();
  }

  /// Cached privacy-options requirement (sync).
  ///
  /// Returns `false` when unknown / not yet cached.
  static bool get privacyOptionsRequired {
    if (!_initialized || _impl == null) return false;
    return _impl!.cachedPrivacyOptionsRequired ?? false;
  }

  /// Show the privacy options form.
  ///
  /// Returns `true` if the form was presented successfully.
  /// Must be called after [initialize].
  static Future<bool> showPrivacyOptions() async {
    _assertInitialized();
    final shown = await _impl!.showPrivacyOptionsForm();
    if (shown) {
      _lastResult = await _buildResult();
    }
    return shown;
  }

  /// Reset the consent state (development / testing only).
  ///
  /// After calling this, [initialize] must be called again.
  static Future<void> resetConsent() async {
    _assertInitialized();
    await _impl!.resetConsent();
    _initialized = false;
    _lastResult = null;
  }

  /// Initialize Mobile Ads if consent allows and it hasn't been initialized yet.
  ///
  /// No-op when [canRequestAds] is `false`.
  static Future<bool> initializeMobileAds() async {
    _assertInitialized();
    if (!canRequestAds) return false;
    await _impl!.initializeMobileAds();
    return true;
  }

  static Future<bool> _safeCanRequestAds() async {
    try {
      return await _impl!.canRequestAds();
    } catch (_) {
      return _impl!.cachedCanRequestAds ?? false;
    }
  }

  static Future<ConsentKitResult> _buildResult({
    bool recoveredFromError = false,
    Object? error,
  }) async {
    final results = await Future.wait([
      _safeGetConsentStatus(),
      _safeCanRequestAdsValue(),
      _safePrivacyRequired(),
    ]);
    return ConsentKitResult(
      status: results[0] as ConsentKitStatus,
      canRequestAds: results[1] as bool,
      isPrivacyOptionsRequired: results[2] as bool,
      recoveredFromError: recoveredFromError,
      error: error,
    );
  }

  static Future<ConsentKitStatus> _safeGetConsentStatus() async {
    try {
      return await _impl!.getConsentStatus();
    } catch (_) {
      return _impl!.cachedStatus ?? ConsentKitStatus.unknown;
    }
  }

  static Future<bool> _safeCanRequestAdsValue() async {
    try {
      return await _impl!.canRequestAds();
    } catch (_) {
      return _impl!.cachedCanRequestAds ?? false;
    }
  }

  static Future<bool> _safePrivacyRequired() async {
    try {
      return await _impl!.isPrivacyOptionsRequired();
    } catch (_) {
      return _impl!.cachedPrivacyOptionsRequired ?? false;
    }
  }

  static void _assertInitialized() {
    if (!_initialized || _impl == null) {
      throw ConsentKitNotInitializedException();
    }
  }

  @visibleForTesting
  static void assertSupportedPlatform() {
    ConsentKitImpl.assertSupportedPlatform();
  }
}
