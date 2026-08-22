package com.firstfriday.palefire.ui

import com.firstfriday.palefire.data.Artwork

internal class ArtworkHistory(private val maximumSize: Int = 500) {
    private val entries = mutableListOf<Artwork>()
    private var currentIndex = -1

    init {
        require(maximumSize > 0)
    }

    fun record(artwork: Artwork) {
        if (currentIndex < entries.lastIndex) {
            entries.subList(currentIndex + 1, entries.size).clear()
        }
        entries += artwork
        if (entries.size > maximumSize) {
            entries.removeAt(0)
        }
        currentIndex = entries.lastIndex
    }

    fun previousCandidate(): Artwork? = entries.getOrNull(currentIndex - 1)

    fun nextCandidate(): Artwork? = entries.getOrNull(currentIndex + 1)

    fun commitPrevious(artwork: Artwork): Boolean {
        if (previousCandidate() != artwork) return false
        currentIndex -= 1
        return true
    }

    fun commitNext(artwork: Artwork): Boolean {
        if (nextCandidate() != artwork) return false
        currentIndex += 1
        return true
    }

    fun clear() {
        entries.clear()
        currentIndex = -1
    }
}
