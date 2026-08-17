import 'package:flutter/material.dart';

import '../../consent_kit.dart';

/// Boots consent in the background and builds your app immediately.
///
/// Matches Google's sample: the UI starts now, UMP may show a native form,
/// and ads stay off until [ConsentKit.canRequestAds] is true.
///
/// ```dart
/// void main() {
///   WidgetsFlutterBinding.ensureInitialized();
///   runApp(
///     ConsentGate(
///       config: ConsentKitConfig(
///         testDeviceIds: ['YOUR_TEST_DEVICE_ID'],
///         debugGeography: ConsentKitDebugGeography.eea,
///       ),
///       child: const MyApp(),
///     ),
///   );
/// }
/// ```
///
/// Set [waitForConsent] to `true` only if you want a loading screen before
/// the app (not recommended - it delays first paint).
class ConsentGate extends StatefulWidget {
  /// The app to show. Prefer this over [builder].
  final Widget? child;

  /// Builds the real app. Ignored when [child] is set.
  final WidgetBuilder? builder;

  /// Optional ConsentKit configuration.
  final ConsentKitConfig? config;

  /// When `true`, holds [child] until consent finishes.
  ///
  /// Defaults to `false` (Google's recommended model).
  final bool waitForConsent;

  /// Shown while consent is initializing when [waitForConsent] is `true`.
  ///
  /// Must include its own [Directionality] (or a [MaterialApp]) if you pass a
  /// custom widget. The default is a centered spinner.
  final Widget? loading;

  /// Shown when [waitForConsent] is `true` and gathering fails.
  final Widget Function(BuildContext context, Object error, VoidCallback retry)?
      errorBuilder;

  /// Called after initialize finishes (including soft recovery).
  final void Function(ConsentKitResult result)? onReady;

  /// Called when gathering fails and ads cannot be requested.
  ///
  /// When [waitForConsent] is `false`, the app still shows; ads stay off.
  final void Function(Object error)? onError;

  /// Test-only platform override. Do not pass this in production.
  final ConsentPlatform? platform;

  const ConsentGate({
    super.key,
    this.child,
    this.builder,
    this.config,
    this.waitForConsent = false,
    this.loading,
    this.errorBuilder,
    this.onReady,
    this.onError,
    this.platform,
  }) : assert(
          child != null || builder != null,
          'ConsentGate requires child or builder.',
        );

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  Object? _error;
  bool _ready = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Widget _app(BuildContext context) {
    return widget.child ?? widget.builder!(context);
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
      _ready = false;
    });

    try {
      final result = await ConsentKit.bootstrap(
        config: widget.config,
        platform: widget.platform,
      );
      if (!mounted) return;
      widget.onReady?.call(result);
      setState(() {
        _ready = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      widget.onError?.call(e);
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.waitForConsent) {
      return _app(context);
    }

    if (_loading) {
      return widget.loading ??
          const Directionality(
            textDirection: TextDirection.ltr,
            child: ColoredBox(
              color: Color(0xFFF7F7F7),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
    }

    if (_error != null) {
      final retry = _bootstrap;
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _error!, retry);
      }
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _error.toString(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: retry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_ready) {
      return _app(context);
    }

    return const SizedBox.shrink();
  }
}
