// utils/logging_setup.dart
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

void setupLogging() {
  Logger.root.level = Level.ALL;
  
  Logger.root.onRecord.listen((record) {
    final time = record.time.toIso8601String();
    final level = _getLevelEmoji(record.level);
    final loggerName = record.loggerName;
    final message = record.message;
    
    String logOutput = '$time $level $loggerName: $message';
    
    if (record.error != null) {
      logOutput += '\nError: ${record.error}';
    }
    
    if (record.stackTrace != null) {
      logOutput += '\nStack: ${record.stackTrace}';
    }
    
    debugPrint(logOutput);
  });
}

String _getLevelEmoji(Level level) {
  switch (level) {
    case Level.SEVERE:
      return '🔴';
    case Level.WARNING:
      return '🟡';
    case Level.INFO:
      return '🔵';
    case Level.CONFIG:
      return '⚙️';
    case Level.FINE:
      return '✅';
    case Level.FINER:
      return '📋';
    case Level.FINEST:
      return '🔍';
    default:
      return '📝';
  }
}
