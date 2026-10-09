import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parin_office/document_factory.dart';
import 'package:parin_office/main.dart';
import 'package:parin_office/office_editor_codec.dart';
import 'package:parin_office/pdf_tools_page.dart';
import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

void main() {
  test('Parin Office provides 128 named, categorized theme presets', () {
    expect(ThemeCatalog.presets.length, 128);
    expect(ThemeCatalog.presets.map((theme) => theme.name).toSet().length, 128);
    expect(ThemeCatalog.presets.map((theme) => theme.family).toSet().length, 16);
  });

  test('Light, dark and AMOLED surfaces remain visually distinct', () {
    final preset = ThemeCatalog.presets.first;
    final light = ThemeCatalog.build(preset, Brightness.light, false);
    final dark = ThemeCatalog.build(preset, Brightness.dark, false);
    final amoled = ThemeCatalog.build(preset, Brightness.dark, true);

    expect(light.scaffoldBackgroundColor, isNot(dark.scaffoldBackgroundColor));
    expect(amoled.scaffoldBackgroundColor, const Color(0xFF000000));
    expect(amoled.cardTheme.color, isNot(amoled.scaffoldBackgroundColor));
    expect(dark.colorScheme.primary, isNot(preset.primary));
    expect(dark.colorScheme.onSurface, const Color(0xFFF2F5FA));
  });

  test('Metro themes include Liquid Glass while preserving all 128 palettes', () {
    expect(AppearanceMode.values, contains(AppearanceMode.liquidGlass));
    expect(ThemeCatalog.presets, hasLength(128));
    final glass = ThemeCatalog.build(
      ThemeCatalog.presets.first,
      Brightness.light,
      false,
      liquidGlass: true,
    );
    expect(glass.cardTheme.elevation, 2);
    expect(glass.colorScheme.surface.alpha, lessThan(255));
    final metro = ThemeCatalog.build(ThemeCatalog.presets.first, Brightness.light, false);
    expect(metro.cardTheme.shape, isA<RoundedRectangleBorder>());
  });

  test('New settings labels resolve for all supported locales', () {
    for (final locale in L10n.locales) {
      expect(L10n.text(locale, 'fontFamily'), isNot('fontFamily'));
      expect(L10n.text(locale, 'showWelcomePanel'), isNot('showWelcomePanel'));
      expect(L10n.text(locale, 'confirmRecentRemoval'), isNot('confirmRecentRemoval'));
    }
  });

  test('Parin Office exposes all supported locales', () {
    expect(L10n.locales.length, 16);
    expect(L10n.locales.map((locale) => locale.languageCode), contains('fa'));
    expect(L10n.locales.map((locale) => locale.languageCode), contains('he'));
    expect(L10n.locales.map((locale) => locale.languageCode), contains('ar'));
    expect(L10n.rtl(const Locale('fa')), isTrue);
    expect(L10n.rtl(const Locale('ar')), isTrue);
    expect(L10n.rtl(const Locale('he')), isTrue);
    expect(L10n.rtl(const Locale('en')), isFalse);
    expect(L10n.text(const Locale('fa'), 'settings'), 'تنظیمات');
  });

  test('Dashboard and editor preferences persist and restore', () async {
    SharedPreferences.setMockInitialValues({});
    final first = AppState();
    await first.load();
    await first.setFlag('showWelcomePanel', false);
    await first.setFlag('showQuickActions', false);
    await first.setFlag('showDashboardMetrics', false);
    await first.setFlag('confirmRecentRemoval', false);
    await first.setEditorFontFamily('monospace');
    await first.setLineSpacing(1.6);

    final restored = AppState();
    await restored.load();
    expect(restored.showWelcomePanel, isFalse);
    expect(restored.showQuickActions, isFalse);
    expect(restored.showDashboardMetrics, isFalse);
    expect(restored.confirmRecentRemoval, isFalse);
    expect(restored.editorFontFamily, 'monospace');
    expect(restored.lineSpacing, closeTo(1.6, 0.001));
    first.dispose();
    restored.dispose();
  });

  test('Word editor exports formatted DOCX paragraphs', () {
    final bytes = OfficeEditorCodec.createWordFromDelta(
      delta: <dynamic>[
        {'insert': 'A formatted heading\n', 'attributes': {'header': 1}},
        {'insert': 'Important text', 'attributes': {'bold': true, 'color': '#FF0000'}},
        {'insert': '\n'},
      ],
      pageSize: 'A4',
      landscape: false,
      margins: 'Normal',
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final document = utf8.decode(
      archive.files.firstWhere((file) => file.name == 'word/document.xml').content as List<int>,
    );
    expect(document, contains('A formatted heading'));
    expect(document, contains('<w:b/>'));
    expect(document, contains('FF0000'));
    expect(document, contains('w:pgSz'));
  });

  test('PowerPoint editor exports multiple editable slides and honors blank layout', () {
    final bytes = OfficeEditorCodec.createPresentation(
      title: 'Editable presentation',
      accentHex: '2869F6',
      slides: <PresentationSlideDraft>[
        PresentationSlideDraft(title: 'First slide', body: 'First bullet\n• Key point'),
        PresentationSlideDraft(title: 'Blank slide', body: 'Must not appear', layout: 'Blank'),
      ],
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((file) => file.name).toSet();
    expect(names, contains('ppt/slides/slide1.xml'));
    expect(names, contains('ppt/slides/slide2.xml'));
    final first = utf8.decode(archive.files.firstWhere((file) => file.name == 'ppt/slides/slide1.xml').content as List<int>);
    final second = utf8.decode(archive.files.firstWhere((file) => file.name == 'ppt/slides/slide2.xml').content as List<int>);
    expect(first, contains('First slide'));
    expect(first, contains('Key point'));
    expect(second, isNot(contains('Must not appear')));
    expect(OfficeEditorCodec.extractPresentation(bytes), hasLength(2));
  });

  test('Excel editor engine can edit cells and recalculate formulas', () async {
    final workbook = xls.Excel.createExcel();
    final sheet = workbook['Sheet1'];
    sheet.updateCell(xls.CellIndex.indexByString('A1'), xls.IntCellValue(10));
    sheet.updateCell(xls.CellIndex.indexByString('A2'), xls.IntCellValue(20));
    sheet.updateCell(xls.CellIndex.indexByString('A3'), xls.FormulaCellValue('SUM(A1:A2)'));
    workbook.recalculate();
    final calculated = sheet.evaluate(xls.CellIndex.indexByString('A3'));
    expect(calculated, isA<xls.IntCellValue>());
    expect((calculated as xls.IntCellValue).value, 30);

    final saved = workbook.save();
    expect(saved, isNotNull);
    final restored = await xls.Excel.decodeBytesAsync(saved!);
    expect(restored.tables.keys, contains('Sheet1'));
    expect(restored['Sheet1'].cell(xls.CellIndex.indexByString('A1')).value, isA<xls.IntCellValue>());
  });

  test('Embedded offline engine opens and round-trips DOCX, XLSX, and PPTX', () async {
    final wordBytes = await OfficeDocumentFactory.create(
      kind: OfficeKind.word,
      title: 'Offline word',
      body: 'A real local engine',
      subtitle: '',
    );
    final word = WordEditorController.fromBytes(wordBytes);
    expect(await word.saveBytesAsync(), isNotEmpty);
    word.dispose();

    final sheetBytes = await OfficeDocumentFactory.create(
      kind: OfficeKind.excel,
      title: 'Offline sheet',
      body: 'Name,Value\\nPen,3\\nBook,7',
      subtitle: '',
    );
    final sheet = SheetEditorController.fromBytes(sheetBytes);
    expect(await sheet.saveBytesAsync(), isNotEmpty);
    sheet.dispose();

    final slidesBytes = await OfficeDocumentFactory.create(
      kind: OfficeKind.powerpoint,
      title: 'Offline slides',
      body: 'First point\\nSecond point',
      subtitle: 'Local',
    );
    final slides = SlideEditorController.fromBytes(slidesBytes);
    expect(await slides.saveBytesAsync(), isNotEmpty);
    slides.dispose();
  });

  test('PDF page-range parser handles discrete pages and ranges safely', () {
    expect(PdfToolsEngine.parsePageRanges('1-3, 5, 7-8', 8), <int>[0, 1, 2, 4, 6, 7]);
    expect(PdfToolsEngine.parsePageRanges('all', 3), <int>[0, 1, 2]);
    expect(() => PdfToolsEngine.parsePageRanges('2-7', 6), throwsFormatException);
    expect(() => PdfToolsEngine.parsePageRanges('0', 6), throwsFormatException);
  });

  test('PDF tools merge files and extract selected pages offline', () async {
    final first = await OfficeDocumentFactory.create(
      kind: OfficeKind.pdf,
      title: 'First PDF',
      body: 'First page text',
      subtitle: '',
    );
    final second = await OfficeDocumentFactory.create(
      kind: OfficeKind.pdf,
      title: 'Second PDF',
      body: 'Second page text',
      subtitle: '',
    );
    final merged = await PdfToolsEngine.merge(<Uint8List>[first, second]);
    expect(PdfToolsEngine.pageCount(merged), 2);
    final extracted = await PdfToolsEngine.extractPages(merged, <int>[1]);
    expect(PdfToolsEngine.pageCount(extracted), 1);
  });

  test('PDF conversion exports editable DOCX, XLSX, and PPTX packages from selectable text', () async {
    final source = await OfficeDocumentFactory.create(
      kind: OfficeKind.pdf,
      title: 'Conversion source',
      body: 'Product Name     Price\\nNotebook        12\\nPen             3',
      subtitle: '',
    );
    final word = await PdfToolsEngine.convertToOffice(
      bytes: source,
      target: PdfOfficeTarget.word,
      title: 'Source.pdf',
    );
    final sheet = await PdfToolsEngine.convertToOffice(
      bytes: source,
      target: PdfOfficeTarget.excel,
      title: 'Source.pdf',
    );
    final slides = await PdfToolsEngine.convertToOffice(
      bytes: source,
      target: PdfOfficeTarget.powerpoint,
      title: 'Source.pdf',
    );
    expect(ZipDecoder().decodeBytes(word).files.map((file) => file.name), contains('word/document.xml'));
    expect(ZipDecoder().decodeBytes(sheet).files.map((file) => file.name), contains('xl/worksheets/sheet1.xml'));
    expect(ZipDecoder().decodeBytes(slides).files.map((file) => file.name), contains('ppt/slides/slide1.xml'));
  });

  test('Create PDF returns a PDF document', () async {
    final bytes = await OfficeDocumentFactory.create(
      kind: OfficeKind.pdf,
      title: 'Test document',
      body: 'Hello Parin Office',
      subtitle: '',
    );
    expect(utf8.decode(bytes.take(5).toList()), startsWith('%PDF-'));
  });

  test('Create Word returns a valid DOCX package', () async {
    final bytes = await OfficeDocumentFactory.create(
      kind: OfficeKind.word,
      title: 'Test document',
      body: 'First paragraph\nSecond paragraph',
      subtitle: '',
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    expect(archive.files.map((file) => file.name), contains('word/document.xml'));
  });

  test('Create PowerPoint returns a PPTX package with a slide', () async {
    final bytes = await OfficeDocumentFactory.create(
      kind: OfficeKind.powerpoint,
      title: 'Test presentation',
      body: 'Outline',
      subtitle: 'A subtitle',
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    expect(archive.files.map((file) => file.name), contains('ppt/slides/slide1.xml'));
    expect(archive.files.map((file) => file.name), contains('ppt/presentation.xml'));
  });

  test('Create Excel returns an XLSX package with worksheet rows', () async {
    final bytes = await OfficeDocumentFactory.create(
      kind: OfficeKind.excel,
      title: 'Test workbook',
      body: 'Name,Value\nWidget,12\nGadget,7',
      subtitle: '',
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    expect(archive.files.map((file) => file.name), contains('xl/worksheets/sheet1.xml'));
    final sheet = archive.files.firstWhere((file) => file.name == 'xl/worksheets/sheet1.xml');
    expect(utf8.decode(sheet.content as List<int>), contains('Widget'));
  });
}
