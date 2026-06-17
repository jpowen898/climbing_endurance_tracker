package com.example.climb_endurance

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.util.Log
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : FlutterFragmentActivity(), SensorEventListener, EventChannel.StreamHandler {
    private val workoutChannelName = "climb_endurance/workout_notification"
    private val heartRateChannelName = "climb_endurance/heart_rate"
    private val heartRateStreamName = "climb_endurance/heart_rate_stream"
    private val notificationChannelId = "active_workout"
    private val logTag = "ClimbEnduranceHR"
    private val notificationId = 1001
    private val notificationPermissionRequestCode = 1001
    private val bodySensorsPermissionRequestCode = 2001
    private val openRecordAction = "com.example.climb_endurance.OPEN_RECORD"
    private val healthConnectPermissions = setOf(
        HealthPermission.getReadPermission(HeartRateRecord::class)
    )
    private var notificationPermissionRequested = false
    private var bodySensorsPermissionRequested = false
    private var workoutChannel: MethodChannel? = null
    private var heartRateEvents: EventChannel.EventSink? = null
    private var sensorManager: SensorManager? = null
    private var heartRateSensor: Sensor? = null
    private var heartRateAccuracy: Int? = null
    private var heartRateListening = false
    private var healthPermissionLauncher: ActivityResultLauncher<Set<String>>? = null
    private var pendingHealthPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        healthPermissionLauncher = registerForActivityResult(
            PermissionController.createRequestPermissionResultContract()
        ) { grantedPermissions: Set<String> ->
            Log.d(
                logTag,
                "Health Connect permission result granted=${grantedPermissions.containsAll(healthConnectPermissions)} permissions=$grantedPermissions"
            )
            pendingHealthPermissionResult?.success(
                grantedPermissions.containsAll(healthConnectPermissions)
            )
            pendingHealthPermissionResult = null
        }

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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            heartRateChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> result.success(startHeartRate())
                "stop" -> {
                    stopHeartRate()
                    result.success(null)
                }
                "healthConnectStatus" -> healthConnectStatus(result)
                "requestHealthConnectPermissions" -> requestHealthConnectPermissions(result)
                "readHealthConnectHeartRate" -> {
                    val startMillis = call.argument<Long>("startMillis")
                    val endMillis = call.argument<Long>("endMillis")
                    if (startMillis == null || endMillis == null) {
                        result.error("bad_args", "startMillis and endMillis are required", null)
                    } else {
                        readHealthConnectHeartRate(startMillis, endMillis, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            heartRateStreamName
        ).setStreamHandler(this)

        handleIntent(intent)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        heartRateEvents = events
        startHeartRate()
    }

    override fun onCancel(arguments: Any?) {
        heartRateEvents = null
        stopHeartRate()
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_HEART_RATE || event.values.isEmpty()) {
            return
        }
        val bpm = event.values[0]
        if (bpm <= 0f) {
            return
        }
        heartRateEvents?.success(
            mapOf(
                "bpm" to bpm.toDouble(),
                "timestamp" to System.currentTimeMillis(),
                "accuracy" to heartRateAccuracy,
                "source" to "local_sensor"
            )
        )
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        if (sensor?.type == Sensor.TYPE_HEART_RATE) {
            heartRateAccuracy = accuracy
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == bodySensorsPermissionRequestCode &&
            grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        ) {
            startHeartRate()
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == openRecordAction) {
            workoutChannel?.invokeMethod("openRecord", null)
        }
    }

    private fun healthConnectStatus(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.Main).launch {
            val status = HealthConnectClient.getSdkStatus(this@MainActivity)
            val available = status == HealthConnectClient.SDK_AVAILABLE
            val granted = if (available) {
                try {
                    healthConnectClient()
                        ?.permissionController
                        ?.getGrantedPermissions()
                        ?.containsAll(healthConnectPermissions) == true
                } catch (_: Exception) {
                    false
                }
            } else {
                false
            }
            result.success(
                mapOf(
                    "available" to available,
                    "status" to status,
                    "permissionsGranted" to granted
                )
            )
            Log.d(
                logTag,
                "Health Connect status=$status available=$available permissionGranted=$granted"
            )
        }
    }

    private fun requestHealthConnectPermissions(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.Main).launch {
            val client = healthConnectClient()
            if (client == null) {
                Log.d(logTag, "Health Connect permission request skipped; client unavailable")
                result.success(false)
                return@launch
            }
            val granted = client.permissionController.getGrantedPermissions()
            if (granted.containsAll(healthConnectPermissions)) {
                Log.d(logTag, "Health Connect heart-rate permission already granted")
                result.success(true)
                return@launch
            }
            if (pendingHealthPermissionResult != null) {
                result.error("permission_pending", "Health Connect permission request already pending", null)
                return@launch
            }
            pendingHealthPermissionResult = result
            try {
                val launcher = healthPermissionLauncher
                if (launcher == null) {
                    pendingHealthPermissionResult = null
                    result.error(
                        "permission_launcher_missing",
                        "Health Connect permission launcher is not ready",
                        null
                    )
                    return@launch
                }
                launcher.launch(healthConnectPermissions)
            } catch (error: Exception) {
                Log.e(logTag, "Unable to launch Health Connect permission request", error)
                pendingHealthPermissionResult = null
                result.error(
                    "permission_launch_failed",
                    error.message ?: "Unable to open Health Connect permissions",
                    null
                )
            }
        }
    }

    private fun readHealthConnectHeartRate(
        startMillis: Long,
        endMillis: Long,
        result: MethodChannel.Result
    ) {
        CoroutineScope(Dispatchers.Main).launch {
            val client = healthConnectClient()
            if (client == null) {
                Log.d(logTag, "Health Connect read skipped; client unavailable")
                result.success(emptyList<Map<String, Any?>>())
                return@launch
            }
            val granted = client.permissionController.getGrantedPermissions()
            if (!granted.containsAll(healthConnectPermissions)) {
                Log.d(logTag, "Health Connect read denied; permission not granted")
                result.error("permission_denied", "Health Connect heart-rate permission is not granted", null)
                return@launch
            }
            try {
                val samples = mutableListOf<Map<String, Any?>>()
                val queryStartMillis = maxOf(0L, startMillis - 60L * 60L * 1000L)
                var pageToken: String? = null
                do {
                    val response = client.readRecords(
                        ReadRecordsRequest(
                            recordType = HeartRateRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(
                                Instant.ofEpochMilli(queryStartMillis),
                                Instant.ofEpochMilli(endMillis)
                            ),
                            pageToken = pageToken
                        )
                    )
                    response.records.forEach { record ->
                        record.samples.forEach { sample ->
                            val sampleMillis = sample.time.toEpochMilli()
                            if (sampleMillis >= startMillis && sampleMillis <= endMillis) {
                                samples.add(
                                    mapOf(
                                        "bpm" to sample.beatsPerMinute.toDouble(),
                                        "timestamp" to sampleMillis,
                                        "accuracy" to null,
                                        "source" to "health_connect"
                                    )
                                )
                            }
                        }
                    }
                    pageToken = response.pageToken
                } while (pageToken != null)
                Log.d(
                    logTag,
                    "Health Connect read ${samples.size} HR samples from $startMillis to $endMillis using queryStart=$queryStartMillis"
                )
                result.success(samples)
            } catch (error: Exception) {
                Log.e(logTag, "Health Connect heart-rate read failed", error)
                result.error("health_connect_read_failed", error.message, null)
            }
        }
    }

    private fun healthConnectClient(): HealthConnectClient? {
        return if (HealthConnectClient.getSdkStatus(this) == HealthConnectClient.SDK_AVAILABLE) {
            HealthConnectClient.getOrCreate(this)
        } else {
            null
        }
    }

    private fun startHeartRate(): Boolean {
        val sensor = heartRateSensor ?: findHeartRateSensor() ?: return false
        if (!canReadBodySensors()) {
            return false
        }
        if (heartRateListening) {
            return true
        }
        val manager = sensorManager ?: return false
        heartRateListening = manager.registerListener(
            this,
            sensor,
            SensorManager.SENSOR_DELAY_NORMAL
        )
        return heartRateListening
    }

    private fun stopHeartRate() {
        sensorManager?.unregisterListener(this)
        heartRateListening = false
    }

    private fun findHeartRateSensor(): Sensor? {
        val manager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        sensorManager = manager
        heartRateSensor = manager.getDefaultSensor(Sensor.TYPE_HEART_RATE)
        return heartRateSensor
    }

    private fun canReadBodySensors(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT_WATCH) {
            return true
        }
        if (checkSelfPermission(Manifest.permission.BODY_SENSORS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return true
        }
        if (!bodySensorsPermissionRequested) {
            bodySensorsPermissionRequested = true
            requestPermissions(
                arrayOf(Manifest.permission.BODY_SENSORS),
                bodySensorsPermissionRequestCode
            )
        }
        return false
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
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                notificationPermissionRequestCode
            )
        }
        return false
    }

    private fun notificationManager(): NotificationManager {
        return getSystemService(NOTIFICATION_SERVICE) as NotificationManager
    }
}
