import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_switch/services/claude_environment_service.dart';

void main() {
  group('ClashVergeService', () {
    test('switches the profile matching the saved display name', () async {
      var written = '';
      final service = ClashVergeService(
        configPath: () => '/tmp/profiles.yaml',
        readFile: (_) async =>
            'current: old\nitems:\n'
            '- uid: abc123\n'
            '  type: local\n'
            '  name: 美国住宅链式\n'
            '- uid: old\n'
            '  type: remote\n'
            '  name: 其他\n',
        writeFile: (_, content) async => written = content,
      );

      await service.switchSubscription('美国住宅链式');
      expect(written, contains('current: abc123'));
    });

    test(
      'reports an unknown subscription instead of selecting another one',
      () async {
        final service = ClashVergeService(
          readFile: (_) async =>
              'current: old\nitems:\n- uid: old\n  name: 其他\n',
        );

        expect(
          () => service.switchSubscription('不存在'),
          throwsA(isA<ClaudeEnvironmentException>()),
        );
      },
    );

    test('lists visible subscription names without exposing URLs', () async {
      final service = ClashVergeService(
        readFile: (_) async =>
            'items:\n'
            '- uid: builtin\n'
            '  type: merge\n'
            '  name: null\n'
            '- uid: abc\n'
            '  name: 美国住宅链式\n'
            '  url: https://secret.example/subscribe\n',
      );

      expect(await service.listSubscriptions(), ['美国住宅链式']);
    });
  });

  group('MacTimezoneService', () {
    test(
      'builds an authorized systemsetup command without password input',
      () async {
        String? executable;
        List<String>? args;
        final service = MacTimezoneService(
          run: (exe, arguments) async {
            executable = exe;
            args = arguments;
            return ProcessResult(1, 0, '', '');
          },
        );

        await service.setTimezone('America/New_York');
        expect(executable, 'osascript');
        expect(args!.join(' '), contains('with administrator privileges'));
        expect(
          args!.join(' '),
          contains('systemsetup -settimezone America/New_York'),
        );
        expect(args!.join(' '), isNot(contains('password')));
      },
    );

    test('rejects shell-injection-shaped timezone values', () async {
      final service = MacTimezoneService(
        run: (_, __) async => ProcessResult(1, 0, '', ''),
      );
      expect(
        () => service.setTimezone('America/New_York; touch /tmp/pwned'),
        throwsA(isA<ClaudeEnvironmentException>()),
      );
    });
  });
}
