import 'package:flutter/material.dart';
import 'package:router_core/router_core.dart';

import '../apple_native_controls.dart';
import '../client_action_service.dart';
import '../platform_style.dart';
import '../selected_router_status.dart';

class ClientsSection extends StatelessWidget {
  const ClientsSection({
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
    final isApple = isAppleNativeTarget;

    if (status == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select and connect a router to see its clients.',
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
                'Clients will appear here after the selected router connects successfully.',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      );
    }

    final filteredClients = status!.clients.where((ClientDevice client) {
      final text = query.trim().toLowerCase();
      if (text.isEmpty) {
        return true;
      }
      return client.name.toLowerCase().contains(text) ||
          client.macAddress.toLowerCase().contains(text) ||
          (client.ipAddress?.toLowerCase().contains(text) ?? false);
    }).toList(growable: false)
      ..sort((ClientDevice a, ClientDevice b) {
        final onlineComparison =
            clientOnlineRank(a).compareTo(clientOnlineRank(b));
        if (onlineComparison != 0) {
          return onlineComparison;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

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
                  'Selected Router Clients',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SearchActionBar(
                  query: query,
                  labelText: 'Search clients',
                  hintText: 'Name, IP, or MAC',
                  onChanged: onQueryChanged,
                  onRefresh: onRefresh,
                ),
                const SizedBox(height: 16),
                if (filteredClients.isEmpty)
                  Text(
                    query.trim().isEmpty
                        ? 'No clients were returned by the router.'
                        : 'No clients matched "$query".',
                    style: theme.textTheme.bodyLarge,
                  )
                else if (isApple)
                  _AppleClientList(
                    clients: filteredClients,
                    policies: status!.policies,
                    busyClientMacs: busyClientMacs,
                    onClientAction: (ClientActionRequest request) =>
                        onClientAction(status!, request),
                  )
                else
                  ...filteredClients.map(
                    (ClientDevice client) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClientRowCard(
                        client: client,
                        policies: status!.policies,
                        isBusy: busyClientMacs.contains(client.macAddress),
                        onActionSelected: (ClientActionRequest request) =>
                            onClientAction(status!, request),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SearchActionBar extends StatefulWidget {
  const SearchActionBar({
    super.key,
    required this.query,
    required this.labelText,
    required this.hintText,
    required this.onChanged,
    required this.onRefresh,
  });

  final String query;
  final String labelText;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onRefresh;

  @override
  State<SearchActionBar> createState() => _SearchActionBarState();
}

class _SearchActionBarState extends State<SearchActionBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(SearchActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMacOS = isMacOSDesignTarget;
    final clearAction = _controller.text.isEmpty
        ? null
        : () {
            _controller.clear();
            widget.onChanged('');
          };

    final searchField = TextField(
      controller: _controller,
      onChanged: (String value) {
        widget.onChanged(value);
      },
      decoration: InputDecoration(
        labelText: isMacOS ? null : widget.labelText,
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search),
      ),
    );

    if (isMacOS) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              Expanded(child: searchField),
              const SizedBox(width: 10),
              AppleNativeButton(
                onPressed: widget.onRefresh,
                label: 'Update',
                style: AppleNativeActionStyle.glass,
              ),
              const SizedBox(width: 6),
              AppleNativeButton(
                onPressed: clearAction,
                label: 'Clear',
                style: AppleNativeActionStyle.plain,
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: widget.onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Update'),
        ),
        const SizedBox(width: 12),
        Expanded(child: searchField),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: clearAction,
          child: const Text('Clear'),
        ),
      ],
    );
  }
}

class _AppleClientList extends StatelessWidget {
  const _AppleClientList({
    required this.clients,
    required this.policies,
    required this.busyClientMacs,
    required this.onClientAction,
  });

  final List<ClientDevice> clients;
  final List<VpnPolicy> policies;
  final Set<String> busyClientMacs;
  final Future<void> Function(ClientActionRequest request) onClientAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onlineCount = clients
        .where(
          (ClientDevice client) =>
              client.connectionState == ClientConnectionState.online,
        )
        .length;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${clients.length} clients shown',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '$onlineCount online, ${clients.length - onlineCount} offline or idle',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                DefaultTextStyle(
                  style: theme.textTheme.labelMedium!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  child: const Row(
                    children: <Widget>[
                      Expanded(flex: 3, child: Text('Device')),
                      Expanded(flex: 3, child: Text('Network')),
                      Expanded(flex: 2, child: Text('Access')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (var index = 0; index < clients.length; index++) ...<Widget>[
            _AppleClientRow(
              client: clients[index],
              policies: policies,
              isBusy: busyClientMacs.contains(clients[index].macAddress),
              onActionSelected: onClientAction,
            ),
            if (index != clients.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class ClientRowCard extends StatelessWidget {
  const ClientRowCard({
    super.key,
    required this.client,
    required this.policies,
    required this.isBusy,
    required this.onActionSelected,
  });

  final ClientDevice client;
  final List<VpnPolicy> policies;
  final bool isBusy;
  final Future<void> Function(ClientActionRequest request) onActionSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMacOS = isMacOSDesignTarget;
    final isApple = isAppleNativeTarget;
    final isOnline = client.connectionState == ClientConnectionState.online;
    final stateColor = isOnline ? colorScheme.primary : colorScheme.outline;
    final policyLabel = _policyLabelFor(
      client: client,
      policies: policies,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(isMacOS ? 14 : 12),
        color: isMacOS ? colorScheme.surface : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(isMacOS ? 14 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    client.name,
                    style: theme.textTheme.titleMedium,
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
                if (isApple)
                  AppleNativePopupMenuButton<ClientActionRequest>.icon(
                    tooltip: 'Client actions',
                    appleSymbol: 'ellipsis.circle',
                    fallbackIcon: Icons.more_horiz,
                    items: <AppleNativeMenuItem<ClientActionRequest>>[
                      AppleNativeMenuItem<ClientActionRequest>(
                        label: 'Wake on LAN',
                        value: ClientActionRequest.wakeOnLan(
                          macAddress: client.macAddress,
                        ),
                        appleSymbol: 'power',
                        fallbackIcon: Icons.power_settings_new_outlined,
                      ),
                      AppleNativeMenuItem<ClientActionRequest>(
                        label: 'Apply Default Policy',
                        value: ClientActionRequest.setDefaultPolicy(
                          macAddress: client.macAddress,
                        ),
                        appleSymbol: 'arrow.uturn.backward.circle',
                        fallbackIcon: Icons.restart_alt,
                      ),
                      AppleNativeMenuItem<ClientActionRequest>(
                        label: 'Block Client',
                        value: ClientActionRequest.block(
                          macAddress: client.macAddress,
                        ),
                        appleSymbol: 'hand.raised',
                        fallbackIcon: Icons.block,
                      ),
                      ...policies.map(
                        (VpnPolicy policy) => AppleNativeMenuItem<ClientActionRequest>(
                          label: 'Apply ${policy.description}',
                          value: ClientActionRequest.setNamedPolicy(
                            macAddress: client.macAddress,
                            policyName: policy.name,
                          ),
                          appleSymbol: 'shield.lefthalf.filled',
                          fallbackIcon: Icons.shield_outlined,
                        ),
                      ),
                    ],
                    onSelected: (ClientActionRequest request) {
                      onActionSelected(request);
                    },
                  )
                else
                  PopupMenuButton<ClientActionRequest>(
                    enabled: !isBusy,
                    tooltip: 'Client actions',
                    onSelected: (ClientActionRequest request) {
                      onActionSelected(request);
                    },
                    itemBuilder: (BuildContext context) {
                      final items = <PopupMenuEntry<ClientActionRequest>>[
                        PopupMenuItem<ClientActionRequest>(
                          value: ClientActionRequest.wakeOnLan(
                            macAddress: client.macAddress,
                          ),
                          child: const Text('Wake on LAN'),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem<ClientActionRequest>(
                          value: ClientActionRequest.setDefaultPolicy(
                            macAddress: client.macAddress,
                          ),
                          child: const Text('Apply Default Policy'),
                        ),
                        PopupMenuItem<ClientActionRequest>(
                          value: ClientActionRequest.block(
                            macAddress: client.macAddress,
                          ),
                          child: const Text('Block Client'),
                        ),
                      ];

                      if (policies.isNotEmpty) {
                        items.add(const PopupMenuDivider());
                        for (final policy in policies) {
                          items.add(
                            PopupMenuItem<ClientActionRequest>(
                              value: ClientActionRequest.setNamedPolicy(
                                macAddress: client.macAddress,
                                policyName: policy.name,
                              ),
                              child: Text('Apply ${policy.description}'),
                            ),
                          );
                        }
                      }
                      return items;
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.more_horiz),
                    ),
                  ),
                if (isMacOS)
                  _StatusBadge(
                    icon: isOnline
                        ? Icons.wifi_tethering
                        : Icons.wifi_tethering_error,
                    label: isOnline ? 'Online' : 'Offline',
                    color: stateColor,
                  )
                else
                  Chip(
                    avatar: Icon(
                      isOnline
                          ? Icons.wifi_tethering
                          : Icons.wifi_tethering_error,
                      size: 18,
                    ),
                    label: Text(isOnline ? 'Online' : 'Offline'),
                    backgroundColor: stateColor.withValues(alpha: 0.12),
                    side: BorderSide(color: stateColor.withValues(alpha: 0.3)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(
                  label: Text(client.ipAddress ?? 'No IP'),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(client.macAddress),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(policyLabel),
                  visualDensity: VisualDensity.compact,
                ),
                if (client.priority != null)
                  Chip(
                    label: Text('Priority ${client.priority}'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (hasTelemetryDetails(client)) ...<Widget>[
              const SizedBox(height: 8),
              TelemetryDetailsTable(client: client),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppleClientRow extends StatelessWidget {
  const _AppleClientRow({
    required this.client,
    required this.policies,
    required this.isBusy,
    required this.onActionSelected,
  });

  final ClientDevice client;
  final List<VpnPolicy> policies;
  final bool isBusy;
  final Future<void> Function(ClientActionRequest request) onActionSelected;

  @override
  Widget build(BuildContext context) {
    final isOnline = client.connectionState == ClientConnectionState.online;
    final policyLabel = _policyLabelFor(client: client, policies: policies);
    final metaFacts = <_TelemetryFact>[
      _TelemetryFact('IP address', client.ipAddress ?? 'No IP assigned'),
      _TelemetryFact('MAC address', client.macAddress),
      _TelemetryFact('Policy', policyLabel),
      if (client.priority != null)
        _TelemetryFact('Priority', '${client.priority}'),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final useColumns = constraints.maxWidth >= 720;
                    if (!useColumns) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _AppleClientDeviceColumn(
                            client: client,
                            isOnline: isOnline,
                          ),
                          const SizedBox(height: 14),
                          _AppleClientFactsColumn(facts: metaFacts),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: _AppleClientDeviceColumn(
                            client: client,
                            isOnline: isOnline,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 3,
                          child: _AppleClientFactsColumn(facts: metaFacts),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 2,
                          child: _AppleClientAccessColumn(
                            policyLabel: policyLabel,
                            client: client,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (isBusy)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  AppleNativePopupMenuButton<ClientActionRequest>.icon(
                    tooltip: 'Client actions',
                    appleSymbol: 'ellipsis.circle',
                    fallbackIcon: Icons.more_horiz,
                    items: <AppleNativeMenuItem<ClientActionRequest>>[
                      AppleNativeMenuItem<ClientActionRequest>(
                        label: 'Wake on LAN',
                        value: ClientActionRequest.wakeOnLan(
                          macAddress: client.macAddress,
                        ),
                        appleSymbol: 'power',
                        fallbackIcon: Icons.power_settings_new_outlined,
                      ),
                      AppleNativeMenuItem<ClientActionRequest>(
                        label: 'Apply Default Policy',
                        value: ClientActionRequest.setDefaultPolicy(
                          macAddress: client.macAddress,
                        ),
                        appleSymbol: 'arrow.uturn.backward.circle',
                        fallbackIcon: Icons.restart_alt,
                      ),
                      AppleNativeMenuItem<ClientActionRequest>(
                        label: 'Block Client',
                        value: ClientActionRequest.block(
                          macAddress: client.macAddress,
                        ),
                        appleSymbol: 'hand.raised',
                        fallbackIcon: Icons.block,
                      ),
                      ...policies.map(
                        (VpnPolicy policy) =>
                            AppleNativeMenuItem<ClientActionRequest>(
                          label: 'Apply ${policy.description}',
                          value: ClientActionRequest.setNamedPolicy(
                            macAddress: client.macAddress,
                            policyName: policy.name,
                          ),
                          appleSymbol: 'shield.lefthalf.filled',
                          fallbackIcon: Icons.shield_outlined,
                        ),
                      ),
                    ],
                    onSelected: (ClientActionRequest request) {
                      onActionSelected(request);
                    },
                  ),
                ],
              ),
            ],
          ),
          if (hasTelemetryDetails(client)) ...<Widget>[
            const SizedBox(height: 14),
            TelemetryDetailsTable(
              client: client,
              embedded: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _AppleClientDeviceColumn extends StatelessWidget {
  const _AppleClientDeviceColumn({
    required this.client,
    required this.isOnline,
  });

  final ClientDevice client;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stateColor =
        isOnline ? theme.colorScheme.primary : theme.colorScheme.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          client.name,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        _StatusBadge(
          icon: isOnline
              ? Icons.wifi_tethering
              : Icons.wifi_tethering_error,
          label: isOnline ? 'Online' : 'Offline',
          color: stateColor,
        ),
        if (client.isWireless) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            client.wifiBand == null
                ? 'Connected over Wi-Fi'
                : 'Connected over Wi-Fi ${client.wifiBand}',
            style: theme.textTheme.bodySmall,
          ),
        ] else ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Connected over Ethernet',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _AppleClientFactsColumn extends StatelessWidget {
  const _AppleClientFactsColumn({
    required this.facts,
  });

  final List<_TelemetryFact> facts;

  @override
  Widget build(BuildContext context) {
    return _LabeledFactTable(facts: facts);
  }
}

class _AppleClientAccessColumn extends StatelessWidget {
  const _AppleClientAccessColumn({
    required this.policyLabel,
    required this.client,
  });

  final String policyLabel;
  final ClientDevice client;

  @override
  Widget build(BuildContext context) {
    final facts = <_TelemetryFact>[
      _TelemetryFact('Access', policyLabel),
      _TelemetryFact(
        'Connection',
        client.isWireless
            ? (client.wifiBand == null ? 'Wi-Fi' : 'Wi-Fi ${client.wifiBand}')
            : 'Ethernet',
      ),
    ];

    return _LabeledFactTable(facts: facts);
  }
}

String _policyLabelFor({
  required ClientDevice client,
  required List<VpnPolicy> policies,
}) {
  if (client.isDenied) {
    return 'Blocked';
  }

  final policyName = client.policyName;
  if (policyName == null || policyName.isEmpty) {
    return 'Default';
  }

  for (final policy in policies) {
    if (policy.name == policyName) {
      return policy.description;
    }
  }

  return policyName;
}

bool hasTelemetryDetails(ClientDevice client) {
  return _buildTelemetryFacts(client).isNotEmpty;
}

class TelemetryDetailsTable extends StatelessWidget {
  const TelemetryDetailsTable({
    super.key,
    required this.client,
    this.embedded = false,
  });

  final ClientDevice client;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final facts = _buildTelemetryFacts(client);

    if (facts.isEmpty) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: embedded ? 0.12 : 0.2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Telemetry',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            _LabeledFactTable(
              facts: facts,
              twoColumnBreakpoint: 560,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledFactTable extends StatelessWidget {
  const _LabeledFactTable({
    required this.facts,
    this.twoColumnBreakpoint = 640,
  });

  final List<_TelemetryFact> facts;
  final double twoColumnBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const spacing = 12.0;
        final useTwoColumns =
            constraints.maxWidth >= twoColumnBreakpoint && facts.length > 1;
        final itemWidth = useTwoColumns
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: 6,
          children: facts
              .map(
                (_TelemetryFact fact) => SizedBox(
                  width: itemWidth,
                  child: _TelemetryFactRow(fact: fact),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _TelemetryFactRow extends StatelessWidget {
  const _TelemetryFactRow({
    required this.fact,
  });

  final _TelemetryFact fact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 124,
          child: Text(
            fact.label,
            style: theme.textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Text(
            fact.value,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

String? _buildWirelessDetail(ClientDevice client) {
  final parts = <String>[];

  if (client.wirelessMode != null && client.wirelessMode!.isNotEmpty) {
    parts.add(client.wirelessMode!);
  }
  if (client.wifiStandard != null && client.wifiStandard!.isNotEmpty) {
    parts.add(client.wifiStandard!);
  }
  if (client.spatialStreams != null) {
    parts.add('${client.spatialStreams}x${client.spatialStreams}');
  }
  if (client.channelWidthMhz != null) {
    parts.add('${client.channelWidthMhz} MHz');
  }

  if (parts.isEmpty) {
    return null;
  }

  return parts.join(' ');
}

List<_TelemetryFact> _buildTelemetryFacts(ClientDevice client) {
  final facts = <_TelemetryFact>[
    _TelemetryFact(
      'Connection',
      client.isWireless
          ? client.wifiBand == null
              ? 'Wi-Fi'
              : 'Wi-Fi ${client.wifiBand}'
          : 'Ethernet',
    ),
  ];

  if (client.signalRssi != null) {
    facts.add(_TelemetryFact('Signal', '${client.signalRssi} dBm'));
  }

  if (client.txRateMbps != null) {
    facts.add(_TelemetryFact('Link speed', '${client.txRateMbps} Mbps'));
  } else if (client.ethernetSpeedMbps != null) {
    facts.add(_TelemetryFact('Link speed', '${client.ethernetSpeedMbps} Mbps'));
  }

  if (client.encryption != null && client.encryption!.isNotEmpty) {
    facts.add(_TelemetryFact('Security', client.encryption!));
  }

  final wirelessDetail = _buildWirelessDetail(client);
  if (wirelessDetail != null) {
    facts.add(_TelemetryFact('Wireless profile', wirelessDetail));
  }

  if (client.ethernetPort != null) {
    facts.add(_TelemetryFact('Switch port', '${client.ethernetPort}'));
  }

  return facts;
}

class _TelemetryFact {
  const _TelemetryFact(this.label, this.value);

  final String label;
  final String value;
}

int clientOnlineRank(ClientDevice client) {
  switch (client.connectionState) {
    case ClientConnectionState.online:
      return 0;
    case ClientConnectionState.offline:
      return 1;
    case ClientConnectionState.unknown:
      return 2;
  }
}
