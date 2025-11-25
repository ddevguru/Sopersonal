package com.devloperwala.play_smart

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.devloperwala.play_smart/upi"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchUpi" -> {
                    val packageName = call.argument<String>("packageName")
                    val uri = call.argument<String>("uri")
                    if (uri.isNullOrEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri)).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            if (!packageName.isNullOrEmpty()) {
                                setPackage(packageName)
                            }
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("UPI_Launch", "Failed to launch UPI app: ${e.message}")
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}