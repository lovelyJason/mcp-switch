import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// 单个 context 文件条目
class GeminiContextFile {
  final String title;      // 显示名，如 "GEMINI.md"
  final String sourceName; // 来源，如 "Global" 或 extension 名 "gemini-cli-jules"
  final String filePath;   // 实际文件路径
  final String content;    // 文件内容

  const GeminiContextFile({
    required this.title,
    required this.sourceName,
    required this.filePath,
    required this.content,
  });

  bool get isGlobal => sourceName == 'Global';
}

/// 读取 Gemini 所有 context 文件
/// - ~/.gemini/GEMINI.md (全局)
/// - ~/.gemini/extensions/{name}/{contextFileName} (各 extension)
class GeminiContextService extends ChangeNotifier {
  List<GeminiContextFile> _contextFiles = [];
  bool _isLoading = false;
  String? _error;

  List<GeminiContextFile> get contextFiles => _contextFiles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  static String get _home => Platform.environment['HOME'] ?? '';

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final files = <GeminiContextFile>[];

      // 1. 全局 ~/.gemini/GEMINI.md
      final globalFile = File('$_home/.gemini/GEMINI.md');
      if (globalFile.existsSync()) {
        files.add(GeminiContextFile(
          title: 'GEMINI.md',
          sourceName: 'Global',
          filePath: globalFile.path,
          content: await globalFile.readAsString(),
        ));
      }

      // 2. Extension context 文件
      final extDir = Directory('$_home/.gemini/extensions');
      if (extDir.existsSync()) {
        for (final entry in extDir.listSync()) {
          if (entry is! Directory) continue;

          final configFile = File('${entry.path}/gemini-extension.json');
          if (!configFile.existsSync()) continue;

          try {
            final json =
                jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
            final extName = json['name']?.toString() ??
                entry.path.split(Platform.pathSeparator).last;
            final rawContextFileName = json['contextFileName']?.toString();
            if (rawContextFileName == null || rawContextFileName.isEmpty) continue;

            // 替换 ${/} 占位符
            final relPath = rawContextFileName.replaceAll(
                r'${/}', Platform.pathSeparator);
            final contextFile = File('${entry.path}/$relPath');
            if (!contextFile.existsSync()) continue;

            final fileName = contextFile.path.split(Platform.pathSeparator).last;
            files.add(GeminiContextFile(
              title: fileName,
              sourceName: extName,
              filePath: contextFile.path,
              content: await contextFile.readAsString(),
            ));
          } catch (e) {
            debugPrint('GeminiContextService: 加载 ${entry.path} 失败: $e');
          }
        }
      }

      _contextFiles = files;
      _error = null;
    } catch (e) {
      _error = '加载 Gemini context 文件失败: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
