import 'package:platform_capabilities/platform_capabilities.dart';
import 'package:router_core/router_core.dart';

enum ClientActionKind {
  setDefaultPolicy,
  setNamedPolicy,
  block,
  wakeOnLan,
}

class ClientActionRequest {
  const ClientActionRequest.setDefaultPolicy({
    required this.macAddress,
  })  : kind = ClientActionKind.setDefaultPolicy,
        policyName = null;

  const ClientActionRequest.setNamedPolicy({
    required this.macAddress,
    required this.policyName,
  }) : kind = ClientActionKind.setNamedPolicy;

  const ClientActionRequest.block({
    required this.macAddress,
  })  : kind = ClientActionKind.block,
        policyName = null;

  const ClientActionRequest.wakeOnLan({
    required this.macAddress,
  })  : kind = ClientActionKind.wakeOnLan,
        policyName = null;

  final ClientActionKind kind;
  final String macAddress;
  final String? policyName;
}

class ClientActionService {
  ClientActionService({
    required SecretRepository secretRepository,
    required LocalDeviceInfoService localDeviceInfoService,
    KeeneticRouterApi Function()? apiFactory,
  })  : _secretRepository = secretRepository,
        _localDeviceInfoService = localDeviceInfoService,
        _apiFactory = apiFactory ?? KeeneticRouterApi.new;

  final SecretRepository _secretRepository;
  final LocalDeviceInfoService _localDeviceInfoService;
  final KeeneticRouterApi Function() _apiFactory;

  Future<void> execute({
    required RouterProfile router,
    required ConnectionTarget? connectionTarget,
    required ClientActionRequest request,
  }) async {
    final password = await _secretRepository.readRouterPassword(router.id);
    if (password == null || password.isEmpty) {
      throw const RouterAuthenticationException(
        'No saved password for the selected router.',
      );
    }

    final api = _apiFactory();
    try {
      final target = connectionTarget ??
          await DefaultConnectionResolver(api).resolve(
            router,
            password: password,
            localIpv4Cidrs: await _localDeviceInfoService.getLocalIpv4Cidrs(),
          );

      switch (request.kind) {
        case ClientActionKind.setDefaultPolicy:
          await api.applyPolicy(
            baseUri: target.uri,
            login: router.login,
            password: password,
            macAddress: request.macAddress,
            policyName: null,
          );
          return;
        case ClientActionKind.setNamedPolicy:
          await api.applyPolicy(
            baseUri: target.uri,
            login: router.login,
            password: password,
            macAddress: request.macAddress,
            policyName: request.policyName,
          );
          return;
        case ClientActionKind.block:
          await api.blockClient(
            baseUri: target.uri,
            login: router.login,
            password: password,
            macAddress: request.macAddress,
          );
          return;
        case ClientActionKind.wakeOnLan:
          await api.wakeOnLan(
            baseUri: target.uri,
            login: router.login,
            password: password,
            macAddress: request.macAddress,
          );
          return;
      }
    } finally {
      api.close();
    }
  }
}
