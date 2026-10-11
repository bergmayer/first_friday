package com.firstfriday.palefire.data

import org.junit.Assert.*
import org.junit.Test

class ArtworkMetadataTest {
    @Test fun readsLiveServerSchemaAndPrefersDate() {
        assertEquals("The Ghent Altar (detail)\nJan van Eyck, c.1432\nNorthern Renaissance · religious painting",
            ArtworkMetadata.displayText("""
                file: "Northern_Renaissance/altar.jpg"
                title: "The Ghent Altar (detail)"
                artist: "Jan van Eyck"
                year: 1432
                date: "c.1432"
                style: "Northern Renaissance"
                genre: "religious painting"
                wikiart: "https://www.wikiart.org/en/jan-van-eyck/altar"
            """.trimIndent()))
        assertEquals("1432", ArtworkMetadata.displayText("year: 1432"))
    }

    @Test fun supportsYamlQuotingUnicodeAndFoldedScalars() {
        assertEquals("Study: \"Blue\" #1\nO'Keeffe, 1930\nÉcole de Paris",
            ArtworkMetadata.displayText("""
                title: "Study: \"Blue\" #1"
                artist: 'O''Keeffe'
                year: 1930 # comment
                style: >-
                  École de
                  Paris
            """.trimIndent()))
    }

    @Test fun missingNullOrMalformedMetadataIsAbsent() {
        for (yaml in listOf("", "file: image.jpg", "title: null\nartist: ''", "title: [broken", "- title")) {
            assertNull(ArtworkMetadata.displayText(yaml))
        }
        assertEquals("No", ArtworkMetadata.displayText("title: No"))
        assertNull(ArtworkMetadata.displayText("title: " + "a".repeat(65536)))
    }
}
