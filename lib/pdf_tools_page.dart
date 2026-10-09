import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'document_factory.dart';
import 'office_editor_codec.dart';

enum PdfOfficeTarget { word, excel, powerpoint }

extension PdfOfficeTargetDetails on PdfOfficeTarget {
  String get label => switch (this) {
        PdfOfficeTarget.word => 'Word',
        PdfOfficeTarget.excel => 'Excel',
        PdfOfficeTarget.powerpoint => 'PowerPoint',
      };

  String get extension => switch (this) {
        PdfOfficeTarget.word => 'docx',
        PdfOfficeTarget.excel => 'xlsx',
        PdfOfficeTarget.powerpoint => 'pptx',
      };
}

/// Local PDF processing helpers. Page import uses vector page templates where
/// possible; it does not upload the document or convert it through a server.
class PdfToolsEngine {
  PdfToolsEngine._();

  static int pageCount(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      return document.pages.count;
    } finally {
      document.dispose();
    }
  }

  static List<int> parsePageRanges(String input, int totalPages) {
    final normalized = input.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'all') {
      return List<int>.generate(totalPages, (index) => index);
    }
    final pages = <int>{};
    for (final rawPart in normalized.split(',')) {
      final part = rawPart.trim();
      if (part.isEmpty) continue;
      final range = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(part);
      if (range != null) {
        final first = int.parse(range.group(1)!);
        final last = int.parse(range.group(2)!);
        if (first < 1 || last < first || last > totalPages) {
          throw FormatException('Page range "$part" is outside 1–$totalPages.');
        }
        for (var page = first; page <= last; page++) {
          pages.add(page - 1);
        }
      } else {
        final page = int.tryParse(part);
        if (page == null || page < 1 || page > totalPages) {
          throw FormatException('Page "$part" is outside 1–$totalPages.');
        }
        pages.add(page - 1);
      }
    }
    if (pages.isEmpty) throw const FormatException('Enter at least one page number.');
    return pages.toList()..sort();
  }

  static Future<Uint8List> merge(List<Uint8List> pdfFiles) async {
    if (pdfFiles.length < 2) {
      throw const FormatException('Choose at least two PDF files to merge.');
    }
    final output = PdfDocument();
    final opened = <PdfDocument>[];
    try {
      for (final bytes in pdfFiles) {
        final source = PdfDocument(inputBytes: bytes);
        opened.add(source);
        for (var index = 0; index < source.pages.count; index++) {
          _copyPageToDocument(source.pages[index], output);
        }
      }
      if (output.pages.count == 0) throw const FormatException('The selected files contain no pages.');
      return Uint8List.fromList(await output.save());
    } finally {
      for (final source in opened) {
        source.dispose();
      }
      output.dispose();
    }
  }

  static Future<Uint8List> extractPages(Uint8List bytes, List<int> zeroBasedPages) async {
    if (zeroBasedPages.isEmpty) throw const FormatException('Select one or more pages.');
    final source = PdfDocument(inputBytes: bytes);
    final output = PdfDocument();
    try {
      for (final index in zeroBasedPages) {
        if (index < 0 || index >= source.pages.count) {
          throw FormatException('Page ${index + 1} does not exist.');
        }
        _copyPageToDocument(source.pages[index], output);
      }
      return Uint8List.fromList(await output.save());
    } finally {
      source.dispose();
      output.dispose();
    }
  }

  static void _copyPageToDocument(PdfPage source, PdfDocument destination) {
    final target = destination.pages.add();
    final sourceSize = source.size;
    final targetSize = target.getClientSize();
    if (sourceSize.width <= 0 || sourceSize.height <= 0) {
      target.graphics.drawPdfTemplate(source.createTemplate(), Offset.zero);
      return;
    }
    final scale = math.min(
      targetSize.width / sourceSize.width,
      targetSize.height / sourceSize.height,
    );
    final width = sourceSize.width * scale;
    final height = sourceSize.height * scale;
    final left = (targetSize.width - width) / 2;
    final top = (targetSize.height - height) / 2;
    target.graphics.drawPdfTemplate(
      source.createTemplate(),
      Offset(left, top),
      Size(width, height),
    );
  }

  static Future<Uint8List> rotate(Uint8List bytes, List<int> pages, PdfPageRotateAngle angle) async {
    final document = PdfDocument(inputBytes: bytes);
    try {
      for (final index in pages) {
        if (index < 0 || index >= document.pages.count) {
          throw FormatException('Page ${index + 1} does not exist.');
        }
        document.pages[index].rotation = angle;
      }
      return Uint8List.fromList(await document.save());
    } finally {
      document.dispose();
    }
  }

  static Future<Uint8List> addPageNumbers(Uint8List bytes) async {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final total = document.pages.count;
      final font = PdfStandardFont(PdfFontFamily.helvetica, 9);
      for (var index = 0; index < total; index++) {
        final page = document.pages[index];
        final size = page.getClientSize();
        page.graphics.drawString(
          '${index + 1} / $total',
          font,
          brush: PdfBrushes.gray,
          bounds: Rect.fromLTWH(0, size.height - 26, size.width, 16),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
      }
      return Uint8List.fromList(await document.save());
    } finally {
      document.dispose();
    }
  }

  static Future<Uint8List> addWatermark(Uint8List bytes, String watermark) async {
    final text = watermark.trim();
    if (text.isEmpty) throw const FormatException('Enter watermark text.');
    final document = PdfDocument(inputBytes: bytes);
    try {
      final font = PdfStandardFont(PdfFontFamily.helvetica, 32, style: PdfFontStyle.bold);
      final brush = PdfSolidBrush(PdfColor(155, 155, 155));
      for (var index = 0; index < document.pages.count; index++) {
        final page = document.pages[index];
        final size = page.getClientSize();
        page.graphics.drawString(
          text,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(24, size.height * 0.42, size.width - 48, 58),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
      }
      return Uint8List.fromList(await document.save());
    } finally {
      document.dispose();
    }
  }

  static Future<Uint8List> convertToOffice({
    required Uint8List bytes,
    required PdfOfficeTarget target,
    required String title,
  }) async {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      final pages = <String>[
        for (var index = 0; index < document.pages.count; index++)
          extractor.extractText(startPageIndex: index, endPageIndex: index, layoutText: true).trim(),
      ];
      final hasText = pages.any((page) => page.isNotEmpty);
      if (!hasText) {
        throw const FormatException(
          'No selectable text was found. This PDF may be scanned; OCR is not included in this offline converter.',
        );
      }
      final baseTitle = title.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');
      switch (target) {
        case PdfOfficeTarget.word:
          final body = <String>[
            for (var index = 0; index < pages.length; index++)
              if (pages[index].isNotEmpty) 'Page ${index + 1}\n${pages[index]}',
          ].join('\n\n');
          return await OfficeDocumentFactory.create(
            kind: OfficeKind.word,
            title: baseTitle,
            body: body,
            subtitle: '',
          );
        case PdfOfficeTarget.excel:
          final rows = <String>['Page,Text'];
          for (var index = 0; index < pages.length; index++) {
            for (final line in pages[index].split(RegExp(r'\r?\n'))) {
              final value = line.trim().replaceAll(',', ';').replaceAll('\r', ' ');
              if (value.isNotEmpty) rows.add('${index + 1},$value');
            }
          }
          return await OfficeDocumentFactory.create(
            kind: OfficeKind.excel,
            title: baseTitle,
            body: rows.join('\n'),
            subtitle: '',
          );
        case PdfOfficeTarget.powerpoint:
          final slides = <PresentationSlideDraft>[
            for (var index = 0; index < pages.length; index++)
              PresentationSlideDraft(
                title: 'Page ${index + 1}',
                body: pages[index].isEmpty ? 'No text extracted from this page.' : pages[index],
              ),
          ];
          return OfficeEditorCodec.createPresentation(
            title: baseTitle,
            slides: slides,
            accentHex: '2869F6',
          );
      }
    } finally {
      document.dispose();
    }
  }
}

class PdfToolsPage extends StatefulWidget {
  const PdfToolsPage({
    super.key,
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;

  @override
  State<PdfToolsPage> createState() => _PdfToolsPageState();
}

class _PdfToolsPageState extends State<PdfToolsPage> {
  bool _busy = false;
  bool _includeCurrent = true;
  int? _pages;
  String? _pageCountError;

  String get _baseName => widget.fileName.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');

  @override
  void initState() {
    super.initState();
    _readPageCount();
  }

  Future<void> _readPageCount() async {
    try {
      final count = PdfToolsEngine.pageCount(widget.bytes);
      if (mounted) setState(() => _pages = count);
    } catch (error) {
      if (mounted) setState(() => _pageCountError = error.toString());
    }
  }

  Future<void> _saveOutput(Uint8List bytes, String fileName, {String title = 'Save PDF output'}) async {
    final path = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: fileName.toLowerCase().endsWith('.pdf') ? 'application/pdf' : _mimeFor(fileName),
      dialogTitle: title,
    );
    if (mounted && path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved $fileName')),
      );
    }
  }

  String _mimeFor(String name) => switch (name.split('.').last.toLowerCase()) {
        'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        _ => 'application/octet-stream',
      };

  Future<void> _run(String label, Future<Uint8List> Function() operation, String outputName) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final output = await operation();
      await _saveOutput(output, outputName, title: label);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askPageRange({String title = 'Pages to process'}) async {
    final controller = TextEditingController(text: 'all');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Page numbers',
                hintText: 'all, 1-3, 5, 8-10',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This PDF has ${_pages ?? '?'} pages. Use commas and ranges; numbering starts at 1.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Continue')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _extractPages() async {
    final input = await _askPageRange(title: 'Split / extract pages');
    if (input == null) return;
    await _run(
      'Extract pages',
      () async {
        final total = PdfToolsEngine.pageCount(widget.bytes);
        final indexes = PdfToolsEngine.parsePageRanges(input, total);
        return PdfToolsEngine.extractPages(widget.bytes, indexes);
      },
      '$_baseName-pages.pdf',
    );
  }

  Future<void> _rotatePages() async {
    final range = await _askPageRange(title: 'Rotate pages');
    if (range == null) return;
    final angle = await showModalBottomSheet<PdfPageRotateAngle>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in const <(String, PdfPageRotateAngle)>[
              ('Rotate clockwise 90°', PdfPageRotateAngle.rotateAngle90),
              ('Rotate 180°', PdfPageRotateAngle.rotateAngle180),
              ('Rotate 270°', PdfPageRotateAngle.rotateAngle270),
              ('Reset to 0°', PdfPageRotateAngle.rotateAngle0),
            ])
              ListTile(title: Text(entry.$1), onTap: () => Navigator.pop(context, entry.$2)),
          ],
        ),
      ),
    );
    if (angle == null) return;
    await _run(
      'Rotate pages',
      () async {
        final total = PdfToolsEngine.pageCount(widget.bytes);
        return PdfToolsEngine.rotate(widget.bytes, PdfToolsEngine.parsePageRanges(range, total), angle);
      },
      '$_baseName-rotated.pdf',
    );
  }

  Future<void> _addPageNumbers() => _run(
        'Add page numbers',
        () => PdfToolsEngine.addPageNumbers(widget.bytes),
        '$_baseName-numbered.pdf',
      );

  Future<void> _addWatermark() async {
    final controller = TextEditingController(text: 'CONFIDENTIAL');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add watermark'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Watermark text')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Apply')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return;
    await _run(
      'Add watermark',
      () => PdfToolsEngine.addWatermark(widget.bytes, value),
      '$_baseName-watermarked.pdf',
    );
  }

  Future<void> _merge() async {
    final selection = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (selection.isEmpty) return;
    await _run(
      'Merge PDFs',
      () async {
        final inputs = <Uint8List>[];
        if (_includeCurrent) inputs.add(widget.bytes);
        for (final file in selection) {
          final selectedBytes = await file.readAsBytes();
          inputs.add(selectedBytes);
        }
        if (inputs.length < 2) throw const FormatException('Select at least two PDFs in total.');
        return PdfToolsEngine.merge(inputs);
      },
      '$_baseName-merged.pdf',
    );
  }

  Future<void> _convert(PdfOfficeTarget target) async {
    await _run(
      'Convert PDF to ${target.label}',
      () => PdfToolsEngine.convertToOffice(
        bytes: widget.bytes,
        target: target,
        title: _baseName,
      ),
      '$_baseName.${target.extension}',
    );
  }

  Widget _tool({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('PDF tools')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.fileName, style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(
                            _pageCountError ?? '${_pages ?? '…'} pages • ${(widget.bytes.length / 1024).ceil()} KB',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Combine and convert', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              _tool(
                icon: Icons.merge_type_rounded,
                title: 'Merge multiple PDFs',
                subtitle: 'Choose PDFs to join; include the currently open file optionally.',
                onTap: _merge,
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('Include current PDF in merge'),
                value: _includeCurrent,
                onChanged: _busy ? null : (value) => setState(() => _includeCurrent = value),
              ),
              for (final target in PdfOfficeTarget.values)
                _tool(
                  icon: switch (target) {
                    PdfOfficeTarget.word => Icons.article_outlined,
                    PdfOfficeTarget.excel => Icons.grid_on_outlined,
                    PdfOfficeTarget.powerpoint => Icons.slideshow_outlined,
                  },
                  title: 'Convert PDF to ${target.label}',
                  subtitle: switch (target) {
                    PdfOfficeTarget.word => 'Extract selectable text into an editable DOCX file.',
                    PdfOfficeTarget.excel => 'Put extracted lines into spreadsheet rows for cleanup.',
                    PdfOfficeTarget.powerpoint => 'Create one editable slide per PDF page.',
                  },
                  onTap: () => _convert(target),
                ),
              const SizedBox(height: 14),
              Text('Pages and layout', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              _tool(
                icon: Icons.content_cut_rounded,
                title: 'Split / extract pages',
                subtitle: 'Create a new PDF from page ranges such as 1-3, 5, 8-10.',
                onTap: _extractPages,
              ),
              _tool(
                icon: Icons.rotate_right_rounded,
                title: 'Rotate pages',
                subtitle: 'Rotate selected pages by 90°, 180°, 270°, or reset.',
                onTap: _rotatePages,
              ),
              _tool(
                icon: Icons.format_list_numbered_rounded,
                title: 'Add page numbers',
                subtitle: 'Add a bottom-center page number to every page.',
                onTap: _addPageNumbers,
              ),
              _tool(
                icon: Icons.branding_watermark_outlined,
                title: 'Add watermark',
                subtitle: 'Stamp a visible watermark across all pages.',
                onTap: _addWatermark,
              ),
              const SizedBox(height: 8),
              const Text(
                'Conversion extracts selectable text only. Scanned/image-only PDFs need OCR, and complex tables or page layouts may need manual cleanup after conversion.',
              ),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: theme.colorScheme.scrim.withAlpha(84),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Working locally…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
