import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pdf/widgets.dart' as pw;

enum DocumentKind { pdf, word, powerpoint, excel }

extension DocumentKindInfo on DocumentKind {
  String get label => switch (this) {
        DocumentKind.pdf => 'PDF',
        DocumentKind.word => 'Word document',
        DocumentKind.powerpoint => 'PowerPoint presentation',
        DocumentKind.excel => 'Excel spreadsheet',
      };

  String get shortLabel => switch (this) {
        DocumentKind.pdf => 'PDF',
        DocumentKind.word => 'Word',
        DocumentKind.powerpoint => 'PowerPoint',
        DocumentKind.excel => 'Excel',
      };

  String get extension => switch (this) {
        DocumentKind.pdf => 'pdf',
        DocumentKind.word => 'docx',
        DocumentKind.powerpoint => 'pptx',
        DocumentKind.excel => 'xlsx',
      };

  String get mimeType => switch (this) {
        DocumentKind.pdf => 'application/pdf',
        DocumentKind.word =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        DocumentKind.powerpoint =>
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        DocumentKind.excel =>
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      };
}

class DocumentFactory {
  const DocumentFactory._();

  static String initialContent(DocumentKind kind) => switch (kind) {
        DocumentKind.pdf => 'Created with Parin Office.\n\nStart writing here.',
        DocumentKind.word => 'Start writing your document here.\n\nAdd headings, paragraphs, lists and notes in the workspace.',
        DocumentKind.powerpoint => 'Add your key message here.\n\nKey point one\nKey point two\nKey point three',
        DocumentKind.excel => 'Item\tQuantity\tPrice\nDesign\t1\t0\nDevelopment\t1\t0',
      };

  static Future<Uint8List> create(
    DocumentKind kind,
    String title,
    String content, {
    String? slideTitle,
  }) async {
    final cleanTitle = title.trim().isEmpty ? 'Untitled' : title.trim();
    switch (kind) {
      case DocumentKind.pdf:
        final document = pw.Document(title: cleanTitle, author: 'Parin Office');
        document.addPage(
          pw.MultiPage(
            margin: const pw.EdgeInsets.all(52),
            build: (context) => [
              pw.Text(
                cleanTitle,
                style: pw.TextStyle(
                  fontSize: 27,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Container(
                height: 4,
                width: 76,
                color: const PdfColor(0.08, 0.34, 0.86),
              ),
              pw.SizedBox(height: 24),
              ...content.split(RegExp(r'\r?\n')).map(
                    (line) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Text(
                        line.isEmpty ? ' ' : line,
                        style: const pw.TextStyle(fontSize: 12, lineSpacing: 4),
                      ),
                    ),
                  ),
            ],
          ),
        );
        return document.save();
      case DocumentKind.word:
        return _zip(_wordPackage(cleanTitle, content));
      case DocumentKind.powerpoint:
        return _zip(_powerPointPackage(
          cleanTitle,
          slideTitle?.trim().isNotEmpty == true ? slideTitle!.trim() : cleanTitle,
          content,
        ));
      case DocumentKind.excel:
        return _zip(_excelPackage(cleanTitle, content));
    }
  }

  static Uint8List _zip(Map<String, String> files) {
    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(ArchiveFile.string(entry.key, entry.value));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static String _xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static Map<String, String> _wordPackage(String title, String content) {
    final paragraphs = <String>[
      '<w:p><w:pPr><w:pStyle w:val="Title"/></w:pPr><w:r><w:t xml:space="preserve">' +
          _xml(title) +
          '</w:t></w:r></w:p>',
      ...content.split(RegExp(r'\r?\n')).map(
            (line) =>
                '<w:p><w:r><w:t xml:space="preserve">' +
                _xml(line.isEmpty ? ' ' : line) +
                '</w:t></w:r></w:p>',
          ),
    ].join();
    return {
      '[Content_Types].xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
 <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
 <Default Extension="xml" ContentType="application/xml"/>
 <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
 <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''',
      '_rels/.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''',
      'word/document.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
 <w:body>''' +
          paragraphs +
          '''<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/></w:sectPr>
 </w:body>
</w:document>''',
      'word/_rels/document.xml.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''',
      'word/styles.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
 <w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Aptos" w:hAnsi="Aptos"/><w:sz w:val="22"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="300" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>
 <w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>
 <w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:rPr><w:b/><w:sz w:val="36"/><w:color w:val="1557D7"/></w:rPr></w:style>
</w:styles>''',
    };
  }

  static String _pptTextParagraph(String text, {int size = 1800, bool bold = false}) {
    return '<a:p><a:r><a:rPr lang="en-US" sz="' +
        size.toString() +
        '"' +
        (bold ? ' b="1"' : '') +
        '><a:solidFill><a:srgbClr val="18243A"/></a:solidFill><a:latin typeface="Aptos"/></a:rPr><a:t xml:space="preserve">' +
        _xml(text.isEmpty ? ' ' : text) +
        '</a:t></a:r><a:endParaRPr lang="en-US" sz="' +
        size.toString() +
        '"/></a:p>';
  }

  static String _pptShape({
    required int id,
    required String name,
    required int x,
    required int y,
    required int cx,
    required int cy,
    required String paragraphs,
  }) {
    return '<p:sp><p:nvSpPr><p:cNvPr id="' +
        id.toString() +
        '" name="' +
        _xml(name) +
        '"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="' +
        x.toString() +
        '" y="' +
        y.toString() +
        '"/><a:ext cx="' +
        cx.toString() +
        '" cy="' +
        cy.toString() +
        '"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr wrap="square" lIns="0" rIns="0" tIns="0" bIns="0"/><a:lstStyle/>' +
        paragraphs +
        '</p:txBody></p:sp>';
  }

  static Map<String, String> _powerPointPackage(
    String presentationName,
    String slideTitle,
    String content,
  ) {
    final titleShape = _pptShape(
      id: 2,
      name: 'Title',
      x: 914400,
      y: 850000,
      cx: 10000000,
      cy: 1150000,
      paragraphs: _pptTextParagraph(slideTitle, size: 3000, bold: true),
    );
    final bodyParagraphs = content
        .split(RegExp(r'\r?\n'))
        .map((line) => _pptTextParagraph(line, size: 1900))
        .join();
    final bodyShape = _pptShape(
      id: 3,
      name: 'Content',
      x: 1000000,
      y: 2500000,
      cx: 9800000,
      cy: 3800000,
      paragraphs: bodyParagraphs,
    );
    return {
      '[Content_Types].xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
 <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
 <Default Extension="xml" ContentType="application/xml"/>
 <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
 <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
 <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
 <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
 <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
</Types>''',
      '_rels/.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''',
      'ppt/presentation.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
 <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>
 <p:sldIdLst><p:sldId id="256" r:id="rId2"/></p:sldIdLst>
 <p:sldSz cx="12192000" cy="6858000" type="screen16x9"/><p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>''',
      'ppt/_rels/presentation.xml.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
 <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
</Relationships>''',
      'ppt/slides/slide1.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
 <p:cSld name="''' +
          _xml(presentationName) +
          '''"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>''' +
          titleShape +
          bodyShape +
          '''</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sld>''',
      'ppt/slides/_rels/slide1.xml.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
</Relationships>''',
      'ppt/slideLayouts/slideLayout1.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1">
 <p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sldLayout>''',
      'ppt/slideLayouts/_rels/slideLayout1.xml.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>''',
      'ppt/slideMasters/slideMaster1.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
 <p:cSld name="Parin Master"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld>
 <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
 <p:sldLayoutIdLst><p:sldLayoutId id="1" r:id="rId1"/></p:sldLayoutIdLst><p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles>
</p:sldMaster>''',
      'ppt/slideMasters/_rels/slideMaster1.xml.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
 <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
</Relationships>''',
      'ppt/theme/theme1.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Parin Office">
 <a:themeElements>
  <a:clrScheme name="Parin"><a:dk1><a:sysClr val="windowText" lastClr="18243A"/></a:dk1><a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1><a:dk2><a:srgbClr val="10182B"/></a:dk2><a:lt2><a:srgbClr val="F5F7FC"/></a:lt2><a:accent1><a:srgbClr val="1557D7"/></a:accent1><a:accent2><a:srgbClr val="12A995"/></a:accent2><a:accent3><a:srgbClr val="F59E0B"/></a:accent3><a:accent4><a:srgbClr val="DD4865"/></a:accent4><a:accent5><a:srgbClr val="7C5CFC"/></a:accent5><a:accent6><a:srgbClr val="27A7E7"/></a:accent6><a:hlink><a:srgbClr val="0563C1"/></a:hlink><a:folHlink><a:srgbClr val="954F72"/></a:folHlink></a:clrScheme>
  <a:fontScheme name="Parin"><a:majorFont><a:latin typeface="Aptos Display"/></a:majorFont><a:minorFont><a:latin typeface="Aptos"/></a:minorFont></a:fontScheme>
  <a:fmtScheme name="Parin"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme>
 </a:themeElements><a:objectDefaults/><a:extraClrSchemeLst/>
</a:theme>''',
    };
  }

  static String _columnName(int zeroBased) {
    var value = zeroBased + 1;
    var result = '';
    while (value > 0) {
      final remainder = (value - 1) % 26;
      result = String.fromCharCode(65 + remainder) + result;
      value = (value - 1) ~/ 26;
    }
    return result;
  }

  static Map<String, String> _excelPackage(String title, String content) {
    final rows = content
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.split('\t'))
        .toList();
    if (rows.isEmpty) rows.add([title]);
    final maxColumns = rows.map((row) => row.length).fold<int>(1, (a, b) => a > b ? a : b);
    final sheetRows = <String>[];
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final cells = <String>[];
      for (var colIndex = 0; colIndex < rows[rowIndex].length; colIndex++) {
        final cell = rows[rowIndex][colIndex];
        final ref = _columnName(colIndex) + (rowIndex + 1).toString();
        final numeric = double.tryParse(cell.trim());
        if (numeric != null && cell.trim().isNotEmpty) {
          cells.add('<c r="' + ref + '"><v>' + cell.trim() + '</v></c>');
        } else {
          cells.add('<c r="' + ref + '" t="inlineStr"><is><t xml:space="preserve">' +
              _xml(cell) +
              '</t></is></c>');
        }
      }
      sheetRows.add('<row r="' + (rowIndex + 1).toString() + '">' + cells.join() + '</row>');
    }
    final lastCell = _columnName(maxColumns - 1) + rows.length.toString();
    return {
      '[Content_Types].xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
 <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
 <Default Extension="xml" ContentType="application/xml"/>
 <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
 <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>''',
      '_rels/.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''',
      'xl/workbook.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="''' +
          _xml(title.length > 31 ? title.substring(0, 31) : title) +
          '''" sheetId="1" r:id="rId1"/></sheets></workbook>''',
      'xl/_rels/workbook.xml.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>''',
      'xl/worksheets/sheet1.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><dimension ref="A1:''' +
          lastCell +
          '''"/><sheetViews><sheetView workbookViewId="0"/></sheetViews><sheetFormatPr defaultRowHeight="18"/><sheetData>''' +
          sheetRows.join() +
          '''</sheetData></worksheet>''',
    };
  }
}
