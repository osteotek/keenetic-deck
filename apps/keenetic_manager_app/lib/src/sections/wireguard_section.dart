import 'package:flutter/material.dart';
import 'package:router_core/router_core.dart';

import '../platform_style.dart';
import '../selected_router_status.dart';

class WireGuardSection extends StatelessWidget {
  const WireGuardSection({
    super.key,
    required this.status,
  });

  final SelectedRouterStatus? status;

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
                'Select and connect a router to view WireGuard peers.',
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
                'WireGuard peers will appear here after the selected router connects successfully.',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      );
    }

    final groupedPeers = _groupPeers(status!.wireGuardPeers);
    final isApple = isAppleNativeTarget;

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
                  'WireGuard',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${status!.wireGuardPeers.length} peers across ${groupedPeers.length} interfaces',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (groupedPeers.isEmpty)
                  Text(
                    'No WireGuard peers were returned by the router.',
                    style: theme.textTheme.bodyLarge,
                  )
                else if (isApple)
                  _AppleWireGuardList(groupedPeers: groupedPeers)
                else
                  ...groupedPeers.entries.map(
                    (MapEntry<String, List<WireGuardPeer>> entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _WireGuardInterfaceCard(
                        interfaceName: entry.key,
                        peers: entry.value,
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

class _AppleWireGuardList extends StatelessWidget {
  const _AppleWireGuardList({
    required this.groupedPeers,
  });

  final Map<String, List<WireGuardPeer>> groupedPeers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: <Widget>[
                Expanded(flex: 3, child: Text('Peer')),
                Expanded(flex: 2, child: Text('Interface')),
                Expanded(flex: 4, child: Text('Allowed IPs')),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final entry in groupedPeers.entries) ...<Widget>[
            _AppleWireGuardInterfaceSection(
              interfaceName: entry.key,
              peers: entry.value,
            ),
          ],
        ],
      ),
    );
  }
}

class _AppleWireGuardInterfaceSection extends StatelessWidget {
  const _AppleWireGuardInterfaceSection({
    required this.interfaceName,
    required this.peers,
  });

  final String interfaceName;
  final List<WireGuardPeer> peers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabledCount =
        peers.where((WireGuardPeer peer) => peer.isEnabled).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  interfaceName,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                '$enabledCount of ${peers.length} enabled',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        for (var index = 0; index < peers.length; index++) ...<Widget>[
          if (index == 0) const Divider(height: 1),
          _AppleWireGuardPeerRow(
            interfaceName: interfaceName,
            peer: peers[index],
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

class _AppleWireGuardPeerRow extends StatelessWidget {
  const _AppleWireGuardPeerRow({
    required this.interfaceName,
    required this.peer,
  });

  final String interfaceName;
  final WireGuardPeer peer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stateColor =
        peer.isEnabled ? theme.colorScheme.primary : theme.colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final useColumns = constraints.maxWidth >= 760;
          final peerColumn = _AppleWireGuardPeerColumn(
            peer: peer,
            stateColor: stateColor,
          );
          final interfaceColumn = _AppleWireGuardInfoBlock(
            title: 'Interface',
            value: interfaceName,
            secondary: peer.endpoint == null || peer.endpoint!.isEmpty
                ? 'No endpoint reported'
                : 'Endpoint: ${peer.endpoint}',
          );
          final allowedIpsColumn = _AppleWireGuardInfoBlock(
            title: 'Allowed IPs',
            value: peer.allowedIps.isEmpty
                ? 'No allowed IPs'
                : peer.allowedIps.join(', '),
            secondary: '${peer.allowedIps.length} route'
                '${peer.allowedIps.length == 1 ? '' : 's'}',
          );

          if (!useColumns) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                peerColumn,
                const SizedBox(height: 14),
                interfaceColumn,
                const SizedBox(height: 12),
                allowedIpsColumn,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 3, child: peerColumn),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: interfaceColumn),
              const SizedBox(width: 20),
              Expanded(flex: 4, child: allowedIpsColumn),
            ],
          );
        },
      ),
    );
  }
}

class _AppleWireGuardPeerColumn extends StatelessWidget {
  const _AppleWireGuardPeerColumn({
    required this.peer,
    required this.stateColor,
  });

  final WireGuardPeer peer;
  final Color stateColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          peer.peerName,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            color: stateColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: stateColor.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              peer.isEnabled ? 'Enabled' : 'Disabled',
              style: theme.textTheme.bodySmall?.copyWith(
                color: stateColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AppleWireGuardInfoBlock extends StatelessWidget {
  const _AppleWireGuardInfoBlock({
    required this.title,
    required this.value,
    required this.secondary,
  });

  final String title;
  final String value;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          secondary,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _WireGuardInterfaceCard extends StatelessWidget {
  const _WireGuardInterfaceCard({
    required this.interfaceName,
    required this.peers,
  });

  final String interfaceName;
  final List<WireGuardPeer> peers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabledCount =
        peers.where((WireGuardPeer peer) => peer.isEnabled).length;

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
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    interfaceName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text('$enabledCount/${peers.length} enabled'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...peers.map(
              (WireGuardPeer peer) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _WireGuardPeerCard(peer: peer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WireGuardPeerCard extends StatelessWidget {
  const _WireGuardPeerCard({
    required this.peer,
  });

  final WireGuardPeer peer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stateColor =
        peer.isEnabled ? colorScheme.primary : colorScheme.outline;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    peer.peerName,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Chip(
                  avatar: Icon(
                    peer.isEnabled
                        ? Icons.check_circle_outline
                        : Icons.pause_circle_outline,
                    size: 18,
                  ),
                  label: Text(peer.isEnabled ? 'Enabled' : 'Disabled'),
                  backgroundColor: stateColor.withValues(alpha: 0.12),
                  side: BorderSide(color: stateColor.withValues(alpha: 0.3)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (peer.endpoint != null && peer.endpoint!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Endpoint: ${peer.endpoint}'),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: peer.allowedIps.isEmpty
                  ? <Widget>[
                      const Chip(
                        label: Text('No allowed IPs'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ]
                  : peer.allowedIps
                      .map(
                        (String ip) => Chip(
                          label: Text(ip),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, List<WireGuardPeer>> _groupPeers(List<WireGuardPeer> peers) {
  final grouped = <String, List<WireGuardPeer>>{};
  for (final peer in peers) {
    grouped.putIfAbsent(peer.interfaceName, () => <WireGuardPeer>[]).add(peer);
  }

  final sortedEntries = grouped.entries.toList(growable: false)
    ..sort(
      (MapEntry<String, List<WireGuardPeer>> a,
              MapEntry<String, List<WireGuardPeer>> b) =>
          a.key.toLowerCase().compareTo(b.key.toLowerCase()),
    );

  return <String, List<WireGuardPeer>>{
    for (final entry in sortedEntries)
      entry.key: (entry.value.toList(growable: false)
        ..sort(
          (WireGuardPeer a, WireGuardPeer b) =>
              a.peerName.toLowerCase().compareTo(b.peerName.toLowerCase()),
        )),
  };
}
