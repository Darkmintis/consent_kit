import 'package:flutter/material.dart';

import '../../consent_kit.dart';

/// A privacy-options control that only appears when UMP requires it.
///
/// GDPR / UMP rules: if privacy options are required, the entry point must be
/// visible and interactable. This widget hides itself otherwise.
///
/// Listens to [ConsentKit.listenable], so it appears after background
/// [ConsentKit.bootstrap] finishes.
///
/// ```dart
/// AppBar(
///   actions: [
///     PrivacyOptionsButton(),
///   ],
/// )
/// ```
class PrivacyOptionsButton extends StatefulWidget {
  /// Optional custom builder. Receives `onPressed` when the button should show.
  final Widget Function(BuildContext context, VoidCallback onPressed)? builder;

  /// Icon used by the default [IconButton].
  final IconData icon;

  /// Tooltip for the default [IconButton].
  final String tooltip;

  /// Called after the privacy form is dismissed (even if unchanged).
  final VoidCallback? onChanged;

  /// When `true`, re-checks requirement after the form closes.
  final bool refreshAfterShow;

  const PrivacyOptionsButton({
    super.key,
    this.builder,
    this.icon = Icons.privacy_tip_outlined,
    this.tooltip = 'Privacy options',
    this.onChanged,
    this.refreshAfterShow = true,
  });

  @override
  State<PrivacyOptionsButton> createState() => _PrivacyOptionsButtonState();
}

class _PrivacyOptionsButtonState extends State<PrivacyOptionsButton> {
  bool _required = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    ConsentKit.listenable.addListener(_onConsentChanged);
    _refresh();
  }

  @override
  void dispose() {
    ConsentKit.listenable.removeListener(_onConsentChanged);
    super.dispose();
  }

  void _onConsentChanged() {
    _refresh();
  }

  Future<void> _refresh() async {
    if (!ConsentKit.isInitialized) {
      if (mounted) {
        setState(() {
          _required = false;
          _checking = false;
        });
      }
      return;
    }

    try {
      final required = await ConsentKit.isPrivacyOptionsRequired();
      if (!mounted) return;
      setState(() {
        _required = required;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _required = ConsentKit.privacyOptionsRequired;
        _checking = false;
      });
    }
  }

  Future<void> _onPressed() async {
    final shown = await ConsentKit.showPrivacyOptions();
    if (!mounted) return;
    if (shown) {
      widget.onChanged?.call();
      if (widget.refreshAfterShow) {
        await _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || !_required) {
      return const SizedBox.shrink();
    }

    if (widget.builder != null) {
      return widget.builder!(context, _onPressed);
    }

    return IconButton(
      tooltip: widget.tooltip,
      icon: Icon(widget.icon),
      onPressed: _onPressed,
    );
  }
}
