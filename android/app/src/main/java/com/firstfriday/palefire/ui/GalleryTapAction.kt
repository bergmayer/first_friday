package com.firstfriday.palefire.ui

internal enum class GalleryTapAction {
    Back,
    Overlay,
    Forward,
}

internal fun galleryTapAction(x: Float, width: Int): GalleryTapAction {
    if (width <= 0) return GalleryTapAction.Overlay
    val third = width / 3f
    return when {
        x < third -> GalleryTapAction.Back
        x >= third * 2 -> GalleryTapAction.Forward
        else -> GalleryTapAction.Overlay
    }
}
