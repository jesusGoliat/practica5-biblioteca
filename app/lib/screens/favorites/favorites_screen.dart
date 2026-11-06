import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/book.dart';
import '../../providers/favorites_provider.dart';
import '../../widgets/common.dart';
import '../search/book_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<FavoritesProvider>().items;
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.favorite_border,
        title: 'Sin favoritos',
        message: 'Marca el corazón en el detalle de un libro para guardarlo aquí.',
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final fav = items[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          leading: BookCover(url: fav.coverUrl(size: 'S')),
          title: Text(fav.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: fav.author == null ? null : Text(fav.author!),
          trailing: IconButton(
            tooltip: 'Quitar de favoritos',
            icon: const Icon(Icons.favorite),
            onPressed: () =>
                context.read<FavoritesProvider>().toggleByFavorite(fav),
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BookDetailScreen(
                book: Book(
                  olKey: fav.olKey,
                  title: fav.title,
                  authors: fav.author == null ? const [] : [fav.author!],
                  coverId: fav.coverId,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
