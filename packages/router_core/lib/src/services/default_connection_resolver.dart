import '../entities/connection_target.dart';
import '../entities/router_profile.dart';
import 'connection_resolver.dart';
import 'router_api.dart';

class DefaultConnectionResolver implements ConnectionResolver {
  DefaultConnectionResolver(this._routerApi);

  final RouterApi _routerApi;

  @override
  Future<ConnectionTarget> resolve(
    RouterProfile profile, {
    required String password,
    required Iterable<String> localIpv4Cidrs,
  }) async {
    final inLocalNetwork = _isRouterInLocalNetwork(
      profile.networkIp,
      localIpv4Cidrs,
    );

    if (profile.keendnsUrls.isEmpty && profile.networkIp == null) {
      return _directTarget(profile.address);
    }

    if (inLocalNetwork && profile.networkIp != null) {
      return _localNetworkTarget(profile.networkIp!);
    }

    if (profile.networkIp != null) {
      final networkTarget = _localNetworkTarget(profile.networkIp!);
      final authenticated = await _routerApi.authenticate(
        baseUri: networkTarget.uri,
        login: profile.login,
        password: password,
      );
      if (authenticated) {
        return networkTarget;
      }
    }

    if (profile.keendnsUrls.isNotEmpty) {
      final configuredHost = _extractHost(profile.address);
      if (configuredHost != null &&
          profile.keendnsUrls.contains(configuredHost)) {
        return ConnectionTarget(
          kind: ConnectionTargetKind.keendns,
          uri: _httpsUri(configuredHost, originalAddress: profile.address),
        );
      }

      final preferred = profile.keendnsUrls.firstWhere(
        (domain) => !domain.endsWith('.keenetic.io'),
        orElse: () => profile.keendnsUrls.first,
      );

      return ConnectionTarget(
        kind: ConnectionTargetKind.keendns,
        uri: _httpsUri(preferred),
      );
    }

    if (profile.networkIp != null) {
      return _localNetworkTarget(profile.networkIp!);
    }

    return _directTarget(profile.address);
  }
}

ConnectionTarget _directTarget(String address) {
  return ConnectionTarget(
    kind: ConnectionTargetKind.direct,
    uri: _normalizeAddress(address),
  );
}

ConnectionTarget _localNetworkTarget(String address) {
  return ConnectionTarget(
    kind: ConnectionTargetKind.localNetwork,
    uri: _normalizeAddress(address),
  );
}

Uri _httpsUri(String host, {String? originalAddress}) {
  final original = originalAddress == null ? null : Uri.tryParse(originalAddress);
  if (original != null && original.hasScheme && original.host == host) {
    return original;
  }
  return Uri(
    scheme: 'https',
    host: host,
  );
}

Uri _normalizeAddress(String address) {
  final parsed = Uri.tryParse(address);
  if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
    return parsed;
  }
  if (parsed != null && !parsed.hasScheme && parsed.host.isEmpty && parsed.path.isNotEmpty) {
    return Uri(
      scheme: 'http',
      host: parsed.path,
    );
  }
  return Uri.parse(address.startsWith('http') ? address : 'http://$address');
}

String? _extractHost(String address) {
  final parsed = Uri.tryParse(address);
  if (parsed == null) {
    return null;
  }
  if (parsed.host.isNotEmpty) {
    return parsed.host;
  }
  if (!parsed.hasScheme && parsed.path.isNotEmpty) {
    return parsed.path;
  }
  return null;
}

bool _isRouterInLocalNetwork(String? routerIp, Iterable<String> localCidrs) {
  if (routerIp == null || routerIp.isEmpty) {
    return false;
  }

  final routerValue = _parseIpv4(routerIp);
  if (routerValue == null) {
    return false;
  }

  for (final cidr in localCidrs) {
    final network = _parseIpv4Cidr(cidr);
    if (network == null) {
      continue;
    }
    if ((routerValue & network.mask) == network.network) {
      return true;
    }
  }

  return false;
}

_Ipv4Network? _parseIpv4Cidr(String cidr) {
  final parts = cidr.split('/');
  if (parts.length != 2) {
    return null;
  }

  final ipValue = _parseIpv4(parts[0]);
  final prefixLength = int.tryParse(parts[1]);
  if (ipValue == null || prefixLength == null || prefixLength < 0 || prefixLength > 32) {
    return null;
  }

  final mask = prefixLength == 0 ? 0 : (0xffffffff << (32 - prefixLength)) & 0xffffffff;
  final network = ipValue & mask;
  return _Ipv4Network(network: network, mask: mask);
}

int? _parseIpv4(String value) {
  final octets = value.split('.');
  if (octets.length != 4) {
    return null;
  }

  var result = 0;
  for (final octet in octets) {
    final part = int.tryParse(octet);
    if (part == null || part < 0 || part > 255) {
      return null;
    }
    result = (result << 8) | part;
  }
  return result;
}

class _Ipv4Network {
  const _Ipv4Network({
    required this.network,
    required this.mask,
  });

  final int network;
  final int mask;
}
