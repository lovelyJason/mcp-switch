import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart' hide FileOutput;
import 'package:path/path.dart' as p;
import 'logger/file_output.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();

  factory LoggerService() {
    return _instance;
  }

  LoggerService._internal();

  late Logger _logger;
  File? _logFile;
  ReleaseLogFilter? _releaseFilter;

  static Future<void> init() async {
    final service = _instance;
    await service._initLogger();
  }

  Future<void> _initLogger() async {
    LogOutput output;
    
    // Strategy:
    // Debug -> Console
    // Release -> File with Configurable Level

    LogFilter filter;
    
    if (kReleaseMode) {
      final home = Platform.environment['HOME'] ?? '.';
      final dir = Directory(p.join(home, '.mcp-switch', 'logs'));
      
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      _logFile = File(p.join(dir.path, 'app.log'));
      output = FileOutput(file: _logFile!);
      
      // Load initial level from ConfigService? 
      // We can't easily access Provider here without context.
      // But LoggerService is singleton.
      // We will assume "Info" level (2) as default for init,
      // and let ConfigService update us later.
      _releaseFilter = ReleaseLogFilter(configuredLevel: 0);
      filter = _releaseFilter!; 
    } else {
      output = ConsoleOutput();
      filter = DevelopmentFilter();
    }

    _logger = Logger(
      filter: filter,
      printer: PrettyPrinter(
        methodCount: 2, // Number of method calls to be displayed
        errorMethodCount: 8, // Number of method calls if stacktrace is provided
        lineLength: 120, // Width of the output
        colors: !kReleaseMode, // Colorful log messages in console, plain in file
        printEmojis: true, // Print an emoji for each log message
        printTime: true, // Should each log print contain a timestamp
      ),
      output: output,
    );
    
    info(
      'Logger initialized. Mode: ${kReleaseMode ? 'Release (File)' : 'Debug (Console)'}',
    );
  }

  static void setReleaseLogLevel(int level) {
    if (kReleaseMode && _instance._releaseFilter != null) {
      _instance._releaseFilter!.configuredLevel = level;
    }
  }

  // --- Static Accessors ---

  /// Log a message at level [Level.trace].
  static void verbose(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _instance._logger.t(message, error: error, stackTrace: stackTrace);
  }

  /// Log a message at level [Level.debug].
  static void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _instance._logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log a message at level [Level.info].
  static void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _instance._logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log a message at level [Level.warning].
  static void warning(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _instance._logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log a message at level [Level.error].
  static void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _instance._logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log a message at level [Level.fatal].
  static void fatal(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _instance._logger.f(message, error: error, stackTrace: stackTrace);
  }
}

class ReleaseLogFilter extends LogFilter {
  int configuredLevel;

  ReleaseLogFilter({this.configuredLevel = 2});

  @override
  bool shouldLog(LogEvent event) {
    // 1. Mandatory: Error and Fatal are ALWAYS logged
    if (event.level == Level.error || event.level == Level.fatal) {
      return true;
    }

    // 2. Forbidden: Debug is NEVER logged (per user request)
    if (event.level == Level.debug) {
      return false;
    }

    // 3. Configurable Levels (0=Error, 1=Warning, 2=Info, 3=Verbose)
    // Map Config Level to Minimum Required Level
    // 0 (Error only) -> handled by step 1
    // 1 (Warning+)   -> Warning
    // 2 (Info+)      -> Info, Warning
    // 3 (Verbose+)   -> Trace, Info, Warning

    if (configuredLevel == 0) return false; // Already handled Error/Fatal

    if (configuredLevel >= 1 && event.level == Level.warning) return true;
    if (configuredLevel >= 2 && event.level == Level.info) return true;
    if (configuredLevel >= 3 && event.level == Level.trace) return true;

    return false;
  }
}
