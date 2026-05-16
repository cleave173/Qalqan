package com.pry.pry_app

import android.Manifest
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val methodChannelName = "qalqan/protection"
    private val eventChannelName = "qalqan/events"
    private val permissionsRequestCode = 7101
    private val receiver = QalqanReceiver()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        QalqanBridge.context = applicationContext

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    QalqanBridge.eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    QalqanBridge.eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermissions" -> {
                        requestProtectionPermissions()
                        result.success(true)
                    }
                    "configure" -> {
                        val parentPhone = call.argument<String>("parentPhone").orEmpty()
                        val childPhone = call.argument<String>("childPhone").orEmpty()
                        QalqanBridge.saveConfig(applicationContext, parentPhone, childPhone)
                        result.success(true)
                    }
                    "sendEmergencySms" -> {
                        val text = call.argument<String>("text").orEmpty()
                        result.success(QalqanBridge.sendEmergencySms(applicationContext, text))
                    }
                    else -> result.notImplemented()
                }
            }

        registerReceiver(receiver, IntentFilter().apply {
            addAction("android.intent.action.PHONE_STATE")
            addAction("android.provider.Telephony.SMS_RECEIVED")
        })
    }

    override fun onDestroy() {
        runCatching { unregisterReceiver(receiver) }
        super.onDestroy()
    }

    private fun requestProtectionPermissions() {
        val permissions = mutableListOf(
            Manifest.permission.READ_PHONE_STATE,
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.RECEIVE_SMS,
            Manifest.permission.READ_SMS,
            Manifest.permission.SEND_SMS,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val missing = permissions.filter {
                ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
            }
            if (missing.isNotEmpty()) {
                ActivityCompat.requestPermissions(this, missing.toTypedArray(), permissionsRequestCode)
            }
        }
    }
}
