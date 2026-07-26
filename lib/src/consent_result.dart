import 'consent_platform.dart';

/// Snapshot of consent state after [ConsentKit.initialize] completes.
class ConsentKitResult {
  /// Current consent status from Google UMP.
  final ConsentKitStatus status;

  /// Whether the app may request ads under the current consent state.
  ///
  /// Backed by UMP's `canRequestAds()` — not a local guess from [status].
  final bool canRequestAds;

  /// Whether the app must show a privacy-options entry point (EU messages).
  final bool isPrivacyOptionsRequired;

  /// `true` when consent gathering hit an error but a previous session still
  /// allows ads (Google's recommended recovery path).
  final bool recoveredFromError;

  /// The error that was recovered from, if any.
  final Object? error;

  const ConsentKitResult({
    required this.status,
    required this.canRequestAds,
    required this.isPrivacyOptionsRequired,
    this.recoveredFromError = false,
    this.error,
  });

  @override
  String toString() =>
      'ConsentKitResult(status: $status, canRequestAds: $canRequestAds, '
      'isPrivacyOptionsRequired: $isPrivacyOptionsRequired'
      '${recoveredFromError ? ', recoveredFromError: true' : ''})';
}
