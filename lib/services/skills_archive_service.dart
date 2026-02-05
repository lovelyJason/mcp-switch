import 'dart:io';
import 'package:archive/archive.dart';
import '../utils/platform_utils.dart';

/// Skills 导入导出服务
/// 负责：压缩、解压 Skills 目录
class SkillsArchiveService {
  /// 用户目录
  String get _home => PlatformUtils.userHome;

  /// Skills 根目录
  String get skillsBasePath => PlatformUtils.joinPath(_home, '.claude', 'skills');

  /// 导出选中的 Skills 到 zip 文件
  /// [skillNames] 要导出的 skill 目录名列表
  /// [outputPath] 输出 zip 文件路径
  /// 返回: (成功, 错误信息)
  Future<(bool, String?)> exportSkills(
    List<String> skillNames,
    String outputPath,
  ) async {
    if (skillNames.isEmpty) {
      return (false, 'no_skills_selected');
    }

    try {
      final archive = Archive();

      for (final skillName in skillNames) {
        final skillDir = Directory(PlatformUtils.joinPath(skillsBasePath, skillName));
        if (!await skillDir.exists()) continue;

        // 递归添加目录下所有文件
        await _addDirectoryToArchive(archive, skillDir, skillName);
      }

      if (archive.isEmpty) {
        return (false, 'no_files_to_export');
      }

      // 压缩并写入文件
      final zipData = ZipEncoder().encode(archive);

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(zipData);

      return (true, null);
    } catch (e) {
      return (false, e.toString());
    }
  }

  /// 递归添加目录到 Archive
  Future<void> _addDirectoryToArchive(
    Archive archive,
    Directory dir,
    String relativePath,
  ) async {
    final entities = await dir.list().toList();

    for (final entity in entities) {
      final name = PlatformUtils.basename(entity.path);
      if (name.startsWith('.')) continue; // 跳过隐藏文件

      final entryPath = '$relativePath/$name';

      if (entity is File) {
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(entryPath, bytes.length, bytes));
      } else if (entity is Directory) {
        await _addDirectoryToArchive(archive, entity, entryPath);
      }
    }
  }

  /// 解压 zip 文件到临时目录，返回包含的 skill 信息
  /// 返回: (skill列表, 错误信息)
  /// 每个 skill 包含: name, hasSkillMd, description, conflictType
  Future<(List<SkillImportInfo>, String?)> extractAndAnalyze(String zipPath) async {
    try {
      final zipFile = File(zipPath);
      if (!await zipFile.exists()) {
        return (<SkillImportInfo>[], 'file_not_found');
      }

      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 分析 archive 中的顶层目录（每个目录是一个 skill）
      final skillDirs = <String>{};
      for (final file in archive) {
        final parts = file.name.split('/');
        if (parts.isNotEmpty && parts[0].isNotEmpty) {
          skillDirs.add(parts[0]);
        }
      }

      final skills = <SkillImportInfo>[];
      for (final skillName in skillDirs) {
        // 检查是否有 SKILL.md
        final hasSkillMd = archive.any(
          (f) => f.name == '$skillName/SKILL.md' || f.name == '$skillName/SKILL.md/',
        );

        // 尝试读取描述
        String? description;
        final skillMdFile = archive.firstWhere(
          (f) => f.name == '$skillName/SKILL.md',
          orElse: () => ArchiveFile('', 0, []),
        );
        if (skillMdFile.name.isNotEmpty) {
          final content = String.fromCharCodes(skillMdFile.content as List<int>);
          description = _parseSkillDescription(content);
        }

        // 检查是否有冲突
        final existingPath = PlatformUtils.joinPath(skillsBasePath, skillName);
        final conflictType = await Directory(existingPath).exists()
            ? SkillConflictType.exists
            : SkillConflictType.none;

        skills.add(SkillImportInfo(
          name: skillName,
          hasSkillMd: hasSkillMd,
          description: description,
          conflictType: conflictType,
        ));
      }

      return (skills, null);
    } catch (e) {
      return (<SkillImportInfo>[], e.toString());
    }
  }

  /// 导入单个 skill
  /// [zipPath] zip 文件路径
  /// [skillName] 要导入的 skill 名称
  /// [resolution] 冲突解决方式
  /// [newName] 重命名时的新名称（仅当 resolution == rename 时使用）
  /// 返回: (成功, 实际导入的名称, 错误信息)
  Future<(bool, String?, String?)> importSkill(
    String zipPath,
    String skillName,
    SkillConflictResolution resolution, {
    String? newName,
  }) async {
    try {
      final zipFile = File(zipPath);
      if (!await zipFile.exists()) {
        return (false, null, 'file_not_found');
      }

      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 确定目标名称
      final targetName = resolution == SkillConflictResolution.rename && newName != null
          ? newName
          : skillName;

      final targetPath = PlatformUtils.joinPath(skillsBasePath, targetName);
      final targetDir = Directory(targetPath);

      // 处理冲突
      if (await targetDir.exists()) {
        switch (resolution) {
          case SkillConflictResolution.skip:
            return (true, targetName, null); // 跳过视为成功
          case SkillConflictResolution.overwrite:
            await targetDir.delete(recursive: true);
            break;
          case SkillConflictResolution.rename:
            // 新名称冲突检查已在 UI 层完成
            break;
        }
      }

      // 确保目标目录存在
      await targetDir.create(recursive: true);

      // 提取文件
      for (final file in archive) {
        if (!file.name.startsWith('$skillName/')) continue;
        if (file.isFile) {
          // 替换原 skillName 为 targetName
          final relativePath = file.name.substring('$skillName/'.length);
          if (relativePath.isEmpty) continue;

          final filePath = PlatformUtils.joinPath(targetPath, relativePath);
          final outputFile = File(filePath);

          // 确保父目录存在
          await outputFile.parent.create(recursive: true);
          await outputFile.writeAsBytes(file.content as List<int>);
        }
      }

      return (true, targetName, null);
    } catch (e) {
      return (false, null, e.toString());
    }
  }

  /// 生成不冲突的新名称
  Future<String> generateNonConflictingName(String baseName) async {
    var counter = 1;
    var newName = '${baseName}_$counter';

    while (await Directory(PlatformUtils.joinPath(skillsBasePath, newName)).exists()) {
      counter++;
      newName = '${baseName}_$counter';
    }

    return newName;
  }

  /// 解析 SKILL.md 中的描述
  String? _parseSkillDescription(String content) {
    final descMatch =
        RegExp(r'^description:\s*(.+)$', multiLine: true).firstMatch(content);
    if (descMatch != null) {
      return descMatch.group(1)?.trim();
    }
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty &&
          !trimmed.startsWith('#') &&
          !trimmed.startsWith('name:') &&
          !trimmed.startsWith('---')) {
        return trimmed.length > 80 ? '${trimmed.substring(0, 80)}...' : trimmed;
      }
    }
    return null;
  }
}

/// Skill 导入信息
class SkillImportInfo {
  final String name;
  final bool hasSkillMd;
  final String? description;
  final SkillConflictType conflictType;

  const SkillImportInfo({
    required this.name,
    required this.hasSkillMd,
    this.description,
    required this.conflictType,
  });
}

/// 冲突类型
enum SkillConflictType {
  none,    // 无冲突
  exists,  // 已存在同名 skill
}

/// 冲突解决方式
enum SkillConflictResolution {
  skip,      // 跳过
  overwrite, // 覆盖
  rename,    // 重命名
}
