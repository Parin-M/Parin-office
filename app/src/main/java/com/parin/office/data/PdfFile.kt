package com.parin.office.data
import android.content.Context
import android.graphics.*
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import com.parin.office.model.Annotation
class PdfFile(private val c:Context,private val u:Uri,private val n:String){
 private val file=Files.cache(c,u,n);private var renderer:PdfRenderer?=null
 fun open(){if(renderer==null)renderer=PdfRenderer(android.os.ParcelFileDescriptor.open(file,android.os.ParcelFileDescriptor.MODE_READ_ONLY))}
 fun count()=requireNotNull(renderer).pageCount
 fun render(index:Int,scale:Float):Bitmap{val p=requireNotNull(renderer).openPage(index);val s=scale.coerceIn(.75f,2.5f);val b=Bitmap.createBitmap((p.width*s).toInt(),(p.height*s).toInt(),Bitmap.Config.ARGB_8888);p.render(b,null,Matrix().apply{setScale(s,s)},PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY);p.close();return b}
 fun export(target:Uri,a:List<Annotation>){val r=PdfRenderer(android.os.ParcelFileDescriptor.open(file,android.os.ParcelFileDescriptor.MODE_READ_ONLY));val out=android.graphics.pdf.PdfDocument();try{for(i in 0 until r.pageCount){val src=r.openPage(i);val s=2f;val b=Bitmap.createBitmap((src.width*s).toInt(),(src.height*s).toInt(),Bitmap.Config.ARGB_8888);src.render(b,null,Matrix().apply{setScale(s,s)},PdfRenderer.Page.RENDER_MODE_FOR_PRINT);src.close();val info=android.graphics.pdf.PdfDocument.PageInfo.Builder(b.width,b.height,i+1).create();val page=out.startPage(info);page.canvas.drawBitmap(b,0f,0f,null);draw(page.canvas,b.width.toFloat(),b.height.toFloat(),a.filter{it.page==i});out.finishPage(page);b.recycle()};c.contentResolver.openOutputStream(target).use{requireNotNull(it);out.writeTo(it!!)}}finally{out.close();r.close()}}
 private fun draw(c:Canvas,w:Float,h:Float,a:List<Annotation>){a.forEach{when(it){is Annotation.Pen->{if(it.points.size>1){val p=Path();it.points.forEachIndexed{idx,q->if(idx==0)p.moveTo(q.x*w,q.y*h)else p.lineTo(q.x*w,q.y*h)};c.drawPath(p,Paint(3).apply{color=it.color;style=Paint.Style.STROKE;strokeWidth=it.width*2;strokeCap=Paint.Cap.ROUND})}};is Annotation.Text->c.drawText(it.value,it.rect.l*w,it.rect.b*h,Paint(3).apply{color=it.color;textSize=it.size});is Annotation.Highlight->{val p=Paint(3).apply{color=it.color;style=Paint.Style.FILL};it.rects.forEach{x->c.drawRect(x.l*w,x.t*h,x.r*w,x.b*h,p)}}}}}
 fun close(){renderer?.close();renderer=null;file.delete()}
}
