import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_switch/models/editor_type.dart';
import 'package:mcp_switch/models/mcp_profile.dart';
import 'package:mcp_switch/services/config/config_service.dart';
import 'package:mcp_switch/services/logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConfigService Codex remote MCP', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LoggerService.init();
      tempDir = await Directory.systemTemp.createTemp('mcp_switch_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<void> configurePaths(ConfigService service) async {
      for (final editor in EditorType.values) {
        final extension = editor == EditorType.codex ? 'toml' : 'json';
        final file = File('${tempDir.path}/${editor.name}.$extension');
        await file.create(recursive: true);
        await file.writeAsString('');
        await service.setConfigPath(editor, file.path);
      }
    }

    test(
      'writes remote Codex MCP as url/http_headers instead of command/args',
      () async {
        final service = ConfigService();
        await configurePaths(service);

        final profile = McpProfile(
          id: 'remote-figma',
          name: 'figma-official',
          description: 'Remote Figma MCP',
          content: {
            'mcpServers': {
              'figma-official': {
                'url': 'https://mcp.figma.com/mcp',
                'http_headers': {'X-Test': 'abc'},
              },
            },
          },
        );

        await service.saveProfile(EditorType.codex, profile);

        final file = File(service.getConfigPath(EditorType.codex));
        final text = await file.readAsString();

        expect(text, contains('[mcp_servers.figma-official]'));
        expect(text, contains('url = "https://mcp.figma.com/mcp"'));
        expect(text, contains('http_headers = { "X-Test" = "abc" }'));
        expect(text, isNot(contains('command = "null"')));
      },
    );

    test('reloads remote Codex MCP from TOML with url and headers', () async {
      final service = ConfigService();
      await configurePaths(service);

      final file = File(service.getConfigPath(EditorType.codex));
      await file.writeAsString(
        '[mcp_servers.figma-official]\n'
        'url = "https://mcp.figma.com/mcp"\n'
        'http_headers = { "X-Test" = "abc" }\n',
      );

      await service.reloadProfiles();

      final profiles = service.getProfiles(EditorType.codex);
      expect(profiles, hasLength(1));
      expect(
        profiles.first.content['mcpServers']['figma-official']['url'],
        'https://mcp.figma.com/mcp',
      );
      expect(
        profiles.first.content['mcpServers']['figma-official']['http_headers'],
        {'X-Test': 'abc'},
      );
    });
  });
}
