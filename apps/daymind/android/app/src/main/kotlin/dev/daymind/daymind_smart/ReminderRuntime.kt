package dev.daymind.daymind_smart

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.security.MessageDigest
import java.util.Calendar
import java.util.UUID
import java.util.concurrent.Executors

object ReminderRuntime {
    const val CHANNEL = "daymind_tasks"
    val executor = Executors.newSingleThreadExecutor()
    private fun manager(context: Context) = context.getSystemService(NotificationManager::class.java)
    fun channel(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        manager(context).createNotificationChannel(NotificationChannel(CHANNEL, "Nhắc công việc", NotificationManager.IMPORTANCE_DEFAULT).apply {
            description = "Nhắc đúng lúc, không làm phiền"; setBypassDnd(false)
        })
    }
    fun granted(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        return manager(context).areNotificationsEnabled() && (Build.VERSION.SDK_INT < 26 || manager(context).getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE)
    }
    fun database(context: Context): SQLiteDatabase? {
        val path = context.getSharedPreferences("daymind_runtime", Context.MODE_PRIVATE).getString("database", null) ?: return null
        if (!java.io.File(path).exists()) return null
        return SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READWRITE).apply { execSQL("PRAGMA busy_timeout=5000") }
    }
    private fun config(db: SQLiteDatabase): JSONObject = db.rawQuery("SELECT value FROM extension_records WHERE area='notifications' AND id='settings'", null).use {
        if (it.moveToFirst()) JSONObject(it.getString(0)) else JSONObject()
    }
    private fun quiet(config: JSONObject, instant: Long): Boolean {
        if (!config.optBoolean("quietEnabled", true)) return false
        val time = Calendar.getInstance().apply { timeInMillis = instant }; val minute = time.get(Calendar.HOUR_OF_DAY) * 60 + time.get(Calendar.MINUTE)
        val start = config.optInt("quietStart", 1320); val end = config.optInt("quietEnd", 420)
        return if (start > end) minute >= start || minute < end else minute >= start && minute < end
    }
    fun arm(context: Context, id: Int, key: String, at: Long) {
        if (at <= System.currentTimeMillis()) return
        val intent = Intent(context, ReminderAlarmReceiver::class.java).setAction("DAYMIND_ALARM").putExtra("id", id).putExtra("key", key)
        val pending = PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        context.getSystemService(AlarmManager::class.java).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
    }
    fun cancel(context: Context, id: Int) {
        val intent = Intent(context, ReminderAlarmReceiver::class.java).setAction("DAYMIND_ALARM")
        val pending = PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
        if (pending != null) { context.getSystemService(AlarmManager::class.java).cancel(pending); pending.cancel() }
        for (visible in manager(context).activeNotifications) {
            if (visible.notification.extras.getIntArray("daymind_event_ids")?.contains(id) == true) manager(context).cancel(visible.id)
        }
    }
    private fun log(db: SQLiteDatabase, key: String, outcome: String, now: Long) {
        db.execSQL("INSERT INTO delivery_logs(id,event_key,outcome,at_ms) VALUES(?,?,?,?)", arrayOf<Any?>(UUID.randomUUID().toString(),key,outcome,now))
    }
    private fun state(db: SQLiteDatabase, key: String, state: String, outcome: String, now: Long) {
        db.execSQL("UPDATE reminder_events SET state=?,updated_ms=? WHERE event_key=?", arrayOf<Any?>(state,now,key)); log(db,key,outcome,now)
    }
    private fun owner(db: SQLiteDatabase): String = db.rawQuery("SELECT value FROM extension_records WHERE area='account' AND id='session'", null).use {
        if (it.moveToFirst()) JSONObject(it.getString(0)).optString("ownerId", "") else ""
    }
    private fun eligible(db: SQLiteDatabase, event: Cursor): Boolean {
        val taskId = event.getString(event.getColumnIndexOrThrow("task_id"))
        if (event.getString(event.getColumnIndexOrThrow("rule_id")) == "digest") return config(db).optBoolean("digestEnabled", false) && taskId == "__digest__:" + owner(db).ifEmpty { "local" }
        val mode=db.rawQuery("SELECT value FROM extension_records WHERE area='task_reminders' AND id=?",arrayOf(taskId)).use { if(it.moveToFirst())JSONObject(it.getString(0)).optString("mode","auto") else "auto" }
        val ruleId=event.getString(event.getColumnIndexOrThrow("rule_id"))
        if(mode=="off")return false
        if(!ruleId.startsWith("snooze:")) {
            if(ruleId=="default" && (mode!="auto" || config(db).optString("preset","normal")=="minimal"))return false
            if(ruleId!="default" && !db.rawQuery("SELECT value FROM extension_records WHERE area='reminder_rules' AND id=?",arrayOf(ruleId)).use { if(!it.moveToFirst())false else JSONObject(it.getString(0)).let { rule -> rule.optBoolean("enabled",true) && rule.optString("taskId")==taskId } })return false
        }
        return db.rawQuery("SELECT * FROM tasks WHERE id=? AND deleted_at IS NULL AND status NOT IN (2,3)", arrayOf(taskId)).use { task ->
            if (!task.moveToFirst() || task.getInt(task.getColumnIndexOrThrow("revision")) != event.getInt(event.getColumnIndexOrThrow("task_revision"))) return@use false
            val ownerIndex = task.getColumnIndex("owner_id")
            if (ownerIndex >= 0 && (task.getString(ownerIndex) ?: "") != owner(db)) return@use false
            val index = event.getColumnIndex("occurrence_id")
            if (index >= 0 && !event.isNull(index)) {
                val occurrence = event.getString(index)
                val valid = db.rawQuery("SELECT value FROM extension_records WHERE area='occurrences' AND id=?", arrayOf(occurrence)).use { item ->
                    if (!item.moveToFirst()) false else {
                        val data = JSONObject(item.getString(0))
                        val revision = event.getColumnIndex("occurrence_revision")
                        !data.optBoolean("deleted", false) && data.optString("status") !in listOf("completed","cancelled","skipped") &&
                            (revision < 0 || event.isNull(revision) || data.optInt("revision", 1) == event.getInt(revision))
                    }
                }
                if (!valid) return@use false
            }
            true
        }
    }
    fun recover(context: Context, restart: Boolean = true, finished: (() -> Unit)? = null) {
        executor.execute {
            try { database(context)?.use { db ->
                val now = System.currentTimeMillis(); var count = 0
                db.beginTransaction()
                try {
                db.rawQuery("SELECT * FROM reminder_events WHERE state IN ('planned','scheduled') ORDER BY scheduled_ms", null).use { rows ->
                    while (rows.moveToNext()) {
                        val key = rows.getString(rows.getColumnIndexOrThrow("event_key")); val id = rows.getInt(rows.getColumnIndexOrThrow("platform_id")); val at = rows.getLong(rows.getColumnIndexOrThrow("scheduled_ms"))
                        if ((restart && at <= now) || rows.getLong(rows.getColumnIndexOrThrow("expires_ms")) < now || !eligible(db,rows)) {
                            cancel(context,id);state(db,key,"expired","recovery_skipped",now)
                        } else if (at > now && granted(context) && config(db).optBoolean("primaryDevice",true) && count < 128) {
                            arm(context,id,key,at);db.execSQL("UPDATE reminder_events SET state='scheduled' WHERE event_key=?",arrayOf<Any?>(key));count++
                        } else if(at > now) { cancel(context,id);db.execSQL("UPDATE reminder_events SET state='planned' WHERE event_key=?",arrayOf<Any?>(key)) }
                    }
                }
                db.setTransactionSuccessful()
                } finally { db.endTransaction() }
            } } catch (_: Exception) { /* An older schema or locked DB is never a reason to replay alerts. */ } finally { finished?.invoke() }
        }
    }
    fun fire(context: Context, key: String) {
        database(context)?.use { db ->
            val now = System.currentTimeMillis(); var title = ""; var config = JSONObject(); var allowed = false
            db.beginTransaction()
            try {
                db.rawQuery("SELECT * FROM reminder_events WHERE event_key=? AND state='scheduled'",arrayOf(key)).use { event ->
                    if (event.moveToFirst()) {
                        config = ReminderRuntime.config(db)
                        val expires = event.getLong(event.getColumnIndexOrThrow("expires_ms"))
                        when {
                            event.getLong(event.getColumnIndexOrThrow("scheduled_ms")) > now -> arm(context,event.getInt(event.getColumnIndexOrThrow("platform_id")),key,event.getLong(event.getColumnIndexOrThrow("scheduled_ms")))
                            !eligible(db,event) -> state(db,key,"cancelled","invalidated",now)
                            expires < now -> state(db,key,"expired","late_skipped",now)
                            !granted(context) || !config.optBoolean("primaryDevice",true) || quiet(config,now) -> state(db,key,"suppressed","quiet_or_permission",now)
                            else -> { title = event.getString(event.getColumnIndexOrThrow("title")); state(db,key,"unknown",if(MainActivity.foreground)"in_app" else "display_attempt",now);allowed=true }
                        }
                    }
                }
                db.setTransactionSuccessful()
            } finally { db.endTransaction() }
            if (allowed && !MainActivity.foreground) {
                val minutes = config.optInt("groupingMinutes",10).coerceIn(1,60); val window = minutes * 60000L; val start = now / window * window
                val groupId = 1000000000 + (start / window % 1000000000L).toInt()
                val style = NotificationCompat.InboxStyle(); var count = 0; var high = false; val visibleIds=mutableListOf<Int>()
                db.rawQuery("SELECT DISTINCT e.* FROM reminder_events e JOIN delivery_logs l ON l.event_key=e.event_key WHERE l.outcome='display_attempt' AND l.at_ms>=? AND l.at_ms<? AND e.state='unknown' ORDER BY e.priority DESC,e.scheduled_ms",arrayOf(start.toString(),(start+window).toString())).use { rows ->
                    while(rows.moveToNext()) { if(!eligible(db,rows))continue; visibleIds.add(rows.getInt(rows.getColumnIndexOrThrow("platform_id")));if(count<7)style.addLine(rows.getString(rows.getColumnIndexOrThrow("title")));high=high || rows.getInt(rows.getColumnIndexOrThrow("priority"))==2;count++ }
                }
                if (count == 0) return
                val launch = PendingIntent.getActivity(context,groupId,Intent(context,MainActivity::class.java).putExtra("daymindOpenNotifications",true).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                val dismiss = PendingIntent.getBroadcast(context,groupId,Intent(context,ReminderActionReceiver::class.java).setAction("DAYMIND_DISMISS").putExtra("key",key).putExtra("group",groupId).putExtra("start",start).putExtra("end",start+window),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                val attempts=db.rawQuery("SELECT COUNT(*) FROM delivery_logs WHERE outcome='display_attempt' AND at_ms>=? AND at_ms<?",arrayOf(start.toString(),(start+window).toString())).use { it.moveToFirst();it.getInt(0) }
                val headline = if(count<=1) title else "${if(high) "Ưu tiên cao · " else ""}$count công việc cần nhắc"
                val builder=NotificationCompat.Builder(context,CHANNEL).setSmallIcon(R.drawable.ic_stat_daymind).setContentTitle(headline)
                    .setContentText(if(count<=1)"Mở DayMind để xem hoặc hoãn công việc." else "Mở DayMind để xem đầy đủ.")
                    .setStyle(style.setSummaryText("DayMind SMART")).setContentIntent(launch).setDeleteIntent(dismiss)
                    .setAutoCancel(true).setOnlyAlertOnce(true).setSilent(attempts>1).setPriority(NotificationCompat.PRIORITY_DEFAULT)
                    .addExtras(android.os.Bundle().apply { putIntArray("daymind_event_ids",visibleIds.toIntArray()) })
                val digest = db.rawQuery("SELECT rule_id FROM reminder_events WHERE event_key=?",arrayOf(key)).use { it.moveToFirst() && it.getString(0)=="digest" }
                if(count<=1 && !digest) {
                    for((action,label) in listOf("done" to "Hoàn thành","snooze" to "Hoãn 10 phút")) {
                        val intent=Intent(context,ReminderActionReceiver::class.java).setAction("DAYMIND_$action").putExtra("key",key).putExtra("group",groupId)
                        val pending=PendingIntent.getBroadcast(context,groupId, intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                        builder.addAction(0,label,pending)
                    }
                }
                manager(context).notify(groupId,builder.build())
            }
            MainActivity.changed(if(allowed && MainActivity.foreground) title else null)
        }
    }
    fun action(context: Context, intent: Intent) {
        val key=intent.getStringExtra("key") ?: return;val now=System.currentTimeMillis();val action=intent.action ?: return
        database(context)?.use { db ->
            db.beginTransaction()
            try {
                if(action=="DAYMIND_DISMISS") {
                    val start=intent.getLongExtra("start",now);val end=intent.getLongExtra("end",now)
                    db.execSQL("UPDATE reminder_events SET state='dismissed',read=1,updated_ms=? WHERE state='unknown' AND event_key IN (SELECT event_key FROM delivery_logs WHERE outcome='display_attempt' AND at_ms>=? AND at_ms<?)",arrayOf<Any?>(now,start,end))
                    log(db,key,"dismissed",now)
                } else db.rawQuery("SELECT * FROM reminder_events WHERE event_key=? AND state='unknown'",arrayOf(key)).use { event ->
                    if(event.moveToFirst() && eligible(db,event)) {
                        val task=event.getString(event.getColumnIndexOrThrow("task_id"));val occurrence=event.getString(event.getColumnIndexOrThrow("occurrence_id"))
                        if(action=="DAYMIND_done") {
                            if(occurrence==null) db.execSQL("UPDATE tasks SET status=2,completed_at=?,updated_at=?,revision=revision+1 WHERE id=?",arrayOf<Any?>(now/1000,now/1000,task))
                            else db.rawQuery("SELECT value FROM extension_records WHERE area='occurrences' AND id=?",arrayOf(occurrence)).use { row ->
                                if(row.moveToFirst()) { val data=JSONObject(row.getString(0));data.put("status","completed");data.put("completedAt",java.time.Instant.ofEpochMilli(now).toString());data.put("revision",data.optInt("revision",1)+1)
                                    db.execSQL("UPDATE extension_records SET value=?,updated_ms=? WHERE area='occurrences' AND id=?",arrayOf<Any?>(data.toString(),now,occurrence)) }
                            }
                            val scope=if(occurrence==null)"task_id=?" else "task_id=? AND occurrence_id=?"
                            val args=if(occurrence==null)arrayOf(task) else arrayOf(task,occurrence)
                            db.rawQuery("SELECT platform_id FROM reminder_events WHERE $scope AND state IN ('scheduled','planned')",args).use { rows -> while(rows.moveToNext())cancel(context,rows.getInt(0)) }
                            db.execSQL("UPDATE reminder_events SET state='cancelled',updated_ms=? WHERE $scope AND state IN ('scheduled','planned')",arrayOf<Any>(now,*args));state(db,key,"dismissed","acknowledged",now)
                        } else if(action=="DAYMIND_snooze") {
                            state(db,key,"snoozed","snoozed",now);val at=now+600000
                            val next=MessageDigest.getInstance("SHA-256").digest("$key|$at".toByteArray()).joinToString(""){"%02x".format(it)}
                            db.execSQL("INSERT INTO reminder_events(event_key,task_id,rule_id,occurrence_id,occurrence_revision,task_revision,scheduled_ms,expires_ms,state,read,title,priority,updated_ms) VALUES(?,?,?,?,?,?,?,?,?,0,?,?,?)",
                                arrayOf<Any?>(next,task,"snooze:$key",occurrence,event.getInt(event.getColumnIndexOrThrow("occurrence_revision")),event.getInt(event.getColumnIndexOrThrow("task_revision")),at,at+900000,"planned",event.getString(event.getColumnIndexOrThrow("title")),event.getInt(event.getColumnIndexOrThrow("priority")),now))
                        }
                        val data=JSONObject().put("taskId",task).put("occurrenceId",occurrence).put("action",action).put("at",now)
                        db.execSQL("INSERT INTO extension_records(area,id,value,updated_ms) VALUES('native_actions',?,?,?)",arrayOf<Any?>(UUID.randomUUID().toString(),data.toString(),now))
                    }
                }
                db.setTransactionSuccessful()
            } finally { db.endTransaction() }
        }
        manager(context).cancel(intent.getIntExtra("group",0));MainActivity.changed()
    }
    fun test(context: Context,title: String,body: String) {
        channel(context);if(!granted(context))return
        manager(context).notify(2147483646,NotificationCompat.Builder(context,CHANNEL).setSmallIcon(R.drawable.ic_stat_daymind).setContentTitle(title).setContentText(body).setSilent(true).setAutoCancel(true).build())
    }
}
class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context,intent: Intent) {
        val key=intent.getStringExtra("key") ?: return;val pending=goAsync()
        ReminderRuntime.executor.execute { try { ReminderRuntime.fire(context,key) } catch (_:Exception) {} finally { ReminderRuntime.recover(context,false) { pending.finish() } } }
    }
}
class ReminderActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context,intent: Intent) { val pending=goAsync();ReminderRuntime.executor.execute { try { ReminderRuntime.action(context,intent) } catch (_:Exception) {} finally { ReminderRuntime.recover(context,false) { pending.finish() } } } }
}
class ReminderRecoveryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context,intent: Intent) {
        if(intent.action in listOf(Intent.ACTION_BOOT_COMPLETED,Intent.ACTION_MY_PACKAGE_REPLACED,Intent.ACTION_TIMEZONE_CHANGED,Intent.ACTION_TIME_CHANGED)) { val pending=goAsync();ReminderRuntime.recover(context) { pending.finish() } }
    }
}
