package com.firstfriday.palefire.data

import kotlinx.coroutines.runBlocking
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.*
import org.junit.Test

class WebDavSidecarTest {
    @Test fun listsOnlyImagesAndLoadsSidecarWithCredentials() = runBlocking {
        val requested = mutableListOf<String>()
        val http = OkHttpClient.Builder().addInterceptor { chain ->
            val request = chain.request()
            assertNotNull(request.header("Authorization"))
            requested += request.method + " " + request.url.encodedPath
            val body = if (request.method == "PROPFIND") {
                val files = if (request.url.encodedPath == "/art/") listOf("sub/") else
                    listOf("painting%20one.JPG", "painting%20one.JPG.yaml", "other.yml", "notes.txt")
                "<multistatus xmlns=\"DAV:\">" + files.joinToString("") {
                    "<response><href>$it</href><propstat><prop><resourcetype>" +
                        (if (it.endsWith('/')) "<collection/>" else "") +
                        "</resourcetype></prop></propstat></response>"
                } + "</multistatus>"
            } else "title: A painting\nartist: An artist\nyear: 1900"
            Response.Builder().request(request).protocol(Protocol.HTTP_1_1).code(200)
                .message("OK").body(body.toResponseBody()).build()
        }.build()
        val client = WebDavClient(ServerSettings("http://gallery.local/art/", "reader", "secret"), http)
        val images = client.listAllImages()
        assertEquals(listOf("sub/painting one.JPG"), images.map { it.displayPath })
        assertEquals(2, requested.size) // No sidecar downloads during recursive scan.
        assertEquals("A painting\nAn artist, 1900", client.metadata(images.single().url))
        assertEquals("GET /art/sub/painting%20one.JPG.yaml", requested.last())
    }

    @Test fun absentSidecarDoesNotFailArtworkLoading() = runBlocking {
        val http = OkHttpClient.Builder().addInterceptor { chain ->
            Response.Builder().request(chain.request()).protocol(Protocol.HTTP_1_1).code(404)
                .message("Not found").body("".toResponseBody()).build()
        }.build()
        assertNull(WebDavClient(ServerSettings("http://gallery.local/", "", ""), http)
            .metadata("http://gallery.local/art.jpg"))
    }
}
