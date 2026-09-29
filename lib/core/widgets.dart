import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'format.dart';
import 'theme.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// AsyncValue için standart yükleniyor / hata / veri görünümü.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
        data: data,
        loading: () => const Center(child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        )),
        error: (e, _) => ErrorView(error: e, onRetry: onRetry),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(context.l10n.errorGeneric, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: Text(context.l10n.retry)),
            ],
          ]),
        ),
      );
}

/// Yüzde değişim etiketi: renk + ok ikonu (yalnızca renge güvenmez).
class ChangeChip extends StatelessWidget {
  const ChangeChip({super.key, required this.ratio, this.dense = false});
  final double ratio;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = changeColor(context, ratio);
    final icon = ratio > 0
        ? Icons.arrow_drop_up
        : ratio < 0
            ? Icons.arrow_drop_down
            : Icons.remove;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: dense ? 18 : 22),
      Text(Fmt.of(context).pct(ratio.abs(), decimals: 2),
          style: tabular.copyWith(color: color, fontWeight: FontWeight.w600)),
    ]);
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value, this.valueColor, this.hint});
  final String label;
  final String value;
  final Color? valueColor;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: t.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: t.titleMedium?.merge(tabular).copyWith(
                    color: valueColor, fontWeight: FontWeight.w700)),
          ),
          if (hint != null) Text(hint!, style: t.bodySmall),
        ]),
      ),
    );
  }
}

/// İki sütunlu metrik ızgarası (dar ekranlarda da taşmaz).
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 600 ? 4 : 2;
        final w = (c.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final child in children) SizedBox(width: w, child: child),
        ]);
      });
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
        child: Row(children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          ?trailing,
        ]),
      );
}

/// "Yatırım tavsiyesi değildir" + kaynak ibaresi.
class DisclaimerNote extends StatelessWidget {
  const DisclaimerNote({super.key, this.text});
  final String? text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text ?? context.l10n.disclaimerShort,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ]),
      );
}

Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, String? confirmLabel, bool destructive = false}) async {
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel ?? l.confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void showSnack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
