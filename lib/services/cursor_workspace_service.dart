import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import '../utils/platform_utils.dart';
import '../constants/editor_features.dart';
import '../models/editor_type.dart';
import 'logger_service.dart';

class CursorWorkspace {
  final String id;
  final String folderPath;
  final String dbPath;

  const CursorWorkspace({
    required this.id,
    required this.folderPath,
    required this.dbPath,
  });
}

/// Cursor workspace SQLite 操作服务
///
/// 负责：
/// 1. 检测本机 Cursor 版本
/// 2. 发现所有 workspace 及其项目路径
/// 3. 读写 workspace 级别的 disabledMcpServers
class CursorWorkspaceService {
  CursorWorkspaceService._();
  static final instance = CursorWorkspaceService._();

  String? _cursorVersion;
  String? _disabledMechanism;

  /// 本机 Cursor 版本号（如 "2.5.26"），null 表示未安装或无法检测
  String? get cursorVersion => _cursorVersion;

  /// 当前 Cursor 版本的 mcp_disabled 机制
  /// 值来自 editor_features.yaml: "json_field" | "sqlite_workspace" | null
  String? get disabledMechanism => _disabledMechanism;

  /// 是否应使用 SQLite 操作 disabled 状态
  bool get shouldUseSqlite => _disabledMechanism == 'sqlite_workspace';

  /// 初始化：检测 Cursor 版本并判断 disabled 管理机制
  Future<void> init() async {
    _cursorVersion = await _detectCursorVersion();
    _disabledMechanism = _resolveDisabledMechanism();
    LoggerService.info(
      'CursorWorkspaceService: version=$_cursorVersion, mechanism=$_disabledMechanism',
    );
  }

  /// 从 Cursor.app Info.plist 检测版本
  Future<String?> _detectCursorVersion() async {
    try {
      if (!Platform.isMacOS) return null;

      final plistPath = '/Applications/Cursor.app/Contents/Info.plist';
      final file = File(plistPath);
      if (!await file.exists()) return null;

      final result = await Process.run('defaults', ['read', plistPath, 'CFBundleShortVersionString']);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (e) {
      LoggerService.error('Failed to detect Cursor version: $e');
    }
    return null;
  }

  /// 根据 editor_features.yaml 的版本区间查找当前 Cursor 版本的 disabled 管理机制
  String? _resolveDisabledMechanism() {
    if (_cursorVersion == null) return null;
    return EditorFeatures.getMechanism(
      EditorType.cursor,
      'mcp_disabled',
      _cursorVersion!,
    );
  }

  /// ~/.cursor/projects 目录
  String get _cursorProjectsRoot {
    return '${PlatformUtils.userHome}/.cursor/projects';
  }

  /// workspaceStorage 根目录
  String get _workspaceStorageRoot {
    final home = PlatformUtils.userHome;
    if (Platform.isMacOS) {
      return '$home/Library/Application Support/Cursor/User/workspaceStorage';
    } else if (Platform.isWindows) {
      return '$home\\AppData\\Roaming\\Cursor\\User\\workspaceStorage';
    }
    return '$home/.config/Cursor/User/workspaceStorage';
  }

  /// 将文件路径转为 .cursor/projects 的目录名格式
  /// /Users/jasonhuang/projects/my/mcp-switch -> Users-jasonhuang-projects-my-mcp-switch
  static String _pathToDirKey(String path) {
    return path.replaceAll('/', '-').replaceAll('.', '-').replaceFirst(RegExp(r'^-'), '');
  }

  /// 发现所有 Cursor workspace（以 ~/.cursor/projects 为数据源）
  Future<List<CursorWorkspace>> getWorkspaces() async {
    // 1. 扫描 ~/.cursor/projects 获取项目列表
    final projectsDir = Directory(_cursorProjectsRoot);
    if (!await projectsDir.exists()) return [];

    final Set<String> projectDirNames = {};
    await for (final entity in projectsDir.list()) {
      if (entity is! Directory) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (name.startsWith('.') || name.startsWith('var-')) continue;
      projectDirNames.add(name);
    }

    if (projectDirNames.isEmpty) return [];

    // 2. 扫描 workspaceStorage 建立 dirKey -> workspace 映射
    final wsDir = Directory(_workspaceStorageRoot);
    if (!await wsDir.exists()) return [];

    final Map<String, CursorWorkspace> wsMap = {};
    await for (final entity in wsDir.list()) {
      if (entity is! Directory) continue;

      final wsJsonFile = File('${entity.path}/workspace.json');
      final dbFile = File('${entity.path}/state.vscdb');
      if (!await wsJsonFile.exists() || !await dbFile.exists()) continue;

      try {
        final wsJson = jsonDecode(await wsJsonFile.readAsString());
        final folderUri = wsJson['folder']?.toString() ?? '';
        if (folderUri.isEmpty) continue;

        final folderPath = Uri.parse(folderUri).toFilePath();
        final id = entity.path.split(Platform.pathSeparator).last;
        final dirKey = _pathToDirKey(folderPath);

        wsMap[dirKey] = CursorWorkspace(
          id: id,
          folderPath: folderPath,
          dbPath: dbFile.path,
        );
      } catch (e) {
        LoggerService.warning('Failed to parse workspace: ${entity.path}: $e');
      }
    }

    // 3. 以 .cursor/projects 为准，匹配 workspaceStorage
    final List<CursorWorkspace> result = [];
    for (final dirName in projectDirNames) {
      final ws = wsMap[dirName];
      if (ws != null) {
        result.add(ws);
      }
    }

    return result;
  }

  /// 读取指定 workspace 的 disabledMcpServers
  List<String> getDisabledServers(String dbPath) {
    try {
      final db = sqlite.sqlite3.open(dbPath, mode: sqlite.OpenMode.readOnly);
      try {
        final result = db.select(
          "SELECT value FROM ItemTable WHERE key = 'cursor/disabledMcpServers'",
        );
        if (result.isNotEmpty) {
          final value = result.first['value'] as String?;
          if (value != null) {
            final list = jsonDecode(value);
            if (list is List) return list.cast<String>();
          }
        }
      } finally {
        db.dispose();
      }
    } catch (e) {
      LoggerService.error('Failed to read disabledMcpServers from $dbPath: $e');
    }
    return [];
  }

  /// 写入指定 workspace 的 disabledMcpServers
  bool _setDisabledServers(String dbPath, List<String> servers) {
    try {
      final db = sqlite.sqlite3.open(dbPath, mode: sqlite.OpenMode.readWrite);
      try {
        final jsonValue = jsonEncode(servers);
        final existing = db.select(
          "SELECT value FROM ItemTable WHERE key = 'cursor/disabledMcpServers'",
        );
        if (existing.isNotEmpty) {
          db.execute(
            "UPDATE ItemTable SET value = ? WHERE key = 'cursor/disabledMcpServers'",
            [jsonValue],
          );
        } else {
          db.execute(
            "INSERT INTO ItemTable (key, value) VALUES ('cursor/disabledMcpServers', ?)",
            [jsonValue],
          );
        }
        return true;
      } finally {
        db.dispose();
      }
    } catch (e) {
      LoggerService.error('Failed to write disabledMcpServers to $dbPath: $e');
      return false;
    }
  }

  /// 在所有 workspace 中切换某个 MCP server 的启用/禁用状态
  ///
  /// [serverName] mcp.json 中的 key（如 "Figma"）
  /// 会自动加上 "user-" 前缀（Cursor 的命名规则）
  /// [disabled] true=禁用, false=启用
  /// 返回成功操作的 workspace 数量
  Future<int> toggleServerInAllWorkspaces(String serverName, bool disabled) async {
    final workspaces = await getWorkspaces();
    final mcpKey = 'user-$serverName';
    int successCount = 0;

    for (final ws in workspaces) {
      final current = getDisabledServers(ws.dbPath);
      List<String> updated;

      if (disabled) {
        updated = current.contains(mcpKey) ? current : [...current, mcpKey];
      } else {
        updated = current.where((s) => s != mcpKey).toList();
      }

      if (_setDisabledServers(ws.dbPath, updated)) {
        successCount++;
      }
    }

    LoggerService.info(
      'toggleServerInAllWorkspaces: $serverName disabled=$disabled, '
      'updated $successCount/${workspaces.length} workspaces',
    );
    return successCount;
  }

  /// 在单个 workspace 中切换某个 MCP server 的启用/禁用状态
  bool toggleServerInWorkspace(CursorWorkspace workspace, String serverName, bool disabled) {
    final mcpKey = 'user-$serverName';
    final current = getDisabledServers(workspace.dbPath);
    List<String> updated;

    if (disabled) {
      updated = current.contains(mcpKey) ? current : [...current, mcpKey];
    } else {
      updated = current.where((s) => s != mcpKey).toList();
    }

    return _setDisabledServers(workspace.dbPath, updated);
  }

  /// 判断某个 MCP server 在指定 workspace 中是否被禁用
  bool isServerDisabledInWorkspace(CursorWorkspace workspace, String serverName) {
    final mcpKey = 'user-$serverName';
    return getDisabledServers(workspace.dbPath).contains(mcpKey);
  }

  /// 在新窗口打开 Cursor 项目
  Future<bool> openCursorProject(String projectPath) async {
    try {
      final result = await Process.run('cursor', [projectPath, '-n']);
      LoggerService.info(
        'cursor CLI: exit=${result.exitCode}, '
        'stderr=${result.stderr.toString().trim()}',
      );
      return result.exitCode == 0;
    } catch (e) {
      LoggerService.error('Failed to open Cursor project: $e');
      return false;
    }
  }
}
