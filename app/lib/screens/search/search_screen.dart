import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/book.dart';
import '../../providers/search_provider.dart';
import '../../widgets/common.dart';
import 'book_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _run(String q) {
    _controller.text = q;
    context.read<SearchProvider>().search(q);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SearchProvider>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            key: const Key('search-field'),
            controller: _controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar libros o autores',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Borrar búsqueda',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        context.read<SearchProvider>().onQueryChanged('');
                      },
                    ),
            ),
            onChanged: (v) {
              setState(() {});
              context.read<SearchProvider>().onQueryChanged(v);
            },
            onSubmitted: (v) => context.read<SearchProvider>().search(v),
          ),
        ),
        if (s.isLoading) const LinearProgressIndicator(),
        if (s.error != null)
          ErrorBanner(
            s.error!,
            onRetry: () => context.read<SearchProvider>().search(s.query),
          ),
        if (s.hasSearched && s.fetchedAt != null && (s.error == null || s.fromCache))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                s.fromCache
                    ? 'Resultados guardados (${formatDateTime(s.fetchedAt!)})'
                    : '${s.total} resultados en '
                        '${((s.elapsed?.inMilliseconds ?? 0) / 1000).toStringAsFixed(1)} s',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        Expanded(child: _body(context, s)),
      ],
    );
  }

  Widget _body(BuildContext context, SearchProvider s) {
    if (!s.hasSearched && !s.isLoading) return _history(context, s);
    if (s.results.isEmpty && !s.isLoading) {
      return s.error != null
          ? const EmptyState(
              icon: Icons.wifi_off,
              title: 'No se pudo completar la búsqueda',
              message: 'Sin conexión no hay resultados guardados para esta consulta.',
            )
          : EmptyState(
              icon: Icons.search_off,
              title: 'Sin resultados',
              message: 'No encontramos libros para "${s.query}".',
            );
    }
    return ListView.separated(
      itemCount: s.results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => _BookTile(book: s.results[i]),
    );
  }

  Widget _history(BuildContext context, SearchProvider s) {
    if (s.history.isEmpty) {
      return const EmptyState(
        icon: Icons.menu_book_outlined,
        title: 'Busca tu próximo libro',
        message: 'Escribe un título o un autor. Tus búsquedas aparecerán aquí.',
      );
    }
    return ListView(
      children: [
        ListTile(
          title: Text(
            'Historial de búsquedas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          trailing: TextButton(
            onPressed: () => context.read<SearchProvider>().clearHistory(),
            child: const Text('Borrar'),
          ),
        ),
        for (final h in s.history)
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(h.query),
            subtitle: Text(formatDateTime(h.createdAt)),
            onTap: () => _run(h.query),
          ),
      ],
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: BookCover(url: book.coverUrl(size: 'S')),
        title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (book.author != null) book.author!,
            if (book.firstPublishYear != null) '${book.firstPublishYear}',
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BookDetailScreen(book: book),
          ),
        ),
      );
}
