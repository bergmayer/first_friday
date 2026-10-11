package com.firstfriday.palefire.data

import org.yaml.snakeyaml.LoaderOptions
import org.yaml.snakeyaml.Yaml
import org.yaml.snakeyaml.nodes.MappingNode
import org.yaml.snakeyaml.nodes.ScalarNode
import org.yaml.snakeyaml.nodes.Tag
import java.io.StringReader

/** Reads scalar nodes so titles and dates retain their spelling. No object construction. */
object ArtworkMetadata {
    fun displayText(yaml: String): String? = runCatching {
        if (yaml.length > 64 * 1024) return null
        val options = LoaderOptions().apply {
            codePointLimit = 64 * 1024
            maxAliasesForCollections = 0
            nestingDepthLimit = 10
        }
        val mapping = Yaml(options).compose(StringReader(yaml)) as? MappingNode ?: return null
        val fields = mapping.value.mapNotNull { entry ->
            val key = entry.keyNode as? ScalarNode ?: return@mapNotNull null
            val value = entry.valueNode as? ScalarNode ?: return@mapNotNull null
            if (value.tag == Tag.NULL) return@mapNotNull null
            value.value.trim().takeIf(String::isNotEmpty)?.let { key.value to it }
        }.toMap()
        val attribution = listOfNotNull(fields["artist"], fields["date"] ?: fields["year"])
            .joinToString(", ")
        val details = listOfNotNull(fields["style"], fields["genre"]).joinToString(" · ")
        listOfNotNull(fields["title"], attribution, details).filter(String::isNotEmpty)
            .joinToString("\n").takeIf(String::isNotEmpty)
    }.getOrNull()
}
