package com.firstfriday.palefire.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RadioStationsTest {
    @Test
    fun matchesApplePlatformStationCatalog() {
        assertEquals(14, RadioStations.all.size)
        assertEquals(RadioStations.all.size, RadioStations.all.map { it.id }.toSet().size)
        assertEquals(
            listOf(
                "WFMU",
                "KEXP",
                "KCRW",
                "WPRB",
                "WAMU",
                "WETA Classical",
                "Radio 1190",
                "NTS Radio 1",
                "NTS Radio 2",
                "BBC World Service",
                "BBC Radio 1",
                "BBC Radio 2",
                "BBC Radio 3",
                "BBC Radio 4",
            ),
            RadioStations.all.map { it.name },
        )
        assertTrue(RadioStations.all.all { it.url.startsWith("http") })
    }

    @Test
    fun defaultsToWfmuAndSevenMinutes() {
        assertEquals("WFMU", RadioStations.find(GalleryDefaults.STATION_ID)?.name)
        assertEquals(420_000L, GalleryDefaults.IMAGE_DURATION_MILLIS)
    }
}
