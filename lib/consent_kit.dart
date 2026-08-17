export 'src/consent_config.dart';
export 'src/consent_exception.dart';
export 'src/consent_platform.dart';
export 'src/consent_result.dart';
export 'src/widgets/ad_gate.dart';
export 'src/widgets/consent_gate.dart';
export 'src/widgets/privacy_options_button.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'src/consent_config.dart';
import 'src/consent_exception.dart';
import 'src/consent_kit_impl.dart';
import 'src/consent_platform.dart';
import 'src/consent_result.dart';
import 'src/stub_consent_platform.dart';

/// The entry point for ConsentKit.
///
/// Google UMP for Flutter AdMob, without a ConsentManager class.
///
/// ## Quick start
///
/// ```dart
/// void main() {
///   WidgetsFlutterBinding.ensureInitialized();
///   ConsentKit.bootstrap();
///   runApp(const MyApp());
/// }
/// ```
///
/// Load ads only through [guardAdLoad] or wrap them in [AdGate].
/// Put [PrivacyOptionsButton] in an AppBar. Debug test-device IDs are ignored
/// in release builds.
class ConsentKit {
  ConsentKit._();

  static ConsentPlatform? _impl;
  static bool _initialized = false;
  static ConsentKitResult? _lastResult;
  static Future<ConsentKitResult>? _initializeFuture;
  static final ValueNotifier<ConsentKitResult?> _listenable =
      ValueNotifier<ConsentKitResult?>(null);

  /// Whether [initialize] / [bootstrap] has completed successfully.
  static bool get isInitialized => _initialized && _impl != null;

  /// The result of the most recent successful [initialize] call.
  static ConsentKitResult? get lastResult => _lastResult;

  /// Completes when consent gathering finishes.
  ///
  /// If [bootstrap] is in flight, waits for it. If gathering already
  /// succeeded, returns [lastResult]. Throws if bootstrap has not been called.
  static Future<ConsentKitResult> get ready async {
    if (_initialized && _lastResult != null) return _lastResult!;
    if (_initializeFuture != null) return _initializeFuture!;
    throw ConsentKitNotInitializedException();
  }

  /// Fires whenever consent state changes (init, privacy form, reset).
  ///
  /// Use with [ListenableBuilder], or prefer [AdGate] / [PrivacyOptionsButton].
  static ValueListenable<ConsentKitResult?> get listenable => _listenable;

  /// Hard-resets static state for testing.
  ///
  /// Unlike [resetConsent], this does not call the platform and does not
  /// require prior initialization. Safe to call in `tearDown`.
  @visibleForTesting
  static void resetForTesting() {
    _impl = null;
    _initialized = false;
    _lastResult = null;
    _initializeFuture = null;
    _listenable.value = null;
  }

  /// Start consent without blocking [runApp].
  ///
  /// Same work as [initialize]. Ignore the returned future in `main`.
  static Future<ConsentKitResult> bootstrap({
    ConsentKitConfig? config,
    ConsentPlatform? platform,
  }) {
    return initialize(config: config, platform: platform);
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
  /// On web and desktop, uses a no-op backend: [canRequestAds] stays `false`
  /// and nothing throws.
  ///
  /// Debug settings in [config] are applied only in `kDebugMode`.
  ///
  /// [platform] is for tests only - do not pass it in production.
  static Future<ConsentKitResult> initialize({
    ConsentKitConfig? config,
    ConsentPlatform? platform,
  }) {
    if (_initialized && _lastResult != null) {
      if (kDebugMode) {
        debugPrint('[ConsentKit] Already initialized. Skipping.');
      }
      return Future.value(_lastResult!);
    }
    return _initializeFuture ??= _gatherConsent(
      config: config ?? const ConsentKitConfig(),
      platform: platform,
    ).whenComplete(() {
      _initializeFuture = null;
    });
  }

  static Future<ConsentKitResult> _gatherConsent({
    required ConsentKitConfig config,
    ConsentPlatform? platform,
  }) async {
    if (platform != null) {
      _impl = platform;
    } else if (ConsentKitImpl.isSupportedPlatform) {
      _impl = ConsentKitImpl();
    } else {
      _impl = StubConsentPlatform();
      if (kDebugMode) {
        debugPrint(
          '[ConsentKit] ${defaultTargetPlatform.name} is not Android/iOS. '
          'Ads stay off.',
        );
      }
    }

    Object? gatheredError;

    try {
      await _impl!.requestConsentInfoUpdate(
        debugMode: kDebugMode,
        testDeviceIds: kDebugMode ? config.testDeviceIds : null,
        debugGeography: kDebugMode ? config.debugGeography : null,
        tagForUnderAgeOfConsent: config.tagForUnderAgeOfConsent,
        timeout: config.infoUpdateTimeout,
      );

      await _impl!.loadAndShowConsentFormIfRequired(
        timeout: config.formTimeout,
      );
    } catch (e) {
      gatheredError = e;
      if (kDebugMode) {
        debugPrint('[ConsentKit] Consent gathering error: $e');
      }

      // Google: on error, still check canRequestAds from a previous session.
      final canAds = await _safeCanRequestAds();
      if (!canAds) {
        _failInitialize();
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

    if (config.initializeMobileAds && result.canRequestAds) {
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
    _listenable.value = result;

    if (kDebugMode) {
      debugPrint('[ConsentKit] Initialized: $result');
    }

    return result;
  }

  static void _failInitialize() {
    _impl = null;
    _initialized = false;
    _lastResult = null;
    _listenable.value = null;
  }

  /// Whether the app can request ads (synchronous, cached).
  ///
  /// Safe before [initialize]: returns `false` until UMP confirms ads.
  static bool get canRequestAds {
    if (!_initialized || _impl == null) return false;
    return _impl!.cachedCanRequestAds ?? false;
  }

  /// Refresh and return whether ads may be requested (async, live from UMP).
  ///
  /// Returns `false` if consent has not finished yet.
  static Future<bool> refreshCanRequestAds() async {
    if (!_initialized || _impl == null) return false;
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
  ///
  /// Returns `false` if consent has not finished yet.
  static Future<bool> isPrivacyOptionsRequired() async {
    if (!_initialized || _impl == null) return false;
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
  /// Returns `false` if consent is not ready or the form was not shown.
  static Future<bool> showPrivacyOptions() async {
    if (_initializeFuture != null) {
      try {
        await _initializeFuture;
      } catch (_) {
        return false;
      }
    }
    if (!_initialized || _impl == null) return false;
    final shown = await _impl!.showPrivacyOptionsForm();
    if (shown) {
      _lastResult = await _buildResult();
      _listenable.value = _lastResult;
    }
    return shown;
  }

  /// Reset the consent state (development / testing only).
  ///
  /// After calling this, [initialize] must be called again.
  static Future<void> resetConsent() async {
    if (!_initialized || _impl == null) {
      throw ConsentKitNotInitializedException();
    }
    await _impl!.resetConsent();
    _initialized = false;
    _lastResult = null;
    _initializeFuture = null;
    _listenable.value = null;
  }

  /// Initialize Mobile Ads if consent allows and it hasn't been initialized yet.
  ///
  /// No-op when [canRequestAds] is `false`.
  static Future<bool> initializeMobileAds() async {
    if (!_initialized || _impl == null) return false;
    if (!canRequestAds) return false;
    await _impl!.initializeMobileAds();
    return true;
  }

  /// Runs [loadAd] only when UMP allows ad requests.
  ///
  /// If [bootstrap] / [initialize] is still running, waits for it.
  /// Returns `true` when [loadAd] ran, `false` when ads are not allowed.
  ///
  /// ```dart
  /// await ConsentKit.guardAdLoad(() => banner.load());
  /// ```
  static Future<bool> guardAdLoad(FutureOr<void> Function() loadAd) async {
    if (_initializeFuture != null) {
      try {
        await _initializeFuture;
      } catch (_) {
        return false;
      }
    }
    if (!canRequestAds) return false;
    await loadAd();
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

  @visibleForTesting
  static void assertSupportedPlatform() {
    ConsentKitImpl.assertSupportedPlatform();
  }
}
