import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'src/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const ClimbEnduranceApp());
}

class ClimbEnduranceApp extends StatelessWidget {
  const ClimbEnduranceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff1e8f6f),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Climb Endurance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xff101412),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      home: const HomeShell(),
    );
  }
}
