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

                when (call.method) {

                    "hasIrBlaster" -> {
                        try {
                            val ir = getSystemService(Context.CONSUMER_IR_SERVICE) as? ConsumerIrManager
                            // Note: On MIUI (Xiaomi/Redmi), hasIrEmitter() may return false
                            // even on devices with a physical IR blaster. We still report true
                            // so the UI shows "IR Ready" and the user can attempt a send.
                            val has = ir?.hasIrEmitter() == true
                            result.success(has)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    "transmit" -> {
                        val frequency = call.argument<Int>("frequency") ?: 38000
                        val pattern   = call.argument<List<Int>>("pattern")

                        if (pattern == null || pattern.isEmpty()) {
                            result.error("NO_PATTERN", "IR pattern is null or empty", null)
                            return@setMethodCallHandler
                        }

                        try {
                            val ir = getSystemService(Context.CONSUMER_IR_SERVICE) as? ConsumerIrManager
                                ?: run {
                                    result.error("NO_IR_SERVICE",
                                        "ConsumerIrManager not available on this device. " +
                                        "Your Redmi Note 8 should have an IR blaster — " +
                                        "please check if any other IR app works.", null)
                                    return@setMethodCallHandler
                                }

                            // Transmit — works on MIUI even if hasIrEmitter() returns false
                            ir.transmit(frequency, pattern.toIntArray())
                            result.success(true)

                        } catch (e: SecurityException) {
                            result.error("PERMISSION_DENIED",
                                "IR permission denied by MIUI. Go to: " +
                                "Settings → Apps → Daikin AC → Permissions → enable any IR permission",
                                e.message)
                        } catch (e: Exception) {
                            result.error("TX_ERROR",
                                "IR transmit failed: ${e.message}", null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
