import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:router_core/router_core.dart';
import 'package:test/test.dart';

void main() {
  group('KeeneticRouterApi', () {
    test('authenticate performs Keenetic challenge-response login', () async {
      final requests = <http.BaseRequest>[];
      final api = KeeneticRouterApi(
        httpClient: MockClient((request) async {
          requests.add(request);

          if (request.url.path == '/auth' && request.method == 'GET') {
            return http.Response(
              '',
              401,
              headers: <String, String>{
                'x-ndm-realm': 'Keenetic',
                'x-ndm-challenge': 'abc123',
              },
            );
          }

          if (request.url.path == '/auth' && request.method == 'POST') {
            final body = jsonDecode((request as http.Request).body)
                as Map<String, dynamic>;
            expect(body['login'], 'admin');
            expect(body['password'], hasLength(64));

            return http.Response(
              '',
              200,
              headers: <String, String>{
                'set-cookie': 'sid=session123; Path=/; HttpOnly',
              },
            );
          }

          fail('Unexpected request ${request.method} ${request.url}');
        }),
      );

      final authenticated = await api.authenticate(
        baseUri: Uri.parse('192.168.1.1'),
        login: 'admin',
        password: 'secret',
      );

      expect(authenticated, isTrue);
      expect(requests, hasLength(2));
      expect(requests.first.url.toString(), 'http://192.168.1.1/auth');
    });

    test('getKeenDnsUrls authenticates and forwards session cookie', () async {
      final fixture = _readFixture('certificate_list.json');
      final api = KeeneticRouterApi(
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth' && request.method == 'GET') {
            return http.Response(
              '',
              401,
              headers: <String, String>{
                'x-ndm-realm': 'Keenetic',
                'x-ndm-challenge': 'abc123',
              },
            );
          }

          if (request.url.path == '/auth' && request.method == 'POST') {
            return http.Response(
              '',
              200,
              headers: <String, String>{
                'set-cookie': 'sid=session123; Path=/; HttpOnly',
              },
            );
          }

          if (request.url.path ==
                  '/rci/ip/http/ssl/acme/list/certificate' &&
              request.method == 'GET') {
            expect(request.headers['cookie'], contains('sid=session123'));
            return http.Response(fixture, 200);
          }

          fail('Unexpected request ${request.method} ${request.url}');
        }),
      );

      final urls = await api.getKeenDnsUrls(
        baseUri: Uri.parse('http://192.168.1.1'),
        login: 'admin',
        password: 'secret',
      );

      expect(urls, <String>['home.keenetic.link', 'hash123.keenetic.io']);
    });

    test('getPolicies maps descriptions to typed entities', () async {
      final fixture = _readFixture('policies.json');
      final api = KeeneticRouterApi(httpClient: _authThenSingleResponse(
        path: '/rci/show/rc/ip/policy',
        body: fixture,
      ));

      final policies = await api.getPolicies(
        baseUri: Uri.parse('http://router.local'),
        login: 'admin',
        password: 'secret',
      );

      expect(policies, hasLength(2));
      expect(policies.first.name, 'default');
      expect(policies.first.description, 'Default route');
      expect(policies.last.name, 'work-vpn');
      expect(policies.last.description, 'Work VPN');
    });

    test('getClients merges host and policy datasets', () async {
      final hostsFixture = _readFixture('client_hosts.json');
      final policiesFixture = _readFixture('client_policies.json');
      var requestIndex = 0;
      final api = KeeneticRouterApi(
        httpClient: MockClient((request) async {
          requestIndex += 1;

          if (request.url.path == '/auth' && request.method == 'GET') {
            return http.Response(
              '',
              401,
              headers: <String, String>{
                'x-ndm-realm': 'Keenetic',
                'x-ndm-challenge': 'abc123',
              },
            );
          }

          if (request.url.path == '/auth' && request.method == 'POST') {
            return http.Response(
              '',
              200,
              headers: <String, String>{
                'set-cookie': 'sid=session123; Path=/; HttpOnly',
              },
            );
          }

          if (request.url.path == '/rci/show/ip/hotspot/host') {
            expect(request.headers['cookie'], contains('sid=session123'));
            return http.Response(hostsFixture, 200);
          }

          if (request.url.path == '/rci/show/rc/ip/hotspot/host') {
            expect(request.headers['cookie'], contains('sid=session123'));
            return http.Response(policiesFixture, 200);
          }

          fail('Unexpected request $requestIndex: ${request.method} ${request.url}');
        }),
      );

      final clients = await api.getClients(
        baseUri: Uri.parse('192.168.1.1'),
        login: 'admin',
        password: 'secret',
      );

      expect(clients, hasLength(3));

      final laptop = clients.firstWhere(
        (client) => client.macAddress == 'aa:bb:cc:dd:ee:ff',
      );
      expect(laptop.name, 'Laptop');
      expect(laptop.ipAddress, '192.168.1.20');
      expect(laptop.policyName, 'work-vpn');
      expect(laptop.access, ClientAccessMode.allow);
      expect(laptop.connectionState, ClientConnectionState.online);
      expect(laptop.isWireless, isTrue);
      expect(laptop.wifiBand, '2.4 GHz');
      expect(laptop.signalRssi, -48);
      expect(laptop.txRateMbps, 866);
      expect(laptop.encryption, 'WPA2');
      expect(laptop.wifiStandard, 'n/ac');
      expect(laptop.spatialStreams, 2);
      expect(laptop.channelWidthMhz, 80);
      expect(laptop.wirelessMode, '11ac');

      final unknown = clients.firstWhere(
        (client) => client.macAddress == '77:88:99:aa:bb:cc',
      );
      expect(unknown.name, 'Unknown');
      expect(unknown.isDenied, isTrue);
      expect(unknown.connectionState, ClientConnectionState.offline);

      final tablet = clients.firstWhere(
        (client) => client.macAddress == '11:22:33:44:55:66',
      );
      expect(tablet.isWireless, isFalse);
      expect(tablet.ethernetSpeedMbps, 1000);
      expect(tablet.ethernetPort, 3);
    });

    test('applyPolicy sends the same payload shape as the Python app', () async {
      final api = KeeneticRouterApi(
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth' && request.method == 'GET') {
            return http.Response(
              '',
              401,
              headers: <String, String>{
                'x-ndm-realm': 'Keenetic',
                'x-ndm-challenge': 'abc123',
              },
            );
          }

          if (request.url.path == '/auth' && request.method == 'POST') {
            return http.Response(
              '',
              200,
              headers: <String, String>{
                'set-cookie': 'sid=session123; Path=/; HttpOnly',
              },
            );
          }

          if (request.url.path == '/rci/ip/hotspot/host' &&
              request.method == 'POST') {
            final body = jsonDecode((request as http.Request).body)
                as Map<String, dynamic>;
            expect(body, <String, dynamic>{
              'mac': 'aa:bb:cc:dd:ee:ff',
              'policy': false,
              'permit': true,
              'schedule': false,
            });
            return http.Response('', 200);
          }

          fail('Unexpected request ${request.method} ${request.url}');
        }),
      );

      await api.applyPolicy(
        baseUri: Uri.parse('router.local'),
        login: 'admin',
        password: 'secret',
        macAddress: 'aa:bb:cc:dd:ee:ff',
        policyName: null,
      );
    });

    test('getWireGuardPeers flattens interface peer maps', () async {
      final fixture = _readFixture('wireguard_peers.json');
      final api = KeeneticRouterApi(httpClient: _authThenSingleResponse(
        path: '/rci/show/interface/Wireguard',
        body: fixture,
      ));

      final peers = await api.getWireGuardPeers(
        baseUri: Uri.parse('https://router.example'),
        login: 'admin',
        password: 'secret',
      );

      expect(peers, hasLength(2));
      expect(peers.first.interfaceName, 'Wireguard0');
      expect(peers.first.peerName, 'alice');
      expect(peers.first.allowedIps, <String>['10.10.10.2/32']);
      expect(peers.first.endpoint, 'vpn.example.com:51820');
      expect(peers.last.isEnabled, isFalse);
    });

    test('getWireGuardPeers returns an empty list when the endpoint is missing',
        () async {
      final api = KeeneticRouterApi(
        httpClient: _authThenStatusResponse(
          path: '/rci/show/interface/Wireguard',
          statusCode: 404,
        ),
      );

      final peers = await api.getWireGuardPeers(
        baseUri: Uri.parse('https://router.example'),
        login: 'admin',
        password: 'secret',
      );

      expect(peers, isEmpty);
    });

    test('getNetworkIp parses bridge IP payload', () async {
      final fixture = _readFixture('network_ip.json');
      final api = KeeneticRouterApi(httpClient: _authThenSingleResponse(
        path: '/rci/sc/interface/Bridge0/ip/address',
        body: fixture,
      ));

      final ip = await api.getNetworkIp(
        baseUri: Uri.parse('router.local'),
        login: 'admin',
        password: 'secret',
      );

      expect(ip, '192.168.1.1');
    });
  });
}

String _readFixture(String fileName) {
  return File('test/fixtures/$fileName').readAsStringSync();
}

MockClient _authThenSingleResponse({
  required String path,
  required String body,
}) {
  return MockClient((request) async {
    if (request.url.path == '/auth' && request.method == 'GET') {
      return http.Response(
        '',
        401,
        headers: <String, String>{
          'x-ndm-realm': 'Keenetic',
          'x-ndm-challenge': 'abc123',
        },
      );
    }

    if (request.url.path == '/auth' && request.method == 'POST') {
      return http.Response(
        '',
        200,
        headers: <String, String>{
          'set-cookie': 'sid=session123; Path=/; HttpOnly',
        },
      );
    }

    if (request.url.path == path) {
      expect(request.headers['cookie'], contains('sid=session123'));
      return http.Response(body, 200);
    }

    fail('Unexpected request ${request.method} ${request.url}');
  });
}

MockClient _authThenStatusResponse({
  required String path,
  required int statusCode,
  String body = '',
}) {
  return MockClient((request) async {
    if (request.url.path == '/auth' && request.method == 'GET') {
      return http.Response(
        '',
        401,
        headers: <String, String>{
          'x-ndm-realm': 'Keenetic',
          'x-ndm-challenge': 'abc123',
        },
      );
    }

    if (request.url.path == '/auth' && request.method == 'POST') {
      return http.Response(
        '',
        200,
        headers: <String, String>{
          'set-cookie': 'sid=session123; Path=/; HttpOnly',
        },
      );
    }

    if (request.url.path == path) {
      expect(request.headers['cookie'], contains('sid=session123'));
      return http.Response(body, statusCode);
    }

    fail('Unexpected request ${request.method} ${request.url}');
  });
}
