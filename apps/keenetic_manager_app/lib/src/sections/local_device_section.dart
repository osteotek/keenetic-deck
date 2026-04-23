import 'package:flutter/material.dart';
import 'package:platform_capabilities/platform_capabilities.dart';
import 'package:router_core/router_core.dart';

import '../client_action_service.dart';
import '../selected_router_status.dart';
import 'clients_section.dart';

class LocalDeviceSection extends StatelessWidget {
  const LocalDeviceSection({
    super.key,
    required this.status,
    required this.busyClientMacs,
    required this.onClientAction,
  });

  final SelectedRouterStatus? status;
  final Set<String> busyClientMacs;
  final Future<void> Function(
    SelectedRouterStatus status,
    ClientActionRequest request,
  ) onClientAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (status == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select and connect a router to match this device against router clients.',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      );
    }

    final localMacAddresses = status!.localMacAddresses;
    final matchedClients = status!.clients
        .where(
          (ClientDevice client) => localMacAddresses.contains(
            client.macAddress.toLowerCase(),
          ),
        )
        .toList(growable: false)
      ..sort(
        (ClientDevice a, ClientDevice b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'This Device',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Matches local MAC addresses against the selected router client list. '
                  'Traffic inspection is intentionally not portable across all target platforms.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _CapabilityChip(
                      label: 'Local interface discovery',
                      enabled: localMacAddresses.isNotEmpty,
                      icon: AppCapability.localInterfaceDiscovery,
                    ),
                    const _CapabilityChip(
                      label: 'Traffic inspection',
                      enabled: false,
                      icon: AppCapability.localTrafficInspection,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (localMacAddresses.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No local MAC addresses were discovered on this device, so router-client matching is unavailable here.',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          )
        else ...<Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Discovered Local MAC Addresses',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: localMacAddresses
                        .map(
                          (String mac) => Chip(
                            label: Text(mac),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!status!.isConnected)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'The router is not connected yet, so local MAC addresses cannot be matched to router clients.',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            )
          else if (matchedClients.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No selected-router clients matched the local MAC addresses discovered on this device.',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Matched Router Clients',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Matched clients can be managed directly from this screen.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    ...matchedClients.map(
                      (ClientDevice client) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ClientRowCard(
                          client: client,
                          policies: status!.policies,
                          isBusy: busyClientMacs.contains(client.macAddress),
                          onActionSelected: (ClientActionRequest request) {
                            return onClientAction(status!, request);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({
    required this.label,
    required this.enabled,
    required this.icon,
  });

  final String label;
  final bool enabled;
  final AppCapability icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tone = enabled ? colorScheme.primary : colorScheme.outline;

    return Chip(
      avatar: Icon(
        _iconDataFor(icon),
        size: 18,
        color: tone,
      ),
      label: Text(
        enabled ? '$label available' : '$label unavailable',
      ),
      side: BorderSide(color: tone.withValues(alpha: 0.3)),
      backgroundColor: tone.withValues(alpha: 0.12),
      visualDensity: VisualDensity.compact,
    );
  }
}

IconData _iconDataFor(AppCapability capability) {
  switch (capability) {
    case AppCapability.localInterfaceDiscovery:
      return Icons.perm_device_information_outlined;
    case AppCapability.localTrafficInspection:
      return Icons.speed_outlined;
    case AppCapability.wakeOnLan:
      return Icons.power_settings_new_outlined;
  }
}
