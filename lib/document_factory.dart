import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

enum OfficeKind { pdf, word, powerpoint, excel }

extension OfficeKindDetails on OfficeKind {
  String get label => switch (this) {
    OfficeKind.pdf => 'PDF',
    OfficeKind.word => 'Word',
    OfficeKind.powerpoint => 'PowerPoint',
    OfficeKind.excel => 'Excel',
  };
  String get extension => switch (this) {
    OfficeKind.pdf => 'pdf',
    OfficeKind.word => 'docx',
    OfficeKind.powerpoint => 'pptx',
    OfficeKind.excel => 'xlsx',
  };
  String get mimeType => switch (this) {
    OfficeKind.pdf => 'application/pdf',
    OfficeKind.word => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    OfficeKind.powerpoint => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    OfficeKind.excel => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  };
  String get description => switch (this) {
    OfficeKind.pdf => 'Create a portable document',
    OfficeKind.word => 'Write and format your ideas',
    OfficeKind.powerpoint => 'Create a title slide and outline',
    OfficeKind.excel => 'Create a starter worksheet',
  };
  IconData get icon => switch (this) {
    OfficeKind.pdf => Icons.picture_as_pdf_rounded,
    OfficeKind.word => Icons.article_rounded,
    OfficeKind.powerpoint => Icons.slideshow_rounded,
    OfficeKind.excel => Icons.grid_on_rounded,
  };
  Color get color => switch (this) {
    OfficeKind.pdf => const Color(0xFFE64B5F),
    OfficeKind.word => const Color(0xFF2878D8),
    OfficeKind.powerpoint => const Color(0xFFF57A22),
    OfficeKind.excel => const Color(0xFF159D6B),
  };
}

class OfficeDocumentFactory {
  static Future<Uint8List> create({
    required OfficeKind kind,
    required String title,
    required String body,
    required String subtitle,
  }) async {
    switch (kind) {
      case OfficeKind.pdf:
        final document = pw.Document();
        document.addPage(pw.MultiPage(
          pageFormat: pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(48),
          build: (_) => [
            pw.Header(
              level: 0,
              child: pw.Text(title, style: pw.TextStyle(fontSize: 23, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 12),
            pw.Text(body, style: const pw.TextStyle(fontSize: 11, lineSpacing: 4)),
            pw.SizedBox(height: 18),
            pw.Divider(),
            pw.Text('Created with Parin Office', style: const pw.TextStyle(fontSize: 9)),
          ],
        ));
        return Uint8List.fromList(await document.save());
      case OfficeKind.word:
        return _zip(_docx(title, body));
      case OfficeKind.powerpoint:
        return _zip(_pptx(title, subtitle.isEmpty ? body : subtitle));
      case OfficeKind.excel:
        return _zip(_xlsx(title, body));
    }
  }

  static String _xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static Uint8List _bytes(String value) => Uint8List.fromList(utf8.encode(value));

  static Uint8List _zip(Map<String, String> files) {
    final archive = Archive();
    for (final entry in files.entries) {
      final data = _bytes(entry.value);
      archive.addFile(ArchiveFile(entry.key, data.length, data));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static Map<String, String> _docx(String title, String body) {
    final paragraphs = <String>[
      '<w:p><w:pPr><w:pStyle w:val="Title"/></w:pPr><w:r><w:t xml:space="preserve">' + _xml(title) + '</w:t></w:r></w:p>',
      ...body.split('\n').map((line) => '<w:p><w:r><w:t xml:space="preserve">' + _xml(line) + '</w:t></w:r></w:p>'),
    ].join();
    return {
      '[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>',
      '_rels/.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>',
      'word/document.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>' + paragraphs + '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr></w:body></w:document>',
      'docProps/core.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>' + _xml(title) + '</dc:title><dc:creator>Parin Office</dc:creator></cp:coreProperties>',
    };
  }

  static Map<String, String> _xlsx(String title, String body) {
    var rows = body.split('\n').where((line) => line.trim().isNotEmpty)
        .map((line) => line.contains('\t') ? line.split('\t') : line.split(',')).toList();
    if (rows.isEmpty) rows = <List<String>>[['Item', 'Value']];
    final sheetRows = <String>[];
    for (var r = 0; r < rows.length; r++) {
      final cells = <String>[];
      for (var c = 0; c < rows[r].length; c++) {
        final col = _columnName(c + 1);
        final value = _xml(rows[r][c].trim());
        cells.add('<c r="' + col + (r + 1).toString() + '" t="inlineStr"><is><t xml:space="preserve">' + value + '</t></is></c>');
      }
      sheetRows.add('<row r="' + (r + 1).toString() + '">' + cells.join() + '</row>');
    }
    final sheetData = sheetRows.join();
    return {
      '[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
      '_rels/.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
      'docProps/core.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>' + _xml(title) + '</dc:title><dc:creator>Parin Office</dc:creator></cp:coreProperties>',
      'xl/workbook.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>',
      'xl/_rels/workbook.xml.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
      'xl/worksheets/sheet1.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>' + sheetData + '</sheetData></worksheet>',
    };
  }

  static String _columnName(int index) {
    var n = index;
    var name = '';
    while (n > 0) {
      final remainder = (n - 1) % 26;
      name = String.fromCharCode(65 + remainder) + name;
      n = (n - 1) ~/ 26;
    }
    return name;
  }

  static Map<String, String> _pptx(String title, String subtitle) {
    const nsA = 'http://schemas.openxmlformats.org/drawingml/2006/main';
    const nsP = 'http://schemas.openxmlformats.org/presentationml/2006/main';
    const nsR = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
    final safeTitle = _xml(title);
    final safeSubtitle = _xml(subtitle);
    const emptyTree = '<p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree>';
    final slide = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sld xmlns:a="' + nsA + '" xmlns:r="' + nsR + '" xmlns:p="' + nsP + '"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr><p:sp><p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="914400" y="1066800"/><a:ext cx="10058400" cy="1300000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr lang="en-US" sz="3200" b="1"><a:solidFill><a:srgbClr val="173B76"/></a:solidFill></a:rPr><a:t>' + safeTitle + '</a:t></a:r><a:endParaRPr lang="en-US"/></a:p></p:txBody></p:sp><p:sp><p:nvSpPr><p:cNvPr id="3" name="Subtitle"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="914400" y="2700000"/><a:ext cx="10058400" cy="2200000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr wrap="square"/><a:lstStyle/><a:p><a:r><a:rPr lang="en-US" sz="1900"><a:solidFill><a:srgbClr val="525C70"/></a:solidFill></a:rPr><a:t>' + safeSubtitle + '</a:t></a:r><a:endParaRPr lang="en-US"/></a:p></p:txBody></p:sp></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>';
    final theme = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><a:theme xmlns:a="' + nsA + '" name="Parin Office"><a:themeElements><a:clrScheme name="Parin"><a:dk1><a:srgbClr val="101116"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1><a:dk2><a:srgbClr val="173B76"/></a:dk2><a:lt2><a:srgbClr val="F5F7FB"/></a:lt2><a:accent1><a:srgbClr val="2869F6"/></a:accent1><a:accent2><a:srgbClr val="7255DE"/></a:accent2><a:accent3><a:srgbClr val="70E3D3"/></a:accent3><a:accent4><a:srgbClr val="E77F67"/></a:accent4><a:accent5><a:srgbClr val="6B8EAD"/></a:accent5><a:accent6><a:srgbClr val="B59CE2"/></a:accent6><a:hlink><a:srgbClr val="2869F6"/></a:hlink><a:folHlink><a:srgbClr val="7255DE"/></a:folHlink></a:clrScheme><a:fontScheme name="Parin"><a:majorFont><a:latin typeface="Aptos"/></a:majorFont><a:minorFont><a:latin typeface="Aptos"/></a:minorFont></a:fontScheme><a:fmtScheme name="Parin"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme></a:themeElements></a:theme>';
    return {
      '[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/><Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/><Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/><Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/><Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/></Types>',
      '_rels/.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/></Relationships>',
      'ppt/presentation.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:presentation xmlns:a="' + nsA + '" xmlns:r="' + nsR + '" xmlns:p="' + nsP + '"><p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst><p:sldIdLst><p:sldId id="256" r:id="rId2"/></p:sldIdLst><p:sldSz cx="12192000" cy="6858000" type="wide"/><p:notesSz cx="6858000" cy="9144000"/></p:presentation>',
      'ppt/_rels/presentation.xml.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/></Relationships>',
      'ppt/slides/slide1.xml': slide,
      'ppt/slides/_rels/slide1.xml.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/></Relationships>',
      'ppt/slideLayouts/slideLayout1.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldLayout xmlns:a="' + nsA + '" xmlns:r="' + nsR + '" xmlns:p="' + nsP + '" type="blank" preserve="1"><p:cSld name="Blank">' + emptyTree + '</p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>',
      'ppt/slideLayouts/_rels/slideLayout1.xml.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>',
      'ppt/slideMasters/slideMaster1.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldMaster xmlns:a="' + nsA + '" xmlns:r="' + nsR + '" xmlns:p="' + nsP + '"><p:cSld>' + emptyTree + '</p:cSld><p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/><p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst><p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles></p:sldMaster>',
      'ppt/slideMasters/_rels/slideMaster1.xml.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/></Relationships>',
      'ppt/theme/theme1.xml': theme,
    };
  }
}