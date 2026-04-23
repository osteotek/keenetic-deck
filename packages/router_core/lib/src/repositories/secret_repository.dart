abstract interface class SecretRepository {
  Future<String?> readRouterPassword(String routerId);

  Future<void> writeRouterPassword(String routerId, String password);

  Future<void> deleteRouterPassword(String routerId);
}

