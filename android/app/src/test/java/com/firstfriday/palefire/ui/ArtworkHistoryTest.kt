package com.firstfriday.palefire.ui

import com.firstfriday.palefire.data.Artwork
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ArtworkHistoryTest {
    private val first = Artwork("https://example.test/first.jpg", "first.jpg")
    private val second = Artwork("https://example.test/second.jpg", "second.jpg")
    private val third = Artwork("https://example.test/third.jpg", "third.jpg")

    @Test
    fun movesBackAndForwardThroughRecordedArtwork() {
        val history = ArtworkHistory()
        history.record(first)
        history.record(second)
        history.record(third)

        assertEquals(second, history.previousCandidate())
        assertTrue(history.commitPrevious(second))
        assertEquals(first, history.previousCandidate())
        assertEquals(third, history.nextCandidate())
        assertTrue(history.commitNext(third))
        assertNull(history.nextCandidate())
    }

    @Test
    fun rejectedCommitDoesNotMoveHistory() {
        val history = ArtworkHistory()
        history.record(first)
        history.record(second)

        assertFalse(history.commitPrevious(third))
        assertEquals(first, history.previousCandidate())
        assertNull(history.nextCandidate())
    }

    @Test
    fun recordingAfterGoingBackReplacesForwardHistory() {
        val history = ArtworkHistory()
        history.record(first)
        history.record(second)
        assertTrue(history.commitPrevious(first))

        history.record(third)

        assertEquals(first, history.previousCandidate())
        assertNull(history.nextCandidate())
    }

    @Test
    fun limitsStoredHistory() {
        val history = ArtworkHistory(maximumSize = 2)
        history.record(first)
        history.record(second)
        history.record(third)

        assertEquals(second, history.previousCandidate())
        assertTrue(history.commitPrevious(second))
        assertNull(history.previousCandidate())
    }
}
