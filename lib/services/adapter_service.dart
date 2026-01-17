
import '../models/v2/registry_item.dart';
import '../models/v2/registry_config.dart';
import '../models/editor_type.dart';

class AdapterService {
  /// Compiles a list of [RegistryItem]s into a map of "mcpServers" configuration
  /// specific to the [targetEditor].
  Map<String, dynamic> compileConfig(
    List<RegistryItem> items,
    EditorType targetEditor,
  ) {
    final mcpServers = <String, dynamic>{};

    for (var item in items) {
      mcpServers[item.id] = _generateServerConfig(item, targetEditor);
    }

    return {'mcpServers': mcpServers};
  }

  /// Generates the configuration map for a single [RegistryItem] based on [targetEditor].
  Map<String, dynamic> _generateServerConfig(
    RegistryItem item,
    EditorType targetEditor,
  ) {
    final config = item.config;

    if (item.mode == 'sse' && config is SseConfig) {
      return _generateSseConfig(config, targetEditor);
    } else if (item.mode == 'local' && config is LocalConfig) {
      return _generateLocalConfig(config, targetEditor);
    } else {
      // Fallback or error handling for mismatched mode/config
      return {};
    }
  }

  Map<String, dynamic> _generateSseConfig(
    SseConfig config,
    EditorType targetEditor,
  ) {
    switch (targetEditor) {
      case EditorType.windsurf:
      case EditorType.antigravity:
      case EditorType.cursor: // Valid assumption: New Cursor versions might support this or standard http
        return {
          'serverUrl': config.endpoint,
          'headers': config.headers,
        };

      case EditorType.claude:
      case EditorType.codex: // Logic typically matches Claude/VSCode
        return {
          'type': 'http',
          'url': config.endpoint,
          'headers': config.headers,
        };

      case EditorType.gemini:
        // Gemini often requires specific Accept headers for SSE
        final headers = Map<String, String>.from(config.headers);
        if (!headers.containsKey('Accept')) {
          headers['Accept'] = 'application/json, text/event-stream';
        }
        return {
          'httpUrl': config.endpoint,
          'headers': headers,
        };
    }
  }

  Map<String, dynamic> _generateLocalConfig(
    LocalConfig config,
    EditorType targetEditor,
  ) {
    // Local (stdio) configuration is generally standard across editors
    return {
      'command': config.command,
      'args': config.args,
      'env': config.env,
    };
  }
}
