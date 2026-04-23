import 'package:flutter_test/flutter_test.dart';
import 'package:keenetic_manager_app/src/router_onboarding_service.dart';
import 'package:router_core/router_core.dart';

void main() {
  group('RouterOnboardingService', () {
    test('normalizes the address and enriches discovered metadata', () async {
      final api = _FakeRouterApi(
        authenticateResult: true,
        networkIp: '192.168.1.1',
        keenDnsUrls: const <String>['home.keenetic.link'],
      );
      final service = RouterOnboardingService(
        apiFactory: () => api,
      );

      final prepared = await service.validateAndPrepare(
        profile: RouterProfile(
          id: 'home',
          name: 'Home',
          address: '192.168.1.1',
          login: 'admin',
          createdAt: DateTime.utc(2026, 4, 23),
          updatedAt: DateTime.utc(2026, 4, 23),
        ),
        password: 'secret',
      );

      expect(prepared.address, 'http://192.168.1.1');
      expect(prepared.networkIp, '192.168.1.1');
      expect(prepared.keendnsUrls, <String>['home.keenetic.link']);
      expect(api.closed, isTrue);
    });

    test('throws when authentication fails', () async {
      final service = RouterOnboardingService(
        apiFactory: () => _FakeRouterApi(authenticateResult: false),
      );

      expect(
        () => service.validateAndPrepare(
          profile: RouterProfile(
            id: 'home',
            name: 'Home',
            address: 'router.local',
            login: 'admin',
            createdAt: DateTime.utc(2026, 4, 23),
            updatedAt: DateTime.utc(2026, 4, 23),
          ),
          password: 'bad-secret',
        ),
        throwsA(isA<RouterAuthenticationException>()),
      );
    });
  });
}

class _FakeRouterApi extends KeeneticRouterApi {
  _FakeRouterApi({
    required this.authenticateResult,
    this.networkIp,
    this.keenDnsUrls = const <String>[],
  });

  final bool authenticateResult;
  final String? networkIp;
  final List<String> keenDnsUrls;
  bool closed = false;

  @override
  Future<bool> authenticate({
    required Uri baseUri,
    required String login,
    required String password,
  }) async {
    return authenticateResult;
  }

  @override
  Future<List<String>> getKeenDnsUrls({
    required Uri baseUri,
    required String login,
    required String password,
  }) async {
    return keenDnsUrls;
  }

  @override
  Future<String?> getNetworkIp({
    required Uri baseUri,
    required String login,
    required String password,
  }) async {
    return networkIp;
  }

  @override
  void close() {
    closed = true;
  }
}
