
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_switch/models/editor_type.dart';
import 'package:mcp_switch/models/v2/registry_config.dart';
import 'package:mcp_switch/models/v2/registry_item.dart';
import 'package:mcp_switch/services/adapter_service.dart';

void main() {
  group('AdapterService', () {
    late AdapterService adapterService;
    late RegistryItem sseItem;
    late RegistryItem localItem;

    setUp(() {
      adapterService = AdapterService();

      sseItem = RegistryItem(
        id: 'context7',
        meta: RegistryMeta(type: 'custom', name: 'Context7'),
        mode: 'sse',
        config: SseConfig(
          endpoint: 'https://api.context7.com/sse',
          headers: {'CONTEXT7_API_KEY': 'abc-123'},
        ),
      );

      localItem = RegistryItem(
        id: 'figma',
        meta: RegistryMeta(type: 'system', name: 'Figma'),
        mode: 'local',
        config: LocalConfig(
          command: 'npx',
          args: ['-y', 'figma-mcp'],
          env: {'TOKEN': 'xyz'},
        ),
      );
    });

    test('should generate Windsurf config (serverUrl)', () {
      final result = adapterService.compileConfig([sseItem], EditorType.windsurf);
      final server = result['mcpServers']['context7'];

      expect(server['serverUrl'], 'https://api.context7.com/sse');
      expect(server['headers']['CONTEXT7_API_KEY'], 'abc-123');
      expect(server['type'], isNull); // Windsurf doesn't strictly use type: http
    });

    test('should generate Claude config (type: http)', () {
      final result = adapterService.compileConfig([sseItem], EditorType.claude);
      final server = result['mcpServers']['context7'];

      expect(server['type'], 'http');
      expect(server['url'], 'https://api.context7.com/sse');
      expect(server['headers']['CONTEXT7_API_KEY'], 'abc-123');
    });

    test('should generate Gemini config (httpUrl + Accept header)', () {
      final result = adapterService.compileConfig([sseItem], EditorType.gemini);
      final server = result['mcpServers']['context7'];

      expect(server['httpUrl'], 'https://api.context7.com/sse');
      expect(server['headers']['Accept'], contains('text/event-stream'));
    });

    test('should generate Local config (stdio) for all editors', () {
      final result = adapterService.compileConfig([localItem], EditorType.cursor);
      final server = result['mcpServers']['figma'];

      expect(server['command'], 'npx');
      expect(server['args'], ['-y', 'figma-mcp']);
      expect(server['env']['TOKEN'], 'xyz');
    });
  });
}
