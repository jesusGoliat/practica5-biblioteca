import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/network/backend_api.dart';
import 'core/network/open_library_api.dart';
import 'data/repository.dart';
import 'providers/auth_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/library_provider.dart';
import 'providers/recommendations_provider.dart';
import 'providers/search_provider.dart';
import 'providers/sync_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();

  final api = BackendApi();
  final repository = Repository(api: api, openLibrary: OpenLibraryApi());
  late final SyncProvider sync;
  final search = SearchProvider(repository);
  final library = LibraryProvider(repository, onChanged: () => sync.localChanged());
  final favorites =
      FavoritesProvider(repository, onChanged: () => sync.localChanged());
  final recommendations = RecommendationsProvider(repository);
  sync = SyncProvider(
    repository,
    onSynced: () async {
      await library.load();
      await favorites.load();
      await search.loadHistory();
      if (search.error != null && search.query.trim().isNotEmpty && !search.isLoading) {
        await search.search(search.query, recordHistory: false);
      }
    },
  );
  final auth = AuthProvider(api: api, repository: repository);
  auth.addListener(() {
    if (!auth.isLoggedIn) {
      search.reset();
      library.reset();
      favorites.reset();
      recommendations.reset();
      sync.reset();
    }
  });

  runApp(
    MultiProvider(
      providers: [
        Provider<Repository>.value(value: repository),
        Provider<BackendApi>.value(value: api),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<SearchProvider>.value(value: search),
        ChangeNotifierProvider<LibraryProvider>.value(value: library),
        ChangeNotifierProvider<FavoritesProvider>.value(value: favorites),
        ChangeNotifierProvider<RecommendationsProvider>.value(
          value: recommendations,
        ),
        ChangeNotifierProvider<SyncProvider>.value(value: sync),
      ],
      child: const BibliotecaApp(),
    ),
  );
}

class BibliotecaApp extends StatefulWidget {
  const BibliotecaApp({super.key});

  @override
  State<BibliotecaApp> createState() => _BibliotecaAppState();
}

class _BibliotecaAppState extends State<BibliotecaApp> {
  late final Future<void> _init = context.read<AuthProvider>().init();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return MaterialApp(
      title: 'Biblioteca ESCOM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7B1E3A)),
        useMaterial3: true,
      ),
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: FutureBuilder<void>(
        future: _init,
        builder: (context, snapshot) {
          if (!auth.initialized) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return auth.isLoggedIn ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}
