
import 'package:flutter/material.dart';
import 'package:seraeditor/database/app_database.dart';
import 'package:seraeditor/root/app_entry.dart';
import 'package:seraeditor/utils/app_theme.dart';
import 'package:seraeditor/utils/logging.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppDatabase.instance.initialize();

  setupLogging();
  
  runApp(const SeraEditorApp());
}

class SeraEditorApp extends StatelessWidget {
  const SeraEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AppEntry(),
    );
  }
}
