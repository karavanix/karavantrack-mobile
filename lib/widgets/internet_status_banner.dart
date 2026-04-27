import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../store/app_store.dart';

/// Telegram-style connectivity banner.
///
/// States:
///  • **Offline**  → amber bar, animated "Connecting..." dots, stays visible.
///  • **Just online** → green bar "Online ✓", auto-hides after 2 s.
///  • **Settled online** → zero-height, invisible.
///
/// Also calls [AppStore.setNetworkOnline] on every change to flush the
/// offline location buffer.
class InternetStatusBanner extends StatefulWidget {
  const InternetStatusBanner({super.key, required this.store});

  final AppStore store;

  @override
  State<InternetStatusBanner> createState() => _InternetStatusBannerState();
}

enum _BannerState { hidden, connecting, online }

class _InternetStatusBannerState extends State<InternetStatusBanner>
    with TickerProviderStateMixin {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  _BannerState _banner = _BannerState.hidden;
  bool _initialized = false;
  Timer? _hideTimer;

  // Slide animation
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  // Dot-pulse animation (for "Connecting…")
  late AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    // Seed initial state
    _connectivity.checkConnectivity().then((results) {
      if (!mounted) return;
      _apply(results, force: true);
    });

    _sub = _connectivity.onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results, {bool force = false}) {
    final isOnline = results.any((r) => r != ConnectivityResult.none);

    if (!_initialized || isOnline != (_banner != _BannerState.connecting)) {
      _initialized = true;
      widget.store.setNetworkOnline(isOnline);

      if (!isOnline) {
        _showConnecting();
      } else {
        _showOnline();
      }
    }
  }

  void _showConnecting() {
    _hideTimer?.cancel();
    setState(() => _banner = _BannerState.connecting);
    _slideCtrl.forward();
  }

  void _showOnline() {
    _hideTimer?.cancel();
    setState(() => _banner = _BannerState.online);
    _slideCtrl.forward();

    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _slideCtrl.reverse().then((_) {
        if (mounted) setState(() => _banner = _BannerState.hidden);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hideTimer?.cancel();
    _slideCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_banner == _BannerState.hidden) return const SizedBox.shrink();

    final isConnecting = _banner == _BannerState.connecting;

    final bgColor = isConnecting
        ? const Color.fromARGB(255, 18, 144, 248) // blue (connecting)
        : const Color(0xFF2ECC71); // green (connected)

    return SlideTransition(
      position: _slideAnim,
      child: Material(
        color: bgColor,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 34,
            child: Center(
              child: isConnecting
                  ? _ConnectingLabel(dotCtrl: _dotCtrl)
                  : const _OnlineLabel(),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── "Connecting…" with animated dots ───────────────────────────────────────

class _ConnectingLabel extends StatelessWidget {
  const _ConnectingLabel({required this.dotCtrl});
  final AnimationController dotCtrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
        const SizedBox(width: 6),
        const Text(
          'Connecting',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        _AnimatedDots(controller: dotCtrl),
      ],
    );
  }
}

class _AnimatedDots extends AnimatedWidget {
  const _AnimatedDots({required AnimationController controller})
      : super(listenable: controller);

  @override
  Widget build(BuildContext context) {
    final value = (listenable as AnimationController).value; // 0.0 → 1.0
    final step = (value * 3).floor(); // 0, 1, or 2
    final dots = '.' * (step + 1); // ".", "..", "..."
    return SizedBox(
      width: 20,
      child: Text(
        dots,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── "Online ✓" label ───────────────────────────────────────────────────────

class _OnlineLabel extends StatelessWidget {
  const _OnlineLabel();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi_rounded, color: Colors.white, size: 14),
        SizedBox(width: 6),
        Text(
          'Online',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(width: 4),
        Icon(Icons.check_rounded, color: Colors.white, size: 13),
      ],
    );
  }
}
