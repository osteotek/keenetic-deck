import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:router_core/router_core.dart';

import 'src/app_section.dart';
import 'src/apple_native_controls.dart';
import 'src/client_action_service.dart';
import 'src/platform_style.dart';
import 'src/router_editor_dialog.dart';
import 'src/router_overview_controller.dart';
import 'src/router_overview_model.dart';
import 'src/selected_router_banner.dart';
import 'src/sections/clients_section.dart';
import 'src/sections/empty_state_section.dart';
import 'src/sections/local_device_section.dart';
import 'src/sections/policies_section.dart';
import 'src/sections/routers_section.dart';
import 'src/sections/settings_section.dart';
import 'src/sections/wireguard_section.dart';
import 'src/selected_router_status.dart';

void main() {
  runApp(const KeeneticManagerApp());
}

class KeeneticManagerApp extends StatelessWidget {
  const KeeneticManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keenetic Deck',
      themeMode: ThemeMode.system,
      theme: _buildAppTheme(brightness: Brightness.light),
      darkTheme: _buildAppTheme(brightness: Brightness.dark),
      home: const RouterOverviewPage(),
    );
  }
}

class RouterOverviewPage extends StatefulWidget {
  const RouterOverviewPage({
    super.key,
    this.controller,
  });

  final RouterOverviewController? controller;

  @override
  State<RouterOverviewPage> createState() => _RouterOverviewPageState();
}

class _RouterOverviewPageState extends State<RouterOverviewPage> {
  static const Duration _autoRefreshInterval = Duration(seconds: 2);

  late final RouterOverviewController _controller;
  late final bool _ownsController;
  Timer? _autoRefreshTimer;
  bool _appIsResumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _controller = widget.controller ?? RouterOverviewController();
    _ownsController = widget.controller == null;
    if (_ownsController) {
      _controller.initialize();
    }
    _autoRefreshTimer = Timer.periodic(
      _autoRefreshInterval,
      (_) => _onAutoRefreshTick(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _showRouterEditor({
    RouterProfile? existing,
  }) async {
    final hasStoredPassword = await _controller.hasStoredPassword(existing);
    if (!mounted) {
      return;
    }
    final result = await showDialog<RouterFormResult>(
      context: context,
      builder: (BuildContext context) => RouterEditorDialog(
        existing: existing,
        hasStoredPassword: hasStoredPassword,
      ),
    );

    if (result == null) {
      return;
    }

    try {
      await _controller.saveRouter(
        result: result,
        existing: existing,
      );
    } on RouterApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _deleteRouter(RouterProfile router) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete router?'),
              content: Text(
                'Delete "${router.name}" from local storage and remove its saved password?',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    await _controller.deleteRouter(router);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${router.name}')),
    );
  }

  Future<void> _runClientAction({
    required SelectedRouterStatus status,
    required ClientActionRequest request,
  }) async {
    try {
      await _controller.runClientAction(
        status: status,
        request: request,
      );

      if (!mounted) {
        return;
      }

      final successMessage = switch (request.kind) {
        ClientActionKind.setDefaultPolicy =>
          'Default policy applied to ${request.macAddress}',
        ClientActionKind.setNamedPolicy =>
          'Policy ${request.policyName} applied to ${request.macAddress}',
        ClientActionKind.block => 'Blocked ${request.macAddress}',
        ClientActionKind.wakeOnLan =>
          'Wake-on-LAN sent to ${request.macAddress}',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } on RouterApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  void _onAutoRefreshTick() {
    if (!mounted || !_appIsResumed || !_shouldAutoRefresh()) {
      return;
    }
    _controller.refresh();
  }

  bool _shouldAutoRefresh() {
    final model = _controller.model;
    if (_controller.isLoading ||
        _controller.isRefreshing ||
        _controller.error != null ||
        model == null ||
        !model.autoRefreshEnabled ||
        model.routers.isEmpty ||
        model.selectedRouterId == null) {
      return false;
    }

    switch (_controller.section) {
      case AppSection.localDevice:
      case AppSection.clients:
      case AppSection.policies:
      case AppSection.wireguard:
        return true;
      case AppSection.routers:
      case AppSection.settings:
        return false;
    }
  }

  late final WidgetsBindingObserver _lifecycleObserver =
      _RouterOverviewLifecycleObserver(
        onLifecycleChanged: (AppLifecycleState state) {
          _appIsResumed = switch (state) {
            AppLifecycleState.resumed => true,
            AppLifecycleState.inactive => false,
            AppLifecycleState.hidden => false,
            AppLifecycleState.paused => false,
            AppLifecycleState.detached => false,
          };
        },
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, Widget? child) {
        final model = _controller.model;
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final isMacOS = isMacOSDesignTarget;
            final isApple = isAppleNativeTarget;
            final useRailNavigation = !isMacOS && constraints.maxWidth >= 960;
            return Scaffold(
              appBar: AppBar(
                toolbarHeight: isApple ? 74 : null,
                titleSpacing: isApple ? 12 : null,
                backgroundColor: isApple ? Colors.transparent : null,
                surfaceTintColor: isApple ? Colors.transparent : null,
                elevation: 0,
                scrolledUnderElevation: 0,
                title: isApple
                    ? _AppleToolbarTitle(
                        section: _controller.section,
                        status: model?.selectedRouterStatus,
                        isRefreshing: _controller.isRefreshing,
                      )
                    : _AppBarTitle(
                        sectionLabel: _controller.section.label,
                        status: model?.selectedRouterStatus,
                        isRefreshing: _controller.isRefreshing,
                      ),
                actions: isApple
                    ? <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _AppleToolbarActions(
                            showAddRouter:
                                isMacOS && _shouldShowAddRouterFab(model),
                            onAddRouter: () => _showRouterEditor(),
                            onRefresh: _controller.refresh,
                          ),
                        ),
                      ]
                    : <Widget>[
                        if (isMacOS && _shouldShowAddRouterFab(model))
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AppleNativeButton(
                              onPressed: () => _showRouterEditor(),
                              label: 'Add Router',
                              style: AppleNativeActionStyle.prominentGlass,
                            ),
                          ),
                        AppleNativeIconButton(
                          onPressed: _controller.refresh,
                          appleSymbol: 'arrow.clockwise',
                          fallbackIcon: Icons.refresh,
                          tooltip: 'Refresh',
                        ),
                      ],
                bottom: isApple
                    ? const PreferredSize(
                        preferredSize: Size.fromHeight(8),
                        child: SizedBox(height: 8),
                      )
                    : null,
              ),
              body: _buildBody(useRailNavigation: useRailNavigation),
              bottomNavigationBar: _buildBottomNavigationBar(
                model: model,
                useRailNavigation: useRailNavigation,
              ),
              floatingActionButton:
                  !isMacOS && _shouldShowAddRouterFab(model)
                      ? FloatingActionButton.extended(
                          onPressed: () => _showRouterEditor(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add router'),
                        )
                      : null,
            );
          },
        );
      },
    );
  }

  Widget _buildBody({
    required bool useRailNavigation,
  }) {
    if (_controller.isLoading && _controller.model == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to load router storage.\n${_controller.error}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final model = _controller.model!;
    if (model.routers.isEmpty) {
      return EmptyStateSection(
        storagePath: model.storagePath,
        onRefresh: _controller.refresh,
      );
    }

    final content = _buildSectionContent(model);
    final sectionPane = _buildRefreshableSectionPane(
      model: model,
      content: content,
    );
    if (useRailNavigation) {
      return Row(
        children: <Widget>[
          NavigationRail(
            selectedIndex: AppSection.values.indexOf(_controller.section),
            onDestinationSelected: (int index) {
              _controller.updateSection(AppSection.values[index]);
            },
            labelType: NavigationRailLabelType.all,
            destinations: AppSection.values
                .map(
                  (AppSection section) => NavigationRailDestination(
                    icon: Icon(section.icon),
                    label: Text(section.label),
                  ),
                )
                .toList(growable: false),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: sectionPane),
        ],
      );
    }

    return sectionPane;
  }

  Widget? _buildBottomNavigationBar({
    required RouterOverviewModel? model,
    required bool useRailNavigation,
  }) {
    if (useRailNavigation ||
        _controller.isLoading ||
        _controller.error != null ||
        model == null ||
        model.routers.isEmpty) {
      return null;
    }

    return AppleNativeTabBar(
      currentIndex: AppSection.values.indexOf(_controller.section),
      onTap: (int index) {
        _controller.updateSection(AppSection.values[index]);
      },
      split: false,
      rightCount: 1,
      items: AppSection.values
          .map(
            (AppSection section) => AppleNativeTabBarItem(
              label: section.label,
              appleSymbol: section.appleSymbol,
              fallbackIcon: section.icon,
            ),
          )
          .toList(growable: false),
    );
  }

  bool _shouldShowAddRouterFab(RouterOverviewModel? model) {
    if (_controller.isLoading || _controller.error != null || model == null) {
      return false;
    }

    if (model.routers.isEmpty) {
      return true;
    }

    return _controller.section == AppSection.routers;
  }

  Widget _buildRefreshableSectionPane({
    required RouterOverviewModel model,
    required Widget content,
  }) {
    final banner = SelectedRouterBanner(
      selectedRouterId: model.selectedRouterId,
      status: model.selectedRouterStatus,
      onRefresh: _controller.refresh,
      onOpenRouters: () => _controller.updateSection(AppSection.routers),
    );

    final refreshableContent = _supportsPullToRefresh()
        ? RefreshIndicator(
            onRefresh: _controller.refresh,
            child: content,
          )
        : content;

    return Column(
      children: <Widget>[
        if (model.selectedRouterId == null ||
            (model.selectedRouterStatus != null &&
                !model.selectedRouterStatus!.isConnected))
          banner,
        Expanded(child: refreshableContent),
      ],
    );
  }

  bool _supportsPullToRefresh() {
    switch (_controller.section) {
      case AppSection.localDevice:
      case AppSection.clients:
      case AppSection.policies:
      case AppSection.wireguard:
      case AppSection.routers:
      case AppSection.settings:
        return true;
    }
  }

  Widget _buildSectionContent(RouterOverviewModel model) {
    switch (_controller.section) {
      case AppSection.localDevice:
        return LocalDeviceSection(
          status: model.selectedRouterStatus,
          busyClientMacs: _controller.busyClientMacs,
          onClientAction:
              (SelectedRouterStatus status, ClientActionRequest request) {
            return _runClientAction(
              status: status,
              request: request,
            );
          },
        );
      case AppSection.clients:
        return ClientsSection(
          status: model.selectedRouterStatus,
          query: _controller.selectedClientQuery,
          onQueryChanged: _controller.updateSelectedClientQuery,
          onRefresh: _controller.refresh,
          busyClientMacs: _controller.busyClientMacs,
          onClientAction:
              (SelectedRouterStatus status, ClientActionRequest request) {
            return _runClientAction(
              status: status,
              request: request,
            );
          },
        );
      case AppSection.policies:
        return PoliciesSection(
          status: model.selectedRouterStatus,
          query: _controller.selectedPolicyQuery,
          onQueryChanged: _controller.updateSelectedPolicyQuery,
          onRefresh: _controller.refresh,
          busyClientMacs: _controller.busyClientMacs,
          onClientAction:
              (SelectedRouterStatus status, ClientActionRequest request) {
            return _runClientAction(
              status: status,
              request: request,
            );
          },
        );
      case AppSection.wireguard:
        return WireGuardSection(
          status: model.selectedRouterStatus,
        );
      case AppSection.routers:
        return RoutersSection(
          model: model,
          onSelect: _controller.selectRouter,
          onEdit: (RouterProfile router) => _showRouterEditor(existing: router),
          onDelete: _deleteRouter,
        );
      case AppSection.settings:
        return SettingsSection(
          model: model,
          onAutoRefreshChanged: (bool value) {
            _controller.setAutoRefreshEnabled(value);
          },
        );
    }
  }
}

ThemeData _buildAppTheme({
  required Brightness brightness,
}) {
  final isApple = isAppleNativeTarget;
  final colorScheme = isApple
      ? _buildMacOSColorScheme(brightness)
      : ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: brightness,
        );

  final base = ThemeData(
    brightness: brightness,
    colorScheme: colorScheme,
    useMaterial3: true,
    platform: isApple ? defaultTargetPlatform : defaultTargetPlatform,
  );

  if (!isApple) {
    return base;
  }

  final outline = colorScheme.outlineVariant.withValues(alpha: 0.55);

  return base.copyWith(
    scaffoldBackgroundColor: brightness == Brightness.light
        ? const Color(0xFFF3F4F7)
        : const Color(0xFF1E1F24),
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface.withValues(alpha: 0.92),
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 18,
      toolbarHeight: 58,
      actionsPadding: const EdgeInsets.only(right: 10),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: outline),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: outline,
      thickness: 1,
      space: 1,
    ),
    chipTheme: base.chipTheme.copyWith(
      side: BorderSide(color: outline),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      backgroundColor: colorScheme.surfaceContainerLow,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.8),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        side: BorderSide(color: outline),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
  );
}

ColorScheme _buildMacOSColorScheme(Brightness brightness) {
  if (brightness == Brightness.dark) {
    return const ColorScheme.dark(
      primary: Color(0xFF5FD0C4),
      onPrimary: Color(0xFF032A26),
      secondary: Color(0xFF9BCBC4),
      onSecondary: Color(0xFF0B2220),
      error: Color(0xFFFF8C8C),
      onError: Color(0xFF3E0909),
      surface: Color(0xFF2A2C31),
      onSurface: Color(0xFFE7E9EE),
      surfaceContainerLow: Color(0xFF25272D),
      surfaceContainerHighest: Color(0xFF343840),
      outlineVariant: Color(0xFF4A4F59),
    );
  }

  return const ColorScheme.light(
    primary: Color(0xFF0D7C70),
    onPrimary: Color(0xFFF6FFFD),
    secondary: Color(0xFF4E6B67),
    onSecondary: Color(0xFFF8FBFA),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFBF9),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1B1C20),
    surfaceContainerLow: Color(0xFFF7F8FA),
    surfaceContainerHighest: Color(0xFFEAECEF),
    outlineVariant: Color(0xFFD6DADF),
  );
}

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({
    required this.sectionLabel,
    required this.status,
    required this.isRefreshing,
  });

  final String sectionLabel;
  final SelectedRouterStatus? status;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final subtitle = _buildSubtitle();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(sectionLabel),
        if (subtitle != null)
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  String? _buildSubtitle() {
    if (isRefreshing) {
      return 'Refreshing router data...';
    }

    if (status == null) {
      return null;
    }

    if (status!.isConnected) {
      return 'Connected • checked ${_formatTime(status!.checkedAt)}';
    }

    if (!status!.hasStoredPassword) {
      return 'Password missing';
    }

    return 'Connection failed • checked ${_formatTime(status!.checkedAt)}';
  }
}

class _AppleToolbarActions extends StatelessWidget {
  const _AppleToolbarActions({
    required this.showAddRouter,
    required this.onAddRouter,
    required this.onRefresh,
  });

  final bool showAddRouter;
  final VoidCallback onAddRouter;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (showAddRouter) ...<Widget>[
              AppleNativeButton(
                onPressed: onAddRouter,
                label: 'Add Router',
                style: AppleNativeActionStyle.prominentGlass,
              ),
              const SizedBox(width: 4),
            ],
            AppleNativeIconButton(
              onPressed: onRefresh,
              appleSymbol: 'arrow.clockwise',
              fallbackIcon: Icons.refresh,
              tooltip: 'Refresh',
              style: AppleNativeActionStyle.glass,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppleToolbarTitle extends StatelessWidget {
  const _AppleToolbarTitle({
    required this.section,
    required this.status,
    required this.isRefreshing,
  });

  final AppSection section;
  final SelectedRouterStatus? status;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = _buildSubtitle();
    final statusTone = _statusTone(theme.colorScheme);
    final statusSymbol = _statusSymbol();

    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: statusTone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: AppleNativeSymbolIcon(
                    appleSymbol: statusSymbol,
                    fallbackIcon: section.icon,
                    size: 16,
                    color: statusTone,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      section.label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _buildSubtitle() {
    if (isRefreshing) {
      return 'Refreshing router data...';
    }

    if (status == null) {
      return 'No router status yet';
    }

    if (status!.isConnected) {
      return 'Connected • checked ${_formatTime(status!.checkedAt)}';
    }

    if (!status!.hasStoredPassword) {
      return 'Password missing';
    }

    return 'Connection failed • checked ${_formatTime(status!.checkedAt)}';
  }

  String _statusSymbol() {
    if (isRefreshing) {
      return 'arrow.triangle.2.circlepath';
    }

    if (status == null) {
      return section.appleSymbol;
    }

    if (status!.isConnected) {
      return 'checkmark.circle';
    }

    if (!status!.hasStoredPassword) {
      return 'lock.circle';
    }

    return 'exclamationmark.triangle';
  }

  Color _statusTone(ColorScheme colorScheme) {
    if (isRefreshing) {
      return colorScheme.primary;
    }

    if (status == null) {
      return colorScheme.secondary;
    }

    if (status!.isConnected) {
      return colorScheme.primary;
    }

    if (!status!.hasStoredPassword) {
      return colorScheme.secondary;
    }

    return colorScheme.error;
  }
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int part) => part.toString().padLeft(2, '0');
  return '${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';
}

class _RouterOverviewLifecycleObserver with WidgetsBindingObserver {
  _RouterOverviewLifecycleObserver({
    required this.onLifecycleChanged,
  });

  final ValueChanged<AppLifecycleState> onLifecycleChanged;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onLifecycleChanged(state);
  }
}
