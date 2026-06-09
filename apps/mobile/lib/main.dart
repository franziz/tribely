import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app.dart';
import 'src/core/config/app_config.dart';
import 'src/core/di/service_locator.dart';
import 'src/core/observability/sentry_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // REGRESSION: DateFormat.yMMMM('en') in requester_profile_sheet.dart requires
  // locale data to be initialized at boot. Removing this call re-introduces
  // the cold-boot LocaleDataException. See TRI-28.
  await initializeDateFormatting('en');
  await configureDependencies();

  // SentryFlutter.init's appRunner installs FlutterError.onError + zone
  // handlers for uncaught Dart + widget errors automatically.
  // Do NOT hand-roll runZonedGuarded — it duplicates the SDK's handlers.
  await initSentry(
    dsn: AppConfig.dev.sentryDsn,
    appRunner: () async => runApp(const ProviderScope(child: TribelyApp())),
  );
}
