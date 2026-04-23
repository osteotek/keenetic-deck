import 'package:flutter_test/flutter_test.dart';
import 'package:platform_capabilities/platform_capabilities.dart';
import 'package:platform_capabilities/src/best_effort_local_device_info_service.dart';

void main() {
  group('BestEffortLocalDeviceInfoService', () {
    test('converts IPv4 addresses into unique /24 CIDRs', () async {
      final service = BestEffortLocalDeviceInfoService(
        ipv4AddressProvider: () async => <String>[
          '192.168.1.20',
          '192.168.1.99',
          '10.0.42.5',
          'invalid',
        ],
      );

      expect(
        await service.getLocalIpv4Cidrs(),
        <String>['10.0.42.0/24', '192.168.1.0/24'],
      );
    });

    test('normalizes and deduplicates mac addresses', () async {
      final service = BestEffortLocalDeviceInfoService(
        ipv4AddressProvider: () async => const <String>[],
        macAddressProvider: () async => <String>[
          'AA:BB:CC:DD:EE:FF',
          'aa:bb:cc:dd:ee:ff',
          ' 11:22:33:44:55:66 ',
        ],
      );

      expect(
        await service.getLocalMacAddresses(),
        <String>['11:22:33:44:55:66', 'aa:bb:cc:dd:ee:ff'],
      );
    });

    test('prefers real CIDRs when they are available', () async {
      final service = BestEffortLocalDeviceInfoService(
        ipv4CidrProvider: () async => <String>[
          '192.168.1.57/24',
          '10.253.28.16/8',
          '192.168.1.57/24',
          'invalid',
        ],
        ipv4AddressProvider: () async => <String>['172.16.5.2'],
      );

      expect(
        await service.getLocalIpv4Cidrs(),
        <String>['10.253.28.16/8', '192.168.1.57/24'],
      );
    });
  });

  group('desktop parser helpers', () {
    test('parses IPv4 CIDRs and MAC addresses from ifconfig output', () {
      const output = '''
lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
\tinet 127.0.0.1 netmask 0xff000000
en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
\tether ba:a2:a2:a0:1a:88
\tinet 192.168.1.57 netmask 0xffffff00 broadcast 192.168.1.255
utun7: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> mtu 1380
\tinet 10.253.28.16 --> 10.253.28.16 netmask 0xff000000
''';

      expect(
        parseIfconfigIpv4Cidrs(output),
        <String>['10.253.28.16/8', '192.168.1.57/24'],
      );
      expect(
        parseIfconfigMacAddresses(output),
        <String>['ba:a2:a2:a0:1a:88'],
      );
    });

    test('parses IPv4 CIDRs and MAC addresses from ip output', () {
      const addrOutput = '''
1: lo    inet 127.0.0.1/8 scope host lo
2: wlan0    inet 192.168.50.23/20 brd 192.168.63.255 scope global wlan0
7: tun0    inet 10.8.0.2/24 scope global tun0
''';
      const linkOutput = '''
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP mode DORMANT group default qlen 1000    link/ether aa:bb:cc:dd:ee:ff brd ff:ff:ff:ff:ff:ff
7: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN mode DEFAULT group default qlen 500    link/ether 12:34:56:78:9a:bc brd ff:ff:ff:ff:ff:ff
''';

      expect(
        parseIpCommandIpv4Cidrs(addrOutput),
        <String>['10.8.0.2/24', '192.168.50.23/20'],
      );
      expect(
        parseIpLinkMacAddresses(linkOutput),
        <String>['12:34:56:78:9a:bc', 'aa:bb:cc:dd:ee:ff'],
      );
    });
  });
}
