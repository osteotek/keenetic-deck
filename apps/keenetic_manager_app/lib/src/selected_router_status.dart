import 'package:router_core/router_core.dart';

class SelectedRouterStatus {
  const SelectedRouterStatus({
    required this.router,
    required this.checkedAt,
    required this.hasStoredPassword,
    this.connectionTarget,
    this.isConnected = false,
    this.localMacAddresses = const <String>[],
    this.clients = const <ClientDevice>[],
    this.policies = const <VpnPolicy>[],
    this.wireGuardPeers = const <WireGuardPeer>[],
    this.clientCount = 0,
    this.onlineClientCount = 0,
    this.policyCount = 0,
    this.wireGuardPeerCount = 0,
    this.errorMessage,
  });

  final RouterProfile router;
  final DateTime checkedAt;
  final bool hasStoredPassword;
  final ConnectionTarget? connectionTarget;
  final bool isConnected;
  final List<String> localMacAddresses;
  final List<ClientDevice> clients;
  final List<VpnPolicy> policies;
  final List<WireGuardPeer> wireGuardPeers;
  final int clientCount;
  final int onlineClientCount;
  final int policyCount;
  final int wireGuardPeerCount;
  final String? errorMessage;
}
