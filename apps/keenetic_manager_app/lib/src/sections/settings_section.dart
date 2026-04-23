import 'package:flutter/material.dart';
import 'package:platform_capabilities/platform_capabilities.dart';

import '../apple_native_controls.dart';
import '../app_metadata.dart';
import '../platform_style.dart';
import '../router_overview_model.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.model,
    required this.onAutoRefreshChanged,
  });

  final RouterOverviewModel model;
  final ValueChanged<bool> onAutoRefreshChanged;

  @override
  Widget build(BuildContext context) {
    final diagnostics = _buildDiagnostics(model);
    final isMacOS = isMacOSDesignTarget;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(isMacOS ? 20 : 16),
      children: <Widget>[
        _SettingsGroup(
          title: 'App',
          isMacOS: isMacOS,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _InfoRow(label: 'Name', value: AppMetadata.name),
              _InfoRow(label: 'Package', value: AppMetadata.packageId),
              _InfoRow(
                label: 'Android ID',
                value: AppMetadata.androidApplicationId,
              ),
              _InfoRow(
                label: 'Linux ID',
                value: AppMetadata.linuxApplicationId,
              ),
              _InfoRow(label: 'Version', value: AppMetadata.version),
              _InfoRow(
                label: 'Channel',
                value: AppMetadata.releaseChannel,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Behavior',
          isMacOS: isMacOS,
          child: AppleNativeSwitchRow(
            title: 'Auto-refresh live router screens',
            subtitle: model.autoRefreshEnabled
                ? 'Enabled. Connected clients, policies, WireGuard, and This Device screens refresh every 2 seconds.'
                : 'Disabled by default. Live router screens only refresh when you pull to refresh or press Update/Refresh.',
            value: model.autoRefreshEnabled,
            onChanged: onAutoRefreshChanged,
          ),
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Storage',
          isMacOS: isMacOS,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SelectableText(model.storagePath),
              const SizedBox(height: 12),
              Text(
                '${model.routers.length} routers stored locally',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Release Notes',
          isMacOS: isMacOS,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: AppMetadata.releaseNotes
                .map(
                  (String note) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 6, right: 8),
                          child: Icon(Icons.fiber_manual_record, size: 10),
                        ),
                        Expanded(child: Text(note)),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Platform Capabilities',
          isMacOS: isMacOS,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Capability diagnostics describe what this build can reliably do across platforms.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ...diagnostics.map(
                (_CapabilityDiagnostic diagnostic) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CapabilityTile(diagnostic: diagnostic),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.isMacOS,
    required this.child,
  });

  final String title;
  final bool isMacOS;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = Padding(
      padding: EdgeInsets.all(isMacOS ? 18 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium,
          ),
          SizedBox(height: isMacOS ? 10 : 8),
          child,
        ],
      ),
    );

    if (!isMacOS) {
      return Card(child: body);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: body,
    );
  }
}

List<_CapabilityDiagnostic> _buildDiagnostics(RouterOverviewModel model) {
  final status = model.selectedRouterStatus;
  final localMacs = status?.localMacAddresses ?? const <String>[];

  return <_CapabilityDiagnostic>[
    _CapabilityDiagnostic(
      capability: AppCapability.localInterfaceDiscovery,
      title: 'Local interface discovery',
      description: localMacs.isEmpty
          ? 'No local MAC addresses were discovered for the current runtime.'
          : 'Discovered ${localMacs.length} local MAC addresses for device matching.',
      isAvailable: localMacs.isNotEmpty,
    ),
    const _CapabilityDiagnostic(
      capability: AppCapability.localTrafficInspection,
      title: 'Traffic inspection',
      description:
          'Per-interface traffic inspection is intentionally disabled in the cross-platform shell because it is not portable across Android, iOS, macOS, and Linux.',
      isAvailable: false,
    ),
    _CapabilityDiagnostic(
      capability: AppCapability.wakeOnLan,
      title: 'Wake-on-LAN',
      description: status?.isConnected == true
          ? 'The selected router is connected, so Wake-on-LAN style actions can be routed through router APIs when implemented in the UI.'
          : 'Wake-on-LAN depends on an active router connection and has not been surfaced as a dedicated workflow yet.',
      isAvailable: status?.isConnected == true,
    ),
  ];
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _CapabilityTile extends StatelessWidget {
  const _CapabilityTile({
    required this.diagnostic,
  });

  final _CapabilityDiagnostic diagnostic;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tone =
        diagnostic.isAvailable ? colorScheme.primary : colorScheme.outline;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: tone.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                _iconFor(diagnostic.capability),
                color: tone,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    diagnostic.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(diagnostic.description),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Chip(
              label: Text(diagnostic.isAvailable ? 'Available' : 'Unavailable'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(AppCapability capability) {
  switch (capability) {
    case AppCapability.localInterfaceDiscovery:
      return Icons.perm_device_information_outlined;
    case AppCapability.localTrafficInspection:
      return Icons.speed_outlined;
    case AppCapability.wakeOnLan:
      return Icons.power_settings_new_outlined;
  }
}

class _CapabilityDiagnostic {
  const _CapabilityDiagnostic({
    required this.capability,
    required this.title,
    required this.description,
    required this.isAvailable,
  });

  final AppCapability capability;
  final String title;
  final String description;
  final bool isAvailable;
}
