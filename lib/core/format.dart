import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Yerel ayara duyarlı sayı/para/yüzde biçimlendirme (tr: 1.234,56 ₺).
class Fmt {
  Fmt(Locale locale) : _tag = locale.toLanguageTag();

  factory Fmt.of(BuildContext context) => Fmt(Localizations.localeOf(context));

  final String _tag;

  String money(double v, {String currency = 'TRY', int? decimals}) {
    final d = decimals ?? (v.abs() >= 1000 ? 0 : 2);
    return NumberFormat.currency(locale: _tag, symbol: _symbol(currency), decimalDigits: d).format(v);
  }

  /// Fiyatlar: büyüklüğe göre anlamlı basamak.
  String price(double v) {
    final d = v.abs() >= 1000 ? 2 : v.abs() >= 1 ? 4 : 6;
    return NumberFormat.decimalPatternDigits(locale: _tag, decimalDigits: d).format(v);
  }

  String number(double v, {int decimals = 2}) =>
      NumberFormat.decimalPatternDigits(locale: _tag, decimalDigits: decimals).format(v);

  String compact(double v) => NumberFormat.compact(locale: _tag).format(v);

  /// [ratio] oran olarak (0.125 -> %12,5).
  String pct(double ratio, {int decimals = 1, bool signed = false}) {
    final s = NumberFormat.decimalPatternDigits(locale: _tag, decimalDigits: decimals)
        .format(ratio * 100);
    final sign = signed && ratio > 0 ? '+' : '';
    return _tag.startsWith('tr') ? '$sign%$s' : '$sign$s%';
  }

  String date(DateTime d) => DateFormat.yMMMd(_tag).format(d);
  String shortDate(DateTime d) => DateFormat.MMMd(_tag).format(d);

  static String _symbol(String currency) => switch (currency) {
        'TRY' => '₺',
        'USD' => r'$',
        'EUR' => '€',
        'GBP' => '£',
        _ => '$currency ',
      };
}

/// Artış/azalış rengi (renk körlüğü için ikonla birlikte kullanılır).
Color changeColor(BuildContext context, double v) {
  final scheme = Theme.of(context).colorScheme;
  if (v > 0) return Colors.green.shade600;
  if (v < 0) return scheme.error;
  return scheme.onSurfaceVariant;
}

/// "1.234,56" ve "1234.56" biçimlerini kabul eder.
double? parseDecimal(String s) {
  var t = s.trim().replaceAll(' ', '');
  if (t.contains(',') && t.contains('.')) {
    t = t.lastIndexOf(',') > t.lastIndexOf('.')
        ? t.replaceAll('.', '').replaceAll(',', '.')
        : t.replaceAll(',', '');
  } else {
    t = t.replaceAll(',', '.');
  }
  return double.tryParse(t);
}
