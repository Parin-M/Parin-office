package com.parin.office.core.layout

data class Size(val width: Float, val height: Float)
data class Point(val x: Float, val y: Float)
data class Rect(val left: Float, val top: Float, val right: Float, val bottom: Float) {
    val width get() = right-left
    val height get() = bottom-top
}
data class Insets(val left:Float=0f,val top:Float=0f,val right:Float=0f,val bottom:Float=0f)

enum class HorizontalAlign { LEFT, CENTER, RIGHT, JUSTIFY }
enum class VerticalAlign { TOP, CENTER, BOTTOM }

data class TextStyle(
    val fontFamily:String="Sans",
    val fontSize:Float=12f,
    val bold:Boolean=false,
    val italic:Boolean=false,
    val underline:Boolean=false,
    val strike:Boolean=false,
    val color:Long=0xFF111827,
    val letterSpacing:Float=0f,
    val lineSpacing:Float=1.15f
)

data class LayoutBlock(
    val id:String,
    val bounds:Rect,
    val text:String="",
    val style:TextStyle=TextStyle(),
    val horizontalAlign:HorizontalAlign=HorizontalAlign.LEFT,
    val verticalAlign:VerticalAlign=VerticalAlign.TOP
)

data class Page(
    val index:Int,
    val size:Size,
    val margins:Insets=Insets(54f,54f,54f,54f),
    val blocks:List<LayoutBlock> = emptyList()
)

class PaginationEngine {
    fun paginate(
        blocks:List<LayoutBlock>,
        pageSize:Size,
        margins:Insets
    ):List<Page>{
        val pages=mutableListOf<Page>()
        val usableWidth=(pageSize.width-margins.left-margins.right).coerceAtLeast(1f)
        val usableHeight=(pageSize.height-margins.top-margins.bottom).coerceAtLeast(1f)
        var current=mutableListOf<LayoutBlock>()
        var y=margins.top
        fun flush(){
            pages+=Page(pages.size,pageSize,margins,current.toList())
            current=mutableListOf()
            y=margins.top
        }
        for(block in blocks){
            val height=block.bounds.height.coerceAtLeast(block.style.fontSize*1.2f)
            if(height>usableHeight){ continue }
            if(y+height>margins.top+usableHeight && current.isNotEmpty()) flush()
            val width=block.bounds.width.coerceAtMost(usableWidth)
            current+=block.copy(bounds=Rect(margins.left,y,margins.left+width,y+height))
            y+=height
        }
        if(current.isNotEmpty()||pages.isEmpty()) flush()
        return pages
    }
}
