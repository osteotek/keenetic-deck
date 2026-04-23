import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keenetic_manager_app/main.dart';
import 'package:keenetic_manager_app/src/app_section.dart';
import 'package:keenetic_manager_app/src/router_overview_controller.dart';
import 'package:keenetic_manager_app/src/router_overview_model.dart';
import 'package:keenetic_manager_app/src/selected_router_status.dart';
import 'package:router_core/router_core.dart';

void main() {
  group('RouterOverviewPage', () {
    testWidgets('renders the empty state and reload action', (
      WidgetTester tester,
    ) async {
      final controller = _FakeRouterOverviewController(
        model: const RouterOverviewModel(
          storagePath: '/tmp/routers.v1.json',
          routers: <RouterProfile>[],
          selectedRouterId: null,
          passwordStored: <String, bool>{},
          selectedRouterStatus: null,
          autoRefreshEnabled: false,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouterOverviewPage(controller: controller),
        ),
      );

      expect(find.text('No routers stored yet'), findsOneWidget);
      expect(find.text('/tmp/routers.v1.json'), findsOneWidget);
      expect(find.text('Add router'), findsOneWidget);

      await tester.tap(find.text('Reload storage'));
      await tester.pump();

      expect(controller.refreshCount, 1);
    });

    testWidgets('uses a navigation rail on wide layouts and switches sections',
        (
      WidgetTester tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final controller = _FakeRouterOverviewController(
        model: _buildOverviewModel(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouterOverviewPage(controller: controller),
        ),
      );

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Selected Router Status'), findsOneWidget);
      expect(find.text('Routers'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Connected • checked'), findsOneWidget);
      expect(find.text('Add router'), findsOneWidget);

      await tester.tap(find.text('Policies'));
      await tester.pumpAndSettle();

      expect(controller.section, AppSection.policies);
      expect(find.text('Work VPN'), findsAtLeastNWidgets(1));

      await tester.enterText(
        find.widgetWithText(TextField, 'Search policies or clients'),
        'laptop',
      );
      await tester.pump();

      expect(controller.selectedPolicyQuery, 'laptop');
    });

    testWidgets('shows add router only on routers and onboarding screens', (
      WidgetTester tester,
    ) async {
      final controller = _FakeRouterOverviewController(
        model: _buildOverviewModel(),
        section: AppSection.routers,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouterOverviewPage(controller: controller),
        ),
      );

      expect(find.text('Add router'), findsOneWidget);

      controller.updateSection(AppSection.clients);
      await tester.pumpAndSettle();

      expect(find.text('Add router'), findsNothing);
    });

    testWidgets('uses a bottom navigation bar on narrow layouts', (
      WidgetTester tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(430, 900));

      final controller = _FakeRouterOverviewController(
        model: _buildOverviewModel(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouterOverviewPage(controller: controller),
        ),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      controller.updateSection(AppSection.wireguard);
      await tester.pumpAndSettle();

      expect(controller.section, AppSection.wireguard);
      expect(find.text('alice-laptop'), findsOneWidget);
      expect(find.text('10.0.0.2/32'), findsOneWidget);
    });

    testWidgets('macOS wireguard screen uses grouped interface columns', (
      WidgetTester tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.binding.setSurfaceSize(const Size(1280, 900));

        final controller = _FakeRouterOverviewController(
          model: _buildOverviewModel(),
          section: AppSection.wireguard,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RouterOverviewPage(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Peer'), findsOneWidget);
        expect(find.text('Interface'), findsAtLeastNWidgets(1));
        expect(find.text('Allowed IPs'), findsAtLeastNWidgets(1));
        expect(find.textContaining('enabled'), findsAtLeastNWidgets(1));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('macOS shell uses bottom navigation instead of sidebar', (
      WidgetTester tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.binding.setSurfaceSize(const Size(1280, 900));

        final controller = _FakeRouterOverviewController(
          model: _buildOverviewModel(),
          section: AppSection.routers,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RouterOverviewPage(controller: controller),
          ),
        );

        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('renders the local device section with matched router clients',
        (
      WidgetTester tester,
    ) async {
      final controller = _FakeRouterOverviewController(
        model: _buildOverviewModel(),
        section: AppSection.localDevice,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouterOverviewPage(controller: controller),
        ),
      );

      expect(find.text('This Device'), findsAtLeastNWidgets(1));
      expect(find.text('Local interface discovery available'), findsOneWidget);
      expect(find.text('Traffic inspection unavailable'), findsOneWidget);
      expect(find.text('Matched Router Clients'), findsOneWidget);
      expect(
        find.text('Matched clients can be managed directly from this screen.'),
        findsOneWidget,
      );
      expect(find.text('Laptop'), findsOneWidget);
      expect(find.text('aa:bb:cc:dd:ee:ff'), findsAtLeastNWidgets(1));
      expect(find.byTooltip('Client actions'), findsOneWidget);
    });

    testWidgets('client action menu exposes Wake on LAN', (
      WidgetTester tester,
    ) async {
      final controller = _FakeRouterOverviewController(
        model: _buildOverviewModel(),
        section: AppSection.clients,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouterOverviewPage(controller: controller),
        ),
      );

      await tester.tap(find.byTooltip('Client actions').first);
      await tester.pumpAndSettle();

      expect(find.text('Wake on LAN'), findsOneWidget);
    });

    testWidgets('clients screen exposes update and clear search controls', (
      WidgetTester tester,
    ) async {
      final controller = _FakeRouterOverviewController(
        model: _buildOverviewModel(),
        section: AppSection.clients,
        selectedClientQuery: 'laptop',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouterOverviewPage(controller: controller),
        ),
      );

      expect(find.text('Update'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);

      await tester.tap(find.text('Update'));
      await tester.pump();

      expect(controller.refreshCount, 1);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(controller.selectedClientQuery, '');
    });

    testWidgets('macOS clients screen uses grouped desktop columns', (
      WidgetTester tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.binding.setSurfaceSize(const Size(1280, 900));

        final controller = _FakeRouterOverviewController(
          model: _buildOverviewModel(),
          section: AppSection.clients,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RouterOverviewPage(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Device'), findsOneWidget);
        expect(find.text('Network'), findsOneWidget);
        expect(find.text('Access'), findsAtLeastNWidgets(1));
        expect(find.text('IP address'), findsAtLeastNWidgets(1));
        expect(find.text('MAC address'), findsAtLeastNWidgets(1));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('policies screen exposes inline quick policy controls', (
      WidgetTester tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1200, 1600));

      final controller = _FakeRouterOverviewController(
        model: _buildOverviewModel(),
        section: AppSection.policies,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouterOverviewPage(controller: controller),
        ),
      );

      expect(find.text('Quick policy'), findsAtLeastNWidgets(1));
      expect(find.text('Block'), findsAtLeastNWidgets(1));
      expect(find.text('Default'), findsAtLeastNWidgets(1));
      expect(find.text('Work VPN'), findsAtLeastNWidgets(1));
      expect(
        find.text(
          'Ordering: This Device matches first, then online clients, then offline clients.',
        ),
        findsAtLeastNWidgets(1),
      );
      expect(find.text('This Device'), findsAtLeastNWidgets(1));
      expect(find.text('1 online'), findsAtLeastNWidgets(1));
    });

    testWidgets(
        'policies screen prioritizes this device first, then online, then offline',
        (
      WidgetTester tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1200, 1600));

      final controller = _FakeRouterOverviewController(
        model: _buildOverviewModel(
          status: SelectedRouterStatus(
            router: _buildRouter(),
            checkedAt: DateTime.utc(2026, 4, 23, 12),
            hasStoredPassword: true,
            isConnected: true,
            localMacAddresses: const <String>['aa:bb:cc:dd:ee:ff'],
            clients: const <ClientDevice>[
              ClientDevice(
                name: 'Office Printer',
                macAddress: 'de:ad:be:ef:00:01',
                ipAddress: '192.168.1.60',
                policyName: 'work-vpn',
                connectionState: ClientConnectionState.offline,
              ),
              ClientDevice(
                name: 'Laptop',
                macAddress: 'aa:bb:cc:dd:ee:ff',
                ipAddress: '192.168.1.20',
                policyName: 'work-vpn',
                connectionState: ClientConnectionState.online,
              ),
              ClientDevice(
                name: 'Work Phone',
                macAddress: '00:11:22:33:44:55',
                ipAddress: '192.168.1.25',
                policyName: 'work-vpn',
                connectionState: ClientConnectionState.online,
              ),
            ],
            policies: const <VpnPolicy>[
              VpnPolicy(name: 'work-vpn', description: 'Work VPN'),
            ],
          ),
        ),
        section: AppSection.policies,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouterOverviewPage(controller: controller),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Office Printer'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      final laptopTopLeft = tester.getTopLeft(find.text('Laptop')).dy;
      final workPhoneTopLeft = tester.getTopLeft(find.text('Work Phone')).dy;
      final printerTopLeft = tester.getTopLeft(find.text('Office Printer')).dy;

      expect(laptopTopLeft, lessThan(workPhoneTopLeft));
      expect(workPhoneTopLeft, lessThan(printerTopLeft));
      expect(find.text('This Device'), findsAtLeastNWidgets(1));
      expect(find.text('Online'), findsAtLeastNWidgets(2));
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets(
        'shows a shared router failure banner with retry and navigation', (
      WidgetTester tester,
    ) async {
      final controller = _FakeRouterOverviewController(
        model: _buildOverviewModel(
          status: SelectedRouterStatus(
            router: _buildRouter(),
            checkedAt: DateTime.utc(2026, 4, 23, 13),
            hasStoredPassword: true,
            isConnected: false,
            errorMessage:
                'Authentication failed for the selected connection target.',
          ),
        ),
        section: AppSection.clients,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouterOverviewPage(controller: controller),
        ),
      );

      expect(find.text('Router connection failed'), findsOneWidget);
      expect(
        find.text('Authentication failed for the selected connection target.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Routers'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(controller.refreshCount, 1);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Routers'));
      await tester.pumpAndSettle();
      expect(controller.section, AppSection.routers);
    });

    testWidgets('shows refresh affordances for live sections', (
      WidgetTester tester,
    ) async {
      final controller = _FakeRouterOverviewController(
        model: _buildOverviewModel(),
        section: AppSection.routers,
        isRefreshing: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouterOverviewPage(controller: controller),
        ),
      );

      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.text('Refreshing router data...'), findsOneWidget);
    });

    testWidgets('auto-refreshes live sections on a timer', (
      WidgetTester tester,
    ) async {
      final controller = _FakeRouterOverviewController(
        model: _buildOverviewModel(autoRefreshEnabled: true),
        section: AppSection.clients,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouterOverviewPage(controller: controller),
        ),
      );

      expect(controller.refreshCount, 0);

      await tester.pump(const Duration(seconds: 2));

      expect(controller.refreshCount, 1);
    });

    testWidgets('does not auto-refresh router management screens', (
      WidgetTester tester,
    ) async {
      final controller = _FakeRouterOverviewController(
        model: _buildOverviewModel(),
        section: AppSection.routers,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouterOverviewPage(controller: controller),
        ),
      );

      await tester.pump(const Duration(seconds: 2));

      expect(controller.refreshCount, 0);
    });

    testWidgets('renders client telemetry in a labeled table', (
      WidgetTester tester,
    ) async {
      final controller = _FakeRouterOverviewController(
        model: _buildOverviewModel(),
        section: AppSection.clients,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouterOverviewPage(controller: controller),
        ),
      );

      expect(find.text('Telemetry'), findsAtLeastNWidgets(1));
      expect(find.text('Connection'), findsAtLeastNWidgets(1));
      expect(find.text('Wi-Fi 2.4 GHz'), findsOneWidget);
      expect(find.text('Signal'), findsAtLeastNWidgets(1));
      expect(find.text('-48 dBm'), findsOneWidget);
      expect(find.text('Link speed'), findsAtLeastNWidgets(1));
      expect(find.text('866 Mbps'), findsAtLeastNWidgets(1));
      expect(find.text('Security'), findsAtLeastNWidgets(1));
      expect(find.text('WPA2'), findsOneWidget);
      expect(find.text('Wireless profile'), findsAtLeastNWidgets(1));
      expect(find.text('11ac n/ac 2x2 80 MHz'), findsOneWidget);
      expect(find.text('Switch port'), findsAtLeastNWidgets(1));
      expect(find.text('Ethernet'), findsOneWidget);
      expect(find.text('3'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders telemetry facts in two columns when width allows', (
      WidgetTester tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1200, 1000));

      final controller = _FakeRouterOverviewController(
        model: _buildOverviewModel(),
        section: AppSection.clients,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouterOverviewPage(controller: controller),
        ),
      );

      final connectionOffset = tester.getTopLeft(find.text('Connection').first);
      final signalOffset = tester.getTopLeft(find.text('Signal'));

      expect(
        (connectionOffset.dy - signalOffset.dy).abs(),
        lessThan(8),
      );
      expect(signalOffset.dx, greaterThan(connectionOffset.dx));
    });

    testWidgets('does not render telemetry tables on the policies screen', (
      WidgetTester tester,
    ) async {
      final controller = _FakeRouterOverviewController(
        model: _buildOverviewModel(),
        section: AppSection.policies,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouterOverviewPage(controller: controller),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Quick policy'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Quick policy'), findsAtLeastNWidgets(1));
      expect(find.text('Telemetry'), findsNothing);
      expect(find.text('Connection'), findsNothing);
      expect(find.text('Signal'), findsNothing);
      expect(find.text('Wireless profile'), findsNothing);
    });

    testWidgets('renders policy descriptions in client chips', (
      WidgetTester tester,
    ) async {
      final controller = _FakeRouterOverviewController(
        model: _buildOverviewModel(
          status: SelectedRouterStatus(
            router: _buildRouter(),
            checkedAt: DateTime.utc(2026, 4, 23, 12),
            hasStoredPassword: true,
            isConnected: true,
            clients: const <ClientDevice>[
              ClientDevice(
                name: 'Laptop',
                macAddress: 'aa:bb:cc:dd:ee:ff',
                ipAddress: '192.168.1.20',
                policyName: 'Policy0',
                connectionState: ClientConnectionState.online,
              ),
            ],
            policies: const <VpnPolicy>[
              VpnPolicy(name: 'Policy0', description: 'Work VPN'),
            ],
          ),
        ),
        section: AppSection.clients,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouterOverviewPage(controller: controller),
        ),
      );

      expect(find.text('Work VPN'), findsOneWidget);
      expect(find.text('Policy0'), findsNothing);
    });

    testWidgets('renders the settings section with app diagnostics', (
      WidgetTester tester,
    ) async {
      final controller = _FakeRouterOverviewController(
        model: _buildOverviewModel(),
        section: AppSection.settings,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouterOverviewPage(controller: controller),
        ),
      );

      expect(find.text('App'), findsOneWidget);
      expect(find.text('Keenetic Deck'), findsOneWidget);
      expect(find.text('0.1.0-dev+1'), findsOneWidget);
      expect(find.text('org.osteotek.keeneticdeck'), findsOneWidget);
      expect(find.text('org.osteotek.keenetic_deck'), findsAtLeastNWidgets(1));
      expect(find.text('Behavior'), findsOneWidget);
      expect(find.text('Auto-refresh live router screens'), findsOneWidget);
      expect(
        find.text(
          'Disabled by default. Live router screens only refresh when you pull to refresh or press Update/Refresh.',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Storage'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Storage'), findsOneWidget);
      expect(find.text('/tmp/routers.v1.json'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Release Notes'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Release Notes'), findsOneWidget);
      expect(
        find.text('Android, iOS, macOS, and Linux Flutter targets scaffolded.'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Platform Capabilities'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Platform Capabilities'), findsOneWidget);
      expect(find.text('Local interface discovery'), findsOneWidget);
      expect(find.text('Traffic inspection'), findsOneWidget);
      expect(find.text('Wake-on-LAN'), findsOneWidget);
    });
  });
}

class _FakeRouterOverviewController extends RouterOverviewController {
  _FakeRouterOverviewController({
    required RouterOverviewModel model,
    AppSection section = AppSection.routers,
    bool isLoading = false,
    bool isRefreshing = false,
    Object? error,
    String selectedClientQuery = '',
    String selectedPolicyQuery = '',
    Set<String> busyClientMacs = const <String>{},
  })  : _model = model,
        _section = section,
        _isLoading = isLoading,
        _isRefreshing = isRefreshing,
        _error = error,
        _selectedClientQuery = selectedClientQuery,
        _selectedPolicyQuery = selectedPolicyQuery,
        _busyClientMacs = Set<String>.from(busyClientMacs),
        super(storagePath: model.storagePath);

  final RouterOverviewModel _model;
  AppSection _section;
  final bool _isLoading;
  final bool _isRefreshing;
  final Object? _error;
  String _selectedClientQuery;
  String _selectedPolicyQuery;
  final Set<String> _busyClientMacs;
  int refreshCount = 0;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get isRefreshing => _isRefreshing;

  @override
  Object? get error => _error;

  @override
  RouterOverviewModel? get model => _model;

  @override
  AppSection get section => _section;

  @override
  String get selectedClientQuery => _selectedClientQuery;

  @override
  String get selectedPolicyQuery => _selectedPolicyQuery;

  @override
  Set<String> get busyClientMacs => Set<String>.unmodifiable(_busyClientMacs);

  @override
  Future<void> refresh() async {
    refreshCount += 1;
    notifyListeners();
  }

  @override
  void updateSection(AppSection section) {
    if (_section == section) {
      return;
    }
    _section = section;
    notifyListeners();
  }

  @override
  void updateSelectedClientQuery(String value) {
    if (_selectedClientQuery == value) {
      return;
    }
    _selectedClientQuery = value;
    notifyListeners();
  }

  @override
  void updateSelectedPolicyQuery(String value) {
    if (_selectedPolicyQuery == value) {
      return;
    }
    _selectedPolicyQuery = value;
    notifyListeners();
  }
}

RouterOverviewModel _buildOverviewModel({
  SelectedRouterStatus? status,
  bool autoRefreshEnabled = false,
}) {
  final router = _buildRouter();
  final selectedStatus = status ??
      SelectedRouterStatus(
        router: router,
        checkedAt: DateTime.utc(2026, 4, 23, 12),
        hasStoredPassword: true,
        connectionTarget: ConnectionTarget(
          kind: ConnectionTargetKind.direct,
          uri: Uri(scheme: 'http', host: '192.168.1.1'),
        ),
        isConnected: true,
        localMacAddresses: const <String>[
          'aa:bb:cc:dd:ee:ff',
          '11:22:33:44:55:66',
        ],
        clients: const <ClientDevice>[
          ClientDevice(
            name: 'Laptop',
            macAddress: 'aa:bb:cc:dd:ee:ff',
            ipAddress: '192.168.1.20',
            policyName: 'work-vpn',
            accessPointName: 'WifiMaster0/AccessPoint0',
            wifiBand: '2.4 GHz',
            signalRssi: -48,
            txRateMbps: 866,
            encryption: 'WPA2',
            wirelessMode: '11ac',
            wifiStandard: 'n/ac',
            spatialStreams: 2,
            channelWidthMhz: 80,
            connectionState: ClientConnectionState.online,
          ),
          ClientDevice(
            name: 'Living Room TV',
            macAddress: 'de:ad:be:ef:00:01',
            ipAddress: '192.168.1.45',
            ethernetSpeedMbps: 1000,
            ethernetPort: 3,
            connectionState: ClientConnectionState.offline,
          ),
        ],
        policies: const <VpnPolicy>[
          VpnPolicy(name: 'work-vpn', description: 'Work VPN'),
        ],
        wireGuardPeers: const <WireGuardPeer>[
          WireGuardPeer(
            interfaceName: 'Wireguard0',
            peerName: 'alice-laptop',
            allowedIps: <String>['10.0.0.2/32'],
            endpoint: 'vpn.example.com:51820',
            isEnabled: true,
          ),
        ],
        clientCount: 1,
        onlineClientCount: 1,
        policyCount: 1,
        wireGuardPeerCount: 1,
      );

  return RouterOverviewModel(
    storagePath: '/tmp/routers.v1.json',
    routers: <RouterProfile>[router],
    selectedRouterId: router.id,
    passwordStored: const <String, bool>{
      'home-router': true,
    },
    selectedRouterStatus: selectedStatus,
    autoRefreshEnabled: autoRefreshEnabled,
  );
}

RouterProfile _buildRouter() {
  return RouterProfile(
    id: 'home-router',
    name: 'Home',
    address: 'http://192.168.1.1',
    login: 'admin',
    createdAt: DateTime.utc(2026, 4, 23, 10),
    updatedAt: DateTime.utc(2026, 4, 23, 11),
  );
}
