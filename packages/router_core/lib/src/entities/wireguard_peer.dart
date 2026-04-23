class WireGuardPeer {
  const WireGuardPeer({
    required this.interfaceName,
    required this.peerName,
    this.allowedIps = const <String>[],
    this.endpoint,
    this.isEnabled = true,
  });

  final String interfaceName;
  final String peerName;
  final List<String> allowedIps;
  final String? endpoint;
  final bool isEnabled;
}

