package com.parin.office.office.word

import com.parin.office.core.layout.TextStyle

data class WordRun(
    val id:String,
    val text:String,
    val style:TextStyle=TextStyle()
)

data class WordParagraph(
    val id:String,
    val runs:List<WordRun>,
    val styleName:String="Normal",
    val keepWithNext:Boolean=false,
    val pageBreakBefore:Boolean=false
)

data class WordSection(
    val pageWidth:Float=612f,
    val pageHeight:Float=792f,
    val marginLeft:Float=54f,
    val marginTop:Float=54f,
    val marginRight:Float=54f,
    val marginBottom:Float=54f
)

data class WordDocumentModel(
    val sections:List<WordSection> = listOf(WordSection()),
    val paragraphs:List<WordParagraph> = emptyList()
)
