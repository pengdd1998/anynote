package com.anynote.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import java.io.File
import java.io.FileOutputStream
import io.flutter.embedding.android.FlutterActivity

/// Activity that receives ACTION_SEND intents from other apps.
///
/// When the user shares text, a URL, or an image from any app, Android
/// launches this activity. The shared content is persisted in SharedPreferences
/// as JSON and the main Flutter app is started (or brought to the foreground)
/// via MainActivity with a deep link. The Flutter side reads the pending share
/// data via the MethodChannel `com.anynote.app/share`.
///
/// Supported MIME types:
///   - text/plain   -> extra text (may contain a URL)
///   - image/*      -> content URI copied to app cache
///   - application/* -> content URI copied to app cache
class ShareActivity : FlutterActivity() {

    companion object {
        private const val PREFS_NAME = "anynote_share"
        private const val KEY_PENDING_SHARE = "pending_share"
        private const val KEY_PENDING_SHARE_TIMESTAMP = "pending_share_timestamp"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val sharedData = extractSharedContent(intent)
        if (sharedData != null) {
            val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            prefs.edit()
                .putString(KEY_PENDING_SHARE, sharedData)
                .putLong(KEY_PENDING_SHARE_TIMESTAMP, System.currentTimeMillis())
                .apply()
        }

        val mainIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            action = Intent.ACTION_VIEW
            data = Uri.parse("anynote://share/received")
        }
        startActivity(mainIntent)
        finish()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    @Suppress("DEPRECATION")
    private fun extractSharedContent(intent: Intent): String? {
        when (intent.action) {
            Intent.ACTION_SEND -> {
                val mimeType = intent.type ?: return null

                if (mimeType.startsWith("text/")) {
                    val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                    if (!text.isNullOrBlank()) {
                        val escapedText = text
                            .replace("\\", "\\\\")
                            .replace("\"", "\\\"")
                            .replace("\n", "\\n")
                            .replace("\r", "\\r")
                            .replace("\t", "\\t")
                        return "{\"type\":\"text\",\"text\":\"$escapedText\"}"
                    }
                    return null
                }

                if (mimeType.startsWith("image/") || mimeType.startsWith("application/")) {
                    val uri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                    } else {
                        intent.getParcelableExtra(Intent.EXTRA_STREAM)
                    }
                    if (uri != null) {
                        val localPath = copyToCache(uri)
                        if (localPath != null) {
                            val kind = if (mimeType.startsWith("image/")) "image" else "file"
                            return "{\"type\":\"$kind\",\"path\":\"$localPath\"}"
                        }
                    }
                    return null
                }
            }
        }
        return null
    }

    private fun copyToCache(uri: Uri): String? {
        return try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            val fileName = "share_${System.currentTimeMillis()}"
            val outFile = File(cacheDir, fileName)
            val outputStream = FileOutputStream(outFile)
            inputStream.copyTo(outputStream)
            inputStream.close()
            outputStream.close()
            outFile.absolutePath
        } catch (e: Exception) {
            null
        }
    }
}
