import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/common.dart';
import '../admin/admin_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final sync = context.watch<SyncProvider>();
    if (user == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CircleAvatar(
            radius: 36,
            child: Text(
              user.displayName.characters.first.toUpperCase(),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            user.displayName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (user.email != null) Center(child: Text(user.email!)),
        const SizedBox(height: 8),
        Center(
          child: Chip(
            avatar: Icon(user.isAdmin ? Icons.shield : Icons.person, size: 18),
            label: Text(user.isAdmin ? 'Administrador' : 'Usuario'),
          ),
        ),
        const Divider(height: 32),
        ListTile(
          leading: const Icon(Icons.sync),
          title: const Text('Sincronización'),
          subtitle: Text(
            '${sync.status.pending} pendiente(s)\n'
            '${sync.status.lastSyncAt == null ? 'Aún sin sincronizar' : 'Última: ${formatDateTime(sync.status.lastSyncAt!)}'}'
            '${sync.status.lastError == null ? '' : '\nError: ${sync.status.lastError}'}',
          ),
          isThreeLine: true,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 56),
            child: TextButton.icon(
              key: const Key('sync-now'),
              icon: const Icon(Icons.sync),
              label: const Text('Sincronizar ahora'),
              onPressed: sync.online ? sync.syncNow : null,
            ),
          ),
        ),
        if (user.isAdmin)
          ListTile(
            key: const Key('admin-entry'),
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Panel de administración'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AdminScreen()),
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('logout'),
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
          onPressed: () => context.read<AuthProvider>().logout(),
        ),
      ],
    );
  }
}
