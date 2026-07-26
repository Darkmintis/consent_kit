import 'package:flutter/material.dart';

import '../../consent_kit.dart';

/// Boots consent, then builds your app — the easiest ConsentKit integration.
///
/// ```dart
/// void main() {
///   WidgetsFlutterBinding.ensureInitialized();
///   runApp(
///     ConsentGate(
///       config: ConsentKitConfig(
///         testDeviceIds: ['YOUR_TEST_DEVICE_ID'],
///         debugGeography: ConsentKitDebugGeography.eea,
///         initializeMobileAds: true,
///       ),
///       builder: (context) => const MyApp(),
///     ),
///   );
/// }
/// ```
class ConsentGate extends StatefulWidget {
  /// Builds the real app once consent initialization finishes.
  final WidgetBuilder builder;

  /// Optional ConsentKit configuration.
  final ConsentKitConfig? config;

  /// Shown while consent is initializing. Defaults to a centered spinner.
  final Widget? loading;

  /// Shown when consent fails and ads cannot be requested.
  ///
  /// Defaults to a simple error message with a retry button.
  final Widget Function(BuildContext context, Object error, VoidCallback retry)?
      errorBuilder;

  /// Called after a successful initialize (including soft recovery).
  final void Function(ConsentKitResult result)? onReady;

  const ConsentGate({
    super.key,
    required this.builder,
    this.config,
    this.loading,
    this.errorBuilder,
    this.onReady,
  });

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

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
      _ready = false;
    });

    try {
      final result = await ConsentKit.initialize(config: widget.config);
      if (!mounted) return;
      widget.onReady?.call(result);
      setState(() {
        _ready = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.loading ??
          const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
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
      return widget.builder(context);
    }

    return const SizedBox.shrink();
  }
}
