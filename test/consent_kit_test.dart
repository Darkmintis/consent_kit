import 'package:consent_kit/consent_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_consent_platform.dart';

void main() {
  late MockConsentPlatform mock;

  setUp(() async {
    ConsentKit.resetForTesting();
    mock = MockConsentPlatform();
  });

  tearDown(() async {
    ConsentKit.resetForTesting();
  });

  group('ConsentKit.initialize()', () {
    test('throws ConsentKitNotInitializedException when used before init',
        () {
      expect(
        () => ConsentKit.canRequestAds,
        throwsA(isA<ConsentKitNotInitializedException>()),
      );
    });

    test('succeeds and makes canRequestAds accessible', () async {
      await ConsentKit.initialize(platform: mock);

      expect(ConsentKit.canRequestAds, isTrue);
    });

    test('is idempotent — second call is a no-op', () async {
      await ConsentKit.initialize(platform: mock);
      await ConsentKit.initialize(platform: mock);

      expect(ConsentKit.canRequestAds, isTrue);
    });

    test('wraps non-ConsentKitException into ConsentKitException', () async {
      mock.setShouldFail(true);

      await expectLater(
        ConsentKit.initialize(platform: mock),
        throwsA(isA<ConsentKitException>()),
      );
    });

    test('preserves ConsentKitException from platform', () async {
      mock.setCachedStatus(ConsentKitStatus.required);
      mock.setShouldFail(true);

      await expectLater(
        ConsentKit.initialize(platform: mock),
        throwsA(isA<ConsentKitException>()),
      );
    });
  });

  group('ConsentKit.canRequestAds', () {
    test('returns true when consent obtained', () async {
      mock.setCachedStatus(ConsentKitStatus.obtained);
      await ConsentKit.initialize(platform: mock);

      expect(ConsentKit.canRequestAds, isTrue);
    });

    test('returns true when consent not required', () async {
      mock.setCachedStatus(ConsentKitStatus.notRequired);
      await ConsentKit.initialize(platform: mock);

      expect(ConsentKit.canRequestAds, isTrue);
    });

    test('returns true when status unknown', () async {
      mock.setCachedStatus(ConsentKitStatus.unknown);
      await ConsentKit.initialize(platform: mock);

      expect(ConsentKit.canRequestAds, isTrue);
    });

    test('returns false when consent is required but not obtained', () async {
      mock.setCachedStatus(ConsentKitStatus.required);
      await ConsentKit.initialize(platform: mock);

      expect(ConsentKit.canRequestAds, isFalse);
    });

    test('returns true when cachedStatus is null (graceful degradation)',
        () async {
      await ConsentKit.initialize(platform: mock);

      expect(ConsentKit.canRequestAds, isTrue);
    });
  });

  group('ConsentKit.consentStatus', () {
    test('returns null before initialization', () async {
      final status = await ConsentKit.consentStatus;

      expect(status, isNull);
    });

    test('returns status after initialization', () async {
      mock.setCachedStatus(ConsentKitStatus.obtained);
      await ConsentKit.initialize(platform: mock);

      final status = await ConsentKit.consentStatus;

      expect(status, equals(ConsentKitStatus.obtained));
    });

    test('returns null on error', () async {
      await ConsentKit.initialize(platform: mock);
      mock.setShouldFail(true);

      final status = await ConsentKit.consentStatus;

      expect(status, isNull);
    });
  });

  group('ConsentKit.showPrivacyOptions()', () {
    test('returns true when form presented successfully', () async {
      await ConsentKit.initialize(platform: mock);

      final result = await ConsentKit.showPrivacyOptions();

      expect(result, isTrue);
    });

    test('returns false when form presentation fails', () async {
      mock.setPrivacyOptionsResult(false);
      await ConsentKit.initialize(platform: mock);

      final result = await ConsentKit.showPrivacyOptions();

      expect(result, isFalse);
    });

    test('throws when called before initialization', () async {
      expect(
        ConsentKit.showPrivacyOptions(),
        throwsA(isA<ConsentKitNotInitializedException>()),
      );
    });
  });

  group('ConsentKit.resetConsent()', () {
    test('resets state and allows re-initialization', () async {
      mock.setCachedStatus(ConsentKitStatus.required);
      await ConsentKit.initialize(platform: mock);
      expect(ConsentKit.canRequestAds, isFalse);

      await ConsentKit.resetConsent();

      expect(
        () => ConsentKit.canRequestAds,
        throwsA(isA<ConsentKitNotInitializedException>()),
      );

      mock.setCachedStatus(ConsentKitStatus.obtained);
      await ConsentKit.initialize(platform: mock);
      expect(ConsentKit.canRequestAds, isTrue);
    });
  });
}
