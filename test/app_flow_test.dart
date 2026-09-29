import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fraktal/app.dart';
import 'package:fraktal/core/format.dart';
import 'package:fraktal/core/providers.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(p)],
    child: const FraktalApp(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting());

  testWidgets('yasal uyarı kabul edilmeden uygulama açılmaz', (tester) async {
    await pumpApp(tester, prefs: {'settings.locale': 'tr'});
    expect(find.text('Önemli bilgilendirme'), findsOneWidget);

    final button = find.widgetWithText(FilledButton, 'Devam');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();

    // Demo modunda piyasalar açılır.
    expect(find.text('Piyasalar'), findsWidgets);
    expect(find.text('USDTRY'), findsOneWidget);
    expect(find.textContaining('Demo modu'), findsOneWidget);
  });

  testWidgets('portföy oluşturma akışı (demo)', (tester) async {
    await pumpApp(tester, prefs: {'settings.locale': 'tr', 'settings.disclaimer_v1': true});
    await tester.tap(find.text('Portföy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Henüz portföyünüz yok'), findsOneWidget);

    await tester.tap(find.text('Yeni portföy'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Uzun vade');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    // Detay sayfası açıldı.
    expect(find.text('Uzun vade'), findsOneWidget);
    expect(find.text('İşlem ekle'), findsOneWidget);
  });

  testWidgets('İngilizce yerelleştirme', (tester) async {
    await pumpApp(tester, prefs: {'settings.locale': 'en', 'settings.disclaimer_v1': true});
    expect(find.text('Markets'), findsWidgets);
    await tester.tap(find.text('Lab'));
    await tester.pumpAndSettle();
    expect(find.text('Analysis lab'), findsOneWidget);
  });

  test('parseDecimal TR ve EN biçimleri', () {
    expect(parseDecimal('1.234,56'), 1234.56);
    expect(parseDecimal('1,234.56'), 1234.56);
    expect(parseDecimal('12,5'), 12.5);
    expect(parseDecimal('abc'), isNull);
  });
}
