package com.example.climb_endurance

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val workoutChannelName = "climb_endurance/workout_notification"
    private val notificationChannelId = "active_workout"
    private val notificationId = 1001
    private val openRecordAction = "com.example.climb_endurance.OPEN_RECORD"
    private var notificationPermissionRequested = false
    private var workoutChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        workoutChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            workoutChannelName
        )
        workoutChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    val title = call.argument<String>("title") ?: "Workout recording"
                    val text = call.argument<String>("text") ?: "Workout in progress"
                    showWorkoutNotification(title, text)
                    result.success(null)
                }
                "cancel" -> {
                    cancelWorkoutNotification()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == openRecordAction) {
            workoutChannel?.invokeMethod("openRecord", null)
        }
    }

    private fun showWorkoutNotification(title: String, text: String) {
        if (!canPostNotifications()) {
            return
        }
        createNotificationChannel()

        val openIntent = Intent(this, MainActivity::class.java).apply {
            action = openRecordAction
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
        val pendingIntent = PendingIntent.getActivity(this, 0, openIntent, pendingFlags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, notificationChannelId)
        } else {
            Notification.Builder(this)
        }

        val notification = builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setContentIntent(pendingIntent)
            .setCategory(Notification.CATEGORY_STATUS)
            .build()

        notificationManager().notify(notificationId, notification)
    }

    private fun cancelWorkoutNotification() {
        notificationManager().cancel(notificationId)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            notificationChannelId,
            "Active workout",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Shows workout timing while a workout is recording."
            setShowBadge(false)
        }
        notificationManager().createNotificationChannel(channel)
    }

    private fun canPostNotifications(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return true
        }
        if (!notificationPermissionRequested) {
            notificationPermissionRequested = true
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
        }
        return false
    }

    private fun notificationManager(): NotificationManager {
        return getSystemService(NOTIFICATION_SERVICE) as NotificationManager
    }
}
