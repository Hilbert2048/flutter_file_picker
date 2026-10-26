package com.mr.flutter.plugin.filepicker

import org.junit.Assert.assertEquals
import org.junit.Test

class NewGrantTrackerTest {
    @Test
    fun rollbackReleasesOnlyNewBitsAndIsIdempotent() {
        val released = mutableListOf<Pair<String, Int>>()
        val tracker = NewGrantTracker<String> { key, flags -> released.add(key to flags) }
        tracker.record("existing-read", 3, 1)
        tracker.record("existing-read", 3, 3)
        tracker.record("new-read", 1, 0)
        tracker.record("already-owned", 1, 1)
        tracker.rollback()
        tracker.rollback()
        assertEquals(listOf("existing-read" to 2, "new-read" to 1), released)
    }
}
