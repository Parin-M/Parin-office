package com.parin.office.data
import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import com.parin.office.model.*
import java.io.File
import java.io.FileOutputStream
object Files{
 fun name(c:Context,u:Uri)=runCatching{c.contentResolver.query(u,arrayOf(OpenableColumns.DISPLAY_NAME),null,null,null)?.use{q->if(q.moveToFirst())q.getString(0)else null}}.getOrNull()?:"document"
 fun kind(n:String,m:String?)=when{n.endsWith(".pdf",true)||m=="application/pdf"->DocumentKind.PDF;n.endsWith(".docx",true)->DocumentKind.DOCX;n.endsWith(".pptx",true)->DocumentKind.PPTX;n.endsWith(".xlsx",true)->DocumentKind.XLSX;else->DocumentKind.UNSUPPORTED}
 fun persist(c:Context,u:Uri){runCatching{c.contentResolver.takePersistableUriPermission(u,android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION or android.content.Intent.FLAG_GRANT_WRITE_URI_PERMISSION)}}
 fun cache(c:Context,u:Uri,h:String):File{val d=File(c.cacheDir,"docs").apply{mkdirs()};val f=File(d,System.currentTimeMillis().toString()+"_"+h.replace(Regex("[^A-Za-z0-9._-]"),"_"));c.contentResolver.openInputStream(u).use{input->requireNotNull(input);FileOutputStream(f).use{output->input!!.copyTo(output)}};return f}
 fun recent(c:Context)=c.getSharedPreferences("recent",0).getStringSet("docs",emptySet()).orEmpty().mapNotNull{p->val x=p.split("|",limit=3);if(x.size!=3)null else runCatching{RecentDocument(Uri.parse(x[0]),x[1],DocumentKind.valueOf(x[2]))}.getOrNull()}.take(12)
 fun remember(c:Context,u:Uri,n:String,k:DocumentKind){val p=c.getSharedPreferences("recent",0);val s=p.getStringSet("docs",emptySet()).orEmpty().toMutableList();s.removeAll{it.startsWith(u.toString()+"|")};s.add(0,u.toString()+"|"+n.replace("|"," ")+"|"+k.name);p.edit().putStringSet("docs",s.take(12).toSet()).apply()}
}
