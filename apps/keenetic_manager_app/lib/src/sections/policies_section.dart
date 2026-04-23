import 'package:flutter/material.dart';
import 'package:router_core/router_core.dart';

import '../client_action_service.dart';
import '../platform_style.dart';
import '../selected_router_status.dart';
import 'clients_section.dart';

class PoliciesSection extends StatelessWidget {
  const PoliciesSection({
    super.key,
    required this.status,
    required this.query,
    required this.onQueryChanged,
    required this.onRefresh,
    required this.busyClientMacs,
    required this.onClientAction,
  });

  final SelectedRouterStatus? status;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onRefresh;
  final Set<String> busyClientMacs;
  final Future<void> Function(
    SelectedRouterStatus status,
    ClientActionRequest request,
  ) onClientAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMacOS = isMacOSDesignTarget;

    if (status == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select and connect a router to manage policies.',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      );
    }

    if (!status!.isConnected) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Policies will appear here after the selected router connects successfully.',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      );
    }

    final groups = _buildGroups(status!);
    final visibleGroups = _filterGroups(
      groups: groups,
      query: query,
    );
    final summary = _buildSummary(groups);

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
                  'Policies',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Review policy groups first, then manage the clients assigned to each policy.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                SearchActionBar(
                  query: query,
                  labelText: 'Search policies or clients',
                  hintText: 'Policy, name, IP, or MAC',
                  onChanged: onQueryChanged,
                  onRefresh: onRefresh,
                ),
                const SizedBox(height: 16),
                if (isMacOS)
                  _MacPolicySummary(summary: summary)
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      _SummaryTile(
                        label: 'Named policies',
                        value: '${summary.namedPolicyCount}',
                        helper: '${summary.namedPoliciesWithClients} with clients',
                      ),
                      _SummaryTile(
                        label: 'Assigned clients',
                        value: '${summary.assignedClientCount}',
                        helper: 'excluding default and blocked',
                      ),
                      _SummaryTile(
                        label: 'Default clients',
                        value: '${summary.defaultClientCount}',
                        helper: 'router default policy',
                      ),
                      _SummaryTile(
                        label: 'Blocked clients',
                        value: '${summary.blockedClientCount}',
                        helper: 'explicitly denied',
                      ),
                    ],
                  ),
                if (isMacOS) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'This view is arranged like a desktop assignment console: grouped by policy, ordered by This Device, then online, then offline.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (visibleGroups.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                query.trim().isEmpty
                    ? 'No policy data available.'
                    : 'No policies or clients matched "$query".',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          )
        else
          ...visibleGroups.map(
            (_PolicyGroup group) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _PolicyGroupCard(
                group: group,
                status: status!,
                busyClientMacs: busyClientMacs,
                onClientAction: onClientAction,
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.helper,
  });

  final String label;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: 180,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                helper,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyGroupCard extends StatelessWidget {
  const _PolicyGroupCard({
    required this.group,
    required this.status,
    required this.busyClientMacs,
    required this.onClientAction,
  });

  final _PolicyGroup group;
  final SelectedRouterStatus status;
  final Set<String> busyClientMacs;
  final Future<void> Function(
    SelectedRouterStatus status,
    ClientActionRequest request,
  ) onClientAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMacOS = isMacOSDesignTarget;
    final localMatchCount = group.clients
        .where(
          (ClientDevice client) => _isLocalDeviceClient(
            client: client,
            localMacAddresses: status.localMacAddresses,
          ),
        )
        .length;
    final onlineCount = group.clients
        .where(
          (ClientDevice client) =>
              client.connectionState == ClientConnectionState.online,
        )
        .length;
    final offlineCount = group.clients.length - onlineCount;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  group.label,
                  style: theme.textTheme.titleMedium,
                ),
                if (isMacOS)
                  _PolicyMetricLabel(label: '${group.clients.length} clients')
                else
                  Chip(
                    label: Text('${group.clients.length} clients'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (isMacOS)
                  _PolicyMetricLabel(label: '$onlineCount online')
                else
                  Chip(
                    label: Text('$onlineCount online'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (offlineCount > 0)
                  if (isMacOS)
                    _PolicyMetricLabel(label: '$offlineCount offline')
                  else
                    Chip(
                      label: Text('$offlineCount offline'),
                      visualDensity: VisualDensity.compact,
                    ),
                if (localMatchCount > 0)
                  if (isMacOS)
                    _PolicyMetricLabel(
                      label: '$localMatchCount this device',
                      icon: Icons.phone_android_outlined,
                    )
                  else
                    Chip(
                      avatar: const Icon(Icons.phone_android_outlined, size: 16),
                      label: Text('$localMatchCount this device'),
                      visualDensity: VisualDensity.compact,
                    ),
              ],
            ),
            if (group.description != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                group.description!,
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (group.clients.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Ordering: This Device matches first, then online clients, then offline clients.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            if (group.clients.isEmpty)
              Text(
                group.emptyMessage,
                style: theme.textTheme.bodyMedium,
              )
            else
              ...group.clients.map(
                (ClientDevice client) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PolicyClientTile(
                    client: client,
                    status: status,
                    isLocalDevice: _isLocalDeviceClient(
                      client: client,
                      localMacAddresses: status.localMacAddresses,
                    ),
                    isBusy: busyClientMacs.contains(client.macAddress),
                    onClientAction: onClientAction,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PolicyClientTile extends StatelessWidget {
  const _PolicyClientTile({
    required this.client,
    required this.status,
    required this.isLocalDevice,
    required this.isBusy,
    required this.onClientAction,
  });

  final ClientDevice client;
  final SelectedRouterStatus status;
  final bool isLocalDevice;
  final bool isBusy;
  final Future<void> Function(
    SelectedRouterStatus status,
    ClientActionRequest request,
  ) onClientAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMacOS = isMacOSDesignTarget;
    final isOnline = client.connectionState == ClientConnectionState.online;
    final subtitle = <String>[
      if (client.ipAddress != null && client.ipAddress!.isNotEmpty)
        client.ipAddress!,
      client.macAddress,
      if (client.priority != null) 'Priority ${client.priority}',
    ].join(' • ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  isOnline ? Icons.wifi_tethering : Icons.wifi_tethering_error,
                  color: isOnline
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        client.name,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          if (isLocalDevice)
                            if (isMacOS)
                              const _PolicyMetricLabel(
                                label: 'This Device',
                                icon: Icons.phone_android_outlined,
                              )
                            else
                              const Chip(
                                avatar: Icon(
                                  Icons.phone_android_outlined,
                                  size: 16,
                                ),
                                label: Text('This Device'),
                                visualDensity: VisualDensity.compact,
                              ),
                          if (isMacOS)
                            _PolicyMetricLabel(
                              label: isOnline ? 'Online' : 'Offline',
                              icon: isOnline
                                  ? Icons.wifi_tethering
                                  : Icons.wifi_tethering_error,
                            )
                          else
                            Chip(
                              avatar: Icon(
                                isOnline
                                    ? Icons.wifi_tethering
                                    : Icons.wifi_tethering_error,
                                size: 16,
                              ),
                              label: Text(isOnline ? 'Online' : 'Offline'),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isBusy)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                PopupMenuButton<ClientActionRequest>(
                  enabled: !isBusy,
                  tooltip: 'Client actions',
                  onSelected: (ClientActionRequest request) {
                    onClientAction(status, request);
                  },
                  itemBuilder: (BuildContext context) {
                    return <PopupMenuEntry<ClientActionRequest>>[
                      PopupMenuItem<ClientActionRequest>(
                        value: ClientActionRequest.wakeOnLan(
                          macAddress: client.macAddress,
                        ),
                        child: const Text('Wake on LAN'),
                      ),
                    ];
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Quick policy',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _PolicyActionChip(
                  label: 'Block',
                  selected: client.isDenied,
                  enabled: !isBusy,
                  onTap: () => onClientAction(
                    status,
                    ClientActionRequest.block(
                      macAddress: client.macAddress,
                    ),
                  ),
                ),
                _PolicyActionChip(
                  label: 'Default',
                  selected:
                      !client.isDenied &&
                      (client.policyName == null || client.policyName!.isEmpty),
                  enabled: !isBusy,
                  onTap: () => onClientAction(
                    status,
                    ClientActionRequest.setDefaultPolicy(
                      macAddress: client.macAddress,
                    ),
                  ),
                ),
                ...status.policies.map(
                  (VpnPolicy policy) => _PolicyActionChip(
                    label: policy.description,
                    selected:
                        !client.isDenied && client.policyName == policy.name,
                    enabled: !isBusy,
                    onTap: () => onClientAction(
                      status,
                      ClientActionRequest.setNamedPolicy(
                          macAddress: client.macAddress,
                          policyName: policy.name,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyActionChip extends StatelessWidget {
  const _PolicyActionChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (_) => onTap() : null,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MacPolicySummary extends StatelessWidget {
  const _MacPolicySummary({
    required this.summary,
  });

  final _PoliciesSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          _SummaryRow(
            label: 'Named policies',
            value: '${summary.namedPolicyCount}',
            helper: '${summary.namedPoliciesWithClients} with clients',
          ),
          const Divider(height: 1),
          _SummaryRow(
            label: 'Assigned clients',
            value: '${summary.assignedClientCount}',
            helper: 'excluding default and blocked',
          ),
          const Divider(height: 1),
          _SummaryRow(
            label: 'Default clients',
            value: '${summary.defaultClientCount}',
            helper: 'router default policy',
          ),
          const Divider(height: 1),
          _SummaryRow(
            label: 'Blocked clients',
            value: '${summary.blockedClientCount}',
            helper: 'explicitly denied',
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.helper,
  });

  final String label;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(helper, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _PolicyMetricLabel extends StatelessWidget {
  const _PolicyMetricLabel({
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 15),
              const SizedBox(width: 6),
            ],
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

List<_PolicyGroup> _filterGroups({
  required List<_PolicyGroup> groups,
  required String query,
}) {
  final filter = query.trim().toLowerCase();
  if (filter.isEmpty) {
    return groups;
  }

  return groups.where((_PolicyGroup group) {
    if (group.label.toLowerCase().contains(filter) ||
        (group.description?.toLowerCase().contains(filter) ?? false)) {
      return true;
    }

    return group.clients.any((ClientDevice client) {
      return client.name.toLowerCase().contains(filter) ||
          client.macAddress.toLowerCase().contains(filter) ||
          (client.ipAddress?.toLowerCase().contains(filter) ?? false);
    });
  }).toList(growable: false);
}

List<_PolicyGroup> _buildGroups(SelectedRouterStatus status) {
  final policyLookup = <String, VpnPolicy>{
    for (final policy in status.policies) policy.name: policy,
  };
  final groups = <String, List<ClientDevice>>{
    '__blocked__': <ClientDevice>[],
    '__default__': <ClientDevice>[],
    for (final policy in status.policies) policy.name: <ClientDevice>[],
  };

  for (final client in status.clients) {
    final key = _policyKeyFor(client);
    groups.putIfAbsent(key, () => <ClientDevice>[]).add(client);
  }

  return groups.entries.map((_MapEntry<String, List<ClientDevice>> entry) {
    final clients = entry.value.toList(growable: false)
      ..sort((ClientDevice a, ClientDevice b) {
        final localComparison = _policyClientRank(
          client: a,
          localMacAddresses: status.localMacAddresses,
        ).compareTo(
          _policyClientRank(
            client: b,
            localMacAddresses: status.localMacAddresses,
          ),
        );
        if (localComparison != 0) {
          return localComparison;
        }
        final onlineComparison =
            clientOnlineRank(a).compareTo(clientOnlineRank(b));
        if (onlineComparison != 0) {
          return onlineComparison;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    if (entry.key == '__blocked__') {
      return _PolicyGroup(
        key: entry.key,
        label: 'Blocked',
        description: 'Clients explicitly denied access.',
        emptyMessage: 'No clients are blocked right now.',
        clients: clients,
      );
    }

    if (entry.key == '__default__') {
      return _PolicyGroup(
        key: entry.key,
        label: 'Default',
        description: 'Clients using the router default policy.',
        emptyMessage: 'No clients are using the default policy.',
        clients: clients,
      );
    }

    final policy = policyLookup[entry.key];
    return _PolicyGroup(
      key: entry.key,
      label: policy?.description ?? entry.key,
      description: policy == null ? null : 'Policy key: ${policy.name}',
      emptyMessage: 'No clients are currently assigned to this policy.',
      clients: clients,
    );
  }).toList(growable: false)
    ..sort((_PolicyGroup a, _PolicyGroup b) {
      final rankComparison = a.rank.compareTo(b.rank);
      if (rankComparison != 0) {
        return rankComparison;
      }
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
}

bool _isLocalDeviceClient({
  required ClientDevice client,
  required List<String> localMacAddresses,
}) {
  return localMacAddresses.contains(client.macAddress.toLowerCase());
}

int _policyClientRank({
  required ClientDevice client,
  required List<String> localMacAddresses,
}) {
  if (_isLocalDeviceClient(
    client: client,
    localMacAddresses: localMacAddresses,
  )) {
    return 0;
  }
  return 1;
}

_PoliciesSummary _buildSummary(List<_PolicyGroup> groups) {
  final namedGroups =
      groups.where((_PolicyGroup group) => group.kind == _PolicyGroupKind.named);
  final defaultGroup = groups.firstWhere(
    (_PolicyGroup group) => group.key == '__default__',
  );
  final blockedGroup = groups.firstWhere(
    (_PolicyGroup group) => group.key == '__blocked__',
  );

  return _PoliciesSummary(
    namedPolicyCount: namedGroups.length,
    namedPoliciesWithClients:
        namedGroups.where((_PolicyGroup group) => group.clients.isNotEmpty).length,
    assignedClientCount:
        namedGroups.fold(0, (int sum, _PolicyGroup group) => sum + group.clients.length),
    defaultClientCount: defaultGroup.clients.length,
    blockedClientCount: blockedGroup.clients.length,
  );
}

String _policyKeyFor(ClientDevice client) {
  if (client.isDenied) {
    return '__blocked__';
  }
  if (client.policyName == null || client.policyName!.isEmpty) {
    return '__default__';
  }
  return client.policyName!;
}

class _PoliciesSummary {
  const _PoliciesSummary({
    required this.namedPolicyCount,
    required this.namedPoliciesWithClients,
    required this.assignedClientCount,
    required this.defaultClientCount,
    required this.blockedClientCount,
  });

  final int namedPolicyCount;
  final int namedPoliciesWithClients;
  final int assignedClientCount;
  final int defaultClientCount;
  final int blockedClientCount;
}

enum _PolicyGroupKind {
  blocked,
  defaultPolicy,
  named,
}

class _PolicyGroup {
  const _PolicyGroup({
    required this.key,
    required this.label,
    required this.emptyMessage,
    required this.clients,
    this.description,
  });

  final String key;
  final String label;
  final String emptyMessage;
  final String? description;
  final List<ClientDevice> clients;

  _PolicyGroupKind get kind {
    switch (key) {
      case '__blocked__':
        return _PolicyGroupKind.blocked;
      case '__default__':
        return _PolicyGroupKind.defaultPolicy;
      default:
        return _PolicyGroupKind.named;
    }
  }

  int get rank {
    switch (kind) {
      case _PolicyGroupKind.blocked:
        return 0;
      case _PolicyGroupKind.defaultPolicy:
        return 1;
      case _PolicyGroupKind.named:
        return 2;
    }
  }
}

typedef _MapEntry<K, V> = MapEntry<K, V>;
