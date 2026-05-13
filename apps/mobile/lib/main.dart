import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app.dart';
import 'src/core/di/service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // REGRESSION: DateFormat.yMMMM('en') in requester_profile_sheet.dart requires
  // locale data to be initialized at boot. Removing this call re-introduces
  // the cold-boot LocaleDataException. See TRI-28.
  await initializeDateFormatting('en');
  await configureDependencies();
  runApp(const ProviderScope(child: TribelyApp()));
}
