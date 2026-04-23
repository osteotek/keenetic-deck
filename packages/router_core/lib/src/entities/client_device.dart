enum ClientConnectionState {
  online,
  offline,
  unknown,
}

enum ClientAccessMode {
  allow,
  deny,
  unknown,
}

class ClientDevice {
  const ClientDevice({
    required this.name,
    required this.macAddress,
    this.ipAddress,
    this.policyName,
    this.access = ClientAccessMode.unknown,
    this.isDenied = false,
    this.isPermitted = false,
    this.priority,
    this.connectionState = ClientConnectionState.unknown,
    this.accessPointName,
    this.wifiBand,
    this.signalRssi,
    this.txRateMbps,
    this.encryption,
    this.wirelessMode,
    this.wifiStandard,
    this.spatialStreams,
    this.channelWidthMhz,
    this.ethernetSpeedMbps,
    this.ethernetPort,
  });

  final String name;
  final String macAddress;
  final String? ipAddress;
  final String? policyName;
  final ClientAccessMode access;
  final bool isDenied;
  final bool isPermitted;
  final int? priority;
  final ClientConnectionState connectionState;
  final String? accessPointName;
  final String? wifiBand;
  final int? signalRssi;
  final int? txRateMbps;
  final String? encryption;
  final String? wirelessMode;
  final String? wifiStandard;
  final int? spatialStreams;
  final int? channelWidthMhz;
  final int? ethernetSpeedMbps;
  final int? ethernetPort;

  bool get isWireless =>
      accessPointName != null && accessPointName!.trim().isNotEmpty;
}
