#!/usr/bin/env dart
/// DMG 打包脚本
/// 用法: dart run scripts/build_dmg.dart [version]
/// 示例: dart run scripts/build_dmg.dart 1.0.3

import 'dart:io';
import 'package:path/path.dart' as p;

const String appName = 'MCP Switch';
const String bundleName = 'MCP Switch';
const String defaultVersion = '1.0.2';

// ANSI 颜色
const String green = '\x1B[32m';
const String yellow = '\x1B[33m';
const String red = '\x1B[31m';
const String reset = '\x1B[0m';

Future<void> main(List<String> args) async {
  final version = args.isNotEmpty ? args[0] : defaultVersion;

  // 获取项目根目录
  final scriptDir = p.dirname(Platform.script.toFilePath());
  final projectRoot = p.dirname(scriptDir);

  final buildDir = p.join(projectRoot, 'build', 'macos', 'Build', 'Products', 'Release');
  final appPath = p.join(buildDir, '$bundleName.app');
  final outputDir = p.join(projectRoot, 'build', 'dmg');
  final dmgName = '${appName.replaceAll(' ', '-')}-$version.dmg';
  final dmgPath = p.join(outputDir, dmgName);
  final installerDir = p.join(projectRoot, 'installer', 'dmg');
  final backgroundImg = p.join(installerDir, 'background.png');
  final appdmgConfig = p.join(installerDir, 'appdmg.json');

  print('$green╔════════════════════════════════════════╗$reset');
  print('$green║   Creating DMG for $appName v$version   ║$reset');
  print('$green╚════════════════════════════════════════╝$reset');
  print('');

  // 检查前置条件
  print('${yellow}Checking prerequisites...$reset');

  // 检查 appdmg 是否安装
  final appdmgCheck = await Process.run('which', ['appdmg']);
  if (appdmgCheck.exitCode != 0) {
    print('${red}Error: appdmg not found. Install with: npm install -g appdmg$reset');
    exit(1);
  }

  // 检查 app 是否存在
  if (!Directory(appPath).existsSync()) {
    print('${red}Error: App not found at $appPath$reset');
    print('${yellow}Please build the app first: flutter build macos --release$reset');
    exit(1);
  }

  // 检查背景图是否存在
  if (!File(backgroundImg).existsSync()) {
    print('${yellow}Background image not found. Generating...$reset');
    await _generateBackground(installerDir);
  }

  // 创建输出目录
  await Directory(outputDir).create(recursive: true);

  // 删除已存在的 DMG
  final existingDmg = File(dmgPath);
  if (existingDmg.existsSync()) {
    print('${yellow}Removing existing DMG...$reset');
    existingDmg.deleteSync();
  }

  // 更新 appdmg.json 中的路径（相对路径）
  await _updateAppdmgConfig(appdmgConfig, projectRoot);

  // 创建 DMG
  print('${yellow}Creating DMG with appdmg...$reset');
  print('');

  final result = await Process.run(
    'appdmg',
    [appdmgConfig, dmgPath],
    workingDirectory: installerDir,
  );

  stdout.write(result.stdout);
  stderr.write(result.stderr);

  if (result.exitCode != 0) {
    print('');
    print('${red}Error: Failed to create DMG$reset');
    exit(1);
  }

  print('');
  print('$green╔════════════════════════════════════════╗$reset');
  print('$green║          DMG Created Successfully!     ║$reset');
  print('$green╚════════════════════════════════════════╝$reset');
  print('');
  print('Output: $green$dmgPath$reset');
  print('');

  // 显示文件信息
  final fileInfo = await Process.run('ls', ['-lh', dmgPath]);
  print(fileInfo.stdout);

  // 询问是否打开
  stdout.write('Open DMG to verify? (y/n) ');
  final input = stdin.readLineSync();
  if (input?.toLowerCase() == 'y') {
    await Process.run('open', [dmgPath]);
  }
}

/// 生成背景图（调用 Python 脚本）
Future<void> _generateBackground(String installerDir) async {
  final pythonScript = p.join(installerDir, 'create_background.py');
  if (File(pythonScript).existsSync()) {
    final result = await Process.run(
      'python3',
      [pythonScript],
      workingDirectory: installerDir,
    );
    if (result.exitCode != 0) {
      print('${red}Warning: Failed to generate background: ${result.stderr}$reset');
    }
  }
}

/// 更新 appdmg.json 配置
Future<void> _updateAppdmgConfig(String configPath, String projectRoot) async {
  final config = '''{
  "title": "$appName",
  "background": "background.png",
  "icon-size": 100,
  "window": {
    "size": {
      "width": 540,
      "height": 380
    }
  },
  "contents": [
    {
      "x": 135,
      "y": 190,
      "type": "file",
      "path": "../../build/macos/Build/Products/Release/$bundleName.app"
    },
    {
      "x": 405,
      "y": 190,
      "type": "link",
      "path": "/Applications"
    }
  ]
}
''';

  await File(configPath).writeAsString(config);
}
