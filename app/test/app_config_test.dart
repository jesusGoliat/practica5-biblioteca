import 'package:flutter_test/flutter_test.dart';

import 'package:biblioteca/core/config/app_config.dart';

void main() {
  test('release rechaza una API remota por HTTP', () {
    expect(
      () => AppConfig.validate(release: true, url: 'http://192.168.1.10:8000'),
      throwsStateError,
    );
  });

  test('release acepta HTTPS y debug permite HTTP local', () {
    AppConfig.validate(release: true, url: 'https://api.ejemplo.dev');
    AppConfig.validate(release: false, url: 'http://127.0.0.1:8000');
  });
}
