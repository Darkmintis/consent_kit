import 'package:flutter/material.dart';
import 'package:consent_kit/consent_kit.dart';

const _config = ConsentKitConfig(
  testDeviceIds: ['YOUR_TEST_DEVICE_ID'],
  debugGeography: ConsentKitDebugGeography.eea,
  initializeMobileAds: false,
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ConsentGate(
      config: _config,
      builder: (context) => const ConsentKitDemo(),
    ),
  );
}

class ConsentKitDemo extends StatelessWidget {
  const ConsentKitDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ConsentKit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0B6E4F),
        useMaterial3: true,
      ),
      home: const ConsentDemo(),
    );
  }
}

class ConsentDemo extends StatefulWidget {
  const ConsentDemo({super.key});

  @override
  State<ConsentDemo> createState() => _ConsentDemoState();
}

class _ConsentDemoState extends State<ConsentDemo> {
  ConsentKitResult? _result;

  @override
  void initState() {
    super.initState();
    _result = ConsentKit.lastResult;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ConsentKit'),
        actions: const [PrivacyOptionsButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Consent Status',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    _buildRow('Can request ads',
                        _result?.canRequestAds == true ? 'Yes' : 'No'),
                    const SizedBox(height: 8),
                    _buildRow('Privacy options required',
                        _result?.isPrivacyOptionsRequired == true ? 'Yes' : 'No'),
                    const SizedBox(height: 8),
                    _buildRow('Status', _result?.status.toString().split('.').last ?? 'unknown'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                await ConsentKit.showPrivacyOptions();
              },
              icon: const Icon(Icons.privacy_tip_outlined),
              label: const Text('Privacy Options'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
