import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/settings_service.dart';
import '../providers/library_provider.dart';
import 'home_screen.dart';
import 'reader_screen.dart';
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
  bool _hasAutoOpened = false;
  // Untyped key — we call closeSearch()/isSearching via dynamic.
  final _homeKey = GlobalKey();

  late final _tabs = [
    HomeScreen(key: _homeKey),
    const StatsScreen(),
    const SavedScreen(),
    const SettingsScreen(),
  ];

  void _tryAutoOpenLastBook() {
    if (_hasAutoOpened) return;
    if (!settings.openLastBookOnStart) return;
    _hasAutoOpened = true;

    final library = context.read<LibraryState>();
    final books = library.books;
    if (books.isEmpty) return;

    // Find the most recently read book.
    final lastRead = books
        .where((b) => b.lastReadAt != null)
        .toList()
      ..sort((a, b) => b.lastReadAt!.compareTo(a.lastReadAt!));
    if (lastRead.isEmpty) return;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(book: lastRead.first),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutoOpenLastBook();
    });

    return ValueListenableBuilder<bool>(
      valueListenable: darkModeNotifier,
      builder: (context, isDark, _) {
        return PopScope(
          canPop: _navIndex == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_navIndex != 0) {
              setState(() => _navIndex = 0);
              return;
            }
            // On library tab — close search if open.
            final homeState = _homeKey.currentState;
            if (homeState != null) {
              // ignore: avoid_dynamic_calls
              final searching = (homeState as dynamic).isSearching as bool;
              if (searching) {
                // ignore: avoid_dynamic_calls
                (homeState as dynamic).closeSearch();
                return;
              }
            }
          },
          child: Scaffold(
            body: IndexedStack(
              index: _navIndex,
              children: [
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
          ),
        );
      },
    );
  }
}
