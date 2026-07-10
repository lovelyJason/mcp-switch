import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_switch/data/database.dart';
import 'package:mcp_switch/services/cursor_account_service.dart';

void main() {
  late AppDatabase db;
  late CursorAccountService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = CursorAccountService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('addAccount rejects duplicate names case-insensitively', () async {
    await service.init();
    await service.addAccount(name: 'Work', accessToken: 'token-a');
    expect(
      () => service.addAccount(name: 'work', accessToken: 'token-b'),
      throwsA(isA<DuplicateCursorAccountNameException>()),
    );
  });

  test('activateCursorAccount marks single active row', () async {
    await service.init();
    final id1 = await service.addAccount(name: 'A', accessToken: 't1');
    final id2 = await service.addAccount(name: 'B', accessToken: 't2');

    await db.activateCursorAccount(id1);
    await service.refresh();
    expect(service.activeAccount?.id, id1);

    await db.activateCursorAccount(id2);
    await service.refresh();
    expect(service.activeAccount?.id, id2);

    final all = await db.getAllCursorAccounts();
    expect(all.where((a) => a.isActive).length, 1);
  });

  test('deleteAccount blocks active account', () async {
    await service.init();
    final id = await service.addAccount(name: 'Active', accessToken: 't');
    await db.activateCursorAccount(id);
    await service.refresh();

    expect(
      () => service.deleteAccount(id),
      throwsA(isA<CursorAccountSwitchException>()),
    );
  });
}
