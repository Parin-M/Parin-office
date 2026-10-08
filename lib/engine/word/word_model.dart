class WordRunModel {
  const WordRunModel({required this.text,this.bold=false,this.italic=false,this.underline=false,this.fontSize=12});
  final String text; final bool bold,italic,underline; final double fontSize;
}
class WordParagraphModel {
  const WordParagraphModel({required this.runs,this.styleName='Normal',this.pageBreakBefore=false,this.keepWithNext=false});
  final List<WordRunModel> runs; final String styleName; final bool pageBreakBefore,keepWithNext;
}
class WordSectionModel {
  const WordSectionModel({this.pageWidth=612,this.pageHeight=792,this.marginLeft=54,this.marginTop=54,this.marginRight=54,this.marginBottom=54});
  final double pageWidth,pageHeight,marginLeft,marginTop,marginRight,marginBottom;
}
