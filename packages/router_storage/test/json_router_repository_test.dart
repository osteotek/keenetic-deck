import 'dart:convert';
import 'dart:io';

import 'package:router_core/router_core.dart';
import 'package:router_storage/router_storage.dart';
import 'package:test/test.dart';

void main() {
  group('JsonRouterRepository', () {
    late Directory tempDir;
    late JsonRouterRepository repository;
    late File storageFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('router_storage_test_');
      storageFile = defaultRouterStorageFile(tempDir);
      repository = JsonRouterRepository(storageFile);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns empty state when storage file does not exist', () async {
      expect(await repository.getRouters(), isEmpty);
      expect(await repository.getSelectedRouterId(), isNull);
    });

    test('saves, updates, selects, and deletes routers', () async {
      final profile = RouterProfile(
        id: 'home-router',
        name: 'Home',
        address: '192.168.1.1',
        login: 'admin',
        networkIp: '192.168.1.1',
        keendnsUrls: const <String>['home.keenetic.link'],
        createdAt: DateTime.utc(2026, 4, 23, 12),
        updatedAt: DateTime.utc(2026, 4, 23, 12),
      );

      await repository.saveRouter(profile);
      await repository.setSelectedRouterId(profile.id);

      final updated = profile.copyWith(
        name: 'Home Updated',
        updatedAt: DateTime.utc(2026, 4, 23, 13),
      );
      await repository.saveRouter(updated);

      final routers = await repository.getRouters();
      expect(routers, hasLength(1));
      expect(routers.single.name, 'Home Updated');
      expect(await repository.getSelectedRouterId(), 'home-router');

      await repository.deleteRouter(profile.id);

      expect(await repository.getRouters(), isEmpty);
      expect(await repository.getSelectedRouterId(), isNull);
    });

    test('writes expected JSON schema to disk', () async {
      final profile = RouterProfile(
        id: 'home-router',
        name: 'Home',
        address: '192.168.1.1',
        login: 'admin',
        createdAt: DateTime.utc(2026, 4, 23, 12),
        updatedAt: DateTime.utc(2026, 4, 23, 12),
      );

      await repository.saveRouter(profile);
      await repository.setSelectedRouterId(profile.id);

      final payload = jsonDecode(await storageFile.readAsString())
          as Map<String, dynamic>;

      expect(payload['version'], 1);
      expect(payload['selected_router_id'], 'home-router');
      expect(payload['routers'], hasLength(1));
      expect((payload['routers'] as List).single['id'], 'home-router');
      expect((payload['routers'] as List).single['created_at'],
          '2026-04-23T12:00:00.000Z');
    });
  });
}
