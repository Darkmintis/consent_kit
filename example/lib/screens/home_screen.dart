import 'package:flutter/material.dart';

import 'package:consent_kit/consent_kit.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ConsentKitStatus? _status;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initConsent();
  }

  Future<void> _initConsent() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ConsentKit.initialize(
        config: ConsentKitConfig(
          // In debug mode, these are automatically applied.
          // In release builds, they are silently ignored.
          testDeviceIds: ['YOUR_TEST_DEVICE_ID'],
          debugGeography: ConsentKitDebugGeography.eea,
        ),
      );

      final status = await ConsentKit.consentStatus;
      setState(() {
        _status = status;
        _loading = false;
      });
    } on ConsentKitException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ConsentKit Demo'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_loading)
                const CircularProgressIndicator()
              else if (_error != null)
                _ErrorCard(message: _error!)
              else ...[
                _StatusCard(status: _status),
                const SizedBox(height: 16),
                _InfoRow(
                  label: 'Can request ads',
                  value: ConsentKit.canRequestAds ? 'Yes' : 'No',
                  valueColor: ConsentKit.canRequestAds
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _showPrivacyOptions,
                  icon: const Icon(Icons.privacy_tip),
                  label: const Text('Privacy Options'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _resetConsent,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset Consent'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPrivacyOptions() async {
    final shown = await ConsentKit.showPrivacyOptions();
    if (shown && mounted) {
      final status = await ConsentKit.consentStatus;
      setState(() => _status = status);
    }
  }

  Future<void> _resetConsent() async {
    try {
      await ConsentKit.resetConsent();
      await _initConsent();
    } on ConsentKitException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }
}

class _StatusCard extends StatelessWidget {
  final ConsentKitStatus? status;

  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (status) {
      ConsentKitStatus.obtained => ('Consent Obtained', Icons.check_circle, Colors.green),
      ConsentKitStatus.notRequired => ('Consent Not Required', Icons.info, Colors.blue),
      ConsentKitStatus.required => ('Consent Required', Icons.warning, Colors.orange),
      ConsentKitStatus.unknown => ('Status Unknown', Icons.help, Colors.grey),
      null => ('No Status', Icons.hourglass_empty, Colors.grey),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(width: 12),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
