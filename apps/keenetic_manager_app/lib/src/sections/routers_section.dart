import 'package:flutter/material.dart';
import 'package:router_core/router_core.dart';

import '../apple_native_controls.dart';
import '../platform_style.dart';
import '../router_overview_model.dart';
import '../selected_router_status.dart';

class RoutersSection extends StatelessWidget {
  const RoutersSection({
    super.key,
    required this.model,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final RouterOverviewModel model;
  final ValueChanged<String> onSelect;
  final ValueChanged<RouterProfile> onEdit;
  final ValueChanged<RouterProfile> onDelete;

  @override
  Widget build(BuildContext context) {
    final isMacOS = isMacOSDesignTarget;
    return ListView(
      padding: EdgeInsets.all(isMacOS ? 20 : 16),
      children: <Widget>[
        StorageCard(storagePath: model.storagePath),
        const SizedBox(height: 16),
        SelectedRouterStatusCard(
          selectedRouterId: model.selectedRouterId,
          status: model.selectedRouterStatus,
        ),
        const SizedBox(height: 16),
        if (isMacOS)
          _MacRouterList(
            model: model,
            onSelect: onSelect,
            onEdit: onEdit,
            onDelete: onDelete,
          )
        else
          for (final router in model.routers)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RouterCard(
                router: router,
                selected: router.id == model.selectedRouterId,
                hasStoredPassword: model.passwordStored[router.id] ?? false,
                onSelect: () => onSelect(router.id),
                onEdit: () => onEdit(router),
                onDelete: () => onDelete(router),
              ),
            ),
      ],
    );
  }
}

class StorageCard extends StatelessWidget {
  const StorageCard({
    super.key,
    required this.storagePath,
  });

  final String storagePath;

  @override
  Widget build(BuildContext context) {
    final isApple = isAppleNativeTarget;
    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Storage',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SelectableText(storagePath),
        ],
      ),
    );

    if (!isApple) {
      return Card(child: body);
    }

    return DecoratedBox(
      decoration: _appleGlassPanelDecoration(context),
      child: body,
    );
  }
}

BoxDecoration _appleGlassPanelDecoration(BuildContext context) {
  final theme = Theme.of(context);
  return BoxDecoration(
    color: theme.colorScheme.surface.withValues(alpha: 0.72),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
    ),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

class _StatusSnapshotRow extends StatelessWidget {
  const _StatusSnapshotRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMetricPill extends StatelessWidget {
  const _StatusMetricPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class SelectedRouterStatusCard extends StatelessWidget {
  const SelectedRouterStatusCard({
    super.key,
    required this.selectedRouterId,
    required this.status,
  });

  final String? selectedRouterId;
  final SelectedRouterStatus? status;

  @override
  Widget build(BuildContext context) {
    final isApple = isAppleNativeTarget;
    if (selectedRouterId == null) {
      final empty = Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No router selected yet. Select one below to make it the active router.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
      if (!isApple) {
        return Card(child: empty);
      }
      return DecoratedBox(
        decoration: _appleGlassPanelDecoration(context),
        child: empty,
      );
    }

    if (status == null) {
      return const SizedBox.shrink();
    }
    final currentStatus = status!;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = currentStatus.isConnected
        ? colorScheme.primary
        : currentStatus.hasStoredPassword
            ? colorScheme.error
            : colorScheme.secondary;
    final statusText = currentStatus.isConnected
        ? 'Connected'
        : currentStatus.hasStoredPassword
            ? 'Connection failed'
            : 'Password missing';

    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Selected Router Status',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (isApple)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        AppleNativeSymbolIcon(
                          appleSymbol: currentStatus.isConnected
                              ? 'checkmark.circle'
                              : currentStatus.hasStoredPassword
                                  ? 'exclamationmark.triangle'
                                  : 'lock.circle',
                          fallbackIcon: currentStatus.isConnected
                              ? Icons.cloud_done_outlined
                              : Icons.error_outline,
                          color: statusColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Chip(
                  avatar: Icon(
                    currentStatus.isConnected
                        ? Icons.cloud_done_outlined
                        : Icons.error_outline,
                    size: 18,
                  ),
                  label: Text(statusText),
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currentStatus.router.name,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(currentStatus.router.address),
          const SizedBox(height: 12),
          if (isApple) ...<Widget>[
            _StatusSnapshotRow(
              label: 'Checked',
              value: formatTimestamp(currentStatus.checkedAt),
            ),
            if (currentStatus.connectionTarget != null) ...<Widget>[
              _StatusSnapshotRow(
                label: 'Resolved target',
                value: currentStatus.connectionTarget!.uri.toString(),
              ),
              _StatusSnapshotRow(
                label: 'Target type',
                value: currentStatus.connectionTarget!.kind.name,
              ),
            ],
          ] else if (currentStatus.connectionTarget != null) ...<Widget>[
            Text(
              'Resolved target: ${currentStatus.connectionTarget!.uri}',
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              'Target type: ${currentStatus.connectionTarget!.kind.name}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
          ],
          if (currentStatus.errorMessage != null) ...<Widget>[
            if (isApple)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.error.withValues(alpha: 0.14),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    currentStatus.errorMessage!,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              )
            else
              Text(
                currentStatus.errorMessage!,
                style: TextStyle(color: colorScheme.error),
              ),
            const SizedBox(height: 12),
          ],
          if (currentStatus.isConnected) ...<Widget>[
            if (isApple)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _StatusMetricPill(
                    label: 'Clients',
                    value: '${currentStatus.clientCount}',
                  ),
                  _StatusMetricPill(
                    label: 'Online',
                    value: '${currentStatus.onlineClientCount}',
                  ),
                  _StatusMetricPill(
                    label: 'Policies',
                    value: '${currentStatus.policyCount}',
                  ),
                  _StatusMetricPill(
                    label: 'WireGuard peers',
                    value: '${currentStatus.wireGuardPeerCount}',
                  ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(
                    label: Text('${currentStatus.clientCount} clients'),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text('${currentStatus.onlineClientCount} online'),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text('${currentStatus.policyCount} policies'),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(
                      '${currentStatus.wireGuardPeerCount} WireGuard peers',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            const SizedBox(height: 12),
          ],
          if (!isApple)
            Text(
              'Checked ${formatTimestamp(currentStatus.checkedAt)}',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );

    if (!isApple) {
      return Card(child: body);
    }

    return DecoratedBox(
      decoration: _appleGlassPanelDecoration(context),
      child: body,
    );
  }
}

String formatTimestamp(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int part) => part.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';
}

class RouterCard extends StatelessWidget {
  const RouterCard({
    super.key,
    required this.router,
    required this.selected,
    required this.hasStoredPassword,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final RouterProfile router;
  final bool selected;
  final bool hasStoredPassword;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    router.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (selected)
                  Chip(
                    avatar: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Selected'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(router.address),
            const SizedBox(height: 4),
            Text('Login: ${router.login}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (hasStoredPassword)
                  const Chip(
                    avatar: Icon(Icons.lock_outline, size: 18),
                    label: Text('Password stored'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (router.networkIp != null) ...<Widget>[
              const SizedBox(height: 4),
              Text('Local IP: ${router.networkIp}'),
            ],
            if (router.keendnsUrls.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: router.keendnsUrls
                    .map((String url) => Chip(label: Text(url)))
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: onSelect,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(selected ? 'Selected' : 'Select'),
                ),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacRouterList extends StatelessWidget {
  const _MacRouterList({
    required this.model,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final RouterOverviewModel model;
  final ValueChanged<String> onSelect;
  final ValueChanged<RouterProfile> onEdit;
  final ValueChanged<RouterProfile> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routers = model.routers;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Stored Routers',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${routers.length} total',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (var index = 0; index < routers.length; index++) ...<Widget>[
            _MacRouterRow(
              router: routers[index],
              selected: routers[index].id == model.selectedRouterId,
              hasStoredPassword: model.passwordStored[routers[index].id] ?? false,
              onSelect: () => onSelect(routers[index].id),
              onEdit: () => onEdit(routers[index]),
              onDelete: () => onDelete(routers[index]),
            ),
            if (index != routers.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _MacRouterRow extends StatelessWidget {
  const _MacRouterRow({
    required this.router,
    required this.selected,
    required this.hasStoredPassword,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final RouterProfile router;
  final bool selected;
  final bool hasStoredPassword;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ColoredBox(
      color: selected
          ? colorScheme.secondary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          router.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (selected)
                        Text(
                          'Active',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    router.address,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: <Widget>[
                      Text(
                        'Login: ${router.login}',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (hasStoredPassword)
                        Text(
                          'Password saved',
                          style: theme.textTheme.bodySmall,
                        ),
                      if (router.networkIp != null)
                        Text(
                          'Local IP: ${router.networkIp}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                  if (router.keendnsUrls.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      router.keendnsUrls.join('  •  '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            Wrap(
              spacing: 8,
              children: <Widget>[
                AppleNativeButton(
                  onPressed: onSelect,
                  label: selected ? 'Selected' : 'Select',
                  style: selected
                      ? AppleNativeActionStyle.bordered
                      : AppleNativeActionStyle.plain,
                ),
                AppleNativeButton(
                  onPressed: onEdit,
                  label: 'Edit',
                  style: AppleNativeActionStyle.plain,
                ),
                AppleNativeButton(
                  onPressed: onDelete,
                  label: 'Delete',
                  style: AppleNativeActionStyle.plain,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
