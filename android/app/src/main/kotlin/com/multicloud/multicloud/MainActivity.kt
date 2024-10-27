package com.multicloud.multicloud

import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val CHANNEL = "file_manager"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "moveToTrash") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    val success = moveToTrash(filePath)
                    if (success) {
                        result.success(null)
                    } else {
                        result.error("ERROR", "Failed to delete file", null)
                    }
                } else {
                    result.error("ERROR", "Invalid file path", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun moveToTrash(filePath: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {  // Android 11+
            val file = File(filePath)
            val uri: Uri = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.RELATIVE_PATH, file.parent)
                put(MediaStore.MediaColumns.IS_TRASHED, 1)  // Mark the file as trashed
            }

            val resolver = applicationContext.contentResolver
            val rowsUpdated = resolver.update(
                uri,
                contentValues,
                "${MediaStore.MediaColumns.DATA}=?",
                arrayOf(filePath)
            )

            return rowsUpdated > 0
        } else {
            // Fallback to deletion for older versions (no trash feature pre-Android 11)
            return File(filePath).delete()
        }
    }
}
