import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keenetic_manager_app/src/app_section.dart';
import 'package:keenetic_manager_app/src/app_preferences_repository.dart';
import 'package:keenetic_manager_app/src/client_action_service.dart';
import 'package:keenetic_manager_app/src/router_editor_dialog.dart';
import 'package:keenetic_manager_app/src/router_onboarding_service.dart';
import 'package:keenetic_manager_app/src/router_overview_controller.dart';
import 'package:keenetic_manager_app/src/selected_router_status.dart';
import 'package:keenetic_manager_app/src/selected_router_status_loader.dart';
import 'package:platform_capabilities/platform_capabilities.dart';
import 'package:router_core/router_core.dart';
import 'package:router_storage/router_storage.dart';

void main() {
  group('RouterOverviewController', () {
    late Directory tempDir;
    late JsonRouterRepository routerRepository;
    late _InMemorySecretRepository secretRepository;
    late _FakeLocalDeviceInfoService localDeviceInfoService;
    late _FakeSelectedRouterStatusLoader statusLoader;
    late _RecordingClientActionService clientActionService;
    late _FakeRouterOnboardingService onboardingService;
    late _InMemoryAppPreferencesRepository appPreferencesRepository;
    late RouterOverviewController controller;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('overview_controller_');
      routerRepository = JsonRouterRepository(defaultRouterStorageFile(tempDir));
      secretRepository = _InMemorySecretRepository();
      localDeviceInfoService = _FakeLocalDeviceInfoService();
      statusLoader = _FakeSelectedRouterStatusLoader();
      clientActionService = _RecordingClientActionService();
      onboardingService = _FakeRouterOnboardingService();
      appPreferencesRepository = _InMemoryAppPreferencesRepository();

      controller = RouterOverviewController(
        routerRepository: routerRepository,
        secretRepository: secretRepository,
        localDeviceInfoService: localDeviceInfoService,
        selectedRouterStatusLoader: statusLoader,
        clientActionService: clientActionService,
        routerOnboardingService: onboardingService,
        appPreferencesRepository: appPreferencesRepository,
        storagePath: defaultRouterStorageFile(tempDir).path,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('initialize loads an empty model', () async {
      await controller.initialize();

      expect(controller.isLoading, isFalse);
      expect(controller.error, isNull);
      expect(controller.model, isNotNull);
      expect(controller.model!.routers, isEmpty);
      expect(controller.section, AppSection.routers);
      expect(controller.model!.autoRefreshEnabled, isFalse);
    });

    test('saveRouter validates, persists, and selects first router', () async {
      await controller.initialize();

      onboardingService.nextPreparedProfile = RouterProfile(
        id: 'home-router',
        name: 'Home',
        address: 'http://192.168.1.1',
        login: 'admin',
        networkIp: '192.168.1.1',
        keendnsUrls: const <String>['home.keenetic.link'],
        createdAt: DateTime.utc(2026, 4, 23, 10),
        updatedAt: DateTime.utc(2026, 4, 23, 11),
      );

      await controller.saveRouter(
        result: const RouterFormResult(
          name: 'Home',
          address: '192.168.1.1',
          login: 'admin',
          password: 'secret',
        ),
      );

      expect(onboardingService.lastPassword, 'secret');
      expect(controller.model!.routers, hasLength(1));
      expect(controller.model!.selectedRouterId, 'home-router');
      expect(
        await secretRepository.readRouterPassword('home-router'),
        'secret',
      );
    });

    test('runClientAction toggles busy state and refreshes model', () async {
      await controller.initialize();

      final router = RouterProfile(
        id: 'home-router',
        name: 'Home',
        address: 'http://192.168.1.1',
        login: 'admin',
        createdAt: DateTime.utc(2026, 4, 23),
        updatedAt: DateTime.utc(2026, 4, 23),
      );
      await routerRepository.saveRouter(router);
      await routerRepository.setSelectedRouterId(router.id);
      statusLoader.nextStatus = SelectedRouterStatus(
        router: router,
        checkedAt: DateTime.utc(2026, 4, 23, 12),
        hasStoredPassword: true,
        connectionTarget: ConnectionTarget(
          kind: ConnectionTargetKind.direct,
          uri: Uri.parse('http://192.168.1.1'),
        ),
        isConnected: true,
      );

      await controller.refresh();

      final action = ClientActionRequest.block(macAddress: 'aa:bb:cc:dd:ee:ff');
      final future = controller.runClientAction(
        status: controller.model!.selectedRouterStatus!,
        request: action,
      );

      expect(controller.busyClientMacs, contains('aa:bb:cc:dd:ee:ff'));

      await future;

      expect(controller.busyClientMacs, isEmpty);
      expect(clientActionService.lastRequest?.macAddress, 'aa:bb:cc:dd:ee:ff');
      expect(statusLoader.loadCount, greaterThanOrEqualTo(2));
    });

    test('section and query setters update state', () async {
      await controller.initialize();

      controller.updateSection(AppSection.wireguard);
      controller.updateSelectedClientQuery('laptop');
      controller.updateSelectedPolicyQuery('default');

      expect(controller.section, AppSection.wireguard);
      expect(controller.selectedClientQuery, 'laptop');
      expect(controller.selectedPolicyQuery, 'default');
    });

    test('setAutoRefreshEnabled persists and updates the model', () async {
      await controller.initialize();

      await controller.setAutoRefreshEnabled(true);

      expect(controller.model!.autoRefreshEnabled, isTrue);
      expect(appPreferencesRepository.preferences.autoRefreshEnabled, isTrue);
    });
  });
}

class _InMemorySecretRepository implements SecretRepository {
  final Map<String, String> _passwords = <String, String>{};

  @override
  Future<void> deleteRouterPassword(String routerId) async {
    _passwords.remove(routerId);
  }

  @override
  Future<String?> readRouterPassword(String routerId) async {
    return _passwords[routerId];
  }

  @override
  Future<void> writeRouterPassword(String routerId, String password) async {
    _passwords[routerId] = password;
  }
}

class _FakeLocalDeviceInfoService implements LocalDeviceInfoService {
  @override
  Future<List<String>> getLocalIpv4Cidrs() async => const <String>['192.168.1.0/24'];

  @override
  Future<List<String>> getLocalMacAddresses() async => const <String>[];
}

class _InMemoryAppPreferencesRepository extends AppPreferencesRepository {
  _InMemoryAppPreferencesRepository()
      : super(File('/tmp/unused_app_preferences.json'));

  AppPreferences preferences = const AppPreferences();

  @override
  Future<AppPreferences> read() async => preferences;

  @override
  Future<void> write(AppPreferences preferences) async {
    this.preferences = preferences;
  }
}

class _FakeSelectedRouterStatusLoader extends SelectedRouterStatusLoader {
  _FakeSelectedRouterStatusLoader()
      : super(
          routerRepository: _NoopRouterRepository(),
          secretRepository: _InMemorySecretRepository(),
          localDeviceInfoService: _FakeLocalDeviceInfoService(),
        );

  SelectedRouterStatus? nextStatus;
  int loadCount = 0;

  @override
  Future<SelectedRouterStatus> load(RouterProfile router) async {
    loadCount += 1;
    return nextStatus ??
        SelectedRouterStatus(
          router: router,
          checkedAt: DateTime.utc(2026, 4, 23, 12),
          hasStoredPassword: true,
        );
  }
}

class _RecordingClientActionService extends ClientActionService {
  _RecordingClientActionService()
      : super(
          secretRepository: _InMemorySecretRepository(),
          localDeviceInfoService: _FakeLocalDeviceInfoService(),
        );

  ClientActionRequest? lastRequest;
  RouterProfile? lastRouter;

  @override
  Future<void> execute({
    required RouterProfile router,
    required ConnectionTarget? connectionTarget,
    required ClientActionRequest request,
  }) async {
    lastRouter = router;
    lastRequest = request;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

class _FakeRouterOnboardingService extends RouterOnboardingService {
  _FakeRouterOnboardingService() : super();

  RouterProfile? nextPreparedProfile;
  String? lastPassword;

  @override
  Future<RouterProfile> validateAndPrepare({
    required RouterProfile profile,
    required String password,
  }) async {
    lastPassword = password;
    return nextPreparedProfile ?? profile;
  }
}

class _NoopRouterRepository implements RouterRepository {
  @override
  Future<void> deleteRouter(String id) async {}

  @override
  Future<RouterProfile?> getRouterById(String id) async => null;

  @override
  Future<List<RouterProfile>> getRouters() async => const <RouterProfile>[];

  @override
  Future<String?> getSelectedRouterId() async => null;

  @override
  Future<void> saveRouter(RouterProfile profile) async {}

  @override
  Future<void> setSelectedRouterId(String? id) async {}
}
