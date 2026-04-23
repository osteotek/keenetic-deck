import '../entities/connection_target.dart';
import '../entities/router_profile.dart';

abstract interface class ConnectionResolver {
  Future<ConnectionTarget> resolve(
    RouterProfile profile, {
    required String password,
    required Iterable<String> localIpv4Cidrs,
  });
}

