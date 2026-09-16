package com.example.health_connect

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.time.Duration
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.UUID

class HealthConnectBridge(private val flutterEngine: FlutterEngine) {
    companion object {
        private const val TAG = "HealthConnectBridge"
        private const val METHOD_CHANNEL = "com.example.health_connect/method"
        private const val EVENT_CHANNEL = "com.example.health_connect/events"
        private const val POLL_INTERVAL_MS = 5000L
    }

    private var healthConnectClient: HealthConnectClient? = null
    private var eventSink: EventChannel.EventSink? = null
    private var scheduler: ScheduledExecutorService? = null
    private val isListening = AtomicBoolean(false)
    private val knownStepRecordIds = mutableSetOf<String>()
    private val knownHrRecordIds = mutableSetOf<String>()

    fun configure() {
        val methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        )
        val eventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL
        )

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> initialize(result)
                "checkPermissions" -> checkPermissions(result)
                "requestPermissions" -> requestPermissions(result)
                "readStepsToday" -> readStepsToday(result)
                "readLatestHeartRate" -> readLatestHeartRate(result)
                "startListening" -> startListening(result)
                "stopListening" -> stopListening(result)
                "readStepsRange" -> readStepsRange(call.arguments as Map<*, *>, result)
                "readHeartRateRange" -> readHeartRateRange(call.arguments as Map<*, *>, result)
                else -> result.notImplemented()
            }
        }

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                Log.d(TAG, "EventChannel onListen")
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                Log.d(TAG, "EventChannel onCancel")
            }
        })
    }

    private fun initialize(result: MethodChannel.Result) {
        try {
            healthConnectClient = HealthConnectClient.getOrCreate(
                flutterEngine.applicationContext
            )
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Health Connect not available", e)
            result.success(false)
        }
    }

    private fun checkPermissions(result: MethodChannel.Result) {
        val client = healthConnectClient
        if (client == null) {
            result.success(mapOf("granted" to false, "error" to "Not initialized"))
            return
        }

        try {
            val scope = kotlinx.coroutines.runBlocking {
                val granted = client.permissionController.getGrantedPermissions()
                val required = setOf(
                    HealthPermission.getReadPermission(StepsRecord::class),
                    HealthPermission.getReadPermission(HeartRateRecord::class)
                )
                mapOf(
                    "steps" to (HealthPermission.getReadPermission(StepsRecord::class) in granted),
                    "heartRate" to (HealthPermission.getReadPermission(HeartRateRecord::class) in granted),
                    "allGranted" to required.all { it in granted }
                )
            }
            result.success(scope)
        } catch (e: Exception) {
            result.success(mapOf("granted" to false, "error" to e.message))
        }
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        val client = healthConnectClient
        if (client == null) {
            result.success(mapOf("granted" to false, "error" to "Not initialized"))
            return
        }

        try {
            kotlinx.coroutines.runBlocking {
                val required = setOf(
                    HealthPermission.getReadPermission(StepsRecord::class),
                    HealthPermission.getReadPermission(HeartRateRecord::class)
                )
                val granted = client.permissionController.requestPermissions(required)
                result.success(mapOf(
                    "steps" to (HealthPermission.getReadPermission(StepsRecord::class) in granted),
                    "heartRate" to (HealthPermission.getReadPermission(HeartRateRecord::class) in granted),
                    "allGranted" to required.all { it in granted }
                ))
            }
        } catch (e: Exception) {
            result.success(mapOf("granted" to false, "error" to e.message))
        }
    }

    private fun readStepsToday(result: MethodChannel.Result) {
        val client = healthConnectClient
        if (client == null) {
            result.success(mapOf("total" to 0, "error" to "Not initialized"))
            return
        }

        try {
            kotlinx.coroutines.runBlocking {
                val startOfDay = Instant.now().truncatedTo(ChronoUnit.DAYS)
                val response = client.readRecords(
                    ReadRecordsRequest(
                        StepsRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(startOfDay, Instant.now())
                    )
                )
                val total = response.records.sumOf { it.count }
                result.success(mapOf("total" to total))
            }
        } catch (e: Exception) {
            result.success(mapOf("total" to 0, "error" to e.message))
        }
    }

    private fun readLatestHeartRate(result: MethodChannel.Result) {
        val client = healthConnectClient
        if (client == null) {
            result.success(mapOf("bpm" to 0, "timestamp" to 0L, "error" to "Not initialized"))
            return
        }

        try {
            kotlinx.coroutines.runBlocking {
                val last24h = Instant.now().minus(Duration.ofHours(24))
                val response = client.readRecords(
                    ReadRecordsRequest(
                        HeartRateRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(last24h, Instant.now())
                    )
                )
                val latest = response.records
                    .flatMap { record ->
                        record.samples.map { sample ->
                            mapOf("bpm" to sample.bpm, "timestamp" to record.startTime.toEpochMilli())
                        }
                    }
                    .maxByOrNull { it["timestamp"] as Long }

                if (latest != null) {
                    result.success(mapOf(
                        "bpm" to (latest["bpm"] as Long),
                        "timestamp" to (latest["timestamp"] as Long)
                    ))
                } else {
                    result.success(mapOf("bpm" to 0, "timestamp" to 0L))
                }
            }
        } catch (e: Exception) {
            result.success(mapOf("bpm" to 0, "timestamp" to 0L, "error" to e.message))
        }
    }

    private fun readStepsRange(args: Map<*, *>, result: MethodChannel.Result) {
        val client = healthConnectClient
        if (client == null) {
            result.success(emptyList<Map<String, Any>>())
            return
        }

        val startMs = args["startMs"] as? Long ?: 0L
        val endMs = args["endMs"] as? Long ?: System.currentTimeMillis()

        try {
            kotlinx.coroutines.runBlocking {
                val start = Instant.ofEpochMilli(startMs)
                val end = Instant.ofEpochMilli(endMs)
                val response = client.readRecords(
                    ReadRecordsRequest(
                        StepsRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(start, end)
                    )
                )
                val events = response.records.map { record ->
                    mapOf(
                        "type" to "steps",
                        "timestamp" to record.startTime.toEpochMilli(),
                        "value" to record.count.toDouble(),
                        "sourceId" to (record.metadata.dataOrigin.packageName ?: ""),
                        "recordId" to (record.metadata.id ?: UUID.randomUUID().toString())
                    )
                }
                result.success(events)
            }
        } catch (e: Exception) {
            result.success(emptyList<Map<String, Any>>())
        }
    }

    private fun readHeartRateRange(args: Map<*, *>, result: MethodChannel.Result) {
        val client = healthConnectClient
        if (client == null) {
            result.success(emptyList<Map<String, Any>>())
            return
        }

        val startMs = args["startMs"] as? Long ?: 0L
        val endMs = args["endMs"] as? Long ?: System.currentTimeMillis()

        try {
            kotlinx.coroutines.runBlocking {
                val start = Instant.ofEpochMilli(startMs)
                val end = Instant.ofEpochMilli(endMs)
                val response = client.readRecords(
                    ReadRecordsRequest(
                        HeartRateRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(start, end)
                    )
                )
                val events = response.records.flatMap { record ->
                    record.samples.map { sample ->
                        mapOf(
                            "type" to "heartRate",
                            "timestamp" to record.startTime.toEpochMilli(),
                            "value" to sample.bpm.toDouble(),
                            "sourceId" to (record.metadata.dataOrigin.packageName ?: ""),
                            "recordId" to (record.metadata.id ?: UUID.randomUUID().toString())
                        )
                    }
                }
                result.success(events)
            }
        } catch (e: Exception) {
            result.success(emptyList<Map<String, Any>>())
        }
    }

    private fun startListening(result: MethodChannel.Result) {
        if (isListening.getAndSet(true)) {
            result.success(true)
            return
        }

        scheduler = Executors.newSingleThreadScheduledExecutor()
        scheduler?.scheduleAtFixedRate({
            try {
                pollAndSendEvents()
            } catch (e: Exception) {
                Log.e(TAG, "Poll error", e)
            }
        }, 0, POLL_INTERVAL_MS, TimeUnit.MILLISECONDS)

        result.success(true)
        Log.d(TAG, "Started passive listening via polling")
    }

    private fun stopListening(result: MethodChannel.Result) {
        isListening.set(false)
        scheduler?.shutdownNow()
        scheduler = null
        result.success(true)
        Log.d(TAG, "Stopped listening")
    }

    private fun pollAndSendEvents() {
        val client = healthConnectClient ?: return
        val sink = eventSink ?: return

        try {
            kotlinx.coroutines.runBlocking {
                val now = Instant.now()
                val last10s = now.minus(Duration.ofSeconds(10))

                // Poll steps
                val stepsResponse = client.readRecords(
                    ReadRecordsRequest(
                        StepsRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(last10s, now)
                    )
                )
                val newStepEvents = stepsResponse.records
                    .filter { it.metadata.id !in knownStepRecordIds }
                    .map { record ->
                        knownStepRecordIds.add(record.metadata.id)
                        mapOf(
                            "type" to "steps",
                            "timestamp" to record.startTime.toEpochMilli(),
                            "value" to record.count.toDouble(),
                            "sourceId" to (record.metadata.dataOrigin.packageName ?: ""),
                            "recordId" to record.metadata.id
                        )
                    }

                // Poll heart rate
                val hrResponse = client.readRecords(
                    ReadRecordsRequest(
                        HeartRateRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(last10s, now)
                    )
                )
                val newHrEvents = hrResponse.records
                    .filter { it.metadata.id !in knownHrRecordIds }
                    .flatMap { record ->
                        knownHrRecordIds.add(record.metadata.id)
                        record.samples.map { sample ->
                            mapOf(
                                "type" to "heartRate",
                                "timestamp" to record.startTime.toEpochMilli(),
                                "value" to sample.bpm.toDouble(),
                                "sourceId" to (record.metadata.dataOrigin.packageName ?: ""),
                                "recordId" to record.metadata.id
                            )
                        }
                    }

                val allNew = newStepEvents + newHrEvents
                if (allNew.isNotEmpty()) {
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        sink.success(allNew)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Poll read error", e)
        }

        // Cleanup old record IDs to prevent memory leak
        if (knownStepRecordIds.size > 1000) {
            knownStepRecordIds.clear()
        }
        if (knownHrRecordIds.size > 1000) {
            knownHrRecordIds.clear()
        }
    }
}
