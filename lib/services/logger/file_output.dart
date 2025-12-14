import 'dart:io';
import 'package:logger/logger.dart';

class FileOutput extends LogOutput {
  final File file;

  FileOutput({required this.file});

  @override
  void output(OutputEvent event) {
    if (!file.existsSync()) {
      try {
        file.createSync(recursive: true);
      } catch (e) {
        // Fallback: If we can't create file, we can't log to it.
        // We shouldn't crash the logger though.
        return;
      }
    }

    // Convert logs to string
    final buffer = StringBuffer();
    for (var line in event.lines) {
      buffer.writeln(line);
    }

    try {
      file.writeAsStringSync(
        buffer.toString(),
        mode: FileMode.append,
        flush: true, // Flush immediately to ensure data is written before crash
      );
    } catch (e) {
      // Ignore write errors to prevent logging from crashing app
    }
  }
}
