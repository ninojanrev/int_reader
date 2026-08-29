import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/library_provider.dart';
import '../services/stats_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with TickerProviderStateMixin {
  late AnimationController _streakController;
  late Animation<double> _streakScale;
  late AnimationController _goalController;
  late Animation<double> _goalProgress;

  ReadingStats? _stats;
  String? _loadError;

  static const monthlyDayGoal = 20;
  final DateTime _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    darkModeNotifier.addListener(_onDarkModeChanged);
    _streakController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _streakScale = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _streakController, curve: Curves.easeInOut));
    _streakController.repeat(reverse: true);
    _goalController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _goalProgress = Tween<double>(begin: 0.0, end: 0.0).animate(CurvedAnimation(parent: _goalController, curve: Curves.easeOutCubic));
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await statsService.compute();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _goalProgress = Tween<double>(
          begin: 0.0,
          end: (stats.daysReadThisMonth / monthlyDayGoal).clamp(0.0, 1.0),
        ).animate(CurvedAnimation(parent: _goalController, curve: Curves.easeOutCubic));
      });
      _goalController.forward(from: 0);
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    }
  }

  @override
  void dispose() {
    darkModeNotifier.removeListener(_onDarkModeChanged);
    _streakController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  void _onDarkModeChanged() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loadError != null) {
      return Center(child: Text('Could not load stats.\n$_loadError',
        textAlign: TextAlign.center, style: theme.textTheme.bodyMedium));
    }
    if (_stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
      const SizedBox(height: 8),
      Text('Your stats', style: theme.textTheme.headlineSmall),
      const SizedBox(height: 16),
      _buildMetricGrid(),
      const SizedBox(height: 20),
      _buildStreakSection(),
      const SizedBox(height: 20),
      _buildMonthlyGoalCard(),
      const SizedBox(height: 24),
      Text('This week', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 12),
      _buildWeeklyChart(),
      const SizedBox(height: 24),
      Text('Currently reading', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      _buildInProgressList(),
      const SizedBox(height: 12),
    ]));
  }

  /// Monday..Sunday read flags for the last 7 calendar days.
  List<bool> _readDaysThisWeek() {
    final week = _stats!.weekMinutes;
    return week.entries.map((e) => e.value > 0).toList();
  }

  Widget _buildStreakSection() {
    final theme = Theme.of(context);
    final streakDays = _stats!.currentStreakDays;
    final bestStreak = _stats!.bestStreakDays;
    // Weekday initials starting Monday.
    const daysOfWeek = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final readDays = _readDaysThisWeek();
    final todayWeekdayIndex = _today.weekday - 1; // Monday == 0
    return Card(elevation: 0, color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AnimatedBuilder(animation: _streakScale,
            builder: (context, child) => Transform.scale(scale: _streakScale.value, child: child),
            child: Icon(Icons.local_fire_department, size: 28,
              color: streakDays > 0 ? const Color(0xFFFF6D00) : theme.colorScheme.onSurfaceVariant)),
          const SizedBox(width: 10),
          Text('$streakDays day streak', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(bestStreak > 0 ? 'Best: $bestStreak days' : 'No reading yet',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ]),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(7, (i) {
          final didRead = i < readDays.length && readDays[i];
          final isToday = i == todayWeekdayIndex;
          final isFuture = i > todayWeekdayIndex;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: didRead ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
              border: isToday ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
            ), child: didRead ? Icon(Icons.check, size: 16, color: theme.colorScheme.onPrimary) : null),
            const SizedBox(height: 4),
            Opacity(opacity: isFuture ? 0.4 : 1.0,
              child: Text(daysOfWeek[i], style: theme.textTheme.labelSmall?.copyWith(
                color: isToday ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                fontWeight: isToday ? FontWeight.w600 : FontWeight.w400))),
          ]);
        })),
      ])),);
  }

  Widget _buildMonthlyGoalCard() {
    final theme = Theme.of(context);
    final daysRead = _stats!.daysReadThisMonth;
    final goalFraction = (daysRead / monthlyDayGoal).clamp(0.0, 1.0);
    return Card(elevation: 0, color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
      child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        AnimatedBuilder(animation: _goalProgress, builder: (context, child) {
          return SizedBox(width: 80, height: 80, child: Stack(alignment: Alignment.center, children: [
            SizedBox(width: 80, height: 80, child: CircularProgressIndicator(
              value: _goalProgress.value, strokeWidth: 7,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: theme.colorScheme.primary, strokeCap: StrokeCap.round)),
            Text('${(_goalProgress.value * 100).round()}%',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ]));
        }),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Monthly goal', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Read on $daysRead of $monthlyDayGoal days this month',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
            value: goalFraction, minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest)),
        ])),
      ])),);
  }

  Widget _buildMetricGrid() {
    final theme = Theme.of(context);
    final library = context.watch<LibraryState>();
    final avgSession = _stats!.daysReadTotal > 0
        ? (_stats!.totalMinutes / _stats!.daysReadTotal).round()
        : 0;
    final avgLabel = avgSession >= 60
        ? '${(avgSession / 60).floor()}h ${avgSession % 60}m'
        : '${avgSession}m';
    final metrics = [
      ('Reading time', _stats!.totalFormatted, Icons.access_time),
      ('Books finished', '${library.finishedBooks.length}', Icons.menu_book_outlined),
      ('Avg. session', avgLabel, Icons.timelapse_outlined),
      ('Days read', '${_stats!.daysReadTotal}', Icons.calendar_today_outlined),
    ];
    return GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.6, children: metrics.map((m) {
      final (label, value, icon) = m;
      return Card(elevation: 0, color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
        child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: theme.textTheme.titleMedium),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ])));
    }).toList());
  }

  Widget _buildWeeklyChart() {
    final theme = Theme.of(context);
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final weeklyMinutes =
        _stats!.weekMinutes.values.map((m) => m.round()).toList();
    if (weeklyMinutes.isEmpty || weeklyMinutes.every((m) => m == 0)) {
      return Card(elevation: 0, color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
        child: Padding(padding: const EdgeInsets.all(16), child: Text(
          'Open a book to start tracking your reading time.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))));
    }
    final maxMinutes = weeklyMinutes.reduce((a, b) => a > b ? a : b);
    final todayIndex = _today.weekday - 1;
    return Card(elevation: 0, color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
      child: Padding(padding: const EdgeInsets.all(16), child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(weeklyMinutes.length, (i) {
        final minutes = weeklyMinutes[i]; final barHeight = maxMinutes == 0 ? 6.0 : 90 * (minutes / maxMinutes);
        final isToday = i == todayIndex;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${minutes}m', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Container(width: 18, height: barHeight.clamp(6.0, 90.0), decoration: BoxDecoration(
            color: minutes == 0
                ? theme.colorScheme.surfaceContainerHighest
                : isToday ? theme.colorScheme.primary : theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 6),
          Text(days[i], style: theme.textTheme.labelSmall?.copyWith(
            color: isToday ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            fontWeight: isToday ? FontWeight.w600 : FontWeight.w400)),
        ]);
      }),
      ),
    ),
  );
  }

  Widget _buildInProgressList() {
    final theme = Theme.of(context);
    final library = context.watch<LibraryState>();
    final inProgress = library.inProgressBooks;
    if (inProgress.isEmpty) {
      return Text('Nothing in progress right now.',
      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    }
    return Column(children: inProgress.map((book) {
      final percent = (book.progress * 100).round();
      return Card(elevation: 0, color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
        child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 34, height: 50,
              child: book.coverImagePath != null
                  ? Image.file(File(book.coverImagePath!), fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildCoverFallback(book, theme))
                  : _buildCoverFallback(book, theme),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(book.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text('$percent% complete', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ])),
        ])));
    }).toList());
  }

  Widget _buildCoverFallback(dynamic book, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        book.title.isNotEmpty ? book.title[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 14,
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
