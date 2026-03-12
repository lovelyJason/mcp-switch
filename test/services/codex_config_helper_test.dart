import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_switch/services/config/codex_config_helper.dart';

void main() {
  group('CodexConfigHelper.parseToml', () {
    test('parses stdio MCP server', () {
      const toml = '''
[mcp_servers.my-server]
command = "npx"
args = [
  "-y",
  "@my/mcp-server"
]
''';
      final profiles = CodexConfigHelper.parseToml(toml, []);
      expect(profiles, hasLength(1));
      expect(profiles.first.name, 'my-server');
      final server = profiles.first.content['mcpServers']['my-server'];
      expect(server['command'], 'npx');
      expect(server['args'], ['-y', '@my/mcp-server']);
    });

    test('parses remote (URL) MCP server', () {
      const toml = '''
[mcp_servers.figma-official]
url = "https://mcp.figma.com/mcp"
http_headers = { "X-Figma-Token" = "token123" }
''';
      final profiles = CodexConfigHelper.parseToml(toml, []);
      expect(profiles, hasLength(1));
      final server = profiles.first.content['mcpServers']['figma-official'];
      expect(server['url'], 'https://mcp.figma.com/mcp');
      expect(server['http_headers'], {'X-Figma-Token': 'token123'});
    });

    test('parses disabled server', () {
      const toml = '''
[mcp_servers.disabled-server]
enabled = false
command = "npx"
args = []
''';
      final profiles = CodexConfigHelper.parseToml(toml, []);
      expect(profiles, hasLength(1));
      final server = profiles.first.content['mcpServers']['disabled-server'];
      expect(server['disabled'], true);
    });

    test('parses multiple servers', () {
      const toml = '''
[mcp_servers.server-a]
command = "npx"
args = ["-y", "a"]

[mcp_servers.server-b]
url = "https://example.com/mcp"
''';
      final profiles = CodexConfigHelper.parseToml(toml, []);
      expect(profiles, hasLength(2));
      expect(profiles[0].name, 'server-a');
      expect(profiles[1].name, 'server-b');
    });

    test('preserves IDs from cached profiles', () {
      const toml = '''
[mcp_servers.my-server]
command = "npx"
args = []
''';
      final cached = CodexConfigHelper.parseToml(toml, []);
      final firstId = cached.first.id;

      final reloaded = CodexConfigHelper.parseToml(toml, cached);
      expect(reloaded.first.id, firstId);
    });

    test('handles inline args', () {
      const toml = '''
[mcp_servers.inline-args]
command = "node"
args = ["--flag", "value"]
''';
      final profiles = CodexConfigHelper.parseToml(toml, []);
      final server = profiles.first.content['mcpServers']['inline-args'];
      expect(server['args'], ['--flag', 'value']);
    });

    test('skips comments and empty lines', () {
      const toml = '''
# This is a comment

[mcp_servers.test]
command = "echo"
args = []
''';
      final profiles = CodexConfigHelper.parseToml(toml, []);
      expect(profiles, hasLength(1));
    });
  });

  group('CodexConfigHelper.generateToml', () {
    test('generates stdio server TOML', () {
      final profiles = CodexConfigHelper.parseToml('''
[mcp_servers.my-server]
command = "npx"
args = ["-y", "pkg"]
''', []);
      final toml = CodexConfigHelper.generateToml(profiles);
      expect(toml, contains('[mcp_servers.my-server]'));
      expect(toml, contains('command = "npx"'));
      expect(toml, contains('"-y"'));
      expect(toml, contains('"pkg"'));
    });

    test('generates remote server TOML', () {
      final profiles = CodexConfigHelper.parseToml('''
[mcp_servers.remote]
url = "https://example.com"
http_headers = { "Authorization" = "Bearer tok" }
''', []);
      final toml = CodexConfigHelper.generateToml(profiles);
      expect(toml, contains('url = "https://example.com"'));
      expect(toml, contains('http_headers'));
      expect(toml, contains('"Authorization"'));
    });

    test('generates disabled server with enabled = false', () {
      final profiles = CodexConfigHelper.parseToml('''
[mcp_servers.off]
enabled = false
command = "echo"
args = []
''', []);
      final toml = CodexConfigHelper.generateToml(profiles);
      expect(toml, contains('enabled = false'));
    });

    test('roundtrip: parse then generate preserves data', () {
      const original = '''
[mcp_servers.alpha]
command = "npx"
args = [
  "-y",
  "@org/alpha"
]

[mcp_servers.beta]
url = "https://beta.io/mcp"
http_headers = { "X-Key" = "val" }
''';
      final profiles = CodexConfigHelper.parseToml(original, []);
      final generated = CodexConfigHelper.generateToml(profiles);

      expect(generated, contains('[mcp_servers.alpha]'));
      expect(generated, contains('command = "npx"'));
      expect(generated, contains('"@org/alpha"'));
      expect(generated, contains('[mcp_servers.beta]'));
      expect(generated, contains('url = "https://beta.io/mcp"'));
    });
  });

  group('CodexConfigHelper.parseAuthFromCli', () {
    test('parses stdio table auth status', () {
      // Real format: Name, Command, Args, Env, Cwd, Status, Auth (index 6)
      const output =
          'Name             Command  Args                                   Env  Cwd  Status    Auth\n'
          'figma-developer  npx      -y figma-developer-mcp ... --stdio     -    -    disabled  Unsupported\n'
          'github           npx      -y -- @anthropic/mcp-github@latest     -    -    enabled   Not logged in\n';
      final authMap = CodexConfigHelper.parseAuthFromCli(output);
      expect(authMap['figma-developer'], 'Unsupported');
      expect(authMap['github'], 'Not logged in');
    });

    test('parses http table auth status', () {
      // Real format: Name, Url, Bearer Token Env Var, Status, Auth (index 4)
      const output =
          'Name            Url                        Bearer Token Env Var  Status   Auth\n'
          'figma-official  https://mcp.figma.com/mcp  -                     enabled  Not logged in\n';
      final authMap = CodexConfigHelper.parseAuthFromCli(output);
      expect(authMap['figma-official'], 'Not logged in');
    });

    test('handles empty output', () {
      final authMap = CodexConfigHelper.parseAuthFromCli('');
      expect(authMap, isEmpty);
    });

    test('handles mixed tables', () {
      const output =
          'Name             Command  Args                                   Env  Cwd  Status    Auth\n'
          'server1          npx      -y pkg                                 -    -    enabled   Unsupported\n'
          '\n'
          'Name            Url                        Bearer Token Env Var  Status   Auth\n'
          'server2         https://example.com        -                     enabled  Not logged in\n';
      final authMap = CodexConfigHelper.parseAuthFromCli(output);
      expect(authMap['server1'], 'Unsupported');
      expect(authMap['server2'], 'Not logged in');
    });
  });

  group('CodexConfigHelper utility methods', () {
    test('escapeTomlString escapes backslash and quotes', () {
      expect(CodexConfigHelper.escapeTomlString(r'a\b'), r'a\\b');
      expect(CodexConfigHelper.escapeTomlString('a"b'), r'a\"b');
    });

    test('parseInlineTable extracts key-value pairs', () {
      final result =
          CodexConfigHelper.parseInlineTable('"Key1" = "Val1", "Key2" = "Val2"');
      expect(result, {'Key1': 'Val1', 'Key2': 'Val2'});
    });

    test('stringMapFrom converts Map to String-String', () {
      expect(CodexConfigHelper.stringMapFrom({'a': 1, 'b': true}),
          {'a': '1', 'b': 'true'});
      expect(CodexConfigHelper.stringMapFrom(null), isEmpty);
      expect(CodexConfigHelper.stringMapFrom('not a map'), isEmpty);
    });

    test('detectColumnStarts finds correct positions', () {
      const header = 'Name           Command  Args';
      final starts = CodexConfigHelper.detectColumnStarts(header);
      expect(starts.first, 0);
      expect(starts.length, greaterThanOrEqualTo(3));
    });

    test('splitByColumns splits line by positions', () {
      final starts = [0, 15, 24];
      const line = 'context7       npx      -y -- @upstash/context7';
      final cols = CodexConfigHelper.splitByColumns(line, starts);
      expect(cols[0], 'context7');
      expect(cols[1], 'npx');
      expect(cols[2], '-y -- @upstash/context7');
    });
  });
}
