import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/book.dart';
import '../../core/models/library_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/common.dart';
import '../search/book_detail_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  static const _tabs = [
    ('want_to_read', 'Por leer'),
    ('reading', 'Leyendo'),
    ('read', 'Leído'),
  ];

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    return DefaultTabController(
      length: _tabs.length,
      child: Column(
        children: [
          TabBar(tabs: [for (final t in _tabs) Tab(text: t.$2)]),
          Expanded(
            child: TabBarView(
              children: [
                for (final t in _tabs)
                  _LibraryList(items: library.byStatus(t.$1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryList extends StatelessWidget {
  const _LibraryList({required this.items});

  final List<LibraryItem> items;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await context.read<SyncProvider>().syncNow();
        if (context.mounted) await context.read<LibraryProvider>().load();
      },
      child: items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 80),
                EmptyState(
                  icon: Icons.collections_bookmark_outlined,
                  title: 'Aquí no hay libros todavía',
                  message: 'Agrega libros desde el detalle de una búsqueda.',
                ),
              ],
            )
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final item = items[i];
                return Dismissible(
                  key: ValueKey(item.publicId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_outline),
                  ),
                  confirmDismiss: (_) async =>
                      await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('¿Quitar de tu biblioteca?'),
                          content: Text(item.title),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Quitar'),
                            ),
                          ],
                        ),
                      ) ??
                      false,
                  onDismissed: (_) =>
                      context.read<LibraryProvider>().remove(item),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    leading: BookCover(url: item.coverUrl(size: 'S')),
                    title: Text(item.title, maxLines: 2),
                    subtitle: Text(
                      [
                        if (item.author != null) item.author!,
                        if (item.rating != null) '★ ${item.rating}',
                      ].join(' · '),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BookDetailScreen(
                          book: Book(
                            olKey: item.olKey,
                            title: item.title,
                            authors: item.author == null
                                ? const []
                                : [item.author!],
                            coverId: item.coverId,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
