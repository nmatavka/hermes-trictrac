package hse.playerservice.repository

import org.apache.commons.io.filefilter.WildcardFileFilter
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.MediaType
import org.springframework.stereotype.Repository
import org.springframework.web.multipart.MultipartFile
import java.io.File
import java.io.FilenameFilter


@Repository
class UserImageStorage(
    @Value("\${storage.image.path}")
    private val baseDir: String,
) {
    companion object {
        val separator = File.separator
    }

    data class ImageWithExtension(
        val image: ByteArray,
        val extension: String,
    )

    fun storeImage(userId: Long, image: MultipartFile, extension: String) {
        findAllFiles(userId).forEach {
            it.delete()
        }
        image.transferTo(File("$baseDir$separator$userId.$extension"))
    }

    fun getImage(userId: Long): ImageWithExtension {
        val image = findAllFiles(userId).firstOrNull() ?: return ImageWithExtension(ByteArray(0), "")
        val type = when (image.extension) {
            "jpg" -> MediaType.IMAGE_JPEG_VALUE
            "png" -> MediaType.IMAGE_PNG_VALUE
            "jpeg" -> MediaType.IMAGE_JPEG_VALUE
            else -> ""
        }
        return ImageWithExtension(image.readBytes(), type)
    }

    private fun findAllFiles(userId: Long): List<File> {
        val wildcard = WildcardFileFilter.builder().setWildcards("$userId.*").get()
        return File(baseDir).listFiles(wildcard as FilenameFilter)?.toList() ?: emptyList()
    }
}