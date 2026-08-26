import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_switch/data/database.dart';
import 'package:mcp_switch/services/provider_switch_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // service.init() 会经 _isSeedDeleted 读取 SharedPreferences，需初始化 binding + mock
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProviderSwitchService provider names', () {
    late AppDatabase db;
    late ProviderSwitchService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = ProviderSwitchService(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('rejects duplicate provider names within the same editor', () async {
      await service.addProfile(editorType: 'codex', name: 'OpenAI');

      expect(
        () => service.addProfile(editorType: 'codex', name: 'openai'),
        throwsA(isA<DuplicateProviderNameException>()),
      );
    });

    test('allows the same provider name for different editors', () async {
      await service.addProfile(editorType: 'codex', name: 'OpenAI');

      await service.addProfile(editorType: 'claude', name: 'OpenAI');

      expect(service.codexProfiles, hasLength(1));
      expect(service.claudeProfiles, hasLength(1));
    });

    test('allows updating a provider without changing its own name', () async {
      await service.addProfile(editorType: 'codex', name: 'OpenAI');
      final profile = service.codexProfiles.single;

      await service.updateProfile(
        id: profile.id,
        editorType: 'codex',
        name: 'openai',
        description: 'OpenAI Official',
      );

      expect(service.codexProfiles.single.name, 'openai');
    });

    test('keeps the Codex official provider name as OpenAI', () async {
      await service.init();

      final official = service.codexProfiles.singleWhere(
        ProviderSwitchService.isOfficialProfile,
      );

      expect(official.name, 'OpenAI');
      expect(official.description, 'OpenAI Official');
    });
  });

  group('generateCodexPreview model_provider preservation', () {
    late AppDatabase db;
    late ProviderSwitchService service;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = ProviderSwitchService(db);
    });

    tearDown(() async {
      await db.close();
    });

    ProviderProfile officialCodexProfile() => ProviderProfile(
          id: 'p1',
          editorType: 'codex',
          name: 'acc',
          isActive: false,
          isOfficialProvider: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    const existing = 'model = "gpt-5.6-sol"\n'
        'model_provider = "openai_https"\n\n'
        '[model_providers.openai_https]\n'
        'base_url = "https://x.example.com"\n';

    test('preserveExistingProvider=true keeps model_provider and section', () {
      final result = service.generateCodexPreview(
        officialCodexProfile(),
        existingConfigContent: existing,
        preserveExistingProvider: true,
      );
      expect(result, contains('model_provider = "openai_https"'));
      expect(result, contains('[model_providers.openai_https]'));
      expect(result, contains('base_url = "https://x.example.com"'));
    });

    test('default (activation path) still clears third-party provider', () {
      final result = service.generateCodexPreview(
        officialCodexProfile(),
        existingConfigContent: existing,
      );
      expect(result, isNot(contains('model_provider = "openai_https"')));
      expect(result, isNot(contains('[model_providers.openai_https]')));
    });
  });
}
