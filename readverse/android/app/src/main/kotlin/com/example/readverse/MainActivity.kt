package com.example.readverse

import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.readverse/audio_latency"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getAudioLatency") {
                    val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
                    // Query hardware output latency in milliseconds
                    // Using string literal for SDK compatibility
                    val outputLatencyMs = audioManager
                        .getProperty("android.media.property.OUTPUT_LATENCY")
                        ?.toIntOrNull() ?: 100
                    result.success(outputLatencyMs)
                } else {
                    result.notImplemented()
                }
            }
    }
}
