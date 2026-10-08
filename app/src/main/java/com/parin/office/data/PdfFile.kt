package com.parin.office.data

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Point
import android.graphics.RectF
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Build
import com.parin.office.model.Annotation

data class PdfSearchHit(
    val page: Int,
    val bounds: List<RectF>,
    val query: String
)

class PdfFile(private val context: Context, private val uri: Uri, private val name: String) {
    private val file = Files.cache(context, uri, name)
    private var renderer: PdfRenderer? = null

    fun open() {
        if (renderer == null) {
            renderer = PdfRenderer(
                android.os.ParcelFileDescriptor.open(
                    file,
                    android.os.ParcelFileDescriptor.MODE_READ_ONLY
                )
            )
        }
    }

    fun count(): Int = requireNotNull(renderer).pageCount

    fun pageSize(index: Int): Pair<Int, Int> {
        val page = requireNotNull(renderer).openPage(index)
        return try {
            page.width to page.height
        } finally {
            page.close()
        }
    }

    fun render(index: Int, scale: Float): Bitmap {
        val page = requireNotNull(renderer).openPage(index)
        val s = scale.coerceIn(.75f, 2.5f)
        val bitmap = Bitmap.createBitmap(
            (page.width * s).toInt().coerceAtLeast(1),
            (page.height * s).toInt().coerceAtLeast(1),
            Bitmap.Config.ARGB_8888
        )
        page.render(
            bitmap,
            null,
            Matrix().apply { setScale(s, s) },
            PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY
        )
        page.close()
        return bitmap
    }

    fun searchText(query: String): List<PdfSearchHit> {
        if (query.isBlank() || Build.VERSION.SDK_INT < 35) return emptyList()
        val r = requireNotNull(renderer)
        val result = mutableListOf<PdfSearchHit>()

        for (pageIndex in 0 until r.pageCount) {
            val page = r.openPage(pageIndex)
            runCatching {
                page.searchText(query).forEach { match ->
                    result += PdfSearchHit(
                        page = pageIndex,
                        bounds = match.bounds.toList(),
                        query = query
                    )
                }
            }
            page.close()
        }

        return result
    }

    fun wordAt(pageIndex: Int, x: Int, y: Int): List<RectF> {
        if (Build.VERSION.SDK_INT < 35) return emptyList()

        val page = requireNotNull(renderer).openPage(pageIndex)
        return try {
            val boundary = android.graphics.pdf.models.selection.SelectionBoundary(Point(x, y))
            page.selectContent(boundary, boundary)
                ?.selectedTextContents
                ?.flatMap { it.bounds }
                .orEmpty()
        } finally {
            page.close()
        }
    }

    fun export(target: Uri, annotations: List<Annotation>) {
        val r = PdfRenderer(
            android.os.ParcelFileDescriptor.open(
                file,
                android.os.ParcelFileDescriptor.MODE_READ_ONLY
            )
        )
        val out = android.graphics.pdf.PdfDocument()

        try {
            for (i in 0 until r.pageCount) {
                val source = r.openPage(i)
                val scale = 2f
                val bitmap = Bitmap.createBitmap(
                    (source.width * scale).toInt(),
                    (source.height * scale).toInt(),
                    Bitmap.Config.ARGB_8888
                )

                source.render(
                    bitmap,
                    null,
                    Matrix().apply { setScale(scale, scale) },
                    PdfRenderer.Page.RENDER_MODE_FOR_PRINT
                )
                source.close()

                val info = android.graphics.pdf.PdfDocument.PageInfo.Builder(
                    bitmap.width, bitmap.height, i + 1
                ).create()

                val page = out.startPage(info)
                page.canvas.drawBitmap(bitmap, 0f, 0f, Paint())
                drawAnnotations(
                    page.canvas,
                    bitmap.width.toFloat(),
                    bitmap.height.toFloat(),
                    annotations.filter { it.page == i }
                )
                out.finishPage(page)
                bitmap.recycle()
            }

            context.contentResolver.openOutputStream(target).use { output ->
                requireNotNull(output)
                out.writeTo(output!!)
            }
        } finally {
            out.close()
            r.close()
        }
    }

    private fun drawAnnotations(canvas: Canvas, width: Float, height: Float, annotations: List<Annotation>) {
        annotations.forEach { annotation ->
            when (annotation) {
                is Annotation.Pen -> {
                    if (annotation.points.size > 1) {
                        val path = Path()
                        annotation.points.forEachIndexed { index, point ->
                            if (index == 0) path.moveTo(point.x * width, point.y * height)
                            else path.lineTo(point.x * width, point.y * height)
                        }
                        canvas.drawPath(
                            path,
                            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                                color = annotation.color
                                style = Paint.Style.STROKE
                                strokeWidth = annotation.width * 2
                                strokeCap = Paint.Cap.ROUND
                                strokeJoin = Paint.Join.ROUND
                            }
                        )
                    }
                }

                is Annotation.Text -> canvas.drawText(
                    annotation.value,
                    annotation.rect.l * width,
                    annotation.rect.b * height,
                    Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = annotation.color
                        textSize = annotation.size
                    }
                )

                is Annotation.Highlight -> {
                    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = annotation.color
                        style = Paint.Style.FILL
                    }
                    annotation.rects.forEach {
                        canvas.drawRect(
                            it.l * width,
                            it.t * height,
                            it.r * width,
                            it.b * height,
                            paint
                        )
                    }
                }
            }
        }
    }

    fun close() {
        renderer?.close()
        renderer = null
        file.delete()
    }
}
