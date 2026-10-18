package com.mr.flutter.plugin.filepicker

import org.junit.Assert.assertEquals
import org.junit.Test

class SavedFileNameTest {
    private fun parse(currentName: String, extension: String) =
        SavedFileName.baseNameAndSuffix(currentName, extension)

    @Test
    fun plainName() {
        assertEquals("report" to null, parse("report.pdf", "pdf"))
    }

    @Test
    fun androidDuplicateStyle() {
        assertEquals("report" to 1, parse("report.pdf (1)", "pdf"))
    }

    @Test
    fun normalizedDuplicateStyle() {
        assertEquals("report" to 2, parse("report (2).pdf", "pdf"))
    }

    @Test
    fun stackedDuplicateSuffixesAreMerged() {
        assertEquals("report" to 2, parse("report (1) (1).pdf", "pdf"))
    }

    // The system picker appended its own extension for a type it did not
    // know, which used to end up as "trace.gpx.xml.gpx" (#2199).
    @Test
    fun extensionAppendedBySystemIsDropped() {
        assertEquals("trace" to null, parse("trace.gpx.xml", "gpx"))
    }

    @Test
    fun extensionIsMatchedLiterally() {
        assertEquals("notes" to null, parse("notes.c++", "c++"))
    }

    @Test
    fun unrelatedNameIsKept() {
        assertEquals("other.txt" to null, parse("other.txt", "pdf"))
    }
}
