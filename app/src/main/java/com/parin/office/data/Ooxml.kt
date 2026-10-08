package com.parin.office.data
import android.content.Context
import android.net.Uri
import com.parin.office.model.*
import org.w3c.dom.Document
import org.w3c.dom.Element
import org.w3c.dom.Node
import java.io.ByteArrayInputStream
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream
import javax.xml.XMLConstants
import javax.xml.parsers.DocumentBuilderFactory
import javax.xml.transform.OutputKeys
import javax.xml.transform.TransformerFactory
import javax.xml.transform.dom.DOMSource
import javax.xml.transform.stream.StreamResult
object Ooxml{
 private fun factory()=DocumentBuilderFactory.newInstance().apply{isNamespaceAware=true;setFeature(XMLConstants.FEATURE_SECURE_PROCESSING,true);runCatching{setFeature("http://apache.org/xml/features/disallow-doctype-decl",true)};runCatching{setFeature("http://xml.org/sax/features/external-general-entities",false)};runCatching{setFeature("http://xml.org/sax/features/external-parameter-entities",false)};setXIncludeAware(false);isExpandEntityReferences=false}
 private fun parse(b:ByteArray):Document=factory().newDocumentBuilder().parse(ByteArrayInputStream(b))
 private fun all(d:Document,l:String):List<Element>{val r=mutableListOf<Element>();val n=d.getElementsByTagName("*");for(i in 0 until n.length){val e=n.item(i) as? Element?:continue;if(e.localName==l||e.nodeName.endsWith(":$l"))r+=e};return r}
 private fun deep(n:Node,l:String):List<Element>{val r=mutableListOf<Element>();val c=n.childNodes;for(i in 0 until c.length){val x=c.item(i);if(x.nodeType==Node.ELEMENT_NODE){val e=x as Element;if(e.localName==l||e.nodeName.endsWith(":$l"))r+=e;r+=deep(x,l)}};return r}
 private fun serial(d:Document):ByteArray{val t=TransformerFactory.newInstance().newTransformer().apply{setOutputProperty(OutputKeys.ENCODING,"UTF-8")};return java.io.ByteArrayOutputStream().use{o->t.transform(DOMSource(d),StreamResult(o));o.toByteArray()}}
 fun load(c:Context,u:Uri,n:String)=loadFile(Files.cache(c,u,n),n)
 fun loadFile(f:File,n:String):OfficeDoc=when{
  n.endsWith(".docx",true)->ZipFile(f).use{z->val e=z.getEntry("word/document.xml")?:return@use OfficeDoc(DocumentKind.DOCX,n);val d=parse(z.getInputStream(e).readBytes());OfficeDoc(DocumentKind.DOCX,n,text=all(d,"p").joinToString("\n"){p->deep(p,"t").joinToString(""){it.textContent?:""}})}
  n.endsWith(".pptx",true)->ZipFile(f).use{z->val ns=z.entries().asSequence().map{it.name}.filter{it.matches(Regex("ppt/slides/slide[0-9]+\\.xml"))}.sortedBy{it.substringAfter("slide").substringBefore(".xml").toInt()};OfficeDoc(DocumentKind.PPTX,n,slides=ns.map{p->val d=parse(z.getInputStream(z.getEntry(p)).readBytes());deep(d,"t").joinToString("\n"){it.textContent?:""}})}
  n.endsWith(".xlsx",true)->ZipFile(f).use{z->val shared=z.getEntry("xl/sharedStrings.xml")?.let{e->val d=parse(z.getInputStream(e).readBytes());all(d,"si").map{deep(it,"t").joinToString(""){x->x.textContent?:""}}}?:emptyList();val e=z.getEntry("xl/worksheets/sheet1.xml")?:return@use OfficeDoc(DocumentKind.XLSX,n);val d=parse(z.getInputStream(e).readBytes());OfficeDoc(DocumentKind.XLSX,n,cells=all(d,"c").mapNotNull{cell->val ref=cell.getAttribute("r").takeIf{it.isNotBlank()}?:return@mapNotNull null;val raw=deep(cell,"v").firstOrNull()?.textContent.orEmpty();val v=when(cell.getAttribute("t")){"s"->shared.getOrNull(raw.toIntOrNull()?:-1).orEmpty();"inlineStr"->deep(cell,"t").joinToString(""){x->x.textContent?:""};else->raw};XCell(ref,v)}.take(400))}
  else->OfficeDoc(DocumentKind.UNSUPPORTED,n)
 }
 fun save(c:Context,u:Uri,d:OfficeDoc,f:Format){val src=Files.cache(c,u,d.name);val out=File.createTempFile("parin-","-out",c.cacheDir);when(d.kind){DocumentKind.DOCX->rewrite(src,out){p,b->if(p=="word/document.xml")docx(b,d.text,f)else b};DocumentKind.PPTX->{var i=0;rewrite(src,out){p,b->if(p.matches(Regex("ppt/slides/slide[0-9]+\\.xml"))){val x=d.slides.getOrNull(i++).orEmpty();pptx(b,x.split("\n"),f)}else b}};DocumentKind.XLSX->{val m=d.cells.associateBy{it.ref};rewrite(src,out){p,b->if(p=="xl/worksheets/sheet1.xml")xlsx(b,m)else b}};else->return};c.contentResolver.openOutputStream(u,"wt").use{target->requireNotNull(target);out.inputStream().use{it.copyTo(target!!)}};src.delete();out.delete()}
 private fun docx(b:ByteArray,text:String,f:Format):ByteArray{val d=parse(b);val lines=text.split("\n");all(d,"p").forEachIndexed{i,p->val ts=deep(p,"t");ts.forEachIndexed{j,t->t.textContent=if(j==0)lines.getOrNull(i).orEmpty()else""}};all(d,"r").forEach{r->var rp=deep(r,"rPr").firstOrNull();if(rp==null){rp=d.createElementNS("http://schemas.openxmlformats.org/wordprocessingml/2006/main","w:rPr");r.insertBefore(rp,r.firstChild)};toggle(d,rp,"b",f.bold);toggle(d,rp,"i",f.italic);toggle(d,rp,"u",f.underline)};return serial(d)}
 private fun toggle(d:Document,p:Element,t:String,on:Boolean){deep(p,t).forEach{p.removeChild(it)};if(on)p.appendChild(d.createElementNS("http://schemas.openxmlformats.org/wordprocessingml/2006/main","w:$t"))}
 private fun pptx(b:ByteArray,lines:List<String>,f:Format):ByteArray{val d=parse(b);all(d,"t").forEachIndexed{i,e->e.textContent=lines.getOrNull(i).orEmpty()};all(d,"rPr").forEach{r->if(f.bold)r.setAttribute("b","1")else r.removeAttribute("b");if(f.italic)r.setAttribute("i","1")else r.removeAttribute("i");if(f.underline)r.setAttribute("u","sng")else r.removeAttribute("u")};return serial(d)}
 private fun xlsx(b:ByteArray,m:Map<String,XCell>):ByteArray{val d=parse(b);all(d,"c").forEach{c->val v=m[c.getAttribute("r")]?.value?:return@forEach;while(c.firstChild!=null)c.removeChild(c.firstChild);c.setAttribute("t","inlineStr");val isN=d.createElement("is");val t=d.createElement("t");t.textContent=v;isN.appendChild(t);c.appendChild(isN)};return serial(d)}
 private fun rewrite(src:File,out:File,repl:(String,ByteArray)->ByteArray){ZipFile(src).use{z->ZipOutputStream(out.outputStream().buffered()).use{o->z.entries().asSequence().forEach{e->o.putNextEntry(ZipEntry(e.name));z.getInputStream(e).use{i->o.write(repl(e.name,i.readBytes()))};o.closeEntry()}}}}
}
