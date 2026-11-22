import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/app_settings.dart';
import 'core/theme.dart';
import 'data/database.dart';
import 'screens/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await AppDb.instance.init();
  await AppAppearance.instance.load();
  runApp(const KresnaApp());
}

class KresnaApp extends StatelessWidget {
  const KresnaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppearanceState>(
      valueListenable: AppAppearance.instance,
      builder: (context, appearance, _) {
        return MaterialApp(
          title: 'Kresna Laundry',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(appearance, brightness: Brightness.light),
          darkTheme: buildTheme(appearance, brightness: Brightness.dark),
          themeMode: appearance.themeMode,
          locale: const Locale('id', 'ID'),
          supportedLocales: const [Locale('id', 'ID')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(appearance.fontScale),
                boldText: appearance.boldText || mq.boldText,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const AppShell(),
        );
      },
    );
  }
}
