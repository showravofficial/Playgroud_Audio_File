package com.example.playgroud_audio_file

import android.content.Context
import android.os.Environment
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.storage.StorageManager

class MainActivity : FlutterActivity() {
    private val CHANNEL = "usb_path_reader/usb"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getUsbPath") {
                val usbPath = getUsbPath()
                if (usbPath != null) {
                    result.success(usbPath)
                } else {
                    result.error("UNAVAILABLE", "USB Path not available.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getUsbPath(): String? {
        val storageManager = getSystemService(Context.STORAGE_SERVICE) as StorageManager
        val storageVolumes = storageManager.storageVolumes
        for (volume in storageVolumes) {
            if (volume.isRemovable) {
                val directory = volume.directory
                if (directory != null) {
                    return directory.path
                }
            }
        }
        return Environment.getExternalStorageDirectory().absolutePath
    }
}
