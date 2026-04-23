import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../entities/client_device.dart';
import '../entities/vpn_policy.dart';
import '../entities/wireguard_peer.dart';
import '../exceptions/router_api_exception.dart';
import 'router_api.dart';

class KeeneticRouterApi implements RouterApi {
  KeeneticRouterApi({
    http.Client? httpClient,
    Duration authenticationTimeout = const Duration(seconds: 2),
    Duration requestTimeout = const Duration(seconds: 5),
  })  : _httpClient = httpClient ?? http.Client(),
        _authenticationTimeout = authenticationTimeout,
        _requestTimeout = requestTimeout,
        _ownsClient = httpClient == null;

  final http.Client _httpClient;
  final Duration _authenticationTimeout;
  final Duration _requestTimeout;
  final bool _ownsClient;

  void close() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }

  @override
  Future<bool> authenticate({
    required Uri baseUri,
    required String login,
    required String password,
  }) async {
    final session = _KeeneticSession(
      client: _httpClient,
      baseUri: _normalizeBaseUri(baseUri),
      login: login,
      password: password,
      authenticationTimeout: _authenticationTimeout,
      requestTimeout: _requestTimeout,
    );
    return session.authenticate();
  }

  @override
  Future<List<String>> getKeenDnsUrls({
    required Uri baseUri,
    required String login,
    required String password,
  }) async {
    final session = await _authenticateSession(
      baseUri: baseUri,
      login: login,
      password: password,
    );
    final response = await session.get('rci/ip/http/ssl/acme/list/certificate');
    final payload = _decodeJson(response.body);
    final items = _expectList(payload, 'KeenDNS certificate list');

    return items
        .whereType<Map<String, dynamic>>()
        .map((item) => item['domain'])
        .whereType<String>()
        .toList(growable: false);
  }

  @override
  Future<String?> getNetworkIp({
    required Uri baseUri,
    required String login,
    required String password,
  }) async {
    final session = await _authenticateSession(
      baseUri: baseUri,
      login: login,
      password: password,
    );
    final response = await session.get('rci/sc/interface/Bridge0/ip/address');
    final payload = _decodeJson(response.body);
    final map = _expectMap(payload, 'network IP payload');
    return map['address'] as String?;
  }

  @override
  Future<List<VpnPolicy>> getPolicies({
    required Uri baseUri,
    required String login,
    required String password,
  }) async {
    final session = await _authenticateSession(
      baseUri: baseUri,
      login: login,
      password: password,
    );
    final response = await session.get('rci/show/rc/ip/policy');
    final payload = _decodeJson(response.body);
    final policies = _expectMap(payload, 'policy list');

    return policies.entries.map((entry) {
      final data = entry.value;
      if (data is! Map<String, dynamic>) {
        return VpnPolicy(name: entry.key, description: entry.key);
      }
      return VpnPolicy(
        name: entry.key,
        description: (data['description'] as String?) ?? entry.key,
      );
    }).toList(growable: false);
  }

  @override
  Future<List<ClientDevice>> getClients({
    required Uri baseUri,
    required String login,
    required String password,
  }) async {
    final session = await _authenticateSession(
      baseUri: baseUri,
      login: login,
      password: password,
    );
    final clientsResponse = await session.get('rci/show/ip/hotspot/host');
    final policiesResponse = await session.get('rci/show/rc/ip/hotspot/host');

    final clientsPayload = _expectList(
      _decodeJson(clientsResponse.body),
      'client list',
    );
    final policiesPayload = _expectList(
      _decodeJson(policiesResponse.body),
      'client policies',
    );

    final clients = <String, _ClientAccumulator>{};

    for (final item in clientsPayload.whereType<Map<String, dynamic>>()) {
      final mac = _normalizeMac(item['mac'] as String?);
      if (mac == null) {
        continue;
      }
      clients[mac] = _ClientAccumulator(
        name: (item['name'] as String?) ?? 'Unknown',
        ipAddress: item['ip'] as String?,
        macAddress: mac,
        rawData: item,
      );
    }

    for (final item in policiesPayload.whereType<Map<String, dynamic>>()) {
      final mac = _normalizeMac(item['mac'] as String?);
      if (mac == null) {
        continue;
      }
      final existing = clients[mac];
      final updated = (existing ?? _ClientAccumulator.unknown(mac)).copyWith(
        policyName: item['policy'] as String?,
        access: _parseAccessMode(item['access'] as String?),
        isDenied: item['deny'] as bool? ?? false,
        isPermitted: item['permit'] as bool? ?? false,
        priority: _parseInt(item['priority']),
      );
      clients[mac] = updated;
    }

    return clients.values.map((client) {
      final state = _isOnline(client.rawData)
          ? ClientConnectionState.online
          : ClientConnectionState.offline;
      return ClientDevice(
        name: client.name,
        macAddress: client.macAddress,
        ipAddress: client.ipAddress,
        policyName: client.policyName,
        access: client.access,
        isDenied: client.isDenied,
        isPermitted: client.isPermitted,
        priority: client.priority,
        connectionState: state,
        accessPointName: _pickClientField(client.rawData, 'ap') as String?,
        wifiBand: _wifiBandFor(
          _pickClientField(client.rawData, 'ap') as String?,
        ),
        signalRssi: _parseInt(_pickClientField(client.rawData, 'rssi')),
        txRateMbps: _parseInt(_pickClientField(client.rawData, 'txrate')),
        encryption: _pickClientField(client.rawData, 'security') as String?,
        wirelessMode: _pickClientField(client.rawData, 'mode') as String?,
        wifiStandard: _formatWifiStandard(
          _pickClientField(client.rawData, '_11'),
        ),
        spatialStreams: _parseInt(_pickClientField(client.rawData, 'txss')),
        channelWidthMhz: _parseInt(_pickClientField(client.rawData, 'ht')),
        ethernetSpeedMbps: _parseInt(client.rawData['speed']),
        ethernetPort: _parseInt(client.rawData['port']),
      );
    }).toList(growable: false);
  }

  @override
  Future<void> applyPolicy({
    required Uri baseUri,
    required String login,
    required String password,
    required String macAddress,
    required String? policyName,
  }) async {
    final session = await _authenticateSession(
      baseUri: baseUri,
      login: login,
      password: password,
    );
    await session.post(
      'rci/ip/hotspot/host',
      body: <String, Object?>{
        'mac': macAddress,
        'policy': policyName ?? false,
        'permit': true,
        'schedule': false,
      },
    );
  }

  @override
  Future<void> blockClient({
    required Uri baseUri,
    required String login,
    required String password,
    required String macAddress,
  }) async {
    final session = await _authenticateSession(
      baseUri: baseUri,
      login: login,
      password: password,
    );
    await session.post(
      'rci/ip/hotspot/host',
      body: <String, Object?>{
        'mac': macAddress,
        'schedule': false,
        'deny': true,
      },
    );
  }

  @override
  Future<void> wakeOnLan({
    required Uri baseUri,
    required String login,
    required String password,
    required String macAddress,
  }) async {
    final session = await _authenticateSession(
      baseUri: baseUri,
      login: login,
      password: password,
    );
    await session.post(
      'rci/ip/hotspot/wake',
      body: <String, Object?>{
        'mac': macAddress,
      },
    );
  }

  @override
  Future<List<WireGuardPeer>> getWireGuardPeers({
    required Uri baseUri,
    required String login,
    required String password,
  }) async {
    final session = await _authenticateSession(
      baseUri: baseUri,
      login: login,
      password: password,
    );
    late final http.Response response;
    try {
      response = await session.get('rci/show/interface/Wireguard');
    } on RouterRequestException {
      return const <WireGuardPeer>[];
    }
    final payload = _decodeJson(response.body);
    final interfaces = _expectMap(payload, 'WireGuard interfaces');
    final peers = <WireGuardPeer>[];

    for (final interfaceEntry in interfaces.entries) {
      final interfaceData = interfaceEntry.value;
      if (interfaceData is! Map<String, dynamic>) {
        continue;
      }
      final peerMap = interfaceData['peer'];
      if (peerMap is! Map<String, dynamic>) {
        continue;
      }

      for (final peerEntry in peerMap.entries) {
        final peerData = peerEntry.value;
        if (peerData is! Map<String, dynamic>) {
          peers.add(
            WireGuardPeer(
              interfaceName: interfaceEntry.key,
              peerName: peerEntry.key,
            ),
          );
          continue;
        }

        peers.add(
          WireGuardPeer(
            interfaceName: interfaceEntry.key,
            peerName: peerEntry.key,
            allowedIps: _parseStringList(
              peerData['allowed_ips'] ?? peerData['allowed-ips'],
            ),
            endpoint: peerData['endpoint'] as String?,
            isEnabled: peerData['enabled'] as bool? ?? true,
          ),
        );
      }
    }

    return peers;
  }

  Future<_KeeneticSession> _authenticateSession({
    required Uri baseUri,
    required String login,
    required String password,
  }) async {
    final session = _KeeneticSession(
      client: _httpClient,
      baseUri: _normalizeBaseUri(baseUri),
      login: login,
      password: password,
      authenticationTimeout: _authenticationTimeout,
      requestTimeout: _requestTimeout,
    );

    final isAuthenticated = await session.authenticate();
    if (!isAuthenticated) {
      throw const RouterAuthenticationException();
    }
    return session;
  }
}

class _KeeneticSession {
  _KeeneticSession({
    required this.client,
    required this.baseUri,
    required this.login,
    required this.password,
    required this.authenticationTimeout,
    required this.requestTimeout,
  });

  final http.Client client;
  final Uri baseUri;
  final String login;
  final String password;
  final Duration authenticationTimeout;
  final Duration requestTimeout;
  final Map<String, String> _cookies = <String, String>{};

  Future<bool> authenticate() async {
    final initialResponse = await _send(
      'GET',
      'auth',
      timeout: authenticationTimeout,
      checkStatus: false,
    );

    if (initialResponse.statusCode == HttpStatus.ok) {
      return true;
    }

    if (initialResponse.statusCode != HttpStatus.unauthorized) {
      return false;
    }

    final realm = initialResponse.headers['x-ndm-realm'];
    final challenge = initialResponse.headers['x-ndm-challenge'];
    if (realm == null || challenge == null) {
      return false;
    }

    final md5Digest = md5.convert(utf8.encode('$login:$realm:$password'));
    final passwordDigest = sha256.convert(
      utf8.encode('$challenge$md5Digest'),
    );

    final authResponse = await _send(
      'POST',
      'auth',
      body: <String, Object?>{
        'login': login,
        'password': passwordDigest.toString(),
      },
      timeout: requestTimeout,
      checkStatus: false,
    );

    return authResponse.statusCode == HttpStatus.ok;
  }

  Future<http.Response> get(String endpoint) {
    return _send('GET', endpoint);
  }

  Future<http.Response> post(
    String endpoint, {
    required Map<String, Object?> body,
  }) {
    return _send('POST', endpoint, body: body);
  }

  Future<http.Response> _send(
    String method,
    String endpoint, {
    Object? body,
    Duration? timeout,
    bool checkStatus = true,
  }) async {
    final request = http.Request(method, baseUri.resolve(endpoint));
    request.headers['accept'] = 'application/json';

    if (_cookies.isNotEmpty) {
      request.headers['cookie'] = _cookies.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');
    }

    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final streamedResponse = await client
        .send(request)
        .timeout(timeout ?? requestTimeout);
    final response = await http.Response.fromStream(streamedResponse);
    _captureCookies(response);

    if (checkStatus && response.statusCode != HttpStatus.ok) {
      throw RouterRequestException(
        statusCode: response.statusCode,
        message:
            'Unexpected status code ${response.statusCode} for ${request.url}',
      );
    }

    return response;
  }

  void _captureCookies(http.Response response) {
    final setCookieHeader = response.headers['set-cookie'];
    if (setCookieHeader == null || setCookieHeader.isEmpty) {
      return;
    }

    for (final cookieValue in _splitSetCookieHeader(setCookieHeader)) {
      final cookie = Cookie.fromSetCookieValue(cookieValue);
      _cookies[cookie.name] = cookie.value;
    }
  }
}

class _ClientAccumulator {
  const _ClientAccumulator({
    required this.name,
    required this.macAddress,
    this.ipAddress,
    this.policyName,
    this.access = ClientAccessMode.unknown,
    this.isDenied = false,
    this.isPermitted = false,
    this.priority,
    this.rawData = const <String, dynamic>{},
  });

  factory _ClientAccumulator.unknown(String macAddress) {
    return _ClientAccumulator(
      name: 'Unknown',
      macAddress: macAddress,
    );
  }

  final String name;
  final String macAddress;
  final String? ipAddress;
  final String? policyName;
  final ClientAccessMode access;
  final bool isDenied;
  final bool isPermitted;
  final int? priority;
  final Map<String, dynamic> rawData;

  _ClientAccumulator copyWith({
    String? name,
    String? ipAddress,
    Object? policyName = _undefined,
    ClientAccessMode? access,
    bool? isDenied,
    bool? isPermitted,
    int? priority,
    Map<String, dynamic>? rawData,
  }) {
    return _ClientAccumulator(
      name: name ?? this.name,
      macAddress: macAddress,
      ipAddress: ipAddress ?? this.ipAddress,
      policyName:
          identical(policyName, _undefined) ? this.policyName : policyName as String?,
      access: access ?? this.access,
      isDenied: isDenied ?? this.isDenied,
      isPermitted: isPermitted ?? this.isPermitted,
      priority: priority ?? this.priority,
      rawData: rawData ?? this.rawData,
    );
  }
}

const Object _undefined = Object();

Uri _normalizeBaseUri(Uri input) {
  if (input.hasScheme && input.host.isNotEmpty) {
    final normalizedPath = input.path.isEmpty
        ? '/'
        : input.path.endsWith('/')
            ? input.path
            : '${input.path}/';
    return input.replace(path: normalizedPath, query: null, fragment: null);
  }

  if (!input.hasScheme && input.host.isEmpty && input.path.isNotEmpty) {
    return Uri(
      scheme: 'http',
      host: input.path,
      path: '/',
    );
  }

  final withScheme = input.replace(
    scheme: input.scheme.isEmpty ? 'http' : input.scheme,
  );
  final normalizedPath = withScheme.path.isEmpty
      ? '/'
      : withScheme.path.endsWith('/')
          ? withScheme.path
          : '${withScheme.path}/';
  return withScheme.replace(
    path: normalizedPath,
    query: null,
    fragment: null,
  );
}

dynamic _decodeJson(String body) {
  try {
    return jsonDecode(body);
  } on FormatException catch (error) {
    throw RouterParseException('Invalid JSON payload: $error');
  }
}

Map<String, dynamic> _expectMap(dynamic payload, String context) {
  if (payload is! Map<String, dynamic>) {
    throw RouterParseException('Expected map for $context');
  }
  return payload;
}

List<dynamic> _expectList(dynamic payload, String context) {
  if (payload is! List<dynamic>) {
    throw RouterParseException('Expected list for $context');
  }
  return payload;
}

String? _normalizeMac(String? macAddress) {
  if (macAddress == null || macAddress.isEmpty) {
    return null;
  }
  return macAddress.toLowerCase();
}

ClientAccessMode _parseAccessMode(String? access) {
  switch (access) {
    case 'permit':
    case 'allow':
      return ClientAccessMode.allow;
    case 'deny':
      return ClientAccessMode.deny;
    default:
      return ClientAccessMode.unknown;
  }
}

int? _parseInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

Object? _pickClientField(Map<String, dynamic> rawData, String key) {
  final directValue = rawData[key];
  if (directValue != null) {
    return directValue;
  }

  final mws = rawData['mws'];
  if (mws is Map<String, dynamic>) {
    return mws[key];
  }

  return null;
}

String? _formatWifiStandard(Object? value) {
  if (value is List) {
    final values = value.map((item) => item.toString()).toList(growable: false);
    if (values.isEmpty) {
      return null;
    }
    return values.join('/');
  }
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

String? _wifiBandFor(String? accessPointName) {
  switch (accessPointName) {
    case 'WifiMaster0/AccessPoint0':
      return '2.4 GHz';
    case 'WifiMaster1/AccessPoint0':
      return '5 GHz';
    default:
      return null;
  }
}

bool _isOnline(Map<String, dynamic> rawData) {
  if ((rawData['link'] as String?) == 'up') {
    return true;
  }
  final mws = rawData['mws'];
  if (mws is Map<String, dynamic> && (mws['link'] as String?) == 'up') {
    return true;
  }
  return false;
}

List<String> _parseStringList(Object? value) {
  if (value is List) {
    return value.whereType<String>().toList(growable: false);
  }
  if (value is String && value.isNotEmpty) {
    return <String>[value];
  }
  return const <String>[];
}

List<String> _splitSetCookieHeader(String header) {
  return header.split(RegExp(r', (?=[^;,\s]+=)'));
}
