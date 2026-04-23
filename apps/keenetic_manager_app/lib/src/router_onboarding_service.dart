import 'package:router_core/router_core.dart';

class RouterOnboardingService {
  RouterOnboardingService({
    KeeneticRouterApi Function()? apiFactory,
  }) : _apiFactory = apiFactory ?? KeeneticRouterApi.new;

  final KeeneticRouterApi Function() _apiFactory;

  Future<RouterProfile> validateAndPrepare({
    required RouterProfile profile,
    required String password,
  }) async {
    final api = _apiFactory();
    final baseUri = _normalizeAddress(profile.address);

    try {
      final authenticated = await api.authenticate(
        baseUri: baseUri,
        login: profile.login,
        password: password,
      );

      if (!authenticated) {
        throw const RouterAuthenticationException(
          'Please check the router address, login, and password.',
        );
      }

      String? networkIp = profile.networkIp;
      List<String> keendnsUrls = profile.keendnsUrls;

      try {
        final discoveredNetworkIp = await api.getNetworkIp(
          baseUri: baseUri,
          login: profile.login,
          password: password,
        );
        if (discoveredNetworkIp != null && discoveredNetworkIp.isNotEmpty) {
          networkIp = discoveredNetworkIp;
        }
      } on RouterApiException {
        // Keep auth success and store the profile even if metadata discovery is partial.
      }

      try {
        final discoveredKeenDnsUrls = await api.getKeenDnsUrls(
          baseUri: baseUri,
          login: profile.login,
          password: password,
        );
        if (discoveredKeenDnsUrls.isNotEmpty) {
          keendnsUrls = discoveredKeenDnsUrls;
        }
      } on RouterApiException {
        // Keep auth success and store the profile even if metadata discovery is partial.
      }

      return profile.copyWith(
        address: _canonicalAddressString(baseUri),
        networkIp: networkIp,
        keendnsUrls: keendnsUrls,
        updatedAt: DateTime.now().toUtc(),
      );
    } finally {
      api.close();
    }
  }
}

Uri _normalizeAddress(String rawAddress) {
  final trimmed = rawAddress.trim();
  final parsed = Uri.tryParse(trimmed);

  if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
    return parsed.replace(
      path: parsed.path == '/' ? '' : parsed.path,
      query: parsed.hasQuery ? parsed.query : null,
      fragment: null,
    );
  }

  if (parsed != null && !parsed.hasScheme && parsed.host.isEmpty && parsed.path.isNotEmpty) {
    return Uri(
      scheme: 'http',
      host: parsed.path,
    );
  }

  return Uri.parse(trimmed.startsWith('http') ? trimmed : 'http://$trimmed');
}

String _canonicalAddressString(Uri uri) {
  final normalized = uri.replace(
    path: uri.path == '/' ? '' : uri.path,
    fragment: null,
  );
  return normalized.toString();
}
