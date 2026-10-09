import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

class PresentationSlideDraft {
  PresentationSlideDraft({required this.title, required this.body, this.backgroundHex='FFFFFF', this.layout='Title and content'});
  String title;
  String body;
  String backgroundHex;
  String layout;
  PresentationSlideDraft copy() => PresentationSlideDraft(title:title, body:body, backgroundHex:backgroundHex, layout:layout);
}

class OfficeEditorCodec {
  static String xmlEscape(String value) => value.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'",'&apos;');
  static String xmlUnescape(String value) => value.replaceAll('&lt;','<').replaceAll('&gt;','>').replaceAll('&quot;','"').replaceAll('&apos;',"'").replaceAll('&amp;','&');

  static String _entryText(Archive archive, String path) {
    for (final file in archive.files) {
      if (file.name == path && file.isFile) return utf8.decode(file.content as List<int>,allowMalformed:true);
    }
    return '';
  }

  static String extractWordText(Uint8List bytes) {
    try {
      final archive=ZipDecoder().decodeBytes(bytes);
      final xml=_entryText(archive,'word/document.xml');
      final paragraphs=<String>[];
      for(final match in RegExp(r'<w:p\b[\s\S]*?</w:p>').allMatches(xml)) {
        final runs=<String>[];
        for(final text in RegExp(r'<w:t\b[^>]*>([\s\S]*?)</w:t>').allMatches(match.group(0)!)) {
          runs.add(xmlUnescape(text.group(1)??''));
        }
        if(runs.isNotEmpty) paragraphs.add(runs.join());
      }
      return paragraphs.join('\n').trimRight();
    } catch (_) { return ''; }
  }

  static List<PresentationSlideDraft> extractPresentation(Uint8List bytes) {
    try {
      final archive=ZipDecoder().decodeBytes(bytes);
      final entries=archive.files.where((f)=>f.isFile && RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(f.name)).toList()
        ..sort((a,b) {
          int number(String path)=>int.tryParse(RegExp(r'slide(\d+)\.xml$').firstMatch(path)?.group(1)??'')??0;
          return number(a.name).compareTo(number(b.name));
        });
      final slides=<PresentationSlideDraft>[];
      for(var i=0;i<entries.length;i++) {
        final xml=utf8.decode(entries[i].content as List<int>,allowMalformed:true);
        final text=RegExp(r'<a:t\b[^>]*>([\s\S]*?)</a:t>').allMatches(xml).map((m)=>xmlUnescape(m.group(1)??'')).toList();
        slides.add(PresentationSlideDraft(title:text.isEmpty || text.first.trim().isEmpty?'Slide ${i+1}':text.first,body:text.length<2?'':text.skip(1).join('\n')));
      }
      if(slides.isNotEmpty) return slides;
    } catch (_) {}
    return <PresentationSlideDraft>[PresentationSlideDraft(title:'Presentation title',body:'Add your key points here.')];
  }

  static Uint8List createWordFromDelta({required List<dynamic> delta, required String pageSize, required bool landscape, required String margins}) {
    final paragraphs=<_WordParagraph>[_WordParagraph()];
    for(final raw in delta) {
      if(raw is! Map || raw['insert'] is! String) continue;
      final text=raw['insert'] as String;
      final attributes=raw['attributes'] is Map ? Map<String,dynamic>.from(raw['attributes'] as Map) : <String,dynamic>{};
      final lines=text.split('\n');
      for(var i=0;i<lines.length;i++) {
        if(lines[i].isNotEmpty) paragraphs.last.runs.add(_WordRun(lines[i],attributes));
        if(i<lines.length-1) {paragraphs.last.attributes=attributes;paragraphs.add(_WordParagraph());}
      }
    }
    final paper=switch(pageSize){'Letter'=>(w:12240,h:15840),'A5'=>(w:8391,h:11906),_=>(w:11906,h:16838)};
    final width=landscape?paper.h:paper.w;
    final height=landscape?paper.w:paper.h;
    final margin=switch(margins){'Narrow'=>720,'Wide'=>1800,_=>1440};
    final body=paragraphs.map(_paragraphXml).join();
    final document='<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body>'
        '$body'
        '<w:sectPr><w:pgSz w:w="$width" w:h="$height"${landscape?' w:orient="landscape"':''}/>'
        '<w:pgMar w:top="$margin" w:right="$margin" w:bottom="$margin" w:left="$margin" w:header="708" w:footer="708" w:gutter="0"/></w:sectPr></w:body></w:document>';
    const types='<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/></Types>';
    const rootRels='<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>';
    const documentRels='<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rIdNum" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/></Relationships>';
    const numbering='<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="singleLevel"/><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/><w:lvlJc w:val="left"/></w:lvl></w:abstractNum><w:abstractNum w:abstractNumId="1"><w:multiLevelType w:val="singleLevel"/><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/></w:lvl></w:abstractNum><w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num><w:num w:numId="2"><w:abstractNumId w:val="1"/></w:num></w:numbering>';
    final files=<String,List<int>>{
      '[Content_Types].xml':utf8.encode(types),'_rels/.rels':utf8.encode(rootRels),
      'word/document.xml':utf8.encode(document),'word/_rels/document.xml.rels':utf8.encode(documentRels),'word/numbering.xml':utf8.encode(numbering),
    };
    return _zip(files);
  }

  static String _paragraphXml(_WordParagraph p) {
    final attrs=p.attributes;
    final props=<String>[];
    final align=attrs['align'];
    if(align=='center'||align=='right'||align=='justify') {
      final value=align=='center'?'center':align=='right'?'right':'both';
      props.add('<w:jc w:val="$value"/>');
    }
    final header=attrs['header'];
    if(header is num && header>=1 && header<=3) props.add('<w:pStyle w:val="Heading${header.toInt()}"/>');
    final list=attrs['list'];
    if(list=='bullet'||list=='ordered') {
      final numId=list=='bullet'?1:2;
      props.add('<w:numPr><w:ilvl w:val="0"/><w:numId w:val="$numId"/></w:numPr>');
    }
    if(attrs['blockquote']==true) props.add('<w:ind w:left="480"/>');
    final pPr=props.isEmpty?'':'<w:pPr>${props.join()}</w:pPr>';
    final runs=p.runs.map(_runXml).join();
    return '<w:p>$pPr${runs.isEmpty?'<w:r><w:t></w:t></w:r>':runs}</w:p>';
  }

  static String _runXml(_WordRun run) {
    final attrs=run.attributes;
    final props=<String>[];
    if(attrs['bold']==true) props.add('<w:b/>');
    if(attrs['italic']==true) props.add('<w:i/>');
    if(attrs['underline']==true) props.add('<w:u w:val="single"/>');
    if(attrs['strike']==true) props.add('<w:strike/>');
    final color=_hexColor(attrs['color']?.toString());
    if(color!=null) props.add('<w:color w:val="$color"/>');
    final background=_hexColor(attrs['background']?.toString());
    if(background!=null) props.add('<w:shd w:val="clear" w:color="auto" w:fill="$background"/>');
    final font=attrs['font']?.toString();
    if(font!=null && font.isNotEmpty) {final safe=xmlEscape(font);props.add('<w:rFonts w:ascii="$safe" w:hAnsi="$safe"/>');}
    final size=_halfPoints(attrs['size']?.toString());
    if(size!=null) props.add('<w:sz w:val="$size"/><w:szCs w:val="$size"/>');
    final rPr=props.isEmpty?'':'<w:rPr>${props.join()}</w:rPr>';
    return '<w:r>$rPr<w:t xml:space="preserve">${xmlEscape(run.text)}</w:t></w:r>';
  }

  static String? _hexColor(String? input) {
    if(input==null) return null;
    final hex=input.startsWith('#')?input.substring(1):input;
    if(RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return hex.toUpperCase();
    final rgb=RegExp(r'rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)').firstMatch(input);
    if(rgb==null) return null;
    return [1,2,3].map((i)=>int.parse(rgb.group(i)!).clamp(0,255).toRadixString(16).padLeft(2,'0')).join().toUpperCase();
  }
  static int? _halfPoints(String? size) {
    if(size==null) return null;
    final points=switch(size.toLowerCase()){'small'=>10.0,'large'=>18.0,'huge'=>28.0,_=>double.tryParse(size.replaceAll('px','').replaceAll('pt',''))};
    if(points==null) return null;
    return ((size.toLowerCase().endsWith('px')?points*0.75:points)*2).round().clamp(8,144);
  }

  static Uint8List createPresentation({required String title, required List<PresentationSlideDraft> slides, required String accentHex}) {
    final accent=_hexColor(accentHex)??'2869F6';
    final overrides=slides.asMap().keys.map((i)=>'<Override PartName="/ppt/slides/slide${i+1}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>').join();
    final slideIds=slides.asMap().keys.map((i)=>'<p:sldId id="${256+i}" r:id="rId${i+2}"/>').join();
    final relationships=[
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>',
      ...slides.asMap().keys.map((i)=>'<Relationship Id="rId${i+2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide${i+1}.xml"/>'),
    ].join();
    const nsA='http://schemas.openxmlformats.org/drawingml/2006/main';
    const nsP='http://schemas.openxmlformats.org/presentationml/2006/main';
    const nsR='http://schemas.openxmlformats.org/officeDocument/2006/relationships';
    final files=<String,List<int>>{
      '[Content_Types].xml':utf8.encode('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/><Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/><Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/><Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml">$overrides</Types>'),
      '_rels/.rels':utf8.encode('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/></Relationships>'),
      'ppt/presentation.xml':utf8.encode('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:presentation xmlns:a="$nsA" xmlns:r="$nsR" xmlns:p="$nsP"><p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst><p:sldIdLst>$slideIds</p:sldIdLst><p:sldSz cx="12192000" cy="6858000" type="wide"/><p:notesSz cx="6858000" cy="9144000"/></p:presentation>'),
      'ppt/_rels/presentation.xml.rels':utf8.encode('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">$relationships</Relationships>'),
      'ppt/slideLayouts/slideLayout1.xml':utf8.encode('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldLayout xmlns:a="$nsA" xmlns:r="$nsR" xmlns:p="$nsP" type="blank" preserve="1"><p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>'),
      'ppt/slideLayouts/_rels/slideLayout1.xml.rels':utf8.encode('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>'),
      'ppt/slideMasters/slideMaster1.xml':utf8.encode('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldMaster xmlns:a="$nsA" xmlns:r="$nsR" xmlns:p="$nsP"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld><p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/><p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst><p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles></p:sldMaster>'),
      'ppt/slideMasters/_rels/slideMaster1.xml.rels':utf8.encode('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/></Relationships>'),
      'ppt/theme/theme1.xml':utf8.encode('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><a:theme xmlns:a="$nsA" name="Parin Office"><a:themeElements><a:clrScheme name="Parin Office"><a:dk1><a:srgbClr val="101116"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1><a:dk2><a:srgbClr val="172238"/></a:dk2><a:lt2><a:srgbClr val="F5F7FB"/></a:lt2><a:accent1><a:srgbClr val="$accent"/></a:accent1><a:accent2><a:srgbClr val="7255DE"/></a:accent2><a:accent3><a:srgbClr val="70E3D3"/></a:accent3><a:accent4><a:srgbClr val="E77F67"/></a:accent4><a:accent5><a:srgbClr val="6B8EAD"/></a:accent5><a:accent6><a:srgbClr val="B59CE2"/></a:accent6><a:hlink><a:srgbClr val="$accent"/></a:hlink><a:folHlink><a:srgbClr val="7255DE"/></a:folHlink></a:clrScheme><a:fontScheme name="Parin"><a:majorFont><a:latin typeface="Aptos"/></a:majorFont><a:minorFont><a:latin typeface="Aptos"/></a:minorFont></a:fontScheme><a:fmtScheme name="Parin"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme></a:themeElements></a:theme>'),
    };
    for(var i=0;i<slides.length;i++) {
      files['ppt/slides/slide${i+1}.xml']=utf8.encode(_slideXml(slides[i],accent,nsA,nsR,nsP));
      files['ppt/slides/_rels/slide${i+1}.xml.rels']=utf8.encode('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/></Relationships>');
    }
    files['docProps/core.xml']=utf8.encode('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>${xmlEscape(title)}</dc:title><dc:creator>Parin Office</dc:creator></cp:coreProperties>');
    return _zip(files);
  }

  static String _slideXml(PresentationSlideDraft slide,String accent,String nsA,String nsR,String nsP) {
    final titleSize = slide.layout == 'Section header' ? 4200 : 3200;
    final titleY = slide.layout == 'Section header' ? 1500000 : 700000;
    final title = slide.layout == 'Blank' ? '' : _textBox(
      id:2,name:'Title',x:914400,y:titleY,cx:10363200,cy:1300000,
      text:slide.title,fontSize:titleSize,color:accent,bold:true,
    );
    final showBody = slide.layout != 'Blank' && slide.layout != 'Title only';
    final paragraphs=slide.body.split('\n').map((line) {
      final bullet=line.trimLeft().startsWith('• ')||line.trimLeft().startsWith('- ');
      final text=bullet?line.trimLeft().substring(2):line;
      final marker=bullet?'<a:buChar char="•"/>':'<a:buNone/>';
      final indent=bullet?342900:0;
      return '<a:p><a:pPr marL="$indent">$marker</a:pPr><a:r><a:rPr lang="en-US" sz="2000"/><a:t xml:space="preserve">${xmlEscape(text)}</a:t></a:r><a:endParaRPr lang="en-US" sz="2000"/></a:p>';
    }).join();
    final body = showBody
      ? _rawTextBox(
          id:3,name:'Body',
          x:914400,
          y:slide.layout == 'Section header' ? 3400000 : 2250000,
          cx:10363200,cy:4000000,paragraphs:paragraphs,
        )
      : '';
    final bg=_hexColor(slide.backgroundHex)??'FFFFFF';
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sld xmlns:a="$nsA" xmlns:r="$nsR" xmlns:p="$nsP"><p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val="$bg"/></a:solidFill><a:effectLst/></p:bgPr></p:bg><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>$title$body</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>';
  }
  static String _textBox({required int id,required String name,required int x,required int y,required int cx,required int cy,required String text,required int fontSize,required String color,bool bold=false}) {
    final ps=text.split('\n').map((line)=>'<a:p><a:pPr algn="l"/><a:r><a:rPr lang="en-US" sz="$fontSize"${bold?' b="1"':''}><a:solidFill><a:srgbClr val="$color"/></a:solidFill></a:rPr><a:t xml:space="preserve">${xmlEscape(line)}</a:t></a:r><a:endParaRPr lang="en-US" sz="$fontSize"/></a:p>').join();
    return _rawTextBox(id:id,name:name,x:x,y:y,cx:cx,cy:cy,paragraphs:ps);
  }

  static String _rawTextBox({required int id,required String name,required int x,required int y,required int cx,required int cy,required String paragraphs}) =>
      '<p:sp><p:nvSpPr><p:cNvPr id="$id" name="${xmlEscape(name)}"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="$x" y="$y"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr wrap="square" anchor="t"/><a:lstStyle/>$paragraphs</p:txBody></p:sp>';

  static Uint8List _zip(Map<String,List<int>> entries) {
    final archive=Archive();
    for(final entry in entries.entries) archive.addFile(ArchiveFile(entry.key,entry.value.length,entry.value));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }
}

class _WordParagraph {
  final List<_WordRun> runs=< _WordRun>[];
  Map<String,dynamic> attributes=<String,dynamic>{};
}
class _WordRun {
  const _WordRun(this.text,this.attributes);
  final String text;
  final Map<String,dynamic> attributes;
}
