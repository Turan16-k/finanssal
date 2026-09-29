import 'dart:math' as math;

/// Tohumlanabilir rastgele sayı üreteci: düzgün, standart normal ve Poisson.
///
/// Aynı tohum her platformda aynı diziyi verir (dart:math Random deterministiktir),
/// böylece kayıtlı bir simülasyon yeniden üretilebilir.
class Rng {
  Rng([int? seed]) : _r = math.Random(seed);

  final math.Random _r;
  double? _spare;

  double uniform() => _r.nextDouble();

  /// Marsaglia polar yöntemi; ikinci değer bir sonraki çağrı için saklanır.
  double normal() {
    final spare = _spare;
    if (spare != null) {
      _spare = null;
      return spare;
    }
    double u, v, s;
    do {
      u = _r.nextDouble() * 2 - 1;
      v = _r.nextDouble() * 2 - 1;
      s = u * u + v * v;
    } while (s >= 1 || s == 0);
    final m = math.sqrt(-2 * math.log(s) / s);
    _spare = v * m;
    return u * m;
  }

  /// Knuth algoritması; küçük lambda (günlük sıçrama olasılığı) için uygundur.
  int poisson(double lambda) {
    if (lambda <= 0) return 0;
    final l = math.exp(-lambda);
    var k = 0;
    var p = 1.0;
    do {
      k++;
      p *= _r.nextDouble();
    } while (p > l);
    return k - 1;
  }
}
