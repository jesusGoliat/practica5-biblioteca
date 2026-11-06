import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/favorites_provider.dart';
import '../providers/library_provider.dart';
import '../providers/recommendations_provider.dart';
import '../providers/search_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/common.dart';
import 'favorites/favorites_screen.dart';
import 'library/library_screen.dart';
import 'profile/profile_screen.dart';
import 'recommendations/recommendations_screen.dart';
import 'search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSession());
  }

  Future<void> _loadSession() async {
    final library = context.read<LibraryProvider>();
    final favorites = context.read<FavoritesProvider>();
    final search = context.read<SearchProvider>();
    final recommendations = context.read<RecommendationsProvider>();
    final sync = context.read<SyncProvider>();
    await Future.wait([library.load(), favorites.load(), search.loadHistory()]);
    await recommendations.load(refresh: false);
    await sync.start();
  }

  @override
  Widget build(BuildContext context) {
    final libraryCount = context.watch<LibraryProvider>().items.length;
    const pages = <Widget>[
      SearchScreen(),
      LibraryScreen(),
      FavoritesScreen(),
      RecommendationsScreen(),
      ProfileScreen(),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SyncBanner(),
            Expanded(child: IndexedStack(index: _index, children: pages)),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: libraryCount > 0,
              label: Text('$libraryCount'),
              child: const Icon(Icons.collections_bookmark_outlined),
            ),
            label: 'Biblioteca',
          ),
          const NavigationDestination(
            icon: Icon(Icons.favorite_border),
            label: 'Favoritos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            label: 'Para ti',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
