import 'package:flutter_test/flutter_test.dart';
import 'package:parin_office/main.dart';

void main() {
  test('Parin Office ships at least 100 theme presets', () {
    expect(ThemeCatalog.presets.length, greaterThanOrEqualTo(100));
  });

  test('Parin Office exposes all requested locales', () {
    expect(L10n.locales.length, 16);
    expect(L10n.locales.map((e) => e.languageCode), contains('fa'));
    expect(L10n.locales.map((e) => e.languageCode), contains('he'));
    expect(L10n.locales.map((e) => e.languageCode), contains('ar'));
  });
}
