import 'package:router_core/router_core.dart';
import 'package:test/test.dart';

void main() {
  group('DefaultConnectionResolver', () {
    test('prefers the local network IP when the router is in a local CIDR', () async {
      final resolver = DefaultConnectionResolver(_FakeRouterApi());
      final profile = RouterProfile(
        id: 'router-1',
        name: 'Home',
        address: 'https://home.keenetic.link',
        login: 'admin',
        networkIp: '192.168.1.1',
        keendnsUrls: const <String>['home.keenetic.link'],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final target = await resolver.resolve(
        profile,
        password: 'secret',
        localIpv4Cidrs: const <String>['192.168.1.0/24'],
      );

      expect(target.kind, ConnectionTargetKind.localNetwork);
      expect(target.uri.toString(), 'http://192.168.1.1');
    });

    test('falls back to preferred KeenDNS domain when local access fails', () async {
      final resolver = DefaultConnectionResolver(
        _FakeRouterApi(authenticateResult: false),
      );
      final profile = RouterProfile(
        id: 'router-1',
        name: 'Home',
        address: '192.168.1.1',
        login: 'admin',
        networkIp: '10.0.0.1',
        keendnsUrls: const <String>[
          'hash123.keenetic.io',
          'nice-name.keenetic.link',
        ],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final target = await resolver.resolve(
        profile,
        password: 'secret',
        localIpv4Cidrs: const <String>['192.168.1.0/24'],
      );

      expect(target.kind, ConnectionTargetKind.keendns);
      expect(target.uri.toString(), 'https://nice-name.keenetic.link');
    });
  });
}

class _FakeRouterApi implements RouterApi {
  _FakeRouterApi({
    this.authenticateResult = true,
  });

  final bool authenticateResult;

  @override
  Future<bool> authenticate({
    required Uri baseUri,
    required String login,
    required String password,
  }) async {
    return authenticateResult;
  }

  @override
  Future<void> applyPolicy({
    required Uri baseUri,
    required String login,
    required String password,
    required String macAddress,
    required String? policyName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> blockClient({
    required Uri baseUri,
    required String login,
    required String password,
    required String macAddress,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<ClientDevice>> getClients({
    required Uri baseUri,
    required String login,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getKeenDnsUrls({
    required Uri baseUri,
    required String login,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String?> getNetworkIp({
    required Uri baseUri,
    required String login,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<VpnPolicy>> getPolicies({
    required Uri baseUri,
    required String login,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<WireGuardPeer>> getWireGuardPeers({
    required Uri baseUri,
    required String login,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> wakeOnLan({
    required Uri baseUri,
    required String login,
    required String password,
    required String macAddress,
  }) {
    throw UnimplementedError();
  }
}
