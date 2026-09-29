import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../../data/account_repository.dart';

/// Bülten metnini sunucudaki Gemini fonksiyonuyla analiz eder; skor simülasyon
/// drift'ine uygulanabilir.
class BulletinCard extends ConsumerStatefulWidget {
  const BulletinCard({
    super.key,
    required this.sentiment,
    required this.applied,
    required this.onResult,
    required this.onToggle,
  });

  final double sentiment;
  final bool applied;
  final ValueChanged<double> onResult;
  final ValueChanged<bool> onToggle;

  @override
  ConsumerState<BulletinCard> createState() => _BulletinCardState();
}

class _BulletinCardState extends ConsumerState<BulletinCard> {
  final _ctrl = TextEditingController();
  BulletinAnalysis? _analysis;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      String? appCheck;
      if (ref.read(firebaseReadyProvider)) {
        appCheck = await FirebaseAppCheck.instance.getToken().catchError((_) => null);
      }
      final a = await ref.read(accountRepositoryProvider)!.analyzeBulletin(_ctrl.text, appCheckToken: appCheck);
      setState(() => _analysis = a);
      widget.onResult(a.sentiment);
    } on FunctionException catch (e) {
      if (mounted) showSnack(context, e.status == 429 ? l.quotaExceeded : l.errorGeneric);
    } catch (_) {
      if (mounted) showSnack(context, l.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = _analysis;
    return ExpansionTile(
      title: Text(l.bulletinTitle),
      subtitle: widget.applied
          ? Text('${l.sentiment}: ${Fmt.of(context).number(widget.sentiment)}')
          : null,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        TextField(
          controller: _ctrl,
          minLines: 3,
          maxLines: 8,
          maxLength: 8000,
          decoration: InputDecoration(hintText: l.bulletinHint),
        ),
        Text(l.aiNotice, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            onPressed: _busy ? null : _analyze,
            child: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l.analyze),
          ),
        ),
        if (a != null) ...[
          const SizedBox(height: 8),
          Text('${l.sentiment}: ${a.label} (${Fmt.of(context).number(a.sentiment)})',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(a.summary),
          for (final p in a.keyPoints) Text('• $p'),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.useSentiment),
          value: widget.applied,
          onChanged: widget.onToggle,
        ),
      ],
    );
  }
}
