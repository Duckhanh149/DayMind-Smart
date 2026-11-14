package dev.daymind.daymind_smart

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Messenger
import android.os.ResultReceiver
import java.io.File

/** Private, short-lived IPC. All Android SQLite access lives in :reminders,
 * apart from Flutter's bundled SQLite library and its POSIX process locks.
 * This adds no service, Flutter engine, startup job or second scheduler. */
class ReminderControlReceiver : BroadcastReceiver() {
    companion object {
        const val EVENT_CHANGED = 1701
        @Volatile var initializedInRemoteProcess = false
            private set

        fun request(context: Context, command: String, client: Messenger,
                    foreground: Boolean, path: String? = null,
                    completed: ((Boolean) -> Unit)? = null) {
            if (command == "initialize") initializedInRemoteProcess = false
            val handler = Handler(Looper.getMainLooper())
            var answered = false
            val timeout = Runnable { if (!answered) { answered = true; completed?.invoke(false) } }
            val reply = object : ResultReceiver(handler) {
                override fun onReceiveResult(code: Int, data: Bundle?) {
                    if (!answered) {
                        answered = true
                        handler.removeCallbacks(timeout)
                        val remote = data?.getInt("nativePid") != android.os.Process.myPid() && data?.containsKey("nativePid") == true
                        if (command == "initialize") initializedInRemoteProcess = code == 0 && remote
                        if (command == "deactivate") initializedInRemoteProcess = false
                        completed?.invoke(code == 0 && remote)
                    }
                }
            }
            if (completed != null) handler.postDelayed(timeout, 15000)
            try {
                context.sendBroadcast(Intent(context, ReminderControlReceiver::class.java)
                    .putExtra("command", command).putExtra("client", client)
                    .putExtra("foreground", foreground).putExtra("path", path)
                    .putExtra("reply", reply))
            } catch (_: Exception) {
                handler.removeCallbacks(timeout)
                if (!answered) { answered = true; completed?.invoke(false) }
            }
        }
    }

    @Suppress("DEPRECATION")
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        val reply = intent.getParcelableExtra<ResultReceiver>("reply")
        val client = intent.getParcelableExtra<Messenger>("client")
        val command = intent.getStringExtra("command")
        val answer = Bundle().apply { putInt("nativePid", android.os.Process.myPid()) }
        ReminderRuntime.executor.execute {
            var deferred = false
            try {
                if (command == "detach") {
                    ReminderRuntime.detachClient(client)
                } else {
                    ReminderRuntime.attachClient(client, intent.getBooleanExtra("foreground", false))
                    when (command) {
                        "visibility" -> Unit
                        "initialize" -> {
                            val path = File(requireNotNull(intent.getStringExtra("path"))).canonicalFile
                            require(path.path.startsWith(context.filesDir.canonicalPath + File.separator))
                            ReminderRuntime.switchDatabase(context, path.path)
                            ReminderRuntime.channel(context)
                            // Reply only after recovery's transaction and connection close.
                            ReminderRuntime.recover(context) {
                                reply?.send(0, answer)
                                pending.finish()
                            }
                            deferred = true
                        }
                        "deactivate" -> ReminderRuntime.deactivate(context)
                        else -> throw IllegalArgumentException("Unsupported native lifecycle request")
                    }
                }
                if (!deferred) reply?.send(0, answer)
            } catch (_: Exception) {
                reply?.send(1, null)
            } finally {
                if (!deferred) pending.finish()
            }
        }
    }
}
