import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/bootstrap.dart';
import 'core/providers.dart';

Future<void> main() async {
  final boot = await bootstrap();
  await initializeDateFormatting();
  runApp(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(boot.prefs),
      firebaseReadyProvider.overrideWithValue(boot.firebaseReady),
    ],
    child: const FraktalApp(),
  ));
}
