package com.masterprompt.master_prompt

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * The three jobs the Dart side cannot do for itself: hand a downloaded APK to
 * the package installer, put a file into the share sheet, and write one out to
 * wherever the user keeps their documents.
 *
 * All three are plumbing. Which file, what it is called and what is in it are
 * decided in Dart, where they can be tested; none of this can be covered by a
 * test on a Linux runner, so it is kept as thin as it will go.
 */
class MainActivity : FlutterActivity() {

    private var pendingSave: MethodChannel.Result? = null
    private var pendingSaveSource: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "install" -> result.success(install(call.argument<String>("path")))
                    "share" -> result.success(
                        share(
                            call.argument<String>("path"),
                            call.argument<String>("text").orEmpty(),
                        )
                    )
                    // Answers with one of "downloads", "chosen", "cancelled"
                    // or "failed", matching the `SaveOutcome` Dart switches on.
                    "save" -> save(
                        call.argument<String>("path"),
                        call.argument<String>("name").orEmpty(),
                        result,
                    )
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Returns one of `handedOver`, `needsPermission` or `manual`, matching the
     * `InstallOutcome` the Dart side switches on.
     */
    private fun install(path: String?): String {
        val file = path?.let { File(it) } ?: return "manual"
        if (!file.exists()) return "manual"

        // Since Android O an app may not install packages until it has been
        // granted the right, and the grant is a settings screen rather than a
        // runtime dialog. Send the user there and let them come back, rather
        // than failing silently with nothing on screen to explain it.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            try {
                startActivity(
                    Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                        .setData(Uri.parse("package:$packageName"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            } catch (e: Exception) {
                // Some builds have no such screen. The message the Dart side
                // shows for this outcome still tells the user what to allow.
            }
            return "needsPermission"
        }

        // A `file://` URI has been rejected since Android N, so the installer
        // is given a content URI backed by res/xml/file_paths.xml instead.
        val uri = FileProvider.getUriForFile(this, "$packageName$AUTHORITY_SUFFIX", file)
        return try {
            startActivity(
                Intent(Intent.ACTION_VIEW)
                    .setDataAndType(uri, "application/vnd.android.package-archive")
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            "handedOver"
        } catch (e: Exception) {
            "manual"
        }
    }

    /**
     * Offers [path] to the share sheet with [text] as the accompanying message.
     *
     * The point of the attachment is that a chat input has a length limit and a
     * file does not: the covering instruction goes in [text], the twenty
     * thousand characters of brief go in the file. `text/plain` because it is
     * the type nearly every app that takes a document registers for; a narrower
     * one would leave the sheet empty on some devices.
     */
    private fun share(path: String?, text: String): Boolean {
        val file = path?.let { File(it) } ?: return false
        if (!file.exists()) return false

        return try {
            val uri = FileProvider.getUriForFile(this, "$packageName$AUTHORITY_SUFFIX", file)
            val send = Intent(Intent.ACTION_SEND)
                .setType("text/plain")
                .putExtra(Intent.EXTRA_STREAM, uri)
                .putExtra(Intent.EXTRA_TEXT, text)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            startActivity(
                Intent.createChooser(send, null)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Writes [path] out under the name [name], for the user to attach by hand.
     *
     * This is the default route, not the fallback: a share always opens a new
     * conversation — the receiving app decides that and an `ACTION_SEND` intent
     * carries no way to say otherwise — so a file is the only way to put a
     * brief into a chat that already exists.
     *
     * Straight into Downloads where that is possible, because a dialog on every
     * send is exactly the kind of step this whole thread of work has been
     * removing. Returns which route it took: "Saved to Downloads" and "Saved as
     * *name*" are different things to tell someone who now has to find the file.
     */
    private fun save(path: String?, name: String, result: MethodChannel.Result) {
        val file = path?.let { File(it) }
        if (file == null || !file.exists()) {
            result.success("failed")
            return
        }
        val title = name.ifEmpty { file.name }

        // Since Android 10 an app may write into the shared Downloads
        // collection with no permission at all. Below that it would need
        // WRITE_EXTERNAL_STORAGE, which is far too much to ask for one file, so
        // those devices get the picker instead.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            toDownloads(file, title)
        ) {
            result.success("downloads")
            return
        }

        // Only one save can be in flight, and a stale pending result would
        // strand the Dart side waiting forever.
        pendingSave?.success("cancelled")
        pendingSave = result
        pendingSaveSource = file

        try {
            startActivityForResult(
                Intent(Intent.ACTION_CREATE_DOCUMENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("text/plain")
                    .putExtra(Intent.EXTRA_TITLE, title),
                SAVE_REQUEST,
            )
        } catch (e: Exception) {
            pendingSave = null
            pendingSaveSource = null
            result.success("failed")
        }
    }

    /**
     * Copies [file] into the shared Downloads collection. False if anything
     * refuses, so the caller can fall through to the picker rather than the
     * user being told it simply did not work.
     */
    private fun toDownloads(file: File, title: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        return try {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, title)
                put(MediaStore.Downloads.MIME_TYPE, "text/plain")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val collection = MediaStore.Downloads.getContentUri(
                MediaStore.VOLUME_EXTERNAL_PRIMARY
            )
            val uri = contentResolver.insert(collection, values) ?: return false
            contentResolver.openOutputStream(uri)?.use { out ->
                file.inputStream().use { it.copyTo(out) }
            } ?: return false
            // Left pending until the bytes are there, so nothing can open a
            // half-written brief.
            contentResolver.update(
                uri,
                ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) },
                null,
                null,
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != SAVE_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingSave
        val source = pendingSaveSource
        pendingSave = null
        pendingSaveSource = null

        val uri = data?.data
        if (result == null) return
        if (resultCode != Activity.RESULT_OK || uri == null || source == null) {
            // Cancelling the picker is an ordinary outcome, not a failure.
            result.success("cancelled")
            return
        }
        result.success(
            try {
                if (contentResolver.openOutputStream(uri)?.use { out ->
                        source.inputStream().use { it.copyTo(out) }
                    } != null
                ) {
                    "chosen"
                } else {
                    "failed"
                }
            } catch (e: Exception) {
                "failed"
            }
        )
    }

    private companion object {
        const val CHANNEL = "masterprompt/platform"
        const val AUTHORITY_SUFFIX = ".fileprovider"
        const val SAVE_REQUEST = 0x4D50
    }
}
