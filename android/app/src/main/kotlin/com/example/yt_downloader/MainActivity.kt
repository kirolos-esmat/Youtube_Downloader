package com.example.yt_downloader

import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val CHANNEL = "yt_downloader_channel"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setExecutable" -> handleSetExecutable(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handleSetExecutable(call: MethodCall, result: MethodChannel.Result) {
        try {
            val path = call.argument<String>("path") ?: throw IllegalArgumentException("Missing path parameter")
            
            Log.d("YT_DLP", "Attempting to set permissions for: $path")
            
            // Verify file exists first
            if (!fileExists(path)) {
                throw IOException("File does not exist at path: $path")
            }

            // Set executable permissions
            val chmodProcess = Runtime.getRuntime().exec(arrayOf("chmod", "755", path))
            val exitCode = chmodProcess.waitFor()
            
            if (exitCode == 0) {
                Log.d("YT_DLP", "Successfully set permissions for $path")
                result.success(true)
            } else {
                val error = getProcessError(chmodProcess)
                throw IOException("chmod failed with exit code $exitCode: $error")
            }
        } catch (e: Exception) {
            Log.e("YT_DLP", "Error setting permissions", e)
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }

    private fun fileExists(path: String): Boolean {
        return try {
            Runtime.getRuntime().exec(arrayOf("ls", path)).waitFor() == 0
        } catch (e: IOException) {
            false
        }
    }

    private fun getProcessError(process: Process): String {
        return try {
            process.errorStream.bufferedReader().use { it.readText() }
        } catch (e: IOException) {
            "Unable to read error stream: ${e.message}"
        }
    }
}