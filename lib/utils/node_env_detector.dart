import 'dart:io';
import 'platform_utils.dart';

/// Node.js 环境检测结果
class NodeEnvInfo {
  final String managerName; // fnm, nvm, volta, n, system, none
  final String? binDir; // global bin 目录
  final String? nodeVersion;
  final bool isAvailable;

  const NodeEnvInfo({
    required this.managerName,
    this.binDir,
    this.nodeVersion,
    this.isAvailable = false,
  });

  static const unavailable = NodeEnvInfo(managerName: 'none');

  /// 根据 npm 包名推断全局安装后的 bin 名称并返回完整路径
  String? resolveGlobalBinPath(String binName) {
    if (binDir == null) return null;
    return PlatformUtils.joinPath(binDir!, binName);
  }
}

/// 检测当前系统的 Node.js 环境
class NodeEnvDetector {
  /// 按优先级检测 Node 版本管理器，返回第一个可用的
  static Future<NodeEnvInfo> detect() async {
    final detectors = [
      _detectFnm,
      _detectNvm,
      _detectVolta,
      _detectN,
      _detectSystemNode,
    ];

    for (final detector in detectors) {
      final result = await detector();
      if (result.isAvailable) return result;
    }

    return NodeEnvInfo.unavailable;
  }

  static Future<NodeEnvInfo> _detectFnm() async {
    try {
      final home = PlatformUtils.userHome;
      String binDir;

      if (Platform.isMacOS || Platform.isLinux) {
        // fnm default alias bin 目录（稳定路径，不依赖 session）
        final fnmBase = PlatformUtils.joinPath(
          home, '.local', 'share', 'fnm', 'aliases',
        );
        binDir = PlatformUtils.joinPath(fnmBase, 'default', 'bin');
      } else {
        // Windows: %APPDATA%\fnm\aliases\default
        final appData = Platform.environment['APPDATA'] ?? '';
        if (appData.isEmpty) return const NodeEnvInfo(managerName: 'fnm');
        binDir = PlatformUtils.joinPath(appData, 'fnm', 'aliases', 'default');
      }

      final dir = Directory(binDir);
      if (!await dir.exists()) return const NodeEnvInfo(managerName: 'fnm');

      final nodeExe = Platform.isWindows ? 'node.exe' : 'node';
      final nodePath = PlatformUtils.joinPath(binDir, nodeExe);
      if (!await File(nodePath).exists()) {
        return const NodeEnvInfo(managerName: 'fnm');
      }

      final version = await _getNodeVersion(nodePath);
      return NodeEnvInfo(
        managerName: 'fnm',
        binDir: binDir,
        nodeVersion: version,
        isAvailable: true,
      );
    } catch (_) {
      return const NodeEnvInfo(managerName: 'fnm');
    }
  }

  static Future<NodeEnvInfo> _detectNvm() async {
    try {
      final home = PlatformUtils.userHome;
      String nvmDir;

      if (Platform.isMacOS || Platform.isLinux) {
        nvmDir = Platform.environment['NVM_DIR'] ??
            PlatformUtils.joinPath(home, '.nvm');
      } else {
        // Windows: nvm-windows uses %APPDATA%\nvm or %NVM_HOME%
        nvmDir = Platform.environment['NVM_HOME'] ??
            PlatformUtils.joinPath(
              Platform.environment['APPDATA'] ?? '', 'nvm',
            );
      }

      if (!await Directory(nvmDir).exists()) {
        return const NodeEnvInfo(managerName: 'nvm');
      }

      String binDir;
      if (Platform.isMacOS || Platform.isLinux) {
        // nvm: ~/.nvm/versions/node/<version>/bin
        // Find current default via alias
        final aliasFile = File(
          PlatformUtils.joinPath(nvmDir, 'alias', 'default'),
        );
        if (!await aliasFile.exists()) {
          return const NodeEnvInfo(managerName: 'nvm');
        }
        final alias = (await aliasFile.readAsString()).trim();
        // Resolve alias to actual version
        final versionsDir = Directory(
          PlatformUtils.joinPath(nvmDir, 'versions', 'node'),
        );
        if (!await versionsDir.exists()) {
          return const NodeEnvInfo(managerName: 'nvm');
        }
        String? matchedVersion;
        await for (final entry in versionsDir.list()) {
          if (entry is Directory) {
            final name = PlatformUtils.basename(entry.path);
            if (name.startsWith('v$alias') || name == alias) {
              matchedVersion = name;
              break;
            }
          }
        }
        if (matchedVersion == null) {
          // Try partial match
          await for (final entry in versionsDir.list()) {
            if (entry is Directory) {
              final name = PlatformUtils.basename(entry.path);
              if (name.startsWith('v$alias')) {
                matchedVersion = name;
                break;
              }
            }
          }
        }
        if (matchedVersion == null) {
          return const NodeEnvInfo(managerName: 'nvm');
        }
        binDir = PlatformUtils.joinPath(
          nvmDir, 'versions', 'node', matchedVersion, 'bin',
        );
      } else {
        // nvm-windows: symlink at NVM_SYMLINK or default path
        final symlink = Platform.environment['NVM_SYMLINK'] ??
            'C:\\Program Files\\nodejs';
        binDir = symlink;
      }

      final dir = Directory(binDir);
      if (!await dir.exists()) return const NodeEnvInfo(managerName: 'nvm');

      final nodeExe = Platform.isWindows ? 'node.exe' : 'node';
      final nodePath = PlatformUtils.joinPath(binDir, nodeExe);
      if (!await File(nodePath).exists()) {
        return const NodeEnvInfo(managerName: 'nvm');
      }

      final version = await _getNodeVersion(nodePath);
      return NodeEnvInfo(
        managerName: 'nvm',
        binDir: binDir,
        nodeVersion: version,
        isAvailable: true,
      );
    } catch (_) {
      return const NodeEnvInfo(managerName: 'nvm');
    }
  }

  static Future<NodeEnvInfo> _detectVolta() async {
    try {
      final home = PlatformUtils.userHome;
      String binDir;

      if (Platform.isMacOS || Platform.isLinux) {
        binDir = PlatformUtils.joinPath(home, '.volta', 'bin');
      } else {
        final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
        if (localAppData.isEmpty) return const NodeEnvInfo(managerName: 'volta');
        binDir = PlatformUtils.joinPath(localAppData, 'Volta', 'bin');
      }

      final dir = Directory(binDir);
      if (!await dir.exists()) return const NodeEnvInfo(managerName: 'volta');

      final nodeExe = Platform.isWindows ? 'node.exe' : 'node';
      final nodePath = PlatformUtils.joinPath(binDir, nodeExe);
      if (!await File(nodePath).exists()) {
        return const NodeEnvInfo(managerName: 'volta');
      }

      final version = await _getNodeVersion(nodePath);
      return NodeEnvInfo(
        managerName: 'volta',
        binDir: binDir,
        nodeVersion: version,
        isAvailable: true,
      );
    } catch (_) {
      return const NodeEnvInfo(managerName: 'volta');
    }
  }

  static Future<NodeEnvInfo> _detectN() async {
    try {
      if (Platform.isWindows) return const NodeEnvInfo(managerName: 'n');

      // n installs to N_PREFIX/bin or /usr/local/bin
      final prefix = Platform.environment['N_PREFIX'] ?? '/usr/local';
      final binDir = PlatformUtils.joinPath(prefix, 'bin');

      final nodePath = PlatformUtils.joinPath(binDir, 'node');
      if (!await File(nodePath).exists()) {
        return const NodeEnvInfo(managerName: 'n');
      }

      // Verify it's managed by n (check n binary exists)
      final nPath = PlatformUtils.joinPath(binDir, 'n');
      if (!await File(nPath).exists()) {
        return const NodeEnvInfo(managerName: 'n');
      }

      final version = await _getNodeVersion(nodePath);
      return NodeEnvInfo(
        managerName: 'n',
        binDir: binDir,
        nodeVersion: version,
        isAvailable: true,
      );
    } catch (_) {
      return const NodeEnvInfo(managerName: 'n');
    }
  }

  static Future<NodeEnvInfo> _detectSystemNode() async {
    try {
      final result = await PlatformUtils.runCommand(
        Platform.isWindows ? 'where node' : 'which node',
      );

      if (result.exitCode != 0) {
        return const NodeEnvInfo(managerName: 'system');
      }

      final nodePath = (result.stdout as String).trim().split('\n').first;
      if (nodePath.isEmpty) return const NodeEnvInfo(managerName: 'system');

      final binDir = File(nodePath).parent.path;
      final version = await _getNodeVersion(nodePath);

      return NodeEnvInfo(
        managerName: 'system',
        binDir: binDir,
        nodeVersion: version,
        isAvailable: true,
      );
    } catch (_) {
      return const NodeEnvInfo(managerName: 'system');
    }
  }

  static Future<String?> _getNodeVersion(String nodePath) async {
    try {
      final result = await Process.run(nodePath, ['--version']);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } catch (_) {}
    return null;
  }
}
