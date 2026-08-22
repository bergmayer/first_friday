package com.firstfriday.palefire.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.URI

class WebDavListingParserTest {
    @Test
    fun parsesSelfDirectoryChildDirectoryAndArtwork() {
        val xml = """
            <?xml version="1.0" encoding="utf-8"?>
            <d:multistatus xmlns:d="DAV:">
              <d:response>
                <d:href>/art/</d:href>
                <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop></d:propstat>
              </d:response>
              <d:response>
                <d:href>/art/High_Renaissance/</d:href>
                <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop></d:propstat>
              </d:response>
              <d:response>
                <d:href>/art/dosso-dossi_jupiter-mercury-and-virtue-1524.jpg</d:href>
                <d:propstat><d:prop><d:resourcetype/></d:prop></d:propstat>
              </d:response>
            </d:multistatus>
        """.trimIndent().toByteArray()

        val entries = WebDavListingParser.parse(xml, URI("http://gallery.local/art/"))

        assertEquals(3, entries.size)
        assertTrue(entries[0].isSelf)
        assertTrue(entries[1].isCollection)
        assertEquals("High_Renaissance", entries[1].name)
        assertFalse(entries[2].isCollection)
        assertEquals("dosso-dossi_jupiter-mercury-and-virtue-1524.jpg", entries[2].name)
    }

    @Test
    fun decodesUtf8AndLegacyPercentEncodedNames() {
        assertEquals(
            "René_Magritte.jpg",
            WebDavListingParser.decodeLastPathComponent("/art/Ren%C3%A9_Magritte.jpg"),
        )
        assertEquals(
            "René_Magritte.jpg",
            WebDavListingParser.decodeLastPathComponent("/art/Ren%E9_Magritte.jpg"),
        )
        assertEquals(
            "Untitled_🖼️.jpg",
            WebDavListingParser.decodeLastPathComponent("/art/Untitled_🖼️.jpg"),
        )
        assertEquals(
            "100%_finished.jpg",
            WebDavListingParser.decodeLastPathComponent("/art/100%_finished.jpg"),
        )
    }

    @Test
    fun resolvesRelativeHrefAgainstRequestedDirectory() {
        val xml = """
            <multistatus xmlns="DAV:">
              <response><href>child/image.jpg</href><propstat><prop><resourcetype/></prop></propstat></response>
            </multistatus>
        """.trimIndent().toByteArray()

        val entry = WebDavListingParser.parse(xml, URI("http://gallery.local/art/"))
            .single()

        assertEquals("http://gallery.local/art/child/image.jpg", entry.uri.toASCIIString())
        assertEquals("image.jpg", entry.name)
    }
}
