package com.parin.office.model
import android.graphics.Color
import android.net.Uri
enum class DocumentKind{PDF,DOCX,PPTX,XLSX,UNSUPPORTED}
enum class PdfTool{PEN,TEXT,FREE_HIGHLIGHT,TEXT_HIGHLIGHT,ERASER}
enum class EraserTarget{ANY,PEN,TEXT,HIGHLIGHT}
data class RecentDocument(val uri:Uri,val name:String,val kind:DocumentKind)
data class P(val x:Float,val y:Float)
data class R(val l:Float,val t:Float,val r:Float,val b:Float){fun hit(p:P)=p.x in l..r&&p.y in t..b}
sealed class Annotation(open val page:Int){
 data class Pen(override val page:Int,val points:List<P>,val color:Int=Color.rgb(25,35,60),val width:Float=3f):Annotation(page)
 data class Text(override val page:Int,val rect:R,val value:String,val color:Int=Color.rgb(25,35,60),val size:Float=20f):Annotation(page)
 data class Highlight(override val page:Int,val rects:List<R>,val color:Int=Color.argb(110,255,220,55)):Annotation(page)
}
data class XCell(val ref:String,val value:String)
data class OfficeDoc(val kind:DocumentKind,val name:String,val text:String="",val slides:List<String> = emptyList(),val cells:List<XCell> = emptyList())
data class Format(val bold:Boolean=false,val italic:Boolean=false,val underline:Boolean=false,val size:Int=12)
