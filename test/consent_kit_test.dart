import 'package:consent_kit/consent_kit.dart';
import 'package:consent_kit/src/stub_consent_platform.dart';
import 'package:consent_kit/testing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockConsentPlatform mock;

  setUp(() {
    ConsentKit.resetForTesting();
    mock = MockConsentPlatform();
  });

  tearDown(() {
    ConsentKit.resetForTesting();
  });

  group('ConsentKit.initialize()', () {
    test('is safe before init - ads stay off, no throws on reads', () {
      expect(ConsentKit.isInitialized, isFalse);
      expect(ConsentKit.lastResult, isNull);
      expect(ConsentKit.privacyOptionsRequired, isFalse);
      expect(ConsentKit.canRequestAds, isFalse);
      expect(ConsentKit.refreshCanRequestAds(), completion(isFalse));
      expect(ConsentKit.isPrivacyOptionsRequired(), completion(isFalse));
      expect(ConsentKit.showPrivacyOptions(), completion(isFalse));
      expect(ConsentKit.initializeMobileAds(), completion(isFalse));
      expect(ConsentKit.guardAdLoad(() {}), completion(isFalse));
      expect(
        ConsentKit.resetConsent(),
        throwsA(isA<ConsentKitNotInitializedException>()),
      );
      expectLater(
        ConsentKit.ready,
        throwsA(isA<ConsentKitNotInitializedException>()),
      );
    });

    test('returns full ConsentKitResult and sets state', () async {
      mock
        ..setCachedStatus(ConsentKitStatus.obtained)
        ..setCanRequestAds(true)
        ..setPrivacyOptionsRequired(true);

      final result = await ConsentKit.initialize(platform: mock);

      expect(result.status, ConsentKitStatus.obtained);
      expect(result.canRequestAds, isTrue);
      expect(result.isPrivacyOptionsRequired, isTrue);
      expect(result.recoveredFromError, isFalse);
      expect(result.error, isNull);
      expect(ConsentKit.isInitialized, isTrue);
      expect(ConsentKit.canRequestAds, isTrue);
      expect(ConsentKit.privacyOptionsRequired, isTrue);
      expect(ConsentKit.lastResult, same(result));
      expect(mock.requestInfoUpdateCallCount, 1);
      expect(mock.loadFormCallCount, 1);
    });

    test('runs Google flow: info update then form', () async {
      mock.setCanRequestAds(true);
      await ConsentKit.initialize(platform: mock);

      expect(mock.requestInfoUpdateCallCount, 1);
      expect(mock.loadFormCallCount, 1);
    });

    test('is idempotent — second call skips platform work', () async {
      mock.setCanRequestAds(true);
      final first = await ConsentKit.initialize(platform: mock);
      final second = await ConsentKit.initialize(platform: mock);

      expect(identical(first, second), isTrue);
      expect(mock.requestInfoUpdateCallCount, 1);
      expect(mock.loadFormCallCount, 1);
    });

    test('passes config timeouts and under-age tag to platform', () async {
      mock.setCanRequestAds(true);

      await ConsentKit.initialize(
        platform: mock,
        config: const ConsentKitConfig(
          tagForUnderAgeOfConsent: true,
          infoUpdateTimeout: Duration(seconds: 7),
          formTimeout: Duration(seconds: 21),
        ),
      );

      final call = mock.lastInfoUpdateCall!;
      expect(call.tagForUnderAgeOfConsent, isTrue);
      expect(call.timeout, const Duration(seconds: 7));
    });

    test('passes debug settings when running in debug mode', () async {
      mock.setCanRequestAds(true);

      await ConsentKit.initialize(
        platform: mock,
        config: const ConsentKitConfig(
          testDeviceIds: ['DEVICE-1', 'DEVICE-2'],
          debugGeography: ConsentKitDebugGeography.eea,
        ),
      );

      final call = mock.lastInfoUpdateCall!;
      // Unit tests run with kDebugMode == true.
      expect(kDebugMode, isTrue);
      expect(call.debugMode, isTrue);
      expect(call.testDeviceIds, ['DEVICE-1', 'DEVICE-2']);
      expect(call.debugGeography, ConsentKitDebugGeography.eea);
    });

    test('wraps non-ConsentKitException when ads cannot be requested', () async {
      mock
        ..setCanRequestAds(false)
        ..setShouldFailInfoUpdate(true);

      await expectLater(
        ConsentKit.initialize(platform: mock),
        throwsA(
          isA<ConsentKitException>().having(
            (e) => e.cause,
            'cause',
            isA<Exception>(),
          ),
        ),
      );
      expect(ConsentKit.isInitialized, isFalse);
      expect(ConsentKit.lastResult, isNull);
    });

    test('preserves ConsentKitException when ads cannot be requested', () async {
      final failing = _ThrowingConsentPlatform(
        error: const ConsentKitException('native boom'),
        canRequestAds: false,
      );

      await expectLater(
        ConsentKit.initialize(platform: failing),
        throwsA(
          isA<ConsentKitException>().having(
            (e) => e.message,
            'message',
            'native boom',
          ),
        ),
      );
    });

    test('recovers from info-update error when previous session allows ads',
        () async {
      mock
        ..setCanRequestAds(true)
        ..setCachedStatus(ConsentKitStatus.obtained)
        ..setShouldFailInfoUpdate(true);

      final result = await ConsentKit.initialize(platform: mock);

      expect(result.recoveredFromError, isTrue);
      expect(result.error, isNotNull);
      expect(result.canRequestAds, isTrue);
      expect(ConsentKit.isInitialized, isTrue);
    });

    test('recovers from form error when previous session allows ads', () async {
      mock
        ..setCanRequestAds(true)
        ..setCachedStatus(ConsentKitStatus.obtained)
        ..setShouldFailForm(true);

      final result = await ConsentKit.initialize(platform: mock);

      expect(result.recoveredFromError, isTrue);
      expect(result.canRequestAds, isTrue);
      expect(mock.loadFormCallCount, 1);
    });

    test('initializes Mobile Ads when configured and ads allowed', () async {
      mock.setCanRequestAds(true);

      await ConsentKit.initialize(
        platform: mock,
        config: const ConsentKitConfig(initializeMobileAds: true),
      );

      expect(mock.mobileAdsInitialized, isTrue);
      expect(mock.initializeMobileAdsCallCount, 1);
    });

    test('skips Mobile Ads when ads not allowed', () async {
      mock
        ..setCanRequestAds(false)
        ..setCachedStatus(ConsentKitStatus.required);

      await ConsentKit.initialize(
        platform: mock,
        config: const ConsentKitConfig(initializeMobileAds: true),
      );

      expect(mock.mobileAdsInitialized, isFalse);
    });

    test('does not fail initialize when Mobile Ads init throws', () async {
      mock
        ..setCanRequestAds(true)
        ..setShouldFailMobileAds(true);

      final result = await ConsentKit.initialize(
        platform: mock,
        config: const ConsentKitConfig(initializeMobileAds: true),
      );

      expect(result.canRequestAds, isTrue);
      expect(ConsentKit.isInitialized, isTrue);
      expect(mock.mobileAdsInitialized, isFalse);
    });

    test('works with default empty config', () async {
      mock.setCanRequestAds(true);
      final result = await ConsentKit.initialize(platform: mock);
      expect(result.canRequestAds, isTrue);
    });
  });

  group('ConsentKit.canRequestAds', () {
    test('mirrors UMP canRequestAds for all common cases', () async {
      for (final allowed in [true, false]) {
        ConsentKit.resetForTesting();
        mock = MockConsentPlatform()
          ..setCanRequestAds(allowed)
          ..setCachedStatus(
            allowed ? ConsentKitStatus.obtained : ConsentKitStatus.required,
          );
        await ConsentKit.initialize(platform: mock);
        expect(ConsentKit.canRequestAds, allowed);
      }
    });

    test('refreshCanRequestAds updates cached value', () async {
      mock.setCanRequestAds(true);
      await ConsentKit.initialize(platform: mock);
      mock.setCanRequestAds(false);

      expect(await ConsentKit.refreshCanRequestAds(), isFalse);
      expect(ConsentKit.canRequestAds, isFalse);
    });

    test('canRequestAds is false when cache is null after init edge case',
        () async {
      // Platform that leaves cachedCanRequestAds null but async returns true.
      final platform = _NullCacheAdsPlatform();
      await ConsentKit.initialize(platform: platform);
      // After _buildResult, cache should be populated via canRequestAds().
      expect(ConsentKit.canRequestAds, isTrue);
    });
  });

  group('ConsentKit.consentStatus', () {
    test('returns null before initialization', () async {
      expect(await ConsentKit.consentStatus, isNull);
    });

    test('returns each ConsentKitStatus value', () async {
      for (final status in ConsentKitStatus.values) {
        ConsentKit.resetForTesting();
        mock = MockConsentPlatform()
          ..setCachedStatus(status)
          ..setCanRequestAds(status != ConsentKitStatus.required);
        await ConsentKit.initialize(platform: mock);
        expect(await ConsentKit.consentStatus, status);
      }
    });

    test('returns null when platform getConsentStatus fails', () async {
      mock
        ..setCanRequestAds(true)
        ..setCachedStatus(ConsentKitStatus.obtained);
      await ConsentKit.initialize(platform: mock);
      mock.setShouldFailGetStatus(true);

      expect(await ConsentKit.consentStatus, isNull);
    });
  });

  group('ConsentKit privacy options', () {
    test('sync and async requirement stay in sync', () async {
      mock
        ..setCanRequestAds(true)
        ..setPrivacyOptionsRequired(true);
      await ConsentKit.initialize(platform: mock);

      expect(ConsentKit.privacyOptionsRequired, isTrue);
      expect(await ConsentKit.isPrivacyOptionsRequired(), isTrue);
    });

    test('showPrivacyOptions updates lastResult', () async {
      mock
        ..setCanRequestAds(true)
        ..setPrivacyOptionsRequired(true)
        ..setCachedStatus(ConsentKitStatus.obtained);
      await ConsentKit.initialize(platform: mock);

      mock
        ..setPrivacyOptionsRequired(false)
        ..setCachedStatus(ConsentKitStatus.notRequired);

      final shown = await ConsentKit.showPrivacyOptions();
      expect(shown, isTrue);
      expect(mock.showPrivacyOptionsCallCount, 1);
      expect(ConsentKit.lastResult?.status, ConsentKitStatus.notRequired);
      expect(ConsentKit.lastResult?.isPrivacyOptionsRequired, isFalse);
    });

    test('showPrivacyOptions returns false without updating when not shown',
        () async {
      mock.setCanRequestAds(true);
      final before = await ConsentKit.initialize(platform: mock);
      mock.setPrivacyOptionsResult(false);

      expect(await ConsentKit.showPrivacyOptions(), isFalse);
      expect(ConsentKit.lastResult, same(before));
    });
  });

  group('ConsentKit.initializeMobileAds()', () {
    test('initializes when ads allowed', () async {
      mock.setCanRequestAds(true);
      await ConsentKit.initialize(platform: mock);

      expect(await ConsentKit.initializeMobileAds(), isTrue);
      expect(mock.mobileAdsInitialized, isTrue);
    });

    test('returns false when ads not allowed', () async {
      mock
        ..setCanRequestAds(false)
        ..setCachedStatus(ConsentKitStatus.required);
      await ConsentKit.initialize(platform: mock);

      expect(await ConsentKit.initializeMobileAds(), isFalse);
      expect(mock.mobileAdsInitialized, isFalse);
    });
  });

  group('ConsentKit.resetConsent()', () {
    test('clears state and allows a fresh initialize', () async {
      mock
        ..setCanRequestAds(false)
        ..setCachedStatus(ConsentKitStatus.required);
      await ConsentKit.initialize(platform: mock);
      expect(ConsentKit.canRequestAds, isFalse);

      await ConsentKit.resetConsent();

      expect(mock.resetCallCount, 1);
      expect(ConsentKit.isInitialized, isFalse);
      expect(ConsentKit.lastResult, isNull);
      expect(ConsentKit.canRequestAds, isFalse);

      mock
        ..setCanRequestAds(true)
        ..setCachedStatus(ConsentKitStatus.obtained);
      await ConsentKit.initialize(platform: mock);
      expect(ConsentKit.canRequestAds, isTrue);
      expect(mock.requestInfoUpdateCallCount, 2);
    });
  });

  group('ConsentKitResult', () {
    test('toString includes core fields', () {
      const result = ConsentKitResult(
        status: ConsentKitStatus.obtained,
        canRequestAds: true,
        isPrivacyOptionsRequired: false,
      );
      expect(result.toString(), contains('obtained'));
      expect(result.toString(), contains('canRequestAds: true'));
    });

    test('toString marks recoveredFromError', () {
      const result = ConsentKitResult(
        status: ConsentKitStatus.obtained,
        canRequestAds: true,
        isPrivacyOptionsRequired: false,
        recoveredFromError: true,
      );
      expect(result.toString(), contains('recoveredFromError: true'));
    });
  });

  group('Exceptions', () {
    test('ConsentKitException formats with and without cause', () {
      const plain = ConsentKitException('oops');
      expect(plain.toString(), 'ConsentKitException: oops');

      final withCause = ConsentKitException('oops', cause: StateError('x'));
      expect(withCause.toString(), contains('caused by:'));
    });

    test('ConsentKitNotInitializedException has actionable message', () {
      final e = ConsentKitNotInitializedException();
      expect(e.message, contains('bootstrap()'));
      expect(e, isA<ConsentKitException>());
    });

    test('ConsentKitUnsupportedPlatformException mentions Android and iOS', () {
      final e = ConsentKitUnsupportedPlatformException();
      expect(e.message, contains('Android'));
      expect(e.message, contains('iOS'));
    });

    test('assertSupportedPlatform allows Android and iOS', () {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(ConsentKit.assertSupportedPlatform, returnsNormally);
      }
      debugDefaultTargetPlatformOverride = null;
    });

    test('assertSupportedPlatform throws on desktop platforms', () {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      for (final platform in [
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          ConsentKit.assertSupportedPlatform,
          throwsA(isA<ConsentKitUnsupportedPlatformException>()),
        );
      }
    });
  });

  group('ConsentKitConfig', () {
    test('defaults are production-safe', () {
      const config = ConsentKitConfig();
      expect(config.testDeviceIds, isNull);
      expect(config.debugGeography, isNull);
      expect(config.tagForUnderAgeOfConsent, isNull);
      expect(config.initializeMobileAds, isTrue);
      expect(config.infoUpdateTimeout, const Duration(seconds: 10));
      expect(config.formTimeout, const Duration(seconds: 30));
    });
  });

  group('ConsentGate', () {
    testWidgets('builds app when consent already initialized', (tester) async {
      mock.setCanRequestAds(true);
      await ConsentKit.initialize(platform: mock);

      await tester.pumpWidget(
        ConsentGate(
          builder: (context) => const MaterialApp(home: Text('ready')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ready'), findsOneWidget);
      expect(ConsentKit.isInitialized, isTrue);
    });

    testWidgets('calls onReady with result', (tester) async {
      mock.setCanRequestAds(true);
      await ConsentKit.initialize(platform: mock);
      ConsentKitResult? ready;

      await tester.pumpWidget(
        ConsentGate(
          onReady: (r) => ready = r,
          builder: (context) => const MaterialApp(home: Text('ready')),
        ),
      );
      await tester.pumpAndSettle();

      expect(ready, isNotNull);
      expect(ready!.canRequestAds, isTrue);
    });

    testWidgets('shows loading then app', (tester) async {
      mock.setCanRequestAds(true);
      await ConsentKit.initialize(platform: mock);

      await tester.pumpWidget(
        ConsentGate(
          waitForConsent: true,
          loading: const MaterialApp(home: Text('loading')),
          builder: (context) => const MaterialApp(home: Text('ready')),
        ),
      );

      // First frame may still be loading before the microtask completes.
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('ready'), findsOneWidget);
    });
  });

  group('PrivacyOptionsButton', () {
    testWidgets('hides when privacy options not required', (tester) async {
      mock
        ..setCanRequestAds(true)
        ..setPrivacyOptionsRequired(false);
      await ConsentKit.initialize(platform: mock);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PrivacyOptionsButton()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('shows when privacy options required', (tester) async {
      mock
        ..setCanRequestAds(true)
        ..setPrivacyOptionsRequired(true);
      await ConsentKit.initialize(platform: mock);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PrivacyOptionsButton()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('uses custom builder and invokes onChanged', (tester) async {
      mock
        ..setCanRequestAds(true)
        ..setPrivacyOptionsRequired(true);
      await ConsentKit.initialize(platform: mock);

      var changed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivacyOptionsButton(
              onChanged: () => changed++,
              builder: (context, onPressed) => TextButton(
                onPressed: onPressed,
                child: const Text('Manage privacy'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage privacy'));
      await tester.pumpAndSettle();

      expect(mock.showPrivacyOptionsCallCount, 1);
      expect(changed, 1);
    });

    testWidgets('hides before ConsentKit is initialized', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PrivacyOptionsButton()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('appears after delayed bootstrap when required', (tester) async {
      final delayed = _DelayedConsentPlatform(
        delay: const Duration(milliseconds: 20),
      )
        ..setCanRequestAds(true)
        ..setPrivacyOptionsRequired(true);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PrivacyOptionsButton()),
        ),
      );
      await tester.pump();
      expect(find.byType(IconButton), findsNothing);

      final gather = ConsentKit.bootstrap(platform: delayed);
      await tester.pump(const Duration(milliseconds: 30));
      await gather;
      await tester.pump();

      expect(find.byType(IconButton), findsOneWidget);
    });
  });

  group('AdGate', () {
    testWidgets('hides ads until consent allows them', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdGate(
            placeholder: const Text('no-ads'),
            builder: (context) => const Text('ads'),
          ),
        ),
      );
      expect(find.text('no-ads'), findsOneWidget);
      expect(find.text('ads'), findsNothing);

      mock
        ..setCanRequestAds(true)
        ..setCachedStatus(ConsentKitStatus.obtained);
      await ConsentKit.bootstrap(platform: mock);
      await tester.pump();

      expect(find.text('ads'), findsOneWidget);
      expect(find.text('no-ads'), findsNothing);
    });
  });

  group('ConsentKit.bootstrap / guardAdLoad / listenable', () {
    test('bootstrap is initialize', () async {
      mock.setCanRequestAds(true);
      final result = await ConsentKit.bootstrap(platform: mock);
      expect(result.canRequestAds, isTrue);
      expect(ConsentKit.isInitialized, isTrue);
      expect(await ConsentKit.ready, same(result));
    });

    test('concurrent initialize shares one gather', () async {
      mock.setCanRequestAds(true);
      final first = ConsentKit.initialize(platform: mock);
      final second = ConsentKit.initialize(platform: mock);
      final results = await Future.wait([first, second]);
      expect(identical(results[0], results[1]), isTrue);
      expect(mock.requestInfoUpdateCallCount, 1);
    });

    test('guardAdLoad runs load only when ads allowed', () async {
      mock
        ..setCanRequestAds(false)
        ..setCachedStatus(ConsentKitStatus.required);
      await ConsentKit.initialize(platform: mock);

      var loads = 0;
      expect(await ConsentKit.guardAdLoad(() => loads++), isFalse);
      expect(loads, 0);

      ConsentKit.resetForTesting();
      mock = MockConsentPlatform()
        ..setCanRequestAds(true)
        ..setCachedStatus(ConsentKitStatus.obtained);
      await ConsentKit.initialize(platform: mock);
      expect(await ConsentKit.guardAdLoad(() => loads++), isTrue);
      expect(loads, 1);
    });

    test('guardAdLoad waits for in-flight bootstrap', () async {
      final delayed = _DelayedConsentPlatform(
        delay: const Duration(milliseconds: 20),
      )..setCanRequestAds(true);

      var loads = 0;
      final gather = ConsentKit.bootstrap(platform: delayed);
      final guarded = ConsentKit.guardAdLoad(() => loads++);
      await gather;
      expect(await guarded, isTrue);
      expect(loads, 1);
    });

    test('listenable updates after initialize', () async {
      mock.setCanRequestAds(true);
      expect(ConsentKit.listenable.value, isNull);
      await ConsentKit.initialize(platform: mock);
      expect(ConsentKit.listenable.value?.canRequestAds, isTrue);
    });

    test('stub platform leaves ads off and does not throw', () async {
      final result = await ConsentKit.initialize(
        platform: StubConsentPlatform(),
      );
      expect(result.canRequestAds, isFalse);
      expect(ConsentKit.canRequestAds, isFalse);
      expect(await ConsentKit.guardAdLoad(() {}), isFalse);
    });

    test('default config initializes Mobile Ads when ads allowed', () async {
      mock.setCanRequestAds(true);
      await ConsentKit.initialize(platform: mock);
      expect(mock.mobileAdsInitialized, isTrue);
    });
  });

  group('ConsentGate non-blocking', () {
    testWidgets('shows app before consent finishes', (tester) async {
      final delayed = _DelayedConsentPlatform(
        delay: const Duration(milliseconds: 40),
      )..setCanRequestAds(true);

      await tester.pumpWidget(
        ConsentGate(
          platform: delayed,
          builder: (context) => const MaterialApp(home: Text('app')),
        ),
      );

      expect(find.text('app'), findsOneWidget);
      expect(ConsentKit.isInitialized, isFalse);

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.text('app'), findsOneWidget);
      expect(ConsentKit.isInitialized, isTrue);
    });
  });
}

/// Platform that throws a ConsentKitException on info update.
class _ThrowingConsentPlatform implements ConsentPlatform {
  _ThrowingConsentPlatform({
    required this.error,
    required bool canRequestAds,
  }) : _adsAllowed = canRequestAds;

  final ConsentKitException error;
  final bool _adsAllowed;

  @override
  ConsentKitStatus? get cachedStatus => ConsentKitStatus.unknown;

  @override
  bool? get cachedCanRequestAds => _adsAllowed;

  @override
  bool? get cachedPrivacyOptionsRequired => false;

  @override
  Future<void> requestConsentInfoUpdate({
    required bool debugMode,
    List<String>? testDeviceIds,
    ConsentKitDebugGeography? debugGeography,
    bool? tagForUnderAgeOfConsent,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    throw error;
  }

  @override
  Future<void> loadAndShowConsentFormIfRequired({
    Duration timeout = const Duration(seconds: 30),
  }) async {}

  @override
  Future<ConsentKitStatus> getConsentStatus() async => ConsentKitStatus.unknown;

  @override
  Future<bool> canRequestAds() async => _adsAllowed;

  @override
  Future<bool> isPrivacyOptionsRequired() async => false;

  @override
  Future<bool> isConsentFormAvailable() async => false;

  @override
  Future<bool> showPrivacyOptionsForm() async => false;

  @override
  Future<void> resetConsent() async {}

  @override
  Future<void> initializeMobileAds() async {}
}

/// Platform with null sync cache until async canRequestAds is called.
class _NullCacheAdsPlatform implements ConsentPlatform {
  bool? _cached;

  @override
  ConsentKitStatus? get cachedStatus => ConsentKitStatus.notRequired;

  @override
  bool? get cachedCanRequestAds => _cached;

  @override
  bool? get cachedPrivacyOptionsRequired => false;

  @override
  Future<void> requestConsentInfoUpdate({
    required bool debugMode,
    List<String>? testDeviceIds,
    ConsentKitDebugGeography? debugGeography,
    bool? tagForUnderAgeOfConsent,
    Duration timeout = const Duration(seconds: 10),
  }) async {}

  @override
  Future<void> loadAndShowConsentFormIfRequired({
    Duration timeout = const Duration(seconds: 30),
  }) async {}

  @override
  Future<ConsentKitStatus> getConsentStatus() async =>
      ConsentKitStatus.notRequired;

  @override
  Future<bool> canRequestAds() async {
    _cached = true;
    return true;
  }

  @override
  Future<bool> isPrivacyOptionsRequired() async => false;

  @override
  Future<bool> isConsentFormAvailable() async => false;

  @override
  Future<bool> showPrivacyOptionsForm() async => false;

  @override
  Future<void> resetConsent() async {}

  @override
  Future<void> initializeMobileAds() async {}
}

class _DelayedConsentPlatform extends MockConsentPlatform {
  _DelayedConsentPlatform({required this.delay});

  final Duration delay;

  @override
  Future<void> requestConsentInfoUpdate({
    required bool debugMode,
    List<String>? testDeviceIds,
    ConsentKitDebugGeography? debugGeography,
    bool? tagForUnderAgeOfConsent,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await Future<void>.delayed(delay);
    await super.requestConsentInfoUpdate(
      debugMode: debugMode,
      testDeviceIds: testDeviceIds,
      debugGeography: debugGeography,
      tagForUnderAgeOfConsent: tagForUnderAgeOfConsent,
      timeout: timeout,
    );
  }
}
