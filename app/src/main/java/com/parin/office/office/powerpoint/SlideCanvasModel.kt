package com.parin.office.office.powerpoint

import com.parin.office.core.layout.Point
import com.parin.office.core.layout.Rect
import com.parin.office.core.layout.Size

enum class ShapeType { TEXT, RECTANGLE, ELLIPSE, LINE, IMAGE, GROUP, TABLE, CHART }

data class SlideObject(
    val id:String,
    val type:ShapeType,
    val bounds:Rect,
    val rotation:Float=0f,
    val zIndex:Int=0,
    val text:String="",
    val locked:Boolean=false
)

data class Slide(
    val index:Int,
    val size:Size=Size(1280f,720f),
    val objects:List<SlideObject> = emptyList()
)

data class SelectionBox(val bounds:Rect,val handles:Boolean=true)

class SlideCanvasModel{
    fun move(slide:Slide,id:String,delta:Point):Slide=
        slide.copy(objects=slide.objects.map{if(it.id==id&&!it.locked)it.copy(bounds=it.bounds.translate(delta))else it})
    fun resize(slide:Slide,id:String,width:Float,height:Float):Slide=
        slide.copy(objects=slide.objects.map{if(it.id==id&&!it.locked)it.copy(bounds=it.bounds.copy(right=it.bounds.left+width,bottom=it.bounds.top+height))else it})
    private fun Rect.translate(p:Point)=copy(left=left+p.x,top=top+p.y,right=right+p.x,bottom=bottom+p.y)
}
