import 'dart:io';

import 'local_device_info_service.dart';

typedef LocalIpv4CidrProvider = Future<List<String>> Function();
typedef LocalIpv4AddressProvider = Future<List<String>> Function();
typedef LocalMacAddressProvider = Future<List<String>> Function();
typedef CommandOutputProvider = Future<String?> Function(
  String executable,
  List<String> arguments,
);

class BestEffortLocalDeviceInfoService implements LocalDeviceInfoService {
  BestEffortLocalDeviceInfoService({
    LocalIpv4CidrProvider? ipv4CidrProvider,
    LocalIpv4AddressProvider? ipv4AddressProvider,
    LocalMacAddressProvider? macAddressProvider,
  })  : _ipv4CidrProvider = ipv4CidrProvider ??
            (ipv4AddressProvider == null
                ? _emptyIpv4CidrProvider
                : () async {
                    final addresses = await ipv4AddressProvider();
                    return addresses
                        .map(_bestEffortCidrFor)
                        .whereType<String>()
                        .toList(growable: false);
                  }),
        _ipv4AddressProvider = ipv4AddressProvider ?? _emptyIpv4AddressProvider,
        _macAddressProvider = macAddressProvider ?? _emptyMacAddressProvider;

  factory BestEffortLocalDeviceInfoService.system({
    CommandOutputProvider? commandOutputProvider,
  }) {
    final provider = commandOutputProvider ?? _runCommandOutput;
    return BestEffortLocalDeviceInfoService(
      ipv4CidrProvider: () => _systemIpv4Cidrs(
        commandOutputProvider: provider,
      ),
      ipv4AddressProvider: _systemIpv4Addresses,
      macAddressProvider: () => _systemMacAddresses(
        commandOutputProvider: provider,
      ),
    );
  }

  final LocalIpv4CidrProvider _ipv4CidrProvider;
  final LocalIpv4AddressProvider _ipv4AddressProvider;
  final LocalMacAddressProvider _macAddressProvider;

  @override
  Future<List<String>> getLocalIpv4Cidrs() async {
    final cidrs = <String>{
      ...await _ipv4CidrProvider(),
    };

    if (cidrs.isEmpty) {
      final addresses = await _ipv4AddressProvider();
      cidrs.addAll(
        addresses.map(_bestEffortCidrFor).whereType<String>(),
      );
    }

    final normalized = cidrs
        .map((String cidr) => cidr.trim())
        .where((String cidr) => _parseIpv4Cidr(cidr) != null)
        .toSet()
        .toList(growable: false)
      ..sort();
    return normalized;
  }

  @override
  Future<List<String>> getLocalMacAddresses() async {
    final macAddresses = await _macAddressProvider();
    final normalized = macAddresses
        .map(_normalizeMacAddress)
        .whereType<String>()
        .toSet()
        .toList(growable: false)
      ..sort();
    return normalized;
  }
}

Future<List<String>> _systemIpv4Cidrs({
  required CommandOutputProvider commandOutputProvider,
}) async {
  if (Platform.isMacOS || Platform.isIOS) {
    final output = await commandOutputProvider('ifconfig', <String>['-a']);
    final cidrs =
        output == null ? const <String>[] : parseIfconfigIpv4Cidrs(output);
    if (cidrs.isNotEmpty) {
      return cidrs;
    }
  }

  if (Platform.isLinux || Platform.isAndroid) {
    final output = await commandOutputProvider(
      'ip',
      const <String>['-o', '-f', 'inet', 'addr', 'show'],
    );
    final cidrs =
        output == null ? const <String>[] : parseIpCommandIpv4Cidrs(output);
    if (cidrs.isNotEmpty) {
      return cidrs;
    }
  }

  return const <String>[];
}

Future<List<String>> _systemMacAddresses({
  required CommandOutputProvider commandOutputProvider,
}) async {
  if (Platform.isMacOS || Platform.isIOS) {
    final output = await commandOutputProvider('ifconfig', <String>['-a']);
    final macs =
        output == null ? const <String>[] : parseIfconfigMacAddresses(output);
    if (macs.isNotEmpty) {
      return macs;
    }
  }

  if (Platform.isLinux || Platform.isAndroid) {
    final output =
        await commandOutputProvider('ip', const <String>['-o', 'link', 'show']);
    final macs =
        output == null ? const <String>[] : parseIpLinkMacAddresses(output);
    if (macs.isNotEmpty) {
      return macs;
    }
  }

  return const <String>[];
}

Future<List<String>> _systemIpv4Addresses() async {
  final interfaces = await NetworkInterface.list(
    includeLoopback: false,
    includeLinkLocal: false,
    type: InternetAddressType.IPv4,
  );

  final addresses = <String>[];
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      final value = address.address;
      if (value.isNotEmpty) {
        addresses.add(value);
      }
    }
  }
  return addresses;
}

Future<List<String>> _emptyIpv4CidrProvider() async => const <String>[];
Future<List<String>> _emptyIpv4AddressProvider() async => const <String>[];
Future<List<String>> _emptyMacAddressProvider() async => const <String>[];

Future<String?> _runCommandOutput(
  String executable,
  List<String> arguments,
) async {
  try {
    final result = await Process.run(executable, arguments);
    if (result.exitCode != 0) {
      return null;
    }

    final stdout = result.stdout;
    if (stdout is String) {
      return stdout;
    }
    return stdout?.toString();
  } on ProcessException {
    return null;
  }
}

List<String> parseIfconfigIpv4Cidrs(String output) {
  final cidrs = <String>{};
  var currentInterface = '';
  var currentIsLoopback = false;

  for (final rawLine in output.split('\n')) {
    final line = rawLine.trimRight();
    final headerMatch = RegExp(r'^([^\s:]+):\s+flags=').firstMatch(line);
    if (headerMatch != null) {
      currentInterface = headerMatch.group(1) ?? '';
      currentIsLoopback = line.contains('LOOPBACK');
      continue;
    }

    if (currentInterface.isEmpty || currentIsLoopback) {
      continue;
    }

    final inetMatch = RegExp(
      r'^\s*inet\s+(\d+\.\d+\.\d+\.\d+)(?:\s+-->\s+\d+\.\d+\.\d+\.\d+)?\s+netmask\s+(0x[0-9a-fA-F]+|\d+\.\d+\.\d+\.\d+)',
    ).firstMatch(line);
    if (inetMatch == null) {
      continue;
    }

    final address = inetMatch.group(1)!;
    final prefixLength = _parseNetmaskPrefixLength(inetMatch.group(2)!);
    if (!_isUsableIpv4(address) || prefixLength == null) {
      continue;
    }
    cidrs.add('$address/$prefixLength');
  }

  final sorted = cidrs.toList(growable: false)..sort();
  return sorted;
}

List<String> parseIpCommandIpv4Cidrs(String output) {
  final cidrs = <String>{};

  for (final rawLine in output.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }

    final match = RegExp(
      r'^\d+:\s+([^ ]+)\s+inet\s+(\d+\.\d+\.\d+\.\d+/\d+)\b',
    ).firstMatch(line);
    if (match == null) {
      continue;
    }

    final interfaceName = match.group(1)!;
    final cidr = match.group(2)!;
    final address = cidr.split('/').first;
    if (interfaceName == 'lo' || !_isUsableIpv4(address)) {
      continue;
    }
    if (_parseIpv4Cidr(cidr) != null) {
      cidrs.add(cidr);
    }
  }

  final sorted = cidrs.toList(growable: false)..sort();
  return sorted;
}

List<String> parseIfconfigMacAddresses(String output) {
  final macs = <String>{};
  var currentInterface = '';
  var currentIsLoopback = false;

  for (final rawLine in output.split('\n')) {
    final line = rawLine.trimRight();
    final headerMatch = RegExp(r'^([^\s:]+):\s+flags=').firstMatch(line);
    if (headerMatch != null) {
      currentInterface = headerMatch.group(1) ?? '';
      currentIsLoopback = line.contains('LOOPBACK');
      continue;
    }

    if (currentInterface.isEmpty || currentIsLoopback) {
      continue;
    }

    final match = RegExp(
      r'^\s*ether\s+([0-9a-fA-F:]{17})\b',
    ).firstMatch(line);
    if (match == null) {
      continue;
    }

    final normalized = _normalizeMacAddress(match.group(1)!);
    if (normalized != null) {
      macs.add(normalized);
    }
  }

  final sorted = macs.toList(growable: false)..sort();
  return sorted;
}

List<String> parseIpLinkMacAddresses(String output) {
  final macs = <String>{};

  for (final rawLine in output.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }

    final match = RegExp(
      r'^\d+:\s+([^:@]+)(?:@[^:]+)?:.*\blink/ether\s+([0-9a-fA-F:]{17})\b',
    ).firstMatch(line);
    if (match == null) {
      continue;
    }

    final interfaceName = match.group(1)!;
    if (interfaceName == 'lo') {
      continue;
    }

    final normalized = _normalizeMacAddress(match.group(2)!);
    if (normalized != null) {
      macs.add(normalized);
    }
  }

  final sorted = macs.toList(growable: false)..sort();
  return sorted;
}

String? _bestEffortCidrFor(String address) {
  final octets = address.split('.');
  if (octets.length != 4) {
    return null;
  }

  final parsed = octets.map(int.tryParse).toList(growable: false);
  if (parsed.any((int? part) => part == null || part < 0 || part > 255)) {
    return null;
  }

  return '${parsed[0]}.${parsed[1]}.${parsed[2]}.0/24';
}

String? _normalizeMacAddress(String mac) {
  final normalized = mac.trim().toLowerCase();
  if (!RegExp(r'^[0-9a-f]{2}(?::[0-9a-f]{2}){5}$').hasMatch(normalized)) {
    return null;
  }
  if (normalized == '00:00:00:00:00:00') {
    return null;
  }
  return normalized;
}

bool _isUsableIpv4(String address) {
  final value = _parseIpv4(address);
  if (value == null) {
    return false;
  }

  final firstOctet = value >> 24;
  if (firstOctet == 127) {
    return false;
  }

  if (firstOctet == 169 && ((value >> 16) & 0xff) == 254) {
    return false;
  }

  return true;
}

int? _parseNetmaskPrefixLength(String value) {
  if (value.startsWith('0x') || value.startsWith('0X')) {
    final parsed = int.tryParse(value.substring(2), radix: 16);
    if (parsed == null || parsed < 0 || parsed > 0xffffffff) {
      return null;
    }
    return _prefixLengthFromMask(parsed);
  }

  final mask = _parseIpv4(value);
  if (mask == null) {
    return null;
  }
  return _prefixLengthFromMask(mask);
}

int? _prefixLengthFromMask(int mask) {
  var seenZero = false;
  var count = 0;

  for (var bit = 31; bit >= 0; bit -= 1) {
    final isSet = ((mask >> bit) & 1) == 1;
    if (isSet) {
      if (seenZero) {
        return null;
      }
      count += 1;
    } else {
      seenZero = true;
    }
  }

  return count;
}

_Ipv4Network? _parseIpv4Cidr(String cidr) {
  final parts = cidr.split('/');
  if (parts.length != 2) {
    return null;
  }

  final ipValue = _parseIpv4(parts[0]);
  final prefixLength = int.tryParse(parts[1]);
  if (ipValue == null ||
      prefixLength == null ||
      prefixLength < 0 ||
      prefixLength > 32) {
    return null;
  }

  final mask =
      prefixLength == 0 ? 0 : (0xffffffff << (32 - prefixLength)) & 0xffffffff;
  final network = ipValue & mask;
  return _Ipv4Network(network: network, mask: mask);
}

int? _parseIpv4(String value) {
  final octets = value.split('.');
  if (octets.length != 4) {
    return null;
  }

  var result = 0;
  for (final octet in octets) {
    final part = int.tryParse(octet);
    if (part == null || part < 0 || part > 255) {
      return null;
    }
    result = (result << 8) | part;
  }
  return result;
}

class _Ipv4Network {
  const _Ipv4Network({
    required this.network,
    required this.mask,
  });

  final int network;
  final int mask;
}
