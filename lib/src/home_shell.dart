import 'package:flutter/material.dart';

import 'pages/data_page.dart';
import 'pages/raw_data_page.dart';
import 'pages/record_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const RecordPage(),
      const DataPage(),
      const RawDataPage(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.timer_outlined), label: 'Record'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Data'),
          NavigationDestination(icon: Icon(Icons.table_chart_outlined), label: 'Raw'),
        ],
      ),
    );
  }
}
