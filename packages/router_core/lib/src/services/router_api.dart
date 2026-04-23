import '../entities/client_device.dart';
import '../entities/vpn_policy.dart';
import '../entities/wireguard_peer.dart';

abstract interface class RouterApi {
  Future<bool> authenticate({
    required Uri baseUri,
    required String login,
    required String password,
  });

  Future<List<String>> getKeenDnsUrls({
    required Uri baseUri,
    required String login,
    required String password,
  });

  Future<String?> getNetworkIp({
    required Uri baseUri,
    required String login,
    required String password,
  });

  Future<List<VpnPolicy>> getPolicies({
    required Uri baseUri,
    required String login,
    required String password,
  });

  Future<List<ClientDevice>> getClients({
    required Uri baseUri,
    required String login,
    required String password,
  });

  Future<void> applyPolicy({
    required Uri baseUri,
    required String login,
    required String password,
    required String macAddress,
    required String? policyName,
  });

  Future<void> blockClient({
    required Uri baseUri,
    required String login,
    required String password,
    required String macAddress,
  });

  Future<void> wakeOnLan({
    required Uri baseUri,
    required String login,
    required String password,
    required String macAddress,
  });

  Future<List<WireGuardPeer>> getWireGuardPeers({
    required Uri baseUri,
    required String login,
    required String password,
  });
}

