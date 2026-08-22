package com.firstfriday.palefire.data

import org.w3c.dom.Element
import java.io.ByteArrayInputStream
import java.net.URI
import java.nio.charset.Charset
import javax.xml.parsers.DocumentBuilderFactory

internal data class WebDavEntry(
    val uri: URI,
    val name: String,
    val isCollection: Boolean,
    val isSelf: Boolean,
)

internal object WebDavListingParser {
    fun parse(data: ByteArray, requestedUri: URI): List<WebDavEntry> {
        val factory = DocumentBuilderFactory.newInstance().apply {
            isNamespaceAware = true
            setExpandEntityReferences(false)
            setFeatureIfSupported("http://apache.org/xml/features/disallow-doctype-decl", true)
            setFeatureIfSupported("http://xml.org/sax/features/external-general-entities", false)
            setFeatureIfSupported("http://xml.org/sax/features/external-parameter-entities", false)
        }
        val document = factory.newDocumentBuilder().parse(ByteArrayInputStream(data))
        val responses = document.getElementsByTagNameNS("*", "response")
        return buildList(responses.length) {
            for (index in 0 until responses.length) {
                val response = responses.item(index) as? Element ?: continue
                val href = response.getElementsByTagNameNS("*", "href")
                    .item(0)?.textContent?.trim().orEmpty()
                if (href.isEmpty()) continue
                val uri = resolve(requestedUri, href)
                val isCollection =
                    response.getElementsByTagNameNS("*", "collection").length > 0
                add(
                    WebDavEntry(
                        uri = uri,
                        name = decodeLastPathComponent(href),
                        isCollection = isCollection,
                        isSelf = normalizedPath(uri) == normalizedPath(requestedUri),
                    ),
                )
            }
        }
    }

    private fun DocumentBuilderFactory.setFeatureIfSupported(name: String, value: Boolean) {
        runCatching { setFeature(name, value) }
    }

    private fun resolve(requestedUri: URI, href: String): URI {
        val safeHref = href.replace(" ", "%20")
        val candidate = URI(safeHref)
        return if (candidate.isAbsolute) candidate else requestedUri.resolve(candidate)
    }

    private fun normalizedPath(uri: URI): String =
        decodePercent(uri.rawPath.orEmpty()).trim('/')

    internal fun decodeLastPathComponent(href: String): String {
        val path = href.substringBefore('?').substringBefore('#').trimEnd('/')
        return decodePercent(path.substringAfterLast('/'))
    }

    internal fun decodePercent(encoded: String): String {
        val bytes = ArrayList<Byte>(encoded.length)
        var index = 0
        while (index < encoded.length) {
            if (encoded[index] == '%' && index + 2 < encoded.length) {
                val value = encoded.substring(index + 1, index + 3).toIntOrNull(16)
                if (value != null) {
                    bytes.add(value.toByte())
                    index += 3
                    continue
                }
            }
            if (encoded[index] == '%') {
                bytes.add('%'.code.toByte())
                index += 1
                continue
            }
            val nextEscape = encoded.indexOf('%', startIndex = index).let {
                if (it == -1) encoded.length else it
            }
            encoded.substring(index, nextEscape)
                .toByteArray(Charsets.UTF_8)
                .forEach(bytes::add)
            index = nextEscape
        }
        val data = bytes.toByteArray()
        val utf8 = Charsets.UTF_8.newDecoder().runCatching { decode(data.asByteBuffer()).toString() }
            .getOrNull()
        if (utf8 != null) return utf8
        return String(data, Charset.forName("windows-1252"))
    }

    private fun ByteArray.asByteBuffer() = java.nio.ByteBuffer.wrap(this)
}
