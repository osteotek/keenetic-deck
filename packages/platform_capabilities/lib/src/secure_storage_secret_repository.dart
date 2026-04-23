import 'package:router_core/router_core.dart';

import 'secure_key_value_store.dart';

class SecureStorageSecretRepository implements SecretRepository {
  SecureStorageSecretRepository(
    this._store, {
    this.namespace = 'org.osteotek.keenetic_deck',
  });

  final SecureKeyValueStore _store;
  final String namespace;

  @override
  Future<void> deleteRouterPassword(String routerId) {
    return _store.delete(_keyFor(routerId));
  }

  @override
  Future<String?> readRouterPassword(String routerId) {
    return _store.read(_keyFor(routerId));
  }

  @override
  Future<void> writeRouterPassword(String routerId, String password) {
    return _store.write(_keyFor(routerId), password);
  }

  String _keyFor(String routerId) => '$namespace/router_password/$routerId';
}
