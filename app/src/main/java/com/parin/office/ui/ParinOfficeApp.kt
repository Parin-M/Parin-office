package com.parin.office.ui

import android.graphics.Bitmap
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color as GColor
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.os.LocaleListCompat
import com.parin.office.MainActivity
import com.parin.office.data.Files
import com.parin.office.data.Ooxml
import com.parin.office.data.PdfFile
import com.parin.office.model.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private enum class Screen { HOME, PDF, OFFICE, SETTINGS }

private val locales = listOf(
    "en" to "English","fa" to "فارسی","da" to "Dansk","de" to "Deutsch","de-CH" to "Schweizerdeutsch",
    "ar" to "العربية","hi" to "हिन्दी","he" to "עברית","es" to "Español","it" to "Italiano",
    "sv" to "Svenska","fi" to "Suomi","no" to "Norsk","is" to "Íslenska","el" to "Ελληνικά","tr" to "Türkçe"
)

private val texts = mapOf(
    "en" to listOf("Open file","Recent","Settings","PDF editor","Office editor","Save","Export","Pen","Text","Free highlight","Text highlight","Eraser","Language","Light theme","Formatting"),
    "fa" to listOf("باز کردن فایل","اخیر","تنظیمات","ویرایشگر PDF","ویرایشگر آفیس","ذخیره","خروجی","مداد","متن","هایلایت آزاد","هایلایت متن","پاک‌کن","زبان","تم روشن","قالب‌بندی"),
    "da" to listOf("Åbn fil","Seneste","Indstillinger","PDF-editor","Office-editor","Gem","Eksportér","Pen","Tekst","Fri fremhævning","Tekstfremhævning","Viskelæder","Sprog","Lyst tema","Formatering"),
    "de" to listOf("Datei öffnen","Zuletzt","Einstellungen","PDF-Editor","Office-Editor","Speichern","Exportieren","Stift","Text","Freie Hervorhebung","Texthervorhebung","Radiergummi","Sprache","Helles Design","Formatierung"),
    "ar" to listOf("فتح ملف","الأخيرة","الإعدادات","محرر PDF","محرر أوفيس","حفظ","تصدير","قلم","نص","تظليل حر","تظليل النص","ممحاة","اللغة","المظهر الفاتح","التنسيق"),
    "hi" to listOf("फ़ाइल खोलें","हाल के","सेटिंग्स","PDF संपादक","Office संपादक","सहेजें","निर्यात","पेन","टेक्स्ट","मुक्त हाइलाइट","टेक्स्ट हाइलाइट","इरेज़र","भाषा","हल्का थीम","फ़ॉर्मेटिंग"),
    "he" to listOf("פתיחת קובץ","אחרונים","הגדרות","עורך PDF","עורך Office","שמירה","ייצוא","עט","טקסט","הדגשה חופשית","הדגשת טקסט","מחק","שפה","ערכת נושא בהירה","עיצוב"),
    "es" to listOf("Abrir archivo","Recientes","Ajustes","Editor PDF","Editor Office","Guardar","Exportar","Lápiz","Texto","Resaltado libre","Resaltado de texto","Borrador","Idioma","Tema claro","Formato"),
    "it" to listOf("Apri file","Recenti","Impostazioni","Editor PDF","Editor Office","Salva","Esporta","Penna","Testo","Evidenziazione libera","Evidenziazione testo","Gomma","Lingua","Tema chiaro","Formattazione"),
    "sv" to listOf("Öppna fil","Senaste","Inställningar","PDF-redigerare","Office-redigerare","Spara","Exportera","Penna","Text","Fri markering","Textmarkering","Sudd","Språk","Ljust tema","Formatering"),
    "fi" to listOf("Avaa tiedosto","Viimeisimmät","Asetukset","PDF-editori","Office-editori","Tallenna","Vie","Kynä","Teksti","Vapaa korostus","Tekstin korostus","Pyyhin","Kieli","Vaalea teema","Muotoilu"),
    "no" to listOf("Åpne fil","Nylige","Innstillinger","PDF-redigerer","Office-redigerer","Lagre","Eksporter","Penn","Tekst","Fri utheving","Tekstutheving","Viskelær","Språk","Lyst tema","Formatering"),
    "is" to listOf("Opna skrá","Nýlegar","Stillingar","PDF ritill","Office ritill","Vista","Flytja út","Penni","Texti","Frjáls áhersla","Textaáhersla","Strokleður","Tungumál","Ljóst þema","Snið"),
    "el" to listOf("Άνοιγμα αρχείου","Πρόσφατα","Ρυθμίσεις","Επεξεργαστής PDF","Επεξεργαστής Office","Αποθήκευση","Εξαγωγή","Στυλό","Κείμενο","Ελεύθερη επισήμανση","Επισήμανση κειμένου","Γόμα","Γλώσσα","Φωτεινό θέμα","Μορφοποίηση"),
    "tr" to listOf("Dosya aç","Son kullanılanlar","Ayarlar","PDF düzenleyici","Office düzenleyici","Kaydet","Dışa aktar","Kalem","Metin","Serbest vurgulama","Metin vurgulama","Silgi","Dil","Açık tema","Biçimlendirme"),
    "de-CH" to listOf("Datei öffnen","Zuletzt","Einstellungen","PDF-Editor","Office-Editor","Speichern","Exportieren","Stift","Text","Freie Hervorhebung","Texthervorhebung","Radiergummi","Sprache","Helles Design","Formatierung")
)
private fun t(i:Int):String {
    val tag = LocaleListCompat.getAdjustedDefault().get(0)?.toLanguageTag() ?: "en"
    return texts[tag]?.get(i) ?: texts[tag.substringBefore("-")]?.get(i) ?: texts.getValue("en")[i]
}

@Composable
fun ParinOfficeTheme(content:@Composable()->Unit) {
    MaterialTheme(
        colorScheme=lightColorScheme(
            primary=GColor(0xFF135DFF),secondary=GColor(0xFF18B6A4),
            background=GColor(0xFFF6F8FC),surface=GColor.White
        ),content=content
    )
}

@Composable
fun ParinOfficeApp(initialUri:Uri?) {
    val c=LocalContext.current
    val activity=c as? MainActivity
    var screen by remember {
        mutableStateOf(
            if(initialUri==null) Screen.HOME
            else if(Files.kind(Files.name(c,initialUri),null)==DocumentKind.PDF) Screen.PDF else Screen.OFFICE
        )
    }
    var uri by remember{mutableStateOf(initialUri)}
    var name by remember{mutableStateOf(initialUri?.let{Files.name(c,it)} ?: "")}
    var kind by remember{mutableStateOf(if(name.isBlank()) DocumentKind.UNSUPPORTED else Files.kind(name,null))}
    var refresh by remember{mutableIntStateOf(0)}

    val launcher=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()){u->
        if(u!=null){
            Files.persist(c,u)
            val n=Files.name(c,u)
            val k=Files.kind(n,c.contentResolver.getType(u))
            Files.remember(c,u,n,k)
            uri=u;name=n;kind=k;refresh++
            screen=if(k==DocumentKind.PDF)Screen.PDF else Screen.OFFICE
        }
    }

    Scaffold(topBar={
        TopAppBar(
            title={Text(when(screen){
                Screen.HOME->"PARIN OFFICE";Screen.PDF->t(3);Screen.OFFICE->t(4);Screen.SETTINGS->t(2)
            })},
            navigationIcon={if(screen!=Screen.HOME)IconButton({screen=Screen.HOME}){Text("‹",fontSize=30.sp)}},
            actions={if(screen==Screen.HOME)TextButton({screen=Screen.SETTINGS}){Text("⚙")}}
        )
    }){pad->
        when(screen){
            Screen.HOME->Home(Modifier.padding(pad),refresh,{launcher.launch(arrayOf(
                "application/pdf",
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                "application/vnd.openxmlformats-officedocument.presentationml.presentation",
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            ))}){r->uri=r.uri;name=r.name;kind=r.kind;screen=if(r.kind==DocumentKind.PDF)Screen.PDF else Screen.OFFICE}
            Screen.PDF->uri?.let{PdfScreen(Modifier.padding(pad),it,name)}
            Screen.OFFICE->uri?.let{OfficeScreen(Modifier.padding(pad),it,name,kind){activity?.openExternal(it)}}
            Screen.SETTINGS->Settings(Modifier.padding(pad)){activity?.setLocale(it)}
        }
    }
}

@Composable private fun Home(m:Modifier,refresh:Int,onOpen:()->Unit,onRecent:(RecentDocument)->Unit){
    val c=LocalContext.current
    val recent=remember(refresh){Files.recent(c)}
    Column(m.fillMaxSize().padding(18.dp).verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(12.dp)){
        Text("PARIN OFFICE",fontSize=34.sp)
        Text("PDF • Word • PowerPoint • Excel",fontSize=16.sp)
        Card(Modifier.fillMaxWidth().height(112.dp).clickable(onClick=onOpen)){
            Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.Center){
                Text(t(0),fontSize=22.sp);Text("DOCX / PPTX / XLSX / PDF")
            }
        }
        Text(t(1),fontSize=20.sp)
        recent.forEach{r->Card(Modifier.fillMaxWidth().clickable{onRecent(r)}){
            Row(Modifier.padding(14.dp),verticalAlignment=Alignment.CenterVertically){
                Text(r.name,Modifier.weight(1f));Text(r.kind.name)
            }
        }}
    }
}

@Composable private fun PdfScreen(m:Modifier,uri:Uri,name:String){
    val c=LocalContext.current
    val scope=rememberCoroutineScope()
    val pdf=remember(uri){PdfFile(c,uri,name)}
    val anns=remember{mutableStateListOf<Annotation>()}
    val save=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/pdf")){u->
        if(u!=null)scope.launch(Dispatchers.IO){pdf.export(u,anns.toList())}
    }
    var tool by remember{mutableStateOf(PdfTool.PEN)}
    var target by remember{mutableStateOf(EraserTarget.ANY)}
    var page by remember{mutableIntStateOf(0)}
    var count by remember{mutableIntStateOf(0)}
    var bmp by remember{mutableStateOf<Bitmap?>(null)}
    var points by remember{mutableStateOf(emptyList<P>())}
    var start by remember{mutableStateOf<P?>(null)}
    var end by remember{mutableStateOf<P?>(null)}
    var showText by remember{mutableStateOf(false)}
    var input by remember{mutableStateOf("")}
    var textPoint by remember{mutableStateOf(P(.1f,.1f))}

    LaunchedEffect(uri){
        pdf.open();count=pdf.count()
        if(count>0)bmp=withContext(Dispatchers.IO){pdf.render(0,1.3f)}
    }
    LaunchedEffect(page){
        if(count>0)bmp=withContext(Dispatchers.IO){pdf.render(page,1.3f)}
    }
    DisposableEffect(pdf){onDispose{pdf.close()}}

    Column(m.fillMaxSize()){
        Row(Modifier.fillMaxWidth().padding(6.dp),horizontalArrangement=Arrangement.spacedBy(4.dp),verticalAlignment=Alignment.CenterVertically){
            TextButton({tool=PdfTool.PEN}){Text(t(7))};TextButton({tool=PdfTool.TEXT}){Text(t(8))}
            TextButton({tool=PdfTool.FREE_HIGHLIGHT}){Text(t(9))};TextButton({tool=PdfTool.TEXT_HIGHLIGHT}){Text(t(10))}
            TextButton({tool=PdfTool.ERASER;target=when(target){EraserTarget.ANY->EraserTarget.PEN;EraserTarget.PEN->EraserTarget.TEXT;EraserTarget.TEXT->EraserTarget.HIGHLIGHT;EraserTarget.HIGHLIGHT->EraserTarget.ANY}}){Text(t(11))}
            Spacer(Modifier.weight(1f))
            TextButton({page=(page-1).coerceAtLeast(0)}){Text("‹")}
            Text((page+1).toString()+"/"+count)
            TextButton({page=(page+1).coerceAtMost((count-1).coerceAtLeast(0))}){Text("›")}
            Button({save.launch(name.removeSuffix(".pdf")+"-edited.pdf")}){Text(t(6))}
        }
        Box(Modifier.fillMaxSize().background(GColor(0xFFEFF2F7)).padding(8.dp),contentAlignment=Alignment.TopCenter){
            bmp?.let{image->
                Box(Modifier.fillMaxWidth().aspectRatio(image.width.toFloat()/image.height.toFloat())
                    .pointerInput(tool,target,page){
                        detectTapGestures{off->
                            val p=P((off.x/size.width).coerceIn(0f,1f),(off.y/size.height).coerceIn(0f,1f))
                            when(tool){
                                PdfTool.TEXT->{textPoint=p;input="";showText=true}
                                PdfTool.ERASER->{val ix=anns.indexOfLast{z->z.page==page&&when(z){
                                    is Annotation.Pen->(target==EraserTarget.ANY||target==EraserTarget.PEN)&&z.points.any{q->kotlin.math.abs(q.x-p.x)<.03f&&kotlin.math.abs(q.y-p.y)<.03f}
                                    is Annotation.Text->(target==EraserTarget.ANY||target==EraserTarget.TEXT)&&z.rect.hit(p)
                                    is Annotation.Highlight->(target==EraserTarget.ANY||target==EraserTarget.HIGHLIGHT)&&z.rects.any{it.hit(p)}
                                }};if(ix>=0)anns.removeAt(ix)}
                                else->Unit
                            }
                        }
                    }
                    .pointerInput(tool,page){
                        detectDragGestures(
                            onDragStart={off->
                                val p=P((off.x/size.width).coerceIn(0f,1f),(off.y/size.height).coerceIn(0f,1f))
                                start=p;end=p;if(tool==PdfTool.PEN)points=listOf(p)
                            },
                            onDrag={ch,_->val p=P((ch.position.x/size.width).coerceIn(0f,1f),(ch.position.y/size.height).coerceIn(0f,1f));if(tool==PdfTool.PEN)points=points+p else end=p},
                            onDragEnd={
                                val a0=start;val b0=end
                                if(a0!=null&&b0!=null)when(tool){
                                    PdfTool.PEN->if(points.size>1)anns+=Annotation.Pen(page,points)
                                    PdfTool.FREE_HIGHLIGHT,PdfTool.TEXT_HIGHLIGHT->anns+=Annotation.Highlight(page,listOf(R(minOf(a0.x,b0.x),minOf(a0.y,b0.y),maxOf(a0.x,b0.x),maxOf(a0.y,b0.y))))
                                    else->Unit
                                }
                                points=emptyList();start=null;end=null
                            }
                        )
                    }
                ){
                    Image(image.asImageBitmap(),null,Modifier.fillMaxSize(),ContentScale.FillBounds)
                    Canvas(Modifier.fillMaxSize()){
                        anns.filter{it.page==page}.forEach{z->
                            when(z){
                                is Annotation.Pen->{if(z.points.size>1){val p=Path();z.points.forEachIndexed{i,q->if(i==0)p.moveTo(q.x*size.width,q.y*size.height)else p.lineTo(q.x*size.width,q.y*size.height)};drawPath(p,GColor(z.color),Stroke(width=4f))}}
                                is Annotation.Text->drawContext.canvas.nativeCanvas.drawText(z.value,z.rect.l*size.width,z.rect.b*size.height,android.graphics.Paint(3).apply{color=z.color;textSize=z.size})
                                is Annotation.Highlight->z.rects.forEach{q->drawRect(GColor(z.color),Offset(q.l*size.width,q.t*size.height),androidx.compose.ui.geometry.Size((q.r-q.l)*size.width,(q.b-q.t)*size.height))}
                            }
                        }
                    }
                }
            }
        }
    }
    if(showText)AlertDialog(
        onDismissRequest={showText=false},
        title={Text(t(8))},
        text={OutlinedTextField(input,{input=it},minLines=3)},
        confirmButton={TextButton({if(input.isNotBlank())anns+=Annotation.Text(page,R(textPoint.x,textPoint.y,(textPoint.x+.35f).coerceAtMost(1f),(textPoint.y+.08f).coerceAtMost(1f)),input);showText=false}){Text(t(5))}}
    )
}

@Composable private fun OfficeScreen(m:Modifier,uri:Uri,name:String,kind:DocumentKind,onExternal:()->Unit){
    val c=LocalContext.current
    val scope=rememberCoroutineScope()
    var doc by remember{mutableStateOf<OfficeDoc?>(null)}
    var text by remember{mutableStateOf("")};var slides by remember{mutableStateOf(emptyList<String>())};var cells by remember{mutableStateOf(emptyList<XCell>())}
    var bold by remember{mutableStateOf(false)};var italic by remember{mutableStateOf(false)};var underline by remember{mutableStateOf(false)}
    LaunchedEffect(uri){doc=withContext(Dispatchers.IO){Ooxml.load(c,uri,name)};doc?.let{text=it.text;slides=it.slides;cells=it.cells}}
    Column(m.fillMaxSize().padding(12.dp)){
        Row(horizontalArrangement=Arrangement.spacedBy(5.dp),verticalAlignment=Alignment.CenterVertically){
            if(kind!=DocumentKind.XLSX){Button({bold=!bold}){Text("B")};Button({italic=!italic}){Text("I")};Button({underline=!underline}){Text("U")}}
            Spacer(Modifier.weight(1f));OutlinedButton(onExternal){Text("Open external")};Button({doc?.let{d->scope.launch(Dispatchers.IO){Ooxml.save(c,uri,when(d.kind){DocumentKind.DOCX->d.copy(text=text);DocumentKind.PPTX->d.copy(slides=slides);DocumentKind.XLSX->d.copy(cells=cells);else->d},Format(bold,italic,underline))}}}){Text(t(5))}
        }
        when(kind){
            DocumentKind.DOCX->OutlinedTextField(text,{text=it},Modifier.fillMaxSize(),minLines=20)
            DocumentKind.PPTX->LazyColumn(Modifier.fillMaxSize()){items(slides.indices.toList()){idx->Card(Modifier.fillMaxWidth().padding(5.dp)){Column(Modifier.padding(10.dp)){Text("Slide "+(idx+1));OutlinedTextField(slides[idx],{v->val x=slides.toMutableList();x[idx]=v;slides=x},Modifier.fillMaxWidth(),minLines=5)}}}}
            DocumentKind.XLSX->LazyColumn(Modifier.fillMaxSize()){items(cells,key={it.ref}){cell->Row(verticalAlignment=Alignment.CenterVertically){Text(cell.ref,Modifier.width(60.dp));OutlinedTextField(cell.value,{v->cells=cells.map{if(it.ref==cell.ref)it.copy(value=v)else it}},Modifier.weight(1f),singleLine=true)}}}
            else->Text("Unsupported")
        }
    }
}

@Composable private fun Settings(m:Modifier,onLocale:(String)->Unit){
    var expanded by remember{mutableStateOf(false)}
    Column(m.fillMaxSize().padding(18.dp).verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(14.dp)){
        Text(t(2),fontSize=28.sp)
        Card{Row(Modifier.fillMaxWidth().padding(14.dp),verticalAlignment=Alignment.CenterVertically){
            Text(t(12),Modifier.weight(1f))
            TextButton({expanded=true}){Text("16")}
            DropdownMenu(expanded,{expanded=false}){locales.forEach{(tag,label)->DropdownMenuItem(text={Text(label)},onClick={expanded=false;onLocale(tag)})}}
        }}
        Card{Column(Modifier.padding(14.dp)){Text(t(13),fontSize=18.sp);Text("Flat tiles • Windows Phone inspired")}}
        Card{Column(Modifier.padding(14.dp)){Text(t(14),fontSize=18.sp);Text("PDF annotations • OOXML preservation • recent files • ABI release builds")}}
        Card{Column(Modifier.padding(14.dp)){Text("Parin Office 0.1.0",fontSize=18.sp);Text("Kotlin Android • open source")}}
    }
}
