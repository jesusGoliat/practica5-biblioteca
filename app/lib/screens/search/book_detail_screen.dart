import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/book.dart';
import '../../core/models/library_item.dart';
import '../../data/repository.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/library_provider.dart';
import '../../widgets/common.dart';

class BookDetailScreen extends StatefulWidget {
  const BookDetailScreen({super.key, required this.book});

  final Book book;

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late Book _book = widget.book;
  bool _loadingDetail = false;
  bool _detailFailed = false;

  @override
  void initState() {
    super.initState();
    if (_book.description == null) _loadDetail();
  }

  Future<void> _loadDetail() async {
    final repo = context.read<Repository>();
    setState(() => _loadingDetail = true);
    try {
      final detail = await repo.openLibrary.work(_book.olKey);
      if (!mounted) return;
      setState(() {
        _book = Book(
          olKey: _book.olKey,
          title: _book.title,
          authors: _book.authors,
          firstPublishYear: _book.firstPublishYear,
          coverId: _book.coverId ?? detail.coverId,
          subjects: _book.subjects.isEmpty ? detail.subjects : _book.subjects,
          editionCount: _book.editionCount,
          description: detail.description,
        );
      });
    } catch (_) {
      if (mounted) setState(() => _detailFailed = true);
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  static const _statuses = {
    'want_to_read': 'Por leer',
    'reading': 'Leyendo',
    'read': 'Leído',
  };

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final favorites = context.watch<FavoritesProvider>();
    final item = library.find(_book.olKey);
    final isFav = favorites.isFavorite(_book.olKey);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle'),
        actions: [
          IconButton(
            key: const Key('favorite-toggle'),
            tooltip: isFav ? 'Quitar de favoritos' : 'Marcar como favorito',
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border),
            onPressed: () => context.read<FavoritesProvider>().toggle(_book),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(url: _book.coverUrl(size: 'M'), width: 110, height: 165),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _book.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (_book.author != null) Text(_book.author!),
                    if (_book.firstPublishYear != null)
                      Text('Primera publicación: ${_book.firstPublishYear}'),
                    if (_book.editionCount != null)
                      Text('${_book.editionCount} ediciones'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Mi biblioteca', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            key: const Key('status-selector'),
            emptySelectionAllowed: true,
            segments: [
              for (final e in _statuses.entries)
                ButtonSegment(value: e.key, label: Text(e.value)),
            ],
            selected: item == null ? <String>{} : {item.status},
            onSelectionChanged: (set) {
              if (set.isEmpty) return;
              final status = set.first;
              final lib = context.read<LibraryProvider>();
              if (item == null) {
                lib.add(_book, status);
              } else {
                lib.update(item, status: status);
              }
            },
          ),
          if (item != null) ...[
            const SizedBox(height: 12),
            _Rating(item: item),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Quitar de mi biblioteca'),
                onPressed: () => context.read<LibraryProvider>().remove(item),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('Descripción', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          if (_loadingDetail)
            const LinearProgressIndicator()
          else
            Text(
              _book.description ??
                  (_detailFailed
                      ? 'Descripción no disponible sin conexión.'
                      : 'Sin descripción.'),
            ),
          if (_book.subjects.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in _book.subjects.take(8)) Chip(label: Text(s)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Rating extends StatelessWidget {
  const _Rating({required this.item});

  final LibraryItem item;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Text('Mi calificación: '),
          for (var i = 1; i <= 5; i++)
            IconButton(
              tooltip: '$i estrella${i == 1 ? '' : 's'}',
              icon: Icon(
                (item.rating ?? 0) >= i ? Icons.star : Icons.star_border,
              ),
              onPressed: () =>
                  context.read<LibraryProvider>().update(item, rating: i),
            ),
        ],
      );
}
