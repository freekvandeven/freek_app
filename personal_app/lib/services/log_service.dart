import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class LogEntry {
  final DateTime timestamp;
  final String level;
  final String message;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  String get formatted =>
      '[${DateFormat('HH:mm:ss.SSS').format(timestamp)}] $level: $message';
}

class LogService {
  static final LogService instance = LogService._();

  LogService._();

  static const int _maxEntries = 2000;
  final _entries = Queue<LogEntry>();

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void _add(String level, String message) {
    _entries.addLast(LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
    ));
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }
  }

  void info(String message) => _add('INFO', message);
  void warning(String message) => _add('WARN', message);
  void error(String message) => _add('ERROR', message);

  /// Install as the global Flutter error handler and debug print interceptor.
  void install() {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      _add('ERROR', details.exceptionAsString());
      if (details.stack != null) {
        _add('STACK', details.stack.toString().split('\n').take(10).join('\n'));
      }
      originalOnError?.call(details);
    };

    final originalOnPlatformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _add('PLATFORM_ERROR', error.toString());
      _add('STACK', stack.toString().split('\n').take(10).join('\n'));
      return originalOnPlatformError?.call(error, stack) ?? false;
    };
  }

  void clear() => _entries.clear();
}

final logServiceProvider = Provider<LogService>((_) => LogService.instance);
