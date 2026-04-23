abstract interface class LocalDeviceInfoService {
  Future<List<String>> getLocalIpv4Cidrs();

  Future<List<String>> getLocalMacAddresses();
}
