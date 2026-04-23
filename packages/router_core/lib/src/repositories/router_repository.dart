import '../entities/router_profile.dart';

abstract interface class RouterRepository {
  Future<List<RouterProfile>> getRouters();

  Future<RouterProfile?> getRouterById(String id);

  Future<void> saveRouter(RouterProfile profile);

  Future<void> deleteRouter(String id);

  Future<String?> getSelectedRouterId();

  Future<void> setSelectedRouterId(String? id);
}

