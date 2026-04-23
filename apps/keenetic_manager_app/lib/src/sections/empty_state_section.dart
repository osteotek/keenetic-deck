import 'package:flutter/material.dart';

import 'routers_section.dart';

class EmptyStateSection extends StatelessWidget {
  const EmptyStateSection({
    super.key,
    required this.storagePath,
    required this.onRefresh,
  });

  final String storagePath;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.router_outlined,
                size: 52,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'No routers stored yet',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'The Flutter shell is now wired to the shared persistence layer. '
                'Once add/edit flows are implemented, saved routers will appear here.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              StorageCard(storagePath: storagePath),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Reload storage'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
