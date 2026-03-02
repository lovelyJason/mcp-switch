import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// 项目类型枚举
enum ProjectType {
  flutter,
  wechatMiniProgram,
  nuxt,
  next,
  vue,
  react,
  angular,
  node,
  rust,
  go,
  python,
  unknown,
}

/// 检测结果：项目类型 + 可选的 favicon 路径
class ProjectIconInfo {
  final ProjectType type;
  final String? faviconPath;

  const ProjectIconInfo({required this.type, this.faviconPath});
}

/// 项目类型检测器
class ProjectTypeDetector {
  /// 检测项目类型并查找 favicon
  static Future<ProjectIconInfo> detect(String projectDir) async {
    final dir = Directory(projectDir);
    if (!await dir.exists()) {
      return const ProjectIconInfo(type: ProjectType.unknown);
    }

    // 优先查找 favicon
    final favicon = await _findFavicon(projectDir);

    // 检测项目类型（按优先级排列）
    final type = await _detectType(projectDir);

    return ProjectIconInfo(type: type, faviconPath: favicon);
  }

  /// 查找项目中的 favicon 文件
  static Future<String?> _findFavicon(String dir) async {
    final candidates = [
      'public/favicon.ico',
      'public/favicon.png',
      'public/logo.png',
      'src/assets/logo.png',
      'web/favicon.png',
      'web/icons/Icon-192.png',
      'assets/images/logo.png',
      'static/favicon.ico',
    ];
    for (final rel in candidates) {
      final f = File(p.join(dir, rel));
      if (await f.exists()) return f.path;
    }
    return null;
  }

  /// 根据特征文件检测项目类型
  static Future<ProjectType> _detectType(String dir) async {
    bool has(String name) => File(p.join(dir, name)).existsSync();

    // Flutter
    if (has('pubspec.yaml')) return ProjectType.flutter;

    // 微信小程序
    if (has('project.config.json') || has('project.private.config.json')) {
      return ProjectType.wechatMiniProgram;
    }
    if (has('app.json') && has('app.wxss')) {
      return ProjectType.wechatMiniProgram;
    }

    // Nuxt
    if (has('nuxt.config.ts') || has('nuxt.config.js')) {
      return ProjectType.nuxt;
    }

    // Next.js
    if (has('next.config.js') ||
        has('next.config.ts') ||
        has('next.config.mjs')) {
      return ProjectType.next;
    }

    // Angular
    if (has('angular.json')) return ProjectType.angular;

    // Vue (非 Nuxt)
    if (has('vue.config.js') || has('vite.config.ts') || has('vite.config.js')) {
      // vite 可能是 React 项目，检查 package.json
      if (has('package.json')) {
        final pkg = await File(p.join(dir, 'package.json')).readAsString();
        if (pkg.contains('"vue"') || pkg.contains('"@vue/')) {
          return ProjectType.vue;
        }
        if (pkg.contains('"react"') || pkg.contains('"@react')) {
          return ProjectType.react;
        }
      }
      return ProjectType.vue; // vite 默认归 vue
    }

    // Rust
    if (has('Cargo.toml')) return ProjectType.rust;

    // Go
    if (has('go.mod')) return ProjectType.go;

    // Python
    if (has('pyproject.toml') ||
        has('requirements.txt') ||
        has('setup.py')) {
      return ProjectType.python;
    }

    // React (CRA / 通用)
    if (has('package.json')) {
      final pkg = await File(p.join(dir, 'package.json')).readAsString();
      if (pkg.contains('"react"')) return ProjectType.react;
      return ProjectType.node;
    }

    return ProjectType.unknown;
  }

  /// 获取项目类型对应的图标
  static IconData getIcon(ProjectType type) {
    switch (type) {
      case ProjectType.flutter:
        return Icons.flutter_dash;
      case ProjectType.wechatMiniProgram:
        return Icons.chat_bubble;
      case ProjectType.nuxt:
      case ProjectType.next:
        return Icons.dns;
      case ProjectType.vue:
        return Icons.change_history;
      case ProjectType.react:
        return Icons.hub_outlined;
      case ProjectType.angular:
        return Icons.all_inclusive;
      case ProjectType.node:
        return Icons.javascript;
      case ProjectType.rust:
        return Icons.settings;
      case ProjectType.go:
        return Icons.speed;
      case ProjectType.python:
        return Icons.code;
      case ProjectType.unknown:
        return Icons.folder_open;
    }
  }

  /// 获取项目类型对应的颜色
  static Color getColor(ProjectType type) {
    switch (type) {
      case ProjectType.flutter:
        return const Color(0xFF54C5F8); // Flutter 蓝
      case ProjectType.wechatMiniProgram:
        return const Color(0xFF07C160); // 微信绿
      case ProjectType.nuxt:
        return const Color(0xFF00DC82); // Nuxt 绿
      case ProjectType.next:
        return Colors.white70;
      case ProjectType.vue:
        return const Color(0xFF42B883); // Vue 绿
      case ProjectType.react:
        return const Color(0xFF61DAFB); // React 蓝
      case ProjectType.angular:
        return const Color(0xFFDD0031); // Angular 红
      case ProjectType.node:
        return const Color(0xFF339933); // Node 绿
      case ProjectType.rust:
        return const Color(0xFFDEA584); // Rust 橙
      case ProjectType.go:
        return const Color(0xFF00ADD8); // Go 蓝
      case ProjectType.python:
        return const Color(0xFF3776AB); // Python 蓝
      case ProjectType.unknown:
        return Colors.grey;
    }
  }
}
