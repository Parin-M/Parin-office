package com.parin.office.data

import android.content.Context
import android.net.Uri
import com.parin.office.model.DocumentKind
import com.parin.office.model.Format
import com.parin.office.model.OfficeDoc
import com.parin.office.model.XCell
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

object Ooxml {
    private fun factory(): DocumentBuilderFactory = DocumentBuilderFactory.newInstance().apply {
        isNamespaceAware = true
        setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true)
        runCatching { setFeature("http://apache.org/xml/features/disallow-doctype-decl", true) }
        runCatching { setFeature("http://xml.org/sax/features/external-general-entities", false) }
        runCatching { setFeature("http://xml.org/sax/features/external-parameter-entities", false) }
        setXIncludeAware(false)
        isExpandEntityReferences = false
    }

    private fun parse(bytes: ByteArray): Document =
        factory().newDocumentBuilder().parse(ByteArrayInputStream(bytes))

    private fun all(document: Document, local: String): List<Element> {
        val result = mutableListOf<Element>()
        val nodes = document.getElementsByTagName("*")
        for (i in 0 until nodes.length) {
            val element = nodes.item(i) as? Element ?: continue
            if (element.localName == local || element.nodeName.endsWith(":$local")) {
                result += element
            }
        }
        return result
    }

    private fun deep(node: Node, local: String): List<Element> {
        val result = mutableListOf<Element>()
        val children = node.childNodes
        for (i in 0 until children.length) {
            val child = children.item(i)
            if (child.nodeType == Node.ELEMENT_NODE) {
                val element = child as Element
                if (element.localName == local || element.nodeName.endsWith(":$local")) {
                    result += element
                }
                result += deep(child, local)
            }
        }
        return result
    }

    private fun serialize(document: Document): ByteArray {
        val transformer = TransformerFactory.newInstance().newTransformer().apply {
            setOutputProperty(OutputKeys.ENCODING, "UTF-8")
        }
        return java.io.ByteArrayOutputStream().use { output ->
            transformer.transform(DOMSource(document), StreamResult(output))
            output.toByteArray()
        }
    }

    fun load(context: Context, uri: Uri, name: String): OfficeDoc =
        loadFile(Files.cache(context, uri, name), name)

    fun loadFile(file: File, name: String): OfficeDoc = when {
        name.endsWith(".docx", true) -> ZipFile(file).use { zip ->
            val entry = zip.getEntry("word/document.xml") ?: return@use OfficeDoc(DocumentKind.DOCX, name)
            val document = parse(zip.getInputStream(entry).readBytes())
            OfficeDoc(
                DocumentKind.DOCX,
                name,
                text = all(document, "p").joinToString(System.lineSeparator()) { paragraph ->
                    deep(paragraph, "t").joinToString("") { it.textContent.orEmpty() }
                }
            )
        }

        name.endsWith(".pptx", true) -> ZipFile(file).use { zip ->
            val names = zip.entries()
                .asSequence()
                .map { it.name }
                .filter { path ->
                    path.startsWith("ppt/slides/slide") &&
                        path.endsWith(".xml") &&
                        path.removePrefix("ppt/slides/slide").removeSuffix(".xml").toIntOrNull() != null
                }
                .sortedBy { path ->
                    path.removePrefix("ppt/slides/slide").removeSuffix(".xml").toInt()
                }
                .toList()

            OfficeDoc(
                DocumentKind.PPTX,
                name,
                slides = names.map { path ->
                    val document = parse(zip.getInputStream(zip.getEntry(path)).readBytes())
                    deep(document, "t").joinToString(System.lineSeparator()) { it.textContent.orEmpty() }
                }
            )
        }

        name.endsWith(".xlsx", true) -> ZipFile(file).use { zip ->
            val shared = zip.getEntry("xl/sharedStrings.xml")?.let { entry ->
                val document = parse(zip.getInputStream(entry).readBytes())
                all(document, "si").map { item ->
                    deep(item, "t").joinToString("") { it.textContent.orEmpty() }
                }
            }.orEmpty()

            val entry = zip.getEntry("xl/worksheets/sheet1.xml")
                ?: return@use OfficeDoc(DocumentKind.XLSX, name)
            val document = parse(zip.getInputStream(entry).readBytes())

            OfficeDoc(
                DocumentKind.XLSX,
                name,
                cells = all(document, "c").mapNotNull { cell ->
                    val reference = cell.getAttribute("r")
                        .takeIf { it.isNotBlank() }
                        ?: return@mapNotNull null
                    val raw = deep(cell, "v").firstOrNull()?.textContent.orEmpty()
                    val value = when (cell.getAttribute("t")) {
                        "s" -> shared.getOrNull(raw.toIntOrNull() ?: -1).orEmpty()
                        "inlineStr" -> deep(cell, "t").joinToString("") { it.textContent.orEmpty() }
                        else -> raw
                    }
                    XCell(reference, value)
                }.take(400)
            )
        }

        else -> OfficeDoc(DocumentKind.UNSUPPORTED, name)
    }

    fun save(context: Context, uri: Uri, document: OfficeDoc, format: Format) {
        val source = Files.cache(context, uri, document.name)
        val output = File.createTempFile("parin-", "-out", context.cacheDir)

        when (document.kind) {
            DocumentKind.DOCX ->
                rewrite(source, output) { path, bytes ->
                    if (path == "word/document.xml") updateDocx(bytes, document.text, format) else bytes
                }

            DocumentKind.PPTX -> {
                var slideIndex = 0
                rewrite(source, output) { path, bytes ->
                    if (path.startsWith("ppt/slides/slide") &&
                        path.endsWith(".xml") &&
                        path.removePrefix("ppt/slides/slide").removeSuffix(".xml").toIntOrNull() != null
                    ) {
                        updatePptx(
                            bytes,
                            document.slides.getOrNull(slideIndex++).orEmpty().lines(),
                            format
                        )
                    } else {
                        bytes
                    }
                }
            }

            DocumentKind.XLSX -> {
                val values = document.cells.associateBy { it.ref }
                rewrite(source, output) { path, bytes ->
                    if (path == "xl/worksheets/sheet1.xml") updateXlsx(bytes, values) else bytes
                }
            }

            else -> return
        }

        context.contentResolver.openOutputStream(uri, "wt").use { target ->
            requireNotNull(target)
            output.inputStream().use { input -> input.copyTo(target!!) }
        }

        source.delete()
        output.delete()
    }

    private fun updateDocx(bytes: ByteArray, text: String, format: Format): ByteArray {
        val document = parse(bytes)
        val lines = text.lines()

        all(document, "p").forEachIndexed { index, paragraph ->
            val targets = deep(paragraph, "t")
            targets.forEachIndexed { textIndex, target ->
                target.textContent = if (textIndex == 0) lines.getOrNull(index).orEmpty() else ""
            }
        }

        all(document, "r").forEach { run ->
            var properties = deep(run, "rPr").firstOrNull()
            if (properties == null) {
                properties = document.createElementNS(
                    "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
                    "w:rPr"
                )
                run.insertBefore(properties, run.firstChild)
            }
            toggle(document, properties, "b", format.bold)
            toggle(document, properties, "i", format.italic)
            toggle(document, properties, "u", format.underline)
        }

        return serialize(document)
    }

    private fun toggle(document: Document, parent: Element, tag: String, enabled: Boolean) {
        deep(parent, tag).forEach { parent.removeChild(it) }
        if (enabled) {
            parent.appendChild(
                document.createElementNS(
                    "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
                    "w:$tag"
                )
            )
        }
    }

    private fun updatePptx(bytes: ByteArray, lines: List<String>, format: Format): ByteArray {
        val document = parse(bytes)
        all(document, "t").forEachIndexed { index, target ->
            target.textContent = lines.getOrNull(index).orEmpty()
        }
        all(document, "rPr").forEach { properties ->
            if (format.bold) properties.setAttribute("b", "1") else properties.removeAttribute("b")
            if (format.italic) properties.setAttribute("i", "1") else properties.removeAttribute("i")
            if (format.underline) properties.setAttribute("u", "sng") else properties.removeAttribute("u")
        }
        return serialize(document)
    }

    private fun updateXlsx(bytes: ByteArray, values: Map<String, XCell>): ByteArray {
        val document = parse(bytes)
        all(document, "c").forEach { cell ->
            val value = values[cell.getAttribute("r")]?.value ?: return@forEach
            while (cell.firstChild != null) cell.removeChild(cell.firstChild)
            cell.setAttribute("t", "inlineStr")
            val inline = document.createElement("is")
            val text = document.createElement("t")
            text.textContent = value
            inline.appendChild(text)
            cell.appendChild(inline)
        }
        return serialize(document)
    }

    private fun rewrite(source: File, output: File, replacer: (String, ByteArray) -> ByteArray) {
        ZipFile(source).use { zip ->
            ZipOutputStream(output.outputStream().buffered()).use { out ->
                zip.entries().asSequence().forEach { entry ->
                    out.putNextEntry(ZipEntry(entry.name))
                    zip.getInputStream(entry).use { input ->
                        out.write(replacer(entry.name, input.readBytes()))
                    }
                    out.closeEntry()
                }
            }
        }
    }
}
