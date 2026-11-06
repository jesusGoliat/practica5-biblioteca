import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:biblioteca/core/network/backend_api.dart';
import 'package:biblioteca/core/network/open_library_api.dart';
import 'package:biblioteca/data/repository.dart';
import 'package:biblioteca/providers/auth_provider.dart';
import 'package:biblioteca/screens/auth/login_screen.dart';

void main() {
  testWidgets('el login valida el correo antes de llamar al servidor', (
    tester,
  ) async {
    final api = BackendApi(baseUrl: 'http://127.0.0.1:1');
    final repo = Repository(api: api, openLibrary: OpenLibraryApi(dio: Dio()));
    final auth = AuthProvider(api: api, repository: repo);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.enterText(find.byKey(const Key('login-email')), 'no-es-correo');
    await tester.enterText(find.byKey(const Key('login-password')), 'secreto123');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();

    expect(find.text('Escribe un correo válido'), findsOneWidget);
    expect(auth.isLoading, isFalse);
    expect(find.text('Continuar con Google'), findsOneWidget);
  });
}
