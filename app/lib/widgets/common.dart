import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/sync_provider.dart';

String formatDateTime(DateTime date) =>
    DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());

class BookCover extends StatelessWidget {
  const BookCover({super.key, this.url, this.width = 56, this.height = 84});

  final String? url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.menu_book_outlined),
    );
    return Semantics(
      label: 'Portada del libro',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: url == null
            ? placeholder
            : Image.network(
                url!,
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : placeholder,
              ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(message!, textAlign: TextAlign.center),
              ],
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      );
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

/// Estado de red y de sincronización visible en toda la app.
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    final status = sync.status;
    final scheme = Theme.of(context).colorScheme;
    final parts = <String>[
      if (!sync.online) 'Sin conexión',
      if (status.pending > 0)
        '${status.pending} cambio${status.pending == 1 ? '' : 's'} pendiente${status.pending == 1 ? '' : 's'}',
      status.lastSyncAt == null
          ? 'Aún sin sincronizar'
          : 'Última actualización: ${formatDateTime(status.lastSyncAt!)}',
      if (status.lastError != null && sync.online)
        'Error: ${status.lastError}',
    ];
    return Material(
      color: !sync.online || status.lastError != null
          ? scheme.tertiaryContainer
          : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Icon(
              sync.online ? Icons.cloud_done_outlined : Icons.cloud_off,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                parts.join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            sync.status.syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    tooltip: 'Sincronizar ahora',
                    icon: const Icon(Icons.sync),
                    onPressed: sync.online ? sync.syncNow : null,
                  ),
          ],
        ),
      ),
    );
  }
}
