package dev.daymind.daymind_smart

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        @Volatile var foreground = false
        var bridge: MethodChannel? = null
        fun changed(title: String? = null) { android.os.Handler(android.os.Looper.getMainLooper()).post { bridge?.invokeMethod("changed", title) } }
    }
    private var permissionResult: MethodChannel.Result? = null
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent);setIntent(intent)
        if(intent.getBooleanExtra("daymindOpenNotifications",false) && bridge!=null) {
            intent.removeExtra("daymindOpenNotifications");bridge?.invokeMethod("openNotifications",null)
        }
    }
    override fun onResume() { super.onResume(); foreground = true }
    override fun onPause() { foreground = false; super.onPause() }
    override fun onDestroy() { foreground = false; bridge = null; super.onDestroy() }
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        val secureStore = SecureStore(this)
        MethodChannel(engine.dartExecutor.binaryMessenger, "daymind/secure").setMethodCallHandler(secureStore::handle)
        bridge = MethodChannel(engine.dartExecutor.binaryMessenger, "daymind/reminders")
        bridge?.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "consumeOpen" -> { val open=intent.getBooleanExtra("daymindOpenNotifications",false);intent.removeExtra("daymindOpenNotifications");result.success(open) }
                    "initialize" -> {
                        val path = java.io.File(call.argument<String>("path")!!).canonicalFile
                        require(path.path.startsWith(filesDir.canonicalPath + java.io.File.separator))
                        getSharedPreferences("daymind_runtime", MODE_PRIVATE).edit().putString("database", path.path).apply()
                        ReminderRuntime.channel(this); ReminderRuntime.recover(this); result.success(null)
                    }
                    "granted" -> result.success(ReminderRuntime.granted(this))
                    "deactivate" -> {
                        ReminderRuntime.executor.execute {
                            try {
                                ReminderRuntime.database(this)?.use { db ->
                                    db.rawQuery("SELECT platform_id FROM reminder_events WHERE state='scheduled' LIMIT 256", null).use { rows ->
                                        while(rows.moveToNext()) ReminderRuntime.cancel(this, rows.getInt(0))
                                    }
                                }
                                check(getSharedPreferences("daymind_runtime", MODE_PRIVATE).edit().remove("database").commit())
                                getSystemService(android.app.NotificationManager::class.java).cancelAll()
                                runOnUiThread { result.success(null) }
                            } catch (_:Exception) {
                                runOnUiThread { result.error("PROFILE_CLOSE", "Chưa dừng được thông báo của không gian cũ.", null) }
                            }
                        }
                    }
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            permissionResult = result
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 9201)
                        } else result.success(ReminderRuntime.granted(this))
                    }
                    "openSettings" -> {
                        startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)); result.success(null)
                    }
                    "schedule" -> {
                        ReminderRuntime.arm(this, call.argument<Int>("id")!!, call.argument<String>("eventKey")!!, call.argument<Number>("at")!!.toLong()); result.success(null)
                    }
                    "cancel" -> { ReminderRuntime.cancel(this, call.argument<Int>("id")!!); result.success(null) }
                    "test" -> { ReminderRuntime.test(this, call.argument<String>("title") ?: "DayMind", call.argument<String>("body") ?: ""); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) { result.error("NOTIFICATION_ERROR", error.message, null) }
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, results: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, results)
        if (requestCode == 9201) { permissionResult?.success(ReminderRuntime.granted(this)); permissionResult = null }
    }
}
