import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:parin_office/main.dart';
import 'package:parin_office/document_factory.dart';
import 'package:archive/archive.dart';

void main() {
  test('contains at least one hundred curated theme palettes', () {
    expect(ThemeCatalog.presets.length, greaterThanOrEqualTo(100));
    expect(ThemeCatalog.presets.length, 128);
    expect(ThemeCatalog.presets.map((item) => item.family).toSet().length, 16);
  });

  test('supports the complete language selector and RTL locales', () {
    expect(L10n.locales.length, 16);
    expect(L10n.locales.any((locale) => locale.languageCode == 'fa'), isTrue);
    expect(L10n.locales.any((locale) => locale.languageCode == 'ar'), isTrue);
    expect(L10n.locales.any((locale) => locale.languageCode == 'he'), isTrue);
    expect(L10n.rtl(const Locale('fa')), isTrue);
    expect(L10n.rtl(const Locale('ar')), isTrue);
    expect(L10n.rtl(const Locale('he')), isTrue);
    expect(L10n.rtl(const Locale('en')), isFalse);
  });

  test('creates real file bytes for PDF, DOCX, PPTX and XLSX', () async {
    final pdf = await DocumentFactory.create(DocumentKind.pdf, 'Sample PDF', 'PDF content');
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');

    final docx = await DocumentFactory.create(DocumentKind.word, 'Sample Word', 'Paragraph one');
    final pptx = await DocumentFactory.create(DocumentKind.powerpoint, 'Sample Slides', 'Key point');
    final xlsx = await DocumentFactory.create(DocumentKind.excel, 'Sample Sheet', 'Name\tValue\nA\t1');

    for (final bytes in [docx, pptx, xlsx]) {
      expect(bytes.take(2).toList(), [80, 75]);
      expect(ZipDecoder().decodeBytes(bytes).files, isNotEmpty);
    }

    final docxArchive = ZipDecoder().decodeBytes(docx);
    final pptxArchive = ZipDecoder().decodeBytes(pptx);
    final xlsxArchive = ZipDecoder().decodeBytes(xlsx);
    expect(docxArchive.findFile('word/document.xml'), isNotNull);
    expect(pptxArchive.findFile('ppt/slides/slide1.xml'), isNotNull);
    expect(xlsxArchive.findFile('xl/worksheets/sheet1.xml'), isNotNull);
  });
}
