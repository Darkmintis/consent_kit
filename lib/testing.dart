/// Testing utilities for ConsentKit.
///
/// ```dart
/// import 'package:consent_kit/testing.dart';
///
/// test('my feature', () async {
///   final mock = MockConsentPlatform()
///     ..setCanRequestAds(true)
///     ..setCachedStatus(ConsentKitStatus.obtained);
///
///   await ConsentKit.initialize(platform: mock);
///   expect(ConsentKit.canRequestAds, isTrue);
/// });
/// ```
library;

export 'src/testing/mock_consent_platform.dart';
