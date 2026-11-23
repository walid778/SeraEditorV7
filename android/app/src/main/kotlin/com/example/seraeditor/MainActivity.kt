
package com.example.seraeditor

import android.app.ActivityManager
import android.content.Context
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "smart_ocr/device"

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "getMemoryInfo" -> {
                    try {
                        val manager =
                            getSystemService(
                                Context.ACTIVITY_SERVICE
                            ) as ActivityManager

                        val memoryInfo =
                            ActivityManager.MemoryInfo()

                        manager.getMemoryInfo(memoryInfo)

                        val modelDir =
                            getExternalFilesDir(null) ?: filesDir

                        val stat = StatFs(modelDir.path)

                        result.success(
                            mapOf(
                                "totalRamMb" to
                                    (memoryInfo.totalMem / 1048576L).toInt(),

                                "availableRamMb" to
                                    (memoryInfo.availMem / 1048576L).toInt(),

                                "freeStorageMb" to
                                    (stat.availableBytes / 1048576L).toInt()
                            )
                        )

                    } catch (e: Exception) {

                        result.error(
                            "MEMORY_ERROR",
                            e.message,
                            null
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
