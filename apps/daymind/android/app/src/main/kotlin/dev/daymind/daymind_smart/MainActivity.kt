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
        fun changed(title: String? = null, kind: String = "reminder") { android.os.Handler(android.os.Looper.getMainLooper()).post { bridge?.invokeMethod("changed", if(title == null) null else mapOf("title" to title,"kind" to kind)) } }
    }
    private var runtimeDatabase: String? = null
    private val runtimeClient by lazy {
        android.os.Messenger(android.os.Handler(android.os.Looper.getMainLooper()) { message ->
            if (message.what == ReminderControlReceiver.EVENT_CHANGED && runtimeDatabase != null &&
                message.data.getString("database") == runtimeDatabase) {
                changed(message.data.getString("title"), message.data.getString("kind") ?: "reminder")
            }
            true
        })
    }
    private fun visibility(visible: Boolean, detach: Boolean = false) {
        ReminderControlReceiver.request(this, if (detach) "detach" else "visibility", runtimeClient, visible)
    }
    private var permissionResult: MethodChannel.Result? = null
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent);setIntent(intent)
        if(intent.getBooleanExtra("daymindOpenNotifications",false) && bridge!=null) {
            intent.removeExtra("daymindOpenNotifications");bridge?.invokeMethod("openNotifications",null)
        }
    }
    override fun onResume() { super.onResume(); foreground = true; visibility(true) }
    override fun onPause() { foreground = false; visibility(false); super.onPause() }
    override fun onDestroy() { foreground = false; runtimeDatabase = null; visibility(false, true); bridge = null; super.onDestroy() }
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
                        runtimeDatabase = path.path
                        ReminderControlReceiver.request(this, "initialize", runtimeClient, foreground, path.path) { ready ->
                            if (ready) result.success(null)
                            else {
                                if (runtimeDatabase == path.path) runtimeDatabase = null
                                result.error("PROFILE_OPEN", "Chưa mở được thông báo cho không gian này.", null)
                            }
                        }
                    }
                    "granted" -> result.success(ReminderRuntime.granted(this))
                    "runtimeIsolation" -> result.success(ReminderControlReceiver.initializedInRemoteProcess)
                    "deactivate" -> {
                        runtimeDatabase = null
                        ReminderControlReceiver.request(this, "deactivate", runtimeClient, foreground) { ready ->
                            if (ready) result.success(null)
                            else result.error("PROFILE_CLOSE", "Chưa dừng được thông báo của không gian cũ.", null)
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
