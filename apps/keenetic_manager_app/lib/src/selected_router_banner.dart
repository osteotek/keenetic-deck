import 'package:flutter/material.dart';

import 'apple_native_controls.dart';
import 'app_section.dart';
import 'platform_style.dart';
import 'selected_router_status.dart';

class SelectedRouterBanner extends StatelessWidget {
  const SelectedRouterBanner({
    super.key,
    required this.selectedRouterId,
    required this.status,
    required this.onRefresh,
    required this.onOpenRouters,
  });

  final String? selectedRouterId;
  final SelectedRouterStatus? status;
  final VoidCallback onRefresh;
  final VoidCallback onOpenRouters;

  @override
  Widget build(BuildContext context) {
    final configuration = _configurationForStatus(
      selectedRouterId: selectedRouterId,
      status: status,
    );
    if (configuration == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isApple = isAppleNativeTarget;
    final tone = switch (configuration.level) {
      _BannerLevel.info => colorScheme.secondary,
      _BannerLevel.warning => colorScheme.tertiary,
      _BannerLevel.error => colorScheme.error,
    };

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tone.withValues(alpha: isApple ? 0.14 : 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AppleNativeSymbolIcon(
                appleSymbol: configuration.appleSymbol,
                fallbackIcon: configuration.icon,
                color: tone,
                size: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                configuration.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(configuration.message),
              if (configuration.checkedAt != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'Last checked ${_formatTimestamp(configuration.checkedAt!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (configuration.showRefresh)
                    AppleNativeButton(
                      onPressed: onRefresh,
                      label: 'Retry',
                      style: AppleNativeActionStyle.bordered,
                    ),
                  AppleNativeButton(
                    onPressed: onOpenRouters,
                    label: AppSection.routers.label,
                    style: AppleNativeActionStyle.bordered,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    if (!isApple) {
      return Material(
        color: tone.withValues(alpha: 0.1),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: tone.withValues(alpha: 0.25)),
            ),
          ),
          child: content,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: tone.withValues(alpha: 0.22),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: content,
        ),
      ),
    );
  }
}

_BannerConfiguration? _configurationForStatus({
  required String? selectedRouterId,
  required SelectedRouterStatus? status,
}) {
  if (selectedRouterId == null) {
    return const _BannerConfiguration(
      title: 'No active router selected',
      message:
          'Choose a router in the Routers section before using live management screens.',
      level: _BannerLevel.info,
      icon: Icons.info_outline,
      appleSymbol: 'info.circle',
      showRefresh: false,
    );
  }

  if (status == null || status.isConnected) {
    return null;
  }

  if (!status.hasStoredPassword) {
    return _BannerConfiguration(
      title: 'Saved password required',
      message:
          'The selected router does not have a saved password. Update its credentials in the Routers section.',
      level: _BannerLevel.warning,
      icon: Icons.lock_outline,
      appleSymbol: 'lock.circle',
      checkedAt: status.checkedAt,
      showRefresh: false,
    );
  }

  return _BannerConfiguration(
    title: 'Router connection failed',
    message: status.errorMessage ??
        'The selected router could not be reached or authenticated.',
    level: _BannerLevel.error,
    icon: Icons.error_outline,
    appleSymbol: 'exclamationmark.triangle',
    checkedAt: status.checkedAt,
    showRefresh: true,
  );
}

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int part) => part.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';
}

class _BannerConfiguration {
  const _BannerConfiguration({
    required this.title,
    required this.message,
    required this.level,
    required this.icon,
    required this.appleSymbol,
    required this.showRefresh,
    this.checkedAt,
  });

  final String title;
  final String message;
  final _BannerLevel level;
  final IconData icon;
  final String appleSymbol;
  final DateTime? checkedAt;
  final bool showRefresh;
}

enum _BannerLevel {
  info,
  warning,
  error,
}
