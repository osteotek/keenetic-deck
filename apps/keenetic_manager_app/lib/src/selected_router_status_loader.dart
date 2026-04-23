import 'package:platform_capabilities/platform_capabilities.dart';
import 'package:router_core/router_core.dart';

import 'selected_router_status.dart';

class SelectedRouterStatusLoader {
  SelectedRouterStatusLoader({
    required RouterRepository routerRepository,
    required SecretRepository secretRepository,
    required LocalDeviceInfoService localDeviceInfoService,
    KeeneticRouterApi Function()? apiFactory,
  })  : _routerRepository = routerRepository,
        _secretRepository = secretRepository,
        _localDeviceInfoService = localDeviceInfoService,
        _apiFactory = apiFactory ?? KeeneticRouterApi.new;

  final RouterRepository _routerRepository;
  final SecretRepository _secretRepository;
  final LocalDeviceInfoService _localDeviceInfoService;
  final KeeneticRouterApi Function() _apiFactory;

  Future<SelectedRouterStatus> load(RouterProfile router) async {
    final localMacAddresses =
        await _localDeviceInfoService.getLocalMacAddresses();
    final password = await _secretRepository.readRouterPassword(router.id);
    if (password == null || password.isEmpty) {
      return SelectedRouterStatus(
        router: router,
        checkedAt: DateTime.now(),
        hasStoredPassword: false,
        localMacAddresses: localMacAddresses,
        errorMessage: 'No saved password for the selected router.',
      );
    }

    final api = _apiFactory();
    try {
      final metadataRefresher = DefaultRouterMetadataRefresher(api);
      final refreshedRouter = await metadataRefresher.refresh(
        router,
        password: password,
      );
      if (_routerMetadataChanged(router, refreshedRouter)) {
        await _routerRepository.saveRouter(refreshedRouter);
      }

      final resolver = DefaultConnectionResolver(api);
      final target = await resolver.resolve(
        refreshedRouter,
        password: password,
        localIpv4Cidrs: await _localDeviceInfoService.getLocalIpv4Cidrs(),
      );

      final authenticated = await api.authenticate(
        baseUri: target.uri,
        login: refreshedRouter.login,
        password: password,
      );
      if (!authenticated) {
        return SelectedRouterStatus(
          router: refreshedRouter,
          checkedAt: DateTime.now(),
          hasStoredPassword: true,
          connectionTarget: target,
          errorMessage:
              'Authentication failed for the selected connection target.',
        );
      }

      final results = await Future.wait<Object>(<Future<Object>>[
        api.getClients(
          baseUri: target.uri,
          login: refreshedRouter.login,
          password: password,
        ),
        api.getPolicies(
          baseUri: target.uri,
          login: refreshedRouter.login,
          password: password,
        ),
        api.getWireGuardPeers(
          baseUri: target.uri,
          login: refreshedRouter.login,
          password: password,
        ),
      ]);

      final clients = results[0] as List<ClientDevice>;
      final policies = results[1] as List<VpnPolicy>;
      final wireGuardPeers = results[2] as List<WireGuardPeer>;
      final onlineClients = clients
          .where(
            (ClientDevice client) =>
                client.connectionState == ClientConnectionState.online,
          )
          .length;

      return SelectedRouterStatus(
        router: refreshedRouter,
        checkedAt: DateTime.now(),
        hasStoredPassword: true,
        connectionTarget: target,
        isConnected: true,
        localMacAddresses: localMacAddresses,
        clients: clients,
        policies: policies,
        wireGuardPeers: wireGuardPeers,
        clientCount: clients.length,
        onlineClientCount: onlineClients,
        policyCount: policies.length,
        wireGuardPeerCount: wireGuardPeers.length,
      );
    } on RouterApiException catch (error) {
      return SelectedRouterStatus(
        router: router,
        checkedAt: DateTime.now(),
        hasStoredPassword: true,
        localMacAddresses: localMacAddresses,
        errorMessage: error.message,
      );
    } catch (error) {
      return SelectedRouterStatus(
        router: router,
        checkedAt: DateTime.now(),
        hasStoredPassword: true,
        localMacAddresses: localMacAddresses,
        errorMessage: error.toString(),
      );
    } finally {
      api.close();
    }
  }
}

bool _routerMetadataChanged(RouterProfile before, RouterProfile after) {
  if (before.networkIp != after.networkIp) {
    return true;
  }
  if (before.keendnsUrls.length != after.keendnsUrls.length) {
    return true;
  }
  for (var index = 0; index < before.keendnsUrls.length; index += 1) {
    if (before.keendnsUrls[index] != after.keendnsUrls[index]) {
      return true;
    }
  }
  return false;
}
