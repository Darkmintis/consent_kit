import 'package:consent_kit/consent_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ConsentKitDemo());
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
      home: const ConsentDemoPage(),
    );
  }
}

class ConsentDemoPage extends StatefulWidget {
  const ConsentDemoPage({super.key});

  @override
  State<ConsentDemoPage> createState() => _ConsentDemoPageState();
}

class _ConsentDemoPageState extends State<ConsentDemoPage> {
  final _testDeviceIdController = TextEditingController();
  Object? _error;
  bool _gathering = false;

  @override
  void initState() {
    super.initState();
    _gatherConsent();
  }

  @override
  void dispose() {
    _testDeviceIdController.dispose();
    super.dispose();
  }

  ConsentKitConfig _config() {
    final typedId = _testDeviceIdController.text.trim();
    return ConsentKitConfig(
      debugGeography: ConsentKitDebugGeography.eea,
      testDeviceIds: typedId.isEmpty ? null : [typedId],
      initializeMobileAds: true,
    );
  }

  Future<void> _gatherConsent() async {
    setState(() {
      _gathering = true;
      _error = null;
    });
    try {
      await ConsentKit.bootstrap(config: _config());
    } catch (error) {
      _error = error;
    }
    if (mounted) {
      setState(() => _gathering = false);
    }
  }

  Future<void> _resetAndShowFormAgain() async {
    setState(() {
      _gathering = true;
      _error = null;
    });
    try {
      if (ConsentKit.isInitialized) {
        await ConsentKit.resetConsent();
      }
      await ConsentKit.bootstrap(config: _config());
    } catch (error) {
      _error = error;
    }
    if (mounted) {
      setState(() => _gathering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ConsentKit.listenable,
      builder: (context, _) {
        final theme = Theme.of(context);
        final result = ConsentKit.lastResult;
        final statusLabel = _gathering
            ? 'gathering'
            : (result?.status.toString().split('.').last ?? 'idle');

        return Scaffold(
          appBar: AppBar(
            title: const Text('ConsentKit'),
            actions: const [PrivacyOptionsButton()],
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'UMP consent demo',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'On a real Android or iOS device the Google consent form '
                'should appear over this screen when geography is EEA. '
                'Run on Chrome/desktop and ads stay off.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Live status', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      if (_gathering) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 12),
                        const Text('Requesting UMP consent...'),
                        const SizedBox(height: 16),
                      ],
                      _statusRow('Phase', statusLabel),
                      const SizedBox(height: 8),
                      _statusRow(
                        'Can request ads',
                        ConsentKit.canRequestAds ? 'Yes' : 'No',
                      ),
                      const SizedBox(height: 8),
                      _statusRow(
                        'Privacy options required',
                        ConsentKit.privacyOptionsRequired ? 'Yes' : 'No',
                      ),
                      const SizedBox(height: 8),
                      _statusRow(
                        'Recovered from error',
                        result?.recoveredFromError == true ? 'Yes' : 'No',
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error.toString(),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Force the EEA form',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Look in logcat / Xcode for the hashed test device ID, '
                        'paste it here, then tap Reset and show form again.',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _testDeviceIdController,
                        decoration: const InputDecoration(
                          labelText: 'Test device ID',
                          hintText: 'from UMP debug logs',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AdGate(
                placeholder: const _AdPlaceholder(
                  message: 'Ad slot empty until UMP allows ads.',
                ),
                builder: (context) => const DemoBannerAd(),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _gathering ? null : _resetAndShowFormAgain,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset and show form again'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _gathering
                    ? null
                    : () async {
                        await ConsentKit.showPrivacyOptions();
                      },
                icon: const Icon(Icons.privacy_tip_outlined),
                label: const Text('Privacy options'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _AdPlaceholder extends StatelessWidget {
  const _AdPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 50,
        child: Center(child: Text(message, textAlign: TextAlign.center)),
      ),
    );
  }
}

class DemoBannerAd extends StatefulWidget {
  const DemoBannerAd({super.key});

  @override
  State<DemoBannerAd> createState() => _DemoBannerAdState();
}

class _DemoBannerAdState extends State<DemoBannerAd> {
  BannerAd? _bannerAd;
  bool _loadFailed = false;

  static String get _testBannerAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    return 'ca-app-pub-3940256099942544/6300978111';
  }

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    final bannerAd = BannerAd(
      adUnitId: _testBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _bannerAd = ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() => _loadFailed = true);
          }
        },
      ),
    );

    final startedLoad = await ConsentKit.guardAdLoad(bannerAd.load);
    if (!startedLoad) {
      bannerAd.dispose();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return const _AdPlaceholder(message: 'Test banner failed to load.');
    }
    final bannerAd = _bannerAd;
    if (bannerAd == null) {
      return const _AdPlaceholder(message: 'Loading test banner...');
    }
    return SizedBox(
      width: bannerAd.size.width.toDouble(),
      height: bannerAd.size.height.toDouble(),
      child: AdWidget(ad: bannerAd),
    );
  }
}
