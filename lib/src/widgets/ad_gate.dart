import 'package:flutter/material.dart';

import '../../consent_kit.dart';

/// Builds [builder] only when UMP allows ad requests.
///
/// Rebuilds automatically when [ConsentKit.listenable] updates. Use this
/// around banners or other ad widgets so they never load without consent.
///
/// ```dart
/// AdGate(
///   builder: (context) => const MyBannerAd(),
/// )
/// ```
class AdGate extends StatelessWidget {
  /// Built when [ConsentKit.canRequestAds] is true.
  final WidgetBuilder builder;

  /// Shown while ads are not allowed. Defaults to an empty box.
  final Widget? placeholder;

  const AdGate({
    super.key,
    required this.builder,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ConsentKit.listenable,
      builder: (context, _) {
        if (!ConsentKit.canRequestAds) {
          return placeholder ?? const SizedBox.shrink();
        }
        return builder(context);
      },
    );
  }
}
