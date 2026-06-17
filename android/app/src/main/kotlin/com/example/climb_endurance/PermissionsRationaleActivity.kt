package com.example.climb_endurance

import android.app.Activity
import android.os.Bundle
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView

class PermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(48, 48, 48, 48)
        }
        container.addView(TextView(this).apply {
            text = "Heart rate data"
            textSize = 24f
        })
        container.addView(TextView(this).apply {
            text = "Climb Endurance reads heart rate from Health Connect only when you sync workout data. Heart rate samples are stored locally with your workout history so you can review set-level HR min, average, and max, plus full-workout HR charts."
            textSize = 16f
            setPadding(0, 24, 0, 0)
        })
        setContentView(container)
    }
}
