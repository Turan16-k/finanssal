import 'dart:math' as math;
import 'dart:typed_data';

/// Temel istatistik ve lineer cebir yardımcıları (numpy karşılıklarıyla uyumlu).

const int tradingDays = 252;

double mean(List<double> x) {
  if (x.isEmpty) return 0;
  var s = 0.0;
  for (final v in x) {
    s += v;
  }
  return s / x.length;
}

/// Popülasyon standart sapması (numpy `std`, ddof=0).
double std(List<double> x) {
  if (x.isEmpty) return 0;
  final m = mean(x);
  var s = 0.0;
  for (final v in x) {
    s += (v - m) * (v - m);
  }
  return math.sqrt(s / x.length);
}

/// Günlük log getiriler: ln(p[t] / p[t-1]).
Float64List logReturns(List<double> prices) {
  final n = prices.length;
  final out = Float64List(n > 1 ? n - 1 : 0);
  for (var i = 1; i < n; i++) {
    out[i - 1] = math.log(prices[i] / prices[i - 1]);
  }
  return out;
}

/// Seriler farklı uzunluktaysa hepsini en kısa olanın uzunluğuna sondan kırpar.
List<List<double>> alignTail(List<List<double>> series) {
  if (series.isEmpty) return const [];
  final n = series.map((s) => s.length).reduce(math.min);
  return [for (final s in series) s.sublist(s.length - n)];
}

/// Örneklem kovaryans matrisi (numpy `cov`, ddof=1). Girdi (A, T).
List<Float64List> covariance(List<List<double>> rows) {
  final a = rows.length;
  final t = a == 0 ? 0 : rows.first.length;
  final means = [for (final r in rows) mean(r)];
  final out = List.generate(a, (_) => Float64List(a));
  if (t < 2) return out;
  for (var i = 0; i < a; i++) {
    for (var j = i; j < a; j++) {
      var s = 0.0;
      final ri = rows[i], rj = rows[j];
      for (var k = 0; k < t; k++) {
        s += (ri[k] - means[i]) * (rj[k] - means[j]);
      }
      final c = s / (t - 1);
      out[i][j] = c;
      out[j][i] = c;
    }
  }
  return out;
}

/// Pearson korelasyon matrisi.
List<Float64List> correlation(List<List<double>> rows) {
  final cov = covariance(rows);
  final a = cov.length;
  final out = List.generate(a, (_) => Float64List(a));
  for (var i = 0; i < a; i++) {
    for (var j = 0; j < a; j++) {
      final d = math.sqrt(cov[i][i] * cov[j][j]);
      out[i][j] = d > 0 ? cov[i][j] / d : (i == j ? 1 : 0);
    }
  }
  return out;
}

/// Alt üçgensel Cholesky çarpanı L (A = L Lᵀ). Köşegene [jitter] eklenir.
List<Float64List> cholesky(List<List<double>> a, {double jitter = 1e-10}) {
  final n = a.length;
  final l = List.generate(n, (_) => Float64List(n));
  for (var i = 0; i < n; i++) {
    for (var j = 0; j <= i; j++) {
      var s = a[i][j] + (i == j ? jitter : 0);
      for (var k = 0; k < j; k++) {
        s -= l[i][k] * l[j][k];
      }
      if (i == j) {
        if (s <= 0) {
          throw ArgumentError('Matris pozitif tanımlı değil (satır $i).');
        }
        l[i][j] = math.sqrt(s);
      } else {
        l[i][j] = s / l[j][j];
      }
    }
  }
  return l;
}

/// numpy `percentile` (varsayılan 'linear' yöntem) ile aynı sonuç. [sorted] artan sıralı olmalı.
double percentileSorted(List<double> sorted, double q) {
  if (sorted.isEmpty) return double.nan;
  final pos = (sorted.length - 1) * q / 100.0;
  final lo = pos.floor();
  final hi = pos.ceil();
  if (lo == hi) return sorted[lo];
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}

double percentile(List<double> x, double q) =>
    percentileSorted(List<double>.of(x)..sort(), q);

/// Negatifleri sıfırlar, toplamı 1'e ölçekler; toplam 0 ise eşit ağırlık.
Float64List normalizeWeights(List<double> w) {
  final out = Float64List(w.length);
  var total = 0.0;
  for (var i = 0; i < w.length; i++) {
    out[i] = w[i] > 0 ? w[i] : 0;
    total += out[i];
  }
  for (var i = 0; i < w.length; i++) {
    out[i] = total > 0 ? out[i] / total : 1 / w.length;
  }
  return out;
}

double dot(List<double> a, List<double> b) {
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    s += a[i] * b[i];
  }
  return s;
}

/// wᵀ Σ w
double quadForm(List<double> w, List<List<double>> sigma) {
  var s = 0.0;
  for (var i = 0; i < w.length; i++) {
    for (var j = 0; j < w.length; j++) {
      s += w[i] * sigma[i][j] * w[j];
    }
  }
  return s;
}
