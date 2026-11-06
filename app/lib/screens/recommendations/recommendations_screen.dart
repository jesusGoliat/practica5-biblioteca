import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/recommendations_provider.dart';
import '../../widgets/common.dart';
import '../search/book_detail_screen.dart';

class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<RecommendationsProvider>();
    final data = p.data;
    return Column(
      children: [
        if (p.isLoading) const LinearProgressIndicator(),
        if (p.error != null)
          ErrorBanner(
            p.error!,
            onRetry: () => context.read<RecommendationsProvider>().load(),
          ),
        if (data != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Criterio',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(data.criterion),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${data.fromCache ? 'Guardadas' : 'Generadas'}: '
                            '${formatDateTime(data.generatedAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('refresh-recommendations'),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Actualizar'),
                          onPressed: p.isLoading
                              ? null
                              : () =>
                                  context.read<RecommendationsProvider>().load(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: data == null || data.items.isEmpty
              ? EmptyState(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Aún no hay recomendaciones',
                  message: 'Genera sugerencias a partir de tus favoritos, '
                      'biblioteca y búsquedas.',
                  action: FilledButton.icon(
                    key: const Key('generate-recommendations'),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Generar recomendaciones'),
                    onPressed: p.isLoading
                        ? null
                        : () => context.read<RecommendationsProvider>().load(),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      context.read<RecommendationsProvider>().load(),
                  child: ListView.separated(
                    itemCount: data.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final r = data.items[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        leading: BookCover(url: r.book.coverUrl(size: 'S')),
                        title: Text(r.book.title, maxLines: 2),
                        subtitle: Text(
                          '${r.book.author ?? 'Autor desconocido'}\n${r.reason}',
                        ),
                        isThreeLine: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BookDetailScreen(book: r.book),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
