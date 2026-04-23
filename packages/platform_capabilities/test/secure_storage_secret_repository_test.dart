import 'package:flutter_test/flutter_test.dart';
import 'package:platform_capabilities/platform_capabilities.dart';

void main() {
  group('SecureStorageSecretRepository', () {
    test('namespaces password keys and supports read/write/delete', () async {
      final store = _InMemorySecureKeyValueStore();
      final repository = SecureStorageSecretRepository(
        store,
        namespace: 'test-space',
      );

      await repository.writeRouterPassword('router-1', 'secret');
      expect(
        store.data,
        containsPair('test-space/router_password/router-1', 'secret'),
      );

      expect(await repository.readRouterPassword('router-1'), 'secret');

      await repository.deleteRouterPassword('router-1');
      expect(await repository.readRouterPassword('router-1'), isNull);
    });
  });
}

class _InMemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> data = <String, String>{};

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    return data[key];
  }

  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }
}
