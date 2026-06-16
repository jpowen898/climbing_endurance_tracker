import 'package:flutter/material.dart';

import 'active_workout_status.dart';
import 'pages/data_page.dart';
import 'pages/raw_data_page.dart';
import 'pages/record_page.dart';
import 'pages/workouts_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    workoutNotificationChannel.setMethodCallHandler((call) async {
      if (call.method == 'openRecord' && mounted) {
        setState(() => _index = 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const RecordPage(),
      const WorkoutsPage(),
      const DataPage(),
      const RawDataPage(),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ValueListenableBuilder<ActiveWorkoutSnapshot>(
              valueListenable: ActiveWorkoutStatus.instance,
              builder: (context, snapshot, child) {
                if (!snapshot.active || _index == 0) {
                  return const SizedBox.shrink();
                }
                return _ActiveWorkoutBanner(
                  snapshot: snapshot,
                  onTap: () => setState(() => _index = 0),
                );
              },
            ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: pages,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.timer_outlined), label: 'Record'),
          NavigationDestination(
              icon: Icon(Icons.fitness_center), label: 'Workouts'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Data'),
          NavigationDestination(
              icon: Icon(Icons.table_chart_outlined), label: 'Raw'),
        ],
      ),
    );
  }
}

class _ActiveWorkoutBanner extends StatelessWidget {
  const _ActiveWorkoutBanner({required this.snapshot, required this.onTap});

  final ActiveWorkoutSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    final foreground = Theme.of(context).colorScheme.onError;
    return Material(
      color: color,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.fiber_manual_record, color: foreground, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${snapshot.modeLabel}: ${snapshot.title} - ${snapshot.timerText}',
                  style:
                      TextStyle(color: foreground, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}
