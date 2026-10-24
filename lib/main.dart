import 'package:flutter/material.dart';

import 'screens/capture_screen.dart';

void main() {
  runApp(const CatchallApp());
}

class CatchallApp extends StatelessWidget {
  const CatchallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catchall',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const CaptureScreen(),
    );
  }
}
