import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:platform_capabilities/platform_capabilities.dart';
import 'package:router_core/router_core.dart';
import 'package:router_storage/router_storage.dart';

import 'app_preferences_repository.dart';
import 'app_section.dart';
import 'client_action_service.dart';
import 'file_secret_repository.dart';
import 'router_editor_dialog.dart';
import 'router_onboarding_service.dart';
import 'router_overview_model.dart';
import 'selected_router_status.dart';
import 'selected_router_status_loader.dart';

class RouterOverviewController extends ChangeNotifier {
  RouterOverviewController({
    JsonRouterRepository? routerRepository,
    SecretRepository? secretRepository,
    LocalDeviceInfoService? localDeviceInfoService,
    SelectedRouterStatusLoader? selectedRouterStatusLoader,
    ClientActionService? clientActionService,
    RouterOnboardingService? routerOnboardingService,
    AppPreferencesRepository? appPreferencesRepository,
    String? storagePath,
  })  : _routerRepository = routerRepository,
        _secretRepository = secretRepository,
        _localDeviceInfoService = localDeviceInfoService,
        _selectedRouterStatusLoader = selectedRouterStatusLoader,
        _clientActionService = clientActionService,
        _routerOnboardingService = routerOnboardingService,
        _appPreferencesRepository = appPreferencesRepository,
        _storagePath = storagePath;

  JsonRouterRepository? _routerRepository;
  SecretRepository? _secretRepository;
  LocalDeviceInfoService? _localDeviceInfoService;
  SelectedRouterStatusLoader? _selectedRouterStatusLoader;
  ClientActionService? _clientActionService;
  RouterOnboardingService? _routerOnboardingService;
  AppPreferencesRepository? _appPreferencesRepository;
  AppPreferences? _appPreferences;
  String? _storagePath;

  bool _isLoading = true;
  bool _isRefreshing = false;
  Object? _error;
  RouterOverviewModel? _model;
  AppSection _section = AppSection.routers;
  String _selectedClientQuery = '';
  String _selectedPolicyQuery = '';
  final Set<String> _busyClientMacs = <String>{};

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  Object? get error => _error;
  RouterOverviewModel? get model => _model;
  AppSection get section => _section;
  String get selectedClientQuery => _selectedClientQuery;
  String get selectedPolicyQuery => _selectedPolicyQuery;
  Set<String> get busyClientMacs => Set<String>.unmodifiable(_busyClientMacs);

  Future<void> initialize() async {
    await _ensureDependencies();
    await refresh();
  }

  Future<void> refresh() async {
    final hasExistingModel = _model != null;
    if (hasExistingModel) {
      _isRefreshing = true;
    } else {
      _isLoading = true;
    }
    _error = null;
    notifyListeners();

    try {
      _model = await _loadModel();
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  void updateSection(AppSection section) {
    if (_section == section) {
      return;
    }
    _section = section;
    notifyListeners();
  }

  void updateSelectedClientQuery(String value) {
    if (_selectedClientQuery == value) {
      return;
    }
    _selectedClientQuery = value;
    notifyListeners();
  }

  void updateSelectedPolicyQuery(String value) {
    if (_selectedPolicyQuery == value) {
      return;
    }
    _selectedPolicyQuery = value;
    notifyListeners();
  }

  Future<void> setAutoRefreshEnabled(bool value) async {
    _appPreferences = (_appPreferences ?? const AppPreferences()).copyWith(
      autoRefreshEnabled: value,
    );
    await _appPreferencesRepository!.write(_appPreferences!);
    if (_model != null) {
      _model = _model!.copyWith(autoRefreshEnabled: value);
      notifyListeners();
    }
  }

  Future<void> saveRouter({
    required RouterFormResult result,
    RouterProfile? existing,
  }) async {
    final now = DateTime.now().toUtc();
    final routers = await _routerRepository!.getRouters();
    final storedPassword = existing == null
        ? null
        : await _secretRepository!.readRouterPassword(existing.id);
    final passwordToValidate = result.password ?? storedPassword;

    if (passwordToValidate == null || passwordToValidate.isEmpty) {
      throw const RouterAuthenticationException(
        'A password is required to validate and save this router.',
      );
    }

    final candidate = RouterProfile(
      id: existing?.id ?? routerIdFor(result.name, result.address, routers),
      name: result.name,
      address: result.address,
      login: result.login,
      networkIp: existing?.networkIp,
      keendnsUrls: existing?.keendnsUrls ?? const <String>[],
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    final profile = await _routerOnboardingService!.validateAndPrepare(
      profile: candidate,
      password: passwordToValidate,
    );

    await _routerRepository!.saveRouter(profile);
    if (result.password case final password? when password.isNotEmpty) {
      await _secretRepository!.writeRouterPassword(profile.id, password);
    } else if (storedPassword != null && storedPassword.isNotEmpty) {
      await _secretRepository!.writeRouterPassword(profile.id, storedPassword);
    }

    final selectedRouterId = await _routerRepository!.getSelectedRouterId();
    if (selectedRouterId == null) {
      await _routerRepository!.setSelectedRouterId(profile.id);
    }

    await refresh();
  }

  Future<void> selectRouter(String routerId) async {
    await _routerRepository!.setSelectedRouterId(routerId);
    await refresh();
  }

  Future<void> deleteRouter(RouterProfile router) async {
    await _routerRepository!.deleteRouter(router.id);
    await _secretRepository!.deleteRouterPassword(router.id);
    await refresh();
  }

  Future<bool> hasStoredPassword(RouterProfile? router) async {
    if (router == null) {
      return false;
    }
    return (await _secretRepository!.readRouterPassword(router.id)) != null;
  }

  Future<void> runClientAction({
    required SelectedRouterStatus status,
    required ClientActionRequest request,
  }) async {
    _busyClientMacs.add(request.macAddress);
    notifyListeners();

    try {
      await _clientActionService!.execute(
        router: status.router,
        connectionTarget: status.connectionTarget,
        request: request,
      );
      await refresh();
    } finally {
      _busyClientMacs.remove(request.macAddress);
      notifyListeners();
    }
  }

  Future<void> _ensureDependencies() async {
    if (_appPreferencesRepository != null && _appPreferences == null) {
      _appPreferences = await _appPreferencesRepository!.read();
    }

    if (_routerRepository != null &&
        _secretRepository != null &&
        _localDeviceInfoService != null &&
        _selectedRouterStatusLoader != null &&
        _clientActionService != null &&
        _routerOnboardingService != null &&
        _appPreferencesRepository != null &&
        _appPreferences != null &&
        _storagePath != null) {
      return;
    }

    final directory = await getApplicationSupportDirectory();
    _storagePath ??= defaultRouterStorageFile(directory).path;
    _routerRepository ??= JsonRouterRepository(
      defaultRouterStorageFile(directory),
    );
    _secretRepository ??= switch (defaultTargetPlatform) {
      TargetPlatform.macOS => FileSecretRepository(
          File('${directory.path}/router_secrets.v1.json'),
        ),
      _ => SecureStorageSecretRepository(
          FlutterSecureKeyValueStore(),
        ),
    };
    _localDeviceInfoService ??= BestEffortLocalDeviceInfoService.system();
    _appPreferencesRepository ??= AppPreferencesRepository(
      File('${directory.path}/app_preferences.v1.json'),
    );
    _appPreferences ??= await _appPreferencesRepository!.read();
    _selectedRouterStatusLoader ??= SelectedRouterStatusLoader(
      routerRepository: _routerRepository!,
      secretRepository: _secretRepository!,
      localDeviceInfoService: _localDeviceInfoService!,
    );
    _clientActionService ??= ClientActionService(
      secretRepository: _secretRepository!,
      localDeviceInfoService: _localDeviceInfoService!,
    );
    _routerOnboardingService ??= RouterOnboardingService();
  }

  Future<RouterOverviewModel> _loadModel() async {
    final repository = _routerRepository!;
    final secretRepository = _secretRepository!;
    final routers = (await repository.getRouters()).toList(growable: true);
    final selectedRouterId = await repository.getSelectedRouterId();
    final passwordStored = <String, bool>{};

    for (final router in routers) {
      passwordStored[router.id] =
          (await secretRepository.readRouterPassword(router.id)) != null;
    }

    SelectedRouterStatus? selectedRouterStatus;
    if (selectedRouterId != null) {
      final selectedIndex = routers
          .indexWhere((RouterProfile router) => router.id == selectedRouterId);
      if (selectedIndex != -1) {
        selectedRouterStatus = await _selectedRouterStatusLoader!.load(
          routers[selectedIndex],
        );
        routers[selectedIndex] = selectedRouterStatus.router;
      }
    }

    return RouterOverviewModel(
      storagePath: _storagePath!,
      routers: routers,
      selectedRouterId: selectedRouterId,
      passwordStored: passwordStored,
      selectedRouterStatus: selectedRouterStatus,
      autoRefreshEnabled: _appPreferences!.autoRefreshEnabled,
    );
  }
}
