import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'models/note_record.dart';
import 'screens/capture_screen.dart';
import 'screens/history_screen.dart';
import 'screens/note_detail_screen.dart';
import 'utils/date_time_utils.dart';

import 'note_storage.dart';

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
