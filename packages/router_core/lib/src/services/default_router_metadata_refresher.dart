import '../entities/router_profile.dart';
import '../exceptions/router_api_exception.dart';
import 'router_api.dart';
import 'router_metadata_refresher.dart';

class DefaultRouterMetadataRefresher implements RouterMetadataRefresher {
  DefaultRouterMetadataRefresher(this._routerApi);

  final RouterApi _routerApi;

  @override
  Future<RouterProfile> refresh(
    RouterProfile profile, {
    required String password,
  }) async {
    var networkIp = profile.networkIp;
    var keendnsUrls = profile.keendnsUrls;

    try {
      final baseUri = Uri.parse(
        profile.address.startsWith('http') ? profile.address : 'http://${profile.address}',
      );

      final refreshedNetworkIp = await _routerApi.getNetworkIp(
        baseUri: baseUri,
        login: profile.login,
        password: password,
      );
      if (refreshedNetworkIp != null && refreshedNetworkIp.isNotEmpty) {
        networkIp = refreshedNetworkIp;
      }

      final refreshedDns = await _routerApi.getKeenDnsUrls(
        baseUri: baseUri,
        login: profile.login,
        password: password,
      );
      if (refreshedDns.isNotEmpty) {
        keendnsUrls = refreshedDns;
      }
    } on RouterApiException {
      return profile;
    }

    return profile.copyWith(
      networkIp: networkIp,
      keendnsUrls: keendnsUrls,
      updatedAt: DateTime.now(),
    );
  }
}
