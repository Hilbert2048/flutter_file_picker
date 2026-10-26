package com.mr.flutter.plugin.filepicker

import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.util.Log

/** Owns only new permission bits acquired by one reference selection. */
internal class ReferenceGrantSession(
    private val resolver: ContentResolver,
    private val options: SafOptions,
) {
    private val acquired = NewGrantTracker<Uri> { uri, flags ->
        resolver.releasePersistableUriPermission(uri, flags)
    }

    fun take(uri: Uri) {
        if (!options.persistsGrant) return
        val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
            (if (options.readWrite) Intent.FLAG_GRANT_WRITE_URI_PERMISSION else 0)
        val before = if (options.cacheFiles) 0 else resolver.persistedUriPermissions
            .firstOrNull { it.uri == uri }?.let {
                (if (it.isReadPermission) Intent.FLAG_GRANT_READ_URI_PERMISSION else 0) or
                    (if (it.isWritePermission) Intent.FLAG_GRANT_WRITE_URI_PERMISSION else 0)
            } ?: 0
        try {
            resolver.takePersistableUriPermission(uri, flags)
            if (!options.cacheFiles) {
                acquired.record(uri, flags, before)
            }
        } catch (_: SecurityException) {
            if (!options.cacheFiles) {
                rollback()
                throw ReferenceAccessDenied()
            }
            // Preserve legacy cached-selection behavior, without private URIs.
            Log.w("FilePicker", "Unable to persist document access")
        }
    }

    fun rollback() {
        acquired.rollback()
    }
}

internal class ReferenceAccessDenied : Exception("Unable to persist document access")

/** Pure ownership policy: failed selections never revoke an older grant. */
internal class NewGrantTracker<Key>(private val release: (Key, Int) -> Unit) {
    private val added = mutableMapOf<Key, Int>()

    fun record(key: Key, requested: Int, existing: Int) {
        val bits = requested and existing.inv()
        if (bits != 0) added[key] = (added[key] ?: 0) or bits
    }

    fun rollback() {
        for ((key, bits) in added) runCatching { release(key, bits) }
        added.clear()
    }
}
