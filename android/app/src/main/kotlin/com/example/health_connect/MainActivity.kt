package com.example.health_connect

import android.content.Context
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private var bridge: HealthConnectBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridge = HealthConnectBridge(this)
        bridge?.configure(flutterEngine)
    }
}
