import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel { debug, info, warn, error }

/// Persistent file-based logger. Writes timestamped lines to a daily log
/// file under the app's documents directory (`logs/app_YYYY-MM-DD.log`) so
/// the client's device retains a record of activity/errors after delivery,
/// independent of a debugger being attached.
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  Directory? _logDir;
  File? _currentFile;
  String? _currentDateKey;
  final _writeLock = <Future>[];

  static const int _maxRetainedDays = 14;

  Future<void> init() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      _logDir = Directory('${docsDir.path}/logs');
      if (!await _logDir!.exists()) {
        await _logDir!.create(recursive: true);
      }
      await _pruneOldLogs();
      i('AppLogger', 'Logger initialized. Log dir: ${_logDir!.path}');
    } catch (e, st) {
      debugPrint('AppLogger: failed to init file logging: $e\n$st');
    }
  }

  String get _dateKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<File> _fileForToday() async {
    final key = _dateKey;
    if (_currentFile != null && _currentDateKey == key) {
      return _currentFile!;
    }
    _currentDateKey = key;
    _currentFile = File('${_logDir!.path}/app_$key.log');
    return _currentFile!;
  }

  Future<void> _pruneOldLogs() async {
    if (_logDir == null || !await _logDir!.exists()) return;
    final cutoff = DateTime.now().subtract(const Duration(days: _maxRetainedDays));
    await for (final entity in _logDir!.list()) {
      if (entity is File) {
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    }
  }

  void _write(LogLevel level, String tag, String message, [Object? error, StackTrace? stackTrace]) {
    final ts = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(5);
    final line = StringBuffer('[$ts] $levelStr [$tag] $message');
    if (error != null) line.write(' | error: $error');
    if (stackTrace != null) line.write('\n$stackTrace');

    if (kDebugMode) {
      debugPrint(line.toString());
    }

    if (_logDir == null) return; // not initialized yet — console-only fallback
    final future = _fileForToday().then((file) async {
      try {
        await file.writeAsString('${line.toString()}\n', mode: FileMode.append, flush: true);
      } catch (_) {
        // Disk full / permission issue — swallow, console output already happened.
      }
    });
    _writeLock.add(future);
    if (_writeLock.length > 50) {
      _writeLock.removeRange(0, _writeLock.length - 50);
    }
  }

  void d(String tag, String message) => _write(LogLevel.debug, tag, message);
  void i(String tag, String message) => _write(LogLevel.info, tag, message);
  void w(String tag, String message, [Object? error, StackTrace? stackTrace]) =>
      _write(LogLevel.warn, tag, message, error, stackTrace);
  void e(String tag, String message, [Object? error, StackTrace? stackTrace]) =>
      _write(LogLevel.error, tag, message, error, stackTrace);

  /// Waits for any in-flight writes to land on disk — call before reading
  /// back log contents (e.g. an in-app "export logs" action).
  Future<void> flush() async {
    await Future.wait(List.of(_writeLock));
  }

  /// Path to today's log file, for support/export tooling.
  String? get currentLogPath => _currentFile?.path;

  String? get logDirPath => _logDir?.path;

  Future<List<File>> allLogFiles() async {
    if (_logDir == null || !await _logDir!.exists()) return [];
    final files = await _logDir!.list().where((e) => e is File).cast<File>().toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }
}
