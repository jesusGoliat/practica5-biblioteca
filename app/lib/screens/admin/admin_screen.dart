import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/favorite_book.dart';
import '../../core/models/history_entry.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/backend_api.dart';
import '../../widgets/common.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<List<Map<String, dynamic>>> _users =
      context.read<BackendApi>().adminUsers();

  void _reload() =>
      setState(() => _users = context.read<BackendApi>().adminUsers());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Administración')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _users,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final e = snapshot.error;
              return EmptyState(
                icon: Icons.lock_outline,
                title: e is ApiException && e.kind == ApiErrorKind.forbidden
                    ? 'Acceso denegado'
                    : 'No se pudo cargar',
                message: e is ApiException ? e.message : '$e',
                action: TextButton(
                  onPressed: _reload,
                  child: const Text('Reintentar'),
                ),
              );
            }
            final users = snapshot.data!;
            return ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final u = users[i];
                return ListTile(
                  leading: Icon(
                    u['role'] == 'admin' ? Icons.shield : Icons.person,
                  ),
                  title: Text('${u['name'] ?? u['username']}'),
                  subtitle: Text(
                    '${u['email'] ?? u['username']}\n'
                    'Favoritos: ${u['favorites']} · Historial: ${u['history']} · '
                    'Biblioteca: ${u['library']}',
                  ),
                  isThreeLine: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _UserDetail(
                        userId: (u['id'] as num).toInt(),
                        label: '${u['email'] ?? u['username']}',
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}

class _UserDetail extends StatelessWidget {
  const _UserDetail({required this.userId, required this.label});

  final int userId;
  final String label;

  @override
  Widget build(BuildContext context) {
    final api = context.read<BackendApi>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(label),
          bottom: const TabBar(
            tabs: [Tab(text: 'Historial'), Tab(text: 'Favoritos')],
          ),
        ),
        body: TabBarView(
          children: [
            _AsyncList<HistoryEntry>(
              future: api.adminHistory(userId),
              empty: 'Sin historial',
              tile: (h) => ListTile(
                leading: const Icon(Icons.history),
                title: Text(h.query),
                subtitle: Text(formatDateTime(h.createdAt)),
              ),
            ),
            _AsyncList<FavoriteBook>(
              future: api.adminFavorites(userId),
              empty: 'Sin favoritos',
              tile: (f) => ListTile(
                leading: BookCover(url: f.coverUrl(size: 'S'), width: 40, height: 60),
                title: Text(f.title),
                subtitle: f.author == null ? null : Text(f.author!),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AsyncList<T> extends StatelessWidget {
  const _AsyncList({required this.future, required this.empty, required this.tile});

  final Future<List<T>> future;
  final String empty;
  final Widget Function(T) tile;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<T>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final e = snapshot.error;
            return EmptyState(
              icon: Icons.error_outline,
              title: 'No se pudo cargar',
              message: e is ApiException ? e.message : '$e',
            );
          }
          final data = snapshot.data!;
          if (data.isEmpty) {
            return EmptyState(icon: Icons.inbox_outlined, title: empty);
          }
          return ListView(children: [for (final x in data) tile(x)]);
        },
      );
}
