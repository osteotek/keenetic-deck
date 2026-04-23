import 'package:router_core/router_core.dart';

import 'selected_router_status.dart';

class RouterOverviewModel {
  const RouterOverviewModel({
    required this.storagePath,
    required this.routers,
    required this.selectedRouterId,
    required this.passwordStored,
    required this.selectedRouterStatus,
    required this.autoRefreshEnabled,
  });

  final String storagePath;
  final List<RouterProfile> routers;
  final String? selectedRouterId;
  final Map<String, bool> passwordStored;
  final SelectedRouterStatus? selectedRouterStatus;
  final bool autoRefreshEnabled;

  RouterOverviewModel copyWith({
    String? storagePath,
    List<RouterProfile>? routers,
    Object? selectedRouterId = _unset,
    Map<String, bool>? passwordStored,
    Object? selectedRouterStatus = _unset,
    bool? autoRefreshEnabled,
  }) {
    return RouterOverviewModel(
      storagePath: storagePath ?? this.storagePath,
      routers: routers ?? this.routers,
      selectedRouterId:
          identical(selectedRouterId, _unset) ? this.selectedRouterId : selectedRouterId as String?,
      passwordStored: passwordStored ?? this.passwordStored,
      selectedRouterStatus:
          identical(selectedRouterStatus, _unset)
              ? this.selectedRouterStatus
              : selectedRouterStatus as SelectedRouterStatus?,
      autoRefreshEnabled: autoRefreshEnabled ?? this.autoRefreshEnabled,
    );
  }
}

const Object _unset = Object();
