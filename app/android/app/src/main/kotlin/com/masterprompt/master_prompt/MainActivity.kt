package com.masterprompt.master_prompt

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * The one job the Dart side cannot do for itself: hand a downloaded APK to the
 * system package installer.
 *
 * Deliberately a single method. Everything about *which* build to install, and
 * whether one is needed at all, is decided in Dart where it can be tested; this
 * is only the last three lines of it, which no test on a Linux runner could
 * ever cover.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "install" -> result.success(install(call.argument<String>("path")))
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
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
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

    private companion object {
        const val CHANNEL = "masterprompt/updates"
    }
}
