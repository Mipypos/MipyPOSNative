package com.mipypos.app

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.mipypos.app/logic"
    private var engineRef: FlutterEngine? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        engineRef = flutterEngine

        // Registrar plugins generados (file_picker, printing, etc.)
        try {
            GeneratedPluginRegistrant.registerWith(flutterEngine)
        } catch (e: Exception) {
            Log.w("MainActivity", "GeneratedPluginRegistrant failed: ${'$'}e")
        }

        // Canal para comunicación desde Dart hacia Kotlin
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "executeLogic" -> {
                    val response = "Lógica ejecutada en Android Nativo"
                    result.success(response)
                }
                else -> result.notImplemented()
            }
        }

        // Ejemplo: invocar método Dart registrado en `lib/native_bridge.dart`
        try {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("getProductsCount", null, object: MethodChannel.Result {
                override fun success(result: Any?) {
                    Log.d("MainActivity", "Products count from Dart: ${'$'}result")
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.e("MainActivity", "Error calling Dart: ${'$'}errorMessage")
                }

                override fun notImplemented() {
                    Log.w("MainActivity", "Dart method not implemented")
                }
            })
        } catch (e: Exception) {
            Log.w("MainActivity", "Could not invoke Dart method: ${'$'}e")
        }
    }
}
