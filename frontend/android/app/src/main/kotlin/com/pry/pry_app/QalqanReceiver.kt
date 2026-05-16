package com.pry.pry_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.TelephonyManager

class QalqanReceiver : BroadcastReceiver() {
    private val watchedSenders = listOf("kaspi.kz", "kaspi", "1414", "halykbank")
    private val codeRegex = Regex("""\b\d{4,8}\b""")

    override fun onReceive(context: Context, intent: Intent) {
        QalqanBridge.context = context.applicationContext
        when (intent.action) {
            TelephonyManager.ACTION_PHONE_STATE_CHANGED -> handlePhoneState(intent)
            Telephony.Sms.Intents.SMS_RECEIVED_ACTION -> handleSms(context, intent)
        }
    }

    private fun handlePhoneState(intent: Intent) {
        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE).orEmpty()
        val active = state == TelephonyManager.EXTRA_STATE_OFFHOOK
        QalqanBridge.callActive = active
        QalqanBridge.emit(
            mapOf(
                "type" to "phone_state",
                "state" to state,
                "callActive" to active,
            )
        )
    }

    private fun handleSms(context: Context, intent: Intent) {
        if (!QalqanBridge.callActive) return
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        for (message in messages) {
            val sender = message.displayOriginatingAddress.orEmpty()
            val body = message.messageBody.orEmpty()
            if (!isWatchedSender(sender)) continue
            val code = codeRegex.find(body)?.value.orEmpty()
            val directText = "[ТРЕВОГА АНТИФРОД] Маме звонят мошенники! Перехвачен код от Kaspi/1414. СРОЧНО перезвони ей: ${QalqanBridge.parentPhone(context)}"
            QalqanBridge.sendEmergencySms(context, directText)
            QalqanBridge.emit(
                mapOf(
                    "type" to "sms_code",
                    "sender" to sender,
                    "code" to code,
                    "body" to body,
                )
            )
        }
    }

    private fun isWatchedSender(sender: String): Boolean {
        val normalized = sender.lowercase()
        return watchedSenders.any { normalized.contains(it) }
    }
}
