package com.daikin.accontroller

import android.content.Context
import android.hardware.ConsumerIrManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.daikin.accontroller/ir"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val irManager = getSystemService(Context.CONSUMER_IR_SERVICE) as? ConsumerIrManager

                when (call.method) {
                    "hasIrBlaster" -> {
                        result.success(irManager?.hasIrEmitter() == true)
                    }
                    "transmit" -> {
                        if (irManager == null || !irManager.hasIrEmitter()) {
                            result.error("NO_IR", "No IR emitter found on this device", null)
                            return@setMethodCallHandler
                        }
                        val frequency = call.argument<Int>("frequency") ?: 38000
                        val pattern   = call.argument<List<Int>>("pattern")
                        if (pattern == null) {
                            result.error("NO_PATTERN", "IR pattern is null", null)
                            return@setMethodCallHandler
                        }
                        try {
                            irManager.transmit(frequency, pattern.toIntArray())
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("TX_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
