package com.firstfriday.palefire.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.Credentials
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.MediaType.Companion.toMediaType
import java.io.IOException
import java.net.URI
import java.util.concurrent.TimeUnit

class WebDavClient(
    settings: ServerSettings,
    private val httpClient: OkHttpClient = defaultClient(),
) {
    private val baseUri = normalizeServerUrl(settings.serverUrl)
    private val authorization = Credentials.basic(
        settings.username,
        settings.password,
        Charsets.UTF_8,
    )

    suspend fun listAllImages(): List<Artwork> = withContext(Dispatchers.IO) {
        val images = mutableListOf<Artwork>()
        walk(baseUri, "", images, mutableSetOf())
        images
    }

    suspend fun download(url: String): ByteArray = withContext(Dispatchers.IO) {
        val uri = URI(url)
        requireSameOrigin(uri)
        execute(
            Request.Builder()
                .url(uri.toASCIIString())
                .header("Authorization", authorization)
                .get()
                .build(),
        )
    }

    private fun walk(
        uri: URI,
        relativePath: String,
        images: MutableList<Artwork>,
        visited: MutableSet<String>,
    ) {
        requireSameOrigin(uri)
        val visitKey = uri.normalize().toASCIIString().trimEnd('/')
        if (!visited.add(visitKey)) return

        propfind(uri).filterNot(WebDavEntry::isSelf).forEach { entry ->
            requireSameOrigin(entry.uri)
            val nextPath = if (relativePath.isEmpty()) {
                entry.name
            } else {
                "$relativePath/${entry.name}"
            }
            if (entry.isCollection) {
                walk(entry.uri, nextPath, images, visited)
            } else if (entry.name.substringAfterLast('.', "").lowercase() in IMAGE_EXTENSIONS) {
                images += Artwork(entry.uri.toASCIIString(), nextPath)
            }
        }
    }

    private fun propfind(uri: URI): List<WebDavEntry> {
        val request = Request.Builder()
            .url(uri.toASCIIString())
            .header("Authorization", authorization)
            .header("Depth", "1")
            .method(
                "PROPFIND",
                PROPFIND_BODY.toRequestBody("application/xml; charset=utf-8".toMediaType()),
            )
            .build()
        return WebDavListingParser.parse(execute(request), uri)
    }

    private fun execute(request: Request): ByteArray =
        httpClient.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                throw IOException("Server returned status ${response.code}")
            }
            response.body.bytes()
        }

    private fun requireSameOrigin(uri: URI) {
        if (
            !uri.scheme.equals(baseUri.scheme, ignoreCase = true) ||
            !uri.host.equals(baseUri.host, ignoreCase = true) ||
            effectivePort(uri) != effectivePort(baseUri)
        ) {
            throw IOException("Server returned a URL on a different host")
        }
    }

    private fun effectivePort(uri: URI): Int = when {
        uri.port != -1 -> uri.port
        uri.scheme.equals("https", ignoreCase = true) -> 443
        else -> 80
    }

    companion object {
        private val IMAGE_EXTENSIONS = setOf(
            "jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "bmp", "tiff", "tif",
        )

        private const val PROPFIND_BODY =
            """<?xml version="1.0" encoding="utf-8"?>
<propfind xmlns="DAV:"><prop><resourcetype/></prop></propfind>"""

        fun normalizeServerUrl(value: String): URI {
            var normalized = value.trim()
            if (!normalized.startsWith("http://", true) &&
                !normalized.startsWith("https://", true)
            ) {
                normalized = "http://$normalized"
            }
            if (!normalized.endsWith('/')) normalized += "/"
            val uri = runCatching { URI(normalized.replace(" ", "%20")) }
                .getOrElse { throw IllegalArgumentException("Invalid server URL") }
            require(uri.scheme.equals("http", true) || uri.scheme.equals("https", true)) {
                "Server URL must use HTTP or HTTPS"
            }
            require(!uri.host.isNullOrBlank()) { "Invalid server URL" }
            return uri
        }

        private fun defaultClient() = OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(45, TimeUnit.SECONDS)
            .callTimeout(60, TimeUnit.SECONDS)
            .build()
    }
}
