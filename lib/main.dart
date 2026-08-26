import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/root_shell.dart';
import 'services/settings_service.dart';
import 'services/reminder_service.dart';
import 'services/font_service.dart';
import 'theme/app_theme.dart';
import 'providers/library_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

ValueNotifier<bool> darkModeNotifier = ValueNotifier<bool>(false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await settings.init();
  darkModeNotifier.value = settings.darkMode;
  // Re-arm the daily reminder on every launch (covers missed reschedules).
  if (settings.reminderEnabled) {
    reminderService.scheduleDaily(settings.reminderMinutesOfDay);
  }
  // Register imported fonts in the background; never blocks startup.
  fontService.loadSavedFonts();
  runApp(const EpubReaderApp());
}

class EpubReaderApp extends StatelessWidget {
  const EpubReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LibraryState()..loadBooks(),
      child: ValueListenableBuilder<bool>(
        valueListenable: darkModeNotifier,
        builder: (context, isDark, _) {
          return MaterialApp(
            key: navigatorKey,
            title: 'EPUB Reader',
            debugShowCheckedModeBanner: false,
            // Snap instantly between light/dark — no cross-fade.
            themeAnimationDuration: Duration.zero,
            theme: buildAppTheme(dark: isDark),
            home: const RootShell(),
          );
        },
      ),
    );
  }
}
