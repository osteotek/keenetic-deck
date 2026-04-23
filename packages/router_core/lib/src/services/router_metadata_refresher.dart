import '../entities/router_profile.dart';

abstract interface class RouterMetadataRefresher {
  Future<RouterProfile> refresh(
    RouterProfile profile, {
    required String password,
  });
}

