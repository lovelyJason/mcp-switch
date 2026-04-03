import 'package:flutter/material.dart';

/// 来自 marketplace 的 Codex Plugin
class CodexPlugin {
  final String name;
  final String displayName;
  final String shortDescription;
  final String? version;
  final String? category;
  final Color brandColor;
  final String marketplace;
  final String pluginDir;
  final bool isInstalled;

  CodexPlugin({
    required this.name,
    required this.displayName,
    required this.shortDescription,
    this.version,
    this.category,
    Color? brandColor,
    required this.marketplace,
    required this.pluginDir,
    this.isInstalled = false,
  }) : brandColor = brandColor ?? Colors.blueGrey;

  static Color _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.blueGrey;
    final h = hex.replaceFirst('#', '');
    try {
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return Colors.blueGrey;
    }
  }

  factory CodexPlugin.fromJson(
    Map<String, dynamic> manifest, {
    required String marketplace,
    required String pluginDir,
    bool isInstalled = false,
  }) {
    final iface = manifest['interface'] as Map<String, dynamic>? ?? {};
    return CodexPlugin(
      name: manifest['name'] as String? ?? '',
      displayName: iface['displayName'] as String? ?? manifest['name'] as String? ?? '',
      shortDescription: iface['shortDescription'] as String? ?? manifest['description'] as String? ?? '',
      version: manifest['version'] as String?,
      category: iface['category'] as String?,
      brandColor: _parseHex(iface['brandColor'] as String?),
      marketplace: marketplace,
      pluginDir: pluginDir,
      isInstalled: isInstalled,
    );
  }
}
