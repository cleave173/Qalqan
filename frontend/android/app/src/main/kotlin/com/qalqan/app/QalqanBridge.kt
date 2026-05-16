package com.qalqan.app

import android.content.Context
import android.telephony.SmsManager
import io.flutter.plugin.common.EventChannel

object QalqanBridge {
    private const val prefsName = "qalqan_prefs"
    private const val parentPhoneKey = "parent_phone"
    private const val childPhoneKey = "child_phone"

    var context: Context? = null
    var eventSink: EventChannel.EventSink? = null
    var callActive: Boolean = false

    fun saveConfig(context: Context, parentPhone: String, childPhone: String) {
        context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .edit()
            .putString(parentPhoneKey, parentPhone)
            .putString(childPhoneKey, childPhone)
            .apply()
    }

    fun parentPhone(context: Context): String =
        context.getSharedPreferences(prefsName, Context.MODE_PRIVATE).getString(parentPhoneKey, "").orEmpty()

    fun childPhone(context: Context): String =
        context.getSharedPreferences(prefsName, Context.MODE_PRIVATE).getString(childPhoneKey, "").orEmpty()

    fun emit(event: Map<String, Any?>) {
        eventSink?.success(event)
    }

    fun sendEmergencySms(context: Context, text: String): Boolean {
        val childPhone = childPhone(context)
        if (childPhone.isBlank() || text.isBlank()) return false
        return runCatching {
            SmsManager.getDefault().sendTextMessage(childPhone, null, text.take(160), null, null)
            true
        }.getOrDefault(false)
    }
}
