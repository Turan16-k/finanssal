import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'providers.dart';
import 'widgets.dart';

/// Biyometrik kilit: etkinse uygulama açılışta ve arka plandan dönüşte kilitlenir.
class AppLock extends ConsumerStatefulWidget {
  const AppLock({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppLock> createState() => _AppLockState();
}

class _AppLockState extends ConsumerState<AppLock> with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  late bool _locked = ref.read(settingsProvider).biometricLock;
  bool _authenticating = false;
  DateTime? _pausedAt;

  /// Kısa uygulama geçişlerinde (ör. fotoğraf seçici) tekrar sorulmasın.
  static const _grace = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!ref.read(settingsProvider).biometricLock || _authenticating) return;
    if (state == AppLifecycleState.paused) _pausedAt = DateTime.now();
    if (state == AppLifecycleState.resumed && _pausedAt != null &&
        DateTime.now().difference(_pausedAt!) > _grace) {
      setState(() => _locked = true);
      _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    _authenticating = true;
    try {
      final ok = await _auth.authenticate(
        localizedReason: context.l10n.biometricReason,
        persistAcrossBackgrounding: true,
      );
      if (ok && mounted) setState(() => _locked = false);
    } catch (_) {
      // Cihazda biyometri/şifre yoksa kilidi kaldır (kullanıcıyı dışarıda bırakma).
      final supported = await _auth.isDeviceSupported();
      if (!supported && mounted) setState(() => _locked = false);
    } finally {
      _authenticating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;
    return Stack(children: [
      widget.child,
      Positioned.fill(
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _unlock,
                icon: const Icon(Icons.fingerprint),
                label: Text(context.l10n.unlock),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}
