package com.mr.flutter.plugin.filepicker

import android.content.Context
import android.database.Cursor
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.FileNotFoundException
import java.util.concurrent.Executors
import android.os.Handler
import android.os.Looper

/** SAF reads only. No streams are copied into cache; tree grants cover children. */
internal class DocumentReferenceAccess(private val context: Context) {
    private val executor = Executors.newSingleThreadExecutor()
    fun close() { executor.shutdown() }
    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        if (call.method !in listOf("documentDescribe", "documentChildren", "documentMetadata")) return false
        val raw = call.argument<String>("uri") ?: run {
            result.error("invalid_arguments", "Missing document URI", null); return true
        }
        executor.execute {
            try {
                val uri = Uri.parse(raw)
                val value: Any = when (call.method) {
                    "documentChildren" -> children(uri)
                    "documentMetadata" -> metadata(uri)
                    else -> describe(uri)
                }
                Handler(Looper.getMainLooper()).post { result.success(value) }
            } catch (error: Exception) {
                val code = when(error) {
                    is SecurityException -> "permission_denied"
                    is FileNotFoundException -> "not_found"
                    is IllegalArgumentException -> "unsupported_format"
                    else -> "provider_unavailable"
                }
                Handler(Looper.getMainLooper()).post { result.error(code, "Document access failed", null) }
            }
        }
        return true
    }
    private fun documentUri(uri: Uri): Uri = if (DocumentsContract.isTreeUri(uri) && !uri.path.orEmpty().contains("/document/"))
        DocumentsContract.buildDocumentUriUsingTree(uri, DocumentsContract.getTreeDocumentId(uri)) else uri
    private val projection = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
        DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE)
    private fun row(uri: Uri, cursor: Cursor): Map<String, Any> {
        val id = cursor.getString(0)
        return mapOf("identity" to "${uri.authority}/$id", "uri" to uri.toString(),
            "name" to cursor.getString(1), "directory" to (cursor.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR))
    }
    private fun describe(source: Uri): Map<String, Any> {
        val uri = documentUri(source)
        return context.contentResolver.query(uri, projection, null, null, null)?.use {
            if (!it.moveToFirst()) throw FileNotFoundException()
            row(uri, it)
        } ?: throw FileNotFoundException()
    }
    private fun children(source: Uri): List<Map<String, Any>> {
        val root = documentUri(source)
        val query = DocumentsContract.buildChildDocumentsUriUsingTree(root, DocumentsContract.getDocumentId(root))
        return context.contentResolver.query(query, projection, null, null, null)?.use {
            val rows = mutableListOf<Map<String, Any>>()
            while (it.moveToNext()) {
                val child = DocumentsContract.buildDocumentUriUsingTree(root, it.getString(0))
                rows.add(row(child, it))
            }
            rows
        } ?: throw FileNotFoundException()
    }
    private fun metadata(uri: Uri): Map<String, Any> {
        val reader = MediaMetadataRetriever()
        try {
            reader.setDataSource(context, uri)
            val values = mutableMapOf<String, Any>()
            for ((name, key) in mapOf("title" to MediaMetadataRetriever.METADATA_KEY_TITLE,
                "artist" to MediaMetadataRetriever.METADATA_KEY_ARTIST, "album" to MediaMetadataRetriever.METADATA_KEY_ALBUM,
                "duration" to MediaMetadataRetriever.METADATA_KEY_DURATION)) {
                reader.extractMetadata(key)?.let { values[name] = it }
            }
            reader.embeddedPicture?.takeIf { it.size <= 8 * 1024 * 1024 }?.let { values["artwork"] = it }
            return values
        } finally { reader.release() }
    }
}
