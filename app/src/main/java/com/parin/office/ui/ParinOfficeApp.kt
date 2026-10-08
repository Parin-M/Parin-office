package com.parin.office.ui

import android.graphics.Bitmap
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color as ComposeColor
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
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
import com.parin.office.model.Annotation
import com.parin.office.model.DocumentKind
import com.parin.office.model.EraserTarget
import com.parin.office.model.Format
import com.parin.office.model.OfficeDoc
import com.parin.office.model.P
import com.parin.office.model.PdfTool
import com.parin.office.model.R
import com.parin.office.model.RecentDocument
import com.parin.office.model.XCell
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private enum class Screen { HOME, PDF, OFFICE, SETTINGS }

private val localeOptions = listOf(
    "en" to "English", "fa" to "فارسی", "da" to "Dansk", "de" to "Deutsch", "de-CH" to "Schweizerdeutsch",
    "ar" to "العربية", "hi" to "हिन्दी", "he" to "עברית", "es" to "Español", "it" to "Italiano",
    "sv" to "Svenska", "fi" to "Suomi", "no" to "Norsk", "is" to "Íslenska", "el" to "Ελληνικά", "tr" to "Türkçe"
)

private val strings = mapOf(
    "en" to listOf("Open file","Recent","Settings","PDF editor","Office editor","Save","Export","Pen","Text","Free highlight","Text highlight","Eraser","Language","Light theme","Formatting"),
    "fa" to listOf("باز کردن فایل","اخیر","تنظیمات","ویرایشگر PDF","ویرایشگر آفیس","ذخیره","خروجی","مداد","متن","هایلایت آزاد","هایلایت متن","پاک‌کن","زبان","تم روشن","قالب‌بندی"),
    "de" to listOf("Datei öffnen","Zuletzt","Einstellungen","PDF-Editor","Office-Editor","Speichern","Exportieren","Stift","Text","Freie Hervorhebung","Texthervorhebung","Radiergummi","Sprache","Helles Design","Formatierung"),
    "ar" to listOf("فتح ملف","الأخيرة","الإعدادات","محرر PDF","محرر أوفيس","حفظ","تصدير","قلم","نص","تظليل حر","تظليل النص","ممحاة","اللغة","المظهر الفاتح","التنسيق"),
    "es" to listOf("Abrir archivo","Recientes","Ajustes","Editor PDF","Editor Office","Guardar","Exportar","Lápiz","Texto","Resaltado libre","Resaltado de texto","Borrador","Idioma","Tema claro","Formato"),
    "it" to listOf("Apri file","Recenti","Impostazioni","Editor PDF","Editor Office","Salva","Esporta","Penna","Testo","Evidenziazione libera","Evidenziazione testo","Gomma","Lingua","Tema chiaro","Formattazione"),
    "sv" to listOf("Öppna fil","Senaste","Inställningar","PDF-redigerare","Office-redigerare","Spara","Exportera","Penna","Text","Fri markering","Textmarkering","Sudd","Språk","Ljust tema","Formatering"),
    "fi" to listOf("Avaa tiedosto","Viimeisimmät","Asetukset","PDF-editori","Office-editori","Tallenna","Vie","Kynä","Teksti","Vapaa korostus","Tekstin korostus","Pyyhin","Kieli","Vaalea teema","Muotoilu"),
    "tr" to listOf("Dosya aç","Son kullanılanlar","Ayarlar","PDF düzenleyici","Office düzenleyici","Kaydet","Dışa aktar","Kalem","Metin","Serbest vurgulama","Metin vurgulama","Silgi","Dil","Açık tema","Biçimlendirme"),
    "da" to listOf("Åbn fil","Seneste","Indstillinger","PDF-editor","Office-editor","Gem","Eksportér","Pen","Tekst","Fri fremhævning","Tekstfremhævning","Viskelæder","Sprog","Lyst tema","Formatering"),
    "hi" to listOf("फ़ाइल खोलें","हाल के","सेटिंग्स","PDF संपादक","Office संपादक","सहेजें","निर्यात","पेन","टेक्स्ट","मुक्त हाइलाइट","टेक्स्ट हाइलाइट","इरेज़र","भाषा","हल्का थीम","फ़ॉर्मेटिंग"),
    "he" to listOf("פתיחת קובץ","אחרונים","הגדרות","עורך PDF","עורך Office","שמירה","ייצוא","עט","טקסט","הדגשה חופשית","הדגשת טקסט","מחק","שפה","ערכת נושא בהירה","עיצוב"),
    "no" to listOf("Åpne fil","Nylige","Innstillinger","PDF-redigerer","Office-redigerer","Lagre","Eksporter","Penn","Tekst","Fri utheving","Tekstutheving","Viskelær","Språk","Lyst tema","Formatering"),
    "is" to listOf("Opna skrá","Nýlegar","Stillingar","PDF ritill","Office ritill","Vista","Flytja út","Penni","Texti","Frjáls áhersla","Textaáhersla","Strokleður","Tungumál","Ljóst þema","Snið"),
    "el" to listOf("Άνοιγμα αρχείου","Πρόσφατα","Ρυθμίσεις","Επεξεργαστής PDF","Επεξεργαστής Office","Αποθήκευση","Εξαγωγή","Στυλό","Κείμενο","Ελεύθερη επισήμανση","Επισήμανση κειμένου","Γόμα","Γλώσσα","Φωτεινό θέμα","Μορφοποίηση"),
    "de-CH" to listOf("Datei öffnen","Zuletzt","Einstellungen","PDF-Editor","Office-Editor","Speichern","Exportieren","Stift","Text","Freie Hervorhebung","Texthervorhebung","Radiergummi","Sprache","Helles Design","Formatierung")
)

private fun tr(index: Int): String {
    val tag = LocaleListCompat.getAdjustedDefault().get(0)?.toLanguageTag() ?: "en"
    return strings[tag]?.get(index) ?: strings[tag.substringBefore("-")]?.get(index) ?: strings.getValue("en")[index]
}

@Composable
fun ParinOfficeTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = ComposeColor(0xFF135DFF),
            secondary = ComposeColor(0xFF18B6A4),
            background = ComposeColor(0xFFF6F8FC),
            surface = ComposeColor.White
        ),
        content = content
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ParinOfficeApp(initialUri: Uri?) {
    val context = LocalContext.current
    val activity = context as? MainActivity
    var screen by remember { mutableStateOf(Screen.HOME) }
    var currentUri by remember { mutableStateOf(initialUri) }
    var currentName by remember { mutableStateOf(initialUri?.let { Files.name(context, it) }.orEmpty()) }
    var currentKind by remember { mutableStateOf(if (currentName.isBlank()) DocumentKind.UNSUPPORTED else Files.kind(currentName, null)) }
    var refresh by remember { mutableIntStateOf(0) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        Files.persist(context, uri)
        val name = Files.name(context, uri)
        val kind = Files.kind(name, context.contentResolver.getType(uri))
        Files.remember(context, uri, name, kind)
        currentUri = uri
        currentName = name
        currentKind = kind
        refresh++
        screen = if (kind == DocumentKind.PDF) Screen.PDF else Screen.OFFICE
    }
    LaunchedEffect(initialUri) {
        if (initialUri != null && currentKind != DocumentKind.UNSUPPORTED) Files.persist(context, initialUri)
    }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(when (screen) { Screen.HOME -> "PARIN OFFICE"; Screen.PDF -> tr(3); Screen.OFFICE -> tr(4); Screen.SETTINGS -> tr(2) }) },
                navigationIcon = { if (screen != Screen.HOME) TextButton({ screen = Screen.HOME }) { Text("‹", fontSize = 30.sp) } },
                actions = { if (screen == Screen.HOME) TextButton({ screen = Screen.SETTINGS }) { Text("⚙") } }
            )
        }
    ) { padding ->
        when (screen) {
            Screen.HOME -> HomeScreen(Modifier.padding(padding), refresh, {
                launcher.launch(arrayOf(
                    "application/pdf",
                    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                ))
            }) { recent ->
                currentUri = recent.uri; currentName = recent.name; currentKind = recent.kind
                screen = if (recent.kind == DocumentKind.PDF) Screen.PDF else Screen.OFFICE
            }
            Screen.PDF -> currentUri?.let { PdfEditor(Modifier.padding(padding), it, currentName) }
            Screen.OFFICE -> currentUri?.let { OfficeEditor(Modifier.padding(padding), it, currentName, currentKind) { activity?.openExternal(it) } }
            Screen.SETTINGS -> SettingsScreen(Modifier.padding(padding)) { activity?.setLocale(it) }
        }
    }
}

@Composable
private fun HomeScreen(modifier: Modifier, refresh: Int, onOpen: () -> Unit, onRecent: (RecentDocument) -> Unit) {
    val context = LocalContext.current
    val recent = remember(refresh) { Files.recent(context) }
    Column(modifier.fillMaxSize().padding(18.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("PARIN OFFICE", fontSize = 34.sp)
        Text("PDF • Word • PowerPoint • Excel", fontSize = 16.sp)
        Card(Modifier.fillMaxWidth().height(112.dp).clickable(onClick = onOpen), shape = RoundedCornerShape(2.dp)) {
            Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.Center) { Text(tr(0), fontSize = 22.sp); Text("DOCX / PPTX / XLSX / PDF") }
        }
        Text(tr(1), fontSize = 20.sp)
        recent.forEach { item ->
            Card(Modifier.fillMaxWidth().clickable { onRecent(item) }, shape = RoundedCornerShape(2.dp)) {
                Row(Modifier.fillMaxWidth().padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Text(item.name, Modifier.weight(1f)); Text(item.kind.name) }
            }
        }
    }
}

@Composable
private fun PdfEditor(modifier: Modifier, uri: Uri, name: String) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val pdf = remember(uri) { PdfFile(context, uri, name) }
    val annotations = remember { mutableStateListOf<Annotation>() }
    val saveLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/pdf")) { target ->
        if (target != null) scope.launch(Dispatchers.IO) { pdf.export(target, annotations.toList()) }
    }
    var tool by remember { mutableStateOf(PdfTool.PEN) }
    var eraserTarget by remember { mutableStateOf(EraserTarget.ANY) }
    var page by remember { mutableIntStateOf(0) }
    var pageCount by remember { mutableIntStateOf(0) }
    var bitmap by remember { mutableStateOf<Bitmap?>(null) }
    var drawing by remember { mutableStateOf(emptyList<P>()) }
    var start by remember { mutableStateOf<P?>(null) }
    var end by remember { mutableStateOf<P?>(null) }
    var showText by remember { mutableStateOf(false) }
    var textInput by remember { mutableStateOf("") }
    var textAnchor by remember { mutableStateOf(P(.1f, .1f)) }
    LaunchedEffect(uri) { pdf.open(); pageCount = pdf.count(); if (pageCount > 0) bitmap = withContext(Dispatchers.IO) { pdf.render(0, 1.3f) } }
    LaunchedEffect(page) { if (pageCount > 0) bitmap = withContext(Dispatchers.IO) { pdf.render(page, 1.3f) } }
    DisposableEffect(pdf) { onDispose { pdf.close() } }
    Column(modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(6.dp), horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
            TextButton({ tool = PdfTool.PEN }) { Text(tr(7)) }
            TextButton({ tool = PdfTool.TEXT }) { Text(tr(8)) }
            TextButton({ tool = PdfTool.FREE_HIGHLIGHT }) { Text(tr(9)) }
            TextButton({ tool = PdfTool.TEXT_HIGHLIGHT }) { Text(tr(10)) }
            TextButton({ tool = PdfTool.ERASER; eraserTarget = when (eraserTarget) { EraserTarget.ANY -> EraserTarget.PEN; EraserTarget.PEN -> EraserTarget.TEXT; EraserTarget.TEXT -> EraserTarget.HIGHLIGHT; EraserTarget.HIGHLIGHT -> EraserTarget.ANY } }) { Text(tr(11)) }
            Spacer(Modifier.weight(1f))
            TextButton({ page = (page - 1).coerceAtLeast(0) }) { Text("‹") }
            Text((page + 1).toString() + "/" + pageCount)
            TextButton({ page = (page + 1).coerceAtMost((pageCount - 1).coerceAtLeast(0)) }) { Text("›") }
            Button({ saveLauncher.launch(name.removeSuffix(".pdf") + "-edited.pdf") }) { Text(tr(6)) }
        }
        Box(Modifier.fillMaxSize().background(ComposeColor(0xFFEFF2F7)).padding(8.dp), contentAlignment = Alignment.TopCenter) {
            bitmap?.let { image ->
                Box(
                    Modifier.fillMaxWidth().aspectRatio(image.width.toFloat() / image.height.toFloat())
                        .pointerInput(tool, eraserTarget, page) {
                            detectTapGestures { offset ->
                                val point = P((offset.x / size.width).coerceIn(0f, 1f), (offset.y / size.height).coerceIn(0f, 1f))
                                when (tool) {
                                    PdfTool.TEXT -> { textAnchor = point; textInput = ""; showText = true }
                                    PdfTool.TEXT_HIGHLIGHT -> scope.launch(Dispatchers.IO) {
                                        val pageSize = pdf.pageSize(page)
                                        val rects = pdf.wordAt(page, (point.x * pageSize.first).toInt(), (point.y * pageSize.second).toInt()).map { rect ->
                                            R(rect.left / pageSize.first.toFloat(), rect.top / pageSize.second.toFloat(), rect.right / pageSize.first.toFloat(), rect.bottom / pageSize.second.toFloat())
                                        }
                                        if (rects.isNotEmpty()) annotations += Annotation.Highlight(page, rects)
                                    }
                                    PdfTool.ERASER -> {
                                        val index = annotations.indexOfLast { annotation ->
                                            annotation.page == page && when (annotation) {
                                                is Annotation.Pen -> (eraserTarget == EraserTarget.ANY || eraserTarget == EraserTarget.PEN) && annotation.points.any { kotlin.math.abs(it.x - point.x) < .03f && kotlin.math.abs(it.y - point.y) < .03f }
                                                is Annotation.Text -> (eraserTarget == EraserTarget.ANY || eraserTarget == EraserTarget.TEXT) && annotation.rect.hit(point)
                                                is Annotation.Highlight -> (eraserTarget == EraserTarget.ANY || eraserTarget == EraserTarget.HIGHLIGHT) && annotation.rects.any { it.hit(point) }
                                            }
                                        }
                                        if (index >= 0) annotations.removeAt(index)
                                    }
                                    else -> Unit
                                }
                            }
                        }
                        .pointerInput(tool, page) {
                            detectDragGestures(
                                onDragStart = { offset ->
                                    val point = P((offset.x / size.width).coerceIn(0f, 1f), (offset.y / size.height).coerceIn(0f, 1f))
                                    start = point; end = point; if (tool == PdfTool.PEN) drawing = listOf(point)
                                },
                                onDrag = { change, _ ->
                                    val point = P((change.position.x / size.width).coerceIn(0f, 1f), (change.position.y / size.height).coerceIn(0f, 1f))
                                    end = point; if (tool == PdfTool.PEN) drawing = drawing + point
                                },
                                onDragEnd = {
                                    val a = start; val b = end
                                    if (a != null && b != null) when (tool) {
                                        PdfTool.PEN -> if (drawing.size > 1) annotations += Annotation.Pen(page, drawing)
                                        PdfTool.FREE_HIGHLIGHT -> annotations += Annotation.Highlight(page, listOf(R(minOf(a.x, b.x), minOf(a.y, b.y), maxOf(a.x, b.x), maxOf(a.y, b.y))))
                                        else -> Unit
                                    }
                                    drawing = emptyList(); start = null; end = null
                                }
                            )
                        }
                ) {
                    Image(bitmap = image.asImageBitmap(), contentDescription = null, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.FillBounds)
                    Canvas(Modifier.fillMaxSize()) {
                        annotations.filter { it.page == page }.forEach { annotation ->
                            when (annotation) {
                                is Annotation.Pen -> drawPen(this, annotation)
                                is Annotation.Text -> drawIntoCanvas { canvas -> canvas.nativeCanvas.drawText(annotation.value, annotation.rect.l * size.width, annotation.rect.b * size.height, android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply { color = annotation.color; textSize = annotation.size }) }
                                is Annotation.Highlight -> annotation.rects.forEach { rect -> drawRect(ComposeColor(annotation.color), Offset(rect.l * size.width, rect.t * size.height), androidx.compose.ui.geometry.Size((rect.r - rect.l) * size.width, (rect.b - rect.t) * size.height)) }
                            }
                        }
                        if (drawing.size > 1) drawPen(this, Annotation.Pen(page, drawing))
                    }
                }
            }
        }
    }
    if (showText) AlertDialog(
        onDismissRequest = { showText = false },
        title = { Text(tr(8)) },
        text = { OutlinedTextField(textInput, { textInput = it }, minLines = 3) },
        confirmButton = {
            TextButton({
                if (textInput.isNotBlank()) annotations += Annotation.Text(page, R(textAnchor.x, textAnchor.y, (textAnchor.x + .35f).coerceAtMost(1f), (textAnchor.y + .08f).coerceAtMost(1f)), textInput)
                showText = false
            }) { Text(tr(5)) }
        }
    )
}

private fun drawPen(scope: DrawScope, annotation: Annotation.Pen) {
    if (annotation.points.size < 2) return
    val path = Path()
    annotation.points.forEachIndexed { index, point ->
        val x = point.x * scope.size.width
        val y = point.y * scope.size.height
        if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)
    }
    scope.drawPath(path, color = ComposeColor(annotation.color), style = Stroke(width = 4f))
}

@Composable
private fun OfficeEditor(modifier: Modifier, uri: Uri, name: String, kind: DocumentKind, onExternal: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var document by remember { mutableStateOf<OfficeDoc?>(null) }
    var text by remember { mutableStateOf("") }
    var slides by remember { mutableStateOf(emptyList<String>()) }
    var cells by remember { mutableStateOf(emptyList<XCell>()) }
    var bold by remember { mutableStateOf(false) }
    var italic by remember { mutableStateOf(false) }
    var underline by remember { mutableStateOf(false) }
    LaunchedEffect(uri) {
        document = withContext(Dispatchers.IO) { Ooxml.load(context, uri, name) }
        document?.let { text = it.text; slides = it.slides; cells = it.cells }
    }
    Column(modifier.fillMaxSize().padding(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(5.dp), verticalAlignment = Alignment.CenterVertically) {
            if (kind != DocumentKind.XLSX) { Button({ bold = !bold }) { Text("B") }; Button({ italic = !italic }) { Text("I") }; Button({ underline = !underline }) { Text("U") } }
            Spacer(Modifier.weight(1f))
            OutlinedButton(onExternal) { Text("Open external") }
            Button({
                val snapshot = document ?: return@Button
                scope.launch(Dispatchers.IO) {
                    Ooxml.save(context, uri, when (snapshot.kind) {
                        DocumentKind.DOCX -> snapshot.copy(text = text)
                        DocumentKind.PPTX -> snapshot.copy(slides = slides)
                        DocumentKind.XLSX -> snapshot.copy(cells = cells)
                        else -> snapshot
                    }, Format(bold, italic, underline))
                }
            }) { Text(tr(5)) }
        }
        Spacer(Modifier.height(8.dp))
        when (kind) {
            DocumentKind.DOCX -> OutlinedTextField(text, { text = it }, Modifier.fillMaxSize(), minLines = 20)
            DocumentKind.PPTX -> LazyColumn(Modifier.fillMaxSize()) { items(slides.indices.toList()) { index -> Card(Modifier.fillMaxWidth().padding(5.dp)) { Column(Modifier.padding(10.dp)) { Text("Slide " + (index + 1).toString()); OutlinedTextField(slides[index], { value -> val updated = slides.toMutableList(); updated[index] = value; slides = updated }, Modifier.fillMaxWidth(), minLines = 5) } } } }
            DocumentKind.XLSX -> LazyColumn(Modifier.fillMaxSize()) { items(cells, key = { it.ref }) { cell -> Row(verticalAlignment = Alignment.CenterVertically) { Text(cell.ref, Modifier.width(60.dp)); OutlinedTextField(cell.value, { value -> cells = cells.map { if (it.ref == cell.ref) it.copy(value = value) else it } }, Modifier.weight(1f), singleLine = true) } } }
            else -> Text("Unsupported")
        }
    }
}

@Composable
private fun SettingsScreen(modifier: Modifier, onLocale: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Column(modifier.fillMaxSize().padding(18.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(tr(2), fontSize = 28.sp)
        Card {
            Row(Modifier.fillMaxWidth().padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(tr(12), Modifier.weight(1f))
                TextButton({ expanded = true }) { Text("16") }
                DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                    localeOptions.forEach { (tag, label) -> DropdownMenuItem(text = { Text(label) }, onClick = { expanded = false; onLocale(tag) }) }
                }
            }
        }
        Card { Column(Modifier.padding(14.dp)) { Text(tr(13), fontSize = 18.sp); Text("Flat tiles • Windows Phone inspired") } }
        Card { Column(Modifier.padding(14.dp)) { Text(tr(14), fontSize = 18.sp); Text("PDF annotations • OOXML preservation • recent files • ABI releases") } }
        Card { Column(Modifier.padding(14.dp)) { Text("Parin Office 0.1.0", fontSize = 18.sp); Text("Kotlin Android • open source") } }
    }
}