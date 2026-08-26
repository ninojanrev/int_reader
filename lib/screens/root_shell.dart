import 'package:flutter/material.dart';
import '../main.dart';
import 'home_screen.dart';
import 'saved_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

/// Hosts the four main tabs behind a single shared bottom nav bar.
/// Using IndexedStack keeps each tab's scroll position and state
/// alive when switching between them.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _navIndex = 0;

  static final _tabs = [
    const HomeScreen(),
    const StatsScreen(),
    const SavedScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkModeNotifier,
      builder: (context, isDark, _) {
        return Scaffold(
          body: IndexedStack(
            index: _navIndex,
            children: [
              // Suspend animations (e.g. the cover backdrop clock) for
              // tabs that aren't selected.
              for (var i = 0; i < _tabs.length; i++)
                TickerMode(enabled: i == _navIndex, child: _tabs[i]),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _navIndex,
            onDestinationSelected: (i) => setState(() => _navIndex = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.auto_stories_outlined), label: 'Library'),
              NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Stats'),
              NavigationDestination(icon: Icon(Icons.bookmark_border), label: 'Saved'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
            ],
          ),
        );
      },
    );
  }
}
