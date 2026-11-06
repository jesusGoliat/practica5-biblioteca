// Recorrido de evidencia (iOS/Android). Necesita el backend en API_BASE_URL.
// Se ejecuta con `flutter drive` (ver .github/workflows/ios.yml).
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:biblioteca/main.dart' as app;

const _email = String.fromEnvironment('DEMO_EMAIL');
const _password = String.fromEnvironment('DEMO_PASSWORD');
const _adminEmail = String.fromEnvironment('ADMIN_EMAIL');
const _adminPassword = String.fromEnvironment('ADMIN_PASSWORD');

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int seconds = 60,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('No apareció: $finder');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(String name) async {
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot(name);
  }

  testWidgets('recorrido de evidencia', (tester) async {
    app.main();
    await pumpUntil(tester, find.byKey(const Key('login-email')));
    await shot('01-login');

    // Registro.
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await pumpUntil(tester, find.byKey(const Key('register-email')));
    await tester.enterText(find.byKey(const Key('register-name')), 'Alumno ESCOM');
    await tester.enterText(find.byKey(const Key('register-email')), _email);
    await tester.enterText(find.byKey(const Key('register-password')), _password);
    await tester.enterText(find.byKey(const Key('register-confirm')), _password);
    await shot('02-registro');
    await tester.tap(find.byKey(const Key('register-submit')));
    await pumpUntil(tester, find.byKey(const Key('search-field')));
    await shot('03-inicio-busqueda');

    // Búsqueda pública (Open Library).
    await tester.enterText(find.byKey(const Key('search-field')), 'dune');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpUntil(tester, find.textContaining('resultados en'));
    await shot('04-resultados-busqueda');

    // Detalle, favorito y biblioteca.
    await tester.tap(find.byType(ListTile).first);
    await pumpUntil(tester, find.byKey(const Key('favorite-toggle')));
    await tester.pump(const Duration(seconds: 2));
    await shot('05-detalle-libro');
    await tester.tap(find.byKey(const Key('favorite-toggle')));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Leyendo'));
    await tester.pump(const Duration(seconds: 1));
    await shot('06-favorito-y-biblioteca');
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Biblioteca'));
    await tester.pump(const Duration(seconds: 1));
    await shot('07-biblioteca');
    await tester.tap(find.text('Favoritos').last);
    await tester.pump(const Duration(seconds: 1));
    await shot('08-favoritos');

    // Recomendaciones.
    await tester.tap(find.text('Para ti'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('generate-recommendations')));
    await pumpUntil(tester, find.text('Criterio'));
    await tester.pump(const Duration(seconds: 2));
    await shot('09-recomendaciones');

    // Historial de búsquedas.
    await tester.tap(find.text('Buscar'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Borrar búsqueda'));
    await tester.pump(const Duration(seconds: 1));
    await shot('10-historial');

    // Perfil / sincronización y cierre de sesión.
    await tester.tap(find.text('Perfil'));
    await tester.pump(const Duration(seconds: 1));
    await shot('11-perfil-sincronizacion');
    await tester.tap(find.byKey(const Key('logout')));
    await pumpUntil(tester, find.byKey(const Key('login-email')));
    await shot('12-sesion-cerrada');

    // Administrador.
    if (_adminEmail.isNotEmpty) {
      await tester.enterText(find.byKey(const Key('login-email')), _adminEmail);
      await tester.enterText(find.byKey(const Key('login-password')), _adminPassword);
      await tester.tap(find.byKey(const Key('login-submit')));
      await pumpUntil(tester, find.byKey(const Key('search-field')));
      await tester.tap(find.text('Perfil'));
      await pumpUntil(tester, find.byKey(const Key('admin-entry')));
      await tester.tap(find.byKey(const Key('admin-entry')));
      await pumpUntil(tester, find.textContaining('Favoritos:'));
      await shot('13-admin-usuarios');
      await tester.tap(find.textContaining('Favoritos:').last);
      await pumpUntil(tester, find.text('Historial'));
      await tester.pump(const Duration(seconds: 2));
      await shot('14-admin-detalle-usuario');
    }
  });
}
