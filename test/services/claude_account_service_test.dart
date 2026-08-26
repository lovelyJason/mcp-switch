import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_switch/data/database.dart';
import 'package:mcp_switch/services/claude_account_service.dart';
import 'package:mcp_switch/services/claude_environment_service.dart';

/// 一段结构与真实 Keychain token 一致的样例
String sampleToken({String sub = 'max', String org = 'org-123'}) =>
    '{"claudeAiOauth":{"accessToken":"at","refreshToken":"rt",'
    '"subscriptionType":"$sub","scopes":["user:inference"],"expiresAt":1},'
    '"organizationUuid":"$org"}';

void main() {
  late AppDatabase db;
  late ClaudeAccountService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = ClaudeAccountService(db);
  });

  tearDown(() async {
    await db.close();
  });

  // 注意：不调用 service.init()，它会读真实 Keychain。
  // 用 refresh() 加载（空）DB，使测试与钥匙串隔离。

  test('addAccount rejects duplicate names case-insensitively', () async {
    await service.refresh();
    await service.addAccount(name: 'Work', token: sampleToken());
    expect(
      () => service.addAccount(
        name: 'work',
        token: sampleToken(org: 'org-2'),
      ),
      throwsA(isA<DuplicateClaudeAccountNameException>()),
    );
  });

  test(
    'addAccount parses subscriptionType and organizationUuid from token',
    () async {
      await service.refresh();
      final id = await service.addAccount(
        name: 'Personal',
        token: sampleToken(sub: 'pro', org: 'org-abc'),
      );
      final saved = await db.getClaudeAccountById(id);
      expect(saved!.subscriptionType, 'pro');
      expect(saved.organizationUuid, 'org-abc');
      expect(saved.token, contains('accessToken'));
    },
  );

  test('addAccount tolerates non-JSON token (meta null, no throw)', () async {
    await service.refresh();
    final id = await service.addAccount(name: 'Raw', token: 'not-json');
    final saved = await db.getClaudeAccountById(id);
    expect(saved!.subscriptionType, isNull);
    expect(saved.organizationUuid, isNull);
    expect(saved.token, 'not-json');
  });

  test('activateClaudeAccount marks single active row', () async {
    await service.refresh();
    final id1 = await service.addAccount(
      name: 'A',
      token: sampleToken(org: 'o1'),
    );
    final id2 = await service.addAccount(
      name: 'B',
      token: sampleToken(org: 'o2'),
    );

    await db.activateClaudeAccount(id1);
    await service.refresh();
    expect(service.activeAccount?.id, id1);

    await db.activateClaudeAccount(id2);
    await service.refresh();
    expect(service.activeAccount?.id, id2);

    final all = await db.getAllClaudeAccounts();
    expect(all.where((a) => a.isActive).length, 1);
  });

  test('deleteAccount blocks active account', () async {
    await service.refresh();
    final id = await service.addAccount(name: 'Active', token: sampleToken());
    await db.activateClaudeAccount(id);
    await service.refresh();

    expect(
      () => service.deleteAccount(id),
      throwsA(isA<ClaudeAccountSwitchException>()),
    );
  });

  test('renameAccount rejects duplicate names', () async {
    await service.refresh();
    await service.addAccount(
      name: 'A',
      token: sampleToken(org: 'o1'),
    );
    final id2 = await service.addAccount(
      name: 'B',
      token: sampleToken(org: 'o2'),
    );

    expect(
      () => service.renameAccount(id: id2, name: 'a'),
      throwsA(isA<DuplicateClaudeAccountNameException>()),
    );
  });

  test('findByToken matches saved account by organizationUuid', () async {
    await service.refresh();
    final id = await service.addAccount(
      name: 'Work',
      token: sampleToken(org: 'org-xyz'),
    );
    // 同 org 的另一份 token（accessToken 不同，模拟续期）应匹配到同一账号
    final match = service.findByToken(sampleToken(sub: 'pro', org: 'org-xyz'));
    expect(match?.id, id);
    // 不同 org 不匹配
    expect(service.findByToken(sampleToken(org: 'other')), isNull);
  });

  test('refreshAccountToken updates token and subscriptionType', () async {
    await service.refresh();
    final id = await service.addAccount(
      name: 'Acc',
      token: sampleToken(sub: 'pro', org: 'o1'),
    );
    await service.refreshAccountToken(id, sampleToken(sub: 'max', org: 'o1'));
    final saved = await db.getClaudeAccountById(id);
    expect(saved!.subscriptionType, 'max');
  });

  test('addAccount stores accountInfo and emailOf parses email', () async {
    await service.refresh();
    const info =
        '{"userID":"u1","oauthAccount":{"emailAddress":"a@b.com",'
        '"organizationUuid":"o1","organizationName":"Org"}}';
    final id = await service.addAccount(
      name: 'A',
      token: sampleToken(),
      accountInfo: info,
    );
    final saved = await db.getClaudeAccountById(id);
    expect(saved!.accountInfo, info);
    expect(ClaudeAccountService.emailOf(saved), 'a@b.com');
  });

  test(
    'addAccount derives org from accountInfo when token lacks it (2.1.207)',
    () async {
      await service.refresh();
      // 新版插件 token 顶层无 organizationUuid
      const newToken =
          '{"claudeAiOauth":{"accessToken":"at","refreshToken":"rt",'
          '"subscriptionType":"pro","scopes":[]}}';
      const info =
          '{"userID":"u","oauthAccount":'
          '{"emailAddress":"x@y.com","organizationUuid":"org-new"}}';
      final id = await service.addAccount(
        name: 'N',
        token: newToken,
        accountInfo: info,
      );
      final saved = await db.getClaudeAccountById(id);
      // 修复前会是 null（org 只从 token 取），导致 reconcile/切换匹配失败
      expect(saved!.organizationUuid, 'org-new');
    },
  );

  test('emailOf returns null when accountInfo absent', () async {
    await service.refresh();
    final id = await service.addAccount(name: 'B', token: sampleToken());
    final saved = await db.getClaudeAccountById(id);
    expect(ClaudeAccountService.emailOf(saved!), isNull);
  });

  test('isNameAvailable respects excludeId', () async {
    await service.refresh();
    final id = await service.addAccount(name: 'Solo', token: sampleToken());
    expect(service.isNameAvailable('Solo'), isFalse);
    expect(service.isNameAvailable('Solo', excludeId: id), isTrue);
  });

  test('persists environment configuration per account', () async {
    await service.refresh();
    final first = await service.addAccount(
      name: 'First',
      token: sampleToken(org: 'o1'),
      proxySoftware: 'clash_verge',
      proxySubscription: '美国住宅链式',
      timezone: 'America/New_York',
    );
    final second = await service.addAccount(
      name: 'Second',
      token: sampleToken(org: 'o2'),
      proxySoftware: 'clash_verge',
      proxySubscription: '美国住宅2',
      timezone: 'America/Chicago',
    );

    final savedFirst = await db.getClaudeAccountById(first);
    final savedSecond = await db.getClaudeAccountById(second);
    expect(savedFirst!.proxySoftware, 'clash_verge');
    expect(savedFirst.proxySubscription, '美国住宅链式');
    expect(savedFirst.timezone, 'America/New_York');
    expect(savedSecond!.proxySubscription, '美国住宅2');
    expect(savedSecond.timezone, 'America/Chicago');
  });

  test(
    'updates environment configuration without changing account identity',
    () async {
      await service.refresh();
      final id = await service.addAccount(
        name: 'Work',
        token: sampleToken(org: 'o1'),
        proxySoftware: 'clash_verge',
        proxySubscription: '旧订阅',
        timezone: 'America/Chicago',
      );

      await service.updateAccount(
        id: id,
        name: 'Work',
        proxySubscription: const Value('新订阅'),
        timezone: const Value('America/New_York'),
      );

      final saved = await db.getClaudeAccountById(id);
      expect(saved!.proxySoftware, 'clash_verge');
      expect(saved.proxySubscription, '新订阅');
      expect(saved.timezone, 'America/New_York');
      expect(saved.organizationUuid, 'o1');
    },
  );

  test(
    'reports partial environment failure after account activation',
    () async {
      await service.refresh();
      final id = await service.addAccount(
        name: 'Env',
        token: sampleToken(org: 'env-org'),
        proxySoftware: 'clash_verge',
        proxySubscription: '不存在',
        timezone: 'America/New_York',
      );
      final account = await db.getClaudeAccountById(id);
      expect(account, isNotNull);

      final envService = ClaudeAccountService(
        db,
        clashVerge: ClashVergeService(readFile: (_) async => 'current: old\n'),
        macTimezone: MacTimezoneService(
          run: (_, __) async => ProcessResult(1, 1, '', 'denied'),
        ),
      );
      await expectLater(
        envService.applyEnvironment(account!),
        throwsA(
          predicate<ClaudeAccountSwitchException>(
            (e) => e.message.contains('account_switched_environment_failed'),
          ),
        ),
      );
    },
  );

  test('current usage query requires an active account', () async {
    await service.refresh();

    await expectLater(
      service.fetchUsageForCurrentAccount(),
      throwsA(
        predicate<ClaudeAccountSwitchException>(
          (e) => e.message == 'no_current_claude_account',
        ),
      ),
    );
  });
}
