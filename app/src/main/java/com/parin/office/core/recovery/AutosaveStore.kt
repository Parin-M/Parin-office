package com.parin.office.core.recovery

import android.content.Context
import java.io.File
import java.nio.charset.StandardCharsets

data class RecoverySnapshot(
    val documentId: String,
    val sourceUri: String,
    val version: Long,
    val payload: String
)

class AutosaveStore(private val context: Context) {
    private val root = File(context.filesDir, "parin-recovery").apply { mkdirs() }
    private val newline = 10.toChar().toString()

    fun write(snapshot: RecoverySnapshot) {
        val safe = snapshot.documentId.replace(Regex("[^A-Za-z0-9._-]"), "_")
        val target = File(root, "$safe.snapshot")
        val temp = File(root, "$safe.tmp")

        val body = buildString {
            append(snapshot.version).append(newline)
            append(snapshot.sourceUri.replace(newline, "%0A")).append(newline)
            append(snapshot.payload)
        }

        temp.writeText(body, StandardCharsets.UTF_8)
        if (target.exists()) target.delete()
        check(temp.renameTo(target)) { "Unable to publish autosave snapshot" }
    }

    fun read(documentId: String): RecoverySnapshot? {
        val safe = documentId.replace(Regex("[^A-Za-z0-9._-]"), "_")
        val file = File(root, "$safe.snapshot")
        if (!file.exists()) return null

        val lines = file.readLines(StandardCharsets.UTF_8)
        if (lines.size < 3) return null

        val version = lines[0].toLongOrNull() ?: return null
        return RecoverySnapshot(
            documentId = documentId,
            sourceUri = lines[1].replace("%0A", newline),
            version = version,
            payload = lines.drop(2).joinToString(newline)
        )
    }

    fun delete(documentId: String) {
        val safe = documentId.replace(Regex("[^A-Za-z0-9._-]"), "_")
        File(root, "$safe.snapshot").delete()
    }

    fun listIds(): List<String> =
        root.listFiles()
            ?.filter { it.extension == "snapshot" }
            ?.map { it.name.removeSuffix(".snapshot") }
            ?.sorted()
            .orEmpty()
}
