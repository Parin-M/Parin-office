import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parin_office/document_factory.dart';
import 'package:parin_office/main.dart';

void main() {
  test('Parin Office provides 128 named, categorized theme presets', () {
    expect(ThemeCatalog.presets.length, 128);
    expect(ThemeCatalog.presets.map((theme) => theme.name).toSet().length, 128);
    expect(ThemeCatalog.presets.map((theme) => theme.family).toSet().length, 16);
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
