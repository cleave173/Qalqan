package com.pry.pry_app

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent

class QalqanAccessibilityService : AccessibilityService() {
    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit

    override fun onInterrupt() = Unit
}
