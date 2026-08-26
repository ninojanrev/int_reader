package com.example.epub_reader

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.view.KeyEvent
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var volumeEvents: EventChannel.EventSink? = null

    private val storagePermissionRequestCode = 4711

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "int_reader/volume_keys"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                volumeEvents = events
            }

            override fun onCancel(arguments: Any?) {
                volumeEvents = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "int_reader/storage"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "ensureStorageAccess" -> {
                    if (hasStorageAccess()) {
                        result.success(true)
                    } else {
                        pendingStorageResult = result
                        requestStorageAccess()
                    }
                }
                "hasStorageAccess" -> result.success(hasStorageAccess())
                else -> result.notImplemented()
            }
        }
    }

    private fun hasStorageAccess(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            ContextCompat.checkSelfPermission(
                this, Manifest.permission.READ_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestStorageAccess() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Send the user to the system "All files access" toggle for our app.
            val intent = Intent(
                Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                Uri.parse("package:$packageName")
            )
            try {
                startActivity(intent)
            } catch (e: Exception) {
                startActivity(
                    Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                )
            }
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE),
                storagePermissionRequestCode
            )
        }
    }

    private var pendingStorageResult: MethodChannel.Result? = null

    override fun onResume() {
        super.onResume()
        // Returning from the All-files-access settings page: report the new state.
        pendingStorageResult?.let { result ->
            pendingStorageResult = null
            result.success(hasStorageAccess())
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == storagePermissionRequestCode) {
            pendingStorageResult?.let { result ->
                pendingStorageResult = null
                result.success(grantResults.isNotEmpty() &&
                        grantResults[0] == PackageManager.PERMISSION_GRANTED)
            }
        }
    }

    /// Forward volume keys to Dart and consume them so the system volume
    /// stays unchanged while reading. Everything else behaves normally.
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    volumeEvents?.success("up")
                    return true
                }
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    volumeEvents?.success("down")
                    return true
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }
}
