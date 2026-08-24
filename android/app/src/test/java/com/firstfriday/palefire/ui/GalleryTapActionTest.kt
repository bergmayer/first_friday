package com.firstfriday.palefire.ui

import org.junit.Assert.assertEquals
import org.junit.Test

class GalleryTapActionTest {
    @Test
    fun `left third goes back`() {
        assertEquals(GalleryTapAction.Back, galleryTapAction(x = 0f, width = 300))
        assertEquals(GalleryTapAction.Back, galleryTapAction(x = 99f, width = 300))
    }

    @Test
    fun `center third opens overlay`() {
        assertEquals(GalleryTapAction.Overlay, galleryTapAction(x = 100f, width = 300))
        assertEquals(GalleryTapAction.Overlay, galleryTapAction(x = 199f, width = 300))
    }

    @Test
    fun `right third advances`() {
        assertEquals(GalleryTapAction.Forward, galleryTapAction(x = 200f, width = 300))
        assertEquals(GalleryTapAction.Forward, galleryTapAction(x = 299f, width = 300))
    }

    @Test
    fun `unknown width safely uses overlay`() {
        assertEquals(GalleryTapAction.Overlay, galleryTapAction(x = 0f, width = 0))
    }
}
