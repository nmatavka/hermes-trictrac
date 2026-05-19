package utils

import com.expediagroup.graphql.generator.annotations.GraphQLIgnore
import java.io.File

interface HasFilename {
    val filename: Filename
    val path get() = filename.value
    @GraphQLIgnore fun load() = File(path)
}


@JvmInline value class Filename(val value: String) : HasFilename {
    override val filename get() = this
    override fun toString() = value
}